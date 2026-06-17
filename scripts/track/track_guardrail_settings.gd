class_name TrackGuardrailSettings
extends Resource

@export var enabled: bool = true
@export var center_offset_from_road_edge_m: float = 0.55
@export var thickness_m: float = 0.55
@export var height_m: float = 1.15
@export var post_spacing_m: float = 24.0
@export var post_size_m: float = 0.42
@export var material_key: StringName = &"guardrail_metal"
@export var color: Color = Color(0.58, 0.6, 0.57, 1.0)


func center_offset_from_centerline_m(road_width_m: float) -> float:
	return road_width_m * 0.5 + center_offset_from_road_edge_m
