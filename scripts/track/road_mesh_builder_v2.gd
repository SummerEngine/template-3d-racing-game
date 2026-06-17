class_name RoadMeshBuilderV2
extends RefCounted

const DEFAULT_ROOT_NAME: String = "GeneratedRoadV2"
const ROAD_UV_SCALE_M: float = 20.0
const MARKING_UV_SCALE_M: float = 8.0
const WET_ASPHALT_MATERIAL := preload("res://resources/materials/storm_coast_wet_asphalt_placeholder.tres")


func build(parent: Node3D, query: TrackQueryV2, options: Dictionary = {}) -> Node3D:
	if parent == null or query == null:
		return null

	var root_name: String = String(options.get("root_name", DEFAULT_ROOT_NAME))
	if bool(options.get("clear_existing", true)):
		var old_root: Node = parent.get_node_or_null(root_name)
		if old_root != null:
			parent.remove_child(old_root)
			old_root.free()

	var root := Node3D.new()
	root.name = root_name
	root.set_meta("track_query_v2", query)
	root.set_meta("track_length_m", query.get_track_length_m())
	parent.add_child(root)

	var road_mesh: ArrayMesh = build_road_surface_mesh(query, options)
	if bool(options.get("generate_road", true)):
		var road := MeshInstance3D.new()
		road.name = "RoadSurface"
		road.mesh = road_mesh
		road.material_override = _road_material()
		root.add_child(road)

	if bool(options.get("generate_collision", true)):
		_create_collision(root, query, options)

	if bool(options.get("generate_lane_markings", true)):
		_create_mesh_child(
			root,
			"LaneMarkings",
			build_lane_markings_mesh(query, options),
			_material(Color(0.92, 0.92, 0.86, 1.0), 0.42, 0.0)
		)

	if bool(options.get("generate_shoulders", true)):
		_create_mesh_child(
			root,
			"Shoulders",
			build_shoulders_mesh(query, options),
			_material(Color(0.16, 0.15, 0.14, 1.0), 0.9, 0.0)
		)

	if bool(options.get("generate_curbs", true)):
		_create_mesh_child(
			root,
			"Curbs",
			build_curbs_mesh(query, options),
			_material(Color(0.82, 0.15, 0.12, 1.0), 0.55, 0.0)
		)

	if bool(options.get("generate_surrounding_terrain", true)):
		_create_mesh_child(
			root,
			"SurroundingTerrain",
			build_surrounding_terrain_mesh(query, options),
			_terrain_material()
		)

	if bool(options.get("generate_guardrail_hooks", true)):
		_create_guardrail_branch(root, query, options)

	if bool(options.get("assign_owner", false)):
		var owner_node: Node = parent.owner if parent.owner != null else parent
		_assign_owner_recursive(root, owner_node)

	return root


func build_road_surface_mesh(query: TrackQueryV2, options: Dictionary = {}) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var ring_count: int = _ring_count(query, options)
	var length_m: float = maxf(query.get_track_length_m(), 0.001)

	for i: int in range(ring_count):
		var distance_m: float = _distance_for_ring(i, ring_count, length_m)
		var sample: Dictionary = query.sample_at_distance(distance_m)
		var center: Vector3 = sample["position"]
		var right: Vector3 = sample["right"]
		var up: Vector3 = sample["up"]
		var width_m: float = float(sample["road_width_m"])
		vertices.append(center - right * width_m * 0.5)
		vertices.append(center + right * width_m * 0.5)
		normals.append(up)
		normals.append(up)
		uvs.append(Vector2(0.0, distance_m / ROAD_UV_SCALE_M))
		uvs.append(Vector2(width_m / ROAD_UV_SCALE_M, distance_m / ROAD_UV_SCALE_M))

	for i: int in range(ring_count - 1):
		var a: int = i * 2
		var b: int = i * 2 + 1
		var c: int = (i + 1) * 2
		var d: int = (i + 1) * 2 + 1
		indices.append_array([a, b, c, b, d, c])

	return _array_mesh_from_surface(vertices, normals, uvs, indices)


func build_lane_markings_mesh(query: TrackQueryV2, options: Dictionary = {}) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var lane_count: int = maxi(int(options.get("lane_count", 2)), 1)
	if lane_count <= 1:
		return _array_mesh_from_surface(vertices, normals, uvs, indices)

	var dash_length_m: float = float(options.get("dash_length_m", 6.0))
	var dash_gap_m: float = float(options.get("dash_gap_m", 9.0))
	var marking_width_m: float = float(options.get("lane_marking_width_m", 0.28))
	var vertical_offset_m: float = float(options.get("marking_vertical_offset_m", 0.035))
	var start_offset_m: float = float(options.get("dash_start_offset_m", 18.0))
	var stride_m: float = maxf(dash_length_m + dash_gap_m, 0.1)
	var track_length_m: float = query.get_track_length_m()
	var dash_count: int = floori(maxf(track_length_m - start_offset_m, 0.0) / stride_m)

	for dash_index: int in range(dash_count):
		var center_distance_m: float = start_offset_m + float(dash_index) * stride_m + dash_length_m * 0.5
		for line_index: int in range(1, lane_count):
			var sample: Dictionary = query.sample_at_distance(center_distance_m)
			var width_m: float = float(sample["road_width_m"])
			var lateral_offset_m: float = -width_m * 0.5 + width_m * float(line_index) / float(lane_count)
			var transform: Transform3D = query.surface_transform(center_distance_m, lateral_offset_m, vertical_offset_m)
			_append_oriented_quad(
				vertices,
				normals,
				uvs,
				indices,
				transform,
				marking_width_m,
				dash_length_m,
				center_distance_m
			)

	return _array_mesh_from_surface(vertices, normals, uvs, indices)


func build_shoulders_mesh(query: TrackQueryV2, options: Dictionary = {}) -> ArrayMesh:
	var shoulder_width_m: float = float(options.get("shoulder_width_m", 1.35))
	var vertical_offset_m: float = float(options.get("shoulder_vertical_offset_m", -0.012))
	return _build_side_strips_mesh(query, shoulder_width_m, 0.0, vertical_offset_m, false, options)


func build_curbs_mesh(query: TrackQueryV2, options: Dictionary = {}) -> ArrayMesh:
	var curb_width_m: float = float(options.get("curb_width_m", 0.42))
	var vertical_offset_m: float = float(options.get("curb_vertical_offset_m", 0.035))
	return _build_side_strips_mesh(query, curb_width_m, 0.0, vertical_offset_m, true, options)


func build_surrounding_terrain_mesh(query: TrackQueryV2, options: Dictionary = {}) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var ring_count: int = _ring_count(query, options)
	var length_m: float = maxf(query.get_track_length_m(), 0.001)
	var terrain_width_m: float = maxf(float(options.get("terrain_width_m", 72.0)), 1.0)
	var edge_gap_m: float = maxf(float(options.get("terrain_edge_gap_m", 2.5)), 0.0)
	var outer_drop_m: float = maxf(float(options.get("terrain_outer_drop_m", 6.5)), 0.0)
	var roughness_m: float = maxf(float(options.get("terrain_roughness_m", 1.8)), 0.0)

	for side: float in [-1.0, 1.0]:
		var base_index: int = vertices.size()
		var side_sign: float = -1.0 if side < 0.0 else 1.0
		for i: int in range(ring_count):
			var distance_m: float = _distance_for_ring(i, ring_count, length_m)
			var sample: Dictionary = query.sample_at_distance(distance_m)
			var center: Vector3 = sample["position"]
			var right: Vector3 = sample["right"]
			var up: Vector3 = sample["up"]
			var width_m: float = float(sample["road_width_m"])
			var inner_offset: float = side_sign * (width_m * 0.5 + edge_gap_m)
			var outer_offset: float = side_sign * (width_m * 0.5 + edge_gap_m + terrain_width_m)
			var terrain_wave_m: float = _terrain_height_wave(distance_m, side_sign, roughness_m)
			var inner_height_m: float = -0.28 + terrain_wave_m * 0.16
			var outer_height_m: float = -outer_drop_m + terrain_wave_m

			vertices.append(center + right * inner_offset + up * inner_height_m)
			vertices.append(center + right * outer_offset + up * outer_height_m)
			normals.append(up)
			normals.append(up)
			uvs.append(Vector2(0.0, distance_m / ROAD_UV_SCALE_M))
			uvs.append(Vector2(terrain_width_m / ROAD_UV_SCALE_M, distance_m / ROAD_UV_SCALE_M))

		for i: int in range(ring_count - 1):
			var a: int = base_index + i * 2
			var b: int = base_index + i * 2 + 1
			var c: int = base_index + (i + 1) * 2
			var d: int = base_index + (i + 1) * 2 + 1
			if side < 0.0:
				indices.append_array([a, c, b, b, c, d])
			else:
				indices.append_array([a, b, c, b, d, c])

	return _array_mesh_from_surface(vertices, normals, uvs, indices)


func build_guardrail_preview_mesh(query: TrackQueryV2, side: float, options: Dictionary = {}) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var ring_count: int = _ring_count(query, options)
	var length_m: float = maxf(query.get_track_length_m(), 0.001)
	var edge_offset_m: float = float(options.get("guardrail_edge_offset_m", 0.72))
	var rail_height_m: float = float(options.get("guardrail_height_m", 0.95))
	var beam_height_m: float = float(options.get("guardrail_beam_height_m", 0.34))
	var side_sign: float = -1.0 if side < 0.0 else 1.0

	for i: int in range(ring_count):
		var distance_m: float = _distance_for_ring(i, ring_count, length_m)
		var sample: Dictionary = query.sample_at_distance(distance_m)
		var transform: Transform3D = query.road_edge_transform(distance_m, side_sign, edge_offset_m)
		var up: Vector3 = sample["up"]
		var outward: Vector3 = sample["right"] * side_sign
		var lower: Vector3 = transform.origin + up * rail_height_m
		var upper: Vector3 = transform.origin + up * (rail_height_m + beam_height_m)
		vertices.append(lower)
		vertices.append(upper)
		normals.append(outward)
		normals.append(outward)
		uvs.append(Vector2(0.0, distance_m / ROAD_UV_SCALE_M))
		uvs.append(Vector2(1.0, distance_m / ROAD_UV_SCALE_M))

	for i: int in range(ring_count - 1):
		var a: int = i * 2
		var b: int = i * 2 + 1
		var c: int = (i + 1) * 2
		var d: int = (i + 1) * 2 + 1
		indices.append_array([a, c, b, b, c, d])

	return _array_mesh_from_surface(vertices, normals, uvs, indices)


func _build_side_strips_mesh(
	query: TrackQueryV2,
	strip_width_m: float,
	edge_gap_m: float,
	vertical_offset_m: float,
	inside_road: bool,
	options: Dictionary
) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var ring_count: int = _ring_count(query, options)
	var length_m: float = maxf(query.get_track_length_m(), 0.001)

	for side: float in [-1.0, 1.0]:
		var base_index: int = vertices.size()
		for i: int in range(ring_count):
			var distance_m: float = _distance_for_ring(i, ring_count, length_m)
			var sample: Dictionary = query.sample_at_distance(distance_m)
			var center: Vector3 = sample["position"]
			var right: Vector3 = sample["right"]
			var up: Vector3 = sample["up"]
			var width_m: float = float(sample["road_width_m"])
			var side_sign: float = -1.0 if side < 0.0 else 1.0
			var inner_offset: float = side_sign * (width_m * 0.5 + edge_gap_m)
			var outer_offset: float = side_sign * (width_m * 0.5 + edge_gap_m + strip_width_m)
			if inside_road:
				inner_offset = side_sign * maxf(width_m * 0.5 - strip_width_m, 0.0)
				outer_offset = side_sign * width_m * 0.5

			vertices.append(center + right * inner_offset + up * vertical_offset_m)
			vertices.append(center + right * outer_offset + up * vertical_offset_m)
			normals.append(up)
			normals.append(up)
			uvs.append(Vector2(0.0, distance_m / ROAD_UV_SCALE_M))
			uvs.append(Vector2(strip_width_m / ROAD_UV_SCALE_M, distance_m / ROAD_UV_SCALE_M))

		for i: int in range(ring_count - 1):
			var a: int = base_index + i * 2
			var b: int = base_index + i * 2 + 1
			var c: int = base_index + (i + 1) * 2
			var d: int = base_index + (i + 1) * 2 + 1
			if side < 0.0:
				indices.append_array([a, c, b, b, c, d])
			else:
				indices.append_array([a, b, c, b, d, c])

	return _array_mesh_from_surface(vertices, normals, uvs, indices)


func _create_collision(root: Node3D, query: TrackQueryV2, options: Dictionary) -> void:
	if query == null or query.get_track_length_m() <= 0.0:
		return

	var body := StaticBody3D.new()
	body.name = "RoadCollision"
	body.collision_layer = 1
	body.collision_mask = 1
	body.set_meta("collision_mode", "segment_slabs")
	root.add_child(body)

	var track_length_m: float = query.get_track_length_m()
	var spacing_m: float = maxf(float(options.get("collision_spacing_m", options.get("sample_spacing_m", 5.0))), 0.5)
	var segment_count: int = maxi(ceili(track_length_m / spacing_m), 1)
	var segment_length_m: float = track_length_m / float(segment_count)
	var thickness_m: float = maxf(float(options.get("collision_thickness_m", 0.9)), 0.05)
	var width_margin_m: float = maxf(float(options.get("collision_width_margin_m", 0.35)), 0.0)
	var surface_lift_m: float = float(options.get("collision_surface_lift_m", 0.02))
	var overlap_m: float = maxf(float(options.get("collision_segment_overlap_m", 0.6)), 0.0)

	for i: int in range(segment_count):
		var start_distance_m: float = float(i) * segment_length_m
		var end_distance_m: float = minf(start_distance_m + segment_length_m, track_length_m)
		var slab_length_m: float = maxf(end_distance_m - start_distance_m + overlap_m, 0.1)
		var midpoint_distance_m: float = start_distance_m + (end_distance_m - start_distance_m) * 0.5
		var sample: Dictionary = query.sample_at_distance(midpoint_distance_m)
		var width_m: float = maxf(float(sample["road_width_m"]) + width_margin_m * 2.0, 0.1)

		var shape := BoxShape3D.new()
		shape.size = Vector3(width_m, thickness_m, slab_length_m)

		var collision := CollisionShape3D.new()
		collision.name = "CollisionShape3D" if i == 0 else "CollisionShape3D_%03d" % i
		collision.shape = shape
		collision.transform = query.surface_transform(
			midpoint_distance_m,
			0.0,
			surface_lift_m - thickness_m * 0.5
		)
		body.add_child(collision)


func _create_guardrail_branch(root: Node3D, query: TrackQueryV2, options: Dictionary) -> void:
	var guardrails := Node3D.new()
	guardrails.name = "Guardrails"
	root.add_child(guardrails)

	var material: StandardMaterial3D = _material(Color(0.54, 0.57, 0.56, 1.0), 0.62, 0.0)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	for side: float in [-1.0, 1.0]:
		var side_name: String = "Left" if side < 0.0 else "Right"
		_create_mesh_child(
			guardrails,
			"Guardrail%sPreviewBeam" % side_name,
			build_guardrail_preview_mesh(query, side, options),
			material
		)

	var hooks := Node3D.new()
	hooks.name = "GuardrailHooks"
	guardrails.add_child(hooks)
	_create_guardrail_hooks(hooks, query, options)


func _create_guardrail_hooks(parent: Node3D, query: TrackQueryV2, options: Dictionary) -> void:
	var spacing_m: float = float(options.get("guardrail_hook_spacing_m", 16.0))
	var edge_offset_m: float = float(options.get("guardrail_edge_offset_m", 0.72))
	var vertical_offset_m: float = float(options.get("guardrail_hook_vertical_offset_m", 0.0))
	var length_m: float = query.get_track_length_m()
	var hook_count: int = maxi(ceili(length_m / maxf(spacing_m, 0.1)), 1)

	for side: float in [-1.0, 1.0]:
		var side_name: String = "L" if side < 0.0 else "R"
		for i: int in range(hook_count):
			var distance_m: float = minf(float(i) * spacing_m, length_m)
			var marker := Marker3D.new()
			marker.name = "GuardrailHook_%s_%03d" % [side_name, i]
			marker.transform = query.road_edge_transform(distance_m, side, edge_offset_m, vertical_offset_m)
			marker.set_meta("track_distance_m", distance_m)
			marker.set_meta("road_side", side)
			marker.set_meta("edge_offset_m", edge_offset_m)
			marker.set_meta("surface_id", query.get_surface_type_at_distance(distance_m))
			marker.set_meta("zone_id", query.get_zone_at_distance(distance_m))
			parent.add_child(marker)


func _create_mesh_child(
	parent: Node3D,
	node_name: String,
	mesh: ArrayMesh,
	material: StandardMaterial3D
) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.material_override = material
	parent.add_child(node)
	return node


func _append_oriented_quad(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	indices: PackedInt32Array,
	transform: Transform3D,
	width_m: float,
	length_m: float,
	distance_m: float
) -> void:
	var right: Vector3 = transform.basis.x.normalized()
	var up: Vector3 = transform.basis.y.normalized()
	var forward: Vector3 = -transform.basis.z.normalized()
	var half_width: Vector3 = right * width_m * 0.5
	var half_length: Vector3 = forward * length_m * 0.5
	var start_index: int = vertices.size()
	vertices.append(transform.origin - half_width - half_length)
	vertices.append(transform.origin + half_width - half_length)
	vertices.append(transform.origin - half_width + half_length)
	vertices.append(transform.origin + half_width + half_length)
	normals.append_array([up, up, up, up])
	uvs.append_array([
		Vector2(0.0, distance_m / MARKING_UV_SCALE_M),
		Vector2(1.0, distance_m / MARKING_UV_SCALE_M),
		Vector2(0.0, (distance_m + length_m) / MARKING_UV_SCALE_M),
		Vector2(1.0, (distance_m + length_m) / MARKING_UV_SCALE_M),
	])
	indices.append_array([start_index, start_index + 1, start_index + 2, start_index + 1, start_index + 3, start_index + 2])


func _array_mesh_from_surface(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	indices: PackedInt32Array
) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if vertices.is_empty() or indices.is_empty():
		return mesh

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _ring_count(query: TrackQueryV2, options: Dictionary) -> int:
	var spacing_m: float = float(options.get("sample_spacing_m", 5.0))
	var min_samples: int = maxi(int(options.get("min_samples", 8)), 2)
	var length_m: float = query.get_track_length_m()
	return maxi(ceili(length_m / maxf(spacing_m, 0.25)) + 1, min_samples + 1)


func _distance_for_ring(index: int, ring_count: int, length_m: float) -> float:
	if ring_count <= 1:
		return 0.0
	return length_m * float(index) / float(ring_count - 1)


func _material(color: Color, roughness: float = 0.82, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


func _road_material() -> Material:
	var source_material: Material = WET_ASPHALT_MATERIAL
	if source_material != null:
		return source_material.duplicate() as Material
	return _material(Color(0.018, 0.021, 0.024, 1.0), 0.18, 0.0)


func _terrain_material() -> StandardMaterial3D:
	var material: StandardMaterial3D = _material(Color(0.16, 0.20, 0.17, 1.0), 0.96, 0.0)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _terrain_height_wave(distance_m: float, side_sign: float, roughness_m: float) -> float:
	if roughness_m <= 0.0:
		return 0.0
	return (
		sin(distance_m * 0.012 + side_sign * 1.7) * roughness_m
		+ sin(distance_m * 0.031 + side_sign * 4.9) * roughness_m * 0.35
	)


func _assign_owner_recursive(node: Node, owner_node: Node) -> void:
	if node == null or owner_node == null:
		return
	node.owner = owner_node
	for child: Node in node.get_children():
		_assign_owner_recursive(child, owner_node)
