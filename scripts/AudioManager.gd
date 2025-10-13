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

# Background music player
var background_music_player: AudioStreamPlayer = null

signal volume_changed(volume_type: String, new_volume: float)
signal background_music_finished()

func _ready():
	print("AudioManager initialized")
	_load_audio_settings()
	
	# Create background music player
	background_music_player = AudioStreamPlayer.new()
	background_music_player.name = "BackgroundMusicPlayer"
	add_child(background_music_player)
	background_music_player.finished.connect(_on_background_music_finished)

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

# Apply music volume to background music player
func _apply_music_volume():
	if background_music_player:
		set_audio_stream_player_volume(background_music_player, "music")

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

# Background Music Management Functions

# Play background music from file path
func play_background_music(path: String, from_position: float = 0.0, volume_multiplier: float = 1.0):
	if not background_music_player:
		print("Error: Background music player not initialized")
		return
		
	if path == "":
		print("No background music path provided")
		return
		
	if not FileAccess.file_exists(path):
		print("Background music file not found: ", path)
		return
	
	# Load the audio stream - handle both res:// and user directory paths
	var audio_stream: AudioStream = null
	
	if path.begins_with("res://"):
		# Load from project resources
		audio_stream = load(path)
	else:
		# Load from external file (user directory)
		var file_extension = path.get_extension().to_lower()
		
		if file_extension == "ogg":
			# Load OGG Vorbis file
			var ogg_stream = AudioStreamOggVorbis.new()
			ogg_stream = AudioStreamOggVorbis.load_from_file(path)
			audio_stream = ogg_stream
		elif file_extension == "mp3":
			# Load MP3 file
			var file = FileAccess.open(path, FileAccess.READ)
			if file:
				var mp3_stream = AudioStreamMP3.new()
				mp3_stream.data = file.get_buffer(file.get_length())
				file.close()
				audio_stream = mp3_stream
		elif file_extension == "wav":
			# Load WAV file
			var file = FileAccess.open(path, FileAccess.READ)
			if file:
				var wav_stream = AudioStreamWAV.new()
				# Skip WAV header (44 bytes for standard WAV)
				file.seek(44)
				wav_stream.data = file.get_buffer(file.get_length() - 44)
				wav_stream.format = AudioStreamWAV.FORMAT_16_BITS
				wav_stream.stereo = true
				wav_stream.mix_rate = 44100  # Standard sample rate
				file.close()
				audio_stream = wav_stream
		else:
			print("Unsupported audio format: ", file_extension)
			return
	
	if audio_stream == null:
		print("Failed to load background music: ", path)
		return
		
	if not audio_stream is AudioStream:
		print("Loaded resource is not an AudioStream: ", path)
		return
		
	# Stop any currently playing music
	stop_background_music()
		
	# Set stream and volume
	background_music_player.stream = audio_stream
	set_audio_stream_player_volume(background_music_player, "music")
	
	# Apply volume multiplier if provided
	if volume_multiplier != 1.0:
		var current_db = background_music_player.volume_db
		var linear_volume = db_to_linear(current_db) * volume_multiplier
		background_music_player.volume_db = linear_to_db(linear_volume)
		print("Applied background music volume multiplier: ", volume_multiplier)
	
	# Play from position
	background_music_player.play(from_position)
	print("Background music started: ", path, " at position: ", from_position)

# Stop background music
func stop_background_music():
	if background_music_player and background_music_player.playing:
		background_music_player.stop()
		print("Background music stopped")

# Pause background music
func pause_background_music():
	if background_music_player and background_music_player.playing:
		background_music_player.stream_paused = true
		print("Background music paused")

# Resume background music
func resume_background_music():
	if background_music_player and background_music_player.stream_paused:
		background_music_player.stream_paused = false
		print("Background music resumed")

# Get current playback position
func get_background_music_position() -> float:
	if background_music_player and background_music_player.playing:
		return background_music_player.get_playback_position()
	return 0.0

# Check if background music is playing
func is_background_music_playing() -> bool:
	return background_music_player != null and background_music_player.playing

# Set background music to specific position
func seek_background_music(position: float):
	if background_music_player and background_music_player.stream:
		background_music_player.seek(position)
		print("Background music seeked to: ", position)

# Callback when background music finishes
func _on_background_music_finished():
	background_music_finished.emit()
	print("Background music finished playing")
