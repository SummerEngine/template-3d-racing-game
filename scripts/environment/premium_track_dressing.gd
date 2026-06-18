@tool
class_name PremiumTrackDressing
extends Node3D

const SPONSOR_MARKS: Array[Dictionary] = [
	{"name": "VOLT RACING", "accent": Color(0.05, 0.72, 1.0, 1.0), "base": Color(0.03, 0.05, 0.07, 1.0)},
	{"name": "APEX ENERGY", "accent": Color(0.95, 0.62, 0.14, 1.0), "base": Color(0.08, 0.07, 0.06, 1.0)},
	{"name": "GRIPFORGE", "accent": Color(0.94, 0.08, 0.12, 1.0), "base": Color(0.05, 0.05, 0.055, 1.0)},
	{"name": "NEON VECTOR", "accent": Color(0.00, 0.84, 0.78, 1.0), "base": Color(0.02, 0.035, 0.045, 1.0)},
	{"name": "STORMLINE", "accent": Color(0.72, 0.78, 0.86, 1.0), "base": Color(0.06, 0.07, 0.08, 1.0)},
]

@export_enum("city_sunset", "coastal_mountain") var style: String = "city_sunset"
@export var generate_on_ready: bool = true
@export var clear_previous_on_generate: bool = true
@export var root_name: String = "GeneratedPremiumTrackDressing"
@export_node_path("Node") var track_query_provider_path: NodePath = NodePath("../TrackAuthoring/Generated/StormCoastTrackGenerator")
@export var use_generated_sponsor_textures: bool = true
@export var sponsor_texture_paths: PackedStringArray = PackedStringArray([
	"res://assets/track/sponsors/sponsor_volt_racing.png",
	"res://assets/track/sponsors/sponsor_apex_energy.png",
	"res://assets/track/sponsors/sponsor_gripforge.png",
	"res://assets/track/sponsors/sponsor_neon_vector.png",
])
@export_file("*.glb", "*.gltf", "*.tscn") var generated_barrier_scene_path: String = "res://assets/environment/storm_coast_concrete_barrier_hunyuan.glb"
@export_file("*.glb", "*.gltf", "*.tscn") var generated_cliff_scene_path: String = "res://assets/environment/storm_coast_cliff_rock_wall_hunyuan.glb"
@export_file("*.glb", "*.gltf", "*.tscn") var generated_service_post_scene_path: String = "res://assets/environment/storm_coast_floodlight_camera_post_hunyuan.glb"
@export var generated_barrier_scene_scale: Vector3 = Vector3(2.2, 2.2, 2.2)
@export var generated_cliff_scene_scale: Vector3 = Vector3(8.0, 8.0, 8.0)
@export var generated_service_post_scene_scale: Vector3 = Vector3(2.5, 2.5, 2.5)

@export_category("City Dressing")
@export_range(4, 48, 1) var building_count: int = 28
@export_range(30.0, 260.0, 1.0) var skyline_distance_m: float = 118.0
@export_range(12.0, 90.0, 1.0) var min_building_height_m: float = 24.0
@export_range(16.0, 150.0, 1.0) var max_building_height_m: float = 82.0
@export_range(2, 18, 1) var banner_count: int = 10
@export_range(2, 16, 1) var floodlight_count: int = 8
@export_range(0, 18, 1) var reflector_post_count: int = 12

@export_category("Coastal Dressing")
@export_range(4, 32, 1) var cliff_cluster_count: int = 16
@export_range(80.0, 420.0, 1.0) var cliff_distance_m: float = 185.0
@export_range(2, 16, 1) var sailboat_count: int = 7
@export_range(0, 16, 1) var warning_sign_count: int = 8
@export_range(0, 14, 1) var powerline_pole_count: int = 7
@export_range(0, 12, 1) var mist_bank_count: int = 5
@export var track_relative_dressing_enabled: bool = true
@export_range(24.0, 120.0, 1.0) var track_barrier_segment_spacing_m: float = 34.0
@export_range(40.0, 180.0, 1.0) var track_sponsor_spacing_m: float = 118.0
@export_range(50.0, 240.0, 1.0) var track_rock_cluster_spacing_m: float = 92.0
@export_range(40.0, 220.0, 1.0) var track_service_post_spacing_m: float = 135.0

var _generated_root: Node3D = null


func _ready() -> void:
	if generate_on_ready:
		call_deferred("generate")


func generate() -> void:
	if clear_previous_on_generate:
		_clear_previous()

	_generated_root = Node3D.new()
	_generated_root.name = root_name
	add_child(_generated_root)
	_assign_owner(_generated_root)

	match style:
		"coastal_mountain":
			_generate_coastal_mountain()
		_:
			_generate_city_sunset()


func _generate_city_sunset() -> void:
	_add_floor_accent_strips()
	_add_city_skyline()
	_add_grandstand(Vector3(-78.0, 4.0, -82.0), Vector3(42.0, 8.0, 8.0), 16.0)
	_add_grandstand(Vector3(88.0, 4.0, 76.0), Vector3(48.0, 9.0, 8.0), -18.0)
	_add_pit_wall(Vector3(-34.0, 1.25, -42.0), 90.0, 11)
	_add_start_gantry()
	_add_banners()
	_add_reflector_posts(34.0, -102.0, 102.0)
	_add_floodlights()


func _generate_coastal_mountain() -> void:
	_add_ocean_plane()
	_add_hillside_city()
	_add_cliffs()
	_add_coastal_support_structures()
	_add_coastal_roadside_signage()
	_add_powerline_run()
	_add_mist_banks()
	_add_reflector_posts(36.0, -116.0, 116.0)
	_add_sailboats()
	_add_floodlights()
	_add_track_relative_coastal_details()


func _add_city_skyline() -> void:
	var material_palette: Array[StandardMaterial3D] = [
		_material(Color(0.20, 0.23, 0.25, 1.0), 0.62, 0.12),
		_material(Color(0.27, 0.30, 0.33, 1.0), 0.55, 0.18),
		_material(Color(0.15, 0.18, 0.21, 1.0), 0.68, 0.10),
	]
	for index: int in range(building_count):
		var angle := lerpf(-0.92, 0.92, float(index) / maxf(float(building_count - 1), 1.0))
		var x := sin(angle) * skyline_distance_m
		var z := -cos(angle) * skyline_distance_m - 38.0
		var height_seed := 0.5 + 0.5 * sin(float(index) * 1.73 + 0.4)
		var height := lerpf(min_building_height_m, max_building_height_m, height_seed)
		var width := 9.0 + float(index % 5) * 3.5
		var depth := 10.0 + float((index + 2) % 4) * 4.0
		var building := MeshInstance3D.new()
		building.name = "SkylineTower_%02d" % index
		var mesh := BoxMesh.new()
		mesh.size = Vector3(width, height, depth)
		building.mesh = mesh
		building.position = Vector3(x, height * 0.5 - 0.5, z)
		building.rotation_degrees.y = rad_to_deg(angle) * 0.22
		building.material_override = material_palette[index % material_palette.size()]
		_generated_root.add_child(building)
		_assign_owner(building)
		_add_building_window_rows(building, width, height, depth, index)

		if index % 3 == 0:
			_add_rooftop_light(building.position + Vector3(0.0, height * 0.5 + 0.45, 0.0))


func _add_building_window_rows(parent: Node3D, width: float, height: float, depth: float, seed_index: int) -> void:
	var row_count: int = clampi(floori(height / 6.5), 3, 10)
	var glow_color := Color(0.82, 0.94, 1.0, 1.0) if seed_index % 2 == 0 else Color(1.0, 0.76, 0.46, 1.0)
	for row_index: int in range(row_count):
		if (row_index + seed_index) % 4 == 0:
			continue
		var strip := MeshInstance3D.new()
		strip.name = "WindowBand_%02d" % row_index
		var strip_mesh := BoxMesh.new()
		strip_mesh.size = Vector3(width * (0.55 + 0.10 * float((row_index + seed_index) % 3)), 0.12, 0.055)
		strip.mesh = strip_mesh
		var y := -height * 0.5 + 3.0 + (float(row_index) + 0.5) * (height - 6.0) / maxf(float(row_count), 1.0)
		strip.position = Vector3(0.0, y, -depth * 0.5 - 0.035)
		strip.material_override = _emissive_material(glow_color, 0.42)
		parent.add_child(strip)
		_assign_owner(strip)


func _add_grandstand(stand_position: Vector3, size: Vector3, yaw_degrees: float) -> void:
	var base := MeshInstance3D.new()
	base.name = "Grandstand"
	var base_mesh := BoxMesh.new()
	base_mesh.size = size
	base.mesh = base_mesh
	base.position = stand_position
	base.rotation_degrees.y = yaw_degrees
	base.material_override = _material(Color(0.12, 0.14, 0.15, 1.0), 0.74, 0.2)
	_generated_root.add_child(base)
	_assign_owner(base)

	var rail := MeshInstance3D.new()
	rail.name = "GrandstandGlowRail"
	var rail_mesh := BoxMesh.new()
	rail_mesh.size = Vector3(size.x + 2.0, 0.22, 0.18)
	rail.mesh = rail_mesh
	rail.position = stand_position + Vector3(0.0, size.y * 0.5 + 0.25, -size.z * 0.45).rotated(Vector3.UP, deg_to_rad(yaw_degrees))
	rail.rotation_degrees.y = yaw_degrees
	rail.material_override = _emissive_material(Color(0.95, 0.46, 0.18, 1.0), 1.2)
	_generated_root.add_child(rail)
	_assign_owner(rail)


func _add_pit_wall(origin: Vector3, yaw_degrees: float, panel_count: int) -> void:
	for index: int in range(panel_count):
		var panel := MeshInstance3D.new()
		panel.name = "PitWallPanel_%02d" % index
		var mesh := BoxMesh.new()
		mesh.size = Vector3(4.6, 1.7, 0.24)
		panel.mesh = mesh
		panel.position = origin + Vector3(float(index) * 4.9, 0.0, 0.0).rotated(Vector3.UP, deg_to_rad(yaw_degrees))
		panel.rotation_degrees.y = yaw_degrees
		var color := Color(0.92, 0.94, 0.90, 1.0) if index % 2 == 0 else Color(0.12, 0.14, 0.16, 1.0)
		panel.material_override = _material(color, 0.42, 0.24)
		_generated_root.add_child(panel)
		_assign_owner(panel)
		if index % 2 == 0:
			_add_sign_label(panel, "APEX", Vector3(0.0, 0.05, -0.13), Color(0.95, 0.12, 0.12, 1.0), 0.010)


func _add_banners() -> void:
	for index: int in range(banner_count):
		var side := -1.0 if index % 2 == 0 else 1.0
		var sponsor: Dictionary = SPONSOR_MARKS[index % SPONSOR_MARKS.size()]
		var board_position := Vector3(side * 42.0, 2.2, lerpf(-94.0, 94.0, float(index) / maxf(float(banner_count - 1), 1.0)))
		_add_sponsor_board(
			"TracksideSponsor_%02d" % index,
			board_position,
			-88.0 if side < 0.0 else 88.0,
			String(sponsor["name"]),
			sponsor["base"],
			sponsor["accent"],
			Vector2(8.8, 2.55)
		)


func _add_banner_stripe(stripe_position: Vector3, yaw_degrees: float, index: int) -> void:
	var stripe := MeshInstance3D.new()
	stripe.name = "BannerAccent_%02d" % index
	var mesh := BoxMesh.new()
	mesh.size = Vector3(7.0, 0.28, 0.08)
	stripe.mesh = mesh
	stripe.position = stripe_position + Vector3(0.0, 0.62, 0.0)
	stripe.rotation_degrees.y = yaw_degrees
	stripe.material_override = _emissive_material(Color(0.95, 0.20, 0.12, 1.0), 0.65)
	_generated_root.add_child(stripe)
	_assign_owner(stripe)


func _add_start_gantry() -> void:
	var gantry_root := Node3D.new()
	gantry_root.name = "PremiumStartGantry"
	gantry_root.position = Vector3(0.0, 0.0, -18.0)
	_generated_root.add_child(gantry_root)
	_assign_owner(gantry_root)

	for side: float in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		post.name = "GantryPost_%s" % ("L" if side < 0.0 else "R")
		var post_mesh := BoxMesh.new()
		post_mesh.size = Vector3(0.42, 7.2, 0.42)
		post.mesh = post_mesh
		post.position = Vector3(side * 13.6, 3.6, 0.0)
		post.material_override = _material(Color(0.19, 0.21, 0.22, 1.0), 0.34, 0.48)
		gantry_root.add_child(post)
		_assign_owner(post)

	var bridge := MeshInstance3D.new()
	bridge.name = "GantryBridge"
	var bridge_mesh := BoxMesh.new()
	bridge_mesh.size = Vector3(29.0, 0.62, 0.55)
	bridge.mesh = bridge_mesh
	bridge.position = Vector3(0.0, 6.85, 0.0)
	bridge.material_override = _material(Color(0.16, 0.18, 0.19, 1.0), 0.28, 0.52)
	gantry_root.add_child(bridge)
	_assign_owner(bridge)

	_add_sponsor_board(
		"GantryHeroBoard",
		gantry_root.position + Vector3(0.0, 6.05, -0.42),
		0.0,
		"APEX DRIFT",
		Color(0.035, 0.038, 0.042, 1.0),
		Color(0.95, 0.58, 0.12, 1.0),
		Vector2(10.5, 1.25)
	)


func _add_floodlights() -> void:
	for index: int in range(floodlight_count):
		var side := -1.0 if index % 2 == 0 else 1.0
		var z := lerpf(-74.0, 74.0, float(index) / maxf(float(floodlight_count - 1), 1.0))
		var pole_position := Vector3(side * 72.0, 8.0, z)
		var pole := MeshInstance3D.new()
		pole.name = "FloodlightPole_%02d" % index
		var pole_mesh := CylinderMesh.new()
		pole_mesh.top_radius = 0.18
		pole_mesh.bottom_radius = 0.24
		pole_mesh.height = 16.0
		pole.mesh = pole_mesh
		pole.position = pole_position
		pole.material_override = _material(Color(0.25, 0.27, 0.28, 1.0), 0.46, 0.25)
		_generated_root.add_child(pole)
		_assign_owner(pole)

		var light := SpotLight3D.new()
		light.name = "Floodlight_%02d" % index
		light.position = pole_position + Vector3(-side * 1.0, 7.0, 0.0)
		light.look_at_from_position(light.position, Vector3(0.0, 0.0, z * 0.45), Vector3.UP)
		light.light_energy = 1.4 if style == "coastal_mountain" else 5.2
		light.spot_range = 95.0
		light.spot_angle = 34.0
		light.light_color = Color(0.88, 0.94, 1.0, 1.0)
		_generated_root.add_child(light)
		_assign_owner(light)


func _add_track_relative_coastal_details() -> void:
	if not track_relative_dressing_enabled:
		return

	var track_provider := _resolve_track_query_provider()
	if track_provider == null or not track_provider.has_method("get_track_length_m"):
		return

	var track_length_m: float = float(track_provider.call("get_track_length_m"))
	if track_length_m <= 1.0 and track_provider.has_method("regenerate_track"):
		track_provider.call("regenerate_track")
		track_length_m = float(track_provider.call("get_track_length_m"))
	if track_length_m <= 1.0:
		return

	_add_trackside_safety_barriers(track_provider, track_length_m)
	_add_trackside_sponsor_boards(track_provider, track_length_m)
	_add_brake_marker_boards(track_provider, track_length_m)
	_add_trackside_service_posts(track_provider, track_length_m)
	_add_trackside_rock_clusters(track_provider, track_length_m)
	_add_trackside_foliage_clusters(track_provider, track_length_m)


func _resolve_track_query_provider() -> Node:
	if not String(track_query_provider_path).is_empty():
		var configured := get_node_or_null(track_query_provider_path)
		if configured != null:
			return configured

	var parent_node := get_parent()
	if parent_node != null:
		var fallback := parent_node.get_node_or_null("TrackAuthoring/Generated/StormCoastTrackGenerator")
		if fallback != null:
			return fallback
	return null


func _add_trackside_safety_barriers(track_provider: Node, track_length_m: float) -> void:
	var material := _material(Color(0.48, 0.49, 0.47, 1.0), 0.72, 0.0)
	var barrier_scene: PackedScene = _load_packed_scene(generated_barrier_scene_path)
	var segment_count: int = maxi(floori(track_length_m / maxf(track_barrier_segment_spacing_m, 1.0)), 1)
	for index: int in range(segment_count):
		var distance_m: float = 18.0 + float(index) * track_barrier_segment_spacing_m
		if distance_m >= track_length_m - 18.0:
			continue
		for side: float in [-1.0, 1.0]:
			if (index + int(side * 2.0)) % 5 == 0:
				continue
			var edge_xform: Transform3D = _edge_transform(track_provider, distance_m, side, 2.65, 0.48)
			var node_name: String = "TracksideConcreteBarrier_%s_%03d" % ["L" if side < 0.0 else "R", index]
			if barrier_scene != null and index % 6 == 0:
				_add_scene_instance(node_name, barrier_scene, edge_xform, generated_barrier_scene_scale)
			else:
				_add_oriented_box(
					node_name,
					edge_xform,
					Vector3(0.42, 0.96, 5.4),
					material
				)


func _add_trackside_sponsor_boards(track_provider: Node, track_length_m: float) -> void:
	var board_index: int = 0
	var distance_m: float = 72.0
	while distance_m < track_length_m - 80.0:
		for side: float in [-1.0, 1.0]:
			if _unit_noise(board_index, int(side * 10.0)) < 0.33:
				continue
			var sponsor: Dictionary = SPONSOR_MARKS[board_index % SPONSOR_MARKS.size()]
			var panel_xform: Transform3D = _road_facing_panel_transform(track_provider, distance_m, side, 5.3, 2.15)
			_add_trackside_ad_panel(
				"TrackEdgeSponsor_%s_%03d" % ["L" if side < 0.0 else "R", board_index],
				panel_xform,
				String(sponsor["name"]),
				sponsor["base"],
				sponsor["accent"],
				Vector2(8.2, 2.25)
			)
			board_index += 1
		distance_m += track_sponsor_spacing_m


func _add_brake_marker_boards(track_provider: Node, track_length_m: float) -> void:
	var marker_distances: Array[float] = [140.0, 100.0, 60.0]
	var corner_anchors: Array[float] = [track_length_m * 0.18, track_length_m * 0.43, track_length_m * 0.68, track_length_m * 0.86]
	for corner_index: int in range(corner_anchors.size()):
		var corner_distance: float = corner_anchors[corner_index]
		for marker_index: int in range(marker_distances.size()):
			var marker_distance: float = fposmod(corner_distance - marker_distances[marker_index], track_length_m)
			for side: float in [-1.0, 1.0]:
				var panel_xform: Transform3D = _road_facing_panel_transform(track_provider, marker_distance, side, 3.6, 1.15)
				_add_trackside_marker_panel(
					"BrakeMarker_%03d_%s_%03d" % [int(marker_distances[marker_index]), "L" if side < 0.0 else "R", corner_index],
					panel_xform,
					str(int(marker_distances[marker_index]))
				)


func _add_trackside_service_posts(track_provider: Node, track_length_m: float) -> void:
	var service_post_scene: PackedScene = _load_packed_scene(generated_service_post_scene_path)
	var post_index: int = 0
	var distance_m: float = 42.0
	while distance_m < track_length_m - 30.0:
		var side := -1.0 if post_index % 2 == 0 else 1.0
		var post_xform: Transform3D = _edge_transform(track_provider, distance_m, side, 6.4, 2.4)
		if service_post_scene != null and post_index % 3 == 0:
			_add_scene_instance("GeneratedServicePost_%03d" % post_index, service_post_scene, post_xform, generated_service_post_scene_scale)
		else:
			_add_service_camera_post("ServiceCameraPost_%03d" % post_index, post_xform, side)
		post_index += 1
		distance_m += track_service_post_spacing_m


func _add_trackside_rock_clusters(track_provider: Node, track_length_m: float) -> void:
	var cliff_scene: PackedScene = _load_packed_scene(generated_cliff_scene_path)
	var rock_materials: Array[StandardMaterial3D] = [
		_material(Color(0.18, 0.22, 0.22, 1.0), 0.82, 0.02),
		_material(Color(0.24, 0.27, 0.26, 1.0), 0.78, 0.03),
		_material(Color(0.12, 0.16, 0.15, 1.0), 0.88, 0.0),
	]
	var cluster_index: int = 0
	var distance_m: float = 88.0
	while distance_m < track_length_m - 50.0:
		var side := -1.0 if cluster_index % 3 != 1 else 1.0
		var chunk_count: int = 3 + (cluster_index % 3)
		for chunk_index: int in range(chunk_count):
			var offset_m: float = 10.0 + float(chunk_index) * 5.5 + _unit_noise(cluster_index, chunk_index) * 4.0
			var height_m: float = 4.5 + _unit_noise(cluster_index + 7, chunk_index) * 7.0
			var size := Vector3(
				4.5 + _unit_noise(chunk_index, cluster_index) * 5.0,
				height_m,
				5.5 + _unit_noise(cluster_index, chunk_index + 13) * 5.5
			)
			var rock_xform: Transform3D = _edge_transform(
				track_provider,
				distance_m + float(chunk_index) * 4.2,
				side,
				offset_m,
				height_m * 0.5 - 0.4,
				_unit_noise(cluster_index, chunk_index + 31) * 26.0 - 13.0
			)
			var node_name: String = "RoadsideCliffChunk_%03d_%02d" % [cluster_index, chunk_index]
			if cliff_scene != null and chunk_index == 0 and cluster_index % 2 == 0:
				_add_scene_instance(node_name, cliff_scene, rock_xform, generated_cliff_scene_scale)
			else:
				var rock := MeshInstance3D.new()
				rock.name = node_name
				rock.mesh = _irregular_rock_mesh(size, cluster_index * 31 + chunk_index)
				rock.material_override = rock_materials[(cluster_index + chunk_index) % rock_materials.size()]
				_generated_root.add_child(rock)
				rock.global_transform = rock_xform
				_assign_owner(rock)
		cluster_index += 1
		distance_m += track_rock_cluster_spacing_m


func _add_trackside_foliage_clusters(track_provider: Node, track_length_m: float) -> void:
	var foliage_material := _material(Color(0.055, 0.12, 0.075, 1.0), 0.94, 0.0)
	var trunk_material := _material(Color(0.13, 0.09, 0.06, 1.0), 0.88, 0.0)
	var cluster_index: int = 0
	var distance_m: float = 120.0
	while distance_m < track_length_m - 80.0:
		for side: float in [-1.0, 1.0]:
			if _unit_noise(cluster_index, int(side * 8.0)) < 0.42:
				continue
			var cluster_xform: Transform3D = _edge_transform(track_provider, distance_m, side, 13.0 + _unit_noise(cluster_index, 3) * 11.0, 1.2)
			_add_tree_cluster("RoadsideTreeCluster_%s_%03d" % ["L" if side < 0.0 else "R", cluster_index], cluster_xform, foliage_material, trunk_material, cluster_index)
		cluster_index += 1
		distance_m += 165.0


func _add_trackside_ad_panel(
	node_name: String,
	panel_transform: Transform3D,
	label_text: String,
	base_color: Color,
	accent_color: Color,
	size_m: Vector2
) -> void:
	var board := MeshInstance3D.new()
	board.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size_m.x, size_m.y, 0.22)
	board.mesh = mesh
	var sponsor_texture := _sponsor_texture_for_label(label_text)
	board.material_override = _textured_material(sponsor_texture, base_color) if sponsor_texture != null else _material(base_color, 0.34, 0.12)
	_generated_root.add_child(board)
	board.global_transform = panel_transform
	_assign_owner(board)

	var stripe := MeshInstance3D.new()
	stripe.name = "TracksidePanelAccent"
	var stripe_mesh := BoxMesh.new()
	stripe_mesh.size = Vector3(size_m.x * 0.86, 0.16, 0.045)
	stripe.mesh = stripe_mesh
	stripe.position = Vector3(0.0, -size_m.y * 0.30, 0.14)
	stripe.material_override = _emissive_material(accent_color, 0.42)
	board.add_child(stripe)
	_assign_owner(stripe)

	if sponsor_texture == null:
		_add_sign_label(board, label_text, Vector3(0.0, 0.08, 0.14), Color(0.94, 0.96, 0.94, 1.0), 0.018)


func _add_trackside_marker_panel(node_name: String, panel_transform: Transform3D, label_text: String) -> void:
	var panel := MeshInstance3D.new()
	panel.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.65, 1.2, 0.14)
	panel.mesh = mesh
	panel.material_override = _material(Color(0.88, 0.90, 0.84, 1.0), 0.48, 0.0)
	_generated_root.add_child(panel)
	panel.global_transform = panel_transform
	_assign_owner(panel)
	_add_sign_label(panel, label_text, Vector3(0.0, 0.02, 0.095), Color(0.05, 0.055, 0.055, 1.0), 0.016)


func _add_service_camera_post(node_name: String, post_transform: Transform3D, side: float) -> void:
	var root := Node3D.new()
	root.name = node_name
	_generated_root.add_child(root)
	root.global_transform = post_transform
	_assign_owner(root)

	var pole := MeshInstance3D.new()
	pole.name = "Post"
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.11
	pole_mesh.bottom_radius = 0.15
	pole_mesh.height = 4.8
	pole.mesh = pole_mesh
	pole.position = Vector3(0.0, 0.0, 0.0)
	pole.material_override = _material(Color(0.17, 0.18, 0.18, 1.0), 0.46, 0.42)
	root.add_child(pole)
	_assign_owner(pole)

	var camera_box := MeshInstance3D.new()
	camera_box.name = "CameraBox"
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(0.82, 0.34, 0.48)
	camera_box.mesh = box_mesh
	camera_box.position = Vector3(side * 0.25, 2.15, 0.0)
	camera_box.material_override = _material(Color(0.06, 0.065, 0.07, 1.0), 0.34, 0.36)
	root.add_child(camera_box)
	_assign_owner(camera_box)

	var beacon := OmniLight3D.new()
	beacon.name = "SmallBeacon"
	beacon.position = Vector3(0.0, 2.65, 0.0)
	beacon.light_energy = 0.18
	beacon.omni_range = 5.0
	beacon.light_color = Color(1.0, 0.48, 0.12, 1.0)
	root.add_child(beacon)
	_assign_owner(beacon)


func _add_tree_cluster(
	node_name: String,
	cluster_transform: Transform3D,
	foliage_material: Material,
	trunk_material: Material,
	seed_index: int
) -> void:
	var root := Node3D.new()
	root.name = node_name
	_generated_root.add_child(root)
	root.global_transform = cluster_transform
	_assign_owner(root)

	for tree_index: int in range(3):
		var x := (_unit_noise(seed_index, tree_index) - 0.5) * 6.0
		var z := (_unit_noise(seed_index + 11, tree_index) - 0.5) * 5.0
		var height := 4.0 + _unit_noise(seed_index + 23, tree_index) * 3.8
		var trunk := MeshInstance3D.new()
		trunk.name = "Trunk_%02d" % tree_index
		var trunk_mesh := CylinderMesh.new()
		trunk_mesh.top_radius = 0.12
		trunk_mesh.bottom_radius = 0.20
		trunk_mesh.height = height * 0.58
		trunk.mesh = trunk_mesh
		trunk.position = Vector3(x, height * 0.29 - 1.2, z)
		trunk.material_override = trunk_material
		root.add_child(trunk)
		_assign_owner(trunk)

		var crown := MeshInstance3D.new()
		crown.name = "Crown_%02d" % tree_index
		var crown_mesh := SphereMesh.new()
		crown_mesh.radius = 1.2 + _unit_noise(seed_index + 31, tree_index) * 0.6
		crown_mesh.height = 2.2 + _unit_noise(seed_index + 43, tree_index) * 1.0
		crown.mesh = crown_mesh
		crown.position = Vector3(x, height * 0.62, z)
		crown.scale = Vector3(1.2, 1.0, 0.9)
		crown.material_override = foliage_material
		root.add_child(crown)
		_assign_owner(crown)


func _add_oriented_box(node_name: String, box_transform: Transform3D, size_m: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size_m
	node.mesh = mesh
	node.material_override = material
	_generated_root.add_child(node)
	node.global_transform = box_transform
	_assign_owner(node)
	return node


func _add_scene_instance(
	node_name: String,
	scene: PackedScene,
	instance_transform: Transform3D,
	instance_scale: Vector3
) -> Node3D:
	var instance := scene.instantiate()
	if not instance is Node3D:
		instance.queue_free()
		return null

	var node := instance as Node3D
	node.name = node_name
	_generated_root.add_child(node)
	node.global_transform = instance_transform
	node.scale = instance_scale
	_assign_owner_recursive(node)
	return node


func _load_packed_scene(path: String) -> PackedScene:
	if path.is_empty():
		return null
	var resource := load(path)
	if resource is PackedScene:
		return resource as PackedScene
	return null


func _edge_transform(
	track_provider: Node,
	distance_m: float,
	side: float,
	edge_offset_m: float,
	vertical_offset_m: float,
	yaw_offset_degrees: float = 0.0
) -> Transform3D:
	if track_provider != null and track_provider.has_method("road_edge_anchor_transform"):
		return track_provider.call("road_edge_anchor_transform", distance_m, side, edge_offset_m, 0.0, vertical_offset_m, yaw_offset_degrees)
	if track_provider != null and track_provider.has_method("road_edge_transform"):
		return track_provider.call("road_edge_transform", distance_m, side, edge_offset_m, vertical_offset_m, yaw_offset_degrees)
	return Transform3D.IDENTITY


func _road_facing_panel_transform(
	track_provider: Node,
	distance_m: float,
	side: float,
	edge_offset_m: float,
	vertical_offset_m: float
) -> Transform3D:
	if track_provider == null or not track_provider.has_method("sample_at_distance"):
		return _edge_transform(track_provider, distance_m, side, edge_offset_m, vertical_offset_m)

	var sample: Dictionary = track_provider.call("sample_at_distance", distance_m)
	var forward: Vector3 = _safe_vector(sample.get("tangent", Vector3.FORWARD), Vector3.FORWARD).normalized()
	var up: Vector3 = _safe_vector(sample.get("up", Vector3.UP), Vector3.UP).normalized()
	var right: Vector3 = _safe_vector(sample.get("right", Vector3.RIGHT), Vector3.RIGHT).normalized()
	var side_sign: float = -1.0 if side < 0.0 else 1.0
	var inward: Vector3 = -right * side_sign
	var edge: Transform3D = _edge_transform(track_provider, distance_m, side, edge_offset_m, vertical_offset_m)
	return Transform3D(Basis(forward, up, inward).orthonormalized(), edge.origin)


func _safe_vector(value: Variant, fallback: Vector3) -> Vector3:
	if value is Vector3:
		var vector_value: Vector3 = value
		if vector_value.length_squared() > 0.0001:
			return vector_value
	return fallback


func _irregular_rock_mesh(size_m: Vector3, seed_index: int) -> ArrayMesh:
	var base_vertices: Array[Vector3] = [
		Vector3(-0.5, -0.5, -0.5),
		Vector3(0.5, -0.5, -0.5),
		Vector3(0.5, -0.5, 0.5),
		Vector3(-0.5, -0.5, 0.5),
		Vector3(-0.45, 0.5, -0.42),
		Vector3(0.42, 0.5, -0.48),
		Vector3(0.48, 0.5, 0.40),
		Vector3(-0.40, 0.5, 0.46),
		Vector3(0.0, 0.72, 0.0),
	]
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	for index: int in range(base_vertices.size()):
		var vertex: Vector3 = base_vertices[index]
		var jitter := Vector3(
			(_unit_noise(seed_index, index * 3) - 0.5) * 0.22,
			(_unit_noise(seed_index, index * 3 + 1) - 0.5) * 0.16,
			(_unit_noise(seed_index, index * 3 + 2) - 0.5) * 0.22
		)
		var final_vertex: Vector3 = (vertex + jitter) * size_m
		vertices.append(final_vertex)
		normals.append(final_vertex.normalized())
		uvs.append(Vector2(vertex.x + 0.5, vertex.z + 0.5))

	var indices := PackedInt32Array([
		0, 1, 2, 0, 2, 3,
		0, 4, 5, 0, 5, 1,
		1, 5, 6, 1, 6, 2,
		2, 6, 7, 2, 7, 3,
		3, 7, 4, 3, 4, 0,
		4, 8, 5, 5, 8, 6, 6, 8, 7, 7, 8, 4,
	])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _unit_noise(seed_index: int, salt: int) -> float:
	return fposmod(sin(float(seed_index * 127 + salt * 311)) * 43758.5453, 1.0)


func _add_floor_accent_strips() -> void:
	for side: float in [-1.0, 1.0]:
		var strip := MeshInstance3D.new()
		strip.name = "RunoffGlowStrip_%s" % ("L" if side < 0.0 else "R")
		var mesh := BoxMesh.new()
		mesh.size = Vector3(1.2, 0.035, 180.0)
		strip.mesh = mesh
		strip.position = Vector3(side * 28.0, 0.06, 0.0)
		strip.material_override = _emissive_material(Color(0.08, 0.60, 1.0, 1.0), 0.95)
		_generated_root.add_child(strip)
		_assign_owner(strip)


func _add_ocean_plane() -> void:
	var ocean := MeshInstance3D.new()
	ocean.name = "OceanPlane"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(620.0, 340.0)
	ocean.mesh = mesh
	ocean.position = Vector3(0.0, -5.5, -cliff_distance_m)
	ocean.material_override = _material(Color(0.02, 0.16, 0.25, 1.0), 0.22, 0.08)
	_generated_root.add_child(ocean)
	_assign_owner(ocean)


func _add_coastal_roadside_signage() -> void:
	for index: int in range(warning_sign_count):
		var side := -1.0 if index % 2 == 0 else 1.0
		var z := lerpf(-112.0, 112.0, float(index) / maxf(float(warning_sign_count - 1), 1.0))
		var sponsor: Dictionary = SPONSOR_MARKS[(index + 3) % SPONSOR_MARKS.size()]
		if index % 3 == 0:
			_add_sponsor_board(
				"CoastalSponsor_%02d" % index,
				Vector3(side * 39.0, 2.0, z),
				-72.0 if side < 0.0 else 72.0,
				String(sponsor["name"]),
				sponsor["base"],
				sponsor["accent"],
				Vector2(7.0, 2.1)
			)
		else:
			_add_warning_chevrons(index, Vector3(side * 31.0, 1.3, z), -68.0 if side < 0.0 else 68.0, side)


func _add_warning_chevrons(index: int, chevron_position: Vector3, yaw_degrees: float, side: float) -> void:
	var board := MeshInstance3D.new()
	board.name = "CoastalChevronWarning_%02d" % index
	var mesh := BoxMesh.new()
	mesh.size = Vector3(2.6, 1.25, 0.16)
	board.mesh = mesh
	board.position = chevron_position
	board.rotation_degrees.y = yaw_degrees
	board.material_override = _material(Color(0.055, 0.06, 0.06, 1.0), 0.32, 0.2)
	_generated_root.add_child(board)
	_assign_owner(board)

	for chevron_index: int in range(3):
		var stripe := MeshInstance3D.new()
		stripe.name = "ChevronStripe_%02d" % chevron_index
		var stripe_mesh := BoxMesh.new()
		stripe_mesh.size = Vector3(0.18, 0.96, 0.06)
		stripe.mesh = stripe_mesh
		stripe.position = Vector3(-0.72 + float(chevron_index) * 0.52, 0.0, -0.10)
		stripe.rotation_degrees.z = 24.0 * side
		stripe.material_override = _emissive_material(Color(1.0, 0.48, 0.08, 1.0), 0.72)
		board.add_child(stripe)
		_assign_owner(stripe)


func _add_cliffs() -> void:
	for index: int in range(cliff_cluster_count):
		var angle := lerpf(-0.9, 0.9, float(index) / maxf(float(cliff_cluster_count - 1), 1.0))
		for chunk_index: int in range(3):
			var rock := MeshInstance3D.new()
			rock.name = "CoastalCliff_%02d_%02d" % [index, chunk_index]
			var mesh := BoxMesh.new()
			var h := 15.0 + 8.0 * sin(float(index + chunk_index) * 1.4)
			mesh.size = Vector3(
				14.0 + float((index + chunk_index) % 4) * 3.2,
				h,
				15.0 + float(chunk_index) * 3.0
			)
			rock.mesh = mesh
			rock.position = Vector3(
				sin(angle) * cliff_distance_m + float(chunk_index - 1) * 10.5,
				h * 0.5 - 4.0 + float(chunk_index) * 1.6,
				-cos(angle) * cliff_distance_m + float(chunk_index - 1) * 9.0
			)
			rock.rotation_degrees = Vector3(
				2.0 * sin(float(chunk_index + index)),
				rad_to_deg(angle) * 0.35 + float(chunk_index - 1) * 9.0,
				4.5 * sin(float(index + chunk_index))
			)
			rock.material_override = _material(Color(0.22, 0.27, 0.28, 1.0), 0.78, 0.08)
			_generated_root.add_child(rock)
			_assign_owner(rock)


func _add_hillside_city() -> void:
	for index: int in range(22):
		var cluster_x := lerpf(-170.0, 170.0, float(index) / 21.0)
		var hill_y := 8.0 + absf(cluster_x) * 0.045 + sin(float(index) * 0.81) * 3.5
		var z := -235.0 - float(index % 4) * 11.0
		var width := 7.0 + float(index % 4) * 2.2
		var height := 8.0 + float((index + 2) % 5) * 4.5
		var depth := 7.0 + float((index + 1) % 3) * 2.0
		var building := MeshInstance3D.new()
		building.name = "CoastalHillsideBuilding_%02d" % index
		var mesh := BoxMesh.new()
		mesh.size = Vector3(width, height, depth)
		building.mesh = mesh
		building.position = Vector3(cluster_x, hill_y + height * 0.5, z)
		building.rotation_degrees.y = sin(float(index) * 0.52) * 6.0
		building.material_override = _material(Color(0.72, 0.76, 0.76, 1.0), 0.64, 0.04)
		_generated_root.add_child(building)
		_assign_owner(building)
		_add_building_window_rows(building, width, height, depth, index + 40)


func _add_coastal_support_structures() -> void:
	_add_retaining_wall(Vector3(-48.0, 2.2, -82.0), 18.0, 74.0)
	_add_retaining_wall(Vector3(54.0, 2.2, 68.0), -22.0, 68.0)
	for index: int in range(3):
		var tunnel := MeshInstance3D.new()
		tunnel.name = "CoastalConcretePortal_%02d" % index
		var mesh := BoxMesh.new()
		mesh.size = Vector3(18.0, 8.2, 2.4)
		tunnel.mesh = mesh
		tunnel.position = Vector3(-72.0 + float(index) * 72.0, 3.9, -138.0 - float(index % 2) * 12.0)
		tunnel.rotation_degrees.y = -8.0 + float(index) * 6.0
		tunnel.material_override = _material(Color(0.47, 0.49, 0.48, 1.0), 0.72, 0.02)
		_generated_root.add_child(tunnel)
		_assign_owner(tunnel)


func _add_retaining_wall(origin: Vector3, yaw_degrees: float, length_m: float) -> void:
	var panel_count: int = maxi(roundi(length_m / 7.5), 1)
	for index: int in range(panel_count):
		var panel := MeshInstance3D.new()
		panel.name = "CoastalRetainingWall_%02d" % index
		var mesh := BoxMesh.new()
		mesh.size = Vector3(7.2, 4.4, 0.44)
		panel.mesh = mesh
		panel.position = origin + Vector3((float(index) - float(panel_count - 1) * 0.5) * 7.35, 0.0, 0.0).rotated(Vector3.UP, deg_to_rad(yaw_degrees))
		panel.rotation_degrees.y = yaw_degrees
		panel.material_override = _material(Color(0.36, 0.38, 0.38, 1.0), 0.74, 0.02)
		_generated_root.add_child(panel)
		_assign_owner(panel)


func _add_powerline_run() -> void:
	if powerline_pole_count <= 0:
		return

	var previous_top := Vector3.ZERO
	var has_previous := false
	for index: int in range(powerline_pole_count):
		var t := float(index) / maxf(float(powerline_pole_count - 1), 1.0)
		var z := lerpf(-128.0, 128.0, t)
		var x := -54.0 + sin(float(index) * 0.73) * 4.5
		var height := 10.5 + sin(float(index) * 1.31) * 1.4
		var pole_top := Vector3(x, height + 1.8, z)

		var pole := MeshInstance3D.new()
		pole.name = "CoastalPowerPole_%02d" % index
		var pole_mesh := CylinderMesh.new()
		pole_mesh.top_radius = 0.22
		pole_mesh.bottom_radius = 0.32
		pole_mesh.height = height
		pole.mesh = pole_mesh
		pole.position = Vector3(x, height * 0.5, z)
		pole.material_override = _material(Color(0.20, 0.18, 0.15, 1.0), 0.82, 0.0)
		_generated_root.add_child(pole)
		_assign_owner(pole)

		var crossbar := MeshInstance3D.new()
		crossbar.name = "PowerPoleCrossbar_%02d" % index
		var crossbar_mesh := BoxMesh.new()
		crossbar_mesh.size = Vector3(4.2, 0.16, 0.16)
		crossbar.mesh = crossbar_mesh
		crossbar.position = Vector3(x, height + 0.85, z)
		crossbar.material_override = pole.material_override
		_generated_root.add_child(crossbar)
		_assign_owner(crossbar)

		if has_previous:
			_add_wire_segment(previous_top + Vector3(0.0, 0.0, 0.0), pole_top, 0)
			_add_wire_segment(previous_top + Vector3(1.55, -0.12, 0.0), pole_top + Vector3(1.55, -0.12, 0.0), 1)
			_add_wire_segment(previous_top + Vector3(-1.55, -0.12, 0.0), pole_top + Vector3(-1.55, -0.12, 0.0), 2)
		previous_top = pole_top
		has_previous = true


func _add_wire_segment(start: Vector3, end: Vector3, wire_index: int) -> void:
	var delta := end - start
	var length := delta.length()
	if length <= 0.01:
		return

	var wire := MeshInstance3D.new()
	wire.name = "PowerWire_%02d" % wire_index
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.045, 0.045, length)
	wire.mesh = mesh
	wire.transform = Transform3D(_basis_from_forward(delta.normalized()), (start + end) * 0.5)
	wire.material_override = _material(Color(0.035, 0.037, 0.037, 1.0), 0.42, 0.55)
	_generated_root.add_child(wire)
	_assign_owner(wire)


func _add_mist_banks() -> void:
	for index: int in range(mist_bank_count):
		var mist := MeshInstance3D.new()
		mist.name = "CoastalMistBank_%02d" % index
		var mesh := PlaneMesh.new()
		mesh.size = Vector2(58.0 + float(index % 3) * 16.0, 13.0 + float(index % 2) * 4.0)
		mist.mesh = mesh
		mist.position = Vector3(
			lerpf(-110.0, 110.0, float(index) / maxf(float(mist_bank_count - 1), 1.0)),
			8.0 + float(index % 2) * 1.5,
			-135.0 - float(index % 3) * 34.0
		)
		mist.rotation_degrees = Vector3(90.0, -8.0 + float(index) * 3.5, 0.0)
		mist.material_override = _transparent_material(Color(0.62, 0.72, 0.82, 0.16), 0.96)
		_generated_root.add_child(mist)
		_assign_owner(mist)


func _add_sailboats() -> void:
	for index: int in range(sailboat_count):
		var boat := MeshInstance3D.new()
		boat.name = "DistantSailboat_%02d" % index
		var mesh := BoxMesh.new()
		mesh.size = Vector3(3.2, 0.35, 1.1)
		boat.mesh = mesh
		boat.position = Vector3(-95.0 + float(index) * 28.0, -5.0, -210.0 - float(index % 3) * 22.0)
		boat.material_override = _material(Color(0.92, 0.93, 0.88, 1.0), 0.52, 0.2)
		_generated_root.add_child(boat)
		_assign_owner(boat)


func _add_reflector_posts(side_offset_m: float, start_z: float, end_z: float) -> void:
	if reflector_post_count <= 0:
		return

	for index: int in range(reflector_post_count):
		var t := float(index) / maxf(float(reflector_post_count - 1), 1.0)
		var z := lerpf(start_z, end_z, t)
		for side: float in [-1.0, 1.0]:
			var post := MeshInstance3D.new()
			post.name = "ReflectorPost_%s_%02d" % ["L" if side < 0.0 else "R", index]
			var post_mesh := BoxMesh.new()
			post_mesh.size = Vector3(0.16, 1.25, 0.16)
			post.mesh = post_mesh
			post.position = Vector3(side * side_offset_m, 0.62, z)
			post.material_override = _material(Color(0.78, 0.80, 0.76, 1.0), 0.44, 0.0)
			_generated_root.add_child(post)
			_assign_owner(post)

			var reflector := MeshInstance3D.new()
			reflector.name = "ReflectorFace"
			var reflector_mesh := BoxMesh.new()
			reflector_mesh.size = Vector3(0.18, 0.22, 0.035)
			reflector.mesh = reflector_mesh
			reflector.position = Vector3(0.0, 0.38, -0.09)
			reflector.material_override = _emissive_material(Color(1.0, 0.52, 0.12, 1.0), 0.55)
			post.add_child(reflector)
			_assign_owner(reflector)


func _add_sponsor_board(
	node_name: String,
	board_position: Vector3,
	yaw_degrees: float,
	label_text: String,
	base_color: Color,
	accent_color: Color,
	size_m: Vector2
) -> MeshInstance3D:
	var board := MeshInstance3D.new()
	board.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size_m.x, size_m.y, 0.18)
	board.mesh = mesh
	board.position = board_position
	board.rotation_degrees.y = yaw_degrees
	var sponsor_texture := _sponsor_texture_for_label(label_text)
	board.material_override = _textured_material(sponsor_texture, base_color) if sponsor_texture != null else _material(base_color, 0.28, 0.26)
	_generated_root.add_child(board)
	_assign_owner(board)

	var stripe := MeshInstance3D.new()
	stripe.name = "SponsorAccentStripe"
	var stripe_mesh := BoxMesh.new()
	stripe_mesh.size = Vector3(size_m.x * 0.86, 0.16, 0.045)
	stripe.mesh = stripe_mesh
	stripe.position = Vector3(0.0, -size_m.y * 0.28, -0.115)
	stripe.material_override = _emissive_material(accent_color, 0.85)
	board.add_child(stripe)
	_assign_owner(stripe)

	if sponsor_texture == null:
		_add_sign_label(board, label_text, Vector3(0.0, 0.08, -0.12), Color(0.94, 0.96, 0.94, 1.0), 0.018)
	return board


func _sponsor_texture_for_label(label_text: String) -> Texture2D:
	if not use_generated_sponsor_textures or sponsor_texture_paths.is_empty():
		return null

	var normalized_label := label_text.to_lower().replace(" ", "_")
	for path: String in sponsor_texture_paths:
		if path.to_lower().contains(normalized_label):
			var direct_texture := load(path)
			if direct_texture is Texture2D:
				return direct_texture

	var fallback_index: int = _stable_index_from_text(label_text) % sponsor_texture_paths.size()
	var texture := load(sponsor_texture_paths[fallback_index])
	if texture is Texture2D:
		return texture
	return null


func _stable_index_from_text(text: String) -> int:
	var total := 0
	for index: int in range(text.length()):
		total += text.unicode_at(index) * (index + 1)
	return absi(total)


func _add_sign_label(parent: Node3D, text: String, local_position: Vector3, color: Color, pixel_size: float) -> Label3D:
	var label := Label3D.new()
	label.name = "SignText"
	label.text = text
	label.pixel_size = pixel_size
	label.font_size = 72
	label.outline_size = 8
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.72)
	label.modulate = color
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = local_position
	parent.add_child(label)
	_assign_owner(label)
	return label


func _add_rooftop_light(light_position: Vector3) -> void:
	var light := OmniLight3D.new()
	light.name = "RooftopBeacon"
	light.position = light_position
	light.light_energy = 0.55
	light.omni_range = 18.0
	light.light_color = Color(1.0, 0.18, 0.10, 1.0)
	_generated_root.add_child(light)
	_assign_owner(light)


func _clear_previous() -> void:
	var existing := get_node_or_null(root_name)
	if existing != null:
		remove_child(existing)
		existing.free()


func _material(color: Color, roughness: float = 0.55, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = clampf(roughness, 0.0, 1.0)
	material.metallic = clampf(metallic, 0.0, 1.0)
	return material


func _textured_material(texture: Texture2D, fallback_color: Color) -> StandardMaterial3D:
	var material := _material(fallback_color, 0.36, 0.08)
	material.albedo_color = Color.WHITE
	material.albedo_texture = texture
	return material


func _emissive_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := _material(color, 0.32, 0.0)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


func _transparent_material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := _material(color, roughness, 0.0)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return material


func _basis_from_forward(forward: Vector3) -> Basis:
	var safe_forward := forward.normalized()
	if safe_forward.length_squared() <= 0.0001:
		safe_forward = Vector3.FORWARD
	var right := Vector3.UP.cross(safe_forward).normalized()
	if right.length_squared() <= 0.0001:
		right = Vector3.RIGHT
	var up := safe_forward.cross(right).normalized()
	return Basis(right, up, safe_forward).orthonormalized()


func _assign_owner(node: Node) -> void:
	if Engine.is_editor_hint() and get_tree() != null and owner != null:
		node.owner = owner


func _assign_owner_recursive(node: Node) -> void:
	_assign_owner(node)
	for child: Node in node.get_children():
		_assign_owner_recursive(child)
