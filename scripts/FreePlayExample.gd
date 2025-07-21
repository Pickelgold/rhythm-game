##
## Example script showing how to use the FreePlayController
## This can be attached to any node to demonstrate the free play functionality
##

extends Node

@export var free_play_controller: FreePlayController

func _ready():
	if free_play_controller:
		print("Free Play Example initialized!")
		print("Current note range: %s" % free_play_controller.get_note_range_string())
		print("Press keys to play notes:")
		print("Row 1: ` 1 2 3 4 5 6 7 8 9 0 - =")
		print("Row 2: Tab Q W E R T Y U I O P [")
		print("Row 3: Caps A S D F G H J K L ; '")
		print("Row 4: Shift Z X C V B N M , . /")
		print("")
		print("You can change the base note with:")
		print("free_play_controller.set_base_note(48)  # C3")
		print("free_play_controller.set_base_note(60)  # C4")

## Example function to change octave programmatically
func set_octave_c3():
	if free_play_controller:
		free_play_controller.set_base_note(48)  # C3

func set_octave_c4():
	if free_play_controller:
		free_play_controller.set_base_note(60)  # C4

func set_octave_c2():
	if free_play_controller:
		free_play_controller.set_base_note(36)  # C2 (default)
