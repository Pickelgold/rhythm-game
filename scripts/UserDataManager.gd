extends Node

# Directory structure paths (initialized at runtime)
var BASE_DIR: String
var MAPSETS_DIR: String
var SOUNDFONTS_DIR: String
var REPLAYS_DIR: String
var CONFIG_FILE: String

# Built-in resource paths for copying essential files
const BUILTIN_MAPSETS_DIR = "res://mapsets/"
const BUILTIN_SOUNDFONTS_DIR = "res://soundfonts/"
const BUILTIN_REPLAYS_DIR = "res://replays/"

var is_initialized = false

func _ready():
	# Initialize paths at runtime - different approach for web vs desktop
	if OS.get_name() == "Web":
		# Use Godot's user:// for web (maps to browser IndexedDB storage)
		BASE_DIR = "user://"
		MAPSETS_DIR = BASE_DIR + "mapsets/"
		SOUNDFONTS_DIR = BASE_DIR + "soundfonts/"
		REPLAYS_DIR = BASE_DIR + "replays/"
		CONFIG_FILE = BASE_DIR + "config.json"
	else:
		# Use clean OS-specific paths for desktop platforms
		var user_data_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
		if OS.get_name() == "Linux":
			user_data_dir = OS.get_environment("HOME") + "/.local/share"
		elif OS.get_name() == "Windows":
			user_data_dir = OS.get_environment("APPDATA")
		elif OS.get_name() == "macOS":
			user_data_dir = OS.get_environment("HOME") + "/Library/Application Support"
		
		BASE_DIR = user_data_dir + "/rhythm-game/"
		MAPSETS_DIR = BASE_DIR + "mapsets/"
		SOUNDFONTS_DIR = BASE_DIR + "soundfonts/"
		REPLAYS_DIR = BASE_DIR + "replays/"
		CONFIG_FILE = BASE_DIR + "config.json"
	
	ensure_user_data_structure()

# Ensure all necessary directories exist and copy essential files
func ensure_user_data_structure():
	if is_initialized:
		return
	
	print("Initializing user data structure...")
	
	# Check if this is the first run
	var is_first_run = not DirAccess.dir_exists_absolute(BASE_DIR)
	
	# Always ensure directories exist (safe to call even if they exist)
	DirAccess.make_dir_recursive_absolute(BASE_DIR)
	DirAccess.make_dir_recursive_absolute(MAPSETS_DIR)
	DirAccess.make_dir_recursive_absolute(SOUNDFONTS_DIR)
	DirAccess.make_dir_recursive_absolute(REPLAYS_DIR)
	
	if is_first_run:
		print("First run detected - setting up user data directory...")
		
		# Copy built-in files on first run only
		_copy_mapsets_to_user_directory()
		_copy_soundfonts_to_user_directory()
		_copy_replays_to_user_directory()
	
	# Always check/create config (can be missing or corrupted on any run)
	_ensure_valid_config()
	
	is_initialized = true
	print("User data structure initialized successfully")

# Copy all built-in mapsets to user directory (first run only)
func _copy_mapsets_to_user_directory():
	var source_dir = DirAccess.open(BUILTIN_MAPSETS_DIR)
	if source_dir == null:
		print("Warning: No built-in mapsets directory found")
		return
	
	print("Copying built-in mapsets to user directory...")
	
	source_dir.list_dir_begin()
	var folder_name = source_dir.get_next()
	
	while folder_name != "":
		if source_dir.current_is_dir() and not folder_name.begins_with("."):
			var source_mapset_path = BUILTIN_MAPSETS_DIR + folder_name + "/"
			var dest_mapset_path = MAPSETS_DIR + folder_name + "/"
			
			_copy_directory_recursive(source_mapset_path, dest_mapset_path)
			print("Copied mapset: ", folder_name)
		
		folder_name = source_dir.get_next()
	
	source_dir.list_dir_end()

# Copy all built-in soundfonts to user directory (first run only)
func _copy_soundfonts_to_user_directory():
	var source_dir = DirAccess.open(BUILTIN_SOUNDFONTS_DIR)
	if source_dir == null:
		print("Warning: No built-in soundfonts directory found")
		return
	
	print("Copying built-in soundfonts to user directory...")
	
	source_dir.list_dir_begin()
	var item_name = source_dir.get_next()
	
	while item_name != "":
		if not item_name.begins_with("."):
			if source_dir.current_is_dir():
				# Copy soundfont subdirectories recursively
				var source_soundfont_path = BUILTIN_SOUNDFONTS_DIR + item_name + "/"
				var dest_soundfont_path = SOUNDFONTS_DIR + item_name + "/"
				
				_copy_directory_recursive(source_soundfont_path, dest_soundfont_path)
				print("Copied soundfont directory: ", item_name)
			else:
				# Copy individual soundfont files
				var source_file_path = BUILTIN_SOUNDFONTS_DIR + item_name
				var dest_file_path = SOUNDFONTS_DIR + item_name
				
				_copy_file(source_file_path, dest_file_path)
				print("Copied soundfont: ", item_name)
		
		item_name = source_dir.get_next()
	
	source_dir.list_dir_end()

# Copy all built-in replays to user directory (first run only)
func _copy_replays_to_user_directory():
	var source_dir = DirAccess.open(BUILTIN_REPLAYS_DIR)
	if source_dir == null:
		# No built-in replays is normal
		return
	
	print("Copying built-in replays to user directory...")
	
	source_dir.list_dir_begin()
	var item_name = source_dir.get_next()
	
	while item_name != "":
		if not item_name.begins_with("."):
			if source_dir.current_is_dir():
				# Copy replay directories recursively
				var source_replay_path = BUILTIN_REPLAYS_DIR + item_name + "/"
				var dest_replay_path = REPLAYS_DIR + item_name + "/"
				
				_copy_directory_recursive(source_replay_path, dest_replay_path)
				print("Copied replay directory: ", item_name)
			else:
				# Copy individual files
				var source_file_path = BUILTIN_REPLAYS_DIR + item_name
				var dest_file_path = REPLAYS_DIR + item_name
				
				_copy_file(source_file_path, dest_file_path)
				print("Copied replay file: ", item_name)
		
		item_name = source_dir.get_next()
	
	source_dir.list_dir_end()

# Get the default configuration structure
func _get_default_config() -> Dictionary:
	return {
		"version": "1.0",
		"audio": {
			"master_volume": 1.0,
			"music_volume": 1.0,
			"sfx_volume": 1.0,
			"midi_volume": 1.0
		},
		"gameplay": {
			"scroll_speed": 1.0,
			"hit_timing_offset": 0.0,
			"show_fps": false
		},
		"input": {
			# Key bindings can be added here later
		}
	}

# Safely parse config file without throwing errors
func _try_parse_config() -> Dictionary:
	var file = FileAccess.open(CONFIG_FILE, FileAccess.READ)
	if file == null:
		return {}
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		return {}
	
	if not json.data is Dictionary:
		return {}
	
	return json.data

# Ensure valid config file exists
func _ensure_valid_config():
	if not FileAccess.file_exists(CONFIG_FILE):
		_create_default_config()
		return
	
	# Check if config is valid/parseable
	var config = _try_parse_config()
	if config.is_empty():
		print("Config file corrupted, recreating with defaults")
		_create_default_config()

# Create default configuration file
func _create_default_config():
	var default_config = _get_default_config()
	var config_json = JSON.stringify(default_config, "\t")
	var file = FileAccess.open(CONFIG_FILE, FileAccess.WRITE)
	if file:
		file.store_string(config_json)
		file.close()
		print("Created default config file")
	else:
		print("Error: Could not create config file")

# Utility function to copy a file
func _copy_file(source_path: String, dest_path: String) -> bool:
	var source_file = FileAccess.open(source_path, FileAccess.READ)
	if source_file == null:
		print("Error: Could not open source file: ", source_path)
		return false
	
	var dest_file = FileAccess.open(dest_path, FileAccess.WRITE)
	if dest_file == null:
		print("Error: Could not create destination file: ", dest_path)
		source_file.close()
		return false
	
	var buffer = source_file.get_buffer(source_file.get_length())
	dest_file.store_buffer(buffer)
	
	source_file.close()
	dest_file.close()
	return true

# Utility function to copy a directory recursively
func _copy_directory_recursive(source_dir: String, dest_dir: String):
	DirAccess.make_dir_recursive_absolute(dest_dir)
	
	var dir = DirAccess.open(source_dir)
	if dir == null:
		print("Error: Could not open source directory: ", source_dir)
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		var source_path = source_dir + file_name
		var dest_path = dest_dir + file_name
		
		if dir.current_is_dir():
			if not file_name.begins_with("."):
				_copy_directory_recursive(source_path + "/", dest_path + "/")
		else:
			_copy_file(source_path, dest_path)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()

# Public API functions for getting paths
func get_mapsets_path() -> String:
	return MAPSETS_DIR

func get_soundfonts_path() -> String:
	return SOUNDFONTS_DIR

func get_replays_path() -> String:
	return REPLAYS_DIR

func get_config_file_path() -> String:
	return CONFIG_FILE

func get_base_path() -> String:
	return BASE_DIR

# Function to get the default soundfont path
func get_default_soundfont() -> String:
	var soundfont_dir = DirAccess.open(SOUNDFONTS_DIR)
	if soundfont_dir == null:
		return ""
	
	soundfont_dir.list_dir_begin()
	var file_name = soundfont_dir.get_next()
	
	while file_name != "":
		if file_name.get_extension().to_lower() == "sf2":
			soundfont_dir.list_dir_end()
			return SOUNDFONTS_DIR + file_name
		file_name = soundfont_dir.get_next()
	
	soundfont_dir.list_dir_end()
	return ""

# Load configuration with bulletproof fallbacks
func load_config() -> Dictionary:
	if not FileAccess.file_exists(CONFIG_FILE):
		_create_default_config()
		return _get_default_config()
	
	var config = _try_parse_config()
	if config.is_empty():
		print("Config file corrupted, recreating with defaults")
		_create_default_config()
		return _get_default_config()
	
	return config

# Save configuration
func save_config(config: Dictionary):
	var config_json = JSON.stringify(config, "\t")
	var file = FileAccess.open(CONFIG_FILE, FileAccess.WRITE)
	if file:
		file.store_string(config_json)
		file.close()
		print("Config saved successfully")
	else:
		print("Error: Could not save config file")

# === MAPSET USER DATA FUNCTIONS ===

# Get the path to a mapset's user data file
func get_mapset_user_data_path(mapset_id: String) -> String:
	# Extract numeric ID from format like "/m/0"
	var id_parts = mapset_id.split("/")
	if id_parts.size() != 3 or id_parts[1] != "m":
		print("Invalid mapset ID format: ", mapset_id)
		return ""
	
	# Get mapset folder name (we need to find it by reading metadata)
	var dir = DirAccess.open(MAPSETS_DIR)
	if dir == null:
		return ""
	
	dir.list_dir_begin()
	var folder_name = dir.get_next()
	
	while folder_name != "":
		if dir.current_is_dir() and not folder_name.begins_with("."):
			var metadata_path = MAPSETS_DIR + folder_name + "/metadata.json"
			if FileAccess.file_exists(metadata_path):
				var file = FileAccess.open(metadata_path, FileAccess.READ)
				if file:
					var json_string = file.get_as_text()
					file.close()
					var json = JSON.new()
					if json.parse(json_string) == OK and json.data is Dictionary:
						if json.data.get("id", "") == mapset_id:
							# Found the mapset, construct replay folder name
							var mapset_name = json.data.get("title", "Unknown")
							var replay_folder = "[m" + id_parts[2] + " replays] " + mapset_name
							return REPLAYS_DIR + replay_folder + "/mapset.json"
		
		folder_name = dir.get_next()
	
	dir.list_dir_end()
	return ""

# Get default mapset user data structure
func get_default_mapset_user_data(mapset_id: String) -> Dictionary:
	# Try to get author recommendations from metadata.json
	var author_settings = _get_author_recommendations(mapset_id)
	
	return {
		"mapset_id": mapset_id,
		"settings": {
			"audio_offset": 0.0,  # User offset starts at 0, not author's value
			"background_dim": author_settings.get("background_dim", null),
			"background_audio_volume": author_settings.get("background_audio_volume", 1.0),
			"midi_volume": author_settings.get("midi_volume", 1.0)
		},
		"difficulties": {}
	}

# Get author recommendations from metadata.json
func _get_author_recommendations(mapset_id: String) -> Dictionary:
	# Find the mapset directory and read its metadata
	var dir = DirAccess.open(MAPSETS_DIR)
	if dir == null:
		return {}
	
	dir.list_dir_begin()
	var folder_name = dir.get_next()
	
	while folder_name != "":
		if dir.current_is_dir() and not folder_name.begins_with("."):
			var metadata_path = MAPSETS_DIR + folder_name + "/metadata.json"
			if FileAccess.file_exists(metadata_path):
				var file = FileAccess.open(metadata_path, FileAccess.READ)
				if file:
					var json_string = file.get_as_text()
					file.close()
					var json = JSON.new()
					if json.parse(json_string) == OK and json.data is Dictionary:
						if json.data.get("id", "") == mapset_id:
							# Found the mapset, return author settings
							return {
								"audio_offset": json.data.get("audio_offset", 0.0),
								"background_dim": json.data.get("background_dim", null),
								"background_audio_volume": json.data.get("background_audio_volume", 1.0),
								"midi_volume": json.data.get("midi_volume", 1.0)
							}
		
		folder_name = dir.get_next()
	
	dir.list_dir_end()
	return {}

# Get default difficulty data structure
func get_default_difficulty_data() -> Dictionary:
	return {
		"last_played": null,
		"play_count": 0,
		"highest_accuracy": 0.0,
		"scroll_speed": null
	}

# Load mapset user data
func load_mapset_user_data(mapset_id: String) -> Dictionary:
	var path = get_mapset_user_data_path(mapset_id)
	if path == "":
		return get_default_mapset_user_data(mapset_id)
	
	# Create replay directory if it doesn't exist
	var replay_dir = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(replay_dir):
		DirAccess.make_dir_recursive_absolute(replay_dir)
	
	if not FileAccess.file_exists(path):
		# Create default file if it doesn't exist
		var default_data = get_default_mapset_user_data(mapset_id)
		save_mapset_user_data(mapset_id, default_data)
		return default_data
	
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		print("Failed to open mapset user data: ", path)
		return get_default_mapset_user_data(mapset_id)
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		print("Failed to parse mapset user data JSON: ", path)
		return get_default_mapset_user_data(mapset_id)
	
	if not json.data is Dictionary:
		print("Invalid mapset user data format: ", path)
		return get_default_mapset_user_data(mapset_id)
	
	return json.data

# Save mapset user data
func save_mapset_user_data(mapset_id: String, data: Dictionary) -> bool:
	var path = get_mapset_user_data_path(mapset_id)
	if path == "":
		print("Failed to get path for mapset: ", mapset_id)
		return false
	
	# Create replay directory if it doesn't exist
	var replay_dir = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(replay_dir):
		DirAccess.make_dir_recursive_absolute(replay_dir)
	
	var json_string = JSON.stringify(data, "\t")
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		return true
	else:
		print("Failed to save mapset user data: ", path)
		return false

# Update play statistics after completing a song
func update_mapset_play_stats(mapset_id: String, difficulty_id: String, accuracy: float) -> void:
	var data = load_mapset_user_data(mapset_id)
	
	# Ensure difficulties dictionary exists
	if not data.has("difficulties"):
		data["difficulties"] = {}
	
	# Get or create difficulty data
	if not data["difficulties"].has(difficulty_id):
		data["difficulties"][difficulty_id] = get_default_difficulty_data()
	
	var diff_data = data["difficulties"][difficulty_id]
	
	# Update statistics
	diff_data["last_played"] = Time.get_datetime_string_from_system()
	diff_data["play_count"] = diff_data.get("play_count", 0) + 1
	diff_data["highest_accuracy"] = max(diff_data.get("highest_accuracy", 0.0), accuracy)
	
	# Save updated data
	save_mapset_user_data(mapset_id, data)

# Get mapset settings (for use during gameplay)
func get_mapset_settings(mapset_id: String) -> Dictionary:
	var data = load_mapset_user_data(mapset_id)
	return data.get("settings", {
		"audio_offset": 0.0,
		"background_dim": null,
		"background_audio_volume": 1.0,
		"midi_volume": 1.0
	})

# Get difficulty settings (for use during gameplay)
func get_difficulty_settings(mapset_id: String, difficulty_id: String) -> Dictionary:
	var data = load_mapset_user_data(mapset_id)
	if data.has("difficulties") and data["difficulties"].has(difficulty_id):
		return data["difficulties"][difficulty_id]
	return get_default_difficulty_data()
