class_name GeneratedPropState
extends Resource

enum AnchorMode {
	NONE,
	ROAD_RELATIVE,
	WORLD_LOCKED,
	SOCKET_LOCKED,
}

enum RoadSide {
	LEFT = -1,
	RIGHT = 1,
}

@export var stable_id: StringName = &""
@export var generator_rule_id: StringName = &""
@export var anchor_distance_m: float = 0.0
@export var road_side: int = RoadSide.RIGHT
@export var lateral_offset_from_road_edge_m: float = 0.0
@export var longitudinal_offset_m: float = 0.0
@export var vertical_offset_m: float = 0.0
@export var yaw_offset_degrees: float = 0.0
@export var manual_override_mode: AnchorMode = AnchorMode.NONE
@export var world_locked_transform: Transform3D = Transform3D.IDENTITY
@export var socket_id: StringName = &""


static func make_stable_id(rule_id: StringName, ordinal: int, suffix: String = "") -> StringName:
	var base: String = _title_identifier(String(rule_id))
	var suffix_text: String = "" if suffix.is_empty() else "_%s" % suffix.strip_edges()
	return StringName("%s_%03d%s" % [base, maxi(ordinal, 0), suffix_text])


static func normalize_road_side(value: int) -> int:
	return RoadSide.LEFT if value < 0 else RoadSide.RIGHT


func has_manual_override() -> bool:
	return manual_override_mode != AnchorMode.NONE


func is_road_relative() -> bool:
	return manual_override_mode == AnchorMode.ROAD_RELATIVE


func is_world_locked() -> bool:
	return manual_override_mode == AnchorMode.WORLD_LOCKED


func is_socket_locked() -> bool:
	return manual_override_mode == AnchorMode.SOCKET_LOCKED


func reset_override() -> void:
	manual_override_mode = AnchorMode.NONE
	lateral_offset_from_road_edge_m = 0.0
	longitudinal_offset_m = 0.0
	vertical_offset_m = 0.0
	yaw_offset_degrees = 0.0
	world_locked_transform = Transform3D.IDENTITY
	socket_id = &""


func set_road_relative(
	new_anchor_distance_m: float,
	new_road_side: int,
	new_lateral_offset_from_road_edge_m: float,
	new_longitudinal_offset_m: float,
	new_vertical_offset_m: float,
	new_yaw_offset_degrees: float
) -> void:
	anchor_distance_m = new_anchor_distance_m
	road_side = normalize_road_side(new_road_side)
	lateral_offset_from_road_edge_m = new_lateral_offset_from_road_edge_m
	longitudinal_offset_m = new_longitudinal_offset_m
	vertical_offset_m = new_vertical_offset_m
	yaw_offset_degrees = new_yaw_offset_degrees
	manual_override_mode = AnchorMode.ROAD_RELATIVE
	socket_id = &""


func set_world_locked(new_world_transform: Transform3D) -> void:
	world_locked_transform = new_world_transform
	manual_override_mode = AnchorMode.WORLD_LOCKED
	socket_id = &""


func set_socket_locked(new_socket_id: StringName) -> void:
	socket_id = new_socket_id
	manual_override_mode = AnchorMode.SOCKET_LOCKED


static func _title_identifier(raw_text: String) -> String:
	var cleaned: String = raw_text.strip_edges()
	if cleaned.is_empty():
		return "Prop"

	cleaned = cleaned.replace("-", "_").replace(" ", "_")
	var parts: PackedStringArray = cleaned.split("_", false)
	var result: String = ""
	for part: String in parts:
		var trimmed: String = part.strip_edges()
		if trimmed.is_empty():
			continue
		result += trimmed.substr(0, 1).to_upper() + trimmed.substr(1).to_lower()

	return "Prop" if result.is_empty() else result
