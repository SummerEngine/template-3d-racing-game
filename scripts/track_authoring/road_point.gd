@tool
class_name RoadPoint
extends "res://scripts/track_authoring/track_authoring_marker.gd"

enum TangentMode { AUTO, ALIGNED, MANUAL }

@export var sequence_index: int = 0
@export_range(4.0, 32.0, 0.1) var road_width_m: float = 12.5
@export_range(-45.0, 45.0, 0.1) var banking_degrees: float = 0.0
@export var surface_type: StringName = &"wet_asphalt"
@export var zone_id: StringName = &"coast"
@export var tangent_mode: TangentMode = TangentMode.AUTO
@export var handle_in: Vector3 = Vector3.ZERO
@export var handle_out: Vector3 = Vector3.ZERO
@export_range(20.0, 360.0, 1.0) var preferred_speed_kmh: float = 150.0
@export var checkpoint_hint: bool = false


func get_marker_kind() -> StringName:
	return &"road_point"


func get_authoring_record() -> Dictionary:
	var record: Dictionary = super.get_authoring_record()
	record.merge({
		"sequence_index": sequence_index,
		"road_width_m": road_width_m,
		"banking_degrees": banking_degrees,
		"surface_type": surface_type,
		"zone_id": zone_id,
		"tangent_mode": TangentMode.keys()[tangent_mode],
		"handle_in": handle_in,
		"handle_out": handle_out,
		"preferred_speed_kmh": preferred_speed_kmh,
		"checkpoint_hint": checkpoint_hint,
	}, true)
	return record


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = super._get_configuration_warnings()
	if sequence_index != authoring_order:
		warnings.append("sequence_index and authoring_order differ; sorting uses sequence_index first.")
	return warnings
