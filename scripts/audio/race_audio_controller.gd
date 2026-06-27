class_name RaceAudioController
extends Node

@export var race_manager_path: NodePath = ^"../RaceManager"
@export var music_stream: AudioStream = preload("res://assets/audio/music/race_neon_sprint_loop.mp3")
@export var countdown_three_stream: AudioStream = preload("res://assets/audio/sfx/race_countdown_3_hype.wav")
@export var countdown_two_stream: AudioStream = preload("res://assets/audio/sfx/race_countdown_3_hype.wav")
@export var countdown_one_stream: AudioStream = preload("res://assets/audio/sfx/race_countdown_3_hype.wav")
@export var go_stream: AudioStream = preload("res://assets/audio/sfx/race_go_hype_launch.wav")
@export var finish_stream: AudioStream = preload("res://assets/audio/sfx/race_finish_hype_flyby.wav")
@export var music_bus: StringName = &"Music"
@export var sfx_bus: StringName = &"SFX"
@export var music_volume_db: float = -12.0
@export var countdown_hit_volume_db: float = 1.5
@export_range(0.5, 2.0, 0.01) var countdown_three_pitch_scale: float = 1.0
@export_range(0.5, 2.0, 0.01) var countdown_two_pitch_scale: float = 1.1
@export_range(0.5, 2.0, 0.01) var countdown_one_pitch_scale: float = 1.22
@export var go_volume_db: float = 3.0
@export var finish_volume_db: float = 1.0

var _race_manager: Node = null
var _music_player: AudioStreamPlayer = null
var _countdown_player: AudioStreamPlayer = null
var _go_player: AudioStreamPlayer = null
var _finish_player: AudioStreamPlayer = null
var _last_countdown_whole_seconds: int = -1
var _music_tween: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_race_manager = get_node_or_null(race_manager_path)
	if _race_manager == null:
		_race_manager = _find_node_by_name(get_tree().current_scene, &"RaceManager")
	_music_player = _make_player("RaceMusic", music_stream, String(music_bus), music_volume_db)
	_countdown_player = _make_player("CountdownHit", null, String(sfx_bus), countdown_hit_volume_db)
	_go_player = _make_player("RaceGo", go_stream, String(sfx_bus), go_volume_db)
	_finish_player = _make_player("RaceFinish", finish_stream, String(sfx_bus), finish_volume_db)
	_set_stream_loop(_music_player.stream, true)
	if _music_player.stream != null:
		_music_player.play()
	_connect_race_signals()


func _connect_race_signals() -> void:
	if _race_manager == null:
		push_warning("RaceAudioController: race manager not found")
		return
	if _race_manager.has_signal("race_phase_changed"):
		_race_manager.connect("race_phase_changed", _on_race_phase_changed)
	if _race_manager.has_signal("countdown_changed"):
		_race_manager.connect("countdown_changed", _on_countdown_changed)
	if _race_manager.has_signal("race_started"):
		_race_manager.connect("race_started", _on_race_started)
	if _race_manager.has_signal("race_finished"):
		_race_manager.connect("race_finished", _on_race_finished)


func _on_race_phase_changed(_previous_phase: int, new_phase: int) -> void:
	var phase_name: String = ""
	if _race_manager != null and _race_manager.has_method("get_phase_name"):
		phase_name = String(_race_manager.call("get_phase_name")).to_lower()
	if phase_name.is_empty():
		phase_name = "countdown" if new_phase == 1 else ""
	if phase_name == "setup" or phase_name == "countdown":
		_last_countdown_whole_seconds = -1


func _on_countdown_changed(_time_remaining_seconds: float, whole_seconds: int) -> void:
	if whole_seconds <= 0 or whole_seconds > 3 or whole_seconds == _last_countdown_whole_seconds:
		return
	_last_countdown_whole_seconds = whole_seconds
	_play_one_shot(_countdown_player, _get_countdown_stream(whole_seconds), countdown_hit_volume_db, _get_countdown_pitch(whole_seconds))


func _on_race_started() -> void:
	_last_countdown_whole_seconds = 0
	_play_one_shot(_go_player, go_stream, go_volume_db)


func _on_race_finished(_results: Array) -> void:
	_play_one_shot(_finish_player, finish_stream, finish_volume_db)


func fade_music_out(fade_seconds: float = 0.75) -> void:
	if _music_player == null or not _music_player.playing:
		return
	if _music_tween != null:
		_music_tween.kill()
		_music_tween = null
	var fade_time: float = maxf(fade_seconds, 0.0)
	if fade_time <= 0.0:
		_music_player.stop()
		return
	_music_tween = create_tween()
	_music_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_music_tween.tween_property(_music_player, "volume_db", -60.0, fade_time)
	_music_tween.tween_callback(Callable(_music_player, "stop"))


func _make_player(player_name: String, stream: AudioStream, bus_name: String, volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.stream = stream
	player.bus = bus_name
	player.volume_db = volume_db
	add_child(player)
	return player


func _play_one_shot(player: AudioStreamPlayer, stream: AudioStream, volume_db: float, pitch_scale: float = 1.0) -> void:
	if player == null or stream == null:
		return
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.stop()
	player.play()


func _get_countdown_stream(whole_seconds: int) -> AudioStream:
	match whole_seconds:
		3:
			return countdown_three_stream
		2:
			return countdown_two_stream
		1:
			return countdown_one_stream
		_:
			return null


func _get_countdown_pitch(whole_seconds: int) -> float:
	match whole_seconds:
		3:
			return countdown_three_pitch_scale
		2:
			return countdown_two_pitch_scale
		1:
			return countdown_one_pitch_scale
		_:
			return 1.0


func _set_stream_loop(stream: AudioStream, should_loop: bool) -> void:
	if stream == null:
		return
	for property: Dictionary in stream.get_property_list():
		if String(property.get("name", "")) == "loop":
			stream.set("loop", should_loop)
			return


func _find_node_by_name(root: Node, node_name: StringName) -> Node:
	if root == null or node_name == &"":
		return null
	if root.name == node_name:
		return root
	for child: Node in root.get_children():
		var found: Node = _find_node_by_name(child, node_name)
		if found != null:
			return found
	return null
