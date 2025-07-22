extends Control

# Dictionary to map keys to their ColorRect nodes
var key_map = {}

# Original colors
var normal_color = Color(0.164706, 0.164706, 0.164706, 1)  # Dark gray for standard keys
var modifier_color = Color(0.101961, 0.101961, 0.101961, 1)  # Darker gray for modifiers
var pressed_color = Color(0.4, 0.4, 0.4, 1)  # Lighter gray when pressed

func _ready():
	# Build the key mapping
	setup_key_mapping()

func setup_key_mapping():
	# Row 1 keys
	var row1 = $"../UI/MarginContainer/AspectRatioContainer/VBoxContainer/Row 1"
	key_map[KEY_QUOTELEFT] = row1.get_node("ColorRect")  # `
	key_map[KEY_1] = row1.get_node("ColorRect2")
	key_map[KEY_2] = row1.get_node("ColorRect3")
	key_map[KEY_3] = row1.get_node("ColorRect4")
	key_map[KEY_4] = row1.get_node("ColorRect5")
	key_map[KEY_5] = row1.get_node("ColorRect6")
	key_map[KEY_6] = row1.get_node("ColorRect7")
	key_map[KEY_7] = row1.get_node("ColorRect8")
	key_map[KEY_8] = row1.get_node("ColorRect9")
	key_map[KEY_9] = row1.get_node("ColorRect10")
	key_map[KEY_0] = row1.get_node("ColorRect11")
	key_map[KEY_MINUS] = row1.get_node("ColorRect12")
	key_map[KEY_EQUAL] = row1.get_node("ColorRect13")
	
	# Row 2 keys
	var row2 = $"../UI/MarginContainer/AspectRatioContainer/VBoxContainer/Row 2"
	key_map[KEY_TAB] = row2.get_node("ColorRect")
	key_map[KEY_Q] = row2.get_node("ColorRect2")
	key_map[KEY_W] = row2.get_node("ColorRect3")
	key_map[KEY_E] = row2.get_node("ColorRect4")
	key_map[KEY_R] = row2.get_node("ColorRect5")
	key_map[KEY_T] = row2.get_node("ColorRect6")
	key_map[KEY_Y] = row2.get_node("ColorRect7")
	key_map[KEY_U] = row2.get_node("ColorRect8")
	key_map[KEY_I] = row2.get_node("ColorRect9")
	key_map[KEY_O] = row2.get_node("ColorRect10")
	key_map[KEY_P] = row2.get_node("ColorRect11")
	key_map[KEY_BRACKETLEFT] = row2.get_node("ColorRect12")
	
	# Row 3 keys
	var row3 = $"../UI/MarginContainer/AspectRatioContainer/VBoxContainer/Row 3"
	key_map[KEY_CAPSLOCK] = row3.get_node("ColorRect")
	key_map[KEY_A] = row3.get_node("ColorRect2")
	key_map[KEY_S] = row3.get_node("ColorRect3")
	key_map[KEY_D] = row3.get_node("ColorRect4")
	key_map[KEY_F] = row3.get_node("ColorRect5")
	key_map[KEY_G] = row3.get_node("ColorRect6")
	key_map[KEY_H] = row3.get_node("ColorRect7")
	key_map[KEY_J] = row3.get_node("ColorRect8")
	key_map[KEY_K] = row3.get_node("ColorRect9")
	key_map[KEY_L] = row3.get_node("ColorRect10")
	key_map[KEY_SEMICOLON] = row3.get_node("ColorRect11")
	key_map[KEY_APOSTROPHE] = row3.get_node("ColorRect12")
	
	# Row 4 keys
	var row4 = $"../UI/MarginContainer/AspectRatioContainer/VBoxContainer/Row 4"
	# Store both shift keys with location info
	key_map["LSHIFT"] = row4.get_node("ColorRect")  # Left Shift
	key_map["RSHIFT"] = row4.get_node("ColorRect12")  # Right Shift
	key_map[KEY_Z] = row4.get_node("ColorRect2")
	key_map[KEY_X] = row4.get_node("ColorRect3")
	key_map[KEY_C] = row4.get_node("ColorRect4")
	key_map[KEY_V] = row4.get_node("ColorRect5")
	key_map[KEY_B] = row4.get_node("ColorRect6")
	key_map[KEY_N] = row4.get_node("ColorRect7")
	key_map[KEY_M] = row4.get_node("ColorRect8")
	key_map[KEY_COMMA] = row4.get_node("ColorRect9")
	key_map[KEY_PERIOD] = row4.get_node("ColorRect10")
	key_map[KEY_SLASH] = row4.get_node("ColorRect11")

func _input(event):
	if event is InputEventKey:
		var key_code = event.keycode
		var key_rect = null
		
		# Handle shift keys separately using location
		if key_code == KEY_SHIFT:
			if event.location == KEY_LOCATION_LEFT:
				key_rect = key_map["LSHIFT"]
			elif event.location == KEY_LOCATION_RIGHT:
				key_rect = key_map["RSHIFT"]
		else:
			# Handle all other keys normally
			if key_map.has(key_code):
				key_rect = key_map[key_code]
		
		if key_rect != null:
			if event.pressed:
				# Key pressed - change to lighter color
				key_rect.color = pressed_color
			else:
				# Key released - restore original color
				restore_original_color(key_rect)

func restore_original_color(key_rect):
	# All keys use the same normal color
	key_rect.color = normal_color
