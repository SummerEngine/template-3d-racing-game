class_name TestTrack5km
extends Node3D

const SceneryProps := preload("res://scripts/procedural/procedural_scenery_prop_factory.gd")

const TRACK_NODE_NAME: String = "GeneratedTrack"
const ROAD_WIDTH_M: float = 10.0
const HALF_ROAD_WIDTH_M: float = ROAD_WIDTH_M * 0.5
const ROAD_Y_OFFSET_M: float = 0.0
const MARKING_Y_OFFSET_M: float = 0.035
const GUARDRAIL_CENTER_OFFSET_M: float = HALF_ROAD_WIDTH_M + 0.55
const GUARDRAIL_THICKNESS_M: float = 0.55
const GUARDRAIL_HEIGHT_M: float = 1.15
const GUARDRAIL_POST_SPACING_M: float = 24.0
const GUARDRAIL_POST_SIZE_M: float = 0.42
const CENTER_DASH_LENGTH_M: float = 6.0
const CENTER_DASH_GAP_M: float = 9.0
const CENTER_DASH_WIDTH_M: float = 0.32
const CENTER_DASH_START_OFFSET_M: float = 24.0
const START_LINE_WIDTH_M: float = 9.4
const START_LINE_LENGTH_M: float = 1.4

@export var target_track_length_m: float = 5000.0
@export var centerline_samples: int = 420
@export var track_y: float = 0.03
@export var place_player_car_on_ready: bool = true
@export var player_car_path: NodePath = ^"PlayerCar"
@export var spawn_forward_offset_m: float = 18.0
@export var spawn_vertical_offset_m: float = 0.14
@export var spawn_procedural_scenery: bool = true
@export var scenery_seed: int = 7123
@export var scenery_spacing_m: float = 170.0

var track_length_m: float = 0.0

var _centerline: PackedVector3Array = PackedVector3Array()
var _distance_table: PackedFloat32Array = PackedFloat32Array()
var _initial_spawn_transform: Transform3D = Transform3D.IDENTITY
var _generated_root: Node3D = null
var _terrain_container: Node3D = null
var _road_container: Node3D = null
var _markings_container: Node3D = null
var _guardrails_container: Node3D = null
var _collision_container: Node3D = null
var _scenery_container: Node3D = null
var _helpers_container: Node3D = null


func _ready() -> void:
	regenerate_track()


func regenerate_track() -> void:
	_clear_generated_track()
	_create_containers()

	_centerline = _build_centerline()
	_distance_table = _build_distance_table(_centerline)
	track_length_m = _distance_table[_distance_table.size() - 1]
	_initial_spawn_transform = _compute_spawn_transform(spawn_forward_offset_m)

	var bounds: Rect2 = _bounds_xz(_centerline)
	_create_grass(bounds)
	_create_ground_collision(bounds)
	_create_road(_centerline)
	_create_center_dashes(_centerline, _distance_table)
	_create_start_line()
	_create_guardrails(_centerline, _distance_table)
	if spawn_procedural_scenery:
		_create_procedural_scenery()
	_create_spawn_marker()

	set_meta("track_length_m", track_length_m)
	set_meta("road_width_m", ROAD_WIDTH_M)
	set_meta("initial_spawn_transform", _initial_spawn_transform)

	if place_player_car_on_ready:
		place_player_car_at_start()

	print("Generated closed %.0fm low-poly test track with %.1fm road width." % [track_length_m, ROAD_WIDTH_M])


func get_initial_spawn_transform() -> Transform3D:
	return _initial_spawn_transform


func place_player_car_at_start() -> void:
	var player_node: Node = get_node_or_null(player_car_path)
	if player_node == null or not player_node is Node3D:
		return

	var player_car := player_node as Node3D
	player_car.global_transform = _initial_spawn_transform
	if player_car is CharacterBody3D:
		var body := player_car as CharacterBody3D
		body.velocity = Vector3.ZERO


func _clear_generated_track() -> void:
	var old_node: Node = get_node_or_null(TRACK_NODE_NAME)
	if old_node != null:
		remove_child(old_node)
		old_node.free()


func _create_containers() -> void:
	_generated_root = _add_container(self, TRACK_NODE_NAME)
	_terrain_container = _add_container(_generated_root, "Terrain")
	_road_container = _add_container(_generated_root, "Road")
	_markings_container = _add_container(_generated_root, "Markings")
	_guardrails_container = _add_container(_generated_root, "Guardrails")
	_collision_container = _add_container(_generated_root, "Collision")
	_scenery_container = _add_container(_generated_root, "Scenery")
	_helpers_container = _add_container(_generated_root, "Helpers")


func _add_container(parent: Node, container_name: String) -> Node3D:
	var container := Node3D.new()
	container.name = container_name
	parent.add_child(container)
	return container


func _build_centerline() -> PackedVector3Array:
	var samples: int = maxi(centerline_samples, 96)
	var raw_points := PackedVector3Array()

	for i: int in range(samples):
		var theta: float = TAU * float(i) / float(samples)
		var radius: float = (
			1.0
			+ 0.16 * sin(theta * 3.0 + 0.35)
			+ 0.08 * sin(theta * 5.0 - 1.1)
			+ 0.05 * cos(theta * 2.0 + 0.9)
		)
		raw_points.append(Vector3(cos(theta) * radius, track_y, sin(theta) * radius))

	var raw_length: float = _closed_path_length(raw_points)
	var track_scale: float = target_track_length_m / raw_length
	var scaled_points := PackedVector3Array()
	for point: Vector3 in raw_points:
		scaled_points.append(Vector3(point.x * track_scale, track_y, point.z * track_scale))

	return _align_first_segment_to_spawn_axis(scaled_points)


func _align_first_segment_to_spawn_axis(points: PackedVector3Array) -> PackedVector3Array:
	var tangent: Vector3 = _tangent_at(points, 0)
	var yaw_to_positive_z: float = atan2(-tangent.x, tangent.z)
	var rotated_points := PackedVector3Array()

	for point: Vector3 in points:
		rotated_points.append(point.rotated(Vector3.UP, yaw_to_positive_z))

	var start: Vector3 = rotated_points[0]
	var aligned_points := PackedVector3Array()
	for point: Vector3 in rotated_points:
		aligned_points.append(Vector3(point.x - start.x, track_y, point.z - start.z))

	return aligned_points


func _build_distance_table(points: PackedVector3Array) -> PackedFloat32Array:
	var distances := PackedFloat32Array()
	var distance: float = 0.0
	distances.append(distance)

	for i: int in range(points.size()):
		distance += points[i].distance_to(points[(i + 1) % points.size()])
		distances.append(distance)

	return distances


func _create_grass(bounds: Rect2) -> void:
	var grass_size: float = maxf(bounds.size.x, bounds.size.y) + 360.0
	var grass_mesh := PlaneMesh.new()
	grass_mesh.size = Vector2(grass_size, grass_size)

	var grass := MeshInstance3D.new()
	grass.name = "GrassField"
	grass.mesh = grass_mesh
	grass.position = Vector3(bounds.get_center().x, track_y - 0.04, bounds.get_center().y)
	grass.material_override = _material(Color(0.08, 0.32, 0.12, 1.0), 0.9)
	_terrain_container.add_child(grass)


func _create_ground_collision(bounds: Rect2) -> void:
	var ground_size: float = maxf(bounds.size.x, bounds.size.y) + 360.0
	var body := StaticBody3D.new()
	body.name = "GeneratedGroundCollision"
	body.collision_layer = 1
	body.collision_mask = 1
	_collision_container.add_child(body)

	var shape := BoxShape3D.new()
	shape.size = Vector3(ground_size, 0.2, ground_size)

	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	collision.shape = shape
	collision.position = Vector3(bounds.get_center().x, track_y - 0.12, bounds.get_center().y)
	body.add_child(collision)


func _create_road(points: PackedVector3Array) -> void:
	var road := MeshInstance3D.new()
	road.name = "Road_%.0fm_10mWide" % track_length_m
	road.mesh = _strip_mesh(points, 0.0, ROAD_WIDTH_M, track_y + ROAD_Y_OFFSET_M)
	road.material_override = _material(Color(0.015, 0.016, 0.018, 1.0), 0.82)
	_road_container.add_child(road)


func _create_center_dashes(points: PackedVector3Array, distances: PackedFloat32Array) -> void:
	var dashes := MeshInstance3D.new()
	dashes.name = "WhiteCenterDashes"
	dashes.mesh = _center_dash_mesh(points, distances, track_y + MARKING_Y_OFFSET_M)
	dashes.material_override = _material(Color(0.96, 0.96, 0.92, 1.0), 0.38)
	_markings_container.add_child(dashes)


func _create_start_line() -> void:
	var sample: Dictionary = _sample_at_distance(_centerline, _distance_table, 0.0)
	var center: Vector3 = sample["position"]
	var tangent: Vector3 = sample["tangent"]
	var normal: Vector3 = _normal_from_tangent(tangent)
	center.y = track_y + MARKING_Y_OFFSET_M + 0.01

	var line := MeshInstance3D.new()
	line.name = "StartFinishLine"
	line.mesh = _quad_mesh(center + tangent * 3.0, normal, tangent, START_LINE_WIDTH_M, START_LINE_LENGTH_M, center.y)
	line.material_override = _material(Color(0.98, 0.98, 0.94, 1.0), 0.3)
	_markings_container.add_child(line)


func _create_guardrails(points: PackedVector3Array, distances: PackedFloat32Array) -> void:
	var rail_material: StandardMaterial3D = _material(Color(0.58, 0.6, 0.57, 1.0), 0.64)
	rail_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var post_material: StandardMaterial3D = _material(Color(0.72, 0.74, 0.7, 1.0), 0.58)

	for side: float in [-1.0, 1.0]:
		var side_name: String = "Left" if side < 0.0 else "Right"

		var rail := MeshInstance3D.new()
		rail.name = "Guardrail%sBeam" % side_name
		rail.mesh = _guardrail_beam_mesh(points, side)
		rail.material_override = rail_material
		_guardrails_container.add_child(rail)

		var posts := MeshInstance3D.new()
		posts.name = "Guardrail%sPosts" % side_name
		posts.mesh = _guardrail_post_mesh(points, distances, side)
		posts.material_override = post_material
		_guardrails_container.add_child(posts)

	_create_guardrail_collision(points)


func _create_guardrail_collision(points: PackedVector3Array) -> void:
	var body := StaticBody3D.new()
	body.name = "GuardrailCollision"
	body.collision_layer = 1
	body.collision_mask = 1
	_collision_container.add_child(body)

	for side: float in [-1.0, 1.0]:
		for i: int in range(points.size()):
			var next_index: int = (i + 1) % points.size()
			var start: Vector3 = _offset_point(points, i, side * GUARDRAIL_CENTER_OFFSET_M)
			var end: Vector3 = _offset_point(points, next_index, side * GUARDRAIL_CENTER_OFFSET_M)
			var segment: Vector3 = end - start
			segment.y = 0.0
			var length: float = segment.length()
			if length <= 0.01:
				continue

			var tangent: Vector3 = segment / length
			var normal: Vector3 = _normal_from_tangent(tangent)
			var segment_basis := Basis(normal, Vector3.UP, tangent).orthonormalized()
			var shape := BoxShape3D.new()
			shape.size = Vector3(GUARDRAIL_THICKNESS_M + 0.28, GUARDRAIL_HEIGHT_M + 0.45, length + 0.75)

			var collision := CollisionShape3D.new()
			collision.name = "GuardrailCollision_%s_%03d" % ["L" if side < 0.0 else "R", i]
			collision.shape = shape
			collision.transform = Transform3D(
				segment_basis,
				(start + end) * 0.5 + Vector3.UP * ((GUARDRAIL_HEIGHT_M + 0.45) * 0.5)
			)
			body.add_child(collision)


func _create_spawn_marker() -> void:
	var marker := Marker3D.new()
	marker.name = "InitialSpawnTransform"
	marker.global_transform = _initial_spawn_transform
	_helpers_container.add_child(marker)


func _create_procedural_scenery() -> void:
	var spacing: float = maxf(scenery_spacing_m, 80.0)
	var distance: float = 55.0
	var step_index: int = 0

	while distance < track_length_m:
		var zone: String = _zone_for_distance(distance)
		var sample: Dictionary = _sample_at_distance(_centerline, _distance_table, distance)
		_create_zone_ground_patch(sample, zone, -1.0, step_index)
		_create_zone_ground_patch(sample, zone, 1.0, step_index)

		match zone:
			"suburban":
				_place_scenery_prop("house", sample, -1.0, 38.0 + float(step_index % 4) * 6.0, step_index, {
					"size": Vector3(10.0 + float(step_index % 3), 4.8, 7.5),
				})
				_place_scenery_prop("house", sample, 1.0, 46.0 + float((step_index + 2) % 4) * 5.0, step_index + 41, {
					"size": Vector3(9.0 + float((step_index + 1) % 3), 4.5, 7.0),
				})
			"highway":
				_place_scenery_prop("crop", sample, -1.0, 42.0, step_index, {
					"size": Vector2(46.0, 30.0),
					"row_count": 8,
				})
				_place_scenery_prop("crop", sample, 1.0, 46.0, step_index + 7, {
					"size": Vector2(52.0, 34.0),
					"row_count": 9,
				})
				if step_index % 3 == 0:
					var billboard_side: float = -1.0 if step_index % 2 == 0 else 1.0
					_place_scenery_prop("billboard", sample, billboard_side, 62.0, step_index + 23, {
						"panel_size": Vector2(10.0, 4.0),
						"clearance": 5.2,
					})
			"industrial":
				_place_scenery_prop("factory", sample, -1.0, 62.0, step_index, {
					"size": Vector3(20.0, 7.0, 15.0),
				})
				if step_index % 2 == 0:
					_place_scenery_prop("container", sample, 1.0, 34.0, step_index + 13, {
						"size": Vector3(12.0, 2.8, 3.0),
					})
					_place_scenery_prop("container", sample, 1.0, 46.0, step_index + 17, {
						"size": Vector3(12.0, 2.8, 3.0),
					})
				else:
					_place_scenery_prop("factory", sample, 1.0, 72.0, step_index + 29, {
						"size": Vector3(18.0, 6.0, 13.0),
					})

		distance += spacing
		step_index += 1


func _create_zone_ground_patch(sample: Dictionary, zone: String, side: float, step_index: int) -> void:
	var sample_position: Vector3 = sample["position"]
	var tangent: Vector3 = sample["tangent"]
	var normal: Vector3 = _normal_from_tangent(tangent) * side
	var center: Vector3 = sample_position + normal * 42.0
	center.y = track_y - 0.025

	var mesh := BoxMesh.new()
	mesh.size = Vector3(48.0, 0.035, maxf(scenery_spacing_m * 0.82, 65.0))

	var patch := MeshInstance3D.new()
	patch.name = "%sGroundPatch_%03d_%s" % [zone.capitalize(), step_index, "L" if side < 0.0 else "R"]
	patch.mesh = mesh
	patch.material_override = _material(_zone_ground_color(zone, step_index), 0.92)
	patch.global_transform = Transform3D(Basis(normal, Vector3.UP, tangent).orthonormalized(), center)
	_scenery_container.add_child(patch)


func _place_scenery_prop(
	kind: String,
	sample: Dictionary,
	side: float,
	lateral_offset: float,
	step_index: int,
	options: Dictionary
) -> void:
	var sample_position: Vector3 = sample["position"]
	var tangent: Vector3 = sample["tangent"]
	var normal: Vector3 = _normal_from_tangent(tangent) * side
	var prop_position: Vector3 = sample_position + normal * lateral_offset
	prop_position.y = track_y

	var prop_seed: int = scenery_seed + step_index * 97 + int(side * 19.0)
	var prop: Node3D = SceneryProps.create_prop(kind, prop_seed, options)
	prop.name = "%s_%03d_%s" % [prop.name, step_index, "L" if side < 0.0 else "R"]

	var face_road: Vector3 = -normal
	var yaw_jitter: float = deg_to_rad(float((prop_seed % 9) - 4) * 2.5)
	prop.global_transform = Transform3D(_basis_from_forward(face_road).rotated(Vector3.UP, yaw_jitter), prop_position)
	_scenery_container.add_child(prop)


func _zone_for_distance(distance: float) -> String:
	var ratio: float = fposmod(distance, track_length_m) / track_length_m
	if ratio < 0.23 or ratio > 0.86:
		return "suburban"
	if ratio < 0.58:
		return "highway"
	return "industrial"


func _zone_ground_color(zone: String, variant: int) -> Color:
	match zone:
		"suburban":
			return Color(0.12 + 0.02 * float(variant % 3), 0.38, 0.15, 1.0)
		"highway":
			return Color(0.34 + 0.04 * float(variant % 2), 0.42, 0.12, 1.0)
		"industrial":
			return Color(0.31, 0.32 + 0.02 * float(variant % 3), 0.33, 1.0)
		_:
			return Color(0.1, 0.28, 0.12, 1.0)


func _compute_spawn_transform(distance: float) -> Transform3D:
	var sample: Dictionary = _sample_at_distance(_centerline, _distance_table, distance)
	var origin: Vector3 = sample["position"]
	var forward: Vector3 = sample["tangent"]
	origin.y = track_y + spawn_vertical_offset_m
	return Transform3D(_basis_from_forward(forward), origin)


func _basis_from_forward(forward: Vector3) -> Basis:
	var flat_forward := Vector3(forward.x, 0.0, forward.z).normalized()
	if flat_forward.length_squared() <= 0.0001:
		flat_forward = Vector3(0.0, 0.0, 1.0)

	var back: Vector3 = -flat_forward
	var right: Vector3 = Vector3.UP.cross(back).normalized()
	return Basis(right, Vector3.UP, back).orthonormalized()


func _strip_mesh(points: PackedVector3Array, offset: float, width: float, y: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var distance: float = 0.0

	for i: int in range(points.size()):
		if i > 0:
			distance += points[i - 1].distance_to(points[i])

		var tangent: Vector3 = _tangent_at(points, i)
		var normal: Vector3 = _normal_from_tangent(tangent)
		var center: Vector3 = points[i] + normal * offset
		center.y = y
		vertices.append(center - normal * width * 0.5)
		vertices.append(center + normal * width * 0.5)
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)
		uvs.append(Vector2(0.0, distance / 20.0))
		uvs.append(Vector2(1.0, distance / 20.0))

	for i: int in range(points.size()):
		var next: int = (i + 1) % points.size()
		var a: int = i * 2
		var b: int = i * 2 + 1
		var c: int = next * 2
		var d: int = next * 2 + 1
		indices.append_array([a, c, b, b, c, d])

	return _array_mesh_from_surface(vertices, normals, uvs, indices)


func _center_dash_mesh(points: PackedVector3Array, distances: PackedFloat32Array, y: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var stride: float = CENTER_DASH_LENGTH_M + CENTER_DASH_GAP_M
	var dash_count: int = floori(maxf(track_length_m - CENTER_DASH_START_OFFSET_M, 0.0) / stride)

	for i: int in range(dash_count):
		var center_distance: float = CENTER_DASH_START_OFFSET_M + float(i) * stride + CENTER_DASH_LENGTH_M * 0.5
		var sample: Dictionary = _sample_at_distance(points, distances, center_distance)
		var center: Vector3 = sample["position"]
		var tangent: Vector3 = sample["tangent"]
		var normal: Vector3 = _normal_from_tangent(tangent)
		center.y = y
		_append_flat_quad(
			vertices,
			normals,
			uvs,
			indices,
			center,
			normal,
			tangent,
			CENTER_DASH_WIDTH_M,
			CENTER_DASH_LENGTH_M
		)

	return _array_mesh_from_surface(vertices, normals, uvs, indices)


func _guardrail_beam_mesh(points: PackedVector3Array, side: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	for i: int in range(points.size()):
		var next: int = (i + 1) % points.size()
		var current_sample: Dictionary = _guardrail_cross_section(points, i, side)
		var next_sample: Dictionary = _guardrail_cross_section(points, next, side)

		var inner_bottom_a: Vector3 = current_sample["inner_bottom"]
		var inner_top_a: Vector3 = current_sample["inner_top"]
		var outer_bottom_a: Vector3 = current_sample["outer_bottom"]
		var outer_top_a: Vector3 = current_sample["outer_top"]
		var inner_bottom_b: Vector3 = next_sample["inner_bottom"]
		var inner_top_b: Vector3 = next_sample["inner_top"]
		var outer_bottom_b: Vector3 = next_sample["outer_bottom"]
		var outer_top_b: Vector3 = next_sample["outer_top"]
		var side_normal: Vector3 = current_sample["side_normal"]

		_append_mesh_quad(vertices, normals, uvs, indices, inner_bottom_a, inner_bottom_b, inner_top_a, inner_top_b, -side_normal)
		_append_mesh_quad(vertices, normals, uvs, indices, outer_bottom_a, outer_top_a, outer_bottom_b, outer_top_b, side_normal)
		_append_mesh_quad(vertices, normals, uvs, indices, inner_top_a, inner_top_b, outer_top_a, outer_top_b, Vector3.UP)

	return _array_mesh_from_surface(vertices, normals, uvs, indices)


func _guardrail_cross_section(points: PackedVector3Array, index: int, side: float) -> Dictionary:
	var tangent: Vector3 = _tangent_at(points, index)
	var side_normal: Vector3 = _normal_from_tangent(tangent) * side
	var center: Vector3 = points[index] + side_normal * GUARDRAIL_CENTER_OFFSET_M
	var inner: Vector3 = center - side_normal * (GUARDRAIL_THICKNESS_M * 0.5)
	var outer: Vector3 = center + side_normal * (GUARDRAIL_THICKNESS_M * 0.5)
	inner.y = track_y
	outer.y = track_y

	return {
		"inner_bottom": inner,
		"outer_bottom": outer,
		"inner_top": inner + Vector3.UP * GUARDRAIL_HEIGHT_M,
		"outer_top": outer + Vector3.UP * GUARDRAIL_HEIGHT_M,
		"side_normal": side_normal,
	}


func _guardrail_post_mesh(points: PackedVector3Array, distances: PackedFloat32Array, side: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var post_count: int = floori(track_length_m / GUARDRAIL_POST_SPACING_M)

	for i: int in range(post_count):
		var sample: Dictionary = _sample_at_distance(points, distances, float(i) * GUARDRAIL_POST_SPACING_M)
		var sample_position: Vector3 = sample["position"]
		var tangent: Vector3 = sample["tangent"]
		var side_normal: Vector3 = _normal_from_tangent(tangent) * side
		var center: Vector3 = sample_position + side_normal * GUARDRAIL_CENTER_OFFSET_M
		center.y = track_y + GUARDRAIL_HEIGHT_M * 0.5
		var post_basis := Basis(side_normal, Vector3.UP, tangent).orthonormalized()
		_append_box(
			vertices,
			normals,
			uvs,
			indices,
			Transform3D(post_basis, center),
			Vector3(GUARDRAIL_POST_SIZE_M, GUARDRAIL_HEIGHT_M, GUARDRAIL_POST_SIZE_M)
		)

	return _array_mesh_from_surface(vertices, normals, uvs, indices)


func _quad_mesh(center: Vector3, normal: Vector3, tangent: Vector3, width: float, length: float, y: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	center.y = y
	_append_flat_quad(vertices, normals, uvs, indices, center, normal, tangent, width, length)
	return _array_mesh_from_surface(vertices, normals, uvs, indices)


func _append_flat_quad(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	indices: PackedInt32Array,
	center: Vector3,
	normal: Vector3,
	tangent: Vector3,
	width: float,
	length: float
) -> void:
	var half_width: Vector3 = normal.normalized() * width * 0.5
	var half_length: Vector3 = tangent.normalized() * length * 0.5
	_append_mesh_quad(
		vertices,
		normals,
		uvs,
		indices,
		center - half_width - half_length,
		center + half_width - half_length,
		center - half_width + half_length,
		center + half_width + half_length,
		Vector3.UP
	)


func _append_mesh_quad(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	indices: PackedInt32Array,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3,
	normal: Vector3
) -> void:
	var start_index: int = vertices.size()
	vertices.append_array([a, b, c, d])
	normals.append_array([normal, normal, normal, normal])
	uvs.append_array([Vector2.ZERO, Vector2.RIGHT, Vector2.UP, Vector2.ONE])
	indices.append_array([start_index, start_index + 2, start_index + 1, start_index + 1, start_index + 2, start_index + 3])


func _append_box(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	indices: PackedInt32Array,
	box_transform: Transform3D,
	size: Vector3
) -> void:
	var hx: float = size.x * 0.5
	var hy: float = size.y * 0.5
	var hz: float = size.z * 0.5
	var corners: Array[Vector3] = [
		Vector3(-hx, -hy, -hz),
		Vector3(hx, -hy, -hz),
		Vector3(-hx, hy, -hz),
		Vector3(hx, hy, -hz),
		Vector3(-hx, -hy, hz),
		Vector3(hx, -hy, hz),
		Vector3(-hx, hy, hz),
		Vector3(hx, hy, hz),
	]

	var world_corners: Array[Vector3] = []
	for corner: Vector3 in corners:
		world_corners.append(box_transform * corner)

	_append_mesh_quad(vertices, normals, uvs, indices, world_corners[0], world_corners[1], world_corners[2], world_corners[3], -box_transform.basis.z)
	_append_mesh_quad(vertices, normals, uvs, indices, world_corners[5], world_corners[4], world_corners[7], world_corners[6], box_transform.basis.z)
	_append_mesh_quad(vertices, normals, uvs, indices, world_corners[4], world_corners[0], world_corners[6], world_corners[2], -box_transform.basis.x)
	_append_mesh_quad(vertices, normals, uvs, indices, world_corners[1], world_corners[5], world_corners[3], world_corners[7], box_transform.basis.x)
	_append_mesh_quad(vertices, normals, uvs, indices, world_corners[2], world_corners[3], world_corners[6], world_corners[7], box_transform.basis.y)
	_append_mesh_quad(vertices, normals, uvs, indices, world_corners[4], world_corners[5], world_corners[0], world_corners[1], -box_transform.basis.y)


func _array_mesh_from_surface(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	indices: PackedInt32Array
) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _sample_at_distance(points: PackedVector3Array, distances: PackedFloat32Array, distance: float) -> Dictionary:
	var total_length: float = distances[distances.size() - 1]
	var wrapped_distance: float = fposmod(distance, total_length)

	for i: int in range(points.size()):
		var start_distance: float = distances[i]
		var end_distance: float = distances[i + 1]
		if wrapped_distance <= end_distance:
			var segment_length: float = maxf(end_distance - start_distance, 0.001)
			var t: float = (wrapped_distance - start_distance) / segment_length
			var next: int = (i + 1) % points.size()
			var sampled_position: Vector3 = points[i].lerp(points[next], t)
			var tangent: Vector3 = points[next] - points[i]
			tangent.y = 0.0
			return {
				"position": sampled_position,
				"tangent": tangent.normalized(),
			}

	return {
		"position": points[0],
		"tangent": _tangent_at(points, 0),
	}


func _offset_point(points: PackedVector3Array, index: int, offset: float) -> Vector3:
	var tangent: Vector3 = _tangent_at(points, index)
	var normal: Vector3 = _normal_from_tangent(tangent)
	var point: Vector3 = points[index] + normal * offset
	point.y = track_y
	return point


func _tangent_at(points: PackedVector3Array, index: int) -> Vector3:
	var prev: Vector3 = points[(index - 1 + points.size()) % points.size()]
	var next: Vector3 = points[(index + 1) % points.size()]
	var tangent: Vector3 = next - prev
	tangent.y = 0.0
	if tangent.length_squared() <= 0.0001:
		return Vector3(0.0, 0.0, 1.0)
	return tangent.normalized()


func _normal_from_tangent(tangent: Vector3) -> Vector3:
	var flat_tangent := Vector3(tangent.x, 0.0, tangent.z)
	if flat_tangent.length_squared() <= 0.0001:
		return Vector3.RIGHT
	return Vector3(flat_tangent.z, 0.0, -flat_tangent.x).normalized()


func _closed_path_length(points: PackedVector3Array) -> float:
	var length: float = 0.0
	for i: int in range(points.size()):
		length += points[i].distance_to(points[(i + 1) % points.size()])
	return length


func _bounds_xz(points: PackedVector3Array) -> Rect2:
	var min_x: float = points[0].x
	var max_x: float = points[0].x
	var min_z: float = points[0].z
	var max_z: float = points[0].z
	for point: Vector3 in points:
		min_x = minf(min_x, point.x)
		max_x = maxf(max_x, point.x)
		min_z = minf(min_z, point.z)
		max_z = maxf(max_z, point.z)
	return Rect2(Vector2(min_x, min_z), Vector2(max_x - min_x, max_z - min_z))


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material
