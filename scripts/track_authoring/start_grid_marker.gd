@tool
class_name StartGridMarker
extends "res://scripts/track_authoring/track_authoring_marker.gd"

@export_range(1, 32, 1) var slot_count: int = 4
@export_range(1, 16, 1) var rows: int = 2
@export_range(1, 8, 1) var columns: int = 2
@export_range(1.0, 10.0, 0.1) var lane_spacing_m: float = 3.6
@export_range(2.0, 20.0, 0.1) var row_spacing_m: float = 7.5
@export_range(-6.0, 6.0, 0.1) var stagger_offset_m: float = 1.8
@export_range(-0.5, 1.0, 0.01) var vertical_offset_m: float = -0.08
@export var start_section_only: bool = true


func get_marker_kind() -> StringName:
	return &"start_grid_marker"


func get_start_grid_transform(slot_index: int) -> Transform3D:
	var safe_columns: int = maxi(columns, 1)
	var clamped_slot: int = clampi(slot_index, 0, maxi(slot_count - 1, 0))
	var row_index: int = floori(float(clamped_slot) / float(safe_columns))
	var column_index: int = clamped_slot % safe_columns
	var centered_column: float = float(column_index) - float(safe_columns - 1) * 0.5
	var stagger: float = stagger_offset_m if row_index % 2 == 1 else 0.0
	var local_offset := Vector3(
		centered_column * lane_spacing_m + stagger,
		vertical_offset_m,
		-float(row_index) * row_spacing_m
	)
	return Transform3D(global_transform.basis, global_transform * local_offset)


func get_start_grid_slot(slot_index: int) -> Dictionary:
	var slot_transform: Transform3D = get_start_grid_transform(slot_index)
	return {
		"slot_index": slot_index,
		"transform": slot_transform,
		"position": slot_transform.origin,
	}


func get_authoring_record() -> Dictionary:
	var record: Dictionary = super.get_authoring_record()
	record.merge({
		"slot_count": slot_count,
		"rows": rows,
		"columns": columns,
		"lane_spacing_m": lane_spacing_m,
		"row_spacing_m": row_spacing_m,
		"stagger_offset_m": stagger_offset_m,
		"vertical_offset_m": vertical_offset_m,
		"start_section_only": start_section_only,
	}, true)
	return record


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = super._get_configuration_warnings()
	if slot_count > rows * columns:
		warnings.append("slot_count is greater than rows * columns; some slots will overlap the last configured row.")
	return warnings
