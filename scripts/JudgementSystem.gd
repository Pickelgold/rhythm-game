extends Node
class_name JudgementSystem

# Reference to other systems
var keyboard_controller: Node
var midi_spawner: Node

# Track active notes that can be judged (within timing window)
var active_notes_by_lane: Dictionary = {}  # lane_number -> Array of note data

# Track notes that have been judged to avoid duplicate judgements
var judged_notes: Dictionary = {}  # note_id -> true

# Track notes that were previously in the judgement window
var previously_active_notes: Dictionary = {}  # note_id -> true

# Track which keys are currently held down for hold notes
var held_keys: Dictionary = {}  # lane_number -> true

# Track active hold notes (notes that have been started but not ended)
var active_hold_notes: Dictionary = {}  # lane_number -> note_data

# Timing configuration
var judgement_window_ms: float = 200.0  # ±200ms window
var current_song_time: float = 0.0

# References to judgement labels for each lane
var press_labels: Dictionary = {}
var release_labels: Dictionary = {}


func _ready():
	# Wait for scene to be fully loaded
	await get_tree().process_frame
	
	# Get references to other systems
	keyboard_controller = get_node("../KeyboardController")
	midi_spawner = get_node("../MIDISpawner")
	
	# Connect to keyboard controller signals
	if keyboard_controller:
		keyboard_controller.key_pressed.connect(_on_key_pressed)
		keyboard_controller.key_released.connect(_on_key_released)
	
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

# Get precise song time at the exact moment of input (not frame-dependent)
func get_precise_song_time() -> float:
	if not midi_spawner or not midi_spawner.is_song_playing:
		return midi_spawner.song_offset_seconds if midi_spawner else 0.0
	
	var current_time_msec = Time.get_ticks_msec()
	var elapsed_seconds = (current_time_msec - midi_spawner.song_start_time_msec) / 1000.0
	return midi_spawner.song_offset_seconds + elapsed_seconds

func _setup_judgement_labels():
	# Get references to all judgement labels
	var ui_root = get_node("../UI/MarginContainer/AspectRatioContainer/VBoxContainer")
	
	# Row 1: Lanes 37-49
	var row1 = ui_root.get_node("Row 1")
	for lane in range(37, 50):
		var lane_node = row1.get_node("Lane " + str(lane))
		# Check if this lane has the new VBoxContainer structure
		if lane_node.get_node("Background").has_node("VBoxContainer"):
			var vbox = lane_node.get_node("Background/VBoxContainer")
			press_labels[lane] = vbox.get_node("PressLabel")
			release_labels[lane] = vbox.get_node("ReleaseLabel")
		else:
			# Fallback to old single label structure
			var label = lane_node.get_node("Background/JudgementLabel")
			press_labels[lane] = label
			release_labels[lane] = label
	
	# Row 2: Lanes 25-36
	var row2 = ui_root.get_node("Row 2")
	for lane in range(25, 37):
		var lane_node = row2.get_node("Lane " + str(lane))
		# Check if this lane has the new VBoxContainer structure
		if lane_node.get_node("Background").has_node("VBoxContainer"):
			var vbox = lane_node.get_node("Background/VBoxContainer")
			press_labels[lane] = vbox.get_node("PressLabel")
			release_labels[lane] = vbox.get_node("ReleaseLabel")
		else:
			# Fallback to old single label structure
			var label = lane_node.get_node("Background/JudgementLabel")
			press_labels[lane] = label
			release_labels[lane] = label
	
	# Row 3: Lanes 13-24
	var row3 = ui_root.get_node("Row 3")
	for lane in range(13, 25):
		var lane_node = row3.get_node("Lane " + str(lane))
		# Check if this lane has the new VBoxContainer structure
		if lane_node.get_node("Background").has_node("VBoxContainer"):
			var vbox = lane_node.get_node("Background/VBoxContainer")
			press_labels[lane] = vbox.get_node("PressLabel")
			release_labels[lane] = vbox.get_node("ReleaseLabel")
		else:
			# Fallback to old single label structure
			var label = lane_node.get_node("Background/JudgementLabel")
			press_labels[lane] = label
			release_labels[lane] = label
	
	# Row 4: Lanes 1-12
	var row4 = ui_root.get_node("Row 4")
	for lane in range(1, 13):
		var lane_node = row4.get_node("Lane " + str(lane))
		# Check if this lane has the new VBoxContainer structure
		if lane_node.get_node("Background").has_node("VBoxContainer"):
			var vbox = lane_node.get_node("Background/VBoxContainer")
			press_labels[lane] = vbox.get_node("PressLabel")
			release_labels[lane] = vbox.get_node("ReleaseLabel")
		else:
			# Fallback to old single label structure
			var label = lane_node.get_node("Background/JudgementLabel")
			press_labels[lane] = label
			release_labels[lane] = label

func _update_active_notes():
	if not midi_spawner or not midi_spawner.midi_loader:
		return
	
	# Get notes in a wider time range to avoid missing notes due to timing precision
	var judgement_window_seconds = judgement_window_ms / 1000.0
	var search_start = current_song_time - judgement_window_seconds - 0.1  # Extra buffer
	var search_end = current_song_time + judgement_window_seconds + 0.1    # Extra buffer
	
	# Use the optimized time range query instead of processing all notes
	var nearby_notes = midi_spawner.midi_loader.get_notes_in_timerange(search_start, search_end)
	
	# Clear current active notes
	for lane in active_notes_by_lane.keys():
		active_notes_by_lane[lane].clear()
	
	for note_data in nearby_notes:
		var lane = note_data["lane"]
		var start_time = note_data["start_time"]
		var end_time = note_data["end_time"]
		
		# Create unique IDs for start and end timing points
		var start_note_id = str(start_time) + "_" + str(lane) + "_start"
		var end_note_id = str(end_time) + "_" + str(lane) + "_end"
		
		# Check if note start time is within judgement window
		var start_diff = start_time - current_song_time
		if abs(start_diff) <= judgement_window_seconds:
			# Add start timing point
			active_notes_by_lane[lane].append({
				"time": start_time,
				"type": "start",
				"note_data": note_data,
				"note_id": start_note_id
			})
			# Mark as previously active so we can detect misses later
			previously_active_notes[start_note_id] = true
		elif start_diff < -judgement_window_seconds and previously_active_notes.has(start_note_id) and not judged_notes.has(start_note_id):
			# Note start was previously in judgement window but has now passed without being hit - it's a miss
			_show_miss(lane, start_note_id)
		
		# Check if note end time is within judgement window
		var end_diff = end_time - current_song_time
		if abs(end_diff) <= judgement_window_seconds:
			# Add end timing point
			active_notes_by_lane[lane].append({
				"time": end_time,
				"type": "end", 
				"note_data": note_data,
				"note_id": end_note_id
			})
			# Mark as previously active so we can detect misses later
			previously_active_notes[end_note_id] = true
		elif end_diff < -judgement_window_seconds and previously_active_notes.has(end_note_id) and not judged_notes.has(end_note_id):
			# Only show miss for note end if the key is not being held down AND there's no active hold note
			# OR if this note end doesn't match the current active hold note
			var should_show_miss = true
			
			if held_keys.has(lane) and active_hold_notes.has(lane):
				# Check if this note end belongs to the currently active hold note
				var active_note = active_hold_notes[lane]
				if active_note["start_time"] == note_data["start_time"] and active_note["end_time"] == note_data["end_time"]:
					# This is the end of the currently held note - don't show miss
					should_show_miss = false
			
			if should_show_miss:
				_show_release_miss(lane, end_note_id)

func _on_key_pressed(lane_number: int):
	# Check if key is already being held down (ignore key repeat)
	if held_keys.has(lane_number):
		return
	
	# Mark key as held down
	held_keys[lane_number] = true
	
	# Find the closest note START timing in this lane
	if not active_notes_by_lane.has(lane_number):
		# Wrong lane pressed - show miss and mark as missed press
		_show_miss(lane_number, "wrong_lane_" + str(current_song_time))
		# Track this as a missed press so we can show release miss later
		active_hold_notes[lane_number] = {"missed_press": true}
		return
	
	var lane_notes = active_notes_by_lane[lane_number]
	if lane_notes.is_empty():
		# No notes in this lane - show miss and mark as missed press
		_show_miss(lane_number, "no_notes_" + str(current_song_time))
		# Track this as a missed press so we can show release miss later
		active_hold_notes[lane_number] = {"missed_press": true}
		return
	
	# Find the closest note START timing point
	var closest_start_note = null
	var closest_time_diff = INF
	
	for note_timing in lane_notes:
		# Only consider note starts for key press events
		if note_timing["type"] == "start":
			var time_diff = abs(note_timing["time"] - current_song_time)
			if time_diff < closest_time_diff:
				closest_time_diff = time_diff
				closest_start_note = note_timing
	
	if closest_start_note == null:
		# No valid start note found - show miss and mark as missed press
		_show_miss(lane_number, "no_start_note_" + str(current_song_time))
		# Track this as a missed press so we can show release miss later
		active_hold_notes[lane_number] = {"missed_press": true}
		return
	
	# Mark this note start as judged to prevent duplicate judgements
	judged_notes[closest_start_note["note_id"]] = true
	
	# Start tracking this hold note
	active_hold_notes[lane_number] = closest_start_note["note_data"]
	
	# Calculate timing difference using PRECISE time in milliseconds
	var precise_input_time_ms = get_precise_song_time() * 1000.0
	var note_time_ms = closest_start_note["time"] * 1000.0
	var timing_diff_ms = round(precise_input_time_ms - note_time_ms)
	
	# Generate judgement text
	var judgement_text = _format_judgement(timing_diff_ms, "↓")
	
	# Update the press judgement label
	if press_labels.has(lane_number):
		press_labels[lane_number].text = judgement_text
		_set_label_color(press_labels[lane_number], timing_diff_ms)
		
		# Add a timer to clear the text after a short delay
		_clear_press_judgement_after_delay(lane_number, 1.0)

func _on_key_released(lane_number: int):
	# Mark key as no longer held down
	held_keys.erase(lane_number)
	
	# Check if there was an active hold note in this lane
	if not active_hold_notes.has(lane_number):
		# No active hold note - this might be a miss or just a tap
		return
	
	var hold_note_data = active_hold_notes[lane_number]
	
	# Check if this was a missed press (wrong lane or no notes)
	if hold_note_data.has("missed_press") and hold_note_data["missed_press"]:
		# This was a missed press, show release miss
		_show_release_miss(lane_number, "missed_press_release_" + str(current_song_time))
		# Remove from active hold notes
		active_hold_notes.erase(lane_number)
		return
	
	# This was a valid note press, handle normal release logic
	var end_time = hold_note_data["end_time"]
	var end_note_id = str(end_time) + "_" + str(lane_number) + "_end"
	
	# Remove from active hold notes
	active_hold_notes.erase(lane_number)
	
	# Mark the end as judged to prevent miss detection
	judged_notes[end_note_id] = true
	
	# Calculate timing difference for the note end using PRECISE time in milliseconds
	var precise_input_time_ms = get_precise_song_time() * 1000.0
	var note_end_time_ms = end_time * 1000.0
	var timing_diff_ms = round(precise_input_time_ms - note_end_time_ms)
	
	# Generate judgement text for the release
	var judgement_text = _format_judgement(timing_diff_ms, "↑")
	
	# Update the release judgement label
	if release_labels.has(lane_number):
		release_labels[lane_number].text = judgement_text
		_set_label_color(release_labels[lane_number], timing_diff_ms)
		
		# Add a timer to clear the text after a short delay
		_clear_release_judgement_after_delay(lane_number, 1.0)

func _format_judgement(timing_diff_ms: float, type: String = "") -> String:
	var abs_diff = abs(timing_diff_ms)
	
	if abs_diff >= judgement_window_ms:
		return "Miss " + type
	
	# Round to nearest millisecond for display (but keep internal precision)
	var rounded_diff = round(timing_diff_ms)
	
	var timing_text = ""
	if rounded_diff == 0:
		timing_text = "0"  # Perfect timing
	elif rounded_diff > 0:
		timing_text = "+" + str(int(rounded_diff))
	else:
		timing_text = str(int(rounded_diff))
	
	# Add type suffix if provided
	if type != "":
		return timing_text + " " + type
	else:
		return timing_text

func _set_label_color(label: Label, timing_diff_ms: float):
	# Set color based on timing accuracy
	var abs_diff = abs(timing_diff_ms)
	
	if abs_diff >= judgement_window_ms:
		# Miss - Red
		label.modulate = Color.RED
	elif abs_diff < 0.05:  # Very close to perfect (within 0.05ms)
		# Perfect timing - Green
		label.modulate = Color.GREEN
	elif timing_diff_ms < 0:
		# Early hit - Magenta
		label.modulate = Color.MAGENTA
	else:
		# Late hit - Orange
		label.modulate = Color.ORANGE

func _show_miss(lane_number: int, note_id: String):
	# Mark this note as judged to prevent duplicate miss messages
	judged_notes[note_id] = true
	
	# Update the press judgement label to show "Miss ↓"
	if press_labels.has(lane_number):
		press_labels[lane_number].text = "Miss ↓"
		press_labels[lane_number].modulate = Color.RED
		
		# Add a timer to clear the text after a short delay
		_clear_press_judgement_after_delay(lane_number, 1.0)

func _show_release_miss(lane_number: int, note_id: String):
	# Mark this note as judged to prevent duplicate miss messages
	judged_notes[note_id] = true
	
	# Update the release judgement label to show "Miss ↑"
	if release_labels.has(lane_number):
		release_labels[lane_number].text = "Miss ↑"
		release_labels[lane_number].modulate = Color.RED
		
		# Add a timer to clear the text after a short delay
		_clear_release_judgement_after_delay(lane_number, 1.0)

func _clear_press_judgement_after_delay(lane_number: int, delay: float):
	# Create a timer to clear the press judgement text
	var timer = Timer.new()
	timer.wait_time = delay
	timer.one_shot = true
	add_child(timer)
	
	timer.timeout.connect(func():
		if press_labels.has(lane_number):
			press_labels[lane_number].text = ""
			press_labels[lane_number].modulate = Color.WHITE  # Reset color
		timer.queue_free()
	)
	
	timer.start()

func _clear_release_judgement_after_delay(lane_number: int, delay: float):
	# Create a timer to clear the release judgement text
	var timer = Timer.new()
	timer.wait_time = delay
	timer.one_shot = true
	add_child(timer)
	
	timer.timeout.connect(func():
		if release_labels.has(lane_number):
			release_labels[lane_number].text = ""
			release_labels[lane_number].modulate = Color.WHITE  # Reset color
		timer.queue_free()
	)
	
	timer.start()
