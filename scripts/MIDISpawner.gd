extends Node

# Reference to the note scene
var note_scene = preload("res://Note.tscn")

# Preload the MIDI loader script
var MIDIBeatmapLoaderScript = preload("res://scripts/MIDIBeatmapLoader.gd")

# MIDI loader
var midi_loader

# Timing variables
var current_song_time: float = 0.0  # Start at 0, will be adjusted based on lookahead
var pixels_per_second: float = 200.0

# Dynamic lookahead time based on screen height and speed
var lookahead_time: float = 0.0  # Will be calculated based on lane height and speed

# Tracking spawned notes to avoid duplicates
var spawned_notes: Dictionary = {}

# Configuration - Exported variables for Inspector
@export_file("*.mid") var midi_file_path: String = "res://beatmaps/I.mid"
@export var base_midi_note: int = 36  # C2
@export var enabled_channels: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]  # All MIDI channels (0-15)

func _ready():
	# Wait a frame to ensure the scene is fully loaded
	await get_tree().process_frame
	
	# Calculate dynamic lookahead time based on lane height and speed
	_calculate_lookahead_time()
	
	# Set starting time to negative lookahead to catch early notes
	current_song_time = -lookahead_time
	
	# Initialize MIDI loader
	midi_loader = MIDIBeatmapLoaderScript.new()
	midi_loader.base_midi_note = base_midi_note
	midi_loader.enabled_channels = enabled_channels
	
	# Load the MIDI file
	if midi_loader.load_midi_file(midi_file_path):
		_debug_print_notes()
	else:
		pass

func _process(delta):
	if midi_loader == null:
		return
	
	# Update song time
	current_song_time += delta
	
	# Spawn notes that should appear in the lookahead window
	spawn_midi_notes()

func spawn_midi_notes():
	var lookahead_start = current_song_time
	var lookahead_end = current_song_time + lookahead_time
	
	# Get notes that should be spawned in this time window
	var notes_to_spawn = midi_loader.get_notes_in_timerange(lookahead_start, lookahead_end)
	
	for note_data in notes_to_spawn:
		var note_id = str(note_data["start_time"]) + "_" + str(note_data["lane"])
		
		# Skip if already spawned
		if spawned_notes.has(note_id):
			continue
		
		# Spawn the note
		spawn_note(note_data)
		spawned_notes[note_id] = true

func spawn_note(note_data: Dictionary):
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
	
	# Calculate note dimensions including white lines
	var duration_height = duration * pixels_per_second
	var line_thickness = note.get_total_line_thickness()
	var total_note_height = duration_height + line_thickness
	
	# Get the container size to position and size the note properly
	var container_size = lane_container.size
	var note_width = container_size.x
	
	# Set note size (includes the white lines)
	note.size = Vector2(note_width, total_note_height)
	
	# Update the line heights in the note to match judgement thickness
	var top_line = note.get_node("TopLine")
	var bottom_line = note.get_node("BottomLine")
	if top_line:
		top_line.offset_bottom = judgement_thickness
	if bottom_line:
		bottom_line.offset_top = -judgement_thickness
	
	# Calculate when the note should reach the judgement line
	var time_until_hit = start_time - current_song_time
	var travel_distance = time_until_hit * pixels_per_second
	
	# Position the note so its bottom line aligns with judgement line at perfect timing
	# The judgement line is at the bottom of the lane container (where the JudgementLine ColorRect is)
	# When time_until_hit = 0, the note's bottom should be at the container's bottom
	var perfect_timing_y = lane_container.size.y - judgement_thickness
	var start_y_position = perfect_timing_y - total_note_height - travel_distance
	note.position = Vector2(0, start_y_position)
	
	# Add the note to the container
	lane_container.add_child(note)
	
	# Start the note falling
	note.start_falling(pixels_per_second)

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
	# Get the lane container height to calculate how long notes need to travel
	var sample_container = get_lane_container(37)  # Use lane 37 as sample
	if not sample_container:
		# Fallback to default if we can't get container size
		lookahead_time = 2.0
		return
	
	# Get the background container (parent of NoteContainer)
	var background = sample_container.get_parent()
	if not background:
		lookahead_time = 2.0
		return
	
	# Calculate how long it takes for a note to travel from top to judgement line
	var lane_height = background.size.y
	var travel_time = lane_height / pixels_per_second
	
	# Add a small buffer (0.1 seconds) to ensure notes spawn slightly above the visible area
	lookahead_time = travel_time + 0.1

func _debug_print_notes():
	pass

# Configuration functions
func set_midi_file(path: String):
	midi_file_path = path
	# Reset spawned notes when changing songs
	spawned_notes.clear()
	current_song_time = -lookahead_time
	if midi_loader:
		midi_loader.load_midi_file(path)

func set_base_midi_note(note: int):
	base_midi_note = note
	if midi_loader:
		midi_loader.set_base_midi_note(note)

func set_enabled_channels(channels: Array[int]):
	enabled_channels = channels
	if midi_loader:
		midi_loader.set_enabled_channels(channels)

func reset_song_time():
	current_song_time = -lookahead_time
	spawned_notes.clear()
