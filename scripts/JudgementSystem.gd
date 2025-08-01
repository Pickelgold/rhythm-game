extends Node
class_name JudgementSystem

# Reference to other systems
var keyboard_controller: Node
var midi_spawner: Node

# Track active notes that can be judged (within timing window)
var active_notes_by_lane: Dictionary = {}  # lane_number -> Array of note data

# Timing configuration
var judgement_window_ms: float = 100.0  # ±100ms window
var current_song_time: float = 0.0

# References to judgement labels for each lane
var judgement_labels: Dictionary = {}

func _ready():
	# Wait for scene to be fully loaded
	await get_tree().process_frame
	
	# Get references to other systems
	keyboard_controller = get_node("../KeyboardController")
	midi_spawner = get_node("../MIDISpawner")
	
	# Connect to keyboard controller signals
	if keyboard_controller:
		keyboard_controller.key_pressed.connect(_on_key_pressed)
	
	# Initialize judgement labels dictionary
	_setup_judgement_labels()
	
	# Initialize active notes tracking
	for i in range(1, 50):  # Lanes 1-49
		active_notes_by_lane[i] = []

func _process(delta):
	# Update current song time to match midi_spawner
	if midi_spawner:
		current_song_time = midi_spawner.current_song_time
	
	# Update active notes (add notes entering judgement zone, remove notes leaving it)
	_update_active_notes()

func _setup_judgement_labels():
	# Get references to all judgement labels
	var ui_root = get_node("../UI/MarginContainer/AspectRatioContainer/VBoxContainer")
	
	# Row 1: Lanes 37-49
	var row1 = ui_root.get_node("Row 1")
	for lane in range(37, 50):
		var lane_node = row1.get_node("Lane " + str(lane))
		var label = lane_node.get_node("Background/JudgementLabel")
		judgement_labels[lane] = label
	
	# Row 2: Lanes 25-36
	var row2 = ui_root.get_node("Row 2")
	for lane in range(25, 37):
		var lane_node = row2.get_node("Lane " + str(lane))
		var label = lane_node.get_node("Background/JudgementLabel")
		judgement_labels[lane] = label
	
	# Row 3: Lanes 13-24
	var row3 = ui_root.get_node("Row 3")
	for lane in range(13, 25):
		var lane_node = row3.get_node("Lane " + str(lane))
		var label = lane_node.get_node("Background/JudgementLabel")
		judgement_labels[lane] = label
	
	# Row 4: Lanes 1-12
	var row4 = ui_root.get_node("Row 4")
	for lane in range(1, 13):
		var lane_node = row4.get_node("Lane " + str(lane))
		var label = lane_node.get_node("Background/JudgementLabel")
		judgement_labels[lane] = label

func _update_active_notes():
	if not midi_spawner or not midi_spawner.midi_loader:
		return
	
	# Get all notes from the MIDI loader
	var all_notes = midi_spawner.midi_loader.get_all_notes()
	
	# Clear current active notes
	for lane in active_notes_by_lane.keys():
		active_notes_by_lane[lane].clear()
	
	# Add notes that are within the judgement window
	var judgement_window_seconds = judgement_window_ms / 1000.0
	
	for note_data in all_notes:
		var lane = note_data["lane"]
		var start_time = note_data["start_time"]
		var end_time = note_data["end_time"]
		
		# Check if note start or end time is within judgement window
		var start_diff = abs(start_time - current_song_time)
		var end_diff = abs(end_time - current_song_time)
		
		if start_diff <= judgement_window_seconds or end_diff <= judgement_window_seconds:
			# Add both start and end timing points
			active_notes_by_lane[lane].append({
				"time": start_time,
				"type": "start",
				"note_data": note_data
			})
			active_notes_by_lane[lane].append({
				"time": end_time,
				"type": "end", 
				"note_data": note_data
			})

func _on_key_pressed(lane_number: int):
	# Find the closest note timing in this lane
	if not active_notes_by_lane.has(lane_number):
		return
	
	var lane_notes = active_notes_by_lane[lane_number]
	if lane_notes.is_empty():
		return
	
	# Find the closest timing point
	var closest_note = null
	var closest_time_diff = INF
	
	for note_timing in lane_notes:
		var time_diff = abs(note_timing["time"] - current_song_time)
		if time_diff < closest_time_diff:
			closest_time_diff = time_diff
			closest_note = note_timing
	
	if closest_note == null:
		return
	
	# Calculate timing difference in milliseconds
	var timing_diff_ms = (current_song_time - closest_note["time"]) * 1000.0
	
	# Generate judgement text
	var judgement_text = _format_judgement(timing_diff_ms)
	
	# Update the judgement label
	if judgement_labels.has(lane_number):
		judgement_labels[lane_number].text = judgement_text
		
		# Optional: Add a timer to clear the text after a short delay
		_clear_judgement_after_delay(lane_number, 1.0)

func _format_judgement(timing_diff_ms: float) -> String:
	var abs_diff = abs(timing_diff_ms)
	
	if abs_diff >= judgement_window_ms:
		return "Miss"
	
	# Round to nearest millisecond
	var rounded_diff = round(timing_diff_ms)
	
	if rounded_diff == 0:
		return "0ms"
	elif rounded_diff > 0:
		return "+" + str(int(rounded_diff)) + "ms"
	else:
		return str(int(rounded_diff)) + "ms"

func _clear_judgement_after_delay(lane_number: int, delay: float):
	# Create a timer to clear the judgement text
	var timer = Timer.new()
	timer.wait_time = delay
	timer.one_shot = true
	add_child(timer)
	
	timer.timeout.connect(func():
		if judgement_labels.has(lane_number):
			judgement_labels[lane_number].text = ""
		timer.queue_free()
	)
	
	timer.start()
