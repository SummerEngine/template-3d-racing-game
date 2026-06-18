class_name StormCoastPreviewScene
extends Node3D

const RaceConfigScript := preload("res://scripts/race/race_config.gd")

@export_node_path("Node") var track_generator_path: NodePath = ^"World/TrackAuthoring/Generated/StormCoastTrackGenerator"
@export_node_path("Node3D") var player_car_path: NodePath = ^"World/Vehicles/PlayerCar"
@export_node_path("Node") var npc_cars_root_path: NodePath = ^"World/Vehicles/NpcCars"
@export_node_path("Node3D") var camera_rig_path: NodePath = ^"World/CameraRig"
@export_node_path("Node") var race_manager_path: NodePath = ^"Managers/RaceManager"
@export var regenerate_track_on_ready: bool = true
@export var place_player_on_start_grid: bool = true
@export var player_start_slot_index: int = 2
@export var npc_start_slot_indices: Array[int] = [0, 1, 3]
@export var auto_start_countdown: bool = true
@export var print_setup_summary: bool = true
@export var print_floor_probe: bool = true
@export var floor_probe_delay_s: float = 0.8

@export_category("Track Safety")
@export var track_safety_enabled: bool = true
@export_range(0.0, 4.0, 0.1) var road_touch_tolerance_m: float = 0.8
@export_range(0.0, 12.0, 0.25) var offroad_respawn_margin_m: float = 3.5
@export_range(0.0, 3.0, 0.05) var offroad_respawn_delay_s: float = 0.65
@export_range(1.0, 40.0, 0.5) var fall_respawn_depth_m: float = 8.0
@export_range(-0.5, 1.5, 0.05) var respawn_vertical_offset_m: float = -0.08
@export var print_respawn_events: bool = false

var _track_generator: Node = null
var _track_query: RefCounted = null
var _player_car: Node3D = null
var _npc_cars_root: Node = null
var _camera_rig: Node = null
var _race_manager: Node = null
var _last_valid_track_distance_m: float = 0.0
var _offroad_time_s: float = 0.0


func _ready() -> void:
	call_deferred("_setup_preview_scene")


func _setup_preview_scene() -> void:
	_resolve_nodes()
	_apply_session_configuration()
	_regenerate_track()
	_place_vehicles()
	_configure_npc_drivers()
	_register_race_participants()
	_capture_initial_valid_track_position()
	_configure_camera()
	_print_setup_summary()
	_probe_floor_after_delay()


func _physics_process(delta: float) -> void:
	_update_track_safety(delta)


func _resolve_nodes() -> void:
	_track_generator = get_node_or_null(track_generator_path)
	_player_car = get_node_or_null(player_car_path) as Node3D
	_npc_cars_root = get_node_or_null(npc_cars_root_path)
	_camera_rig = get_node_or_null(camera_rig_path)
	_race_manager = get_node_or_null(race_manager_path)


func _regenerate_track() -> void:
	if regenerate_track_on_ready and _track_generator != null and _track_generator.has_method("regenerate_track"):
		_track_generator.call("regenerate_track")
	_resolve_track_query()


func _place_vehicles() -> void:
	if not place_player_on_start_grid or _player_car == null:
		return
	if _track_generator != null and _track_generator.has_method("place_node_at_start_grid"):
		_track_generator.call("place_node_at_start_grid", _player_car, player_start_slot_index)
		_reset_vehicle_motion(_player_car)
		var npc_index: int = 0
		for npc_car: Node3D in _collect_npc_cars():
			var grid_index: int = _npc_start_slot_index(npc_index)
			_track_generator.call("place_node_at_start_grid", npc_car, grid_index)
			_reset_vehicle_motion(npc_car)
			npc_index += 1


func _npc_start_slot_index(npc_index: int) -> int:
	if npc_index >= 0 and npc_index < npc_start_slot_indices.size():
		return int(npc_start_slot_indices[npc_index])
	var grid_index: int = maxi(npc_index, 0)
	if grid_index >= player_start_slot_index:
		grid_index += 1
	return grid_index


func _configure_npc_drivers() -> void:
	_resolve_track_query()
	var difficulty_hooks: Dictionary = _get_difficulty_hooks()
	var npc_index: int = 0
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


func _configure_camera() -> void:
	if _camera_rig == null or _player_car == null:
		return
	if _camera_rig.has_method("set_target"):
		_camera_rig.call("set_target", _player_car)


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


func _collect_npc_cars() -> Array[Node3D]:
	var result: Array[Node3D] = []
	if _npc_cars_root == null:
		return result
	for child: Node in _npc_cars_root.get_children():
		var car: Node3D = child as Node3D
		if car != null:
			result.append(car)
	return result


func _resolve_track_query() -> void:
	if _track_generator != null and _track_generator.has_method("get_track_query"):
		var query: Variant = _track_generator.call("get_track_query")
		if query is RefCounted:
			_track_query = query


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


func _capture_initial_valid_track_position() -> void:
	if _track_generator == null or _player_car == null:
		return
	if _track_generator.has_method("closest_distance_for_position"):
		_last_valid_track_distance_m = float(_track_generator.call("closest_distance_for_position", _player_car.global_position))
		_offroad_time_s = 0.0


func _update_track_safety(delta: float) -> void:
	if not track_safety_enabled or _track_generator == null or _player_car == null:
		return
	if not _track_generator.has_method("closest_distance_for_position"):
		return
	if not _track_generator.has_method("surface_transform"):
		return
	if not _track_generator.has_method("get_road_width_m"):
		return

	var distance_m: float = float(_track_generator.call("closest_distance_for_position", _player_car.global_position))
	var surface_transform: Transform3D = _track_generator.call("surface_transform", distance_m)
	var road_width_m: float = float(_track_generator.call("get_road_width_m", distance_m))
	var local_offset: Vector3 = _player_car.global_position - surface_transform.origin
	var lateral_offset_m: float = absf(local_offset.dot(surface_transform.basis.x.normalized()))
	var vertical_offset_m: float = local_offset.dot(surface_transform.basis.y.normalized())
	var road_half_width_m: float = road_width_m * 0.5
	var touched_road: bool = lateral_offset_m <= road_half_width_m + road_touch_tolerance_m and vertical_offset_m >= -fall_respawn_depth_m

	if touched_road:
		_last_valid_track_distance_m = distance_m
		_offroad_time_s = 0.0
		return

	var far_outside_road: bool = lateral_offset_m > road_half_width_m + offroad_respawn_margin_m
	var fell_below_track: bool = vertical_offset_m < -fall_respawn_depth_m
	if far_outside_road:
		_offroad_time_s += delta
	else:
		_offroad_time_s = maxf(0.0, _offroad_time_s - delta)

	if fell_below_track or _offroad_time_s >= offroad_respawn_delay_s:
		_respawn_player_on_track(fell_below_track)


func _respawn_player_on_track(fell_below_track: bool) -> void:
	if _track_generator == null or _player_car == null:
		return
	if not _track_generator.has_method("surface_transform"):
		return

	var respawn_transform: Transform3D = _track_generator.call(
		"surface_transform",
		_last_valid_track_distance_m,
		0.0,
		respawn_vertical_offset_m
	)
	_player_car.global_transform = respawn_transform
	_reset_vehicle_motion(_player_car)
	_offroad_time_s = 0.0
	if print_respawn_events:
		var reason: String = "fell" if fell_below_track else "offroad"
		print("StormCoastTrackSafety: respawned player reason=%s distance_m=%.1f" % [reason, _last_valid_track_distance_m])


func _print_setup_summary() -> void:
	if not print_setup_summary:
		return

	var track_length_m: float = 0.0
	var start_grid_slots: int = 0
	if _track_generator != null:
		if _track_generator.has_method("get_track_length_m"):
			track_length_m = float(_track_generator.call("get_track_length_m"))
		if _track_generator.has_method("get_track_query"):
			var query: Variant = _track_generator.call("get_track_query")
			if query != null and query.has_method("get_start_grid_slot_count"):
				start_grid_slots = int(query.call("get_start_grid_slot_count"))

	var player_position: Vector3 = _player_car.global_position if _player_car != null else Vector3.ZERO
	print(
			"StormCoastPreviewScene ready: track_length_m=%.1f, start_grid_slots=%d, player_position=%s"
			% [track_length_m, start_grid_slots, str(player_position)]
	)


func _probe_floor_after_delay() -> void:
	if not print_floor_probe:
		return
	if get_tree() == null:
		return
	await get_tree().create_timer(maxf(floor_probe_delay_s, 0.0)).timeout

	var closest_distance_m: float = 0.0
	var surface_y: float = 0.0
	var surface_delta_y: float = 0.0
	var collision_exists: bool = false
	var collision_mode: String = ""
	var ray_hit: bool = false
	var ray_hit_collider: String = ""
	if _track_generator != null:
		var road_collision_body: Node = _track_generator.get_node_or_null("GeneratedStormCoastRoad/RoadCollision")
		collision_exists = road_collision_body != null and road_collision_body.get_child_count() > 0
		if road_collision_body != null:
			collision_mode = str(road_collision_body.get_meta("collision_mode", ""))
		if _player_car != null and _track_generator.has_method("closest_distance_for_position"):
			closest_distance_m = float(_track_generator.call("closest_distance_for_position", _player_car.global_position))
		if _track_generator.has_method("surface_transform"):
			var surface_transform: Transform3D = _track_generator.call("surface_transform", closest_distance_m)
			surface_y = surface_transform.origin.y
			if _player_car != null:
				surface_delta_y = _player_car.global_position.y - surface_y
			var ray_result: Dictionary = _raycast_road_surface(surface_transform.origin)
			ray_hit = not ray_result.is_empty()
			var collider: Object = ray_result.get("collider", null)
			if collider is Node:
				ray_hit_collider = String((collider as Node).name)

	var on_floor: bool = false
	var player_y: float = 0.0
	var player_velocity_y: float = 0.0
	if _player_car is CharacterBody3D:
		var body := _player_car as CharacterBody3D
		on_floor = body.is_on_floor()
		player_y = body.global_position.y
		player_velocity_y = body.velocity.y
	elif _player_car != null:
		player_y = _player_car.global_position.y

	print(
			"StormCoastFloorProbe: collision_exists=%s, collision_mode=%s, ray_hit=%s, ray_hit_collider=%s, on_floor=%s, closest_distance_m=%.1f, player_y=%.3f, surface_y=%.3f, delta_y=%.3f, velocity_y=%.3f"
			% [str(collision_exists), collision_mode, str(ray_hit), ray_hit_collider, str(on_floor), closest_distance_m, player_y, surface_y, surface_delta_y, player_velocity_y]
	)


func _raycast_road_surface(surface_position: Vector3) -> Dictionary:
	if get_world_3d() == null:
		return {}
	var from: Vector3 = surface_position + Vector3.UP * 6.0
	var to: Vector3 = surface_position - Vector3.UP * 6.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1
	query.hit_from_inside = true
	if _player_car is CollisionObject3D:
		query.exclude = [(_player_car as CollisionObject3D).get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query)
