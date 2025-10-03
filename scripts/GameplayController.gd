extends Node

# This script should be attached to the root node of the gameplay scene
# to initialize the MidiPlayer with the correct user data paths

@onready var midi_player: MidiPlayer

func _ready():
	# Find the MidiPlayer node in the scene
	midi_player = find_child("MidiPlayer")
	
	if midi_player == null:
		print("Warning: MidiPlayer not found in gameplay scene")
		return
	
	# Set the soundfont path to the user data directory
	var soundfont_path = UserDataManager.get_default_soundfont()
	if soundfont_path != "":
		print("Setting soundfont to: ", soundfont_path)
		midi_player.set_soundfont(soundfont_path)
	else:
		print("Warning: No soundfont found in user data directory")

# Helper function to find a node recursively
func find_child(node_name: String) -> Node:
	return _find_child_recursive(self, node_name)

func _find_child_recursive(node: Node, target_name: String) -> Node:
	for child in node.get_children():
		if child.name == target_name:
			return child
		var found = _find_child_recursive(child, target_name)
		if found:
			return found
	return null
