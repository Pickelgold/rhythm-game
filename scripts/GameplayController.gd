extends Node

# This script should be attached to the root node of the gameplay scene
# to initialize the MidiPlayer with the correct user data paths

@onready var midi_player: MidiPlayer
@onready var midi_spawner = null  # Will be set in _ready
@onready var judgement_system: JudgementSystem = $"../JudgementSystem"

# Path to results screen scene
const RESULTS_SCENE_PATH = "res://scenes/results_screen.tscn"

func _ready():
	# Try to find MIDISpawner in different possible locations
	midi_spawner = get_node_or_null("../MIDISpawner")
	if not midi_spawner:
		midi_spawner = get_node_or_null("/root/Gameplay/MIDISpawner")
	if not midi_spawner:
		midi_spawner = get_node_or_null("MIDISpawner")
	
	# Connect to song finished signal
	if midi_spawner:
		print("Found MIDISpawner at: ", midi_spawner.get_path())
		print("Attempting to connect to MIDISpawner signal...")
		var connection_result = midi_spawner.song_finished.connect(_on_song_finished)
		if connection_result == OK:
			print("Successfully connected to song_finished signal from MIDISpawner")
		else:
			print("ERROR: Failed to connect signal, error code: ", connection_result)
	else:
		print("ERROR: MIDISpawner not found in any location!")
		print("Trying to list all children of parent...")
		if get_parent():
			for child in get_parent().get_children():
				print("  - ", child.name, " (", child.get_class(), ")")
	
	# Find the MidiPlayer node in the scene
	midi_player = _find_midi_player()
	
	if midi_player == null:
		print("Warning: MidiPlayer not found in gameplay scene")
		return
	
	# Set the soundfont path to the user data directory
	var soundfont_path = UserDataManager.get_default_soundfont()
	if soundfont_path != "":
		print("Setting soundfont to: ", soundfont_path)
		midi_player.set_soundfont(soundfont_path)
	else:
		print("Warning: No soundfont found in user data directory")
	
	# Register MidiPlayer with AudioManager for volume control
	AudioManager.register_midi_player(midi_player)
	
	# Apply mapset MIDI volume multiplier
	if not GameGlobals.current_beatmap_config.is_empty():
		var mapset_settings = GameGlobals.current_beatmap_config.get("mapset_settings", {})
		var midi_volume_mult = mapset_settings.get("midi_volume", 1.0)
		var current_db = midi_player.volume_db
		# Convert to linear, apply multiplier, convert back to dB
		var linear_volume = db_to_linear(current_db) * midi_volume_mult
		midi_player.volume_db = linear_to_db(linear_volume)
		print("MIDI volume set with mapset multiplier: ", midi_volume_mult)
	

# Update play statistics when song ends
func update_play_statistics():
	if GameGlobals.current_beatmap_config.is_empty():
		return
	
	var mapset_id = GameGlobals.current_beatmap_config.get("mapset_id", "")
	var difficulty_id = GameGlobals.current_beatmap_config.get("difficulty_id", "")
	
	if mapset_id == "" or difficulty_id == "":
		print("Cannot update statistics: missing mapset or difficulty ID")
		return
	
	# Get current accuracy from judgement system
	var accuracy = 100.0
	if judgement_system:
		accuracy = judgement_system.get_accuracy()
	
	# Update the mapset play statistics
	UserDataManager.update_mapset_play_stats(mapset_id, difficulty_id, accuracy)
	print("Updated play statistics for ", mapset_id, " / ", difficulty_id, " with accuracy: ", accuracy, "%")

# Called when the song finishes
func _on_song_finished():
	print("=== _on_song_finished() called in GameplayController ===")
	print("Song finished! Showing results screen...")
	
	# Collect results data
	var results_data = _collect_results_data()
	print("Collected results data: ", results_data)
	
	# Update play statistics
	update_play_statistics()
	
	# Store results data in GameGlobals for the results screen
	GameGlobals.last_results_data = results_data
	
	# Change to results scene (audio continues through AudioManager)
	get_tree().change_scene_to_file(RESULTS_SCENE_PATH)
	print("Changed scene to results screen")

# Collect all the results data from the judgement system
func _collect_results_data() -> Dictionary:
	var data = {}
	
	if judgement_system:
		# Get accuracy
		data["accuracy"] = judgement_system.get_accuracy()
		
		# Get score (using total hit points)
		data["score"] = judgement_system.total_hit_points
		
		# Get max combo (use the tracked max_combo)
		data["max_combo"] = judgement_system.max_combo
		
		# Get real judgement counts from the tracking system
		data["judgement_counts"] = judgement_system.judgement_counts.duplicate()
		
		# Store total notes for reference
		data["total_notes"] = judgement_system.total_notes_attempted
	else:
		# Default values if no judgement system
		data["accuracy"] = 0.0
		data["score"] = 0
		data["max_combo"] = 0
		data["judgement_counts"] = {
			"perfect": 0,
			"great": 0,
			"good": 0,
			"miss": 0
		}
		data["total_notes"] = 0
	
	return data


# Helper function to find the MidiPlayer node
func _find_midi_player() -> Node:
	return _find_node_recursive(self, "MidiPlayer")

func _find_node_recursive(node: Node, target_name: String) -> Node:
	for child in node.get_children():
		if child.name == target_name:
			return child
		var found = _find_node_recursive(child, target_name)
		if found:
			return found
	return null
