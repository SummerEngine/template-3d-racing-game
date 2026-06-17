class_name StartGridProfile
extends Resource

const StartGridResolverScript := preload("res://scripts/race/start_grid/start_grid_resolver.gd")

@export var grid_origin_distance_m: float = 18.0
@export var slot_count: int = 4
@export var rows: int = 2
@export var columns: int = 2
@export var lane_spacing_m: float = 3.6
@export var row_spacing_m: float = 7.5
@export var stagger_offset_m: float = 3.75
@export var start_section_only: bool = true
@export var slot_vertical_offset_m: float = 0.14
@export var edge_clearance_m: float = 1.0


func get_effective_slot_count() -> int:
	return max(0, slot_count)


func get_effective_columns() -> int:
	return max(1, columns)


func get_effective_rows() -> int:
	var column_count: int = get_effective_columns()
	var rows_for_slots: int = int(ceil(float(get_effective_slot_count()) / float(column_count)))
	return max(max(1, rows), rows_for_slots)


func is_slot_index_valid(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < get_effective_slot_count()


func get_slot_row(slot_index: int) -> int:
	return int(floor(float(max(0, slot_index)) / float(get_effective_columns())))


func get_slot_column(slot_index: int) -> int:
	return posmod(max(0, slot_index), get_effective_columns())


func get_slot_distance_m(slot_index: int, track_length_m: float = 0.0) -> float:
	var row_index: int = get_slot_row(slot_index)
	var column_index: int = get_slot_column(slot_index)
	var stagger_m: float = maxf(0.0, stagger_offset_m) if posmod(column_index, 2) == 1 else 0.0
	var distance_m: float = grid_origin_distance_m - float(row_index) * maxf(0.0, row_spacing_m) - stagger_m

	if start_section_only:
		if track_length_m > 0.0:
			return clampf(distance_m, 0.0, track_length_m)
		return maxf(0.0, distance_m)

	if track_length_m > 0.0:
		return fposmod(distance_m, track_length_m)
	return distance_m


func get_slot_lateral_offset_m(slot_index: int, road_width_m: float = -1.0) -> float:
	var column_count: int = get_effective_columns()
	if column_count <= 1:
		return 0.0

	var centered_column: float = float(get_slot_column(slot_index)) - float(column_count - 1) * 0.5
	var effective_spacing_m: float = maxf(0.0, lane_spacing_m)
	if road_width_m > 0.0:
		var usable_half_width_m: float = maxf(0.0, road_width_m * 0.5 - maxf(0.0, edge_clearance_m))
		var spacing_that_fits_m: float = usable_half_width_m * 2.0 / float(column_count - 1)
		effective_spacing_m = minf(effective_spacing_m, spacing_that_fits_m)

	return centered_column * effective_spacing_m


func get_slot_local_offset(slot_index: int, road_width_m: float = -1.0) -> Vector3:
	var row_index: int = get_slot_row(slot_index)
	var column_index: int = get_slot_column(slot_index)
	var stagger_m: float = maxf(0.0, stagger_offset_m) if posmod(column_index, 2) == 1 else 0.0
	return Vector3(
		get_slot_lateral_offset_m(slot_index, road_width_m),
		slot_vertical_offset_m,
		-float(row_index) * maxf(0.0, row_spacing_m) - stagger_m
	)


func get_slot_transform(track_query: Object, slot_index: int) -> Transform3D:
	return StartGridResolverScript.get_slot_transform(track_query, self, slot_index)


func get_slot_transforms(track_query: Object) -> Array[Transform3D]:
	return StartGridResolverScript.get_slot_transforms(track_query, self)


func get_slot_descriptor(track_query: Object, slot_index: int) -> Dictionary:
	return StartGridResolverScript.get_slot_descriptor(track_query, self, slot_index)
