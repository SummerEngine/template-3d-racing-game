@tool
class_name TrackAuthoringMarker
extends Marker3D

@export var marker_id: StringName = &""
@export var display_name: String = ""
@export var authoring_order: int = 0
@export_range(0.0, 10000.0, 0.1) var road_distance_m: float = 0.0
@export var enabled: bool = true
@export_multiline var notes: String = ""


func get_marker_kind() -> StringName:
	return &"marker"


func is_authoring_enabled() -> bool:
	return enabled


func get_authoring_position() -> Vector3:
	if is_inside_tree():
		return global_position
	return position


func get_authoring_record() -> Dictionary:
	return {
		"kind": get_marker_kind(),
		"marker_id": marker_id,
		"display_name": display_name,
		"authoring_order": authoring_order,
		"road_distance_m": road_distance_m,
		"enabled": enabled,
		"local_position": position,
		"world_position": get_authoring_position(),
		"notes": notes,
	}


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if String(marker_id).is_empty():
		warnings.append("Set marker_id so generated or baked data can refer to this marker stably.")
	if not enabled:
		warnings.append("This marker is disabled and should be ignored by authoring tools.")
	return warnings
