extends Control
class_name BeatmapCard

# Signal emitted when this card is selected
signal card_selected(beatmap_data: Dictionary)

# References to UI elements
@onready var jacket_texture: TextureRect = $CardMargin/VBoxContainer/JacketContainer/Jacket
@onready var title_label: Label = $CardMargin/VBoxContainer/InfoContainer/Title
@onready var artist_label: Label = $CardMargin/VBoxContainer/InfoContainer/Artist
@onready var background: ColorRect = $Background
@onready var button: Button = $Button

# Beatmap data
var beatmap_data: Dictionary = {}
var is_selected: bool = false

# Colors for different states
var normal_color = Color(0.2, 0.2, 0.2, 1.0)
var hover_color = Color(0.3, 0.3, 0.3, 1.0)
var selected_color = Color(0.4, 0.6, 0.8, 1.0)

func _ready():
	# Connect button signals
	button.pressed.connect(_on_button_pressed)
	button.mouse_entered.connect(_on_mouse_entered)
	button.mouse_exited.connect(_on_mouse_exited)
	
	# Set initial appearance
	_update_appearance()

# Set the beatmap data for this card
func setup_beatmap(data: Dictionary):
	beatmap_data = data
	
	# Update labels using get_node to avoid @onready timing issues
	if data.has("title"):
		get_node("CardMargin/VBoxContainer/InfoContainer/Title").text = data["title"]
	if data.has("artist"):
		get_node("CardMargin/VBoxContainer/InfoContainer/Artist").text = data["artist"]
	
	# Load jacket image
	if data.has("jacket_path"):
		_load_jacket_image(data["jacket_path"])

# Load the jacket image from file path
func _load_jacket_image(image_path: String):
	if FileAccess.file_exists(image_path):
		var texture = ImageTexture.new()
		var image = Image.new()
		var error = image.load(image_path)
		
		if error == OK:
			texture.set_image(image)
			get_node("CardMargin/VBoxContainer/JacketContainer/Jacket").texture = texture
		else:
			print("Failed to load jacket image: ", image_path)
	else:
		print("Jacket image not found: ", image_path)

# Handle button press
func _on_button_pressed():
	card_selected.emit(beatmap_data)

# Handle mouse hover
func _on_mouse_entered():
	if not is_selected:
		background.color = hover_color

func _on_mouse_exited():
	if not is_selected:
		background.color = normal_color

# Set selection state
func set_selected(selected: bool):
	is_selected = selected
	_update_appearance()

# Update visual appearance based on state
func _update_appearance():
	if is_selected:
		background.color = selected_color
	else:
		background.color = normal_color
