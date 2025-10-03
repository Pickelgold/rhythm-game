extends Node

# Audio volume controls (0.0 to 1.0)
var master_volume: float = 1.0
var music_volume: float = 1.0
var sfx_volume: float = 1.0
var midi_volume: float = 1.0

# Audio bus name for master control
const MASTER_BUS = "Master"

# Reference to MidiPlayer for MIDI volume control
var midi_player: MidiPlayer

signal volume_changed(volume_type: String, new_volume: float)

func _ready():
	print("AudioManager initialized")
	_load_audio_settings()

# Load audio settings from UserDataManager config
func _load_audio_settings():
	var config = UserDataManager.load_config()
	var audio_config = config.get("audio", {})
	
	master_volume = audio_config.get("master_volume", 1.0)
	music_volume = audio_config.get("music_volume", 1.0)
	sfx_volume = audio_config.get("sfx_volume", 1.0)
	midi_volume = audio_config.get("midi_volume", 1.0)
	
	print("Audio settings loaded: Master=", master_volume, " Music=", music_volume, " SFX=", sfx_volume, " MIDI=", midi_volume)
	_apply_all_volumes()

# Save current audio settings to config
func _save_audio_settings():
	var config = UserDataManager.load_config()
	config["audio"] = {
		"master_volume": master_volume,
		"music_volume": music_volume, 
		"sfx_volume": sfx_volume,
		"midi_volume": midi_volume
	}
	UserDataManager.save_config(config)


# Set master volume and apply to all audio
func set_master_volume(volume: float):
	master_volume = clamp(volume, 0.0, 1.0)
	_apply_all_volumes()
	_save_audio_settings()
	emit_signal("volume_changed", "master", master_volume)
	print("Master volume set to: ", master_volume)

# Set music/background volume
func set_music_volume(volume: float):
	music_volume = clamp(volume, 0.0, 1.0)
	_apply_music_volume()
	_save_audio_settings()
	emit_signal("volume_changed", "music", music_volume)
	print("Music volume set to: ", music_volume)

# Set sound effects volume
func set_sfx_volume(volume: float):
	sfx_volume = clamp(volume, 0.0, 1.0)
	_apply_sfx_volume()
	_save_audio_settings()
	emit_signal("volume_changed", "sfx", sfx_volume)
	print("SFX volume set to: ", sfx_volume)

# Set MIDI volume
func set_midi_volume(volume: float):
	midi_volume = clamp(volume, 0.0, 1.0)
	_apply_midi_volume()
	_save_audio_settings()
	emit_signal("volume_changed", "midi", midi_volume)
	print("MIDI volume set to: ", midi_volume)

# Apply all volume settings
func _apply_all_volumes():
	_apply_master_volume()
	_apply_music_volume()
	_apply_sfx_volume()
	_apply_midi_volume()

# Apply master volume to Master bus
func _apply_master_volume():
	var master_bus_idx = AudioServer.get_bus_index(MASTER_BUS)
	if master_bus_idx >= 0:
		AudioServer.set_bus_volume_db(master_bus_idx, linear_to_db(master_volume))

# Apply music volume (currently just stores value for AudioStreamPlayer usage)
func _apply_music_volume():
	pass

# Apply SFX volume (currently just stores value for future SFX sources)
func _apply_sfx_volume():
	pass

# Apply MIDI volume to MidiPlayer
func _apply_midi_volume():
	if midi_player:
		var combined_volume = master_volume * midi_volume
		var volume_db = linear_to_db(combined_volume)
		volume_db = clamp(volume_db, -80.0, 0.0)  # MidiPlayer range
		midi_player.volume_db = volume_db
		print("Applied MIDI volume: ", combined_volume, " (", volume_db, " dB)")

# Register MidiPlayer for volume control
func register_midi_player(player: MidiPlayer):
	midi_player = player
	_apply_midi_volume()  # Apply current settings immediately
	print("MidiPlayer registered with AudioManager")

# Unregister MidiPlayer
func unregister_midi_player():
	midi_player = null
	print("MidiPlayer unregistered from AudioManager")

# Get effective volume for audio sources (combines master + specific volume)
func get_effective_music_volume() -> float:
	return master_volume * music_volume

func get_effective_sfx_volume() -> float:
	return master_volume * sfx_volume

func get_effective_midi_volume() -> float:
	return master_volume * midi_volume

# Utility function to convert AudioStreamPlayer volume
func set_audio_stream_player_volume(player: AudioStreamPlayer, volume_type: String):
	var effective_volume: float
	match volume_type:
		"music":
			effective_volume = get_effective_music_volume()
		"sfx":
			effective_volume = get_effective_sfx_volume()
		_:
			effective_volume = master_volume
	
	player.volume_db = linear_to_db(effective_volume)

# Reset all volumes to defaults
func reset_to_defaults():
	set_master_volume(1.0)
	set_music_volume(1.0)
	set_sfx_volume(1.0)
	set_midi_volume(1.0)
	print("Audio volumes reset to defaults")
