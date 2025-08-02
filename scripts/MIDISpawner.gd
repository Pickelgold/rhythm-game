extends Node

# Reference to the note scene
var note_scene = preload("res://Note.tscn")

# Preload the MIDI loader script
var MIDIBeatmapLoaderScript = preload("res://scripts/MIDIBeatmapLoader.gd")

# MIDI loader
var midi_loader

# Timing variables - New absolute time system
var song_start_time_msec: int = 0  # Millisecond timestamp when song started
var song_offset_seconds: float = 0.0  # Offset for lookahead (negative value)
var current_song_time: float = 0.0  # Current song time in seconds
var is_song_playing: bool = false  # Track if song is actively playing

# Note movement configuration
var note_speed_pixels_per_second: float = 200.0  # pixels per second instead of percentage
var lane_height_pixels: float = 400.0  # will be calculated from actual lane height

# Dynamic lookahead time based on note travel time
var lookahead_time: float = 0.0  # Will be calculated based on travel time

# Tracking spawned notes with precise timing
var spawned_notes: Dictionary = {}  # note_id -> spawn_time
var active_notes: Array[Node] = []  # Currently active note instances

# Configuration - Exported variables for Inspector
@export_file("*.mid") var midi_file_path: String = "res://beatmaps/I.mid"
@export var base_midi_note: int = 36  # C2
@export var enabled_channels: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]  # All MIDI channels (0-15)

func _ready():
	# Wait a frame to ensure the scene is fully loaded
	await get_tree().process_frame
	
	# Calculate actual lane height from the first available lane
	_calculate_lane_dimensions()
	
	# Calculate dynamic lookahead time based on note travel time
	_calculate_lookahead_time()
	
	# Initialize MIDI loader
	midi_loader = MIDIBeatmapLoaderScript.new()
	midi_loader.base_midi_note = base_midi_note
	midi_loader.enabled_channels = enabled_channels
	
	# Load the MIDI file
	if midi_loader.load_midi_file(midi_file_path):
		_debug_print_notes()
		# Start the song with precise timing
		start_song()
	else:
		pass

func _process(delta):
	if midi_loader == null or not is_song_playing:
		return
	
	# Update song time using absolute time calculation
	current_song_time = get_absolute_song_time()
	
	# Update positions of all active notes
	update_note_positions()
	
	# Spawn notes at precise times
	spawn_notes_at_exact_time()

# Calculate absolute song time from system time
func get_absolute_song_time() -> float:
	if not is_song_playing:
		return song_offset_seconds
	
	var current_time_msec = Time.get_ticks_msec()
	var elapsed_seconds = (current_time_msec - song_start_time_msec) / 1000.0
	return song_offset_seconds + elapsed_seconds

# Start the song with precise timing
func start_song():
	song_start_time_msec = Time.get_ticks_msec()
	song_offset_seconds = -lookahead_time  # Start with negative time for lookahead
	is_song_playing = true
	current_song_time = song_offset_seconds
	
	print("Song started at: ", song_start_time_msec, " msec")
	print("Initial song time: ", current_song_time, " seconds")

# Pause the song
func pause_song():
	if is_song_playing:
		current_song_time = get_absolute_song_time()
		song_offset_seconds = current_song_time
		is_song_playing = false

# Resume the song
func resume_song():
	if not is_song_playing:
		song_start_time_msec = Time.get_ticks_msec()
		is_song_playing = true

# Calculate actual lane dimensions from the UI
func _calculate_lane_dimensions():
	# Try to get the first available lane to measure dimensions
	var test_container = get_lane_container(1)  # Try lane 1 first
	if not test_container:
		# Try other lanes if lane 1 doesn't exist
		for lane in range(2, 50):
			test_container = get_lane_container(lane)
			if test_container:
				break
	
	if test_container:
		lane_height_pixels = test_container.size.y
		# Calculate note speed to maintain the same visual speed as before
		# Old system: 0.5 percentage per second = 50% of lane per second
		# New system: equivalent pixels per second
		note_speed_pixels_per_second = lane_height_pixels * 0.5
		print("Lane height: ", lane_height_pixels, " pixels")
		print("Note speed: ", note_speed_pixels_per_second, " pixels/second")
	else:
		print("Warning: Could not find any lane to measure dimensions")

# Legacy function - no longer used, replaced by spawn_notes_at_exact_time()
# Kept for reference but not called
func spawn_midi_notes():
	pass

func get_lane_container(lane_number: int) -> Node:
	# Map lane number to row and position
	var row_info = get_row_info_for_lane(lane_number)
	if row_info == null:
		return null
	
	var row_node = get_node("../UI/MarginContainer/AspectRatioContainer/VBoxContainer/" + row_info["row_name"])
	if not row_node:
		return null
	
	var lane_node = row_node.get_node("Lane " + str(lane_number))
	if not lane_node:
		return null
	
	return lane_node.get_node("Background/NoteContainer")

func get_lane_judgement(lane_number: int) -> Node:
	# Map lane number to row and position
	var row_info = get_row_info_for_lane(lane_number)
	if row_info == null:
		return null
	
	var row_node = get_node("../UI/MarginContainer/AspectRatioContainer/VBoxContainer/" + row_info["row_name"])
	if not row_node:
		return null
	
	var lane_node = row_node.get_node("Lane " + str(lane_number))
	if not lane_node:
		return null
	
	return lane_node.get_node("JudgementLine")

func get_row_info_for_lane(lane_number: int) -> Dictionary:
	# Map lane numbers to their respective rows
	if lane_number >= 1 and lane_number <= 12:
		return {"row_name": "Row 4"}
	elif lane_number >= 13 and lane_number <= 24:
		return {"row_name": "Row 3"}
	elif lane_number >= 25 and lane_number <= 36:
		return {"row_name": "Row 2"}
	elif lane_number >= 37 and lane_number <= 49:
		return {"row_name": "Row 1"}
	else:
		return {}

func _calculate_lookahead_time():
	# Calculate how long it takes for a note to travel the full lane height
	var travel_time = lane_height_pixels / note_speed_pixels_per_second
	
	# Add a small buffer (0.1 seconds) to ensure notes spawn slightly above the visible area
	lookahead_time = travel_time + 0.1
	
	print("Travel time: ", travel_time, " seconds")
	print("Lookahead time: ", lookahead_time, " seconds")

# Spawn notes at their exact calculated spawn times
func spawn_notes_at_exact_time():
	if not midi_loader:
		return
	
	var all_notes = midi_loader.get_all_notes()
	
	for note_data in all_notes:
		var note_id = str(note_data["start_time"]) + "_" + str(note_data["lane"])
		
		# Skip if already spawned
		if spawned_notes.has(note_id):
			continue
		
		# Calculate exact spawn time for this note
		var spawn_time = note_data["start_time"] - lookahead_time
		
		# Check if it's time to spawn this note
		if current_song_time >= spawn_time:
			spawn_note_precise(note_data)
			spawned_notes[note_id] = current_song_time

# Precise note spawning with absolute positioning
func spawn_note_precise(note_data: Dictionary):
	var lane_number = note_data["lane"]
	var start_time = note_data["start_time"]
	var end_time = note_data["end_time"]
	
	# Get the lane container and judgement line
	var lane_container = get_lane_container(lane_number)
	var lane_judgement = get_lane_judgement(lane_number)
	
	if not lane_container or not lane_judgement:
		return
	
	# Calculate judgement line thickness to match note lines
	var judgement_thickness = lane_judgement.size.y
	
	# Create the note instance
	var note = note_scene.instantiate()
	
	# Update note line thickness to match judgement line
	note.line_thickness = judgement_thickness
	
	# Initialize the note with MIDI timing
	var duration = end_time - start_time
	note.initialize(start_time, end_time, lane_number)
	
	# Get the container size to position and size the note properly
	var container_size = lane_container.size
	var lane_height = container_size.y
	var note_width = container_size.x
	
	# Calculate note dimensions: duration + line thickness
	var duration_height = duration * note_speed_pixels_per_second
	var total_note_height = duration_height + judgement_thickness
	
	# Set the overall Note size - VBoxContainer will handle internal layout
	note.custom_minimum_size = Vector2(note_width, total_note_height)
	note.size = Vector2(note_width, total_note_height)
	
	# Set the line thicknesses - Body will automatically expand to fill remaining space
	var top_line = note.get_node("TopLine")
	var bottom_line = note.get_node("BottomLine")
	
	if top_line:
		top_line.custom_minimum_size.y = judgement_thickness
	if bottom_line:
		bottom_line.custom_minimum_size.y = judgement_thickness
	
	# Body will automatically expand to fill: total_height - top_line - bottom_line = duration_height
	
	# Calculate exact initial position based on time until hit
	var time_until_hit = start_time - current_song_time
	var judgement_line_y = lane_container.size.y - judgement_thickness
	var exact_y = judgement_line_y - (time_until_hit * note_speed_pixels_per_second) - note.size.y
	
	# Position the note precisely
	note.position = Vector2(0, exact_y)
	
	# Add the note to the container and active notes list
	lane_container.add_child(note)
	active_notes.append(note)
	
	# Disable the old movement system since we handle positioning manually
	note.stop_falling()

# Update positions of all active notes using absolute time
func update_note_positions():
	# Clean up notes that have been freed
	active_notes = active_notes.filter(func(note): return is_instance_valid(note))
	
	for note in active_notes:
		if not is_instance_valid(note):
			continue
		
		# Calculate exact position based on time until hit
		var time_until_hit = note.start_time - current_song_time
		var lane_container = get_lane_container(note.lane_number)
		
		if not lane_container:
			continue
		
		# Calculate exact Y position
		var judgement_line_y = lane_container.size.y - get_lane_judgement(note.lane_number).size.y
		var exact_y = judgement_line_y - (time_until_hit * note_speed_pixels_per_second) - note.size.y
		
		# Update note position
		note.position.y = exact_y
		
		# Remove notes that have fallen off screen
		if note.position.y > lane_container.size.y + note.size.y:
			active_notes.erase(note)
			note.queue_free()

func _debug_print_notes():
	pass

# Configuration functions
func set_midi_file(path: String):
	midi_file_path = path
	# Reset all timing and spawning state
	spawned_notes.clear()
	active_notes.clear()
	is_song_playing = false
	if midi_loader:
		midi_loader.load_midi_file(path)
		# Restart the song with new timing
		start_song()

func set_base_midi_note(note: int):
	base_midi_note = note
	if midi_loader:
		midi_loader.set_base_midi_note(note)

func set_enabled_channels(channels: Array[int]):
	enabled_channels = channels
	if midi_loader:
		midi_loader.set_enabled_channels(channels)

func reset_song_time():
	# Clear all active notes
	for note in active_notes:
		if is_instance_valid(note):
			note.queue_free()
	active_notes.clear()
	spawned_notes.clear()
	
	# Restart the song timing
	start_song()

# Stop the song completely
func stop_song():
	is_song_playing = false
	# Clear all active notes
	for note in active_notes:
		if is_instance_valid(note):
			note.queue_free()
	active_notes.clear()
	spawned_notes.clear()
