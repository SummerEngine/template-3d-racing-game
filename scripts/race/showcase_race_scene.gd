class_name ShowcaseRaceScene
extends Node3D

const RaceConfigScript := preload("res://scripts/race/race_config.gd")

@export var track_generator_path: NodePath = ^"World/TrackRoot"
@export var race_manager_path: NodePath = ^"Managers/RaceManager"
@export var player_car_path: NodePath = ^"World/Vehicles/PlayerCar"
@export var npc_cars_root_path: NodePath = ^"World/Vehicles/NpcCars"
@export var auto_start_countdown: bool = true

var _track_query: RefCounted = null
var _track_generator: Node = null
var _race_manager: Node = null
var _player_car: Node3D = null
var _npc_cars_root: Node = null


func _ready() -> void:
	call_deferred("_setup_showcase_race")


func _setup_showcase_race() -> void:
	_resolve_nodes()
	_apply_session_configuration()
	_regenerate_track()
	_place_vehicles()
	_configure_npc_drivers()
	_register_race_participants()


func get_track_query() -> RefCounted:
	return _track_query


func _resolve_nodes() -> void:
	_track_generator = get_node_or_null(track_generator_path)
	_race_manager = get_node_or_null(race_manager_path)
	_player_car = get_node_or_null(player_car_path) as Node3D
	_npc_cars_root = get_node_or_null(npc_cars_root_path)


func _regenerate_track() -> void:
	if _track_generator == null:
		return
	if _track_generator.has_method("regenerate_track"):
		_track_generator.call("regenerate_track")
	if _track_generator.has_method("get_track_query"):
		var query: Variant = _track_generator.call("get_track_query")
		if query is RefCounted:
			_track_query = query


func _place_vehicles() -> void:
	if _track_generator == null or not _track_generator.has_method("place_node_at_spawn"):
		return
	if _player_car != null:
		_track_generator.call("place_node_at_spawn", _player_car, 0)
	_reset_vehicle_motion(_player_car)

	var grid_index: int = 1
	for npc_car: Node3D in _collect_npc_cars():
		_track_generator.call("place_node_at_spawn", npc_car, grid_index)
		_reset_vehicle_motion(npc_car)
		grid_index += 1


func _configure_npc_drivers() -> void:
	var npc_index: int = 0
	var difficulty_hooks: Dictionary = _get_difficulty_hooks()
	for npc_car: Node3D in _collect_npc_cars():
		var driver: Node = npc_car.get_node_or_null("NpcDriver")
		if driver == null:
			npc_index += 1
			continue

		_set_if_property(npc_car, &"driver_path", npc_car.get_path_to(driver))
		_set_if_property(npc_car, &"use_default_player_driver", false)
		_set_if_property(driver, &"vehicle_path", driver.get_path_to(npc_car))
		_set_if_property(driver, &"lane_index", npc_index % 2)
		_set_if_property(driver, &"track_query_provider", _track_query)
		if driver.has_method("set_track_query"):
			driver.call("set_track_query", _track_query)
		_apply_difficulty_to_driver(driver, difficulty_hooks)
		npc_index += 1


func _register_race_participants() -> void:
	if _race_manager == null:
		return
	_connect_race_flow_signals()
	if _race_manager.has_method("set_track_progress_provider"):
		_race_manager.call("set_track_progress_provider", _track_query)
	if _race_manager.has_method("reset_race"):
		_race_manager.call("reset_race")

	if _player_car != null and _race_manager.has_method("register_participant_node"):
		_race_manager.call("register_participant_node", _player_car, "Player", &"player", true)

	var npc_index: int = 0
	for npc_car: Node3D in _collect_npc_cars():
		if _race_manager.has_method("register_npc_slot"):
			_race_manager.call("register_npc_slot", npc_index, npc_car, _npc_display_name(npc_index))
		elif _race_manager.has_method("register_participant_node"):
			_race_manager.call("register_participant_node", npc_car, _npc_display_name(npc_index), StringName("npc_%d" % [npc_index + 1]), false)
		npc_index += 1

	_set_vehicle_controls_enabled(false)
	if auto_start_countdown and _race_manager.has_method("start_countdown"):
		_race_manager.call("start_countdown")
	else:
		_set_vehicle_controls_enabled(true)


func _collect_npc_cars() -> Array[Node3D]:
	var result: Array[Node3D] = []
	if _npc_cars_root == null:
		return result
	for child: Node in _npc_cars_root.get_children():
		var car: Node3D = child as Node3D
		if car != null:
			result.append(car)
	return result


func _reset_vehicle_motion(vehicle: Node3D) -> void:
	if vehicle == null:
		return
	if vehicle is CharacterBody3D:
		var body := vehicle as CharacterBody3D
		body.velocity = Vector3.ZERO


func _connect_race_flow_signals() -> void:
	if _race_manager == null:
		return
	if _race_manager.has_signal("race_started") and not _race_manager.race_started.is_connected(Callable(self, "_on_race_started")):
		_race_manager.race_started.connect(Callable(self, "_on_race_started"))
	if _race_manager.has_signal("race_phase_changed") and not _race_manager.race_phase_changed.is_connected(Callable(self, "_on_race_phase_changed")):
		_race_manager.race_phase_changed.connect(Callable(self, "_on_race_phase_changed"))


func _on_race_started() -> void:
	_set_vehicle_controls_enabled(true)


func _on_race_phase_changed(_previous_phase: int, _new_phase: int) -> void:
	if _race_manager != null and _race_manager.has_method("get_phase_name"):
		var phase_name: String = String(_race_manager.call("get_phase_name")).to_lower()
		if phase_name == "setup" or phase_name == "countdown" or phase_name == "finished":
			_set_vehicle_controls_enabled(false)


func _set_vehicle_controls_enabled(enabled: bool) -> void:
	var vehicles: Array[Node3D] = []
	if _player_car != null:
		vehicles.append(_player_car)
	vehicles.append_array(_collect_npc_cars())
	for vehicle: Node3D in vehicles:
		if vehicle.has_method("set_controls_enabled"):
			vehicle.call("set_controls_enabled", enabled)
		else:
			_set_if_property(vehicle, &"controls_enabled", enabled)


func _npc_display_name(npc_index: int) -> String:
	match npc_index:
		0:
			return "Technician"
		1:
			return "Bully"
		2:
			return "Showoff"
		_:
			return "NPC %d" % [npc_index + 1]


func _set_if_property(target: Object, property_name: StringName, value: Variant) -> void:
	if target == null:
		return
	for property: Dictionary in target.get_property_list():
		if String(property.get("name", "")) == String(property_name):
			target.set(property_name, value)
			return


func _apply_session_configuration() -> void:
	var session: Node = get_node_or_null("/root/GameSession")
	if session == null:
		return

	if _player_car != null and session.has_method("get_car_color"):
		var color_variant: String = str(session.call("get_car_color"))
		if _player_car.has_method("set_car_color_variant"):
			_player_car.call("set_car_color_variant", color_variant)
		else:
			_set_if_property(_player_car, &"car_color_variant", color_variant)

	if _race_manager != null:
		var config: RaceConfig = RaceConfigScript.new()
		if session.has_method("build_race_config"):
			var config_value: Variant = session.call("build_race_config")
			if config_value is RaceConfig:
				config = config_value
		if _race_manager.has_method("configure"):
			_race_manager.call("configure", config)
		else:
			_set_if_property(_race_manager, &"race_config", config)

	if session.has_method("apply_brightness_to_scene"):
		session.call("apply_brightness_to_scene", self)
	if session.has_method("apply_audio_settings"):
		session.call("apply_audio_settings")


func _get_difficulty_hooks() -> Dictionary:
	if _race_manager != null and _race_manager.has_method("get_difficulty_hooks"):
		var hooks_value: Variant = _race_manager.call("get_difficulty_hooks")
		if hooks_value is Dictionary:
			return hooks_value
	return {}


func _apply_difficulty_to_driver(driver: Node, difficulty_hooks: Dictionary) -> void:
	if driver == null or difficulty_hooks.is_empty():
		return
	var npc_skill: Dictionary = difficulty_hooks.get("npc_skill", {})
	var speed_multiplier: float = _get_skill_float(npc_skill, "speed_multiplier", 1.0)
	var precision: float = _get_skill_float(npc_skill, "racing_line_precision", 1.0)
	var turn_width_multiplier: float = _get_skill_float(npc_skill, "turn_width_multiplier", 1.0)
	var assertiveness: float = _get_skill_float(npc_skill, "overtake_assertiveness", 1.0)

	_set_if_property(driver, &"target_speed_ratio", clampf(0.82 * speed_multiplier, 0.35, 1.18))
	_set_if_property(driver, &"lookahead_m", clampf(28.0 * precision, 14.0, 46.0))
	_set_if_property(driver, &"steer_gain", clampf(1.65 * precision, 0.9, 2.4))
	_set_if_property(driver, &"brake_strength", clampf(0.72 * precision, 0.45, 0.95))
	_set_if_property(driver, &"fallback_lane_width_m", clampf(3.5 * turn_width_multiplier, 2.5, 5.25))
	_set_if_property(driver, &"corner_speed_multiplier", clampf(0.58 + (assertiveness - 1.0) * 0.08, 0.46, 0.72))


func _get_skill_float(source: Dictionary, key: String, fallback: float) -> float:
	var value: Variant = source.get(key, fallback)
	if value is float or value is int:
		return float(value)
	return fallback
