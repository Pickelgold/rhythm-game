extends Control
class_name SongSelect

# References to UI elements
@onready var grid_container: GridContainer = $MarginContainer/HBoxContainer/ScrollContainer/GridContainer
@onready var selected_song_panel: PanelContainer = $MarginContainer/HBoxContainer/SelectedSong

# Beatmap data
var beatmaps: Array[Dictionary] = []
var selected_beatmap: Dictionary = {}
var beatmap_cards: Array[BeatmapCard] = []

# Preload the BeatmapCard scene
var beatmap_card_scene = preload("res://scenes/BeatmapCard.tscn")

func _ready():
	# Load all beatmaps
	_scan_beatmaps()
	
	# Populate the grid with beatmap cards
	_populate_beatmap_grid()

# Scan the beatmaps directory for all available beatmaps
func _scan_beatmaps():
	beatmaps.clear()
	var beatmaps_dir = UserDataManager.get_beatmaps_path()
	
	var dir = DirAccess.open(beatmaps_dir)
	if dir == null:
		print("Failed to open beatmaps directory: ", beatmaps_dir)
		return
	
	dir.list_dir_begin()
	var folder_name = dir.get_next()
	
	while folder_name != "":
		# Skip files, only process directories
		if dir.current_is_dir() and not folder_name.begins_with("."):
			var beatmap_path = beatmaps_dir + folder_name + "/"
			var beatmap_data = _load_beatmap_metadata(beatmap_path)
			
			if not beatmap_data.is_empty():
				beatmaps.append(beatmap_data)
				print("Loaded beatmap: ", beatmap_data.get("title", "Unknown"))
		
		folder_name = dir.get_next()
	
	dir.list_dir_end()
	
	print("Found ", beatmaps.size(), " beatmaps")

# Load metadata for a single beatmap
func _load_beatmap_metadata(beatmap_path: String) -> Dictionary:
	var metadata_file = beatmap_path + "metadata.json"
	
	if not FileAccess.file_exists(metadata_file):
		print("No metadata.json found in: ", beatmap_path)
		return {}
	
	var file = FileAccess.open(metadata_file, FileAccess.READ)
	if file == null:
		print("Failed to open metadata file: ", metadata_file)
		return {}
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		print("Failed to parse JSON in: ", metadata_file)
		return {}
	
	var metadata = json.data
	if not metadata is Dictionary:
		print("Invalid metadata format in: ", metadata_file)
		return {}
	
	# Add full path information to the metadata
	var result = metadata.duplicate()
	result["beatmap_path"] = beatmap_path
	
	# Build full paths for assets
	if result.has("jacket"):
		result["jacket_path"] = beatmap_path + result["jacket"]
	
	if result.has("background"):
		result["background_path"] = beatmap_path + result["background"]
	
	# Process difficulties to add full paths
	if result.has("difficulties") and result["difficulties"] is Array:
		for difficulty in result["difficulties"]:
			if difficulty.has("beatmap"):
				difficulty["chart_path"] = beatmap_path + difficulty["beatmap"]
	
	return result

# Populate the grid container with beatmap cards
func _populate_beatmap_grid():
	# Clear existing cards
	_clear_beatmap_cards()
	
	# Create cards for each beatmap
	for beatmap_data in beatmaps:
		var card = beatmap_card_scene.instantiate()
		
		# Setup the card with beatmap data
		card.setup_beatmap(beatmap_data)
		
		# Connect selection signal
		card.card_selected.connect(_on_beatmap_selected)
		
		# Add to grid
		grid_container.add_child(card)
		beatmap_cards.append(card)

# Clear all beatmap cards from the grid
func _clear_beatmap_cards():
	for card in beatmap_cards:
		if card and is_instance_valid(card):
			card.queue_free()
	
	beatmap_cards.clear()
	
	# Also clear any remaining children from grid
	for child in grid_container.get_children():
		child.queue_free()

# Handle beatmap selection
func _on_beatmap_selected(beatmap_data: Dictionary):
	# Update selected beatmap
	selected_beatmap = beatmap_data
	
	# Update visual selection state
	for card in beatmap_cards:
		card.set_selected(card.beatmap_data == beatmap_data)
	
	# Update selected song panel (placeholder for now)
	_update_selected_song_panel()
	
	print("Selected beatmap: ", beatmap_data.get("title", "Unknown"))

# Update the selected song panel with current selection
func _update_selected_song_panel():
	if selected_beatmap.is_empty():
		return
	
	# Create/update UI elements for the selected song panel
	var vbox = selected_song_panel.get_node("VBoxContainer")
	
	# Clear existing children
	for child in vbox.get_children():
		child.queue_free()
	
	# Create a container for the info content (takes remaining space)
	var info_container = VBoxContainer.new()
	info_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(info_container)
	
	# Add background image if available
	if selected_beatmap.has("background_path"):
		var background_rect = TextureRect.new()
		background_rect.custom_minimum_size = Vector2(300, 200)
		background_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		background_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_load_background_image(background_rect, selected_beatmap["background_path"])
		info_container.add_child(background_rect)
	
	# Add title
	var title_label = Label.new()
	title_label.text = selected_beatmap.get("title", "Unknown Title")
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_container.add_child(title_label)
	
	# Add artist
	var artist_label = Label.new()
	artist_label.text = "by " + selected_beatmap.get("artist", "Unknown Artist")
	artist_label.add_theme_font_size_override("font_size", 16)
	artist_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	artist_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_container.add_child(artist_label)
	
	# Add BPM and mapper info
	var info_label = Label.new()
	var bpm = selected_beatmap.get("bpm", "Unknown")
	var mapper = selected_beatmap.get("mapper", "Unknown")
	info_label.text = "BPM: " + str(bpm) + "\nMapped by: " + mapper
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_container.add_child(info_label)
	
	# Add difficulties
	if selected_beatmap.has("difficulties"):
		var diff_label = Label.new()
		diff_label.text = "Difficulties:"
		diff_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		diff_label.add_theme_font_size_override("font_size", 14)
		info_container.add_child(diff_label)
		
		for diff in selected_beatmap["difficulties"]:
			var diff_info = Label.new()
			var star_rating = diff.get("starRating", 0)
			diff_info.text = "• " + diff.get("name", "Unknown") + " (★" + str(star_rating) + ")"
			diff_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			info_container.add_child(diff_info)
	
	# Add play button (anchored to bottom, full width)
	var play_button = Button.new()
	play_button.text = "PLAY"
	play_button.custom_minimum_size = Vector2(0, 60)
	play_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play_button.size_flags_vertical = Control.SIZE_SHRINK_END
	play_button.add_theme_font_size_override("font_size", 20)
	play_button.pressed.connect(_on_play_button_pressed)
	vbox.add_child(play_button)
	
	print("Selected beatmap: ", selected_beatmap.get("title", "Unknown"))

# Load background image for selected song panel
func _load_background_image(texture_rect: TextureRect, image_path: String):
	if FileAccess.file_exists(image_path):
		var texture = ImageTexture.new()
		var image = Image.new()
		var error = image.load(image_path)
		
		if error == OK:
			texture.set_image(image)
			texture_rect.texture = texture
		else:
			print("Failed to load background image: ", image_path)
	else:
		print("Background image not found: ", image_path)

# Handle play button press - transition to gameplay
func _on_play_button_pressed():
	if selected_beatmap.is_empty():
		print("No beatmap selected!")
		return
	
	if not selected_beatmap.has("difficulties") or selected_beatmap["difficulties"].is_empty():
		print("No difficulties available for selected beatmap!")
		return
	
	# For now, use the first difficulty (can be extended to allow difficulty selection)
	var difficulty = selected_beatmap["difficulties"][0]
	
	# Prepare gameplay configuration
	var gameplay_config = {
		"title": selected_beatmap.get("title", "Unknown"),
		"artist": selected_beatmap.get("artist", "Unknown"),
		"bpm": selected_beatmap.get("bpm", 120),
		"chart_path": difficulty.get("chart_path", ""),
		"audio_path": "", # Will be set below
		"background_path": selected_beatmap.get("background_path", ""),
		"audio_offset": difficulty.get("audioOffset", 0.0)
	}
	
	# Find the audio file in the beatmap directory
	var audio_file_path = _find_audio_file(selected_beatmap.get("beatmap_path", ""))
	if audio_file_path != "":
		gameplay_config["audio_path"] = audio_file_path
	else:
		print("Warning: No audio file found for beatmap")
	
	# Store the configuration globally for the gameplay scene to access
	GameGlobals.current_beatmap_config = gameplay_config
	
	# Transition to gameplay scene
	get_tree().change_scene_to_file("res://scenes/gameplay.tscn")

# Find the audio file in the beatmap directory
func _find_audio_file(beatmap_path: String) -> String:
	if beatmap_path == "":
		return ""
	
	var dir = DirAccess.open(beatmap_path)
	if dir == null:
		return ""
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if not dir.current_is_dir():
			var extension = file_name.get_extension().to_lower()
			if extension in ["ogg", "mp3", "wav"]:
				dir.list_dir_end()
				return beatmap_path + file_name
		file_name = dir.get_next()
	
	dir.list_dir_end()
	return ""

# Get the currently selected beatmap (for use by other systems)
func get_selected_beatmap() -> Dictionary:
	return selected_beatmap
