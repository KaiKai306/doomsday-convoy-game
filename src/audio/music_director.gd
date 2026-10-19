extends Node
## One music service for the menu, ordinary play and disposable developer play.
## Two voices overlap only during fades and at loop boundaries.
const CATALOG = preload("res://src/audio/music_catalog.gd")
const BUS_NAME = &"ConvoyMusic"
var active_player: AudioStreamPlayer
var voices: Array[AudioStreamPlayer] = []
var current_cue = ""
var desired_cue = ""
var current_track = ""
var generation = 0
var transition_seconds = 0.65
var loop_crossfade_seconds = 1.2
var playlist_index = 0
var preferences: Dictionary = {"master":80,"music":65,"mute":false}
var _owner: WeakRef
var _settings: WeakRef
var _fade: Tween
var _transitioning = false
var _streams: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if AudioServer.get_bus_index(BUS_NAME) < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count-1,BUS_NAME)
	for index in 2:
		var voice = AudioStreamPlayer.new()
		voice.name = "MusicVoice%d" % index
		voice.bus = BUS_NAME
		voice.volume_linear = 0.0
		add_child(voice)
		voices.append(voice)
		voice.finished.connect(_voice_finished.bind(voice))
	active_player = voices[0]
	apply_preferences(preferences)

func activate(owner: Node) -> void:
	_owner = weakref(owner)

func is_owner(owner: Node) -> bool:
	return _owner != null and _owner.get_ref() == owner

func bind_preferences(settings: Node) -> void:
	if _settings != null:
		var previous = _settings.get_ref()
		if is_instance_valid(previous) and previous.audio_changed.is_connected(_preferences_changed):
			previous.audio_changed.disconnect(_preferences_changed)
	_settings = weakref(settings)
	settings.audio_changed.connect(_preferences_changed)
	_preferences_changed()

func _preferences_changed() -> void:
	if _settings != null and is_instance_valid(_settings.get_ref()):
		apply_preferences(_settings.get_ref().values)

func apply_preferences(values: Dictionary) -> void:
	preferences = values.duplicate()
	var gain = clampf(float(values.get("master",80))/100.0,0,1) * clampf(float(values.get("music",65))/100.0,0,1)
	var bus = AudioServer.get_bus_index(BUS_NAME)
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus,linear_to_db(maxf(gain,0.000001)))
		AudioServer.set_bus_mute(bus,bool(values.get("mute",false)) or is_zero_approx(gain))

func request(owner: Node, cue: String) -> void:
	if not is_owner(owner) or cue == "" or CATALOG.playlist(cue).is_empty(): return
	if desired_cue == cue: return
	desired_cue = cue
	current_cue = cue
	playlist_index = 0
	_switch_track(str(CATALOG.playlist(cue)[0]),transition_seconds,true)

func _stream(track_id: String) -> AudioStreamOggVorbis:
	if not _streams.has(track_id):
		var definition = CATALOG.track(track_id)
		var resource = load(str(definition.get("path","")))
		if not resource is AudioStreamOggVorbis:
			push_error("Cannot load music track: "+track_id)
			return null
		var copy = resource.duplicate() as AudioStreamOggVorbis
		# The overlap at the end preserves the recording tail and avoids a hard
		# waveform jump. One-shot endings stop naturally instead of restarting.
		copy.loop = false
		_streams[track_id] = copy
	return _streams[track_id]

func _switch_track(track_id: String, seconds: float, reuse_playing: bool) -> void:
	var stream = _stream(track_id)
	if stream == null: return
	generation += 1
	var token = generation
	if _fade != null: _fade.kill()
	var outgoing = active_player
	var incoming: AudioStreamPlayer = null
	if reuse_playing:
		for voice in voices:
			if voice.playing and str(voice.get_meta("track_id","")) == track_id:
				incoming = voice
				break
	if incoming == null:
		# A third request may arrive while the previous two voices are still
		# fading. Preserve the louder voice instead of cutting it simply
		# because the quieter newcomer was labelled active_player.
		outgoing = voices[0] if voices[0].volume_linear >= voices[1].volume_linear else voices[1]
		incoming = voices[1] if outgoing == voices[0] else voices[0]
		incoming.stop()
		incoming.stream = stream
		incoming.set_meta("track_id",track_id)
		incoming.volume_linear = 0.0
		incoming.play()
	active_player = incoming
	current_track = track_id
	_transitioning = true
	var gain = db_to_linear(float(CATALOG.track(track_id).get("gain_db",0.0)))
	_fade = create_tween().set_parallel(true)
	_fade.tween_property(incoming,"volume_linear",gain,seconds)
	if outgoing != incoming:
		_fade.tween_property(outgoing,"volume_linear",0.0,seconds)
	_fade.chain().tween_callback(func():
		if generation != token: return
		for voice in voices:
			if voice != active_player: voice.stop(); voice.volume_linear = 0.0
		_transitioning = false
	)

func _process(_delta: float) -> void:
	if _owner != null and not is_instance_valid(_owner.get_ref()):
		stop()
		return
	if _transitioning or current_track == "" or not active_player.playing: return
	if not bool(CATALOG.track(current_track).get("loop",true)): return
	var length = active_player.stream.get_length()
	var remaining = length-active_player.get_playback_position()
	if length > loop_crossfade_seconds*2.0 and remaining <= loop_crossfade_seconds:
		_advance(loop_crossfade_seconds)

func _voice_finished(voice: AudioStreamPlayer) -> void:
	if voice == active_player and not _transitioning and current_track != "" and bool(CATALOG.track(current_track).get("loop",true)):
		_advance(transition_seconds)

func _advance(seconds: float) -> void:
	var playlist = CATALOG.playlist(desired_cue)
	if playlist.is_empty(): return
	playlist_index = (playlist_index+1) % playlist.size()
	_switch_track(str(playlist[playlist_index]),seconds,false)

func stop() -> void:
	generation += 1
	if _fade != null: _fade.kill()
	for voice in voices: voice.stop(); voice.volume_linear = 0.0
	_owner = null
	_transitioning = false
	current_cue = ""
	desired_cue = ""
	current_track = ""
