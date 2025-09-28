extends Node
class_name SongProgressManager

# References to other systems
var midi_spawner: Node
var time_label: Label

func _ready():
	# Wait for scene to be fully loaded
	await get_tree().process_frame
	
	# Get references to other systems
	midi_spawner = get_node("../MIDISpawner")
	
	# Get reference to the time label
	time_label = get_node("../UI/HBoxContainer/RightUI/VBoxContainer/SongProgress/Time")

func _process(delta):
	if not midi_spawner or not midi_spawner.midi_loader or not time_label:
		return
	
	# Get current time and total duration
	var current_time = max(0.0, midi_spawner.current_song_time)  # Don't show negative time
	var total_duration = midi_spawner.midi_loader.get_total_duration()
	
	# Format and update the display
	var current_formatted = format_time(current_time)
	var total_formatted = format_time(total_duration)
	
	time_label.text = current_formatted + " /\n" + total_formatted

# Convert seconds to MM:SS format
func format_time(seconds: float) -> String:
	var total_seconds = int(seconds)
	var minutes = total_seconds / 60
	var remaining_seconds = total_seconds % 60
	
	return "%02d:%02d" % [minutes, remaining_seconds]
