extends Control
class_name SongSelect

# References to UI elements
@onready var grid_container: GridContainer = $MarginContainer/HBoxContainer/ScrollContainer/GridContainer
@onready var selected_song_panel: PanelContainer = $MarginContainer/HBoxContainer/SelectedSong

# Mapset data
var mapsets: Array[Dictionary] = []
var selected_mapset: Dictionary = {}
var mapset_cards: Array[MapsetCard] = []

# Preload the MapsetCard scene
var mapset_card_scene = preload("res://scenes/MapsetCard.tscn")

func _ready():
	# Load all mapsets
	_scan_mapsets()
	
	# Populate the grid with mapset cards
	_populate_mapset_grid()

# Scan the mapsets directory for all available mapsets
func _scan_mapsets():
	mapsets.clear()
	var mapsets_dir = UserDataManager.get_mapsets_path()
	
	var dir = DirAccess.open(mapsets_dir)
	if dir == null:
		print("Failed to open mapsets directory: ", mapsets_dir)
		return
	
	dir.list_dir_begin()
	var folder_name = dir.get_next()
	
	while folder_name != "":
		# Skip files, only process directories
		if dir.current_is_dir() and not folder_name.begins_with("."):
			var mapset_path = mapsets_dir + folder_name + "/"
			var mapset_data = _load_mapset_metadata(mapset_path)
			
			if not mapset_data.is_empty():
				mapsets.append(mapset_data)
				print("Loaded mapset: ", mapset_data.get("title", "Unknown"))
		
		folder_name = dir.get_next()
	
	dir.list_dir_end()
	
	print("Found ", mapsets.size(), " mapsets")

# Load metadata for a single mapset
func _load_mapset_metadata(mapset_path: String) -> Dictionary:
	var metadata_file = mapset_path + "metadata.json"
	
	if not FileAccess.file_exists(metadata_file):
		print("No metadata.json found in: ", mapset_path)
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
	result["mapset_path"] = mapset_path
	
	# Build full paths for assets
	if result.has("jacket"):
		result["jacket_path"] = mapset_path + result["jacket"]
	
	if result.has("background"):
		result["background_path"] = mapset_path + result["background"]
	
	# Build full path for audio if specified
	if result.has("audio"):
		result["audio_path"] = mapset_path + result["audio"]
	
	# Process difficulties to add full paths
	if result.has("difficulties") and result["difficulties"] is Array:
		for difficulty in result["difficulties"]:
			if difficulty.has("beatmap"):
				difficulty["beatmap_path"] = mapset_path + difficulty["beatmap"]
	
	return result

# Populate the grid container with mapset cards
func _populate_mapset_grid():
	# Clear existing cards
	_clear_mapset_cards()
	
	# Create cards for each mapset
	for mapset_data in mapsets:
		var card = mapset_card_scene.instantiate()
		
		# Setup the card with mapset data
		card.setup_mapset(mapset_data)
		
		# Connect selection signal
		card.card_selected.connect(_on_mapset_selected)
		
		# Add to grid
		grid_container.add_child(card)
		mapset_cards.append(card)

# Clear all mapset cards from the grid
func _clear_mapset_cards():
	for card in mapset_cards:
		if card and is_instance_valid(card):
			card.queue_free()
	
	mapset_cards.clear()
	
	# Also clear any remaining children from grid
	for child in grid_container.get_children():
		child.queue_free()

# Handle mapset selection
func _on_mapset_selected(mapset_data: Dictionary):
	# Update selected mapset
	selected_mapset = mapset_data
	
	# Update visual selection state
	for card in mapset_cards:
		card.set_selected(card.mapset_data == mapset_data)
	
	# Update selected song panel (placeholder for now)
	_update_selected_song_panel()
	
	print("Selected mapset: ", mapset_data.get("title", "Unknown"))

# Update the selected song panel with current selection
func _update_selected_song_panel():
	if selected_mapset.is_empty():
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
	if selected_mapset.has("background_path"):
		var background_rect = TextureRect.new()
		background_rect.custom_minimum_size = Vector2(300, 200)
		background_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		background_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_load_background_image(background_rect, selected_mapset["background_path"])
		info_container.add_child(background_rect)
	
	# Add title
	var title_label = Label.new()
	title_label.text = selected_mapset.get("title", "Unknown Title")
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_container.add_child(title_label)
	
	# Add artist
	var artist_label = Label.new()
	artist_label.text = "by " + selected_mapset.get("artist", "Unknown Artist")
	artist_label.add_theme_font_size_override("font_size", 16)
	artist_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	artist_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_container.add_child(artist_label)
	
	# Add BPM and mapper info
	var info_label = Label.new()
	var bpm = selected_mapset.get("bpm", "Unknown")
	var mapper = selected_mapset.get("mapper", "Unknown")
	info_label.text = "BPM: " + str(bpm) + "\nMapped by: " + mapper
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_container.add_child(info_label)
	
	# Add difficulties
	if selected_mapset.has("difficulties"):
		var diff_label = Label.new()
		diff_label.text = "Difficulties:"
		diff_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		diff_label.add_theme_font_size_override("font_size", 14)
		info_container.add_child(diff_label)
		
		for diff in selected_mapset["difficulties"]:
			var diff_info = Label.new()
			# Support both old and new field names for compatibility
			var star_rating = diff.get("star_rating", diff.get("starRating", 0))
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
	
	print("Selected mapset: ", selected_mapset.get("title", "Unknown"))

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
	if selected_mapset.is_empty():
		print("No mapset selected!")
		return
	
	if not selected_mapset.has("difficulties") or selected_mapset["difficulties"].is_empty():
		print("No difficulties available for selected mapset!")
		return
	
	# For now, use the first difficulty (can be extended to allow difficulty selection)
	var difficulty = selected_mapset["difficulties"][0]
	
	# Get mapset and difficulty IDs
	var mapset_id = selected_mapset.get("id", "/m/0")
	var difficulty_id = difficulty.get("id", "/d/0")
	
	# Load mapset user data
	var mapset_settings = UserDataManager.get_mapset_settings(mapset_id)
	var difficulty_settings = UserDataManager.get_difficulty_settings(mapset_id, difficulty_id)
	
	# Load global config for global offset
	var global_config = UserDataManager.load_config()
	var global_offset = 0.0
	if global_config.has("gameplay") and global_config["gameplay"].has("hit_timing_offset"):
		global_offset = global_config["gameplay"]["hit_timing_offset"]
	
	# Prepare gameplay configuration
	var gameplay_config = {
		"title": selected_mapset.get("title", "Unknown"),
		"artist": selected_mapset.get("artist", "Unknown"),
		"bpm": selected_mapset.get("bpm", 120),
		"beatmap_path": difficulty.get("beatmap_path", ""),
		"audio_path": "", # Will be set below
		"background_path": selected_mapset.get("background_path", ""),
		"global_audio_offset": global_offset,  # Pass global offset
		"mapset_id": mapset_id,
		"difficulty_id": difficulty_id,
		"mapset_settings": mapset_settings,
		"difficulty_settings": difficulty_settings
	}
	
	# Use audio path from metadata if available, otherwise find it
	if selected_mapset.has("audio_path"):
		gameplay_config["audio_path"] = selected_mapset["audio_path"]
	else:
		# Find the audio file in the mapset directory (backward compatibility)
		var audio_file_path = _find_audio_file(selected_mapset.get("mapset_path", ""))
		if audio_file_path != "":
			gameplay_config["audio_path"] = audio_file_path
		else:
			print("Warning: No audio file found for mapset")
	
	# Store the configuration globally for the gameplay scene to access
	GameGlobals.current_beatmap_config = gameplay_config
	
	# Transition to gameplay scene
	get_tree().change_scene_to_file("res://scenes/gameplay.tscn")

# Find the audio file in the mapset directory
func _find_audio_file(mapset_path: String) -> String:
	if mapset_path == "":
		return ""
	
	var dir = DirAccess.open(mapset_path)
	if dir == null:
		return ""
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if not dir.current_is_dir():
			var extension = file_name.get_extension().to_lower()
			if extension in ["ogg", "mp3", "wav"]:
				dir.list_dir_end()
				return mapset_path + file_name
		file_name = dir.get_next()
	
	dir.list_dir_end()
	return ""

# Get the currently selected mapset (for use by other systems)
func get_selected_mapset() -> Dictionary:
	return selected_mapset
