@tool
class_name WidthMarker
extends "res://scripts/track_authoring/track_authoring_marker.gd"

enum WidthBlendMode { STEP, LINEAR, SMOOTH }

@export_range(4.0, 36.0, 0.1) var target_width_m: float = 12.5
@export_range(0.0, 250.0, 0.1) var blend_before_m: float = 30.0
@export_range(0.0, 250.0, 0.1) var blend_after_m: float = 30.0
@export var blend_mode: WidthBlendMode = WidthBlendMode.SMOOTH
@export var affects_left_edge: bool = true
@export var affects_right_edge: bool = true
@export_range(0.0, 8.0, 0.1) var shoulder_width_m: float = 1.5


func get_marker_kind() -> StringName:
	return &"width_marker"


func get_authoring_record() -> Dictionary:
	var record: Dictionary = super.get_authoring_record()
	record.merge({
		"target_width_m": target_width_m,
		"blend_before_m": blend_before_m,
		"blend_after_m": blend_after_m,
		"blend_mode": WidthBlendMode.keys()[blend_mode],
		"affects_left_edge": affects_left_edge,
		"affects_right_edge": affects_right_edge,
		"shoulder_width_m": shoulder_width_m,
	}, true)
	return record
