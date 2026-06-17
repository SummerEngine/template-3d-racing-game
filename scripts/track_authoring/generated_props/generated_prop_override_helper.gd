class_name GeneratedPropOverrideHelper
extends RefCounted

const GeneratedPropStateScript := preload("res://scripts/track_authoring/generated_props/generated_prop_state.gd")

const EDGE_TRANSFORM_KEY: StringName = &"edge_transform"
const ANCHOR_DISTANCE_KEY: StringName = &"anchor_distance_m"
const ROAD_SIDE_KEY: StringName = &"road_side"
const EPSILON: float = 0.0001


static func store_road_relative_override_from_node(
	prop_node: Node3D,
	state: GeneratedPropStateScript,
	road_edge_provider: Object
) -> bool:
	if prop_node == null:
		return false
	return store_road_relative_override_from_transform(state, prop_node.global_transform, road_edge_provider)


static func store_road_relative_override_from_transform(
	state: GeneratedPropStateScript,
	world_transform: Transform3D,
	road_edge_provider: Object
) -> bool:
	if state == null or road_edge_provider == null:
		return false

	var edge: Dictionary = resolve_edge_for_position(road_edge_provider, world_transform.origin, state)
	if edge.is_empty():
		return false

	var edge_transform: Transform3D = edge[EDGE_TRANSFORM_KEY]
	var local_position: Vector3 = edge_transform.affine_inverse() * world_transform.origin
	state.set_road_relative(
		float(edge[ANCHOR_DISTANCE_KEY]),
		int(edge[ROAD_SIDE_KEY]),
		local_position.x,
		-local_position.z,
		local_position.y,
		measure_yaw_offset_degrees(edge_transform, world_transform)
	)
	return true


static func store_world_locked_override(state: GeneratedPropStateScript, world_transform: Transform3D) -> bool:
	if state == null:
		return false
	state.set_world_locked(world_transform)
	return true


static func build_transform_from_state(
	state: GeneratedPropStateScript,
	road_edge_provider: Object,
	generated_transform: Transform3D = Transform3D.IDENTITY
) -> Transform3D:
	if state == null:
		return generated_transform

	match state.manual_override_mode:
		GeneratedPropStateScript.AnchorMode.WORLD_LOCKED:
			return state.world_locked_transform
		GeneratedPropStateScript.AnchorMode.ROAD_RELATIVE:
			var edge: Dictionary = resolve_edge_for_state(road_edge_provider, state)
			if edge.is_empty():
				return generated_transform
			return compose_road_relative_transform(
				edge[EDGE_TRANSFORM_KEY],
				state.lateral_offset_from_road_edge_m,
				state.longitudinal_offset_m,
				state.vertical_offset_m,
				state.yaw_offset_degrees
			)
		_:
			return generated_transform


static func compose_road_relative_transform(
	edge_transform: Transform3D,
	lateral_offset_from_road_edge_m: float,
	longitudinal_offset_m: float,
	vertical_offset_m: float,
	yaw_offset_degrees: float
) -> Transform3D:
	var origin: Vector3 = (
		edge_transform.origin
		+ edge_transform.basis.x * lateral_offset_from_road_edge_m
		+ edge_transform.basis.y * vertical_offset_m
		- edge_transform.basis.z * longitudinal_offset_m
	)
	var yaw_basis := Basis(Vector3.UP, deg_to_rad(yaw_offset_degrees))
	return Transform3D((edge_transform.basis * yaw_basis).orthonormalized(), origin)


static func measure_yaw_offset_degrees(edge_transform: Transform3D, world_transform: Transform3D) -> float:
	var relative_basis: Basis = edge_transform.basis.inverse() * world_transform.basis
	return rad_to_deg(relative_basis.get_euler().y)


static func resolve_edge_for_state(road_edge_provider: Object, state: GeneratedPropStateScript) -> Dictionary:
	if state == null or road_edge_provider == null:
		return {}
	return _edge_dictionary_for_distance(
		road_edge_provider,
		state.anchor_distance_m,
		state.road_side,
		Vector3.ZERO,
		false
	)


static func resolve_edge_for_position(
	road_edge_provider: Object,
	world_position: Vector3,
	state: GeneratedPropStateScript
) -> Dictionary:
	if road_edge_provider == null:
		return {}

	var preferred_distance_m: float = state.anchor_distance_m if state != null else 0.0
	var preferred_side: int = state.road_side if state != null else GeneratedPropStateScript.RoadSide.RIGHT

	if road_edge_provider.has_method("get_closest_road_edge"):
		var raw_edge: Variant = road_edge_provider.call(
			"get_closest_road_edge",
			world_position,
			preferred_distance_m,
			preferred_side
		)
		var normalized: Dictionary = _normalize_edge_dictionary(raw_edge, preferred_distance_m, preferred_side)
		if not normalized.is_empty():
			return normalized

	if road_edge_provider.has_method("closest_distance_for_position"):
		var distance_m: float = float(road_edge_provider.call("closest_distance_for_position", world_position))
		return _edge_dictionary_for_distance(road_edge_provider, distance_m, preferred_side, world_position, true)

	return _edge_dictionary_for_distance(
		road_edge_provider,
		preferred_distance_m,
		preferred_side,
		world_position,
		false
	)


static func _edge_dictionary_for_distance(
	road_edge_provider: Object,
	anchor_distance_m: float,
	preferred_road_side: int,
	world_position: Vector3,
	choose_nearest_side: bool
) -> Dictionary:
	if road_edge_provider == null:
		return {}

	var road_side: int = GeneratedPropStateScript.normalize_road_side(preferred_road_side)
	if choose_nearest_side:
		road_side = _choose_nearest_road_side(road_edge_provider, anchor_distance_m, world_position, road_side)

	var edge_transform: Transform3D = Transform3D.IDENTITY
	if road_edge_provider.has_method("get_road_edge_transform"):
		edge_transform = road_edge_provider.call("get_road_edge_transform", anchor_distance_m, road_side)
	elif road_edge_provider.has_method("road_edge_transform"):
		edge_transform = road_edge_provider.call("road_edge_transform", anchor_distance_m, road_side)
	elif road_edge_provider.has_method("sample_at_distance") and road_edge_provider.has_method("road_edge_position"):
		edge_transform = _build_edge_transform_from_track_query(road_edge_provider, anchor_distance_m, road_side)
	else:
		return {}

	return {
		ANCHOR_DISTANCE_KEY: anchor_distance_m,
		ROAD_SIDE_KEY: road_side,
		EDGE_TRANSFORM_KEY: edge_transform,
	}


static func _choose_nearest_road_side(
	road_edge_provider: Object,
	anchor_distance_m: float,
	world_position: Vector3,
	fallback_side: int
) -> int:
	if not road_edge_provider.has_method("road_edge_position"):
		return GeneratedPropStateScript.normalize_road_side(fallback_side)

	var left_position: Variant = road_edge_provider.call("road_edge_position", anchor_distance_m, -1.0, 0.0)
	var right_position: Variant = road_edge_provider.call("road_edge_position", anchor_distance_m, 1.0, 0.0)
	if not (left_position is Vector3) or not (right_position is Vector3):
		return GeneratedPropStateScript.normalize_road_side(fallback_side)

	var left_distance_sq: float = world_position.distance_squared_to(left_position)
	var right_distance_sq: float = world_position.distance_squared_to(right_position)
	return GeneratedPropStateScript.RoadSide.LEFT if left_distance_sq < right_distance_sq else GeneratedPropStateScript.RoadSide.RIGHT


static func _build_edge_transform_from_track_query(
	road_edge_provider: Object,
	anchor_distance_m: float,
	road_side: int
) -> Transform3D:
	var sample_variant: Variant = road_edge_provider.call("sample_at_distance", anchor_distance_m)
	if not (sample_variant is Dictionary):
		return Transform3D.IDENTITY

	var sample: Dictionary = sample_variant
	var edge_position_variant: Variant = road_edge_provider.call("road_edge_position", anchor_distance_m, float(road_side), 0.0)
	if not (edge_position_variant is Vector3):
		return Transform3D.IDENTITY

	var road_normal: Vector3 = _dict_vector(sample, &"normal", Vector3.RIGHT)
	var road_tangent: Vector3 = _dict_vector(sample, &"tangent", Vector3.FORWARD)
	var road_up: Vector3 = _dict_vector(sample, &"up", Vector3.UP)

	if road_normal.length_squared() <= EPSILON:
		road_normal = Vector3.RIGHT
	if road_tangent.length_squared() <= EPSILON:
		road_tangent = Vector3.FORWARD
	if road_up.length_squared() <= EPSILON:
		road_up = Vector3.UP

	var side_sign: float = -1.0 if road_side < 0 else 1.0
	var outward: Vector3 = road_normal.normalized() * side_sign
	var back: Vector3 = -road_tangent.normalized()
	var basis := Basis(outward, road_up.normalized(), back).orthonormalized()
	return Transform3D(basis, edge_position_variant)


static func _normalize_edge_dictionary(raw_edge: Variant, fallback_distance_m: float, fallback_side: int) -> Dictionary:
	if not (raw_edge is Dictionary):
		return {}

	var source: Dictionary = raw_edge
	var transform_value: Variant = source.get(EDGE_TRANSFORM_KEY, source.get(&"transform", Transform3D.IDENTITY))
	if not (transform_value is Transform3D):
		return {}

	return {
		ANCHOR_DISTANCE_KEY: float(source.get(ANCHOR_DISTANCE_KEY, source.get(&"distance_m", fallback_distance_m))),
		ROAD_SIDE_KEY: GeneratedPropStateScript.normalize_road_side(int(source.get(ROAD_SIDE_KEY, fallback_side))),
		EDGE_TRANSFORM_KEY: transform_value,
	}


static func _dict_vector(source: Dictionary, key: StringName, fallback: Vector3) -> Vector3:
	var value: Variant = source.get(key, fallback)
	return value if value is Vector3 else fallback
