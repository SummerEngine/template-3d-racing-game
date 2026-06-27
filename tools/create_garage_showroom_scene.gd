extends SceneTree

const SHOWROOM_SCENE_PATH: String = "res://scenes/ui/garage_showroom.tscn"
const HANGAR_FLOOR_TEXTURE_PATH: String = "res://assets/ui/showroom/hangar_floor_workshop_concrete_4k.png"
const HANGAR_FLOOR_NORMAL_TEXTURE_PATH: String = "res://assets/ui/showroom/hangar_floor_workshop_concrete_4k_normal.png"
const TIRE_MARKS_DECAL_TEXTURE_PATH: String = "res://assets/ui/showroom/tire_marks_decal_4k.png"
const HANGAR_WALL_TILE_TEXTURE_PATH: String = "res://assets/ui/showroom/hangar_wall_tileable.png"
const HANGAR_WALL_PANEL_TEXTURE_PATH: String = "res://assets/ui/showroom/hangar_wall_panels_4k.png"
const HANGAR_WALL_NORMAL_TEXTURE_PATH: String = "res://assets/ui/showroom/hangar_wall_panels_4k_normal.png"
const HANGAR_CEILING_TEXTURE_PATH: String = "res://assets/ui/showroom/hangar_ceiling_panels_4k.png"
const HANGAR_CEILING_NORMAL_TEXTURE_PATH: String = "res://assets/ui/showroom/hangar_ceiling_panels_4k_normal.png"
const GARAGE_PLATFORM_MODEL_PATH: String = "res://assets/ui/showroom/platform/rotation_platform.glb"
const GARAGE_TOOL_CART_MODEL_PATH: String = "res://assets/ui/showroom/props/tool_cart.glb"
const GARAGE_CEILING_LIGHT_MODEL_PATH: String = "res://assets/ui/showroom/lights/industrial_ceiling_light_reference.glb"
const GARAGE_PLATFORM_SCALE: float = 2.746472
const GARAGE_PLATFORM_POSITION: Vector3 = Vector3(0.0025858446, 0.23249164, 0.0022535285)
const GARAGE_PLATFORM_TOP_Y: float = 0.4894
const GARAGE_TOOL_CART_SCALE: float = 0.48172298
const GARAGE_TOOL_CART_POSITION: Vector3 = Vector3(-4.2493668, 0.46041885, -2.549956)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var root := Node3D.new()
	root.name = "GarageShowroom"

	_build_environment(root)
	_build_room(root)
	_build_lights(root)
	_build_turntable(root)
	_build_camera(root)
	_build_editable_props(root)
	_assign_owner_recursive(root, root)

	var packed_scene := PackedScene.new()
	var pack_error := packed_scene.pack(root)
	if pack_error != OK:
		push_error("Could not pack %s: %d" % [SHOWROOM_SCENE_PATH, pack_error])
		quit(1)
		return

	var save_error := ResourceSaver.save(packed_scene, SHOWROOM_SCENE_PATH)
	if save_error != OK:
		push_error("Could not save %s: %d" % [SHOWROOM_SCENE_PATH, save_error])
		quit(1)
		return

	print("Garage showroom scene saved to %s" % SHOWROOM_SCENE_PATH)
	quit(0)


func _build_environment(root: Node3D) -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.006, 0.008, 0.012, 1.0)
	environment.background_energy_multiplier = 0.65
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.62, 0.70, 0.78, 1.0)
	environment.ambient_light_energy = 0.46
	environment.set("reflected_light_source", 1)
	environment.set("tonemap_mode", 4)
	environment.tonemap_exposure = 1.056
	environment.tonemap_white = 6.0
	environment.set("tonemap_agx_contrast", 1.126)
	environment.set("tonemap_agx_white", 12.0)
	environment.ssr_enabled = false
	environment.ssr_max_steps = 96
	environment.ssr_fade_in = 0.08
	environment.ssr_fade_out = 2.8
	environment.ssr_depth_tolerance = 0.25
	environment.ssao_enabled = true
	environment.ssao_radius = 2.2
	environment.ssao_intensity = 0.826
	environment.ssao_power = 1.245
	environment.ssao_detail = 0.455
	environment.ssil_enabled = true
	environment.ssil_radius = 3.0
	environment.ssil_intensity = 0.266
	environment.glow_enabled = true
	environment.glow_intensity = 0.196
	environment.glow_strength = 0.504
	environment.glow_bloom = 0.056
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.014
	environment.adjustment_contrast = 1.049
	environment.adjustment_saturation = 0.972
	world_environment.environment = environment
	root.add_child(world_environment)


func _build_room(root: Node3D) -> void:
	var room := Node3D.new()
	room.name = "EditableRoom"
	root.add_child(room)

	var floor_material := _make_material(Color(0.72, 0.73, 0.71, 1.0), 0.0, 0.32, HANGAR_FLOOR_TEXTURE_PATH, Vector3(2.2, 1.0, 2.0), Color.TRANSPARENT, 0.0, HANGAR_FLOOR_NORMAL_TEXTURE_PATH, 0.20)
	var wall_material := _make_material(Color(0.76, 0.79, 0.79, 1.0), 0.0, 0.60, HANGAR_WALL_PANEL_TEXTURE_PATH, Vector3(1.0, 1.0, 1.0), Color.TRANSPARENT, 0.0, HANGAR_WALL_NORMAL_TEXTURE_PATH, 0.24)
	var side_wall_material := _make_material(Color(0.64, 0.68, 0.69, 1.0), 0.0, 0.62, HANGAR_WALL_PANEL_TEXTURE_PATH, Vector3(1.0, 1.0, 1.0), Color.TRANSPARENT, 0.0, HANGAR_WALL_NORMAL_TEXTURE_PATH, 0.22)
	var ceiling_material := _make_material(Color(0.36, 0.38, 0.40, 1.0), 0.10, 0.46, HANGAR_CEILING_TEXTURE_PATH, Vector3.ONE, Color.TRANSPARENT, 0.0, HANGAR_CEILING_NORMAL_TEXTURE_PATH, 0.32)
	var beam_material := _make_material(Color(0.055, 0.060, 0.065, 1.0), 0.38, 0.36)
	var trim_material := _make_material(Color(0.13, 0.15, 0.16, 1.0), 0.26, 0.40)
	var window_material := _make_material(Color(0.58, 0.88, 1.0, 0.88), 0.0, 0.12, "", Vector3.ONE, Color(0.40, 0.86, 1.0, 1.0), 0.85)

	_add_box(room, "HangarPolishedFloor", Vector3(11.0, 0.08, 9.0), Vector3(0.0, -0.08, 0.0), floor_material)
	_build_floor_decals(room)
	_add_box(room, "HangarBackWall", Vector3(11.0, 3.45, 0.12), Vector3(0.0, 1.62, -4.30), wall_material)
	_add_box(room, "HangarLeftWall", Vector3(0.12, 3.35, 9.0), Vector3(-5.42, 1.55, 0.0), side_wall_material)
	_add_box(room, "HangarRightWall", Vector3(0.12, 3.35, 9.0), Vector3(5.42, 1.55, 0.0), side_wall_material)
	_add_box(room, "HangarCeiling", Vector3(11.0, 0.10, 9.0), Vector3(0.0, 3.34, 0.0), ceiling_material)
	_build_reference_ceiling_fixture(room)

	for index: int in range(7):
		var x := -4.8 + float(index) * 1.6
		_add_box(room, "HangarBackVerticalBeam_%02d" % index, Vector3(0.055, 3.25, 0.08), Vector3(x, 1.55, -4.20), beam_material)
	for beam_y: float in [0.52, 1.62, 2.74]:
		_add_box(room, "HangarBackHorizontalBeam_%.1f" % beam_y, Vector3(10.65, 0.045, 0.08), Vector3(0.0, beam_y, -4.18), beam_material)
	for index: int in range(5):
		var z := -3.45 + float(index) * 1.72
		_add_box(room, "HangarLeftBayBeam_%02d" % index, Vector3(0.08, 3.05, 0.055), Vector3(-5.32, 1.45, z), trim_material)
		_add_box(room, "HangarRightBayBeam_%02d" % index, Vector3(0.08, 3.05, 0.055), Vector3(5.32, 1.45, z), trim_material)
		_add_box(room, "HangarRoofRib_%02d" % index, Vector3(10.75, 0.08, 0.075), Vector3(0.0, 3.22, z), beam_material)

	for index: int in range(5):
		var window_x := -3.55 + float(index) * 1.78
		_add_box(room, "HangarUpperWindow_%02d" % index, Vector3(1.18, 0.38, 0.035), Vector3(window_x, 2.34, -4.13), window_material)

	_add_box(room, "HangarLeftWindowStrip", Vector3(0.035, 0.32, 4.2), Vector3(-5.25, 2.28, -1.0), window_material)
	_add_box(room, "HangarRightWindowStrip", Vector3(0.035, 0.32, 4.2), Vector3(5.25, 2.28, -1.0), window_material)
	_add_box(room, "HangarBackLowerKickPlate", Vector3(10.7, 0.36, 0.055), Vector3(0.0, 0.18, -4.12), trim_material)
	_add_box(room, "HangarLeftLowerKickPlate", Vector3(0.055, 0.34, 8.6), Vector3(-5.25, 0.17, 0.0), trim_material)
	_add_box(room, "HangarRightLowerKickPlate", Vector3(0.055, 0.34, 8.6), Vector3(5.25, 0.17, 0.0), trim_material)


func _build_floor_decals(room: Node3D) -> void:
	var decals := Node3D.new()
	decals.name = "EditableFloorDecals"
	room.add_child(decals)

	var tire_marks := MeshInstance3D.new()
	tire_marks.name = "TireMarksDecal_01"
	var tire_mesh := PlaneMesh.new()
	tire_mesh.size = Vector2(3.4, 5.8)
	tire_marks.mesh = tire_mesh
	tire_marks.position = Vector3(-1.2, -0.03, 1.3)
	tire_marks.material_override = _make_decal_material(TIRE_MARKS_DECAL_TEXTURE_PATH)
	decals.add_child(tire_marks)


func _build_reference_ceiling_fixture(room: Node3D) -> void:
	var fixtures := Node3D.new()
	fixtures.name = "EditableCeilingFixtures"
	room.add_child(fixtures)

	var fixture := Node3D.new()
	fixture.name = "IndustrialCeilingLightReference_01"
	fixture.position = Vector3(0.0, 3.12, -0.55)
	fixtures.add_child(fixture)

	if ResourceLoader.exists(GARAGE_CEILING_LIGHT_MODEL_PATH):
		var packed_light := ResourceLoader.load(GARAGE_CEILING_LIGHT_MODEL_PATH) as PackedScene
		if packed_light != null:
			var light_model := packed_light.instantiate() as Node3D
			if light_model != null:
				light_model.name = "IndustrialCeilingLightMesh"
				light_model.rotation_degrees = Vector3(90.0, 0.0, 0.0)
				fixture.add_child(light_model)

	var emitter := MeshInstance3D.new()
	emitter.name = "LightEmitterPanel"
	var emitter_mesh := BoxMesh.new()
	emitter_mesh.size = Vector3(1.35, 0.035, 1.08)
	emitter.mesh = emitter_mesh
	emitter.position = Vector3(0.0, -0.22, 0.0)
	emitter.material_override = _make_material(Color(1.0, 0.96, 0.84, 1.0), 0.0, 0.08, "", Vector3.ONE, Color(1.0, 0.93, 0.72, 1.0), 1.8)
	fixture.add_child(emitter)

	var spot := SpotLight3D.new()
	spot.name = "RealLightSpot"
	spot.position = Vector3(0.0, -0.24, 0.0)
	spot.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	spot.light_color = Color(1.0, 0.955, 0.86, 1.0)
	spot.light_energy = 3.2
	spot.shadow_enabled = true
	spot.spot_range = 6.8
	spot.spot_angle = 52.0
	spot.spot_attenuation = 1.15
	fixture.add_child(spot)

	var glow := OmniLight3D.new()
	glow.name = "RealLightGlow"
	glow.position = Vector3(0.0, -0.18, 0.0)
	glow.light_color = Color(1.0, 0.93, 0.78, 1.0)
	glow.light_energy = 0.55
	glow.omni_range = 3.2
	fixture.add_child(glow)


func _build_lights(root: Node3D) -> void:
	var lights := Node3D.new()
	lights.name = "EditableLights"
	root.add_child(lights)

	var key := DirectionalLight3D.new()
	key.name = "KeyLight"
	key.light_energy = 1.7
	key.light_color = Color(1.0, 0.96, 0.88, 1.0)
	key.shadow_enabled = true
	key.rotation_degrees = Vector3(-54.0, -32.0, 0.0)
	lights.add_child(key)

	var fill := OmniLight3D.new()
	fill.name = "FillLight"
	fill.light_energy = 1.8
	fill.light_color = Color(0.78, 0.88, 1.0, 1.0)
	fill.omni_range = 7.5
	fill.position = Vector3(2.8, 2.4, 3.3)
	lights.add_child(fill)

	var front_reflector := OmniLight3D.new()
	front_reflector.name = "FrontReflector"
	front_reflector.light_energy = 1.1
	front_reflector.light_color = Color(1.0, 0.95, 0.86, 1.0)
	front_reflector.omni_range = 5.0
	front_reflector.position = Vector3(-2.8, 1.6, 2.8)
	lights.add_child(front_reflector)

	var panel_material := _make_material(Color(1.0, 0.96, 0.84, 1.0), 0.0, 0.32, "", Vector3.ONE, Color(1.0, 0.93, 0.72, 1.0), 0.9)
	for row: int in range(3):
		var z := -2.45 + float(row) * 2.35
		for column: int in range(3):
			var x := -2.75 + float(column) * 2.75
			_add_box(lights, "HangarLightPanel_%02d_%02d" % [row, column], Vector3(1.25, 0.035, 0.42), Vector3(x, 3.16, z), panel_material)
			var light := OmniLight3D.new()
			light.name = "HangarSoftLight_%02d_%02d" % [row, column]
			light.light_energy = 0.68
			light.light_color = Color(1.0, 0.96, 0.86, 1.0)
			light.omni_range = 4.6
			light.position = Vector3(x, 2.94, z)
			lights.add_child(light)
	_build_beauty_lighting(root)


func _build_beauty_lighting(root: Node3D) -> void:
	var beauty := Node3D.new()
	beauty.name = "EditableBeautyLighting"
	root.add_child(beauty)

	var probe := ReflectionProbe.new()
	probe.name = "ShowroomReflectionProbe"
	probe.position = Vector3(-0.45, 1.35, -0.35)
	probe.size = Vector3(13.5, 5.2, 15.5)
	probe.origin_offset = Vector3(0.0, 0.15, 0.0)
	probe.box_projection = true
	probe.interior = true
	probe.intensity = 0.128
	probe.blend_distance = 1.15
	beauty.add_child(probe)

	var cool_softbox := _make_material(Color(0.93, 0.965, 1.0, 1.0), 0.0, 0.05, "", Vector3.ONE, Color(0.78, 0.90, 1.0, 1.0), 2.6)
	var warm_softbox := _make_material(Color(1.0, 0.955, 0.84, 1.0), 0.0, 0.06, "", Vector3.ONE, Color(1.0, 0.86, 0.62, 1.0), 1.65)
	_add_hidden_beauty_box(beauty, "BeautySoftbox_Ceiling_Left", Vector3(3.1, 0.035, 0.48), Vector3(-1.95, 3.24, 0.65), cool_softbox)
	_add_hidden_beauty_box(beauty, "BeautySoftbox_Ceiling_Right", Vector3(3.1, 0.035, 0.48), Vector3(1.65, 3.24, 0.65), cool_softbox)
	_add_hidden_beauty_box(beauty, "BeautySoftbox_Back_Warm", Vector3(3.1, 0.035, 0.48), Vector3(-0.25, 2.34, -4.04), warm_softbox, Vector3(40.0, 0.0, 0.0))
	_add_hidden_beauty_box(beauty, "BeautySoftbox_Left_Rim", Vector3(0.045, 1.45, 3.15), Vector3(-5.18, 1.65, 0.7), cool_softbox)
	_add_hidden_beauty_box(beauty, "BeautySoftbox_Right_Rim", Vector3(0.045, 1.45, 3.15), Vector3(5.18, 1.65, 0.7), cool_softbox)

	_add_beauty_spot(beauty, "BeautyOverheadSpot_Left", Vector3(-1.95, 3.02, 0.65), Color(0.88, 0.95, 1.0, 1.0), 1.505, 1.25)
	_add_beauty_spot(beauty, "BeautyOverheadSpot_Right", Vector3(1.65, 3.02, 0.65), Color(0.88, 0.95, 1.0, 1.0), 1.4, 1.2)
	_add_beauty_omni(beauty, "BeautyLeftCoolRim", Vector3(-4.45, 1.55, 1.7), Color(0.55, 0.82, 1.0, 1.0), 0.875, 4.6)
	_add_beauty_omni(beauty, "BeautyRightCoolRim", Vector3(4.45, 1.55, 1.7), Color(0.55, 0.82, 1.0, 1.0), 0.665, 4.6)
	_add_beauty_omni(beauty, "BeautyFrontWarmKicker", Vector3(-2.8, 0.95, 3.05), Color(1.0, 0.80, 0.56, 1.0), 0.504, 3.8)


func _add_hidden_beauty_box(parent: Node3D, node_name: String, box_size: Vector3, box_position: Vector3, box_material: Material, box_rotation_degrees: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var node := _add_box(parent, node_name, box_size, box_position, box_material, box_rotation_degrees)
	node.visible = false
	return node


func _add_beauty_spot(parent: Node3D, node_name: String, light_position: Vector3, color: Color, energy: float, size: float) -> void:
	var light := SpotLight3D.new()
	light.name = node_name
	light.position = light_position
	light.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	light.light_color = color
	light.light_energy = energy
	light.light_size = size
	light.shadow_enabled = true
	light.shadow_blur = 2.0
	light.spot_range = 7.0
	light.spot_angle = 58.0
	light.spot_attenuation = 1.1
	parent.add_child(light)


func _add_beauty_omni(parent: Node3D, node_name: String, light_position: Vector3, color: Color, energy: float, light_range: float) -> void:
	var light := OmniLight3D.new()
	light.name = node_name
	light.position = light_position
	light.light_color = color
	light.light_energy = energy
	light.light_size = 0.9
	light.omni_range = light_range
	parent.add_child(light)


func _build_turntable(root: Node3D) -> void:
	var turntable := Node3D.new()
	turntable.name = "Turntable"
	root.add_child(turntable)

	var platform_material := _make_material(Color(0.11, 0.12, 0.13, 1.0), 0.5, 0.24)
	var highlight_material := _make_material(Color(0.19, 0.22, 0.25, 1.0), 0.35, 0.28)

	var car_mount_y := 0.14
	var platform_scene := ResourceLoader.load(GARAGE_PLATFORM_MODEL_PATH) as PackedScene
	if platform_scene != null:
		var platform_model := platform_scene.instantiate() as Node3D
		if platform_model != null:
			platform_model.name = "RotationPlatformModel"
			platform_model.scale = Vector3.ONE * GARAGE_PLATFORM_SCALE
			platform_model.position = GARAGE_PLATFORM_POSITION
			turntable.add_child(platform_model)
			car_mount_y = GARAGE_PLATFORM_TOP_Y

	if turntable.get_node_or_null("RotationPlatformModel") == null:
		var base := MeshInstance3D.new()
		base.name = "RotatingRoundPlatform"
		var mesh := CylinderMesh.new()
		mesh.top_radius = 2.55
		mesh.bottom_radius = 2.65
		mesh.height = 0.24
		mesh.radial_segments = 64
		base.mesh = mesh
		base.position = Vector3(0.0, 0.02, 0.0)
		base.material_override = platform_material
		turntable.add_child(base)

		var highlight := MeshInstance3D.new()
		highlight.name = "PlatformTopHighlight"
		var highlight_mesh := CylinderMesh.new()
		highlight_mesh.top_radius = 2.40
		highlight_mesh.bottom_radius = 2.40
		highlight_mesh.height = 0.025
		highlight_mesh.radial_segments = 64
		highlight.mesh = highlight_mesh
		highlight.position = Vector3(0.0, 0.155, 0.0)
		highlight.material_override = highlight_material
		turntable.add_child(highlight)

	var car_mount := Node3D.new()
	car_mount.name = "CarMount"
	car_mount.position = Vector3(0.0, car_mount_y, 0.0)
	turntable.add_child(car_mount)


func _build_camera(root: Node3D) -> void:
	var camera := Camera3D.new()
	camera.name = "PreviewCamera"
	camera.fov = 42.0
	camera.current = true
	var elevation_radians := deg_to_rad(24.0)
	var camera_position := Vector3(0.0, sin(elevation_radians) * 6.5, cos(elevation_radians) * 6.5)
	camera.look_at_from_position(camera_position, Vector3(0.55, 0.85, 0.0), Vector3.UP)
	root.add_child(camera)


func _build_editable_props(root: Node3D) -> void:
	var props := Node3D.new()
	props.name = "EditableProps"
	root.add_child(props)

	var dark_material := _make_material(Color(0.055, 0.060, 0.066, 1.0), 0.2, 0.42)
	var cabinet_material := _make_material(Color(0.18, 0.20, 0.22, 1.0), 0.35, 0.32)
	var tire_material := _make_material(Color(0.018, 0.017, 0.016, 1.0), 0.0, 0.72)

	_add_box(props, "ToolCabinet", Vector3(0.95, 0.8, 0.35), Vector3(-4.55, 0.34, -3.25), cabinet_material)
	_add_box(props, "LowWorkBench", Vector3(1.45, 0.35, 0.42), Vector3(4.40, 0.17, -3.15), dark_material)
	for index: int in range(3):
		var tire := MeshInstance3D.new()
		tire.name = "SpareTire_%02d" % index
		var tire_mesh := TorusMesh.new()
		tire_mesh.inner_radius = 0.16
		tire_mesh.outer_radius = 0.34
		tire_mesh.rings = 18
		tire_mesh.ring_segments = 10
		tire.mesh = tire_mesh
		tire.position = Vector3(-4.65 + float(index) * 0.46, 0.40, 2.80)
		tire.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		tire.material_override = tire_material
		props.add_child(tire)

	var tool_cart_scene := ResourceLoader.load(GARAGE_TOOL_CART_MODEL_PATH) as PackedScene
	if tool_cart_scene != null:
		var tool_cart := tool_cart_scene.instantiate() as Node3D
		if tool_cart != null:
			tool_cart.name = "ToolCart"
			tool_cart.scale = Vector3.ONE * GARAGE_TOOL_CART_SCALE
			tool_cart.position = GARAGE_TOOL_CART_POSITION
			props.add_child(tool_cart)


func _add_box(parent: Node3D, node_name: String, box_size: Vector3, box_position: Vector3, box_material: Material, box_rotation_degrees: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = box_size
	node.mesh = mesh
	node.position = box_position
	node.rotation_degrees = box_rotation_degrees
	node.material_override = box_material
	parent.add_child(node)
	return node


func _make_material(color: Color, metallic: float, roughness: float, texture_path: String = "", uv_scale: Vector3 = Vector3.ONE, emission_color: Color = Color.TRANSPARENT, emission_energy: float = 0.0, normal_texture_path: String = "", normal_scale: float = 0.25) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	material.set("uv1_scale", uv_scale)
	if not texture_path.is_empty() and ResourceLoader.exists(texture_path):
		var texture := ResourceLoader.load(texture_path) as Texture2D
		if texture != null:
			material.albedo_texture = texture
			material.set("texture_repeat", 1)
	if not normal_texture_path.is_empty() and ResourceLoader.exists(normal_texture_path):
		var normal_texture := ResourceLoader.load(normal_texture_path) as Texture2D
		if normal_texture != null:
			material.set("normal_enabled", true)
			material.set("normal_scale", normal_scale)
			material.set("normal_texture", normal_texture)
	if emission_energy > 0.0:
		material.set("emission_enabled", true)
		material.set("emission", emission_color)
		material.set("emission_energy_multiplier", emission_energy)
	return material


func _make_decal_material(texture_path: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.roughness = 0.88
	material.set("transparency", 1)
	material.set("cull_mode", 2)
	if ResourceLoader.exists(texture_path):
		var texture := ResourceLoader.load(texture_path) as Texture2D
		if texture != null:
			material.albedo_texture = texture
	return material


func _assign_owner_recursive(node: Node, owner_node: Node) -> void:
	for child: Node in node.get_children():
		child.owner = owner_node
		_assign_owner_recursive(child, owner_node)
