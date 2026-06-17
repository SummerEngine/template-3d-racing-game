class_name TrackSample
extends RefCounted

# Typed payload behind TrackQueryV2.sample_at_distance().
# Dictionaries returned by the query keep these same field names.

var distance_m: float = 0.0
var ratio: float = 0.0
var segment_index: int = 0
var position: Vector3 = Vector3.ZERO
var tangent: Vector3 = Vector3(0.0, 0.0, 1.0)
var up: Vector3 = Vector3.UP
var right: Vector3 = Vector3.RIGHT
var banking_degrees: float = 0.0
var width_m: float = 12.0
var surface_id: StringName = &"asphalt"
var zone_id: StringName = &"default"


func configure(
	sample_distance_m: float,
	sample_ratio: float,
	sample_segment_index: int,
	sample_position: Vector3,
	sample_tangent: Vector3,
	sample_up: Vector3,
	sample_banking_degrees: float,
	sample_width_m: float,
	sample_surface_id: StringName,
	sample_zone_id: StringName
) -> void:
	distance_m = sample_distance_m
	ratio = sample_ratio
	segment_index = sample_segment_index
	position = sample_position
	tangent = _safe_direction(sample_tangent, Vector3(0.0, 0.0, 1.0))
	up = _safe_up_for_tangent(tangent, sample_up)
	right = right_from_tangent_up(tangent, up)
	banking_degrees = sample_banking_degrees
	width_m = maxf(sample_width_m, 0.1)
	surface_id = sample_surface_id
	zone_id = sample_zone_id


func to_dictionary() -> Dictionary:
	return {
		"distance": distance_m,
		"distance_m": distance_m,
		"ratio": ratio,
		"segment_index": segment_index,
		"position": position,
		"tangent": tangent,
		"up": up,
		"normal": up,
		"right": right,
		"side_normal": right,
		"banking": banking_degrees,
		"banking_degrees": banking_degrees,
		"banking_radians": deg_to_rad(banking_degrees),
		"width": width_m,
		"width_m": width_m,
		"road_width_m": width_m,
		"surface_id": surface_id,
		"surface_type": surface_id,
		"zone_id": zone_id,
	}


func basis() -> Basis:
	return basis_from_tangent_up(tangent, up)


func surface_transform(lateral_offset_m: float = 0.0, vertical_offset_m: float = 0.0) -> Transform3D:
	var origin: Vector3 = position + right * lateral_offset_m + up * vertical_offset_m
	return Transform3D(basis(), origin)


static func basis_from_tangent_up(sample_tangent: Vector3, sample_up: Vector3) -> Basis:
	var forward: Vector3 = _safe_direction(sample_tangent, Vector3(0.0, 0.0, 1.0))
	var resolved_up: Vector3 = _safe_up_for_tangent(forward, sample_up)
	var back: Vector3 = -forward
	var resolved_right: Vector3 = back.cross(resolved_up).normalized()
	if resolved_right.length_squared() <= 0.0001:
		resolved_right = Vector3.RIGHT
	resolved_up = resolved_right.cross(back).normalized()
	return Basis(resolved_right, resolved_up, back).orthonormalized()


static func right_from_tangent_up(sample_tangent: Vector3, sample_up: Vector3) -> Vector3:
	return basis_from_tangent_up(sample_tangent, sample_up).x.normalized()


static func banked_up(sample_tangent: Vector3, base_up: Vector3, sample_banking_degrees: float) -> Vector3:
	var forward: Vector3 = _safe_direction(sample_tangent, Vector3(0.0, 0.0, 1.0))
	var resolved_up: Vector3 = _safe_up_for_tangent(forward, base_up)
	return resolved_up.rotated(forward, deg_to_rad(sample_banking_degrees)).normalized()


static func _safe_direction(value: Vector3, fallback: Vector3) -> Vector3:
	if value.length_squared() <= 0.0001:
		return fallback.normalized()
	return value.normalized()


static func _safe_up_for_tangent(sample_tangent: Vector3, candidate_up: Vector3) -> Vector3:
	var forward: Vector3 = _safe_direction(sample_tangent, Vector3(0.0, 0.0, 1.0))
	var resolved_up: Vector3 = candidate_up
	if resolved_up.length_squared() <= 0.0001:
		resolved_up = Vector3.UP
	resolved_up = resolved_up.normalized()
	resolved_up = resolved_up - forward * resolved_up.dot(forward)
	if resolved_up.length_squared() <= 0.0001:
		resolved_up = Vector3.UP - forward * Vector3.UP.dot(forward)
	if resolved_up.length_squared() <= 0.0001:
		resolved_up = Vector3.RIGHT - forward * Vector3.RIGHT.dot(forward)
	return resolved_up.normalized()
