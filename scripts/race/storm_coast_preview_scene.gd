class_name StormCoastPreviewScene
extends Node3D

@export_node_path("Node") var track_generator_path: NodePath = ^"World/TrackAuthoring/Generated/StormCoastTrackGenerator"
@export_node_path("Node3D") var player_car_path: NodePath = ^"World/Vehicles/PlayerCar"
@export_node_path("Node3D") var camera_rig_path: NodePath = ^"World/CameraRig"
@export var regenerate_track_on_ready: bool = true
@export var place_player_on_start_grid: bool = true
@export var player_start_slot_index: int = 0
@export var print_setup_summary: bool = true
@export var print_floor_probe: bool = true
@export var floor_probe_delay_s: float = 0.8

@export_category("Track Safety")
@export var track_safety_enabled: bool = true
@export_range(0.0, 4.0, 0.1) var road_touch_tolerance_m: float = 0.8
@export_range(0.0, 12.0, 0.25) var offroad_respawn_margin_m: float = 3.5
@export_range(0.0, 3.0, 0.05) var offroad_respawn_delay_s: float = 0.65
@export_range(1.0, 40.0, 0.5) var fall_respawn_depth_m: float = 8.0
@export_range(0.1, 3.0, 0.05) var respawn_vertical_offset_m: float = 0.85
@export var print_respawn_events: bool = false

var _track_generator: Node = null
var _player_car: Node3D = null
var _camera_rig: Node = null
var _last_valid_track_distance_m: float = 0.0
var _offroad_time_s: float = 0.0


func _ready() -> void:
	call_deferred("_setup_preview_scene")


func _setup_preview_scene() -> void:
	_resolve_nodes()
	_regenerate_track()
	_place_player()
	_capture_initial_valid_track_position()
	_configure_camera()
	_print_setup_summary()
	_probe_floor_after_delay()


func _physics_process(delta: float) -> void:
	_update_track_safety(delta)


func _resolve_nodes() -> void:
	_track_generator = get_node_or_null(track_generator_path)
	_player_car = get_node_or_null(player_car_path) as Node3D
	_camera_rig = get_node_or_null(camera_rig_path)


func _regenerate_track() -> void:
	if not regenerate_track_on_ready:
		return
	if _track_generator != null and _track_generator.has_method("regenerate_track"):
		_track_generator.call("regenerate_track")


func _place_player() -> void:
	if not place_player_on_start_grid or _player_car == null:
		return
	if _track_generator != null and _track_generator.has_method("place_node_at_start_grid"):
		_track_generator.call("place_node_at_start_grid", _player_car, player_start_slot_index)
		_reset_vehicle_motion(_player_car)


func _configure_camera() -> void:
	if _camera_rig == null or _player_car == null:
		return
	if _camera_rig.has_method("set_target"):
		_camera_rig.call("set_target", _player_car)


func _reset_vehicle_motion(vehicle: Node3D) -> void:
	if vehicle is CharacterBody3D:
		var body := vehicle as CharacterBody3D
		body.velocity = Vector3.ZERO


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
	var ray_hit: bool = false
	var ray_hit_collider: String = ""
	if _track_generator != null:
		collision_exists = _track_generator.get_node_or_null("GeneratedStormCoastRoad/RoadCollision/CollisionShape3D") != null
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
			"StormCoastFloorProbe: collision_exists=%s, ray_hit=%s, ray_hit_collider=%s, on_floor=%s, closest_distance_m=%.1f, player_y=%.3f, surface_y=%.3f, delta_y=%.3f, velocity_y=%.3f"
			% [str(collision_exists), str(ray_hit), ray_hit_collider, str(on_floor), closest_distance_m, player_y, surface_y, surface_delta_y, player_velocity_y]
	)


func _raycast_road_surface(surface_position: Vector3) -> Dictionary:
	if get_world_3d() == null:
		return {}
	var from: Vector3 = surface_position + Vector3.UP * 6.0
	var to: Vector3 = surface_position - Vector3.UP * 6.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1
	query.hit_from_inside = true
	return get_world_3d().direct_space_state.intersect_ray(query)
