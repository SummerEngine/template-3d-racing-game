class_name GeneratedPropValidator
extends RefCounted

const GeneratedPropOverrideHelperScript := preload("res://scripts/track_authoring/generated_props/generated_prop_override_helper.gd")
const GeneratedPropStateScript := preload("res://scripts/track_authoring/generated_props/generated_prop_state.gd")

const ISSUE_INSIDE_ROAD: StringName = &"inside_road"
const DEFAULT_MINIMUM_CLEARANCE_M: float = 0.25


static func validate_node(
	prop_node: Node3D,
	state: GeneratedPropStateScript,
	road_edge_provider: Object,
	minimum_clearance_m: float = DEFAULT_MINIMUM_CLEARANCE_M
) -> Dictionary:
	if prop_node == null:
		return _invalid_result(state, PackedStringArray([String(ISSUE_INSIDE_ROAD)]), Transform3D.IDENTITY)
	return validate_transform(state, prop_node.global_transform, road_edge_provider, minimum_clearance_m)


static func validate_state(
	state: GeneratedPropStateScript,
	road_edge_provider: Object,
	minimum_clearance_m: float = DEFAULT_MINIMUM_CLEARANCE_M
) -> Dictionary:
	var transform: Transform3D = GeneratedPropOverrideHelperScript.build_transform_from_state(
		state,
		road_edge_provider,
		state.world_locked_transform if state != null else Transform3D.IDENTITY
	)
	return validate_transform(state, transform, road_edge_provider, minimum_clearance_m)


static func validate_transform(
	state: GeneratedPropStateScript,
	world_transform: Transform3D,
	road_edge_provider: Object,
	minimum_clearance_m: float = DEFAULT_MINIMUM_CLEARANCE_M
) -> Dictionary:
	if state == null or road_edge_provider == null:
		return _invalid_result(state, PackedStringArray([String(ISSUE_INSIDE_ROAD)]), world_transform)

	var edge: Dictionary = GeneratedPropOverrideHelperScript.resolve_edge_for_position(
		road_edge_provider,
		world_transform.origin,
		state
	)
	if edge.is_empty():
		return _invalid_result(state, PackedStringArray([String(ISSUE_INSIDE_ROAD)]), world_transform)

	var edge_transform: Transform3D = edge[GeneratedPropOverrideHelperScript.EDGE_TRANSFORM_KEY]
	var local_position: Vector3 = edge_transform.affine_inverse() * world_transform.origin
	var lateral_offset_m: float = local_position.x
	var issues := PackedStringArray()
	if lateral_offset_m < minimum_clearance_m:
		issues.append(String(ISSUE_INSIDE_ROAD))

	var snap_lateral_offset_m: float = maxf(lateral_offset_m, minimum_clearance_m)
	var snap_back_transform: Transform3D = GeneratedPropOverrideHelperScript.compose_road_relative_transform(
		edge_transform,
		snap_lateral_offset_m,
		-local_position.z,
		local_position.y,
		GeneratedPropOverrideHelperScript.measure_yaw_offset_degrees(edge_transform, world_transform)
	)

	return {
		"valid": issues.is_empty(),
		"issues": issues,
		"stable_id": state.stable_id,
		"generator_rule_id": state.generator_rule_id,
		"anchor_distance_m": float(edge[GeneratedPropOverrideHelperScript.ANCHOR_DISTANCE_KEY]),
		"road_side": int(edge[GeneratedPropOverrideHelperScript.ROAD_SIDE_KEY]),
		"lateral_offset_from_road_edge_m": lateral_offset_m,
		"snap_back_transform": snap_back_transform,
	}


static func is_inside_road(validation_result: Dictionary) -> bool:
	var issues: PackedStringArray = validation_result.get("issues", PackedStringArray())
	return issues.has(String(ISSUE_INSIDE_ROAD))


static func snap_back_transform(validation_result: Dictionary) -> Transform3D:
	var value: Variant = validation_result.get("snap_back_transform", Transform3D.IDENTITY)
	return value if value is Transform3D else Transform3D.IDENTITY


static func _invalid_result(
	state: GeneratedPropStateScript,
	issues: PackedStringArray,
	fallback_transform: Transform3D
) -> Dictionary:
	return {
		"valid": false,
		"issues": issues,
		"stable_id": state.stable_id if state != null else &"",
		"generator_rule_id": state.generator_rule_id if state != null else &"",
		"anchor_distance_m": state.anchor_distance_m if state != null else 0.0,
		"road_side": state.road_side if state != null else GeneratedPropStateScript.RoadSide.RIGHT,
		"lateral_offset_from_road_edge_m": 0.0,
		"snap_back_transform": fallback_transform,
	}
