@tool
class_name StormCoastAuthoringRoot
extends Node3D

const PREVIEW_ROOT_NAME: String = "AuthoringPreview"
const TRACK_AUTHORING_MARKER_SCRIPT := preload("res://scripts/track_authoring/track_authoring_marker.gd")
const ROAD_POINT_SCRIPT := preload("res://scripts/track_authoring/road_point.gd")
const WIDTH_MARKER_SCRIPT := preload("res://scripts/track_authoring/width_marker.gd")
const BANKING_MARKER_SCRIPT := preload("res://scripts/track_authoring/banking_marker.gd")
const ELEVATION_MARKER_SCRIPT := preload("res://scripts/track_authoring/elevation_marker.gd")
const ZONE_MARKER_SCRIPT := preload("res://scripts/track_authoring/zone_marker.gd")
const START_GRID_MARKER_SCRIPT := preload("res://scripts/track_authoring/start_grid_marker.gd")
const SET_PIECE_MARKER_SCRIPT := preload("res://scripts/track_authoring/set_piece_marker.gd")

@export var authoring_profile: Resource = null
@export_node_path("Node3D") var authoring_branch_path: NodePath = NodePath("Authoring")
@export_node_path("Node3D") var generated_branch_path: NodePath = NodePath("Generated")
@export_node_path("Node3D") var manual_overrides_branch_path: NodePath = NodePath("ManualOverrides")
@export_node_path("Node3D") var set_pieces_branch_path: NodePath = NodePath("SetPieces")
@export_node_path("Node3D") var track_generator_path: NodePath = NodePath("Generated/StormCoastTrackGenerator")
@export_range(0.1, 6.0, 0.1) var preview_segment_width_m: float = 1.2
@export var preview_clear_only_named_scaffold: bool = true
@export_multiline var last_tool_status: String = "No authoring tool action has run in this editor session."

@export_tool_button("Preview Regenerate") var preview_regenerate_button: Callable = preview_regenerate
@export_tool_button("Bake Editable") var bake_editable_button: Callable = bake_editable
@export_tool_button("Freeze Final") var freeze_final_button: Callable = freeze_final


func preview_regenerate() -> Dictionary:
	_ensure_standard_branches()
	var records: Dictionary = collect_authoring_records()
	var generated_branch := get_node_or_null(generated_branch_path) as Node3D
	var road_points: Array = collect_road_points()

	if generated_branch != null:
		_replace_preview_scaffold(generated_branch, road_points)

	var generator_status: String = _regenerate_track_generator()
	last_tool_status = "Preview Regenerate refreshed lightweight authoring handles for %d road points. %s No ManualOverrides were deleted." % [road_points.size(), generator_status]
	_write_profile_summary(last_tool_status)
	return records


func bake_editable() -> Dictionary:
	_ensure_standard_branches()
	var records: Dictionary = collect_authoring_records()
	var generated_branch := get_node_or_null(generated_branch_path)
	if generated_branch != null:
		generated_branch.set_meta("bake_editable_requested", true)
		generated_branch.set_meta("bake_editable_status", "Placeholder only; Agent B road generation is not implemented here.")

	last_tool_status = "Bake Editable requested. Placeholder API only; Generated and ManualOverrides branches were left intact."
	_write_profile_summary(last_tool_status)
	return records


func freeze_final() -> Dictionary:
	_ensure_standard_branches()
	var records: Dictionary = collect_authoring_records()
	set_meta("freeze_final_requested", true)
	set_meta("freeze_final_status", "Placeholder only; no destructive freeze was performed.")
	if authoring_profile != null:
		authoring_profile.set("frozen_final", false)

	last_tool_status = "Freeze Final requested. Placeholder API only; no generated content was locked, renamed, or deleted."
	_write_profile_summary(last_tool_status)
	return records


func collect_authoring_records() -> Dictionary:
	var records: Dictionary = {
		"road_points": _records_for_markers(collect_road_points()),
		"width_markers": _records_for_markers(collect_width_markers()),
		"banking_markers": _records_for_markers(collect_banking_markers()),
		"elevation_markers": _records_for_markers(collect_elevation_markers()),
		"zone_markers": _records_for_markers(collect_zone_markers()),
		"start_grid_markers": _records_for_markers(collect_start_grid_markers()),
		"set_piece_markers": _records_for_markers(collect_set_piece_markers()),
	}
	set_meta("last_authoring_record_counts", get_authoring_marker_counts())
	return records


func get_authoring_marker_counts() -> Dictionary:
	return {
		"road_points": collect_road_points().size(),
		"width_markers": collect_width_markers().size(),
		"banking_markers": collect_banking_markers().size(),
		"elevation_markers": collect_elevation_markers().size(),
		"zone_markers": collect_zone_markers().size(),
		"start_grid_markers": collect_start_grid_markers().size(),
		"set_piece_markers": collect_set_piece_markers().size(),
	}


func collect_road_points() -> Array:
	var result: Array = []
	for marker: Node in _collect_markers():
		if _node_extends_script(marker, ROAD_POINT_SCRIPT) and _marker_enabled(marker):
			result.append(marker)
	result.sort_custom(_sort_road_points)
	return result


func collect_width_markers() -> Array:
	var result: Array = []
	for marker: Node in _collect_markers():
		if _node_extends_script(marker, WIDTH_MARKER_SCRIPT) and _marker_enabled(marker):
			result.append(marker)
	result.sort_custom(_sort_distance_markers)
	return result


func collect_banking_markers() -> Array:
	var result: Array = []
	for marker: Node in _collect_markers():
		if _node_extends_script(marker, BANKING_MARKER_SCRIPT) and _marker_enabled(marker):
			result.append(marker)
	result.sort_custom(_sort_distance_markers)
	return result


func collect_elevation_markers() -> Array:
	var result: Array = []
	for marker: Node in _collect_markers():
		if _node_extends_script(marker, ELEVATION_MARKER_SCRIPT) and _marker_enabled(marker):
			result.append(marker)
	result.sort_custom(_sort_distance_markers)
	return result


func collect_zone_markers() -> Array:
	var result: Array = []
	for marker: Node in _collect_markers():
		if _node_extends_script(marker, ZONE_MARKER_SCRIPT) and _marker_enabled(marker):
			result.append(marker)
	result.sort_custom(_sort_distance_markers)
	return result


func collect_start_grid_markers() -> Array:
	var result: Array = []
	for marker: Node in _collect_markers():
		if _node_extends_script(marker, START_GRID_MARKER_SCRIPT) and _marker_enabled(marker):
			result.append(marker)
	result.sort_custom(_sort_distance_markers)
	return result


func collect_set_piece_markers() -> Array:
	var result: Array = []
	for marker: Node in _collect_markers():
		if _node_extends_script(marker, SET_PIECE_MARKER_SCRIPT) and _marker_enabled(marker):
			result.append(marker)
	result.sort_custom(_sort_distance_markers)
	return result


func _collect_markers() -> Array:
	var result: Array = []
	var roots: Array[Node] = []
	var authoring_branch := get_node_or_null(authoring_branch_path)
	var set_pieces_branch := get_node_or_null(set_pieces_branch_path)
	if authoring_branch != null:
		roots.append(authoring_branch)
	if set_pieces_branch != null and set_pieces_branch != authoring_branch:
		roots.append(set_pieces_branch)

	for root: Node in roots:
		_collect_marker_descendants(root, result)
	return result


func _collect_marker_descendants(node: Node, result: Array) -> void:
	if _node_extends_script(node, TRACK_AUTHORING_MARKER_SCRIPT):
		result.append(node)
	for child: Node in node.get_children():
		_collect_marker_descendants(child, result)


func _records_for_markers(markers: Array) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for marker: Node in markers:
		records.append(marker.call("get_authoring_record"))
	return records


func _sort_road_points(a: Node, b: Node) -> bool:
	var a_index: int = int(a.get("sequence_index"))
	var b_index: int = int(b.get("sequence_index"))
	if a_index == b_index:
		return String(a.get("marker_id")) < String(b.get("marker_id"))
	return a_index < b_index


func _sort_distance_markers(a: Node, b: Node) -> bool:
	var a_distance: float = float(a.get("road_distance_m"))
	var b_distance: float = float(b.get("road_distance_m"))
	if is_equal_approx(a_distance, b_distance):
		return int(a.get("authoring_order")) < int(b.get("authoring_order"))
	return a_distance < b_distance


func _ensure_standard_branches() -> void:
	_ensure_child_node3d(String(authoring_branch_path))
	_ensure_child_node3d(String(generated_branch_path))
	_ensure_child_node3d(String(manual_overrides_branch_path))
	_ensure_child_node3d(String(set_pieces_branch_path))


func _ensure_child_node3d(node_name: String) -> Node3D:
	var existing := get_node_or_null(NodePath(node_name)) as Node3D
	if existing != null:
		return existing

	var branch := Node3D.new()
	branch.name = node_name
	add_child(branch)
	_assign_owner(branch)
	return branch


func _replace_preview_scaffold(generated_branch: Node3D, road_points: Array) -> void:
	if preview_clear_only_named_scaffold:
		var old_preview := generated_branch.get_node_or_null(PREVIEW_ROOT_NAME)
		if old_preview != null:
			generated_branch.remove_child(old_preview)
			old_preview.free()

	var preview_root := Node3D.new()
	preview_root.name = PREVIEW_ROOT_NAME
	generated_branch.add_child(preview_root)
	_assign_owner(preview_root)

	_add_preview_point_handles(preview_root, road_points)
	_add_preview_segments(preview_root, road_points)
	generated_branch.set_meta("last_preview_scaffold", "Generated by preview_regenerate; safe to replace.")


func _add_preview_point_handles(preview_root: Node3D, road_points: Array) -> void:
	var material: StandardMaterial3D = _preview_material(Color(0.1, 0.75, 1.0, 0.85))
	for road_point: Node3D in road_points:
		var handle := MeshInstance3D.new()
		handle.name = "Point_%03d_%s" % [int(road_point.get("sequence_index")), String(road_point.get("marker_id"))]
		var mesh := BoxMesh.new()
		mesh.size = Vector3(2.4, 2.4, 2.4)
		handle.mesh = mesh
		handle.material_override = material
		preview_root.add_child(handle)
		handle.global_position = road_point.global_position
		_assign_owner(handle)


func _add_preview_segments(preview_root: Node3D, road_points: Array) -> void:
	if road_points.size() < 2:
		return

	var material: StandardMaterial3D = _preview_material(Color(0.02, 0.95, 0.72, 0.5))
	var closed_loop: bool = _profile_closed_loop()
	var segment_count: int = road_points.size() if closed_loop else road_points.size() - 1
	for i: int in range(segment_count):
		var start_node := road_points[i] as Node3D
		var end_node := road_points[(i + 1) % road_points.size()] as Node3D
		var start_point: Vector3 = start_node.global_position
		var end_point: Vector3 = end_node.global_position
		var delta: Vector3 = end_point - start_point
		var length_m: float = delta.length()
		if length_m <= 0.01:
			continue

		var segment := MeshInstance3D.new()
		segment.name = "Segment_%03d" % i
		var mesh := BoxMesh.new()
		mesh.size = Vector3(preview_segment_width_m, 0.18, length_m)
		segment.mesh = mesh
		segment.material_override = material
		preview_root.add_child(segment)
		segment.global_transform = Transform3D(_basis_from_forward(delta.normalized()), start_point + delta * 0.5)
		_assign_owner(segment)


func _preview_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func _basis_from_forward(forward: Vector3) -> Basis:
	var safe_forward: Vector3 = forward.normalized()
	if safe_forward.length_squared() <= 0.0001:
		safe_forward = Vector3.FORWARD
	var up := Vector3.UP
	if absf(safe_forward.dot(up)) > 0.96:
		up = Vector3.RIGHT
	var right: Vector3 = up.cross(safe_forward).normalized()
	var adjusted_up: Vector3 = safe_forward.cross(right).normalized()
	return Basis(right, adjusted_up, -safe_forward).orthonormalized()


func _marker_enabled(marker: Node) -> bool:
	if marker.has_method("is_authoring_enabled"):
		return bool(marker.call("is_authoring_enabled"))
	return true


func _node_extends_script(node: Node, expected_script: Script) -> bool:
	var script := node.get_script() as Script
	while script != null:
		if script == expected_script:
			return true
		script = script.get_base_script()
	return false


func _profile_closed_loop() -> bool:
	if authoring_profile != null and authoring_profile.get("closed_loop") != null:
		return bool(authoring_profile.get("closed_loop"))
	return true


func _write_profile_summary(summary: String) -> void:
	if authoring_profile != null:
		authoring_profile.set("last_tool_summary", summary)


func _regenerate_track_generator() -> String:
	var generator := get_node_or_null(track_generator_path)
	if generator == null:
		return "No v2 track generator node was found."
	if not generator.has_method("regenerate_track"):
		return "Track generator node has no regenerate_track() method."

	generator.call("regenerate_track")
	var length_m: float = 0.0
	if generator.has_method("get_track_length_m"):
		length_m = float(generator.call("get_track_length_m"))
	return "V2 road mesh regenerated at %.1fm." % length_m


func _assign_owner(node: Node) -> void:
	var owner_node: Node = self
	var tree := get_tree()
	if Engine.is_editor_hint() and tree != null and tree.edited_scene_root != null:
		owner_node = tree.edited_scene_root
	node.owner = owner_node
