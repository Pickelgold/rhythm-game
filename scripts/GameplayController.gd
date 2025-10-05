extends Node

# This script should be attached to the root node of the gameplay scene
# to initialize the MidiPlayer with the correct user data paths

@onready var midi_player: MidiPlayer

@onready var judgement_system: JudgementSystem = $"../JudgementSystem"

func _ready():
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
	
	# TODO: Connect to song end signal when implemented
	# For now, you would call update_play_statistics() when the song ends

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
