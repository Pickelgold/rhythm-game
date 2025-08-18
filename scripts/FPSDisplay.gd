extends Node
class_name FPSDisplay

# Reference to the FPS label
var fps_label: Label

func _ready():
	# Wait for scene to be fully loaded
	await get_tree().process_frame
	
	# Get reference to the FPS label
	fps_label = get_node("../UI/HBoxContainer/RightUI/VBoxContainer/SongProgress/FPSLabel")

func _process(delta):
	if fps_label:
		# Calculate instantaneous FPS from delta time
		var fps = 1.0 / delta
		# Display as integer for cleaner look
		fps_label.text = str(int(fps)) + " FPS"
