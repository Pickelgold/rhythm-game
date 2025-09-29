extends Node

# Global storage for beatmap configuration
var current_beatmap_config: Dictionary = {}

# Reset configuration
func reset_beatmap_config():
	current_beatmap_config.clear()
