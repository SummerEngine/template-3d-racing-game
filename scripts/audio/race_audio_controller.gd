class_name RaceAudioController
extends Node

@export var race_manager_path: NodePath = ^"../RaceManager"
@export var music_stream: AudioStream = preload("res://assets/audio/music/race_loop_arcade_drift.mp3")
@export var countdown_stream: AudioStream = preload("res://assets/audio/sfx/countdown_start_stinger.mp3")
@export var finish_stream: AudioStream = preload("res://assets/audio/sfx/race_finish_stinger.mp3")
@export var music_bus: StringName = &"Music"
@export var sfx_bus: StringName = &"SFX"
@export var music_volume_db: float = -12.0
@export var stinger_volume_db: float = -4.0

var _race_manager: Node = null
var _music_player: AudioStreamPlayer = null
var _stinger_player: AudioStreamPlayer = null
var _countdown_played: bool = false


func _ready() -> void:
	_race_manager = get_node_or_null(race_manager_path)
	_music_player = _make_player("RaceMusic", music_stream, String(music_bus), music_volume_db)
	_stinger_player = _make_player("RaceStinger", null, String(sfx_bus), stinger_volume_db)
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
	if _race_manager.has_signal("race_finished"):
		_race_manager.connect("race_finished", _on_race_finished)


func _on_race_phase_changed(_previous_phase: int, new_phase: int) -> void:
	var phase_name: String = ""
	if _race_manager != null and _race_manager.has_method("get_phase_name"):
		phase_name = String(_race_manager.call("get_phase_name")).to_lower()
	if phase_name.is_empty():
		phase_name = "countdown" if new_phase == 1 else ""
	if phase_name == "countdown" and not _countdown_played:
		_countdown_played = true
		_play_stinger(countdown_stream, stinger_volume_db)


func _on_race_finished(_results: Array) -> void:
	_play_stinger(finish_stream, stinger_volume_db)


func _make_player(player_name: String, stream: AudioStream, bus_name: String, volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.stream = stream
	player.bus = bus_name
	player.volume_db = volume_db
	add_child(player)
	return player


func _play_stinger(stream: AudioStream, volume_db: float) -> void:
	if _stinger_player == null or stream == null:
		return
	_stinger_player.stream = stream
	_stinger_player.volume_db = volume_db
	_stinger_player.stop()
	_stinger_player.play()


func _set_stream_loop(stream: AudioStream, should_loop: bool) -> void:
	if stream == null:
		return
	for property: Dictionary in stream.get_property_list():
		if String(property.get("name", "")) == "loop":
			stream.set("loop", should_loop)
			return
