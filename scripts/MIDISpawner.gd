extends Node

# Reference to the note scene
var note_scene = preload("res://scenes/Note.tscn")

# Preload the MIDI loader script
var MIDIBeatmapLoaderScript = preload("res://scripts/MIDIBeatmapLoader.gd")

# MIDI loader
var midi_loader

# Background music player
var background_music_player: AudioStreamPlayer
var background_music_start_time: float = 0.0  # When background music should start
var background_music_started: bool = false  # Track if background music has started

# Timing variables - New absolute time system
var song_start_time_msec: int = 0  # Millisecond timestamp when song started
var song_offset_seconds: float = 0.0  # Offset for lookahead (negative value)
var current_song_time: float = 0.0  # Current song time in seconds
var is_song_playing: bool = false  # Track if song is actively playing

# Note movement configuration
var note_speed_pixels_per_second: float  # pixels per second calculated from visibility time
var lane_height_pixels: float  # will be calculated from actual lane height

# Dynamic lookahead time based on note travel time
var lookahead_time: float = 0.0  # Will be calculated based on travel time

# Tracking spawned notes with precise timing
var spawned_notes: Dictionary = {}  # note_id -> spawn_time
var active_notes: Array[Node] = []  # Currently active note instances

# Configuration - Exported variables for Inspector
@export_file("*.mid") var midi_file_path: String = "res://beatmaps/I.mid"
@export var channel_base_notes: Array[int] = [48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48]  # Base note for each MIDI channel (default: C4/48)
@export var enabled_channels: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]  # All MIDI channels (0-15)

# Background music configuration
@export_file("*.ogg", "*.mp3", "*.wav") var background_music_path: String = ""
@export var audio_offset: float = 0.0  # Negative: audio first, Positive: MIDI first
# Background music volume is now managed by AudioManager singleton

# Note timing configuration
@export var note_visibility_seconds: float = 1.0  # How long notes are visible before hitting judgment line

func _ready():
	# Start timing the setup process
	var setup_start_time = Time.get_ticks_msec()
	print("Setup started at: ", setup_start_time, " ms")
	
	# Wait a frame to ensure the scene is fully loaded
	await get_tree().process_frame
	
	# Calculate actual lane height from the first available lane
	_calculate_lane_dimensions()
	
	# Calculate dynamic lookahead time based on note travel time
	_calculate_lookahead_time()
	
	# Initialize background music player
	_setup_background_music()
	
	# Initialize MIDI loader
	midi_loader = MIDIBeatmapLoaderScript.new()
	midi_loader.set_channel_base_notes(channel_base_notes)
	
	# Connect to judgement system for note removal
	var judgement_system = get_node("../JudgementSystem")
	if judgement_system:
		judgement_system.note_should_be_removed.connect(_on_note_should_be_removed)
	
	# Load the MIDI file with enabled channels
	if midi_loader.load_midi_file(midi_file_path, enabled_channels):
		_debug_print_notes()
		# Start the song with precise timing
		start_song()
		
		var total_setup_time = Time.get_ticks_msec() - setup_start_time
		print("Total setup time: ", total_setup_time, " ms")
	else:
		var total_setup_time = Time.get_ticks_msec() - setup_start_time
		print("Total setup time: ", total_setup_time, " ms")

func _process(delta):
	if midi_loader == null or not is_song_playing:
		return
	
	# Update song time using absolute time calculation
	current_song_time = get_absolute_song_time()
	
	# Check if background music should start with precise timing
	_check_background_music_timing()
	
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
	
	if audio_offset < 0:
		# Case 1: Audio starts first, MIDI delayed by abs(audio_offset)
		var midi_delay = abs(audio_offset)
		song_offset_seconds = -lookahead_time - midi_delay
		background_music_start_time = -midi_delay  # Audio starts earlier
	else:
		# Case 2: MIDI starts first, audio delayed by audio_offset
		song_offset_seconds = -lookahead_time  # MIDI starts immediately
		background_music_start_time = audio_offset  # Audio delayed
	
	is_song_playing = true
	current_song_time = song_offset_seconds
	
	# Start background music if available
	_start_background_music()

# Pause the song
func pause_song():
	if is_song_playing:
		current_song_time = get_absolute_song_time()
		song_offset_seconds = current_song_time
		is_song_playing = false
		
		# Pause background music
		if background_music_player and background_music_player.playing:
			background_music_player.stream_paused = true

# Resume the song
func resume_song():
	if not is_song_playing:
		song_start_time_msec = Time.get_ticks_msec()
		is_song_playing = true
		
		# Resume background music
		if background_music_player and background_music_player.stream_paused:
			background_music_player.stream_paused = false

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
		# Calculate note speed based on desired visibility time
		# Speed = distance / time, so pixels per second = lane height / visibility seconds
		note_speed_pixels_per_second = lane_height_pixels / note_visibility_seconds
	else:
		# Fallback: assume standard lane height and calculate speed from visibility time
		lane_height_pixels = 400.0  # Standard fallback lane height
		note_speed_pixels_per_second = lane_height_pixels / note_visibility_seconds


func get_lane_container(lane_number: int) -> Node:
	# Map lane number to row and position
	var row_info = get_row_info_for_lane(lane_number)
	if row_info == null:
		return null
	
	var row_node = get_node("../UI/HBoxContainer/GameplayArea/" + row_info["row_name"])
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
	
	var row_node = get_node("../UI/HBoxContainer/GameplayArea/" + row_info["row_name"])
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
	# Lookahead time is now directly controlled by the export variable
	# This ensures notes are visible for exactly the specified duration
	lookahead_time = note_visibility_seconds
	

# Spawn notes at their exact calculated spawn times
func spawn_notes_at_exact_time():
	if not midi_loader:
		return
	
	# Only check notes that are near the current spawn time to avoid processing all notes every frame
	var spawn_window_start = current_song_time - 0.1  # Small buffer for precision
	var spawn_window_end = current_song_time + lookahead_time + 0.1  # Look ahead for notes to spawn
	
	var nearby_notes = midi_loader.get_notes_in_timerange(spawn_window_start, spawn_window_end)
	
	for note_data in nearby_notes:
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
	var exact_y = judgement_line_y - (time_until_hit * note_speed_pixels_per_second) - note.size.y + judgement_thickness
	
	# Position the note precisely (rounded to whole pixels to prevent flickering)
	note.position = Vector2(0, round(exact_y))
	
	# Add the note to the container and active notes list
	lane_container.add_child(note)
	active_notes.append(note)

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
		var judgement_thickness = get_lane_judgement(note.lane_number).size.y
		var exact_y = judgement_line_y - (time_until_hit * note_speed_pixels_per_second) - note.size.y + judgement_thickness
		
		# Update note position (rounded to whole pixels to prevent flickering)
		note.position.y = round(exact_y)
		
		# Remove notes that have fallen off screen
		if note.position.y > lane_container.size.y + note.size.y:
			active_notes.erase(note)
			note.queue_free()

func _debug_print_notes():
	pass

# Setup background music player
func _setup_background_music():
	# Create AudioStreamPlayer for background music
	background_music_player = AudioStreamPlayer.new()
	add_child(background_music_player)
	
	# Load background music if path is provided
	if background_music_path != "":
		print("Attempting to load background music: ", background_music_path)
		
		# Check if file exists
		if not FileAccess.file_exists(background_music_path):
			print("Background music file not found: ", background_music_path)
			return
		
		# Try to load the audio stream
		var audio_stream = load(background_music_path)
		if audio_stream == null:
			print("Failed to load background music (null stream): ", background_music_path)
			print("Make sure the audio file is imported properly in Godot")
			return
		
		if not audio_stream is AudioStream:
			print("Loaded resource is not an AudioStream: ", background_music_path)
			return
		
		background_music_player.stream = audio_stream
		# Set volume using AudioManager
		AudioManager.set_audio_stream_player_volume(background_music_player, "music")
		print("Background music loaded successfully: ", background_music_path)
		print("Audio stream type: ", audio_stream.get_class())
		print("Background music volume set via AudioManager")
	else:
		print("No background music path specified")

# Start background music with proper timing
func _start_background_music():
	if not background_music_player or not background_music_player.stream:
		return
	
	# background_music_start_time is already calculated in start_song()
	background_music_started = false
	
	if background_music_start_time <= current_song_time:
		# Background music should start now or has already started
		var seek_position = current_song_time - background_music_start_time
		if seek_position >= 0:
			background_music_player.play(seek_position)
			background_music_started = true
			print("Background music started at position: ", seek_position)
	else:
		# Background music will start later - will be checked in _process()
		print("Background music will start in: ", background_music_start_time - current_song_time, " seconds")

# Check if background music should start with precise timing
func _check_background_music_timing():
	if not background_music_player or not background_music_player.stream or background_music_started:
		return
	
	# Check if it's time to start background music
	if current_song_time >= background_music_start_time:
		background_music_player.play()
		background_music_started = true
		print("Background music started at precise time: ", current_song_time)

# Configuration functions
func set_midi_file(path: String):
	midi_file_path = path
	# Reset all timing and spawning state
	spawned_notes.clear()
	active_notes.clear()
	is_song_playing = false
	if midi_loader:
		midi_loader.set_channel_base_notes(channel_base_notes)
		midi_loader.load_midi_file(path, enabled_channels)
		# Restart the song with new timing
		start_song()

# Set base MIDI note for a specific channel
func set_channel_base_note(channel: int, base_note: int):
	if channel >= 0 and channel < 16:
		channel_base_notes[channel] = base_note
		if midi_loader:
			midi_loader.set_channel_base_notes(channel_base_notes)
			midi_loader.reprocess_with_channels(enabled_channels)

# Get base MIDI note for a specific channel
func get_channel_base_note(channel: int) -> int:
	if channel >= 0 and channel < 16:
		return channel_base_notes[channel]
	return 48  # Default C4 for invalid channels

# Reset a channel base note to default (C4/48)
func reset_channel_base_note(channel: int):
	if channel >= 0 and channel < 16:
		channel_base_notes[channel] = 48  # Set to C4/48 default
		if midi_loader:
			midi_loader.set_channel_base_notes(channel_base_notes)
			midi_loader.reprocess_with_channels(enabled_channels)

func set_enabled_channels(channels: Array[int]):
	enabled_channels = channels
	if midi_loader:
		midi_loader.reprocess_with_channels(channels)

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
	
	# Stop background music and reset state
	if background_music_player and background_music_player.playing:
		background_music_player.stop()
	background_music_started = false
	
	# Clear all active notes
	for note in active_notes:
		if is_instance_valid(note):
			note.queue_free()
	active_notes.clear()
	spawned_notes.clear()

# Handle note removal signal from judgement system
func _on_note_should_be_removed(lane_number: int, start_time: float, end_time: float):
	# Find and remove the note that matches the given parameters
	for i in range(active_notes.size() - 1, -1, -1):  # Iterate backwards to safely remove items
		var note = active_notes[i]
		if not is_instance_valid(note):
			active_notes.remove_at(i)
			continue
		
		# Check if this note matches the one that should be removed
		if note.lane_number == lane_number and abs(note.start_time - start_time) < 0.001 and abs(note.end_time - end_time) < 0.001:
			# Remove from active notes and free the node
			active_notes.remove_at(i)
			note.queue_free()
			
			# Also remove from spawned_notes to prevent respawning
			var note_id = str(start_time) + "_" + str(lane_number)
			spawned_notes.erase(note_id)
			
			break  # Only remove the first matching note
