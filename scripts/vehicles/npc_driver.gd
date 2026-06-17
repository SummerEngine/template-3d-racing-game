class_name NpcDriver
extends Node

const VehicleCommandScript := preload("res://scripts/vehicles/vehicle_command.gd")

@export_category("References")
@export var vehicle_path: NodePath = NodePath("")
@export var track_query_path: NodePath = NodePath("")

@export_category("Identity")
@export var personality_id: StringName = &"technician"
@export var lane_index: int = 0

@export_category("Driving")
@export_range(0.0, 1.25, 0.01) var target_speed_ratio: float = 0.82
@export_range(1.0, 120.0, 0.5) var lookahead_m: float = 28.0
@export_range(0.0, 6.0, 0.05) var steer_gain: float = 1.65
@export_range(0.0, 90.0, 1.0) var brake_angle_threshold: float = 34.0
@export_range(0.0, 90.0, 1.0) var drift_angle_threshold: float = 42.0
@export_range(0.1, 1.5, 0.01) var corner_speed_multiplier: float = 0.58
@export_range(0.0, 40.0, 0.5) var drift_min_speed_mps: float = 14.0

@export_category("Difficulty Hooks")
@export_range(0.1, 1.5, 0.01) var catchup_multiplier: float = 1.0
@export_range(0.0, 1.0, 0.01) var brake_strength: float = 0.72
@export_range(0.0, 8.0, 0.1) var fallback_lane_width_m: float = 3.5

var _command: RefCounted = VehicleCommandScript.new()
var _vehicle: Node3D = null
var _track_query: Object = null


func get_command() -> RefCounted:
	return _sample_command()


func write_command(target_command: RefCounted) -> void:
	if target_command == null:
		return

	_sample_command()

	if target_command.get_script() == VehicleCommandScript:
		var typed_command: RefCounted = target_command
		typed_command.copy_from(_command)
	elif target_command.has_method("copy_from"):
		target_command.call("copy_from", _command)


func set_vehicle(vehicle: Node3D) -> void:
	_vehicle = vehicle


func set_track_query(track_query: Object) -> void:
	_track_query = track_query if _has_track_navigation_api(track_query) else null


func _sample_command() -> RefCounted:
	var vehicle: Node3D = _resolve_vehicle()
	var track_query: Object = _resolve_track_query()
	if vehicle == null or track_query == null:
		return _command.clear()

	var vehicle_position: Vector3 = vehicle.global_position
	var current_distance_m: float = _closest_distance_for_position(track_query, vehicle_position)
	var speed_ratio: float = _vehicle_speed_ratio(vehicle)
	var speed_mps: float = _vehicle_speed_mps(vehicle)
	var lookahead_distance_m: float = current_distance_m + lookahead_m * lerpf(0.85, 1.35, speed_ratio)
	var target_sample: Dictionary = _lane_target_sample(track_query, lookahead_distance_m)
	if not bool(target_sample.get("valid", false)):
		return _command.clear()
	var target_position: Vector3 = target_sample["position"]

	var forward: Vector3 = _flat_vehicle_forward(vehicle)
	var target_direction: Vector3 = target_position - vehicle_position
	target_direction.y = 0.0
	if target_direction.length_squared() <= 0.0001:
		return _command.clear()
	target_direction = target_direction.normalized()

	var signed_angle_rad: float = forward.signed_angle_to(target_direction, Vector3.UP)
	var angle_abs_degrees: float = absf(rad_to_deg(signed_angle_rad))
	var steer: float = clampf(-signed_angle_rad * steer_gain * _personality_steer_multiplier(), -1.0, 1.0)
	var desired_speed_ratio: float = _desired_speed_ratio_for_angle(angle_abs_degrees)
	var throttle: float = _throttle_for_speed(speed_ratio, desired_speed_ratio, angle_abs_degrees)
	var brake: float = _brake_for_speed(speed_ratio, desired_speed_ratio, angle_abs_degrees)
	var drift: bool = angle_abs_degrees >= _drift_threshold_degrees() \
			and speed_mps >= drift_min_speed_mps \
			and absf(steer) >= 0.35

	return _command.set_values(throttle, brake, steer, drift)


func _resolve_vehicle() -> Node3D:
	if _vehicle != null and is_instance_valid(_vehicle):
		return _vehicle

	_vehicle = null
	if not String(vehicle_path).is_empty():
		var path_vehicle: Node = get_node_or_null(vehicle_path)
		if path_vehicle is Node3D:
			_vehicle = path_vehicle as Node3D

	if _vehicle == null:
		var parent_node: Node = get_parent()
		if parent_node is Node3D:
			_vehicle = parent_node as Node3D

	return _vehicle


func _resolve_track_query() -> Object:
	if _track_query != null and is_instance_valid(_track_query):
		return _track_query

	_track_query = null
	if not String(track_query_path).is_empty():
		_track_query = _extract_track_query(get_node_or_null(track_query_path))

	if _track_query == null and get_tree() != null:
		_track_query = _extract_track_query(get_tree().current_scene)

	return _track_query


func _extract_track_query(candidate: Object) -> Object:
	if _has_track_navigation_api(candidate):
		return candidate
	if candidate == null:
		return null

	if candidate.has_method("get_track_query"):
		var method_value: Variant = candidate.call("get_track_query")
		if method_value is Object and _has_track_navigation_api(method_value):
			return method_value

	if _has_property(candidate, &"track_query"):
		var property_value: Variant = candidate.get("track_query")
		if property_value is Object and _has_track_navigation_api(property_value):
			return property_value

	return null


func _has_track_navigation_api(candidate: Object) -> bool:
	return candidate != null \
			and candidate.has_method("closest_distance_for_position") \
			and (
					candidate.has_method("lane_transform")
					or candidate.has_method("transform_at_distance")
					or candidate.has_method("sample_at_distance")
			)


func _has_property(candidate: Object, property_name: StringName) -> bool:
	if candidate == null:
		return false
	for property: Dictionary in candidate.get_property_list():
		if String(property.get("name", "")) == String(property_name):
			return true
	return false


func _closest_distance_for_position(track_query: Object, position: Vector3) -> float:
	var value: Variant = track_query.call("closest_distance_for_position", position)
	var distance_m: float = float(value) if value is float or value is int else 0.0
	var track_length_m: float = _track_length_m(track_query)
	if track_length_m > 0.0:
		return fposmod(distance_m, track_length_m)
	return maxf(distance_m, 0.0)


func _lane_target_sample(track_query: Object, distance_m: float) -> Dictionary:
	if track_query.has_method("lane_transform"):
		var lane_value: Variant = track_query.call("lane_transform", distance_m, lane_index)
		if lane_value is Transform3D:
			return {
				"valid": true,
				"position": lane_value.origin,
			}

	if track_query.has_method("transform_at_distance"):
		var offset_m: float = float(lane_index) * fallback_lane_width_m
		var transform_value: Variant = track_query.call("transform_at_distance", distance_m, offset_m)
		if transform_value is Transform3D:
			return {
				"valid": true,
				"position": transform_value.origin,
			}

	if track_query.has_method("sample_at_distance"):
		var sample_value: Variant = track_query.call("sample_at_distance", distance_m)
		if sample_value is Dictionary:
			var sample: Dictionary = sample_value
			var position_value: Variant = sample.get("position", Vector3.ZERO)
			if position_value is Vector3:
				var position: Vector3 = position_value
				var normal_value: Variant = sample.get("normal", Vector3.ZERO)
				if normal_value is Vector3:
					position += normal_value.normalized() * float(lane_index) * fallback_lane_width_m
				return {
					"valid": true,
					"position": position,
				}

	return {
		"valid": false,
		"position": Vector3.ZERO,
	}


func _track_length_m(track_query: Object) -> float:
	if track_query.has_method("get_track_length_m"):
		var track_query_length: Variant = track_query.call("get_track_length_m")
		if track_query_length is float or track_query_length is int:
			return maxf(float(track_query_length), 0.0)

	if track_query.has_method("get_length_m"):
		var path_length: Variant = track_query.call("get_length_m")
		if path_length is float or path_length is int:
			return maxf(float(path_length), 0.0)

	return 0.0


func _desired_speed_ratio_for_angle(angle_abs_degrees: float) -> float:
	var personality_speed: float = target_speed_ratio * catchup_multiplier * _personality_speed_multiplier()
	var base_ratio: float = clampf(personality_speed, 0.05, 1.25)
	if angle_abs_degrees <= brake_angle_threshold:
		return base_ratio

	var corner_weight: float = inverse_lerp(brake_angle_threshold, 90.0, angle_abs_degrees)
	return base_ratio * lerpf(1.0, corner_speed_multiplier, clampf(corner_weight, 0.0, 1.0))


func _throttle_for_speed(speed_ratio: float, desired_speed_ratio: float, angle_abs_degrees: float) -> float:
	if angle_abs_degrees >= 82.0:
		return 0.0
	if speed_ratio > desired_speed_ratio + 0.05:
		return 0.0
	return clampf(0.45 + (desired_speed_ratio - speed_ratio) * 2.4, 0.0, 1.0)


func _brake_for_speed(speed_ratio: float, desired_speed_ratio: float, angle_abs_degrees: float) -> float:
	var angle_brake: float = 0.0
	if angle_abs_degrees > brake_angle_threshold:
		angle_brake = inverse_lerp(brake_angle_threshold, 90.0, angle_abs_degrees)

	var speed_brake: float = 0.0
	if speed_ratio > desired_speed_ratio + 0.03:
		speed_brake = (speed_ratio - desired_speed_ratio) * 2.6

	return clampf(maxf(angle_brake, speed_brake) * brake_strength, 0.0, 1.0)


func _vehicle_speed_ratio(vehicle: Node3D) -> float:
	if vehicle.has_method("get_speed_ratio"):
		var ratio_value: Variant = vehicle.call("get_speed_ratio")
		if ratio_value is float or ratio_value is int:
			return clampf(float(ratio_value), 0.0, 1.5)

	var max_speed_mps: float = 1.0
	var max_speed_value: Variant = vehicle.get("max_speed")
	if max_speed_value is float or max_speed_value is int:
		max_speed_mps = maxf(float(max_speed_value), 1.0)

	return clampf(_vehicle_speed_mps(vehicle) / max_speed_mps, 0.0, 1.5)


func _vehicle_speed_mps(vehicle: Node3D) -> float:
	if vehicle.has_method("get_speed"):
		var speed_value: Variant = vehicle.call("get_speed")
		if speed_value is float or speed_value is int:
			return maxf(float(speed_value), 0.0)

	if vehicle is CharacterBody3D:
		var body: CharacterBody3D = vehicle as CharacterBody3D
		return Vector3(body.velocity.x, 0.0, body.velocity.z).length()

	return 0.0


func _flat_vehicle_forward(vehicle: Node3D) -> Vector3:
	var forward: Vector3 = -vehicle.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.0001:
		return Vector3(0.0, 0.0, -1.0)
	return forward.normalized()


func _personality_speed_multiplier() -> float:
	match personality_id:
		&"technician":
			return 0.96
		&"bully":
			return 1.04
		&"showoff":
			return 1.0
		_:
			return 1.0


func _personality_steer_multiplier() -> float:
	match personality_id:
		&"technician":
			return 0.92
		&"bully":
			return 1.08
		&"showoff":
			return 1.0
		_:
			return 1.0


func _drift_threshold_degrees() -> float:
	match personality_id:
		&"technician":
			return drift_angle_threshold + 12.0
		&"showoff":
			return maxf(8.0, drift_angle_threshold - 10.0)
		_:
			return drift_angle_threshold
