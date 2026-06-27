extends Node

const SAMPLE_RATE := 22050

signal sfx_played(name: String)

var music_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var sfx_streams: Dictionary = {}
var next_sfx_player := 0

func _ready() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.name = "Music"
	music_player.volume_db = -17.0
	add_child(music_player)
	for index in 8:
		var player := AudioStreamPlayer.new()
		player.name = "Sfx%d" % index
		player.volume_db = -9.0
		add_child(player)
		sfx_players.append(player)
	music_player.stream = create_music()
	sfx_streams = {
		"menu": create_tone(660.0, 0.10, "square", 0.55, 1.25),
		"shot": create_tone(920.0, 0.055, "square", 0.22, 0.78),
		"enemy_shot": create_tone(260.0, 0.09, "triangle", 0.24, 0.72),
		"hit": create_noise(0.11, 0.42),
		"shield": create_tone(520.0, 0.22, "sine", 0.5, 1.8),
		"pickup": create_arpeggio([660.0, 880.0, 1100.0], 0.07, 0.45),
		"explode": create_noise(0.22, 0.60),
		"special": create_arpeggio([330.0, 440.0, 660.0, 880.0, 1320.0], 0.10, 0.55),
		"formation": create_arpeggio([740.0, 980.0], 0.055, 0.28),
		"level_up": create_arpeggio([523.25, 659.25, 783.99, 1046.50], 0.09, 0.48),
		"boss": create_arpeggio([196.0, 174.0, 146.0, 110.0], 0.14, 0.52)
	}
	refresh_settings()

func refresh_settings() -> void:
	if not is_instance_valid(music_player):
		return
	music_player.stream_paused = not bool(SaveManager.data.music_enabled)
	if SaveManager.data.music_enabled and not music_player.playing:
		music_player.play()
	if not SaveManager.data.sfx_enabled:
		for player in sfx_players:
			player.stop()

func play_music() -> void:
	refresh_settings()

func play_sfx(name: String) -> void:
	if not SaveManager.data.sfx_enabled or not sfx_streams.has(name):
		return
	var player := sfx_players[next_sfx_player]
	next_sfx_player = (next_sfx_player + 1) % sfx_players.size()
	player.stream = sfx_streams[name]
	player.play()
	sfx_played.emit(name)

func create_music() -> AudioStreamWAV:
	var beat_seconds := 0.20
	var melody := [
		659.25, 783.99, 987.77, 783.99, 659.25, 523.25, 587.33, 659.25,
		783.99, 987.77, 1174.66, 987.77, 783.99, 659.25, 587.33, 523.25,
		659.25, 783.99, 880.00, 987.77, 880.00, 783.99, 659.25, 587.33,
		523.25, 587.33, 659.25, 783.99, 659.25, 587.33, 523.25, 493.88
	]
	var bass := [164.81, 164.81, 130.81, 146.83]
	var seconds := melody.size() * beat_seconds
	var sample_count := int(seconds * SAMPLE_RATE)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	for sample_index in sample_count:
		var time := float(sample_index) / SAMPLE_RATE
		var beat := mini(int(time / beat_seconds), melody.size() - 1)
		var local_time := fmod(time, beat_seconds)
		var envelope := minf(local_time / 0.018, 1.0) * clampf((beat_seconds - local_time) / 0.045, 0.0, 1.0)
		var lead_phase := fmod(time * melody[beat], 1.0)
		var lead := 1.0 if lead_phase < 0.5 else -1.0
		var bass_freq: float = bass[(beat / 8) % bass.size()]
		var bass_phase := fmod(time * bass_freq, 1.0)
		var bass_wave := absf(bass_phase * 2.0 - 1.0) * 2.0 - 1.0
		var pulse := sin(TAU * time * 55.0) * (0.10 if beat % 4 == 0 and local_time < 0.07 else 0.0)
		var sample := (lead * 0.18 * envelope + bass_wave * 0.10 + pulse) * 0.72
		bytes.encode_s16(sample_index * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = bytes
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = sample_count
	return stream

func create_tone(frequency: float, seconds: float, shape: String, volume: float, frequency_end_ratio: float) -> AudioStreamWAV:
	var sample_count := int(seconds * SAMPLE_RATE)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	var phase := 0.0
	for sample_index in sample_count:
		var progress := float(sample_index) / maxf(1.0, sample_count - 1.0)
		var frequency_now := lerpf(frequency, frequency * frequency_end_ratio, progress)
		phase = fmod(phase + frequency_now / SAMPLE_RATE, 1.0)
		var wave := sin(TAU * phase)
		if shape == "square":
			wave = 1.0 if phase < 0.5 else -1.0
		elif shape == "triangle":
			wave = 1.0 - 4.0 * absf(phase - 0.5)
		var envelope := pow(1.0 - progress, 1.8) * minf(progress * 16.0, 1.0)
		bytes.encode_s16(sample_index * 2, int(wave * envelope * volume * 32767.0))
	return wav_from_bytes(bytes)

func create_noise(seconds: float, volume: float) -> AudioStreamWAV:
	var sample_count := int(seconds * SAMPLE_RATE)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	var previous := 0.0
	for sample_index in sample_count:
		var progress := float(sample_index) / maxf(1.0, sample_count - 1.0)
		var noise := randf_range(-1.0, 1.0)
		previous = lerpf(previous, noise, 0.35)
		var envelope := pow(1.0 - progress, 2.2)
		bytes.encode_s16(sample_index * 2, int(previous * envelope * volume * 32767.0))
	return wav_from_bytes(bytes)

func create_arpeggio(notes: Array, note_seconds: float, volume: float) -> AudioStreamWAV:
	var sample_count := int(notes.size() * note_seconds * SAMPLE_RATE)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	for sample_index in sample_count:
		var time := float(sample_index) / SAMPLE_RATE
		var note_index := mini(int(time / note_seconds), notes.size() - 1)
		var note_time := fmod(time, note_seconds)
		var phase := fmod(time * float(notes[note_index]), 1.0)
		var wave := 1.0 if phase < 0.5 else -1.0
		var envelope := clampf((note_seconds - note_time) / (note_seconds * 0.65), 0.0, 1.0)
		bytes.encode_s16(sample_index * 2, int(wave * envelope * volume * 32767.0))
	return wav_from_bytes(bytes)

func wav_from_bytes(bytes: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = bytes
	return stream
