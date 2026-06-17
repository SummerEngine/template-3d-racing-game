@tool
class_name ElevationMarker
extends "res://scripts/track_authoring/track_authoring_marker.gd"

enum ElevationBlendMode { STEP, LINEAR, SMOOTH }

@export var use_node_y_as_elevation: bool = true
@export_range(-200.0, 200.0, 0.1) var elevation_offset_m: float = 0.0
@export_range(-28.0, 28.0, 0.1) var grade_hint_degrees: float = 0.0
@export_range(0.0, 300.0, 0.1) var blend_before_m: float = 50.0
@export_range(0.0, 300.0, 0.1) var blend_after_m: float = 50.0
@export var blend_mode: ElevationBlendMode = ElevationBlendMode.SMOOTH


func get_marker_kind() -> StringName:
	return &"elevation_marker"


func get_effective_elevation_m() -> float:
	if use_node_y_as_elevation:
		return get_authoring_position().y
	return elevation_offset_m


func get_authoring_record() -> Dictionary:
	var record: Dictionary = super.get_authoring_record()
	record.merge({
		"use_node_y_as_elevation": use_node_y_as_elevation,
		"elevation_offset_m": elevation_offset_m,
		"effective_elevation_m": get_effective_elevation_m(),
		"grade_hint_degrees": grade_hint_degrees,
		"blend_before_m": blend_before_m,
		"blend_after_m": blend_after_m,
		"blend_mode": ElevationBlendMode.keys()[blend_mode],
	}, true)
	return record
