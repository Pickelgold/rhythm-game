extends Node

# Directory structure paths (initialized at runtime)
var BASE_DIR: String
var BEATMAPS_DIR: String
var SOUNDFONTS_DIR: String
var CONFIG_FILE: String

# Built-in resource paths for copying essential files
const BUILTIN_BEATMAPS_DIR = "res://beatmaps/"
const BUILTIN_SOUNDFONTS_DIR = "res://soundfonts/"

var is_initialized = false

func _ready():
	# Initialize paths at runtime - different approach for web vs desktop
	if OS.get_name() == "Web":
		# Use Godot's user:// for web (maps to browser IndexedDB storage)
		BASE_DIR = "user://"
		BEATMAPS_DIR = BASE_DIR + "beatmaps/"
		SOUNDFONTS_DIR = BASE_DIR + "soundfonts/"
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
		BEATMAPS_DIR = BASE_DIR + "beatmaps/"
		SOUNDFONTS_DIR = BASE_DIR + "soundfonts/"
		CONFIG_FILE = BASE_DIR + "config.json"
	
	ensure_user_data_structure()

# Ensure all necessary directories exist and copy essential files
func ensure_user_data_structure():
	if is_initialized:
		return
	
	print("Initializing user data structure...")
	
	# Create base directories
	if not DirAccess.dir_exists_absolute(BASE_DIR):
		DirAccess.make_dir_recursive_absolute(BASE_DIR)
		print("Created base directory: ", BASE_DIR)
	
	if not DirAccess.dir_exists_absolute(BEATMAPS_DIR):
		DirAccess.make_dir_recursive_absolute(BEATMAPS_DIR)
		print("Created beatmaps directory: ", BEATMAPS_DIR)
	
	if not DirAccess.dir_exists_absolute(SOUNDFONTS_DIR):
		DirAccess.make_dir_recursive_absolute(SOUNDFONTS_DIR)
		print("Created soundfonts directory: ", SOUNDFONTS_DIR)
	
	# Copy built-in beatmaps to user directory
	_copy_beatmaps_to_user_directory()
	
	# Copy built-in soundfonts to user directory
	_copy_soundfonts_to_user_directory()
	
	# Create default config if it doesn't exist
	_create_default_config()
	
	is_initialized = true
	print("User data structure initialized successfully")

# Copy all built-in beatmaps to user directory
func _copy_beatmaps_to_user_directory():
	var source_dir = DirAccess.open(BUILTIN_BEATMAPS_DIR)
	if source_dir == null:
		print("Warning: No built-in beatmaps directory found")
		return
	
	print("Copying built-in beatmaps to user directory...")
	
	source_dir.list_dir_begin()
	var folder_name = source_dir.get_next()
	
	while folder_name != "":
		if source_dir.current_is_dir() and not folder_name.begins_with("."):
			var source_beatmap_path = BUILTIN_BEATMAPS_DIR + folder_name + "/"
			var dest_beatmap_path = BEATMAPS_DIR + folder_name + "/"
			
			# Only copy if destination doesn't exist
			if not DirAccess.dir_exists_absolute(dest_beatmap_path):
				_copy_directory_recursive(source_beatmap_path, dest_beatmap_path)
				print("Copied beatmap: ", folder_name)
		
		folder_name = source_dir.get_next()
	
	source_dir.list_dir_end()

# Copy all built-in soundfonts to user directory
func _copy_soundfonts_to_user_directory():
	var source_dir = DirAccess.open(BUILTIN_SOUNDFONTS_DIR)
	if source_dir == null:
		print("Warning: No built-in soundfonts directory found")
		return
	
	print("Copying built-in soundfonts to user directory...")
	
	source_dir.list_dir_begin()
	var file_name = source_dir.get_next()
	
	while file_name != "":
		if not source_dir.current_is_dir() and not file_name.begins_with("."):
			var source_file_path = BUILTIN_SOUNDFONTS_DIR + file_name
			var dest_file_path = SOUNDFONTS_DIR + file_name
			
			# Only copy if destination doesn't exist
			if not FileAccess.file_exists(dest_file_path):
				_copy_file(source_file_path, dest_file_path)
				print("Copied soundfont: ", file_name)
		
		file_name = source_dir.get_next()
	
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
func get_beatmaps_path() -> String:
	return BEATMAPS_DIR

func get_soundfonts_path() -> String:
	return SOUNDFONTS_DIR

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
