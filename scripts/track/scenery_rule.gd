class_name SceneryRule
extends Resource

enum PlacementMode {
	ROAD_EDGE,
	DISTANCE_BAND,
	CENTERLINE,
}

enum SideMode {
	LEFT,
	RIGHT,
	BOTH,
	ALTERNATING,
}

@export var prop_id: StringName = &""
@export var display_name: String = ""
@export var placement_mode: PlacementMode = PlacementMode.ROAD_EDGE
@export var sides: SideMode = SideMode.BOTH
@export var road_edge_offset_m: float = 24.0
@export var offset_jitter_m: float = 0.0
@export var min_spacing_m: float = 80.0
@export var max_spacing_m: float = 160.0
@export var coverage_ratio_range: Vector2 = Vector2(0.0, 1.0)
@export var scale_multiplier_range: Vector2 = Vector2(1.0, 1.0)
@export var color_tags: PackedStringArray = PackedStringArray()
@export_multiline var notes: String = ""


func side_values() -> PackedFloat32Array:
	var result := PackedFloat32Array()
	match sides:
		SideMode.LEFT:
			result.append(-1.0)
		SideMode.RIGHT:
			result.append(1.0)
		SideMode.BOTH, SideMode.ALTERNATING:
			result.append(-1.0)
			result.append(1.0)
	return result


func edge_lateral_offset(road_width_m: float, jitter_m: float = 0.0) -> float:
	return road_width_m * 0.5 + road_edge_offset_m + clampf(jitter_m, -absf(offset_jitter_m), absf(offset_jitter_m))


func road_edge_position(
	road_center: Vector3,
	road_normal: Vector3,
	road_width_m: float,
	side: float,
	jitter_m: float = 0.0
) -> Vector3:
	var side_sign: float = -1.0 if side < 0.0 else 1.0
	return road_center + road_normal.normalized() * side_sign * edge_lateral_offset(road_width_m, jitter_m)


func coverage_range_clamped() -> Vector2:
	return Vector2(
		clampf(coverage_ratio_range.x, 0.0, 1.0),
		clampf(coverage_ratio_range.y, 0.0, 1.0)
	)
