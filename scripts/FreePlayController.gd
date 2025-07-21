##
## Free Play Controller for Rhythm Game
## Provides 48-key piano-style input using computer keyboard
##

extends Node
class_name FreePlayController

## Reference to the MIDI player
@export var midi_player: MidiPlayer
## Base MIDI note (C2 = 36 by default, configurable per chart)
@export var base_note: int = 36
## Velocity for all notes
@export var velocity: int = 100
## MIDI channel to use
@export var channel: int = 0

## Maps keyboard keys to note offsets (0-48) - 49 keys total for 4 full octaves
var key_map: Dictionary = {}
## Tracks currently pressed keys to prevent retriggering
var pressed_keys: Dictionary = {}

func _ready():
	_setup_key_map()
	print("FreePlayController initialized with base note: %d (MIDI note %d)" % [base_note, base_note])

## Set up the keyboard to MIDI note mapping
## Layout: Bottom-left (LShift) = lowest note (C2), Top-right (-) = highest note
func _setup_key_map():
	# Row 4 (bottom): LShift Z X C V B N M , . / RShift (12 keys) - LOWEST notes
	# Using special keys for left/right shift based on location
	key_map["lshift"] = 0   # LShift - C2 (lowest note)
	key_map[KEY_Z] = 1
	key_map[KEY_X] = 2
	key_map[KEY_C] = 3
	key_map[KEY_V] = 4
	key_map[KEY_B] = 5
	key_map[KEY_N] = 6
	key_map[KEY_M] = 7
	key_map[KEY_COMMA] = 8
	key_map[KEY_PERIOD] = 9
	key_map[KEY_SLASH] = 10
	key_map["rshift"] = 11  # RShift
	
	# Row 3: Caps A S D F G H J K L ; ' (12 keys)
	key_map[KEY_CAPSLOCK] = 12
	key_map[KEY_A] = 13
	key_map[KEY_S] = 14
	key_map[KEY_D] = 15
	key_map[KEY_F] = 16
	key_map[KEY_G] = 17
	key_map[KEY_H] = 18
	key_map[KEY_J] = 19
	key_map[KEY_K] = 20
	key_map[KEY_L] = 21
	key_map[KEY_SEMICOLON] = 22
	key_map[KEY_APOSTROPHE] = 23
	
	# Row 2: Tab Q W E R T Y U I O P [ (12 keys)
	key_map[KEY_TAB] = 24
	key_map[KEY_Q] = 25
	key_map[KEY_W] = 26
	key_map[KEY_E] = 27
	key_map[KEY_R] = 28
	key_map[KEY_T] = 29
	key_map[KEY_Y] = 30
	key_map[KEY_U] = 31
	key_map[KEY_I] = 32
	key_map[KEY_O] = 33
	key_map[KEY_P] = 34
	key_map[KEY_BRACKETLEFT] = 35
	
	# Row 1 (top): ` 1 2 3 4 5 6 7 8 9 0 - = (13 keys) - HIGHEST notes
	key_map[KEY_QUOTELEFT] = 36   # `
	key_map[KEY_1] = 37
	key_map[KEY_2] = 38
	key_map[KEY_3] = 39
	key_map[KEY_4] = 40
	key_map[KEY_5] = 41
	key_map[KEY_6] = 42
	key_map[KEY_7] = 43
	key_map[KEY_8] = 44
	key_map[KEY_9] = 45
	key_map[KEY_0] = 46
	key_map[KEY_MINUS] = 47
	key_map[KEY_EQUAL] = 48  # = (C6 - highest note, completes 4 full octaves)

## Handle keyboard input
func _unhandled_input(event: InputEvent):
	if not midi_player:
		return
		
	if event is InputEventKey:
		var key_code = event.keycode
		var lookup_key = key_code
		
		# Handle shift keys using location to distinguish left/right
		if key_code == KEY_SHIFT:
			if event.location == KEY_LOCATION_LEFT:
				lookup_key = "lshift"
			elif event.location == KEY_LOCATION_RIGHT:
				lookup_key = "rshift"
			else:
				# Fallback if location is not detected
				lookup_key = "lshift"
		
		if lookup_key in key_map:
			var note_offset = key_map[lookup_key]
			var midi_note = base_note + note_offset
			
			if event.pressed and not event.echo:
				# Key pressed - start note if not already playing
				if lookup_key not in pressed_keys:
					pressed_keys[lookup_key] = midi_note
					midi_player.play_note_direct(midi_note, velocity, channel)
					
			elif not event.pressed:
				# Key released - stop note if it was playing
				if lookup_key in pressed_keys:
					var playing_note = pressed_keys[lookup_key]
					pressed_keys.erase(lookup_key)
					midi_player.stop_note_direct(playing_note, channel)

## Set the base note (useful for changing octave range per chart)
func set_base_note(new_base_note: int):
	# Stop all currently playing notes before changing base note
	_stop_all_notes()
	base_note = new_base_note
	print("Base note changed to: %d (MIDI note %d)" % [base_note, base_note])

## Stop all currently playing notes
func _stop_all_notes():
	for key_code in pressed_keys.keys():
		var midi_note = pressed_keys[key_code]
		midi_player.stop_note_direct(midi_note, channel)
	pressed_keys.clear()

## Get the current note range as a string (for debugging/UI)
func get_note_range_string() -> String:
	var note_names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
	var start_octave = (base_note - 12) / 12  # MIDI note 12 = C0
	var start_note_name = note_names[base_note % 12]
	var end_note = base_note + 48  # 49 keys total (0-48)
	var end_octave = (end_note - 12) / 12
	var end_note_name = note_names[end_note % 12]
	
	return "%s%d - %s%d" % [start_note_name, start_octave, end_note_name, end_octave]
