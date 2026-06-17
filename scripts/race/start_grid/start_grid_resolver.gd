class_name StartGridResolver
extends RefCounted

const DEFAULT_FORWARD: Vector3 = Vector3(0.0, 0.0, 1.0)
const DEFAULT_UP: Vector3 = Vector3.UP
const DEFAULT_VERTICAL_OFFSET_M: float = 0.14


static func is_valid_track_query(track_query: Object) -> bool:
	return track_query != null and (
			track_query.has_method("sample_at_distance")
			or track_query.has_method("surface_transform")
			or track_query.has_method("transform_at_distance")
			or track_query.has_method("lane_transform")
			or track_query.has_method("get_spawn_transform")
	)


static func get_slot_transforms(track_query: Object, profile: Resource) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	if profile == null:
		return result

	var slot_count: int = int(profile.call("get_effective_slot_count"))
	for slot_index: int in range(slot_count):
		result.append(get_slot_transform(track_query, profile, slot_index))
	return result


static func get_slot_transform(track_query: Object, profile: Resource, slot_index: int) -> Transform3D:
	if profile == null or slot_index < 0:
		return Transform3D.IDENTITY

	var track_length_m: float = _track_length_m(track_query)
	var distance_m: float = float(profile.call("get_slot_distance_m", slot_index, track_length_m))
	var sample: Dictionary = _sample_at_distance(track_query, distance_m)
	var road_width_m: float = _road_width_m(track_query, sample, distance_m)
	var lateral_offset_m: float = float(profile.call("get_slot_lateral_offset_m", slot_index, road_width_m))
	var vertical_offset_m: float = _profile_float(profile, &"slot_vertical_offset_m", DEFAULT_VERTICAL_OFFSET_M)

	if not sample.is_empty():
		return _transform_from_sample(sample, lateral_offset_m, vertical_offset_m)

	var surface_transform: Transform3D = _call_transform_method(
			track_query,
			&"surface_transform",
			distance_m,
			lateral_offset_m,
			vertical_offset_m
	)
	if surface_transform != Transform3D.IDENTITY:
		return surface_transform

	var path_transform: Transform3D = _call_transform_method(
			track_query,
			&"transform_at_distance",
			distance_m,
			lateral_offset_m,
			vertical_offset_m
	)
	if path_transform != Transform3D.IDENTITY:
		return path_transform

	if track_query != null and track_query.has_method("lane_transform"):
		var lane_value: Variant = track_query.call("lane_transform", distance_m, int(profile.call("get_slot_column", slot_index)))
		if lane_value is Transform3D:
			var lane_transform: Transform3D = lane_value
			lane_transform.origin += lane_transform.basis.y.normalized() * vertical_offset_m
			return lane_transform

	if track_query != null and track_query.has_method("get_spawn_transform"):
		var spawn_value: Variant = track_query.call("get_spawn_transform", slot_index)
		if spawn_value is Transform3D:
			return spawn_value

	return Transform3D.IDENTITY


static func get_slot_descriptor(track_query: Object, profile: Resource, slot_index: int) -> Dictionary:
	if profile == null:
		return {}

	var track_length_m: float = _track_length_m(track_query)
	var distance_m: float = float(profile.call("get_slot_distance_m", slot_index, track_length_m))
	var sample: Dictionary = _sample_at_distance(track_query, distance_m)
	var road_width_m: float = _road_width_m(track_query, sample, distance_m)
	return {
		"slot_index": slot_index,
		"row": int(profile.call("get_slot_row", slot_index)),
		"column": int(profile.call("get_slot_column", slot_index)),
		"distance_m": distance_m,
		"road_width_m": road_width_m,
		"local_offset": profile.call("get_slot_local_offset", slot_index, road_width_m),
		"transform": get_slot_transform(track_query, profile, slot_index),
	}


static func _transform_from_sample(sample: Dictionary, lateral_offset_m: float, vertical_offset_m: float) -> Transform3D:
	var position: Vector3 = _sample_position(sample)
	var axes: Dictionary = _sample_axes(sample)
	var forward: Vector3 = axes["forward"]
	var up: Vector3 = axes["up"]
	var lateral: Vector3 = axes["lateral"]
	var origin: Vector3 = position + lateral * lateral_offset_m + up * vertical_offset_m
	return Transform3D(_basis_from_forward_up(forward, up), origin)


static func _sample_at_distance(track_query: Object, distance_m: float) -> Dictionary:
	if track_query == null or not track_query.has_method("sample_at_distance"):
		return {}

	var value: Variant = track_query.call("sample_at_distance", distance_m)
	if value is Dictionary:
		return value
	return {}


static func _sample_position(sample: Dictionary) -> Vector3:
	var transform_value: Variant = sample.get("transform", null)
	if transform_value is Transform3D:
		return transform_value.origin

	var position_value: Variant = sample.get("position", null)
	if position_value is Vector3:
		return position_value
	return Vector3.ZERO


static func _sample_axes(sample: Dictionary) -> Dictionary:
	var transform_value: Variant = sample.get("transform", null)
	if transform_value is Transform3D:
		var transform: Transform3D = transform_value
		return {
			"forward": _safe_normalized(-transform.basis.z, DEFAULT_FORWARD),
			"up": _safe_normalized(transform.basis.y, DEFAULT_UP),
			"lateral": _safe_normalized(transform.basis.x, Vector3.RIGHT),
		}

	var forward: Vector3 = _first_axis(sample, ["forward", "tangent", "direction"], DEFAULT_FORWARD)
	var normal_value: Variant = _first_vector(sample, ["surface_normal", "up", "road_up"])
	var lateral_value: Variant = _first_vector(sample, ["right", "lateral", "road_right", "road_normal"])
	var normal_axis_value: Variant = sample.get("normal", null)

	var up: Vector3 = DEFAULT_UP
	var lateral: Vector3 = Vector3.ZERO
	if normal_value is Vector3:
		up = _safe_normalized(normal_value, DEFAULT_UP)

	if lateral_value is Vector3:
		lateral = _safe_normalized(lateral_value, Vector3.ZERO)
	elif normal_axis_value is Vector3:
		var normal_axis: Vector3 = _safe_normalized(normal_axis_value, Vector3.ZERO)
		if absf(normal_axis.dot(DEFAULT_UP)) > 0.55:
			up = normal_axis
		else:
			lateral = normal_axis

	if lateral.length_squared() <= 0.0001:
		lateral = _safe_normalized(up.cross(forward), Vector3.RIGHT)
	if up.length_squared() <= 0.0001 or absf(up.dot(forward)) > 0.98:
		up = _safe_normalized(forward.cross(lateral), DEFAULT_UP)

	return {
		"forward": _safe_normalized(forward, DEFAULT_FORWARD),
		"up": _safe_normalized(up, DEFAULT_UP),
		"lateral": _safe_normalized(lateral, Vector3.RIGHT),
	}


static func _basis_from_forward_up(forward: Vector3, up: Vector3) -> Basis:
	var safe_forward: Vector3 = _safe_normalized(forward, DEFAULT_FORWARD)
	var safe_up: Vector3 = _safe_normalized(up, DEFAULT_UP)
	if absf(safe_forward.dot(safe_up)) > 0.98:
		safe_up = DEFAULT_UP

	var back: Vector3 = -safe_forward
	var basis_right: Vector3 = _safe_normalized(back.cross(safe_up), Vector3.RIGHT)
	var basis_up: Vector3 = _safe_normalized(basis_right.cross(back), safe_up)
	return Basis(basis_right, basis_up, back).orthonormalized()


static func _road_width_m(track_query: Object, sample: Dictionary, distance_m: float) -> float:
	for key: String in ["road_width_m", "road_width", "width_m", "width"]:
		var sample_value: Variant = sample.get(key, null)
		if sample_value is float or sample_value is int:
			return maxf(0.0, float(sample_value))

	if track_query != null and track_query.has_method("get_road_width_m"):
		var arg_count: int = _method_arg_count(track_query, &"get_road_width_m")
		var value: Variant = null
		if arg_count >= 1:
			value = track_query.call("get_road_width_m", distance_m)
		else:
			value = track_query.call("get_road_width_m")
		if value is float or value is int:
			return maxf(0.0, float(value))

	return -1.0


static func _track_length_m(track_query: Object) -> float:
	if track_query == null:
		return 0.0

	for method_name: StringName in [&"get_track_length_m", &"get_length_m"]:
		if track_query.has_method(method_name):
			var value: Variant = track_query.call(method_name)
			if value is float or value is int:
				return maxf(0.0, float(value))
	return 0.0


static func _call_transform_method(
		track_query: Object,
		method_name: StringName,
		distance_m: float,
		lateral_offset_m: float,
		vertical_offset_m: float
) -> Transform3D:
	if track_query == null or not track_query.has_method(method_name):
		return Transform3D.IDENTITY

	var arg_count: int = _method_arg_count(track_query, method_name)
	var value: Variant = null
	if arg_count >= 3:
		value = track_query.call(method_name, distance_m, lateral_offset_m, vertical_offset_m)
	elif arg_count == 2:
		value = track_query.call(method_name, distance_m, lateral_offset_m)
	elif arg_count == 1:
		value = track_query.call(method_name, distance_m)
	else:
		return Transform3D.IDENTITY

	if value is Transform3D:
		return value
	return Transform3D.IDENTITY


static func _method_arg_count(target: Object, method_name: StringName) -> int:
	if target == null:
		return -1

	for method: Dictionary in target.get_method_list():
		if String(method.get("name", "")) == String(method_name):
			var args_value: Variant = method.get("args", [])
			if args_value is Array:
				var args: Array = args_value
				return args.size()
	return -1


static func _profile_float(profile: Resource, property_name: StringName, fallback: float) -> float:
	if profile == null:
		return fallback
	var value: Variant = profile.get(property_name)
	if value is float or value is int:
		return float(value)
	return fallback


static func _first_axis(sample: Dictionary, keys: Array, fallback: Vector3) -> Vector3:
	var value: Variant = _first_vector(sample, keys)
	if value is Vector3:
		return _safe_normalized(value, fallback)
	return fallback


static func _first_vector(sample: Dictionary, keys: Array) -> Variant:
	for key: String in keys:
		var value: Variant = sample.get(key, null)
		if value is Vector3:
			return value
	return null


static func _safe_normalized(value: Vector3, fallback: Vector3) -> Vector3:
	if value.length_squared() <= 0.0001:
		return fallback
	return value.normalized()
