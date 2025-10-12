extends Node

# Global storage for beatmap configuration
var current_beatmap_config: Dictionary = {}

# Results screen data
var last_results_data: Dictionary = {}
var current_background_path: String = ""

# Reset configuration
func reset_beatmap_config():
	current_beatmap_config.clear()
	last_results_data.clear()
	current_background_path = ""
