class_name GeneratedPropRoadEdgeProvider
extends RefCounted

const GeneratedPropStateScript := preload("res://scripts/track_authoring/generated_props/generated_prop_state.gd")

const EDGE_TRANSFORM_KEY: StringName = &"edge_transform"
const ANCHOR_DISTANCE_KEY: StringName = &"anchor_distance_m"
const ROAD_SIDE_KEY: StringName = &"road_side"


# Edge frames use local +X away from road center, +Y road up, and local -Z along road forward.
func get_road_edge_transform(anchor_distance_m: float, road_side: int) -> Transform3D:
	var _unused_distance: float = anchor_distance_m
	var _unused_side: int = road_side
	return Transform3D.IDENTITY


func get_closest_road_edge(
	world_position: Vector3,
	preferred_anchor_distance_m: float = 0.0,
	preferred_road_side: int = GeneratedPropStateScript.RoadSide.RIGHT
) -> Dictionary:
	var _unused_position: Vector3 = world_position
	var safe_side: int = GeneratedPropStateScript.normalize_road_side(preferred_road_side)
	return {
		ANCHOR_DISTANCE_KEY: preferred_anchor_distance_m,
		ROAD_SIDE_KEY: safe_side,
		EDGE_TRANSFORM_KEY: get_road_edge_transform(preferred_anchor_distance_m, safe_side),
	}
