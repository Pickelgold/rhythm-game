class_name MIDIBeatmapLoader
extends RefCounted

# Configuration variables
var base_midi_note: int = 36  # C2 by default
var enabled_channels: Array[int] = [0]  # Default to channel 0 only

# MIDI data
var smf_data: SMF.SMFData
var timebase: int
var processed_notes: Array[Dictionary] = []
var tempo_map: Array[Dictionary] = []  # Track tempo changes over time

# Load and parse a MIDI file
func load_midi_file(path: String) -> bool:
	var smf = SMF.new()
	var result = smf.read_file(path)
	
	if result.error != OK:
		return false
	
	smf_data = result.data
	timebase = smf_data.timebase
	
	# Process all notes from the MIDI file
	_process_midi_notes()
	
	
	return true

# Convert MIDI ticks to seconds using tempo map for accurate timing
func convert_midi_time_to_seconds(midi_ticks: int) -> float:
	if tempo_map.is_empty():
		# Fallback to default tempo if no tempo map available
		var microseconds_per_beat = 500000.0  # 120 BPM
		var ticks_per_beat = float(timebase)
		var total_microseconds = (midi_ticks * microseconds_per_beat) / ticks_per_beat
		return total_microseconds / 1000000.0
	
	var total_seconds = 0.0
	var current_ticks = 0
	var target_ticks = midi_ticks
	
	# Process each tempo segment
	for i in range(tempo_map.size()):
		var tempo_entry = tempo_map[i]
		var segment_start_ticks = tempo_entry["ticks"]
		var microseconds_per_beat = tempo_entry["microseconds_per_beat"]
		
		# Determine the end of this tempo segment
		var segment_end_ticks = target_ticks
		if i < tempo_map.size() - 1:
			segment_end_ticks = min(target_ticks, tempo_map[i + 1]["ticks"])
		
		# Skip if we haven't reached this segment yet
		if segment_end_ticks <= current_ticks:
			continue
		
		# Calculate the actual start and end for this segment
		var actual_start = max(current_ticks, segment_start_ticks)
		var actual_end = segment_end_ticks
		
		if actual_end > actual_start:
			# Calculate time for this segment
			var segment_ticks = actual_end - actual_start
			var ticks_per_beat = float(timebase)
			var segment_microseconds = (segment_ticks * microseconds_per_beat) / ticks_per_beat
			total_seconds += segment_microseconds / 1000000.0
			
			current_ticks = actual_end
		
		# Stop if we've reached our target
		if current_ticks >= target_ticks:
			break
	
	return total_seconds

# Process all MIDI notes and convert them to game format
func _process_midi_notes():
	processed_notes.clear()
	tempo_map.clear()
	
	# First pass: Build tempo map
	_build_tempo_map()
	
	var active_notes = {}  # Track note_on events waiting for note_off
	var found_channels = {}  # Track what channels we find
	var found_notes = {}  # Track what MIDI notes we find
	var total_note_events = 0
	
	# Process each track
	for track in smf_data.tracks:
		# Process each event in the track
		for event_chunk in track.events:
			var channel = event_chunk.channel_number
			var event = event_chunk.event
			var time_seconds = convert_midi_time_to_seconds(event_chunk.time)
			
			# Track found channels and notes for debugging
			if event is SMF.MIDIEventNoteOn:
				total_note_events += 1
				found_channels[channel] = true
				found_notes[event.note] = true
			
			# Skip if this channel is not enabled
			if not enabled_channels.has(channel):
				continue
			
			# Handle note events
			if event is SMF.MIDIEventNoteOn:
				var midi_note = event.note
				var lane = _midi_note_to_lane(midi_note)
				
				if lane > 0:  # Valid lane
					var note_key = str(channel) + "_" + str(midi_note)
					active_notes[note_key] = {
						"start_time": time_seconds,
						"lane": lane,
						"midi_note": midi_note,
						"channel": channel
					}
			
			elif event is SMF.MIDIEventNoteOff:
				var midi_note = event.note
				var note_key = str(channel) + "_" + str(midi_note)
				
				if active_notes.has(note_key):
					var note_data = active_notes[note_key]
					note_data["end_time"] = time_seconds
					
					# Add completed note to processed list
					processed_notes.append(note_data)
					active_notes.erase(note_key)
	
	
	# Handle any remaining active notes (notes without explicit note_off)
	for note_key in active_notes.keys():
		var note_data = active_notes[note_key]
		note_data["end_time"] = note_data["start_time"] + 0.1  # Default 0.1 second duration
		processed_notes.append(note_data)
	
	# Sort notes by start time
	processed_notes.sort_custom(_compare_notes_by_time)
	
	# Merge overlapping notes in the same lane
	_merge_overlapping_notes()

# Convert MIDI note number to lane number
func _midi_note_to_lane(midi_note: int) -> int:
	var lane = (midi_note - base_midi_note) + 1
	
	# Clamp to valid lane range (1-49)
	if lane < 1 or lane > 49:
		return 0  # Invalid lane
	
	return lane

# Compare function for sorting notes by time
func _compare_notes_by_time(a: Dictionary, b: Dictionary) -> bool:
	return a["start_time"] < b["start_time"]

# Merge overlapping notes in the same lane
func _merge_overlapping_notes():
	var merged_notes: Array[Dictionary] = []
	var i = 0
	
	while i < processed_notes.size():
		var current_note = processed_notes[i]
		var merge_group = [current_note]
		
		# Look for overlapping notes in the same lane
		var j = i + 1
		while j < processed_notes.size():
			var next_note = processed_notes[j]
			
			# Check if notes are in same lane and overlap
			if (next_note["lane"] == current_note["lane"] and 
				_notes_overlap(current_note, next_note)):
				merge_group.append(next_note)
				processed_notes.remove_at(j)
			else:
				j += 1
		
		# Merge the group if it has multiple notes
		if merge_group.size() > 1:
			var merged_note = _merge_note_group(merge_group)
			merged_notes.append(merged_note)
		else:
			merged_notes.append(current_note)
		
		i += 1
	
	processed_notes = merged_notes

# Check if two notes overlap in time
func _notes_overlap(note1: Dictionary, note2: Dictionary) -> bool:
	return not (note1["end_time"] <= note2["start_time"] or note2["end_time"] <= note1["start_time"])

# Merge a group of overlapping notes
func _merge_note_group(notes: Array) -> Dictionary:
	var earliest_start = notes[0]["start_time"]
	var latest_end = notes[0]["end_time"]
	
	for note in notes:
		if note["start_time"] < earliest_start:
			earliest_start = note["start_time"]
		if note["end_time"] > latest_end:
			latest_end = note["end_time"]
	
	# Return merged note using the first note as template
	var merged = notes[0].duplicate()
	merged["start_time"] = earliest_start
	merged["end_time"] = latest_end
	
	return merged

# Get notes that should be spawned in a given time range
func get_notes_in_timerange(start_time: float, end_time: float) -> Array[Dictionary]:
	var notes_to_spawn: Array[Dictionary] = []
	
	for note in processed_notes:
		if note["start_time"] >= start_time and note["start_time"] <= end_time:
			notes_to_spawn.append(note)
	
	return notes_to_spawn

# Get all processed notes (for debugging)
func get_all_notes() -> Array[Dictionary]:
	return processed_notes

# Set the base MIDI note (configurable starting point)
func set_base_midi_note(note: int):
	base_midi_note = note
	if smf_data != null:
		_process_midi_notes()  # Reprocess with new base note

# Set enabled channels
func set_enabled_channels(channels: Array[int]):
	enabled_channels = channels
	if smf_data != null:
		_process_midi_notes()  # Reprocess with new channels

# Build tempo map from MIDI file tempo events
func _build_tempo_map():
	tempo_map.clear()
	
	# Start with default tempo (120 BPM = 500000 microseconds per beat)
	tempo_map.append({
		"ticks": 0,
		"microseconds_per_beat": 500000.0
	})
	
	# Collect all tempo events from all tracks
	var tempo_events: Array[Dictionary] = []
	
	for track in smf_data.tracks:
		for event_chunk in track.events:
			var event = event_chunk.event
			
			# Check for tempo change events
			if event is SMF.MIDIEventSystemEvent:
				var args = event.args
				if args.has("type") and args["type"] == SMF.MIDISystemEventType.set_tempo:
					tempo_events.append({
						"ticks": event_chunk.time,
						"microseconds_per_beat": float(args["bpm"])
					})
	
	# Sort tempo events by time
	tempo_events.sort_custom(func(a, b): return a["ticks"] < b["ticks"])
	
	# Add tempo events to tempo map, replacing default if there's a tempo at tick 0
	for tempo_event in tempo_events:
		if tempo_event["ticks"] == 0:
			# Replace the default tempo
			tempo_map[0] = tempo_event
		else:
			# Add new tempo change
			tempo_map.append(tempo_event)
	
	# Debug output
	print("Built tempo map with ", tempo_map.size(), " entries:")
	for i in range(tempo_map.size()):
		var entry = tempo_map[i]
		var bpm = 60000000.0 / entry["microseconds_per_beat"]  # Convert to BPM for readability
		print("  Tick ", entry["ticks"], ": ", entry["microseconds_per_beat"], " μs/beat (", "%.1f" % bpm, " BPM)")

# Get the total duration of the song (latest end time of all notes)
func get_total_duration() -> float:
	if processed_notes.is_empty():
		return 0.0
	
	var max_end_time = 0.0
	for note in processed_notes:
		if note["end_time"] > max_end_time:
			max_end_time = note["end_time"]
	
	return max_end_time
