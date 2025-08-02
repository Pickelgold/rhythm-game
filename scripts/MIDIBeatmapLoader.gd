class_name MIDIBeatmapLoader
extends RefCounted

# Configuration variables
var base_midi_note: int = 36  # C2 by default
var enabled_channels: Array[int] = [0]  # Default to channel 0 only

# MIDI data
var smf_data: SMF.SMFData
var timebase: int
var processed_notes: Array[Dictionary] = []

# Load and parse a MIDI file
func load_midi_file(path: String) -> bool:
	var smf = SMF.new()
	var result = smf.read_file(path)
	
	if result.error != OK:
		print("Error loading MIDI file: ", result.error)
		return false
	
	smf_data = result.data
	timebase = smf_data.timebase
	
	# Process all notes from the MIDI file
	_process_midi_notes()
	
	print("Loaded MIDI file: ", path)
	print("Tracks: ", smf_data.tracks.size())
	print("Timebase: ", timebase)
	print("Enabled channels: ", enabled_channels)
	print("Base MIDI note: ", base_midi_note)
	print("Processed notes: ", processed_notes.size())
	
	return true

# Convert MIDI ticks to seconds with improved precision
func convert_midi_time_to_seconds(midi_ticks: int) -> float:
	# Default tempo: 120 BPM = 500000 microseconds per beat
	# Use higher precision calculation to minimize floating-point errors
	var microseconds_per_beat = 500000.0
	var ticks_per_beat = float(timebase)
	
	# Calculate microseconds first, then convert to seconds to maintain precision
	var total_microseconds = (midi_ticks * microseconds_per_beat) / ticks_per_beat
	return total_microseconds / 1000000.0

# Process all MIDI notes and convert them to game format
func _process_midi_notes():
	processed_notes.clear()
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
	
	# Debug output
	print("Debug: Found ", total_note_events, " total note events")
	print("Debug: Found channels: ", found_channels.keys())
	print("Debug: MIDI note range: ", found_notes.keys().min() if found_notes.size() > 0 else "none", " to ", found_notes.keys().max() if found_notes.size() > 0 else "none")
	
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
