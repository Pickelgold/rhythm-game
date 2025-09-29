class_name MIDIBeatmapLoader
extends RefCounted

# Configuration variables
var channel_base_notes: Array[int] = [48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48]  # Base note for each MIDI channel (default: C4/48)

# MIDI data
var smf_data: SMF.SMFData
var timebase: int
var processed_notes: Array[Dictionary] = []
var tempo_map: Array[Dictionary] = []  # Track tempo changes over time
var channel_programs: Dictionary = {}  # Track initial program per channel
var average_velocity: int = 64  # Average velocity of all notes for consistent audio feedback
var dominant_channel_base_note: int = 48  # Base note from the channel with most notes (for audio feedback)
var dominant_channel_average_velocity: int = 64  # Average velocity from dominant channel only (for audio feedback)

# Load and parse a MIDI file
func load_midi_file(path: String, enabled_channels: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]) -> bool:
	var smf = SMF.new()
	var result = smf.read_file(path)
	
	if result.error != OK:
		return false
	
	smf_data = result.data
	timebase = smf_data.timebase
	
	# Process all notes from the MIDI file
	_process_midi_notes(enabled_channels)
	
	
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

# Capture initial program changes for each channel
func _capture_initial_program_changes(enabled_channels: Array[int]):
	channel_programs.clear()
	
	# Set defaults first
	for i in range(16):
		if i == 9:  # Drum channel (channel 10 in 1-based numbering)
			channel_programs[i] = 0  # Standard drum kit
		else:
			channel_programs[i] = 0  # Grand piano default
	
	# Find first note time for each channel
	var first_note_time_per_channel = {}
	
	# First pass: find when each channel first plays a note
	for track in smf_data.tracks:
		for event_chunk in track.events:
			if event_chunk.event is SMF.MIDIEventNoteOn:
				var channel = event_chunk.channel_number
				if enabled_channels.has(channel):
					var time = convert_midi_time_to_seconds(event_chunk.time)
					if not first_note_time_per_channel.has(channel):
						first_note_time_per_channel[channel] = time
					else:
						first_note_time_per_channel[channel] = min(first_note_time_per_channel[channel], time)
	
	# Second pass: capture program changes that occur before first notes
	for track in smf_data.tracks:
		for event_chunk in track.events:
			if event_chunk.event is SMF.MIDIEventProgramChange:
				var channel = event_chunk.channel_number
				if enabled_channels.has(channel):
					var program = event_chunk.event.number
					var time = convert_midi_time_to_seconds(event_chunk.time)
					
					# Only use program changes before first note (or if no notes exist for this channel)
					if not first_note_time_per_channel.has(channel) or time <= first_note_time_per_channel[channel]:
						channel_programs[channel] = program
	
	# Debug output
	print("Channel programs captured:")
	for channel in range(16):
		if enabled_channels.has(channel) and channel_programs.has(channel):
			var program = channel_programs[channel]
			var instrument_name = "Unknown"
			if channel == 9:
				instrument_name = "Drum Kit"
			elif program == 0:
				instrument_name = "Grand Piano"
			elif program == 40:
				instrument_name = "Violin"
			elif program == 56:
				instrument_name = "Trumpet"
			print("  Channel ", channel, ": Program ", program, " (", instrument_name, ")")

# Process all MIDI notes and convert them to game format
func _process_midi_notes(enabled_channels: Array[int] = []):
	processed_notes.clear()
	tempo_map.clear()
	
	# Debug: Print channel base note configuration
	print("Channel base note configuration:")
	for channel in range(16):
		if enabled_channels.has(channel):
			var base_note = channel_base_notes[channel]
			var note_name = _midi_note_to_name(base_note)
			print("  Channel ", channel, ": ", note_name, " (", base_note, ")")
	
	# First pass: Build tempo map
	_build_tempo_map()
	
	# Second pass: Capture initial program changes
	_capture_initial_program_changes(enabled_channels)
	
	var active_notes = {}  # Track note_on events waiting for note_off
	var found_channels = {}  # Track what channels we find
	var found_notes = {}  # Track what MIDI notes we find
	var total_note_events = 0
	var notes_per_channel = {}  # Track notes per channel for summary
	
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
				var velocity = event.velocity
				var lane = _midi_note_to_lane(midi_note, channel)
				
				if lane > 0:  # Valid lane
					var note_key = str(channel) + "_" + str(midi_note)
					active_notes[note_key] = {
						"start_time": time_seconds,
						"lane": lane,
						"midi_note": midi_note,
						"channel": channel,
						"velocity": velocity,
						"program": channel_programs.get(channel, 0)
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
	
	# Count notes per channel for summary
	for note in processed_notes:
		var channel = note["channel"]
		if not notes_per_channel.has(channel):
			notes_per_channel[channel] = 0
		notes_per_channel[channel] += 1
	
	# Calculate average velocity for consistent audio feedback
	if processed_notes.size() > 0:
		var total_velocity = 0
		for note in processed_notes:
			total_velocity += note["velocity"]
		average_velocity = total_velocity / processed_notes.size()
	else:
		average_velocity = 64  # Default fallback
	
	# Find dominant channel (channel with most notes) for audio feedback base note and velocity
	if notes_per_channel.size() > 0:
		var dominant_channel = 0
		var max_notes = 0
		for channel in notes_per_channel:
			if notes_per_channel[channel] > max_notes:
				max_notes = notes_per_channel[channel]
				dominant_channel = channel
		
		# Set the dominant channel's base note for audio feedback
		dominant_channel_base_note = channel_base_notes[dominant_channel]
		
		# Calculate average velocity from dominant channel only
		var dominant_channel_total_velocity = 0
		var dominant_channel_note_count = 0
		for note in processed_notes:
			if note["channel"] == dominant_channel:
				dominant_channel_total_velocity += note["velocity"]
				dominant_channel_note_count += 1
		
		if dominant_channel_note_count > 0:
			dominant_channel_average_velocity = dominant_channel_total_velocity / dominant_channel_note_count
		else:
			dominant_channel_average_velocity = 64  # Fallback
		
		var dominant_note_name = _midi_note_to_name(dominant_channel_base_note)
		print("Dominant channel: ", dominant_channel, " (", max_notes, " notes) - using base note ", dominant_note_name, " (", dominant_channel_base_note, ") and velocity ", dominant_channel_average_velocity, " for audio feedback")
	else:
		# Fallback if no notes found
		dominant_channel_base_note = 48  # Default C4
		dominant_channel_average_velocity = 64  # Default velocity
	
	# Print processing summary with per-channel breakdown
	var total_notes = processed_notes.size()
	
	print("MIDI processed: ", total_notes, " total notes")
	print("Average velocity: ", average_velocity)
	
	if notes_per_channel.size() > 0:
		# Sort channels for consistent output
		var sorted_channels = notes_per_channel.keys()
		sorted_channels.sort()
		
		for channel in sorted_channels:
			var count = notes_per_channel[channel]
			print("  Channel ", channel, ": ", count, " notes")
	else:
		print("  No valid notes found in enabled channels")

# Convert MIDI note number to lane number using channel-specific base note
func _midi_note_to_lane(midi_note: int, channel: int) -> int:
	var base_note = 48  # Default C4
	if channel >= 0 and channel < 16:
		base_note = channel_base_notes[channel]
	
	var lane = (midi_note - base_note) + 1
	
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
	var overlapping_notes_count = 0
	
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
			overlapping_notes_count += merge_group.size()
			var merged_note = _merge_note_group(merge_group)
			merged_notes.append(merged_note)
		else:
			merged_notes.append(current_note)
		
		i += 1
	
	processed_notes = merged_notes
	
	# Print warning if overlapping notes were merged
	if overlapping_notes_count > 0:
		print("Warning: ", overlapping_notes_count, " overlapping notes were merged")

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

# Set the per-channel base notes configuration
func set_channel_base_notes(base_notes: Array[int]):
	channel_base_notes = base_notes.duplicate()

# Set base MIDI note for a specific channel
func set_channel_base_note(channel: int, base_note: int):
	if channel >= 0 and channel < 16:
		channel_base_notes[channel] = base_note

# Get base MIDI note for a specific channel
func get_channel_base_note(channel: int) -> int:
	if channel >= 0 and channel < 16:
		return channel_base_notes[channel]
	return 48  # Default C4 for invalid channels

# Reset a channel base note to default (C4/48)
func reset_channel_base_note(channel: int):
	if channel >= 0 and channel < 16:
		channel_base_notes[channel] = 48  # Set to C4/48 default

# Reprocess MIDI notes with new channel configuration
func reprocess_with_channels(channels: Array[int]):
	if smf_data != null:
		_process_midi_notes(channels)  # Reprocess with new channels

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

# Get the program for a channel (simplified - no mid-song changes)
func get_program_for_channel(channel: int) -> int:
	return channel_programs.get(channel, 0)

# Helper function to get instrument name for debugging
func _get_instrument_name(program: int, channel: int) -> String:
	if channel == 9:
		return "Drum Kit"
	elif program == 0:
		return "Grand Piano"
	elif program == 40:
		return "Violin"
	elif program == 56:
		return "Trumpet"
	elif program == 73:
		return "Flute"
	else:
		return "Program " + str(program)

# Helper function to convert MIDI note number to note name
func _midi_note_to_name(midi_note: int) -> String:
	var note_names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
	var octave = (midi_note / 12) - 1
	var note_index = midi_note % 12
	return note_names[note_index] + str(octave)

# Get the total duration of the song (latest end time of all notes)
func get_total_duration() -> float:
	if processed_notes.is_empty():
		return 0.0
	
	var max_end_time = 0.0
	for note in processed_notes:
		if note["end_time"] > max_end_time:
			max_end_time = note["end_time"]
	
	return max_end_time
