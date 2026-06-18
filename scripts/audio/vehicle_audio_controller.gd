class_name VehicleAudioController
extends Node

@export var vehicle_root_path: NodePath = ^".."
@export var engine_stream: AudioStream = preload("res://assets/audio/sfx/engine_loop_arcade.mp3")
@export var engine_idle_stream: AudioStream = preload("res://assets/audio/sfx/engine_hybrid_idle_loop.mp3")
@export var engine_load_stream: AudioStream = preload("res://assets/audio/sfx/engine_hybrid_accel_loop.mp3")
@export var engine_high_rpm_stream: AudioStream = preload("res://assets/audio/sfx/engine_hybrid_high_rpm_loop.mp3")
@export var shift_pop_stream: AudioStream = preload("res://assets/audio/sfx/engine_shift_pop.mp3")
@export var drift_stream: AudioStream = preload("res://assets/audio/sfx/drift_tire_screech.mp3")
@export var bump_stream: AudioStream = preload("res://assets/audio/sfx/car_bump_toy.mp3")
@export var scrape_stream: AudioStream = preload("res://assets/audio/sfx/wall_scrape_sparks.mp3")
@export var audio_bus: StringName = &"Master"
@export var engine_idle_volume_db: float = -13.0
@export var engine_load_volume_db: float = -10.0
@export var engine_high_rpm_volume_db: float = -8.0
@export var drift_max_volume_db: float = -5.0
@export_range(3, 8, 1) var virtual_gear_count: int = 6
@export_category("3D Attenuation")
@export_range(24.0, 260.0, 1.0) var engine_max_distance_m: float = 180.0
@export_range(6.0, 80.0, 1.0) var engine_unit_size_m: float = 34.0
@export_range(12.0, 140.0, 1.0) var effect_max_distance_m: float = 72.0
@export_range(2.0, 48.0, 1.0) var effect_unit_size_m: float = 16.0

var _vehicle: Node3D = null
var _engine_idle_player: AudioStreamPlayer3D = null
var _engine_load_player: AudioStreamPlayer3D = null
var _engine_high_rpm_player: AudioStreamPlayer3D = null
var _shift_pop_player: AudioStreamPlayer3D = null
var _drift_player: AudioStreamPlayer3D = null
var _bump_player: AudioStreamPlayer3D = null
var _scrape_player: AudioStreamPlayer3D = null
var _last_virtual_gear: int = 0


func _ready() -> void:
	_vehicle = get_node_or_null(vehicle_root_path) as Node3D
	if _vehicle == null:
		_vehicle = get_parent() as Node3D
	if _vehicle == null:
		push_warning("VehicleAudioController: no vehicle root found")
		return

	_engine_idle_player = _make_player_3d("EngineIdleLoop", engine_idle_stream if engine_idle_stream != null else engine_stream, true)
	_engine_load_player = _make_player_3d("EngineLoadLoop", engine_load_stream if engine_load_stream != null else engine_stream, true)
	_engine_high_rpm_player = _make_player_3d("EngineHighRpmLoop", engine_high_rpm_stream if engine_high_rpm_stream != null else engine_stream, true)
	_shift_pop_player = _make_player_3d("ShiftPopOneShot", shift_pop_stream, false)
	_drift_player = _make_player_3d("DriftLoop", drift_stream, true)
	_bump_player = _make_player_3d("BumpOneShot", bump_stream, false)
	_scrape_player = _make_player_3d("ScrapeOneShot", scrape_stream, false)
	_connect_vehicle_signals()


func _process(_delta: float) -> void:
	if _vehicle == null:
		return
	var speed_ratio: float = _vehicle_speed_ratio()
	var throttle_ratio: float = _vehicle_throttle_ratio()
	var drift_intensity: float = _vehicle_drift_intensity()
	_update_engine_layers(speed_ratio, throttle_ratio)
	_update_shift_pop(speed_ratio, throttle_ratio)

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


func _update_engine_layers(speed_ratio: float, throttle_ratio: float) -> void:
	speed_ratio = _finite_ratio(speed_ratio)
	throttle_ratio = _finite_ratio(throttle_ratio)
	var load_ratio: float = clampf(throttle_ratio * 0.75 + speed_ratio * 0.35, 0.0, 1.0)
	var high_ratio: float = smoothstep(0.42, 0.92, speed_ratio)

	if _engine_idle_player != null:
		_engine_idle_player.volume_db = lerpf(engine_idle_volume_db, -27.0, speed_ratio)
		_engine_idle_player.pitch_scale = lerpf(0.88, 1.06, speed_ratio)

	if _engine_load_player != null:
		_engine_load_player.volume_db = lerpf(-36.0, engine_load_volume_db, load_ratio)
		_engine_load_player.pitch_scale = lerpf(0.86, 1.28, clampf(speed_ratio * 0.8 + throttle_ratio * 0.45, 0.0, 1.0))

	if _engine_high_rpm_player != null:
		_engine_high_rpm_player.volume_db = lerpf(-42.0, engine_high_rpm_volume_db, high_ratio)
		_engine_high_rpm_player.pitch_scale = lerpf(0.92, 1.38, speed_ratio)


func _update_shift_pop(speed_ratio: float, throttle_ratio: float) -> void:
	speed_ratio = _finite_ratio(speed_ratio)
	throttle_ratio = _finite_ratio(throttle_ratio)
	var gear_count: int = maxi(virtual_gear_count, 1)
	var current_gear: int = clampi(floori(speed_ratio * float(gear_count)), 0, gear_count - 1)
	if current_gear > _last_virtual_gear and throttle_ratio > 0.18 and speed_ratio > 0.12:
		_play_one_shot(_shift_pop_player, -8.0)
	_last_virtual_gear = current_gear


func _make_player_3d(player_name: String, stream: AudioStream, autoplay: bool) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.name = player_name
	player.stream = stream
	player.bus = String(audio_bus)
	var is_engine_layer := player_name.begins_with("Engine")
	player.max_distance = engine_max_distance_m if is_engine_layer else effect_max_distance_m
	player.unit_size = engine_unit_size_m if is_engine_layer else effect_unit_size_m
	player.volume_db = -80.0
	add_child(player)
	_set_stream_loop(player.stream, autoplay)
	if autoplay and player.stream != null:
		player.play()
	return player


func _play_one_shot(player: AudioStreamPlayer3D, volume_db: float) -> void:
	if player == null or player.stream == null:
		return
	volume_db = _finite_db(volume_db, -18.0)
	player.volume_db = volume_db
	player.pitch_scale = randf_range(0.96, 1.05)
	player.stop()
	player.play()


func _vehicle_speed_ratio() -> float:
	if _vehicle != null and _vehicle.has_method("get_speed_ratio"):
		return _finite_ratio(float(_vehicle.call("get_speed_ratio")))
	return 0.0


func _vehicle_throttle_ratio() -> float:
	if _vehicle == null:
		return 0.0
	var value: Variant = _vehicle.get("throttle_amount")
	if value is float or value is int:
		return _finite_ratio(float(value))
	return 0.0


func _vehicle_drift_intensity() -> float:
	if _vehicle != null and _vehicle.has_method("get_drift_intensity"):
		return _finite_ratio(float(_vehicle.call("get_drift_intensity")))
	if _vehicle != null and _vehicle.get("drift_intensity") != null:
		return _finite_ratio(float(_vehicle.get("drift_intensity")))
	return 0.0


func _finite_ratio(value: float, fallback: float = 0.0) -> float:
	if is_nan(value) or is_inf(value):
		return fallback
	return clampf(value, 0.0, 1.0)


func _finite_db(value: float, fallback: float) -> float:
	if is_nan(value) or is_inf(value):
		return fallback
	return value


func _set_stream_loop(stream: AudioStream, should_loop: bool) -> void:
	if stream == null:
		return
	for property: Dictionary in stream.get_property_list():
		if String(property.get("name", "")) == "loop":
			stream.set("loop", should_loop)
			return
