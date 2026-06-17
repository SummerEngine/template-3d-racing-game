class_name VehicleAudioController
extends Node

@export var vehicle_root_path: NodePath = ^".."
@export var engine_stream: AudioStream = preload("res://assets/audio/sfx/engine_loop_arcade.mp3")
@export var drift_stream: AudioStream = preload("res://assets/audio/sfx/drift_tire_screech.mp3")
@export var bump_stream: AudioStream = preload("res://assets/audio/sfx/car_bump_toy.mp3")
@export var scrape_stream: AudioStream = preload("res://assets/audio/sfx/wall_scrape_sparks.mp3")
@export var audio_bus: StringName = &"Master"
@export var engine_base_volume_db: float = -24.0
@export var engine_fast_volume_db: float = -9.0
@export var drift_max_volume_db: float = -5.0

var _vehicle: Node3D = null
var _engine_player: AudioStreamPlayer3D = null
var _drift_player: AudioStreamPlayer3D = null
var _bump_player: AudioStreamPlayer3D = null
var _scrape_player: AudioStreamPlayer3D = null


func _ready() -> void:
	_vehicle = get_node_or_null(vehicle_root_path) as Node3D
	if _vehicle == null:
		_vehicle = get_parent() as Node3D
	if _vehicle == null:
		push_warning("VehicleAudioController: no vehicle root found")
		return

	_engine_player = _make_player_3d("EngineLoop", engine_stream, true)
	_drift_player = _make_player_3d("DriftLoop", drift_stream, true)
	_bump_player = _make_player_3d("BumpOneShot", bump_stream, false)
	_scrape_player = _make_player_3d("ScrapeOneShot", scrape_stream, false)
	_connect_vehicle_signals()


func _process(_delta: float) -> void:
	if _vehicle == null:
		return
	var speed_ratio: float = _vehicle_speed_ratio()
	var drift_intensity: float = _vehicle_drift_intensity()
	if _engine_player != null:
		_engine_player.volume_db = lerpf(engine_base_volume_db, engine_fast_volume_db, speed_ratio)
		_engine_player.pitch_scale = lerpf(0.82, 1.34, speed_ratio)

	if _drift_player != null:
		if drift_intensity > 0.05:
			if not _drift_player.playing:
				_drift_player.play()
			_drift_player.volume_db = lerpf(-32.0, drift_max_volume_db, drift_intensity)
			_drift_player.pitch_scale = lerpf(0.92, 1.12, drift_intensity)
		elif _drift_player.playing:
			_drift_player.stop()


func _connect_vehicle_signals() -> void:
	if _vehicle.has_signal("wall_scraped"):
		_vehicle.connect("wall_scraped", _on_wall_scraped)
	if _vehicle.has_signal("vehicle_bumped"):
		_vehicle.connect("vehicle_bumped", _on_vehicle_bumped)


func _on_wall_scraped(intensity: float, _contact_position: Vector3, _contact_normal: Vector3) -> void:
	_play_one_shot(_scrape_player, lerpf(-13.0, -3.0, clampf(intensity, 0.0, 1.0)))


func _on_vehicle_bumped(intensity: float, _contact_position: Vector3, _contact_normal: Vector3) -> void:
	_play_one_shot(_bump_player, lerpf(-10.0, 0.0, clampf(intensity, 0.0, 1.0)))


func _make_player_3d(player_name: String, stream: AudioStream, autoplay: bool) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.name = player_name
	player.stream = stream
	player.bus = String(audio_bus)
	player.max_distance = 42.0
	player.unit_size = 10.0
	player.volume_db = -80.0
	add_child(player)
	_set_stream_loop(player.stream, autoplay)
	if autoplay and player.stream != null:
		player.play()
	return player


func _play_one_shot(player: AudioStreamPlayer3D, volume_db: float) -> void:
	if player == null or player.stream == null:
		return
	player.volume_db = volume_db
	player.pitch_scale = randf_range(0.96, 1.05)
	player.stop()
	player.play()


func _vehicle_speed_ratio() -> float:
	if _vehicle != null and _vehicle.has_method("get_speed_ratio"):
		return clampf(float(_vehicle.call("get_speed_ratio")), 0.0, 1.0)
	return 0.0


func _vehicle_drift_intensity() -> float:
	if _vehicle != null and _vehicle.has_method("get_drift_intensity"):
		return clampf(float(_vehicle.call("get_drift_intensity")), 0.0, 1.0)
	if _vehicle != null and _vehicle.get("drift_intensity") != null:
		return clampf(float(_vehicle.get("drift_intensity")), 0.0, 1.0)
	return 0.0


func _set_stream_loop(stream: AudioStream, should_loop: bool) -> void:
	if stream == null:
		return
	for property: Dictionary in stream.get_property_list():
		if String(property.get("name", "")) == "loop":
			stream.set("loop", should_loop)
			return
