extends Control

# Signal emitted when a key is pressed with the corresponding lane number
signal key_pressed(lane_number: int)

# Dictionary to map keys to their ColorRect nodes
var key_map = {}

# Dictionary to map keys to their lane numbers
var key_to_lane_map = {}

# Original colors
var normal_color = Color(0.164706, 0.164706, 0.164706, 1)  # Dark gray for standard keys
var modifier_color = Color(0.101961, 0.101961, 0.101961, 1)  # Darker gray for modifiers
var pressed_color = Color(0.4, 0.4, 0.4, 1)  # Lighter gray when pressed

func _ready():
	# Build the key mapping
	setup_key_mapping()

func setup_key_mapping():
	# Row 1 keys (Lane 37-49)
	var row1 = $"../UI/MarginContainer/AspectRatioContainer/VBoxContainer/Row 1"
	key_map[KEY_QUOTELEFT] = row1.get_node("Lane 37/Receptor")  # `
	key_to_lane_map[KEY_QUOTELEFT] = 37
	key_map[KEY_1] = row1.get_node("Lane 38/Receptor")
	key_to_lane_map[KEY_1] = 38
	key_map[KEY_2] = row1.get_node("Lane 39/Receptor")
	key_to_lane_map[KEY_2] = 39
	key_map[KEY_3] = row1.get_node("Lane 40/Receptor")
	key_to_lane_map[KEY_3] = 40
	key_map[KEY_4] = row1.get_node("Lane 41/Receptor")
	key_to_lane_map[KEY_4] = 41
	key_map[KEY_5] = row1.get_node("Lane 42/Receptor")
	key_to_lane_map[KEY_5] = 42
	key_map[KEY_6] = row1.get_node("Lane 43/Receptor")
	key_to_lane_map[KEY_6] = 43
	key_map[KEY_7] = row1.get_node("Lane 44/Receptor")
	key_to_lane_map[KEY_7] = 44
	key_map[KEY_8] = row1.get_node("Lane 45/Receptor")
	key_to_lane_map[KEY_8] = 45
	key_map[KEY_9] = row1.get_node("Lane 46/Receptor")
	key_to_lane_map[KEY_9] = 46
	key_map[KEY_0] = row1.get_node("Lane 47/Receptor")
	key_to_lane_map[KEY_0] = 47
	key_map[KEY_MINUS] = row1.get_node("Lane 48/Receptor")
	key_to_lane_map[KEY_MINUS] = 48
	key_map[KEY_EQUAL] = row1.get_node("Lane 49/Receptor")
	key_to_lane_map[KEY_EQUAL] = 49
	
	# Row 2 keys (Lane 25-36)
	var row2 = $"../UI/MarginContainer/AspectRatioContainer/VBoxContainer/Row 2"
	key_map[KEY_TAB] = row2.get_node("Lane 25/Receptor")
	key_to_lane_map[KEY_TAB] = 25
	key_map[KEY_Q] = row2.get_node("Lane 26/Receptor")
	key_to_lane_map[KEY_Q] = 26
	key_map[KEY_W] = row2.get_node("Lane 27/Receptor")
	key_to_lane_map[KEY_W] = 27
	key_map[KEY_E] = row2.get_node("Lane 28/Receptor")
	key_to_lane_map[KEY_E] = 28
	key_map[KEY_R] = row2.get_node("Lane 29/Receptor")
	key_to_lane_map[KEY_R] = 29
	key_map[KEY_T] = row2.get_node("Lane 30/Receptor")
	key_to_lane_map[KEY_T] = 30
	key_map[KEY_Y] = row2.get_node("Lane 31/Receptor")
	key_to_lane_map[KEY_Y] = 31
	key_map[KEY_U] = row2.get_node("Lane 32/Receptor")
	key_to_lane_map[KEY_U] = 32
	key_map[KEY_I] = row2.get_node("Lane 33/Receptor")
	key_to_lane_map[KEY_I] = 33
	key_map[KEY_O] = row2.get_node("Lane 34/Receptor")
	key_to_lane_map[KEY_O] = 34
	key_map[KEY_P] = row2.get_node("Lane 35/Receptor")
	key_to_lane_map[KEY_P] = 35
	key_map[KEY_BRACKETLEFT] = row2.get_node("Lane 36/Receptor")
	key_to_lane_map[KEY_BRACKETLEFT] = 36
	
	# Row 3 keys (Lane 13-24)
	var row3 = $"../UI/MarginContainer/AspectRatioContainer/VBoxContainer/Row 3"
	key_map[KEY_CAPSLOCK] = row3.get_node("Lane 13/Receptor")
	key_to_lane_map[KEY_CAPSLOCK] = 13
	key_map[KEY_A] = row3.get_node("Lane 14/Receptor")
	key_to_lane_map[KEY_A] = 14
	key_map[KEY_S] = row3.get_node("Lane 15/Receptor")
	key_to_lane_map[KEY_S] = 15
	key_map[KEY_D] = row3.get_node("Lane 16/Receptor")
	key_to_lane_map[KEY_D] = 16
	key_map[KEY_F] = row3.get_node("Lane 17/Receptor")
	key_to_lane_map[KEY_F] = 17
	key_map[KEY_G] = row3.get_node("Lane 18/Receptor")
	key_to_lane_map[KEY_G] = 18
	key_map[KEY_H] = row3.get_node("Lane 19/Receptor")
	key_to_lane_map[KEY_H] = 19
	key_map[KEY_J] = row3.get_node("Lane 20/Receptor")
	key_to_lane_map[KEY_J] = 20
	key_map[KEY_K] = row3.get_node("Lane 21/Receptor")
	key_to_lane_map[KEY_K] = 21
	key_map[KEY_L] = row3.get_node("Lane 22/Receptor")
	key_to_lane_map[KEY_L] = 22
	key_map[KEY_SEMICOLON] = row3.get_node("Lane 23/Receptor")
	key_to_lane_map[KEY_SEMICOLON] = 23
	key_map[KEY_APOSTROPHE] = row3.get_node("Lane 24/Receptor")
	key_to_lane_map[KEY_APOSTROPHE] = 24
	
	# Row 4 keys (Lane 1-12)
	var row4 = $"../UI/MarginContainer/AspectRatioContainer/VBoxContainer/Row 4"
	# Store both shift keys with location info
	key_map["LSHIFT"] = row4.get_node("Lane 1/Receptor")  # Left Shift
	key_to_lane_map["LSHIFT"] = 1
	key_map["RSHIFT"] = row4.get_node("Lane 12/Receptor")  # Right Shift
	key_to_lane_map["RSHIFT"] = 12
	key_map[KEY_Z] = row4.get_node("Lane 2/Receptor")
	key_to_lane_map[KEY_Z] = 2
	key_map[KEY_X] = row4.get_node("Lane 3/Receptor")
	key_to_lane_map[KEY_X] = 3
	key_map[KEY_C] = row4.get_node("Lane 4/Receptor")
	key_to_lane_map[KEY_C] = 4
	key_map[KEY_V] = row4.get_node("Lane 5/Receptor")
	key_to_lane_map[KEY_V] = 5
	key_map[KEY_B] = row4.get_node("Lane 6/Receptor")
	key_to_lane_map[KEY_B] = 6
	key_map[KEY_N] = row4.get_node("Lane 7/Receptor")
	key_to_lane_map[KEY_N] = 7
	key_map[KEY_M] = row4.get_node("Lane 8/Receptor")
	key_to_lane_map[KEY_M] = 8
	key_map[KEY_COMMA] = row4.get_node("Lane 9/Receptor")
	key_to_lane_map[KEY_COMMA] = 9
	key_map[KEY_PERIOD] = row4.get_node("Lane 10/Receptor")
	key_to_lane_map[KEY_PERIOD] = 10
	key_map[KEY_SLASH] = row4.get_node("Lane 11/Receptor")
	key_to_lane_map[KEY_SLASH] = 11

func _input(event):
	if event is InputEventKey:
		var key_code = event.keycode
		var key_rect = null
		var lane_number = -1
		
		# Handle shift keys separately using location
		if key_code == KEY_SHIFT:
			if event.location == KEY_LOCATION_LEFT:
				key_rect = key_map["LSHIFT"]
				lane_number = key_to_lane_map["LSHIFT"]
			elif event.location == KEY_LOCATION_RIGHT:
				key_rect = key_map["RSHIFT"]
				lane_number = key_to_lane_map["RSHIFT"]
		else:
			# Handle all other keys normally
			if key_map.has(key_code):
				key_rect = key_map[key_code]
				lane_number = key_to_lane_map[key_code]
		
		if key_rect != null:
			if event.pressed:
				# Key pressed - change to lighter color
				key_rect.color = pressed_color
				
				# Emit signal for judgement system
				if lane_number != -1:
					key_pressed.emit(lane_number)
			else:
				# Key released - restore original color
				restore_original_color(key_rect)

func restore_original_color(key_rect):
	# All keys use the same normal color
	key_rect.color = normal_color
