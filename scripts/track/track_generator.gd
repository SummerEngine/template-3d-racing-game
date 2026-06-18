@tool
class_name TrackGenerator
extends Node3D

const TrackPathScript := preload("res://scripts/track/track_path.gd")
const TrackQueryScript := preload("res://scripts/track/track_query.gd")
const SceneryProps := preload("res://scripts/procedural/procedural_scenery_prop_factory.gd")

const DEFAULT_PROFILE_PATH: String = "res://resources/tracks/showcase_circuit.tres"
const GENERATED_ROOT_NAME: String = "GeneratedTrack"
const ROAD_Y_OFFSET_M: float = 0.0
const MARKING_Y_OFFSET_M: float = 0.035
const CENTER_DASH_LENGTH_M: float = 6.0
const CENTER_DASH_GAP_M: float = 9.0
const CENTER_DASH_WIDTH_M: float = 0.32
const CENTER_DASH_START_OFFSET_M: float = 24.0
const START_LINE_LENGTH_M: float = 1.4
const TERRAIN_MARGIN_M: float = 360.0

@export var track_profile: Resource = null
@export_range(96, 1024, 1) var samples: int = 192
@export var track_y: float = 0.03
@export var generate_on_ready: bool = true
@export var generate_road: bool = true
@export var generate_markings: bool = true
@export var generate_guardrails: bool = true
@export var generate_scenery: bool = true
@export var generate_collision: bool = true
@export var generate_spawn_marker: bool = true
@export_range(1, 16, 1) var spawn_marker_count: int = 4
@export var scenery_seed: int = 260616
@export_range(0.0, 80.0, 0.5) var minimum_scenery_road_edge_clearance_m: float = 24.0
@export_range(0.0, 200.0, 1.0) var guardrail_seam_gap_m: float = 80.0

var _profile: Resource = null
var _track_path: RefCounted = null
var _track_query: RefCounted = null
var _centerline: PackedVector3Array = PackedVector3Array()
var _track_length_m: float = 0.0
var _road_width_m: float = 14.0

var _generated_root: Node3D = null
var _terrain_container: Node3D = null
var _road_container: Node3D = null
var _markings_container: Node3D = null
var _guardrails_container: Node3D = null
var _collision_container: Node3D = null
var _scenery_container: Node3D = null
var _helpers_container: Node3D = null


func _ready() -> void:
	if generate_on_ready:
		call_deferred("regenerate_track")


func regenerate_track() -> void:
	_profile = _resolve_profile()
	if _profile == null:
		push_error("TrackGenerator could not load a TrackProfile.")
		return

	_clear_generated_track()
	_create_containers()
	_build_track_query()

	if _centerline.size() < 2 or _track_length_m <= 0.0:
		push_error("TrackGenerator could not build a usable TrackPath.")
		return

	var bounds: Rect2 = _bounds_xz(_centerline)
	_create_terrain(bounds)

	if generate_collision:
		_create_ground_collision(bounds)
	if generate_road:
		_create_road()
	if generate_markings:
		_create_center_dashes()
		_create_start_line()
	if generate_guardrails and _guardrails_enabled():
		_create_guardrails()
	if generate_scenery:
		_create_scenery()
	if generate_spawn_marker:
		_create_spawn_markers()

	set_meta("track_profile", _profile)
	set_meta("track_query", _track_query)
	set_meta("track_length_m", _track_length_m)
	set_meta("road_width_m", _road_width_m)
	set_meta("spawn_transform", get_spawn_transform(0))


func get_track_query() -> RefCounted:
	return _track_query


func get_track_length_m() -> float:
	if _track_query != null:
		return float(_track_query.call("get_track_length_m"))
	return _track_length_m


func get_road_width_m() -> float:
	if _track_query != null:
		return float(_track_query.call("get_road_width_m"))
	return _road_width_m


func sample_at_distance(distance: float) -> Dictionary:
	if _track_query == null:
		return {}
	return _sample_to_global(_track_query.call("sample_at_distance", distance))


func lane_transform(distance: float, lane_index: int) -> Transform3D:
	if _track_query == null:
		return Transform3D.IDENTITY
	var local_transform: Transform3D = _track_query.call("lane_transform", distance, lane_index)
	return _generator_transform() * local_transform


func environment_weights_at_distance(distance: float) -> Dictionary:
	if _track_query == null:
		return {}
	return _track_query.call("environment_weights_at_distance", distance)


func closest_distance_for_position(world_position: Vector3) -> float:
	if _track_query == null:
		return 0.0
	var local_position: Vector3 = _generator_transform().affine_inverse() * world_position
	return float(_track_query.call("closest_distance_for_position", local_position))


func get_spawn_transform(grid_index: int) -> Transform3D:
	if _track_query == null:
		return Transform3D.IDENTITY
	var local_transform: Transform3D = _track_query.call("get_spawn_transform", grid_index)
	return _generator_transform() * local_transform


func place_node_at_spawn(node: Node3D, grid_index: int) -> void:
	if node == null:
		return

	node.global_transform = get_spawn_transform(grid_index)
	if node is CharacterBody3D:
		var body := node as CharacterBody3D
		body.velocity = Vector3.ZERO


func _resolve_profile() -> Resource:
	if track_profile != null:
		return track_profile

	var loaded_profile := load(DEFAULT_PROFILE_PATH) as Resource
	if loaded_profile != null:
		track_profile = loaded_profile
	return track_profile


func _build_track_query() -> void:
	var target_length_m: float = _resource_float(_profile, "target_length_m", 1800.0)
	_road_width_m = _resource_float(_profile, "road_width_m", 14.0)

	var points: PackedVector3Array = TrackPathScript.build_arcade_loop_points(target_length_m, samples, track_y)
	_track_path = TrackPathScript.from_points(points, true)
	_track_query = TrackQueryScript.new(_profile, _track_path)
	_centerline = _track_path.get("centerline")
	_track_length_m = float(_track_path.call("get_length_m"))


func _clear_generated_track() -> void:
	var old_node: Node = get_node_or_null(GENERATED_ROOT_NAME)
	if old_node != null:
		remove_child(old_node)
		old_node.free()


func _create_containers() -> void:
	_generated_root = _add_container(self, GENERATED_ROOT_NAME)
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
	if Engine.is_editor_hint() and owner != null:
		container.owner = owner
	return container


func _create_terrain(bounds: Rect2) -> void:
	var terrain_size: float = maxf(bounds.size.x, bounds.size.y) + TERRAIN_MARGIN_M
	var terrain_mesh := PlaneMesh.new()
	terrain_mesh.size = Vector2(terrain_size, terrain_size)

	var terrain := MeshInstance3D.new()
	terrain.name = "TerrainBase"
	terrain.mesh = terrain_mesh
	terrain.position = Vector3(bounds.get_center().x, track_y - 0.04, bounds.get_center().y)
	terrain.material_override = _material(_base_terrain_color(), 0.92)
	_terrain_container.add_child(terrain)


func _create_ground_collision(bounds: Rect2) -> void:
	var ground_size: float = maxf(bounds.size.x, bounds.size.y) + TERRAIN_MARGIN_M
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


func _create_road() -> void:
	var road := MeshInstance3D.new()
	road.name = "Road_%.0fm_%.0fmWide" % [_track_length_m, _road_width_m]
	road.mesh = _strip_mesh(_centerline, 0.0, _road_width_m, track_y + ROAD_Y_OFFSET_M)
	road.material_override = _material(_resource_color(_profile, "road_color", Color(0.015, 0.016, 0.018, 1.0)), 0.82)
	_road_container.add_child(road)


func _create_center_dashes() -> void:
	var dashes := MeshInstance3D.new()
	dashes.name = "WhiteCenterDashes"
	dashes.mesh = _center_dash_mesh(track_y + MARKING_Y_OFFSET_M)
	dashes.material_override = _material(Color(0.96, 0.96, 0.92, 1.0), 0.38)
	_markings_container.add_child(dashes)


func _create_start_line() -> void:
	var sample: Dictionary = _track_path.call("sample_at_distance", 0.0)
	var center: Vector3 = sample["position"] + sample["tangent"] * 3.0
	var tangent: Vector3 = sample["tangent"]
	var normal: Vector3 = sample["normal"]
	center.y = track_y + MARKING_Y_OFFSET_M + 0.01

	var line := MeshInstance3D.new()
	line.name = "StartFinishLine"
	line.mesh = _quad_mesh(center, normal, tangent, maxf(_road_width_m - 0.6, 1.0), START_LINE_LENGTH_M, center.y)
	line.material_override = _material(Color(0.98, 0.98, 0.94, 1.0), 0.3)
	_markings_container.add_child(line)


func _create_guardrails() -> void:
	var rail_material: StandardMaterial3D = _material(_guardrail_color(), 0.64)
	rail_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var post_material: StandardMaterial3D = _material(_guardrail_color().lightened(0.22), 0.58)

	for side: float in [-1.0, 1.0]:
		var side_name: String = "Left" if side < 0.0 else "Right"

		var rail := MeshInstance3D.new()
		rail.name = "Guardrail%sBeam" % side_name
		rail.mesh = _guardrail_beam_mesh(side)
		rail.material_override = rail_material
		_guardrails_container.add_child(rail)

		var posts := MeshInstance3D.new()
		posts.name = "Guardrail%sPosts" % side_name
		posts.mesh = _guardrail_post_mesh(side)
		posts.material_override = post_material
		_guardrails_container.add_child(posts)

	if generate_collision:
		_create_guardrail_collision()


func _create_guardrail_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "GuardrailCollision"
	body.collision_layer = 1
	body.collision_mask = 1
	_collision_container.add_child(body)

	var center_offset_m: float = _guardrail_center_offset_m()
	var thickness_m: float = _guardrail_thickness_m()
	var height_m: float = _guardrail_height_m()
	for side: float in [-1.0, 1.0]:
		for i: int in range(_centerline.size()):
			var next_index: int = (i + 1) % _centerline.size()
			var midpoint_distance_m: float = _guardrail_segment_midpoint_distance(i, next_index)
			if not _guardrail_enabled_at_distance(midpoint_distance_m):
				continue

			var start: Vector3 = _offset_point(i, side * center_offset_m)
			var end: Vector3 = _offset_point(next_index, side * center_offset_m)
			var segment: Vector3 = end - start
			segment.y = 0.0
			var length: float = segment.length()
			if length <= 0.01:
				continue

			var tangent: Vector3 = segment / length
			var side_normal: Vector3 = _normal_from_tangent(tangent) * side
			var segment_basis := Basis(side_normal, Vector3.UP, tangent).orthonormalized()
			var shape := BoxShape3D.new()
			shape.size = Vector3(thickness_m + 0.28, height_m + 0.45, length + 0.75)

			var collision := CollisionShape3D.new()
			collision.name = "GuardrailCollision_%s_%03d" % ["L" if side < 0.0 else "R", i]
			collision.shape = shape
			collision.transform = Transform3D(
				segment_basis,
				(start + end) * 0.5 + Vector3.UP * ((height_m + 0.45) * 0.5)
			)
			body.add_child(collision)


func _create_spawn_markers() -> void:
	var marker_root: Node3D = _add_container(_helpers_container, "SpawnMarkers")
	var count: int = maxi(spawn_marker_count, 1)
	for i: int in range(count):
		var marker := Marker3D.new()
		marker.name = "Spawn_%02d" % i
		marker.set_meta("grid_index", i)
		marker.transform = _track_query.call("get_spawn_transform", i)
		marker_root.add_child(marker)


func _create_scenery() -> void:
	var sections: Array = _profile.call("get_ordered_environment_sections")
	for section_index: int in range(sections.size()):
		var section := sections[section_index] as Resource
		if section == null:
			continue

		var environment := section.get("environment") as Resource
		if environment == null:
			continue

		_create_section_ground_patches(section, environment, section_index)

		var rules: Array = environment.get("prop_rules")
		for rule_index: int in range(rules.size()):
			var rule := rules[rule_index] as Resource
			if rule == null:
				continue
			_place_rule_for_section(section, environment, rule, section_index, rule_index)

	_create_transition_scenery()


func _create_section_ground_patches(section: Resource, environment: Resource, section_index: int) -> void:
	var band: Vector2 = _section_distance_band(section)
	var spacing_m: float = 150.0
	var distance: float = band.x + spacing_m * 0.35
	var patch_index: int = 0

	while distance < band.y:
		for side: float in [-1.0, 1.0]:
			var sample: Dictionary = _track_path.call("sample_at_distance", distance)
			var tangent: Vector3 = sample["tangent"]
			var side_normal: Vector3 = sample["normal"] * side
			var center: Vector3 = sample["position"] + side_normal * (_road_width_m * 0.5 + 42.0)
			center.y = track_y - 0.025

			var patch := MeshInstance3D.new()
			patch.name = "%sGroundPatch_%03d_%s" % [_environment_id(environment), patch_index, "L" if side < 0.0 else "R"]
			patch.mesh = _box_mesh(Vector3(52.0, 0.035, spacing_m * 0.78))
			patch.material_override = _material(_environment_terrain_color(environment, section_index + patch_index), 0.92)
			patch.transform = Transform3D(Basis(side_normal, Vector3.UP, tangent).orthonormalized(), center)
			_scenery_container.add_child(patch)

		distance += spacing_m
		patch_index += 1


func _place_rule_for_section(
	section: Resource,
	environment: Resource,
	rule: Resource,
	section_index: int,
	rule_index: int
) -> void:
	var prop_id: StringName = _as_string_name(rule.get("prop_id"))
	var env_id: StringName = _environment_id(environment)
	var band: Vector2 = _section_distance_band(section)
	var placement_band: Vector2 = _coverage_distance_band(environment, prop_id, band, section_index + rule_index)
	var min_spacing_m: float = maxf(_resource_float(rule, "min_spacing_m", 80.0), 1.0)
	var max_spacing_m: float = maxf(_resource_float(rule, "max_spacing_m", min_spacing_m), min_spacing_m)
	var base_spacing_m: float = (min_spacing_m + max_spacing_m) * 0.5
	var side_values: PackedFloat32Array = _rule_side_values(rule)
	if env_id == &"highway_crops" and prop_id == &"billboard":
		side_values = PackedFloat32Array([-1.0, 1.0])
		placement_band = band

	var distance: float = placement_band.x + base_spacing_m * (0.25 + _noise01(section_index, rule_index, 3) * 0.5)
	var placed_count: int = 0
	while distance < placement_band.y:
		var step_seed: int = scenery_seed + section_index * 1009 + rule_index * 173 + placed_count * 41
		var sides_for_step: PackedFloat32Array = side_values
		if int(rule.get("sides")) == 3:
			sides_for_step = PackedFloat32Array([-1.0 if placed_count % 2 == 0 else 1.0])

		for side: float in sides_for_step:
			_place_rule_prop(rule, environment, distance, side, step_seed + int(side * 11.0), section_index, placed_count)

		var jitter: float = lerpf(min_spacing_m, max_spacing_m, _noise01(step_seed, placed_count, rule_index))
		distance += maxf(jitter, 1.0)
		placed_count += 1

	if placed_count == 0 and placement_band.y > placement_band.x:
		for side: float in side_values:
			_place_rule_prop(rule, environment, (placement_band.x + placement_band.y) * 0.5, side, scenery_seed + section_index * 59 + rule_index, section_index, 0)


func _place_rule_prop(
	rule: Resource,
	environment: Resource,
	distance: float,
	side: float,
	prop_seed: int,
	section_index: int,
	step_index: int
) -> void:
	var prop_id: StringName = _as_string_name(rule.get("prop_id"))
	var sample: Dictionary = _track_path.call("sample_at_distance", distance)
	var side_normal: Vector3 = sample["normal"] * side
	var offset_jitter_m: float = _resource_float(rule, "offset_jitter_m", 0.0)
	var jitter_m: float = (lerpf(-offset_jitter_m, offset_jitter_m, _noise01(prop_seed, section_index, step_index)))
	var road_edge_offset_m: float = maxf(_resource_float(rule, "road_edge_offset_m", 24.0), minimum_scenery_road_edge_clearance_m)
	var clearance_m: float = maxf(road_edge_offset_m + jitter_m, minimum_scenery_road_edge_clearance_m)
	var lateral_offset_m: float = _road_width_m * 0.5 + clearance_m
	var prop_position: Vector3 = sample["position"] + side_normal * lateral_offset_m
	prop_position.y = track_y

	var prop: Node3D = _create_prop_for_rule(prop_id, prop_seed, rule)
	prop.name = "%s_%03d_%s" % [String(prop_id).capitalize().replace(" ", ""), step_index, "L" if side < 0.0 else "R"]
	prop.set_meta("environment_id", _environment_id(environment))
	prop.set_meta("prop_id", prop_id)
	prop.set_meta("distance_m", fposmod(distance, _track_length_m))
	prop.set_meta("road_edge_offset_m", road_edge_offset_m)
	prop.set_meta("coverage_range", environment.call("get_coverage_range", prop_id, Vector2(0.0, 1.0)))

	var face_road: Vector3 = -side_normal
	var yaw_jitter: float = deg_to_rad(float((prop_seed % 9) - 4) * 2.0)
	prop.transform = Transform3D(_basis_from_forward(face_road).rotated(Vector3.UP, yaw_jitter), prop_position)
	_scenery_container.add_child(prop)


func _create_transition_scenery() -> void:
	var transitions: Array = _profile.call("get_effective_transitions")
	for transition_index: int in range(transitions.size()):
		var transition := transitions[transition_index] as Resource
		if transition == null:
			continue

		var start_ratio: float = _resource_float(transition, "start_distance_ratio", 0.0)
		var end_ratio: float = _resource_float(transition, "end_distance_ratio", 0.0)
		var start_m: float = start_ratio * _track_length_m
		var end_m: float = end_ratio * _track_length_m
		if end_m <= start_m:
			end_m += _track_length_m

		var midpoint_m: float = (start_m + end_m) * 0.5
		var from_environment := transition.get("from_environment") as Resource
		var to_environment := transition.get("to_environment") as Resource
		var to_environment_id: StringName = _environment_id(to_environment)
		var prop_id: StringName = &"utility_props" if to_environment_id == &"industrial" else &"billboard"

		for side: float in [-1.0, 1.0]:
			var sample: Dictionary = _track_path.call("sample_at_distance", midpoint_m)
			var side_normal: Vector3 = sample["normal"] * side
			var prop_position: Vector3 = sample["position"] + side_normal * (_road_width_m * 0.5 + 22.0)
			prop_position.y = track_y

			var prop: Node3D = _create_prop_for_rule(prop_id, scenery_seed + transition_index * 431 + int(side * 17.0), null)
			prop.name = "Transition_%s_%02d_%s" % [String(prop_id), transition_index, "L" if side < 0.0 else "R"]
			prop.set_meta("transition_from", _environment_id(from_environment))
			prop.set_meta("transition_to", to_environment_id)
			prop.set_meta("transition_prop_rules", transition.get("prop_crossfade_rules"))
			prop.transform = Transform3D(_basis_from_forward(-side_normal), prop_position)
			_scenery_container.add_child(prop)


func _create_prop_for_rule(prop_id: StringName, prop_seed: int, rule: Resource) -> Node3D:
	var scale_value: float = _rule_scale(rule, prop_seed)
	match prop_id:
		&"billboard":
			return SceneryProps.create_prop("billboard", prop_seed, {
				"panel_size": Vector2(10.0, 4.0) * maxf(scale_value, 0.8),
				"clearance": 5.2,
			})
		&"crop_cluster":
			return SceneryProps.create_prop("crop", prop_seed, {
				"size": Vector2(36.0, 24.0) * maxf(scale_value, 0.8),
				"row_count": 7 + int(abs(prop_seed) % 3),
			})
		&"farmhouse_fenced_area":
			return _create_farmhouse_fenced_area(prop_seed, scale_value)
		&"factory":
			return SceneryProps.create_prop("factory", prop_seed, {
				"size": Vector3(7.0, 2.0, 5.0) * maxf(scale_value, 1.0),
			})
		&"container":
			return SceneryProps.create_prop("container", prop_seed, {
				"size": Vector3(13.0, 3.0, 3.2) * clampf(scale_value, 0.8, 1.35),
			})
		&"utility_props":
			return _create_utility_prop(prop_seed)
		_:
			return _create_generic_placeholder(prop_id, prop_seed, scale_value)


func _create_farmhouse_fenced_area(prop_seed: int, scale_value: float) -> Node3D:
	var root := Node3D.new()
	root.name = "FarmhouseFencedArea"
	root.set_meta("scenery_kind", "farmhouse_fenced_area")
	root.set_meta("scenery_seed", prop_seed)

	var house_size := Vector3(5.0, 2.3, 4.0) * maxf(scale_value, 1.0)
	var house: Node3D = SceneryProps.create_prop("house", prop_seed, {"size": house_size})
	house.position = Vector3.ZERO
	root.add_child(house)

	var fence_width: float = house_size.x + 10.0
	var fence_depth: float = house_size.z + 9.0
	var fence_material := _material(Color(0.88, 0.78, 0.56, 1.0), 0.86)
	for x_sign: float in [-1.0, 1.0]:
		var rail := _box_node("FenceSide", Vector3(0.22, 0.5, fence_depth), fence_material)
		rail.position = Vector3(x_sign * fence_width * 0.5, 0.55, 0.0)
		root.add_child(rail)
	for z_sign: float in [-1.0, 1.0]:
		var rail := _box_node("FenceBackFront", Vector3(fence_width, 0.5, 0.22), fence_material)
		rail.position = Vector3(0.0, 0.55, z_sign * fence_depth * 0.5)
		root.add_child(rail)

	var animal_material := _material(Color(0.94, 0.92, 0.86, 1.0), 0.78)
	for i: int in range(3):
		var animal := _box_node("AnimalPlaceholder%02d" % i, Vector3(1.2, 0.7, 0.55), animal_material)
		animal.position = Vector3(-fence_width * 0.25 + float(i) * 1.7, 0.35, fence_depth * 0.22)
		root.add_child(animal)

	return root


func _create_utility_prop(prop_seed: int) -> Node3D:
	var root := Node3D.new()
	root.name = "UtilityProps"
	root.set_meta("scenery_kind", "utility_props")
	root.set_meta("scenery_seed", prop_seed)

	var pole_material := _material(Color(0.42, 0.34, 0.24, 1.0), 0.8)
	var sign_material := _material(Color(0.82, 0.74, 0.42, 1.0), 0.62)
	var metal_material := _material(Color(0.46, 0.47, 0.46, 1.0), 0.52)

	var pole := _box_node("UtilityPole", Vector3(0.42, 7.5, 0.42), pole_material)
	pole.position = Vector3(0.0, 3.75, 0.0)
	root.add_child(pole)

	var crossbar := _box_node("Crossbar", Vector3(4.8, 0.28, 0.28), metal_material)
	crossbar.position = Vector3(0.0, 6.55, 0.0)
	root.add_child(crossbar)

	var sign_node := _box_node("IndustrialSign", Vector3(3.8, 1.65, 0.24), sign_material)
	sign_node.position = Vector3(0.0, 2.15, -0.38)
	root.add_child(sign_node)
	return root


func _create_generic_placeholder(prop_id: StringName, prop_seed: int, scale_value: float) -> Node3D:
	var root := Node3D.new()
	root.name = "SceneryPlaceholder"
	root.set_meta("scenery_kind", prop_id)
	root.set_meta("scenery_seed", prop_seed)
	var box_size: Vector3 = Vector3(4.0, 2.4, 4.0) * maxf(scale_value, 1.0)
	var box := _box_node("PlaceholderBox", box_size, _material(Color(0.64, 0.66, 0.58, 1.0), 0.84))
	box.position.y = box_size.y * 0.5
	root.add_child(box)
	return root


func _section_distance_band(section: Resource) -> Vector2:
	var start_m: float = _resource_float(section, "start_distance_ratio", 0.0) * _track_length_m
	var end_m: float = _resource_float(section, "end_distance_ratio", 1.0) * _track_length_m
	if end_m <= start_m:
		end_m += _track_length_m
	return Vector2(start_m, end_m)


func _coverage_distance_band(
	environment: Resource,
	prop_id: StringName,
	section_band: Vector2,
	salt: int
) -> Vector2:
	var coverage_range: Vector2 = environment.call("get_coverage_range", prop_id, Vector2(0.0, 1.0))
	var coverage_amount: float = clampf((coverage_range.x + coverage_range.y) * 0.5, 0.0, 1.0)
	var section_length_m: float = maxf(section_band.y - section_band.x, 0.0)
	var coverage_length_m: float = maxf(section_length_m * coverage_amount, 0.0)
	if coverage_amount >= 0.95 or coverage_length_m >= section_length_m:
		return section_band

	var free_length_m: float = maxf(section_length_m - coverage_length_m, 0.0)
	var start_bias: float = _noise01(salt, String(prop_id).length(), scenery_seed)
	var start_m: float = section_band.x + free_length_m * start_bias
	return Vector2(start_m, start_m + coverage_length_m)


func _rule_side_values(rule: Resource) -> PackedFloat32Array:
	if rule != null and rule.has_method("side_values"):
		return rule.call("side_values")
	return PackedFloat32Array([-1.0, 1.0])


func _rule_scale(rule: Resource, prop_seed: int) -> float:
	if rule == null:
		return 1.0
	var value = rule.get("scale_multiplier_range")
	if value is Vector2:
		var scale_range: Vector2 = value
		return lerpf(scale_range.x, scale_range.y, _noise01(prop_seed, int(scale_range.x * 10.0), int(scale_range.y * 10.0)))
	return 1.0


func _guardrails_enabled() -> bool:
	var settings := _profile.get("guardrail_settings") as Resource
	if settings == null:
		return true
	return _resource_bool(settings, "enabled", true)


func _guardrail_center_offset_m() -> float:
	var settings := _profile.get("guardrail_settings") as Resource
	if settings != null and settings.has_method("center_offset_from_centerline_m"):
		return float(settings.call("center_offset_from_centerline_m", _road_width_m))
	return _road_width_m * 0.5 + 0.55


func _guardrail_thickness_m() -> float:
	var settings := _profile.get("guardrail_settings") as Resource
	return _resource_float(settings, "thickness_m", 0.55)


func _guardrail_height_m() -> float:
	var settings := _profile.get("guardrail_settings") as Resource
	return _resource_float(settings, "height_m", 1.15)


func _guardrail_post_spacing_m() -> float:
	var settings := _profile.get("guardrail_settings") as Resource
	return maxf(_resource_float(settings, "post_spacing_m", 24.0), 1.0)


func _guardrail_post_size_m() -> float:
	var settings := _profile.get("guardrail_settings") as Resource
	return _resource_float(settings, "post_size_m", 0.42)


func _guardrail_color() -> Color:
	var settings := _profile.get("guardrail_settings") as Resource
	return _resource_color(settings, "color", Color(0.58, 0.6, 0.57, 1.0))


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


func _center_dash_mesh(y: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var stride: float = CENTER_DASH_LENGTH_M + CENTER_DASH_GAP_M
	var dash_count: int = floori(maxf(_track_length_m - CENTER_DASH_START_OFFSET_M, 0.0) / stride)

	for i: int in range(dash_count):
		var center_distance: float = CENTER_DASH_START_OFFSET_M + float(i) * stride + CENTER_DASH_LENGTH_M * 0.5
		var sample: Dictionary = _track_path.call("sample_at_distance", center_distance)
		var center: Vector3 = sample["position"]
		var tangent: Vector3 = sample["tangent"]
		var normal: Vector3 = sample["normal"]
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


func _guardrail_beam_mesh(side: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	for i: int in range(_centerline.size()):
		var next: int = (i + 1) % _centerline.size()
		var midpoint_distance_m: float = _guardrail_segment_midpoint_distance(i, next)
		if not _guardrail_enabled_at_distance(midpoint_distance_m):
			continue

		var current_sample: Dictionary = _guardrail_cross_section(i, side)
		var next_sample: Dictionary = _guardrail_cross_section(next, side)

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


func _guardrail_cross_section(index: int, side: float) -> Dictionary:
	var tangent: Vector3 = _tangent_at(_centerline, index)
	var side_normal: Vector3 = _normal_from_tangent(tangent) * side
	var center: Vector3 = _centerline[index] + side_normal * _guardrail_center_offset_m()
	var inner: Vector3 = center - side_normal * (_guardrail_thickness_m() * 0.5)
	var outer: Vector3 = center + side_normal * (_guardrail_thickness_m() * 0.5)
	inner.y = track_y
	outer.y = track_y

	return {
		"inner_bottom": inner,
		"outer_bottom": outer,
		"inner_top": inner + Vector3.UP * _guardrail_height_m(),
		"outer_top": outer + Vector3.UP * _guardrail_height_m(),
		"side_normal": side_normal,
	}


func _guardrail_post_mesh(side: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var post_count: int = floori(_track_length_m / _guardrail_post_spacing_m())

	for i: int in range(post_count):
		var distance_m: float = float(i) * _guardrail_post_spacing_m()
		if not _guardrail_enabled_at_distance(distance_m):
			continue

		var sample: Dictionary = _track_path.call("sample_at_distance", distance_m)
		var sample_position: Vector3 = sample["position"]
		var tangent: Vector3 = sample["tangent"]
		var side_normal: Vector3 = sample["normal"] * side
		var center: Vector3 = sample_position + side_normal * _guardrail_center_offset_m()
		center.y = track_y + _guardrail_height_m() * 0.5
		var post_basis := Basis(side_normal, Vector3.UP, tangent).orthonormalized()
		_append_box(
			vertices,
			normals,
			uvs,
			indices,
			Transform3D(post_basis, center),
			Vector3(_guardrail_post_size_m(), _guardrail_height_m(), _guardrail_post_size_m())
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


func _offset_point(index: int, offset: float) -> Vector3:
	var tangent: Vector3 = _tangent_at(_centerline, index)
	var normal: Vector3 = _normal_from_tangent(tangent)
	var point: Vector3 = _centerline[index] + normal * offset
	point.y = track_y
	return point


func _tangent_at(points: PackedVector3Array, index: int) -> Vector3:
	if points.size() < 2:
		return Vector3(0.0, 0.0, 1.0)
	var safe_index: int = clampi(index, 0, points.size() - 1)
	var prev: Vector3 = points[(safe_index - 1 + points.size()) % points.size()]
	var next: Vector3 = points[(safe_index + 1) % points.size()]
	var tangent: Vector3 = next - prev
	tangent.y = 0.0
	if tangent.length_squared() <= 0.0001:
		return Vector3(0.0, 0.0, 1.0)
	return tangent.normalized()


func _guardrail_segment_midpoint_distance(index: int, next_index: int) -> float:
	var start_distance_m: float = _distance_for_centerline_index(index)
	var end_distance_m: float = _distance_for_centerline_index(next_index)
	if next_index == 0 and index >= _centerline.size() - 1:
		end_distance_m = _track_length_m
	return (start_distance_m + end_distance_m) * 0.5


func _distance_for_centerline_index(index: int) -> float:
	if _centerline.is_empty() or _track_length_m <= 0.0:
		return 0.0
	return _track_length_m * float(clampi(index, 0, _centerline.size() - 1)) / float(_centerline.size())


func _guardrail_enabled_at_distance(distance_m: float) -> bool:
	var seam_gap_m: float = maxf(guardrail_seam_gap_m, 0.0)
	if seam_gap_m <= 0.0 or _track_length_m <= 0.0:
		return true

	seam_gap_m = minf(seam_gap_m, _track_length_m * 0.45)
	var resolved_distance_m: float = fposmod(distance_m, _track_length_m)
	return resolved_distance_m > seam_gap_m and resolved_distance_m < _track_length_m - seam_gap_m


func _normal_from_tangent(tangent: Vector3) -> Vector3:
	var flat_tangent := Vector3(tangent.x, 0.0, tangent.z)
	if flat_tangent.length_squared() <= 0.0001:
		return Vector3.RIGHT
	return Vector3(flat_tangent.z, 0.0, -flat_tangent.x).normalized()


func _basis_from_forward(forward: Vector3) -> Basis:
	var flat_forward := Vector3(forward.x, 0.0, forward.z).normalized()
	if flat_forward.length_squared() <= 0.0001:
		flat_forward = Vector3(0.0, 0.0, 1.0)

	var back: Vector3 = -flat_forward
	var right: Vector3 = Vector3.UP.cross(back).normalized()
	return Basis(right, Vector3.UP, back).orthonormalized()


func _sample_to_global(sample: Dictionary) -> Dictionary:
	var result: Dictionary = sample.duplicate()
	var generator_xform: Transform3D = _generator_transform()
	if result.has("position"):
		result["position"] = generator_xform * (result["position"] as Vector3)
	if result.has("tangent"):
		result["tangent"] = (generator_xform.basis * (result["tangent"] as Vector3)).normalized()
	if result.has("normal"):
		result["normal"] = (generator_xform.basis * (result["normal"] as Vector3)).normalized()
	return result


func _generator_transform() -> Transform3D:
	if is_inside_tree():
		return global_transform
	return transform


func _bounds_xz(points: PackedVector3Array) -> Rect2:
	if points.is_empty():
		return Rect2()

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


func _base_terrain_color() -> Color:
	var sections: Array = _profile.call("get_ordered_environment_sections")
	if sections.is_empty():
		return Color(0.08, 0.32, 0.12, 1.0)
	var section := sections[0] as Resource
	if section == null:
		return Color(0.08, 0.32, 0.12, 1.0)
	var environment := section.get("environment") as Resource
	return _environment_terrain_color(environment, 0)


func _environment_terrain_color(environment: Resource, variant: int) -> Color:
	if environment == null:
		return Color(0.08, 0.32, 0.12, 1.0)

	var palette: Dictionary = environment.get("terrain_palette")
	var colors: Array = palette.values()
	if colors.is_empty():
		return Color(0.08, 0.32, 0.12, 1.0)

	var color = colors[_positive_index(variant, colors.size())]
	if color is Color:
		return color
	return Color(0.08, 0.32, 0.12, 1.0)


func _box_mesh(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


func _box_node(node_name: String, size: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = _box_mesh(size)
	node.material_override = material
	return node


func _material(color: Color, roughness: float = 0.82, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


func _resource_float(resource: Object, key: String, fallback: float) -> float:
	if resource == null:
		return fallback
	var value = resource.get(key)
	if value == null:
		return fallback
	return float(value)


func _resource_bool(resource: Object, key: String, fallback: bool) -> bool:
	if resource == null:
		return fallback
	var value = resource.get(key)
	if value == null:
		return fallback
	return bool(value)


func _resource_color(resource: Object, key: String, fallback: Color) -> Color:
	if resource == null:
		return fallback
	var value = resource.get(key)
	if value is Color:
		return value
	return fallback


func _environment_id(environment: Resource) -> StringName:
	if environment == null:
		return &""
	var value = environment.get("environment_id")
	return _as_string_name(value)


func _as_string_name(value) -> StringName:
	if value is StringName:
		return value
	return StringName(String(value))


func _noise01(a: int, b: int, c: int) -> float:
	var value: float = sin(float(a * 15731 + b * 789221 + c * 1376312589)) * 43758.5453
	return value - floorf(value)


func _positive_index(value: int, modulo: int) -> int:
	if modulo <= 0:
		return 0
	var index: int = value % modulo
	if index < 0:
		index += modulo
	return index
