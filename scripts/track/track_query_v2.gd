class_name TrackQueryV2
extends RefCounted

const DEFAULT_SURFACE_ID: StringName = &"wet_asphalt"
const DEFAULT_ZONE_ID: StringName = &"storm_coast"

var profile: Resource = null
var metadata: Dictionary = {}

var _road_points: Array[Dictionary] = []
var _distance_table: PackedFloat32Array = PackedFloat32Array()
var _width_markers: Array[Dictionary] = []
var _banking_markers: Array[Dictionary] = []
var _surface_markers: Array[Dictionary] = []
var _zone_markers: Array[Dictionary] = []
var _start_grid_slots: Array[Dictionary] = []
var _start_grid_profile: Dictionary = {}
var _closed_loop: bool = false
var _length_m: float = 0.0
var _default_width_m: float = 12.0
var _lane_count: int = 2
var _lane_spacing_m: float = 3.6


func _init(track_profile: Resource = null, authoring_data: Variant = null) -> void:
	profile = track_profile
	if authoring_data != null:
		configure(track_profile, authoring_data)


func configure(track_profile: Resource, authoring_data: Variant) -> void:
	profile = track_profile
	configure_from_authoring_data(authoring_data, track_profile)


func configure_from_points(
	points: PackedVector3Array,
	closed_loop_enabled: bool = false,
	options: Dictionary = {}
) -> void:
	metadata = options.duplicate(true)
	_apply_defaults_from_sources(options, profile)

	var records: Array[Dictionary] = []
	for point: Vector3 in points:
		records.append({
			"position": point,
			"up": Vector3.UP,
			"width_m": _default_width_m,
			"banking_degrees": 0.0,
			"surface_id": DEFAULT_SURFACE_ID,
			"zone_id": DEFAULT_ZONE_ID,
		})

	_configure_records(records, closed_loop_enabled)
	_apply_marker_sources(options)


func configure_from_authoring_data(authoring_data: Variant, track_profile: Resource = null) -> void:
	profile = track_profile
	metadata = {}
	if authoring_data is Dictionary:
		metadata = (authoring_data as Dictionary).duplicate(true)

	_apply_defaults_from_sources(authoring_data, profile)

	var records: Array[Dictionary] = []
	var road_point_sources: Array = _array_from_source(authoring_data, [
		"road_points",
		"points",
		"centerline",
		"spline_points",
	])

	for source: Variant in road_point_sources:
		records.append(_point_record_from_source(source))

	if records.is_empty() and authoring_data is Node:
		_collect_authoring_nodes(authoring_data as Node, records)

	var closed_loop_enabled: bool = _bool_from_sources([
		authoring_data,
		profile,
	], ["closed_loop", "is_closed_loop"], _closed_loop)
	_configure_records(records, closed_loop_enabled)
	_apply_marker_sources(authoring_data)


func sample_at_distance(distance_m: float) -> Dictionary:
	return sample_ref_at_distance(distance_m).to_dictionary()


func sample_ref_at_distance(distance_m: float) -> TrackSample:
	if _road_points.is_empty():
		return _make_sample(
			0.0,
			0.0,
			0,
			Vector3.ZERO,
			Vector3(0.0, 0.0, 1.0),
			Vector3.UP,
			0.0,
			_default_width_m,
			DEFAULT_SURFACE_ID,
			DEFAULT_ZONE_ID
		)

	if _road_points.size() == 1 or _length_m <= 0.0:
		var only: Dictionary = _road_points[0]
		return _make_sample(
			0.0,
			0.0,
			0,
			only["position"],
			Vector3(0.0, 0.0, 1.0),
			TrackSample.banked_up(Vector3(0.0, 0.0, 1.0), only["up"], _float_value(only, "banking_degrees", 0.0)),
			_float_value(only, "banking_degrees", 0.0),
			_float_value(only, "width_m", _default_width_m),
			_string_name_value(only, "surface_id", DEFAULT_SURFACE_ID),
			_string_name_value(only, "zone_id", DEFAULT_ZONE_ID)
		)

	var resolved_distance: float = _resolve_distance(distance_m)
	var segment_count: int = _road_points.size() if _closed_loop else _road_points.size() - 1

	for i: int in range(segment_count):
		var start_distance: float = _distance_table[i]
		var end_distance: float = _distance_table[i + 1]
		if resolved_distance <= end_distance or i == segment_count - 1:
			var segment_length: float = maxf(end_distance - start_distance, 0.001)
			var t: float = clampf((resolved_distance - start_distance) / segment_length, 0.0, 1.0)
			var next_index: int = (i + 1) % _road_points.size()
			var current: Dictionary = _road_points[i]
			var next: Dictionary = _road_points[next_index]
			var current_position: Vector3 = current["position"]
			var next_position: Vector3 = next["position"]
			var tangent: Vector3 = next_position - current_position
			if tangent.length_squared() <= 0.0001:
				tangent = _tangent_for_index(i)
			else:
				tangent = tangent.normalized()

			var base_up: Vector3 = _interpolated_up(current["up"], next["up"], t, tangent)
			var fallback_banking: float = lerpf(
				_float_value(current, "banking_degrees", 0.0),
				_float_value(next, "banking_degrees", 0.0),
				t
			)
			var banking: float = _float_marker_at_distance(_banking_markers, resolved_distance, fallback_banking, true)
			var width: float = _float_marker_at_distance(
				_width_markers,
				resolved_distance,
				lerpf(_float_value(current, "width_m", _default_width_m), _float_value(next, "width_m", _default_width_m), t),
				true
			)
			var surface_id: StringName = _string_marker_at_distance(
				_surface_markers,
				resolved_distance,
				_string_name_value(current, "surface_id", DEFAULT_SURFACE_ID)
			)
			var zone_id: StringName = _string_marker_at_distance(
				_zone_markers,
				resolved_distance,
				_string_name_value(current, "zone_id", DEFAULT_ZONE_ID)
			)
			var banked_up: Vector3 = TrackSample.banked_up(tangent, base_up, banking)
			return _make_sample(
				resolved_distance,
				resolved_distance / maxf(_length_m, 0.001),
				i,
				current_position.lerp(next_position, t),
				tangent,
				banked_up,
				banking,
				width,
				surface_id,
				zone_id
			)

	return sample_ref_at_distance(0.0)


func closest_distance_for_position(position: Vector3) -> float:
	if _road_points.size() < 2 or _length_m <= 0.0:
		return 0.0

	var best_distance_sq: float = INF
	var best_distance_m: float = 0.0
	var segment_count: int = _road_points.size() if _closed_loop else _road_points.size() - 1

	for i: int in range(segment_count):
		var next_index: int = (i + 1) % _road_points.size()
		var a: Vector3 = _road_points[i]["position"]
		var b: Vector3 = _road_points[next_index]["position"]
		var segment: Vector3 = b - a
		var segment_length_sq: float = segment.length_squared()
		var t: float = 0.0
		if segment_length_sq > 0.0001:
			t = clampf((position - a).dot(segment) / segment_length_sq, 0.0, 1.0)

		var projected: Vector3 = a + segment * t
		var distance_sq: float = position.distance_squared_to(projected)
		if distance_sq < best_distance_sq:
			best_distance_sq = distance_sq
			best_distance_m = _distance_table[i] + (_distance_table[i + 1] - _distance_table[i]) * t

	return _resolve_distance(best_distance_m)


func lane_transform(distance_m: float, lane_index: int) -> Transform3D:
	var lane_count: int = maxi(_lane_count, 1)
	var safe_lane_index: int = clampi(lane_index, 0, lane_count - 1)
	var centered_index: float = float(safe_lane_index) - float(lane_count - 1) * 0.5
	return surface_transform(distance_m, centered_index * _lane_spacing_m)


func surface_transform(
	distance_m: float,
	lateral_offset_m: float = 0.0,
	vertical_offset_m: float = 0.0,
	yaw_offset_degrees: float = 0.0
) -> Transform3D:
	var sample: TrackSample = sample_ref_at_distance(distance_m)
	var result: Transform3D = sample.surface_transform(lateral_offset_m, vertical_offset_m)
	if absf(yaw_offset_degrees) > 0.001:
		result.basis = result.basis.rotated(sample.up, deg_to_rad(yaw_offset_degrees)).orthonormalized()
	return result


func road_edge_transform(
	distance_m: float,
	side: float,
	edge_offset_m: float = 0.0,
	vertical_offset_m: float = 0.0,
	yaw_offset_degrees: float = 0.0
) -> Transform3D:
	var side_sign: float = -1.0 if side < 0.0 else 1.0
	var width: float = get_road_width_m(distance_m)
	return surface_transform(
		distance_m,
		side_sign * (width * 0.5 + edge_offset_m),
		vertical_offset_m,
		yaw_offset_degrees
	)


func road_edge_anchor_transform(
	anchor_distance_m: float,
	road_side: float,
	lateral_offset_from_road_edge_m: float = 0.0,
	longitudinal_offset_m: float = 0.0,
	vertical_offset_m: float = 0.0,
	yaw_offset_degrees: float = 0.0
) -> Transform3D:
	return road_edge_transform(
		anchor_distance_m + longitudinal_offset_m,
		road_side,
		lateral_offset_from_road_edge_m,
		vertical_offset_m,
		yaw_offset_degrees
	)


func road_edge_position(distance_m: float, side: float, edge_offset_m: float = 0.0) -> Vector3:
	return road_edge_transform(distance_m, side, edge_offset_m).origin


func get_track_length_m() -> float:
	return _length_m


func is_closed_loop() -> bool:
	return _closed_loop


func get_road_width_m(distance_m: float = -1.0) -> float:
	if distance_m < 0.0 or _road_points.is_empty():
		return _default_width_m
	var fallback_width: float = _record_width_at_distance(distance_m)
	return _float_marker_at_distance(_width_markers, distance_m, fallback_width, true)


func get_zone_at_distance(distance_m: float) -> StringName:
	return sample_ref_at_distance(distance_m).zone_id


func get_surface_type_at_distance(distance_m: float) -> StringName:
	return sample_ref_at_distance(distance_m).surface_id


func get_spawn_transform(grid_index: int) -> Transform3D:
	return get_start_grid_transform(grid_index)


func get_start_grid_transform(slot_index: int) -> Transform3D:
	if _road_points.is_empty() or _length_m <= 0.0:
		return Transform3D.IDENTITY

	if not _start_grid_slots.is_empty():
		var slot: Dictionary = _start_grid_slots[clampi(slot_index, 0, _start_grid_slots.size() - 1)]
		if slot.has("transform") and slot["transform"] is Transform3D:
			return slot["transform"]
		var slot_distance: float = _float_value(slot, "distance_m", 0.0)
		var slot_lateral: float = _float_value(slot, "lateral_offset_m", 0.0)
		var slot_vertical: float = _float_value(slot, "vertical_offset_m", 0.18)
		var slot_yaw: float = _float_value(slot, "yaw_offset_degrees", 0.0)
		return surface_transform(slot_distance, slot_lateral, slot_vertical, slot_yaw)

	if _start_grid_profile.is_empty():
		return Transform3D.IDENTITY

	var columns: int = maxi(int(_float_value(_start_grid_profile, "columns", float(_lane_count))), 1)
	var lane_spacing: float = _float_value(_start_grid_profile, "lane_spacing_m", _lane_spacing_m)
	var row_spacing: float = _float_value(_start_grid_profile, "row_spacing_m", 7.5)
	var stagger_offset: float = _float_value(_start_grid_profile, "stagger_offset_m", 0.0)
	var origin_distance: float = _float_value(_start_grid_profile, "grid_origin_distance_m", 18.0)
	var vertical_offset: float = _float_value(_start_grid_profile, "vertical_offset_m", 0.18)

	var safe_slot: int = maxi(slot_index, 0)
	var row_index: int = floori(float(safe_slot) / float(columns))
	var column_index: int = safe_slot % columns
	var lateral_offset: float = (float(column_index) - float(columns - 1) * 0.5) * lane_spacing
	var longitudinal_offset: float = -float(row_index) * row_spacing
	if column_index % 2 == 1:
		longitudinal_offset -= stagger_offset
	return surface_transform(origin_distance + longitudinal_offset, lateral_offset, vertical_offset)


func has_start_grid_data() -> bool:
	return not _start_grid_slots.is_empty() or not _start_grid_profile.is_empty()


func get_start_grid_slot_count() -> int:
	if not _start_grid_slots.is_empty():
		return _start_grid_slots.size()
	if _start_grid_profile.is_empty():
		return 0
	return maxi(int(_float_value(_start_grid_profile, "slot_count", 4.0)), 1)


func _configure_records(records: Array[Dictionary], closed_loop_enabled: bool) -> void:
	_road_points = []
	for record: Dictionary in records:
		if not record.has("position") or not (record["position"] is Vector3):
			continue
		var normalized_record: Dictionary = record.duplicate(true)
		normalized_record["width_m"] = maxf(_float_value(normalized_record, "width_m", _default_width_m), 0.1)
		normalized_record["banking_degrees"] = _float_value(normalized_record, "banking_degrees", 0.0)
		normalized_record["up"] = _vector3_value(normalized_record, "up", Vector3.UP)
		normalized_record["surface_id"] = _string_name_value(normalized_record, "surface_id", DEFAULT_SURFACE_ID)
		normalized_record["zone_id"] = _string_name_value(normalized_record, "zone_id", DEFAULT_ZONE_ID)
		_road_points.append(normalized_record)

	_closed_loop = closed_loop_enabled and _road_points.size() > 2
	_distance_table = _build_distance_table()
	_length_m = _distance_table[_distance_table.size() - 1] if not _distance_table.is_empty() else 0.0
	if not _road_points.is_empty():
		_default_width_m = _float_value(_road_points[0], "width_m", _default_width_m)


func _apply_defaults_from_sources(authoring_data: Variant, track_profile: Resource) -> void:
	_default_width_m = _float_from_sources([
		authoring_data,
		track_profile,
	], ["default_road_width_m", "road_width_m", "road_width"], _default_width_m)
	_lane_count = maxi(int(_float_from_sources([
		authoring_data,
		track_profile,
	], ["lane_count", "spawn_lane_count", "columns"], float(_lane_count))), 1)
	_lane_spacing_m = _float_from_sources([
		authoring_data,
		track_profile,
	], ["lane_spacing_m", "spawn_lane_spacing_m"], _lane_spacing_m)


func _apply_marker_sources(source: Variant) -> void:
	_width_markers = _build_float_markers(_array_from_source(source, ["width_markers", "WidthMarkers"]), [
		"width_m",
		"road_width_m",
		"width",
	], _default_width_m)
	_banking_markers = _build_float_markers(_array_from_source(source, ["banking_markers", "BankingMarkers"]), [
		"banking_degrees",
		"banking",
		"bank_degrees",
	], 0.0)
	_surface_markers = _build_string_markers(_array_from_source(source, ["surface_markers", "SurfaceMarkers"]), [
		"surface_id",
		"surface_type",
		"surface",
	], DEFAULT_SURFACE_ID)
	_zone_markers = _build_string_markers(_array_from_source(source, ["zone_markers", "ZoneMarkers"]), [
		"zone_id",
		"zone",
	], DEFAULT_ZONE_ID)
	_start_grid_slots = _build_start_grid_slots(_array_from_source(source, [
		"start_grid_slots",
		"spawn_slots",
		"start_slots",
	]))
	_start_grid_profile = _dictionary_from_source(_get_any(source, [
		"start_grid_profile",
		"start_grid",
		"spawn_grid",
	], {}))

	if _start_grid_profile.is_empty():
		_start_grid_profile = _start_grid_profile_from_profile(profile)

	if _width_markers.is_empty():
		for i: int in range(_road_points.size()):
			_insert_marker_sorted(_width_markers, {
				"distance_m": _distance_table[i],
				"value": _float_value(_road_points[i], "width_m", _default_width_m),
			})

	if _banking_markers.is_empty():
		for i: int in range(_road_points.size()):
			_insert_marker_sorted(_banking_markers, {
				"distance_m": _distance_table[i],
				"value": _float_value(_road_points[i], "banking_degrees", 0.0),
			})


func _collect_authoring_nodes(node: Node, records: Array[Dictionary]) -> void:
	for child: Node in node.get_children():
		var role: String = _node_role(child)
		var child_name: String = child.name.to_lower()
		if child is Node3D and (role == "road_point" or child_name.contains("roadpoint") or child_name.contains("road_point")):
			records.append(_point_record_from_source(child))
		_collect_authoring_nodes(child, records)


func _point_record_from_source(source: Variant) -> Dictionary:
	var position: Vector3 = _vector3_from_any(_get_any(source, [
		"position",
		"local_position",
		"point",
	], Vector3.ZERO), Vector3.ZERO)
	if source is Node3D:
		position = (source as Node3D).position
	elif source is Vector3:
		position = source

	var surface_value: Variant = _get_any(source, ["surface_id", "surface_type", "surface"], DEFAULT_SURFACE_ID)
	var zone_value: Variant = _get_any(source, ["zone_id", "zone"], DEFAULT_ZONE_ID)
	return {
		"position": position,
		"up": _vector3_from_any(_get_any(source, ["up", "normal", "up_vector"], Vector3.UP), Vector3.UP),
		"width_m": _float_from_source(source, ["width_m", "road_width_m", "width"], _default_width_m),
		"banking_degrees": _float_from_source(source, ["banking_degrees", "banking", "bank_degrees"], 0.0),
		"surface_id": _as_string_name(surface_value),
		"zone_id": _as_string_name(zone_value),
	}


func _build_float_markers(sources: Array, value_keys: Array, fallback: float) -> Array[Dictionary]:
	var markers: Array[Dictionary] = []
	for source: Variant in sources:
		var marker: Dictionary = {
			"distance_m": _distance_from_source(source),
			"value": _float_from_source(source, value_keys, fallback),
		}
		_insert_marker_sorted(markers, marker)
	return markers


func _build_string_markers(sources: Array, value_keys: Array, fallback: StringName) -> Array[Dictionary]:
	var markers: Array[Dictionary] = []
	for source: Variant in sources:
		var marker: Dictionary = {
			"distance_m": _distance_from_source(source),
			"value": _as_string_name(_get_any(source, value_keys, fallback)),
		}
		_insert_marker_sorted(markers, marker)
	return markers


func _build_start_grid_slots(sources: Array) -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	for source: Variant in sources:
		var slot: Dictionary = _dictionary_from_source(source)
		if slot.is_empty():
			slot = {
				"distance_m": _distance_from_source(source),
				"lateral_offset_m": _float_from_source(source, ["lateral_offset_m", "lane_offset_m"], 0.0),
				"vertical_offset_m": _float_from_source(source, ["vertical_offset_m", "height_offset_m"], 0.18),
				"yaw_offset_degrees": _float_from_source(source, ["yaw_offset_degrees", "yaw_degrees"], 0.0),
			}
		if source is Node3D and not slot.has("transform"):
			slot["transform"] = (source as Node3D).transform
		_insert_marker_sorted(slots, slot)
	return slots


func _start_grid_profile_from_profile(track_profile: Resource) -> Dictionary:
	if track_profile == null:
		return {}
	var result: Dictionary = {}
	result["grid_origin_distance_m"] = _float_from_source(track_profile, ["grid_origin_distance_m", "spawn_start_distance_m"], 18.0)
	result["slot_count"] = _float_from_source(track_profile, ["slot_count", "spawn_marker_count"], 4.0)
	result["columns"] = _float_from_source(track_profile, ["columns", "spawn_lane_count", "lane_count"], float(_lane_count))
	result["lane_spacing_m"] = _float_from_source(track_profile, ["lane_spacing_m", "spawn_lane_spacing_m"], _lane_spacing_m)
	result["row_spacing_m"] = _float_from_source(track_profile, ["row_spacing_m", "spawn_row_spacing_m"], 7.5)
	result["stagger_offset_m"] = _float_from_source(track_profile, ["stagger_offset_m"], 0.0)
	result["vertical_offset_m"] = _float_from_source(track_profile, ["vertical_offset_m", "spawn_vertical_offset_m"], 0.18)
	return result


func _record_width_at_distance(distance_m: float) -> float:
	if _road_points.is_empty():
		return _default_width_m
	var resolved_distance: float = _resolve_distance(distance_m)
	var segment_count: int = _road_points.size() if _closed_loop else _road_points.size() - 1
	if segment_count <= 0:
		return _float_value(_road_points[0], "width_m", _default_width_m)

	for i: int in range(segment_count):
		var start_distance: float = _distance_table[i]
		var end_distance: float = _distance_table[i + 1]
		if resolved_distance <= end_distance or i == segment_count - 1:
			var t: float = clampf((resolved_distance - start_distance) / maxf(end_distance - start_distance, 0.001), 0.0, 1.0)
			var next_index: int = (i + 1) % _road_points.size()
			return lerpf(
				_float_value(_road_points[i], "width_m", _default_width_m),
				_float_value(_road_points[next_index], "width_m", _default_width_m),
				t
			)
	return _default_width_m


func _float_marker_at_distance(
	markers: Array[Dictionary],
	distance_m: float,
	fallback: float,
	interpolate: bool
) -> float:
	if markers.is_empty():
		return fallback
	if markers.size() == 1 or _length_m <= 0.0:
		return _float_value(markers[0], "value", fallback)

	var resolved_distance: float = _resolve_distance(distance_m)
	var previous: Dictionary = markers[markers.size() - 1] if _closed_loop else markers[0]
	var next: Dictionary = markers[0]

	for marker: Dictionary in markers:
		if _float_value(marker, "distance_m", 0.0) <= resolved_distance:
			previous = marker
		if _float_value(marker, "distance_m", 0.0) >= resolved_distance:
			next = marker
			break

	var previous_distance: float = _float_value(previous, "distance_m", 0.0)
	var next_distance: float = _float_value(next, "distance_m", previous_distance)
	if not _closed_loop and next_distance < previous_distance:
		next = previous
		next_distance = previous_distance
	if next_distance < previous_distance and _closed_loop:
		next_distance += _length_m
	if resolved_distance < previous_distance and _closed_loop:
		resolved_distance += _length_m

	if not interpolate or absf(next_distance - previous_distance) <= 0.001:
		return _float_value(previous, "value", fallback)

	var t: float = clampf((resolved_distance - previous_distance) / (next_distance - previous_distance), 0.0, 1.0)
	return lerpf(_float_value(previous, "value", fallback), _float_value(next, "value", fallback), t)


func _string_marker_at_distance(markers: Array[Dictionary], distance_m: float, fallback: StringName) -> StringName:
	if markers.is_empty():
		return fallback
	var resolved_distance: float = _resolve_distance(distance_m)
	var selected: Dictionary = markers[markers.size() - 1] if _closed_loop else markers[0]
	for marker: Dictionary in markers:
		if _float_value(marker, "distance_m", 0.0) <= resolved_distance:
			selected = marker
		else:
			break
	return _as_string_name(selected.get("value", fallback))


func _build_distance_table() -> PackedFloat32Array:
	var distances := PackedFloat32Array()
	var distance: float = 0.0
	distances.append(distance)
	if _road_points.size() < 2:
		return distances

	var segment_count: int = _road_points.size() if _closed_loop else _road_points.size() - 1
	for i: int in range(segment_count):
		var next_index: int = (i + 1) % _road_points.size()
		distance += (_road_points[i]["position"] as Vector3).distance_to(_road_points[next_index]["position"])
		distances.append(distance)
	return distances


func _resolve_distance(distance_m: float) -> float:
	if _length_m <= 0.0:
		return 0.0
	if _closed_loop:
		return fposmod(distance_m, _length_m)
	return clampf(distance_m, 0.0, _length_m)


func _tangent_for_index(index: int) -> Vector3:
	if _road_points.size() < 2:
		return Vector3(0.0, 0.0, 1.0)
	var safe_index: int = clampi(index, 0, _road_points.size() - 1)
	var previous_index: int = (safe_index - 1 + _road_points.size()) % _road_points.size()
	var next_index: int = (safe_index + 1) % _road_points.size()
	var tangent: Vector3 = _road_points[next_index]["position"] - _road_points[previous_index]["position"]
	if tangent.length_squared() <= 0.0001:
		return Vector3(0.0, 0.0, 1.0)
	return tangent.normalized()


func _interpolated_up(from_up: Vector3, to_up: Vector3, t: float, tangent: Vector3) -> Vector3:
	var blended: Vector3 = from_up.lerp(to_up, t)
	if blended.length_squared() <= 0.0001:
		blended = Vector3.UP
	blended = blended.normalized()
	blended = blended - tangent.normalized() * blended.dot(tangent.normalized())
	if blended.length_squared() <= 0.0001:
		return Vector3.UP
	return blended.normalized()


func _make_sample(
	distance_m: float,
	ratio: float,
	segment_index: int,
	position: Vector3,
	tangent: Vector3,
	up: Vector3,
	banking_degrees: float,
	width_m: float,
	surface_id: StringName,
	zone_id: StringName
) -> TrackSample:
	var sample := TrackSample.new()
	sample.configure(
		distance_m,
		ratio,
		segment_index,
		position,
		tangent,
		up,
		banking_degrees,
		width_m,
		surface_id,
		zone_id
	)
	return sample


func _insert_marker_sorted(markers: Array[Dictionary], marker: Dictionary) -> void:
	var insert_index: int = markers.size()
	var marker_distance: float = _float_value(marker, "distance_m", 0.0)
	for i: int in range(markers.size()):
		if marker_distance < _float_value(markers[i], "distance_m", 0.0):
			insert_index = i
			break
	markers.insert(insert_index, marker)


func _distance_from_source(source: Variant) -> float:
	var distance_value: Variant = _get_any(source, ["distance_m", "distance", "anchor_distance_m"], null)
	if distance_value != null:
		return _resolve_distance(float(distance_value))
	var position_value: Variant = _get_any(source, ["position", "local_position", "point"], null)
	if position_value is Vector3:
		return closest_distance_for_position(position_value)
	if source is Node3D:
		return closest_distance_for_position((source as Node3D).position)
	return 0.0


func _array_from_source(source: Variant, keys: Array) -> Array:
	var value: Variant = _get_any(source, keys, [])
	var result: Array = []
	if value is Array:
		return value
	if value is PackedVector3Array:
		for item: Vector3 in value:
			result.append(item)
	elif value is PackedStringArray:
		for item: String in value:
			result.append(item)
	return result


func _dictionary_from_source(source: Variant) -> Dictionary:
	if source is Dictionary:
		return (source as Dictionary).duplicate(true)
	if source is Resource:
		var result: Dictionary = {}
		for property: Dictionary in (source as Resource).get_property_list():
			var property_name: String = String(property.get("name", ""))
			if property_name.begins_with("resource_") or property_name == "script":
				continue
			var value: Variant = (source as Resource).get(property_name)
			if value != null:
				result[property_name] = value
		return result
	return {}


func _get_any(source: Variant, keys: Array, fallback: Variant = null) -> Variant:
	for key_value: Variant in keys:
		var key: String = String(key_value)
		var value: Variant = _get_value(source, key, null)
		if value != null:
			return value
	return fallback


func _get_value(source: Variant, key: String, fallback: Variant = null) -> Variant:
	if source is Dictionary:
		var dictionary: Dictionary = source
		if dictionary.has(key):
			return dictionary[key]
		var string_name_key := StringName(key)
		if dictionary.has(string_name_key):
			return dictionary[string_name_key]
		return fallback
	if source is Object:
		var object := source as Object
		if object.has_meta(key):
			return object.get_meta(key)
		var value: Variant = object.get(key)
		if value != null:
			return value
	return fallback


func _node_role(node: Node) -> String:
	var role_value: Variant = _get_any(node, ["authoring_role", "track_role", "marker_type", "role"], "")
	return String(role_value).to_lower()


func _float_from_sources(sources: Array, keys: Array, fallback: float) -> float:
	for source: Variant in sources:
		var value: Variant = _get_any(source, keys, null)
		if value != null:
			return float(value)
	return fallback


func _bool_from_sources(sources: Array, keys: Array, fallback: bool) -> bool:
	for source: Variant in sources:
		var value: Variant = _get_any(source, keys, null)
		if value != null:
			return bool(value)
	return fallback


func _float_from_source(source: Variant, keys: Array, fallback: float) -> float:
	var value: Variant = _get_any(source, keys, null)
	if value == null:
		return fallback
	return float(value)


func _float_value(dictionary: Dictionary, key: String, fallback: float) -> float:
	if not dictionary.has(key):
		return fallback
	return float(dictionary[key])


func _vector3_value(dictionary: Dictionary, key: String, fallback: Vector3) -> Vector3:
	if not dictionary.has(key):
		return fallback
	return _vector3_from_any(dictionary[key], fallback)


func _string_name_value(dictionary: Dictionary, key: String, fallback: StringName) -> StringName:
	if not dictionary.has(key):
		return fallback
	return _as_string_name(dictionary[key])


func _vector3_from_any(value: Variant, fallback: Vector3) -> Vector3:
	if value is Vector3:
		return value
	if value is Vector2:
		var vector2: Vector2 = value
		return Vector3(vector2.x, 0.0, vector2.y)
	return fallback


func _as_string_name(value: Variant) -> StringName:
	if value is StringName:
		return value
	return StringName(String(value))
