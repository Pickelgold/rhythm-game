extends Control

# UI Element References
@onready var background_image: TextureRect = $BackgroundImage
@onready var accuracy_value: Label = $Panel/VBoxContainer/StatsContainer/AccuracyContainer/AccuracyValue
@onready var score_value: Label = $Panel/VBoxContainer/StatsContainer/ScoreContainer/ScoreValue
@onready var combo_value: Label = $Panel/VBoxContainer/StatsContainer/ComboContainer/ComboValue
@onready var perfect_value: Label = $Panel/VBoxContainer/JudgementContainer/JudgementGrid/PerfectValue
@onready var great_value: Label = $Panel/VBoxContainer/JudgementContainer/JudgementGrid/GreatValue
@onready var good_value: Label = $Panel/VBoxContainer/JudgementContainer/JudgementGrid/GoodValue
@onready var miss_value: Label = $Panel/VBoxContainer/JudgementContainer/JudgementGrid/MissValue
@onready var retry_button: Button = $Panel/VBoxContainer/ButtonContainer/RetryButton
@onready var song_select_button: Button = $Panel/VBoxContainer/ButtonContainer/SongSelectButton

func _ready():
	# Load background image from GameGlobals
	_load_background_image()
	
	# Load and display results data from GameGlobals
	_display_results_from_globals()
	
	# Connect button signals
	retry_button.pressed.connect(_on_retry_button_pressed)
	song_select_button.pressed.connect(_on_song_select_button_pressed)
	
	print("Results screen loaded with data from GameGlobals")

func _load_background_image():
	# Load background image if path is available
	var background_path = GameGlobals.current_background_path
	if background_path != "" and FileAccess.file_exists(background_path):
		var texture = ImageTexture.new()
		var image = Image.new()
		var error = image.load(background_path)
		if error == OK:
			texture.set_image(image)
			background_image.texture = texture
			print("Background image loaded: ", background_path)
		else:
			print("Failed to load background image: ", background_path)
	else:
		print("No background image path available")

func _display_results_from_globals():
	# Get results data from GameGlobals
	var results_data = GameGlobals.last_results_data
	
	if results_data.is_empty():
		print("Warning: No results data found in GameGlobals")
		return
	
	# Display the results
	display_results(results_data)

func display_results(data: Dictionary):
	# Update accuracy
	var accuracy = data.get("accuracy", 0.0)
	accuracy_value.text = "%.2f%%" % accuracy
	
	# Update score
	var score = data.get("score", 0)
	score_value.text = str(score)
	
	# Update max combo
	var max_combo = data.get("max_combo", 0)
	combo_value.text = str(max_combo)
	
	# Update judgement counts
	var judgement_counts = data.get("judgement_counts", {})
	perfect_value.text = str(judgement_counts.get("perfect", 0))
	great_value.text = str(judgement_counts.get("great", 0))
	good_value.text = str(judgement_counts.get("good", 0))
	miss_value.text = str(judgement_counts.get("miss", 0))
	
	print("Results displayed: Accuracy=", accuracy, "%, Score=", score, ", Max Combo=", max_combo)

func _on_retry_button_pressed():
	print("Retry button pressed")
	
	# Stop background music using AudioManager
	AudioManager.stop_background_music()
	
	# Reload the gameplay scene
	get_tree().change_scene_to_file("res://scenes/gameplay.tscn")

func _on_song_select_button_pressed():
	print("Song Select button pressed")
	
	# Stop background music using AudioManager
	AudioManager.stop_background_music()
	
	# Clear the current beatmap config and results data
	GameGlobals.reset_beatmap_config()
	
	# Go back to song select
	get_tree().change_scene_to_file("res://scenes/song_select.tscn")
