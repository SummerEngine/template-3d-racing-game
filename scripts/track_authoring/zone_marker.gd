@tool
class_name ZoneMarker
extends "res://scripts/track_authoring/track_authoring_marker.gd"

enum ZoneKind { ENVIRONMENT, SURFACE, SAFETY, SET_PIECE, CAMERA, AUDIO }

@export var zone_id: StringName = &"coast"
@export var zone_kind: ZoneKind = ZoneKind.ENVIRONMENT
@export var surface_type: StringName = &"wet_asphalt"
@export var environment_key: StringName = &"mountain_coastal_wet"
@export_range(0.0, 10000.0, 0.1) var end_distance_m: float = 0.0
@export_range(0, 100, 1) var priority: int = 0
@export var affects_weather: bool = true
@export var designer_locked: bool = false


func get_marker_kind() -> StringName:
	return &"zone_marker"


func get_authoring_record() -> Dictionary:
	var record: Dictionary = super.get_authoring_record()
	record.merge({
		"zone_id": zone_id,
		"zone_kind": ZoneKind.keys()[zone_kind],
		"surface_type": surface_type,
		"environment_key": environment_key,
		"start_distance_m": road_distance_m,
		"end_distance_m": end_distance_m,
		"priority": priority,
		"affects_weather": affects_weather,
		"designer_locked": designer_locked,
	}, true)
	return record


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = super._get_configuration_warnings()
	if end_distance_m > 0.0 and end_distance_m <= road_distance_m:
		warnings.append("end_distance_m should be greater than road_distance_m for a ranged zone.")
	return warnings
