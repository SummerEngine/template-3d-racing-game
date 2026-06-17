@tool
class_name CoastalBackdrop
extends Node3D

const GENERATED_ROOT_NAME: String = "GeneratedCoastalBackdrop"

@export var generate_on_ready: bool = true
@export_range(300.0, 2000.0, 10.0) var horizon_distance_m: float = 980.0
@export_range(400.0, 3000.0, 10.0) var backdrop_width_m: float = 1800.0
@export_range(-80.0, 20.0, 1.0) var ocean_height_m: float = -18.0
@export var ocean_color: Color = Color(0.10, 0.32, 0.52, 1.0)
@export var near_hill_color: Color = Color(0.20, 0.36, 0.25, 1.0)
@export var far_mountain_color: Color = Color(0.30, 0.43, 0.50, 1.0)
@export var city_color: Color = Color(0.78, 0.84, 0.88, 1.0)
@export var cloud_color: Color = Color(0.95, 0.97, 1.0, 0.24)


func _ready() -> void:
	if generate_on_ready:
		call_deferred("regenerate")


func regenerate() -> void:
	_clear_generated()

	var root := Node3D.new()
	root.name = GENERATED_ROOT_NAME
	add_child(root)

	_create_ocean(root)
	_create_mountain_layer(
		root,
		"FarMountains",
		horizon_distance_m + 250.0,
		-34.0,
		far_mountain_color,
		[
			Vector2(-920.0, 54.0),
			Vector2(-760.0, 132.0),
			Vector2(-610.0, 92.0),
			Vector2(-430.0, 176.0),
			Vector2(-225.0, 108.0),
			Vector2(-40.0, 154.0),
			Vector2(160.0, 84.0),
			Vector2(360.0, 136.0),
			Vector2(580.0, 94.0),
			Vector2(780.0, 142.0),
			Vector2(940.0, 70.0),
		],
		0.86
	)
	_create_city_strip(root)
	_create_mountain_layer(
		root,
		"CoastalHills",
		horizon_distance_m - 95.0,
		-22.0,
		near_hill_color,
		[
			Vector2(-910.0, 28.0),
			Vector2(-710.0, 62.0),
			Vector2(-540.0, 48.0),
			Vector2(-360.0, 76.0),
			Vector2(-160.0, 44.0),
			Vector2(80.0, 58.0),
			Vector2(280.0, 40.0),
			Vector2(520.0, 82.0),
			Vector2(740.0, 46.0),
			Vector2(920.0, 64.0),
		],
		0.94
	)
	_create_cloud_cluster(
		root,
		"CloudBankHigh",
		Vector3(-220.0, 245.0, horizon_distance_m + 150.0),
		[
			{"offset": Vector3(-190.0, -6.0, 0.0), "size": Vector2(250.0, 54.0), "alpha": 0.16},
			{"offset": Vector3(-48.0, 12.0, -2.0), "size": Vector2(360.0, 78.0), "alpha": 0.20},
			{"offset": Vector3(160.0, -4.0, 1.5), "size": Vector2(270.0, 60.0), "alpha": 0.15},
		]
	)
	_create_cloud_cluster(
		root,
		"CloudBankRight",
		Vector3(390.0, 198.0, horizon_distance_m + 80.0),
		[
			{"offset": Vector3(-135.0, 0.0, 0.0), "size": Vector2(220.0, 48.0), "alpha": 0.14},
			{"offset": Vector3(20.0, 8.0, -2.0), "size": Vector2(280.0, 62.0), "alpha": 0.18},
			{"offset": Vector3(175.0, -5.0, 1.0), "size": Vector2(180.0, 42.0), "alpha": 0.13},
		]
	)
	_create_cloud_cluster(
		root,
		"CloudBankLeft",
		Vector3(-570.0, 182.0, horizon_distance_m + 35.0),
		[
			{"offset": Vector3(-82.0, 4.0, 0.0), "size": Vector2(190.0, 46.0), "alpha": 0.13},
			{"offset": Vector3(62.0, -2.0, -2.0), "size": Vector2(230.0, 52.0), "alpha": 0.17},
		]
	)


func _clear_generated() -> void:
	var old_root: Node = get_node_or_null(GENERATED_ROOT_NAME)
	if old_root == null:
		return
	remove_child(old_root)
	old_root.free()


func _create_ocean(parent: Node3D) -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(backdrop_width_m, 960.0)

	var ocean := MeshInstance3D.new()
	ocean.name = "OceanPlane"
	ocean.mesh = mesh
	ocean.position = Vector3(80.0, ocean_height_m, horizon_distance_m - 120.0)
	ocean.material_override = _make_material(ocean_color, 0.62, 0.0, false)
	parent.add_child(ocean)


func _create_city_strip(parent: Node3D) -> void:
	var city_root := Node3D.new()
	city_root.name = "DistantCity"
	city_root.position = Vector3(340.0, -5.0, horizon_distance_m + 45.0)
	parent.add_child(city_root)

	var widths: Array[float] = [34.0, 22.0, 42.0, 28.0, 52.0, 18.0, 38.0, 58.0, 24.0, 46.0, 30.0, 66.0, 20.0, 42.0]
	var heights: Array[float] = [42.0, 76.0, 58.0, 96.0, 70.0, 48.0, 122.0, 82.0, 54.0, 108.0, 62.0, 88.0, 44.0, 74.0]
	var cursor_x: float = -290.0
	for i: int in range(widths.size()):
		var width: float = widths[i]
		var height: float = heights[i]
		var building := MeshInstance3D.new()
		building.name = "CityBlock_%02d" % i
		var mesh := BoxMesh.new()
		mesh.size = Vector3(width, height, 28.0)
		building.mesh = mesh
		building.position = Vector3(cursor_x + width * 0.5, height * 0.5, sin(float(i) * 0.9) * 20.0)
		building.material_override = _make_material(city_color.lerp(Color(0.58, 0.66, 0.72, 1.0), float(i % 4) * 0.08), 0.88, 0.0, false)
		city_root.add_child(building)
		cursor_x += width + 10.0


func _create_mountain_layer(
	parent: Node3D,
	layer_name: String,
	z_position: float,
	base_y: float,
	color: Color,
	profile: Array,
	roughness: float
) -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	for i: int in range(profile.size()):
		var point: Vector2 = profile[i]
		vertices.append(Vector3(point.x, base_y, z_position))
		vertices.append(Vector3(point.x, base_y + point.y, z_position + sin(float(i) * 1.73) * 10.0))
		normals.append(Vector3(0.0, 0.0, -1.0))
		normals.append(Vector3(0.0, 0.0, -1.0))
		uvs.append(Vector2(float(i), 0.0))
		uvs.append(Vector2(float(i), 1.0))

	for i: int in range(profile.size() - 1):
		var a: int = i * 2
		var b: int = i * 2 + 1
		var c: int = (i + 1) * 2
		var d: int = (i + 1) * 2 + 1
		indices.append_array([a, b, c, b, d, c])

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var layer := MeshInstance3D.new()
	layer.name = layer_name
	layer.mesh = mesh
	layer.material_override = _make_material(color, roughness, 0.0, false)
	parent.add_child(layer)


func _create_cloud_cluster(parent: Node3D, cluster_name: String, cluster_position: Vector3, puffs: Array) -> void:
	var cluster := Node3D.new()
	cluster.name = cluster_name
	cluster.position = cluster_position
	parent.add_child(cluster)

	for i: int in range(puffs.size()):
		var puff: Dictionary = puffs[i]
		var offset: Vector3 = puff.get("offset", Vector3.ZERO)
		var size: Vector2 = puff.get("size", Vector2(180.0, 42.0))
		var alpha: float = float(puff.get("alpha", cloud_color.a))
		var puff_color: Color = Color(cloud_color.r, cloud_color.g, cloud_color.b, alpha)

		var cloud := MeshInstance3D.new()
		cloud.name = "Puff_%02d" % i
		cloud.mesh = _ellipse_mesh(size)
		cloud.position = offset
		cloud.material_override = _make_material(puff_color, 1.0, 0.0, true)
		cluster.add_child(cloud)


func _ellipse_mesh(size: Vector2) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var segment_count: int = 28
	var half_size: Vector2 = size * 0.5

	vertices.append(Vector3.ZERO)
	normals.append(Vector3(0.0, 0.0, -1.0))
	uvs.append(Vector2(0.5, 0.5))

	for i: int in range(segment_count):
		var angle: float = TAU * float(i) / float(segment_count)
		var unit := Vector2(cos(angle), sin(angle))
		vertices.append(Vector3(unit.x * half_size.x, unit.y * half_size.y, 0.0))
		normals.append(Vector3(0.0, 0.0, -1.0))
		uvs.append(unit * 0.5 + Vector2(0.5, 0.5))

	for i: int in range(segment_count):
		var next_index: int = 1 + ((i + 1) % segment_count)
		indices.append_array([0, 1 + i, next_index])

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _make_material(color: Color, roughness: float, metallic: float, transparent: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if transparent or color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material
