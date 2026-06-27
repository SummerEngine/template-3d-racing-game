@tool
class_name StormCoastTrackGenerator
extends Node3D

const TrackQueryV2Script := preload("res://scripts/track/track_query_v2.gd")

@export var track_profile: Resource = null
@export var authoring_root_path: NodePath = NodePath("")
@export var generated_root_name: String = "GeneratedStormCoastRoad"
@export var generate_on_ready: bool = false
@export var use_preview_when_no_authoring: bool = true
@export var assign_owner_in_editor: bool = true

@export var closed_loop: bool = false
@export var smooth_centerline: bool = true
@export_range(4.0, 32.0, 0.25) var default_road_width_m: float = 20.0
@export_range(1, 6, 1) var lane_count: int = 2
@export_range(2.0, 6.0, 0.1) var lane_spacing_m: float = 3.6
@export_range(1.0, 20.0, 0.5) var sample_spacing_m: float = 2.0
@export_range(0.0, 1.0, 0.05) var centerline_tangent_strength: float = 0.72
@export_range(1, 32, 1) var curve_subdivisions: int = 24

@export var generate_road: bool = true
@export var generate_collision: bool = true
@export var generate_lane_markings: bool = true
@export var generate_shoulders: bool = true
@export var generate_curbs: bool = true
@export var generate_surrounding_terrain: bool = true
@export var generate_guardrail_hooks: bool = true
@export var generate_guardrail_markers: bool = false

@export_range(1.0, 20.0, 0.5) var collision_spacing_m: float = 2.0
@export_range(0.2, 2.0, 0.05) var collision_thickness_m: float = 0.9
@export_range(0.0, 2.0, 0.05) var collision_width_margin_m: float = 0.35
@export_range(-0.1, 0.2, 0.01) var collision_surface_lift_m: float = 0.02
@export_range(0.0, 3.0, 0.05) var collision_segment_overlap_m: float = 0.6

@export_range(0.4, 4.0, 0.05) var shoulder_width_m: float = 1.35
@export_range(0.1, 1.4, 0.05) var curb_width_m: float = 0.42
@export_range(10.0, 180.0, 1.0) var terrain_width_m: float = 72.0
@export_range(0.0, 20.0, 0.25) var terrain_outer_drop_m: float = 6.5
@export_range(0.0, 8.0, 0.1) var terrain_roughness_m: float = 1.8
@export_range(0.0, 12.0, 0.25) var terrain_edge_gap_m: float = 2.5
@export_range(2, 12, 1) var terrain_band_count: int = 6
@export_range(0.0, 32.0, 0.5) var terrain_mountain_height_m: float = 0.0
@export_range(0.25, 0.85, 0.05) var terrain_ridge_position: float = 0.62
@export_range(0.75, 8.0, 0.25) var guardrail_sample_spacing_m: float = 1.25
@export_range(6.0, 40.0, 1.0) var guardrail_hook_spacing_m: float = 16.0
@export_range(0.0, 4.0, 0.05) var guardrail_edge_offset_m: float = 0.72
@export_range(0.25, 4.0, 0.05) var guardrail_collision_thickness_m: float = 1.45
@export_range(0.5, 5.0, 0.05) var guardrail_collision_height_m: float = 2.2
@export_range(0.0, 4.0, 0.05) var guardrail_collision_overlap_m: float = 1.4
@export_range(0.0, 200.0, 1.0) var guardrail_seam_gap_m: float = 0.0

@export_range(1, 16, 1) var start_grid_slot_count: int = 4
@export_range(1, 4, 1) var start_grid_columns: int = 2
@export_range(0.0, 80.0, 0.5) var start_grid_origin_distance_m: float = 24.0
@export_range(2.0, 8.0, 0.1) var start_grid_lane_spacing_m: float = 3.8
@export_range(4.0, 14.0, 0.25) var start_grid_row_spacing_m: float = 8.0
@export_range(0.0, 8.0, 0.25) var start_grid_stagger_offset_m: float = 2.0
@export_range(-0.5, 1.0, 0.01) var start_grid_vertical_offset_m: float = -0.08

var _track_query: TrackQueryV2 = null
var _generated_root: Node3D = null


func _ready() -> void:
	if generate_on_ready:
		call_deferred("regenerate_track")


func regenerate_track() -> void:
	var authoring_data: Dictionary = _collect_authoring_data()
	_track_query = TrackQueryV2Script.new()
	_track_query.configure_from_authoring_data(authoring_data, track_profile)

	var builder_script := load("res://scripts/track/road_mesh_builder_v2.gd") as Script
	if builder_script == null:
		push_error("StormCoastTrackGenerator: failed to load road mesh builder.")
		return
	var builder: RefCounted = builder_script.new() as RefCounted
	if builder == null:
		push_error("StormCoastTrackGenerator: road mesh builder did not instantiate.")
		return
	_generated_root = builder.call("build", self, _track_query, _builder_options()) as Node3D


func has_generated_track() -> bool:
	return _track_query != null and get_node_or_null(generated_root_name) != null


func get_track_query() -> TrackQueryV2:
	return _track_query


func get_track_length_m() -> float:
	if _track_query == null:
		return 0.0
	return _track_query.get_track_length_m()


func get_road_width_m(distance_m: float = -1.0) -> float:
	if _track_query == null:
		return default_road_width_m
	return _track_query.get_road_width_m(distance_m)


func sample_at_distance(distance_m: float) -> Dictionary:
	if _track_query == null:
		return {}
	return _track_query.sample_at_distance(distance_m)


func closest_distance_for_position(world_position: Vector3) -> float:
	if _track_query == null:
		return 0.0
	return _track_query.closest_distance_for_position(to_local(world_position))


func lane_transform(distance_m: float, lane_index: int) -> Transform3D:
	if _track_query == null:
		return Transform3D.IDENTITY
	return global_transform * _track_query.lane_transform(distance_m, lane_index)


func surface_transform(
	distance_m: float,
	lateral_offset_m: float = 0.0,
	vertical_offset_m: float = 0.0,
	yaw_offset_degrees: float = 0.0
) -> Transform3D:
	if _track_query == null:
		return Transform3D.IDENTITY
	return global_transform * _track_query.surface_transform(
		distance_m,
		lateral_offset_m,
		vertical_offset_m,
		yaw_offset_degrees
	)


func road_edge_transform(
	distance_m: float,
	side: float,
	edge_offset_m: float = 0.0,
	vertical_offset_m: float = 0.0,
	yaw_offset_degrees: float = 0.0
) -> Transform3D:
	if _track_query == null:
		return Transform3D.IDENTITY
	return global_transform * _track_query.road_edge_transform(
		distance_m,
		side,
		edge_offset_m,
		vertical_offset_m,
		yaw_offset_degrees
	)


func get_road_edge_transform(
	distance_m: float,
	road_side: int,
	edge_offset_m: float = 0.0,
	vertical_offset_m: float = 0.0,
	yaw_offset_degrees: float = 0.0
) -> Transform3D:
	return road_edge_transform(
		distance_m,
		float(-1 if road_side < 0 else 1),
		edge_offset_m,
		vertical_offset_m,
		yaw_offset_degrees
	)


func road_edge_position(distance_m: float, side: float, edge_offset_m: float = 0.0) -> Vector3:
	return road_edge_transform(distance_m, side, edge_offset_m).origin


func get_closest_road_edge(
	world_position: Vector3,
	preferred_distance_m: float = 0.0,
	preferred_side: int = 1
) -> Dictionary:
	if _track_query == null:
		return {}

	var distance_m: float = closest_distance_for_position(world_position)
	if get_track_length_m() <= 0.0:
		distance_m = preferred_distance_m

	var left_transform: Transform3D = road_edge_transform(distance_m, -1.0)
	var right_transform: Transform3D = road_edge_transform(distance_m, 1.0)
	var left_distance_sq: float = world_position.distance_squared_to(left_transform.origin)
	var right_distance_sq: float = world_position.distance_squared_to(right_transform.origin)
	var road_side: int = -1 if left_distance_sq < right_distance_sq else 1
	if is_equal_approx(left_distance_sq, right_distance_sq):
		road_side = -1 if preferred_side < 0 else 1

	var edge_transform: Transform3D = left_transform if road_side < 0 else right_transform
	return {
		"anchor_distance_m": distance_m,
		"distance_m": distance_m,
		"road_side": road_side,
		"edge_transform": edge_transform,
		"transform": edge_transform,
	}


func road_edge_anchor_transform(
	anchor_distance_m: float,
	road_side: float,
	lateral_offset_from_road_edge_m: float = 0.0,
	longitudinal_offset_m: float = 0.0,
	vertical_offset_m: float = 0.0,
	yaw_offset_degrees: float = 0.0
) -> Transform3D:
	if _track_query == null:
		return Transform3D.IDENTITY
	return global_transform * _track_query.road_edge_anchor_transform(
		anchor_distance_m,
		road_side,
		lateral_offset_from_road_edge_m,
		longitudinal_offset_m,
		vertical_offset_m,
		yaw_offset_degrees
	)


func get_spawn_transform(grid_index: int) -> Transform3D:
	return get_start_grid_transform(grid_index)


func get_start_grid_transform(slot_index: int) -> Transform3D:
	if _track_query == null:
		return Transform3D.IDENTITY
	return global_transform * _track_query.get_start_grid_transform(slot_index)


func place_node_at_start_grid(node: Node3D, slot_index: int) -> void:
	if node == null:
		return
	node.global_transform = get_start_grid_transform(slot_index)
	if node is CharacterBody3D:
		(node as CharacterBody3D).velocity = Vector3.ZERO


func _collect_authoring_data() -> Dictionary:
	var authoring_root: Node = _resolve_authoring_root()
	if authoring_root == null:
		return _preview_authoring_data() if use_preview_when_no_authoring else _empty_authoring_data()

	var road_points: Array[Dictionary] = []
	var width_markers: Array[Dictionary] = []
	var banking_markers: Array[Dictionary] = []
	var surface_markers: Array[Dictionary] = []
	var zone_markers: Array[Dictionary] = []
	var start_grid_slots: Array[Dictionary] = []
	var start_grid_profile: Dictionary = _default_start_grid_profile()

	_collect_authoring_nodes(
		authoring_root,
		road_points,
		width_markers,
		banking_markers,
		surface_markers,
		zone_markers,
		start_grid_slots,
		start_grid_profile
	)
	road_points.sort_custom(_sort_road_point_records)

	if road_points.is_empty() and use_preview_when_no_authoring:
		return _preview_authoring_data()

	return {
		"road_points": road_points,
		"width_markers": width_markers,
		"banking_markers": banking_markers,
		"surface_markers": surface_markers,
		"zone_markers": zone_markers,
		"start_grid_slots": start_grid_slots,
		"start_grid_profile": start_grid_profile,
		"closed_loop": closed_loop,
		"smooth_centerline": smooth_centerline,
		"centerline_tangent_strength": centerline_tangent_strength,
		"curve_subdivisions": curve_subdivisions,
		"default_road_width_m": default_road_width_m,
		"lane_count": lane_count,
		"lane_spacing_m": lane_spacing_m,
	}


func _collect_authoring_nodes(
	node: Node,
	road_points: Array[Dictionary],
	width_markers: Array[Dictionary],
	banking_markers: Array[Dictionary],
	surface_markers: Array[Dictionary],
	zone_markers: Array[Dictionary],
	start_grid_slots: Array[Dictionary],
	start_grid_profile: Dictionary
) -> void:
	for child: Node in node.get_children():
		var kind: String = _node_kind(child)
		if child is Node3D:
			match kind:
				"road_point":
					road_points.append(_road_point_record(child as Node3D))
				"width_marker":
					width_markers.append(_marker_record(child as Node3D, "width_m", _node_float(child, ["target_width_m", "width_m", "road_width_m", "width"], default_road_width_m)))
				"banking_marker":
					banking_markers.append(_marker_record(child as Node3D, "banking_degrees", _node_float(child, ["target_bank_degrees", "banking_degrees", "banking", "bank_degrees"], 0.0)))
				"surface_marker":
					surface_markers.append(_marker_record(child as Node3D, "surface_id", _node_string_name(child, ["surface_id", "surface_type", "surface"], TrackQueryV2.DEFAULT_SURFACE_ID)))
				"zone_marker":
					zone_markers.append(_marker_record(child as Node3D, "zone_id", _node_string_name(child, ["zone_id", "zone"], TrackQueryV2.DEFAULT_ZONE_ID)))
				"start_grid_marker":
					start_grid_profile["grid_origin_distance_m"] = _node_float(child, ["road_distance_m", "grid_origin_distance_m", "distance_m", "distance"], start_grid_origin_distance_m)
					start_grid_profile["slot_count"] = int(_node_float(child, ["slot_count"], start_grid_slot_count))
					start_grid_profile["rows"] = int(_node_float(child, ["rows"], 2.0))
					start_grid_profile["columns"] = int(_node_float(child, ["columns"], start_grid_columns))
					start_grid_profile["lane_spacing_m"] = _node_float(child, ["lane_spacing_m"], start_grid_lane_spacing_m)
					start_grid_profile["row_spacing_m"] = _node_float(child, ["row_spacing_m"], start_grid_row_spacing_m)
					start_grid_profile["stagger_offset_m"] = _node_float(child, ["stagger_offset_m"], start_grid_stagger_offset_m)
					start_grid_profile["vertical_offset_m"] = _node_float(child, ["vertical_offset_m", "height_offset_m"], start_grid_vertical_offset_m)
					start_grid_profile["position"] = to_local((child as Node3D).global_position)
				"start_grid_slot":
					start_grid_slots.append(_start_slot_record(child as Node3D))
				_:
					pass

		_collect_authoring_nodes(
			child,
			road_points,
			width_markers,
			banking_markers,
			surface_markers,
			zone_markers,
			start_grid_slots,
			start_grid_profile
		)


func _resolve_authoring_root() -> Node:
	if not String(authoring_root_path).is_empty():
		return get_node_or_null(authoring_root_path)

	for candidate_name: String in ["TrackAuthoring", "Authoring", "RoadAuthoring"]:
		var candidate: Node = get_node_or_null(candidate_name)
		if candidate != null:
			return candidate
	return null


func _road_point_record(node: Node3D) -> Dictionary:
	return {
		"position": to_local(node.global_position),
		"up": _node_vector3(node, ["up", "normal", "up_vector"], Vector3.UP),
		"width_m": _node_float(node, ["width_m", "road_width_m", "width"], default_road_width_m),
		"banking_degrees": _node_float(node, ["banking_degrees", "banking", "bank_degrees"], 0.0),
		"surface_id": _node_string_name(node, ["surface_id", "surface_type", "surface"], TrackQueryV2.DEFAULT_SURFACE_ID),
		"zone_id": _node_string_name(node, ["zone_id", "zone"], TrackQueryV2.DEFAULT_ZONE_ID),
		"road_distance_m": _node_float(node, ["road_distance_m", "distance_m", "distance"], INF),
		"sequence_index": int(_node_float(node, ["sequence_index", "authoring_order"], 0.0)),
		"marker_id": _node_string_name(node, ["marker_id"], StringName(node.name)),
	}


func _sort_road_point_records(a: Dictionary, b: Dictionary) -> bool:
	var a_distance: float = float(a.get("road_distance_m", INF))
	var b_distance: float = float(b.get("road_distance_m", INF))
	var a_has_distance: bool = is_finite(a_distance)
	var b_has_distance: bool = is_finite(b_distance)
	if a_has_distance and b_has_distance and not is_equal_approx(a_distance, b_distance):
		return a_distance < b_distance
	if a_has_distance != b_has_distance:
		return a_has_distance

	var a_sequence: int = int(a.get("sequence_index", 0))
	var b_sequence: int = int(b.get("sequence_index", 0))
	if a_sequence != b_sequence:
		return a_sequence < b_sequence
	return String(a.get("marker_id", "")) < String(b.get("marker_id", ""))


func _marker_record(node: Node3D, value_key: String, value: Variant) -> Dictionary:
	var record: Dictionary = {
		value_key: value,
		"position": to_local(node.global_position),
	}
	var distance_value: Variant = _node_value(node, ["distance_m", "distance", "anchor_distance_m"], null)
	if distance_value != null:
		record["distance_m"] = float(distance_value)
	return record


func _start_slot_record(node: Node3D) -> Dictionary:
	var record: Dictionary = {
		"transform": global_transform.affine_inverse() * node.global_transform,
		"vertical_offset_m": _node_float(node, ["vertical_offset_m", "height_offset_m"], start_grid_vertical_offset_m),
	}
	var distance_value: Variant = _node_value(node, ["distance_m", "distance", "anchor_distance_m"], null)
	if distance_value != null:
		record["distance_m"] = float(distance_value)
	var lateral_value: Variant = _node_value(node, ["lateral_offset_m", "lane_offset_m"], null)
	if lateral_value != null:
		record["lateral_offset_m"] = float(lateral_value)
	return record


func _preview_authoring_data() -> Dictionary:
	return {
		"road_points": [
			{
				"position": Vector3(0.0, 0.0, 0.0),
				"width_m": 14.0,
				"banking_degrees": 0.0,
				"surface_id": &"wet_asphalt",
				"zone_id": &"start_straight",
			},
			{
				"position": Vector3(0.0, 1.8, 150.0),
				"width_m": 14.0,
				"banking_degrees": 1.5,
				"surface_id": &"wet_asphalt",
				"zone_id": &"coastal_approach",
			},
			{
				"position": Vector3(78.0, 7.5, 290.0),
				"width_m": 12.2,
				"banking_degrees": 7.0,
				"surface_id": &"wet_asphalt",
				"zone_id": &"cliffside",
			},
			{
				"position": Vector3(154.0, 13.0, 430.0),
				"width_m": 15.8,
				"banking_degrees": -4.0,
				"surface_id": &"event_ramp",
				"zone_id": &"jump_approach",
			},
			{
				"position": Vector3(92.0, 18.0, 575.0),
				"width_m": 16.5,
				"banking_degrees": 0.0,
				"surface_id": &"landing_asphalt",
				"zone_id": &"landing_recovery",
			},
			{
				"position": Vector3(-32.0, 10.0, 715.0),
				"width_m": 13.4,
				"banking_degrees": -6.0,
				"surface_id": &"wet_asphalt",
				"zone_id": &"mountain_return",
			},
			{
				"position": Vector3(-12.0, 3.0, 860.0),
				"width_m": 14.2,
				"banking_degrees": 2.0,
				"surface_id": &"wet_asphalt",
				"zone_id": &"final_sweep",
			},
		],
		"closed_loop": false,
		"smooth_centerline": smooth_centerline,
		"centerline_tangent_strength": centerline_tangent_strength,
		"curve_subdivisions": curve_subdivisions,
		"default_road_width_m": default_road_width_m,
		"lane_count": lane_count,
		"lane_spacing_m": lane_spacing_m,
		"start_grid_profile": _default_start_grid_profile(),
	}


func _empty_authoring_data() -> Dictionary:
	return {
		"road_points": [],
		"closed_loop": closed_loop,
		"smooth_centerline": smooth_centerline,
		"centerline_tangent_strength": centerline_tangent_strength,
		"curve_subdivisions": curve_subdivisions,
		"default_road_width_m": default_road_width_m,
		"lane_count": lane_count,
		"lane_spacing_m": lane_spacing_m,
		"start_grid_profile": _default_start_grid_profile(),
	}


func _default_start_grid_profile() -> Dictionary:
	return {
		"grid_origin_distance_m": start_grid_origin_distance_m,
		"slot_count": start_grid_slot_count,
		"columns": start_grid_columns,
		"lane_spacing_m": start_grid_lane_spacing_m,
		"row_spacing_m": start_grid_row_spacing_m,
		"stagger_offset_m": start_grid_stagger_offset_m,
		"vertical_offset_m": start_grid_vertical_offset_m,
	}


func _builder_options() -> Dictionary:
	return {
		"root_name": generated_root_name,
		"clear_existing": true,
		"sample_spacing_m": sample_spacing_m,
		"lane_count": lane_count,
		"generate_road": generate_road,
		"generate_collision": generate_collision,
		"collision_spacing_m": collision_spacing_m,
		"collision_thickness_m": collision_thickness_m,
		"collision_width_margin_m": collision_width_margin_m,
		"collision_surface_lift_m": collision_surface_lift_m,
		"collision_segment_overlap_m": collision_segment_overlap_m,
		"generate_lane_markings": generate_lane_markings,
		"generate_shoulders": generate_shoulders,
		"generate_curbs": generate_curbs,
		"generate_surrounding_terrain": generate_surrounding_terrain,
		"terrain_width_m": terrain_width_m,
		"terrain_outer_drop_m": terrain_outer_drop_m,
		"terrain_roughness_m": terrain_roughness_m,
		"terrain_edge_gap_m": terrain_edge_gap_m,
		"terrain_band_count": terrain_band_count,
		"terrain_mountain_height_m": terrain_mountain_height_m,
		"terrain_ridge_position": terrain_ridge_position,
		"generate_guardrail_hooks": generate_guardrail_hooks,
		"generate_guardrail_markers": generate_guardrail_markers,
		"shoulder_width_m": shoulder_width_m,
		"curb_width_m": curb_width_m,
		"guardrail_sample_spacing_m": guardrail_sample_spacing_m,
		"guardrail_hook_spacing_m": guardrail_hook_spacing_m,
		"guardrail_edge_offset_m": guardrail_edge_offset_m,
		"guardrail_collision_thickness_m": guardrail_collision_thickness_m,
		"guardrail_collision_height_m": guardrail_collision_height_m,
		"guardrail_collision_overlap_m": guardrail_collision_overlap_m,
		"guardrail_seam_gap_m": guardrail_seam_gap_m,
		"assign_owner": assign_owner_in_editor and Engine.is_editor_hint(),
	}


func _node_kind(node: Node) -> String:
	if node.has_method("get_marker_kind"):
		var marker_kind: String = String(node.call("get_marker_kind")).to_lower()
		if not marker_kind.is_empty() and marker_kind != "marker":
			return marker_kind

	var explicit_kind: String = String(_node_value(node, ["authoring_role", "track_role", "marker_type", "role"], "")).to_lower()
	if not explicit_kind.is_empty():
		return explicit_kind

	var node_name: String = node.name.to_lower()
	if node_name.begins_with("rp_") or node_name.contains("roadpoint") or node_name.contains("road_point"):
		return "road_point"
	if node_name.contains("widthmarker") or node_name.contains("width_marker"):
		return "width_marker"
	if node_name.contains("bankingmarker") or node_name.contains("banking_marker"):
		return "banking_marker"
	if node_name.contains("surfacemarker") or node_name.contains("surface_marker"):
		return "surface_marker"
	if node_name.contains("zonemarker") or node_name.contains("zone_marker"):
		return "zone_marker"
	if node_name.contains("startgridslot") or node_name.contains("start_grid_slot") or node_name.contains("startslot"):
		return "start_grid_slot"
	if node_name.contains("startgrid") or node_name.contains("start_grid"):
		return "start_grid_marker"
	return ""


func _node_float(node: Object, keys: Array, fallback: float) -> float:
	var value: Variant = _node_value(node, keys, null)
	if value == null:
		return fallback
	return float(value)


func _node_vector3(node: Object, keys: Array, fallback: Vector3) -> Vector3:
	var value: Variant = _node_value(node, keys, null)
	if value is Vector3:
		return value
	return fallback


func _node_string_name(node: Object, keys: Array, fallback: StringName) -> StringName:
	var value: Variant = _node_value(node, keys, null)
	if value == null:
		return fallback
	if value is StringName:
		return value
	return StringName(String(value))


func _node_value(node: Object, keys: Array, fallback: Variant = null) -> Variant:
	for key_value: Variant in keys:
		var key: String = String(key_value)
		if node.has_meta(key):
			return node.get_meta(key)
		var value: Variant = node.get(key)
		if value != null:
			return value
	return fallback
