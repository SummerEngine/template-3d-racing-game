class_name CarCustomizeMenu
extends Control

const MAIN_MENU_SCENE_PATH: String = "res://scenes/ui/main_menu.tscn"
const PLAYER_CAR_SCENE_PATH: String = "res://scenes/player_car.tscn"
const MenuAudioControllerScript := preload("res://scripts/audio/menu_audio_controller.gd")
const UVTextureRepaintClientScript := preload("res://scripts/customization/uv_texture_repaint_client.gd")
const ModelRepaintClientScript := preload("res://scripts/customization/model_repaint_client.gd")
const CarSkinApplierScript := preload("res://scripts/customization/car_skin_applier.gd")
const PREVIEW_SIGNAL_NAMES: Array[StringName] = [
	&"preview_generated",
	&"repaint_preview_ready",
	&"preview_ready",
	&"repaint_completed",
]
const PREVIEW_METHOD_NAMES: Array[StringName] = [
	&"request_repaint_preview",
	&"generate_repaint_preview",
	&"generate_preview",
	&"request_preview",
]
const APPLY_METHOD_NAMES: Array[StringName] = [
	&"apply_skin_preview",
	&"apply_preview",
	&"apply_repaint_result",
	&"apply_repaint",
	&"apply_skin",
]
const PAINT_SWATCHES: Array[Dictionary] = [
	{"label": "Graphite", "primary": Color(0.08, 0.10, 0.11, 1.0), "accent": Color(0.05, 0.68, 0.78, 1.0)},
	{"label": "Pulse Red", "primary": Color(0.92, 0.08, 0.07, 1.0), "accent": Color(1.0, 0.72, 0.10, 1.0)},
	{"label": "Volt Lime", "primary": Color(0.38, 0.92, 0.18, 1.0), "accent": Color(0.04, 0.08, 0.10, 1.0)},
	{"label": "Azure", "primary": Color(0.08, 0.36, 0.95, 1.0), "accent": Color(1.0, 0.18, 0.12, 1.0)},
]

@export var repaint_client_path: NodePath = NodePath("")
@export var skin_applier_path: NodePath = NodePath("")
@export var auto_create_integration_nodes: bool = true
@export_file("*.tscn", "*.glb", "*.gltf") var preview_car_scene_path: String = "res://assets/cars/customizable_hypercar_model3_meshy_retexture.glb"
@export var preview_car_position: Vector3 = Vector3(0.0, 0.19, 0.0)
@export var preview_car_rotation_degrees: Vector3 = Vector3(0.0, 90.0, 0.0)
@export var preview_car_scale: Vector3 = Vector3(2.25, 2.25, 2.25)
@export var auto_ground_preview_car: bool = true
@export var preview_platform_surface_y: float = 0.20
@export var preview_ground_clearance: float = 0.035
@export_range(2.0, 16.0, 0.1) var preview_camera_radius: float = 7.35
@export_range(-45.0, 45.0, 0.1) var preview_camera_yaw_degrees: float = 12.0
@export_range(0.0, 89.0, 0.1) var preview_camera_min_elevation_degrees: float = 4.0
@export_range(0.0, 89.0, 0.1) var preview_camera_max_elevation_degrees: float = 86.0
@export_range(0.0, 89.0, 0.1) var preview_camera_start_elevation_degrees: float = 16.0
@export_range(0.01, 0.5, 0.01) var preview_camera_drag_degrees_per_pixel: float = 0.16
@export var preserve_loaded_preview_materials: bool = true
@export_file("*.glb", "*.gltf", "*.obj") var model_repaint_source_path: String = "res://assets/cars/customizable_hypercar_model3.glb"
@export var model_repaint_source_url: String = ""
@export_file("*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp", "*.tga") var uv_source_texture_path: String = "res://assets/cars/customizable_hypercar_model3_meshy_base_color.png"
@export var uv_source_texture_url: String = ""
@export_range(0.0, 1.0, 0.01) var uv_repaint_strength: float = 0.65
@export var uv_repaint_dry_run: bool = false
@export_range(0.0, 2.0, 0.01) var turntable_speed: float = 0.34

var _repaint_client: Node = null
var _model_repaint_client: Node = null
var _skin_applier: Node = null
var _prompt_edit: TextEdit = null
var _generate_button: Button = null
var _generate_model_button: Button = null
var _apply_button: Button = null
var _status_label: Label = null
var _hue_slider: HSlider = null
var _metallic_slider: HSlider = null
var _roughness_slider: HSlider = null
var _swatch_buttons: Array[Button] = []
var _preview_container: SubViewportContainer = null
var _viewport: SubViewport = null
var _preview_camera: Camera3D = null
var _turntable_root: Node3D = null
var _car_preview: Node3D = null
var _current_preview: Dictionary = {}
var _selected_primary: Color = Color(0.08, 0.36, 0.95, 1.0)
var _selected_accent: Color = Color(1.0, 0.18, 0.12, 1.0)
var _preview_uses_loaded_asset: bool = false
var _camera_orbit_dragging: bool = false
var _camera_orbit_elevation_degrees: float = 16.0
var _preview_camera_target_world: Vector3 = Vector3(0.0, 0.9, 0.0)
var _menu_audio: Node = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_camera_orbit_elevation_degrees = clampf(
		preview_camera_start_elevation_degrees,
		preview_camera_min_elevation_degrees,
		preview_camera_max_elevation_degrees
	)
	_build_interface()
	_build_preview_scene()
	_resolve_integration_nodes()
	call_deferred("_start_menu_audio")
	_select_swatch(3)
	_set_status(_integration_status_text())


func _process(delta: float) -> void:
	if _turntable_root != null:
		_turntable_root.rotate_y(turntable_speed * delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_back_to_main_menu()
		get_viewport().set_input_as_handled()
		return

	if not _camera_orbit_dragging or not (event is InputEventMouseButton):
		return

	var mouse_button := event as InputEventMouseButton
	if mouse_button.button_index == MOUSE_BUTTON_LEFT and not mouse_button.pressed:
		_camera_orbit_dragging = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_back_to_main_menu()


func _resolve_integration_nodes(create_missing: bool = true) -> void:
	_repaint_client = _resolve_optional_node(repaint_client_path)
	_skin_applier = _resolve_optional_node(skin_applier_path)
	if auto_create_integration_nodes and create_missing:
		_repaint_client = _ensure_service_node("UVTextureRepaintClient", UVTextureRepaintClientScript, _repaint_client)
		_model_repaint_client = _ensure_service_node("ModelRepaintClient", ModelRepaintClientScript, _model_repaint_client)
		_skin_applier = _ensure_service_node("CarSkinApplier", CarSkinApplierScript, _skin_applier)
	_configure_uv_repaint_client()
	_configure_model_repaint_client()
	_configure_skin_applier()
	_connect_preview_signals()
	_connect_model_repaint_signals()


func _resolve_optional_node(path: NodePath) -> Node:
	if path.is_empty():
		return null
	return get_node_or_null(path)


func _ensure_service_node(node_name: String, script_resource: Script, existing_node: Node) -> Node:
	if existing_node != null:
		return existing_node

	var service_node := get_node_or_null(node_name)
	if service_node != null:
		return service_node

	service_node = Node.new()
	service_node.name = node_name
	service_node.set_script(script_resource)
	add_child(service_node)
	return service_node


func _configure_uv_repaint_client() -> void:
	if _repaint_client == null:
		return
	_set_property_if_present(_repaint_client, "source_texture_url", uv_source_texture_url)
	_set_property_if_present(_repaint_client, "source_texture_path", uv_source_texture_path)
	_set_property_if_present(_repaint_client, "strength", uv_repaint_strength)
	_set_property_if_present(_repaint_client, "dry_run", uv_repaint_dry_run)


func _configure_model_repaint_client() -> void:
	if _model_repaint_client == null:
		return
	_set_property_if_present(_model_repaint_client, "source_model_url", model_repaint_source_url)
	_set_property_if_present(_model_repaint_client, "source_model_path", model_repaint_source_path)


func _set_property_if_present(target: Object, property_name: StringName, value: Variant) -> void:
	for property_info: Dictionary in target.get_property_list():
		if StringName(str(property_info.get("name", ""))) == property_name:
			target.set(property_name, value)
			return


func _configure_skin_applier() -> void:
	if _skin_applier == null or _car_preview == null:
		return
	if _skin_applier.has_method("set_target"):
		_skin_applier.call("set_target", _car_preview)


func _ensure_repaint_client() -> bool:
	if _repaint_client == null and auto_create_integration_nodes:
		_repaint_client = _ensure_service_node("UVTextureRepaintClient", UVTextureRepaintClientScript, null)
	_configure_uv_repaint_client()
	_connect_preview_signals()
	return _repaint_client != null


func _ensure_model_repaint_client() -> bool:
	if _model_repaint_client == null and auto_create_integration_nodes:
		_model_repaint_client = _ensure_service_node("ModelRepaintClient", ModelRepaintClientScript, null)
	_configure_model_repaint_client()
	_connect_model_repaint_signals()
	return _model_repaint_client != null


func _ensure_skin_applier() -> bool:
	if _skin_applier == null and auto_create_integration_nodes:
		_skin_applier = _ensure_service_node("CarSkinApplier", CarSkinApplierScript, null)
	_configure_skin_applier()
	return _skin_applier != null


func _connect_preview_signals() -> void:
	if _repaint_client == null:
		return
	_connect_repaint_signal(&"repaint_submitted", Callable(self, "_on_repaint_submitted"))
	_connect_repaint_signal(&"repaint_progress", Callable(self, "_on_repaint_progress"))
	_connect_repaint_signal(&"repaint_failed", Callable(self, "_on_repaint_failed"))

	for signal_name: StringName in PREVIEW_SIGNAL_NAMES:
		if _repaint_client.has_signal(signal_name):
			var callback := Callable(self, "_on_repaint_preview_ready")
			if not _repaint_client.is_connected(signal_name, callback):
				_repaint_client.connect(signal_name, callback)


func _connect_model_repaint_signals() -> void:
	if _model_repaint_client == null:
		return

	_connect_model_repaint_signal(&"repaint_submitted", Callable(self, "_on_model_repaint_submitted"))
	_connect_model_repaint_signal(&"repaint_progress", Callable(self, "_on_model_repaint_progress"))
	_connect_model_repaint_signal(&"repaint_failed", Callable(self, "_on_model_repaint_failed"))
	_connect_model_repaint_signal(&"model_repaint_ready", Callable(self, "_on_model_repaint_ready"))


func _connect_repaint_signal(signal_name: StringName, callback: Callable) -> void:
	if _repaint_client == null or not _repaint_client.has_signal(signal_name):
		return
	if not _repaint_client.is_connected(signal_name, callback):
		_repaint_client.connect(signal_name, callback)


func _connect_model_repaint_signal(signal_name: StringName, callback: Callable) -> void:
	if _model_repaint_client == null or not _model_repaint_client.has_signal(signal_name):
		return
	if not _model_repaint_client.is_connected(signal_name, callback):
		_model_repaint_client.connect(signal_name, callback)


func _build_interface() -> void:
	for child: Node in get_children():
		child.queue_free()
	_swatch_buttons.clear()

	var background := ColorRect.new()
	background.name = "WarehouseBackdrop"
	background.color = Color(0.018, 0.022, 0.026, 1.0)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.name = "SafeArea"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var layout := HBoxContainer.new()
	layout.name = "Layout"
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 24)
	margin.add_child(layout)

	var controls := PanelContainer.new()
	controls.name = "Controls"
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.size_flags_vertical = Control.SIZE_EXPAND_FILL
	controls.size_flags_stretch_ratio = 1.0
	controls.add_theme_stylebox_override("panel", _make_style(Color(0.045, 0.052, 0.058, 0.98), Color(0.54, 0.50, 0.39, 0.9), 1, 8))
	layout.add_child(controls)

	var controls_margin := MarginContainer.new()
	controls_margin.name = "Margin"
	controls_margin.add_theme_constant_override("margin_left", 24)
	controls_margin.add_theme_constant_override("margin_top", 22)
	controls_margin.add_theme_constant_override("margin_right", 24)
	controls_margin.add_theme_constant_override("margin_bottom", 22)
	controls.add_child(controls_margin)

	var controls_box := VBoxContainer.new()
	controls_box.name = "Content"
	controls_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	controls_box.add_theme_constant_override("separation", 12)
	controls_margin.add_child(controls_box)

	controls_box.add_child(_make_eyebrow("CUSTOM STUDIO"))
	controls_box.add_child(_make_back_button())
	controls_box.add_child(_make_title("Prototype H1"))
	controls_box.add_child(_make_section_label("Prompt"))

	_prompt_edit = TextEdit.new()
	_prompt_edit.name = "Prompt"
	_prompt_edit.text = "midnight blue satin body, copper pinstripe, clean sponsor-free race livery"
	_prompt_edit.custom_minimum_size = Vector2(280, 116)
	_prompt_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prompt_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_prompt_edit.add_theme_font_size_override("font_size", 14)
	_prompt_edit.add_theme_color_override("font_color", Color(0.91, 0.93, 0.91, 1.0))
	_prompt_edit.add_theme_color_override("caret_color", Color(0.95, 0.68, 0.12, 1.0))
	_prompt_edit.add_theme_stylebox_override("normal", _make_style(Color(0.018, 0.023, 0.028, 1.0), Color(0.22, 0.25, 0.26, 1.0), 1, 7))
	_prompt_edit.add_theme_stylebox_override("focus", _make_style(Color(0.022, 0.027, 0.032, 1.0), Color(0.95, 0.68, 0.12, 1.0), 1, 7))
	controls_box.add_child(_prompt_edit)

	var action_row := HBoxContainer.new()
	action_row.name = "ActionRow"
	action_row.add_theme_constant_override("separation", 10)
	controls_box.add_child(action_row)

	_generate_button = _make_button("Generate Texture", Callable(self, "_on_generate_preview_pressed"), true)
	action_row.add_child(_generate_button)

	_generate_model_button = _make_button("Generate Model", Callable(self, "_on_generate_model_pressed"))
	action_row.add_child(_generate_model_button)

	_apply_button = _make_button("Apply", Callable(self, "_on_apply_pressed"))
	_apply_button.disabled = true
	action_row.add_child(_apply_button)

	controls_box.add_child(_make_section_label("Instant Paint"))
	var swatch_grid := GridContainer.new()
	swatch_grid.name = "Swatches"
	swatch_grid.columns = 2
	swatch_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	swatch_grid.add_theme_constant_override("h_separation", 10)
	swatch_grid.add_theme_constant_override("v_separation", 10)
	controls_box.add_child(swatch_grid)

	for index: int in range(PAINT_SWATCHES.size()):
		swatch_grid.add_child(_make_swatch_button(index))

	controls_box.add_child(_make_section_label("Paint Tuning"))
	_hue_slider = _make_slider(0.0, 1.0, 0.001, 0.58)
	controls_box.add_child(_make_slider_row("Hue", _hue_slider))
	_metallic_slider = _make_slider(0.0, 1.0, 0.01, 0.62)
	controls_box.add_child(_make_slider_row("Metallic", _metallic_slider))
	_roughness_slider = _make_slider(0.05, 1.0, 0.01, 0.28)
	controls_box.add_child(_make_slider_row("Roughness", _roughness_slider))

	_add_spacer(controls_box, 4)
	_status_label = Label.new()
	_status_label.name = "Status"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_status_label.add_theme_font_size_override("font_size", 15)
	_status_label.add_theme_color_override("font_color", Color(0.68, 0.72, 0.72, 1.0))
	controls_box.add_child(_status_label)

	var preview_panel := PanelContainer.new()
	preview_panel.name = "PreviewPanel"
	preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_panel.size_flags_stretch_ratio = 2.0
	preview_panel.add_theme_stylebox_override("panel", _make_style(Color(0.011, 0.014, 0.018, 1.0), Color(0.21, 0.24, 0.24, 1.0), 1, 8))
	layout.add_child(preview_panel)

	var preview_margin := MarginContainer.new()
	preview_margin.name = "PreviewMargin"
	preview_margin.add_theme_constant_override("margin_left", 10)
	preview_margin.add_theme_constant_override("margin_top", 10)
	preview_margin.add_theme_constant_override("margin_right", 10)
	preview_margin.add_theme_constant_override("margin_bottom", 10)
	preview_panel.add_child(preview_margin)

	_preview_container = SubViewportContainer.new()
	_preview_container.name = "CarPreview"
	_preview_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview_container.mouse_filter = Control.MOUSE_FILTER_STOP
	_preview_container.stretch = true
	_preview_container.gui_input.connect(Callable(self, "_on_preview_gui_input"))
	preview_margin.add_child(_preview_container)

	_viewport = SubViewport.new()
	_viewport.name = "PreviewViewport"
	_viewport.size = Vector2i(1280, 820)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_preview_container.add_child(_viewport)


func _build_preview_scene() -> void:
	if _viewport == null:
		return

	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.045, 0.052, 0.056, 1.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.48, 0.55, 0.58, 1.0)
	environment.ambient_light_energy = 0.75
	world.environment = environment
	_viewport.add_child(world)

	var stage_root := Node3D.new()
	stage_root.name = "WarehouseStage"
	_viewport.add_child(stage_root)

	_add_warehouse_floor(stage_root)
	_add_preview_lighting(stage_root)

	_turntable_root = Node3D.new()
	_turntable_root.name = "Turntable"
	stage_root.add_child(_turntable_root)

	var platform := MeshInstance3D.new()
	platform.name = "RotatingPlatform"
	var platform_mesh := CylinderMesh.new()
	platform_mesh.top_radius = 3.15
	platform_mesh.bottom_radius = 3.15
	platform_mesh.height = 0.28
	platform_mesh.radial_segments = 72
	platform.mesh = platform_mesh
	platform.material_override = _make_material(Color(0.11, 0.13, 0.14, 1.0), 0.15, 0.38)
	platform.position.y = 0.02
	_turntable_root.add_child(platform)

	var ring := MeshInstance3D.new()
	ring.name = "PlatformTrim"
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 3.10
	ring_mesh.outer_radius = 3.22
	ring_mesh.ring_segments = 96
	ring_mesh.rings = 8
	ring.mesh = ring_mesh
	ring.material_override = _make_material(Color(0.95, 0.68, 0.12, 1.0), 0.0, 0.24)
	ring.position.y = 0.19
	_turntable_root.add_child(ring)

	_spawn_preview_car()

	_preview_camera = Camera3D.new()
	_preview_camera.name = "PreviewCamera"
	_preview_camera.fov = 46.0
	_preview_camera.current = true
	stage_root.add_child(_preview_camera)
	_refresh_preview_camera_target()
	_update_preview_camera()


func _on_preview_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			_camera_orbit_dragging = mouse_button.pressed
			accept_event()
		return

	if not _camera_orbit_dragging or not (event is InputEventMouseMotion):
		return

	var mouse_motion := event as InputEventMouseMotion
	_camera_orbit_elevation_degrees = clampf(
		_camera_orbit_elevation_degrees + mouse_motion.relative.y * preview_camera_drag_degrees_per_pixel,
		preview_camera_min_elevation_degrees,
		preview_camera_max_elevation_degrees
	)
	_update_preview_camera()
	accept_event()


func _refresh_preview_camera_target() -> void:
	if _turntable_root == null:
		_preview_camera_target_world = Vector3(0.0, 0.9, 0.0)
		return

	_preview_camera_target_world = _turntable_root.global_position + Vector3(0.0, 0.9, 0.0)
	if _car_preview == null:
		return

	var bounds: Dictionary = _combined_mesh_aabb(_car_preview)
	if not bool(bounds.get("has_bounds", false)):
		return

	var car_aabb: AABB = bounds["aabb"]
	var car_center := car_aabb.get_center()
	_preview_camera_target_world = Vector3(
		_turntable_root.global_position.x,
		clampf(car_center.y, _turntable_root.global_position.y + 0.55, _turntable_root.global_position.y + 1.65),
		_turntable_root.global_position.z
	)


func _update_preview_camera() -> void:
	if _preview_camera == null:
		return

	var elevation_radians := deg_to_rad(_camera_orbit_elevation_degrees)
	var yaw_radians := deg_to_rad(preview_camera_yaw_degrees)
	var horizontal_radius := cos(elevation_radians) * preview_camera_radius
	var camera_position := _preview_camera_target_world + Vector3(
		sin(yaw_radians) * horizontal_radius,
		sin(elevation_radians) * preview_camera_radius,
		cos(yaw_radians) * horizontal_radius
	)
	_preview_camera.global_position = camera_position
	_preview_camera.look_at(_preview_camera_target_world, Vector3.UP)


func _add_warehouse_floor(parent: Node3D) -> void:
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(16.0, 12.0)

	var floor_instance := MeshInstance3D.new()
	floor_instance.name = "ConcreteFloor"
	floor_instance.mesh = floor_mesh
	floor_instance.material_override = _make_material(Color(0.075, 0.085, 0.088, 1.0), 0.0, 0.76)
	parent.add_child(floor_instance)

	var back_wall := MeshInstance3D.new()
	back_wall.name = "BackWall"
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(16.0, 4.6, 0.12)
	back_wall.mesh = wall_mesh
	back_wall.material_override = _make_material(Color(0.065, 0.073, 0.076, 1.0), 0.0, 0.8)
	back_wall.position = Vector3(0.0, 2.25, -4.7)
	parent.add_child(back_wall)

	for x_position: float in [-5.6, -2.8, 0.0, 2.8, 5.6]:
		var stripe := MeshInstance3D.new()
		stripe.name = "WallRib"
		var stripe_mesh := BoxMesh.new()
		stripe_mesh.size = Vector3(0.05, 4.5, 0.08)
		stripe.mesh = stripe_mesh
		stripe.material_override = _make_material(Color(0.12, 0.14, 0.145, 1.0), 0.0, 0.45)
		stripe.position = Vector3(x_position, 2.25, -4.62)
		parent.add_child(stripe)


func _add_preview_lighting(parent: Node3D) -> void:
	var key_light := DirectionalLight3D.new()
	key_light.name = "KeyLight"
	key_light.light_energy = 2.4
	key_light.rotation_degrees = Vector3(-48.0, -34.0, 0.0)
	key_light.shadow_enabled = true
	parent.add_child(key_light)

	var strip_left := OmniLight3D.new()
	strip_left.name = "LeftStripLight"
	strip_left.position = Vector3(-3.0, 3.6, 1.6)
	strip_left.light_energy = 2.2
	strip_left.omni_range = 5.8
	parent.add_child(strip_left)

	var strip_right := OmniLight3D.new()
	strip_right.name = "RightStripLight"
	strip_right.position = Vector3(3.0, 2.8, 2.2)
	strip_right.light_color = Color(0.65, 0.90, 1.0, 1.0)
	strip_right.light_energy = 1.8
	strip_right.omni_range = 5.4
	parent.add_child(strip_right)


func _spawn_preview_car() -> void:
	if _turntable_root == null:
		return

	_preview_uses_loaded_asset = false
	var car_scene: PackedScene = _load_preview_scene(preview_car_scene_path)
	if car_scene != null:
		_preview_uses_loaded_asset = true
	else:
		car_scene = _load_preview_scene(PLAYER_CAR_SCENE_PATH)

	if car_scene != null:
		_car_preview = car_scene.instantiate() as Node3D
	else:
		_car_preview = _make_fallback_car()

	if _car_preview == null:
		return

	_car_preview.name = "PreviewCar"
	_car_preview.position = preview_car_position
	_car_preview.rotation_degrees = preview_car_rotation_degrees
	_car_preview.scale = preview_car_scale
	_car_preview.process_mode = Node.PROCESS_MODE_DISABLED
	_turntable_root.add_child(_car_preview)
	_disable_preview_motion(_car_preview)
	_ground_preview_car_on_platform()
	_apply_preview_materials(_selected_primary, _selected_accent, _metallic_value(), _roughness_value())
	_refresh_preview_camera_target()
	_update_preview_camera()


func _load_preview_scene(scene_path: String) -> PackedScene:
	var clean_path := scene_path.strip_edges()
	if clean_path.is_empty() or not ResourceLoader.exists(clean_path):
		return null

	var resource := ResourceLoader.load(clean_path)
	return resource as PackedScene


func _ground_preview_car_on_platform() -> void:
	if not auto_ground_preview_car or _car_preview == null or _turntable_root == null:
		return

	var bounds: Dictionary = _combined_mesh_aabb(_car_preview)
	if not bool(bounds.get("has_bounds", false)):
		return

	var car_aabb: AABB = bounds["aabb"]
	var target_bottom_y := _turntable_root.global_position.y + preview_platform_surface_y + preview_ground_clearance
	_car_preview.global_position.y += target_bottom_y - car_aabb.position.y


func _combined_mesh_aabb(root: Node) -> Dictionary:
	var has_bounds := false
	var combined := AABB()
	for mesh_instance: MeshInstance3D in _collect_mesh_instances(root):
		if mesh_instance.mesh == null or not mesh_instance.visible:
			continue

		var mesh_aabb := _transformed_aabb(mesh_instance.mesh.get_aabb(), mesh_instance.global_transform)
		if has_bounds:
			combined = combined.merge(mesh_aabb)
		else:
			combined = mesh_aabb
			has_bounds = true

	return {
		"has_bounds": has_bounds,
		"aabb": combined,
	}


func _transformed_aabb(aabb: AABB, transform: Transform3D) -> AABB:
	var min_corner := Vector3(INF, INF, INF)
	var max_corner := Vector3(-INF, -INF, -INF)
	for x: int in [0, 1]:
		for y: int in [0, 1]:
			for z: int in [0, 1]:
				var corner := aabb.position + Vector3(aabb.size.x * x, aabb.size.y * y, aabb.size.z * z)
				var transformed_corner := transform * corner
				min_corner = min_corner.min(transformed_corner)
				max_corner = max_corner.max(transformed_corner)

	return AABB(min_corner, max_corner - min_corner)


func _make_fallback_car() -> Node3D:
	var root := Node3D.new()
	root.name = "FallbackCar"

	var body := MeshInstance3D.new()
	body.name = "Body"
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(1.8, 0.48, 3.6)
	body.mesh = body_mesh
	body.position = Vector3(0.0, 0.55, 0.0)
	root.add_child(body)

	var cabin := MeshInstance3D.new()
	cabin.name = "Cabin"
	var cabin_mesh := BoxMesh.new()
	cabin_mesh.size = Vector3(1.02, 0.54, 1.08)
	cabin.mesh = cabin_mesh
	cabin.position = Vector3(0.0, 0.98, 0.34)
	root.add_child(cabin)

	for wheel_position: Vector3 in [
		Vector3(-0.98, 0.32, -1.25),
		Vector3(0.98, 0.32, -1.25),
		Vector3(-0.98, 0.32, 1.25),
		Vector3(0.98, 0.32, 1.25),
	]:
		var wheel := MeshInstance3D.new()
		wheel.name = "Wheel"
		var wheel_mesh := CylinderMesh.new()
		wheel_mesh.top_radius = 0.3
		wheel_mesh.bottom_radius = 0.3
		wheel_mesh.height = 0.22
		wheel.mesh = wheel_mesh
		wheel.position = wheel_position
		wheel.rotation_degrees.z = 90.0
		root.add_child(wheel)

	return root


func _disable_preview_motion(root: Node) -> void:
	root.set_process(false)
	root.set_physics_process(false)
	for child: Node in root.get_children():
		_disable_preview_motion(child)


func _on_generate_preview_pressed() -> void:
	_resolve_integration_nodes()
	_set_generation_buttons_disabled(true)
	_apply_button.disabled = true
	_current_preview = _build_preview_result()
	_apply_preview_materials(_current_preview["primary"], _current_preview["accent"], _current_preview["metallic"], _current_preview["roughness"])

	if _try_request_repaint_preview(_current_preview):
		_set_status("UV texture repaint requested from local proxy.")
		return
	else:
		_set_status("Mock preview ready. No UVTextureRepaintClient is connected.")
		_apply_button.disabled = false

	_set_generation_buttons_disabled(false)


func _on_generate_model_pressed() -> void:
	_resolve_integration_nodes()
	_set_generation_buttons_disabled(true)
	_apply_button.disabled = true
	_current_preview = _build_preview_result()

	if _try_request_model_repaint(_current_preview):
		_set_status("Model retexture requested from local proxy. This is slower than texture preview.")
		return

	_set_status("No ModelRepaintClient is connected.")
	_set_generation_buttons_disabled(false)


func _on_apply_pressed() -> void:
	if _current_preview.is_empty():
		_set_status("Generate or tune a preview first.")
		return

	_resolve_integration_nodes()
	if _try_apply_skin(_current_preview):
		_set_status("Applied through CarSkinApplier.")
	else:
		_apply_preview_materials(_current_preview["primary"], _current_preview["accent"], _current_preview["metallic"], _current_preview["roughness"])
		_set_status("Applied locally in mock mode.")


func _go_back_to_main_menu() -> void:
	var tree := get_tree()
	if tree == null:
		return
	tree.change_scene_to_file(MAIN_MENU_SCENE_PATH)


func _start_menu_audio() -> void:
	_menu_audio = MenuAudioControllerScript.resolve(self)
	if _menu_audio == null:
		return
	if _menu_audio.has_method("play_menu_music"):
		_menu_audio.call("play_menu_music")
	if _menu_audio.has_method("bind_buttons"):
		_menu_audio.call("bind_buttons", self)


func _on_repaint_preview_ready(preview_result: Variant = null) -> void:
	_consume_preview_result(preview_result)
	_apply_button.disabled = _current_preview.is_empty()
	_set_generation_buttons_disabled(false)
	if preview_result is Dictionary and _has_generated_base_color(preview_result):
		_set_status("UV texture ready. Downloading and applying base color...")
		await _apply_generated_repaint_texture(preview_result)
	else:
		_set_status("Preview ready from UVTextureRepaintClient.")


func _on_repaint_submitted(job_id: String) -> void:
	_set_status("UV texture repaint queued: %s" % job_id)


func _on_repaint_progress(_job_id: String, status: String, progress: float, message: String) -> void:
	_set_status("%s %d%% - %s" % [status.capitalize(), roundi(progress * 100.0), message])


func _on_repaint_failed(_job_id: String, message: String) -> void:
	_set_status("UV texture repaint failed: %s" % message)
	_apply_button.disabled = false
	_set_generation_buttons_disabled(false)


func _on_model_repaint_submitted(job_id: String) -> void:
	_set_status("Model retexture queued: %s" % job_id)


func _on_model_repaint_progress(_job_id: String, status: String, progress: float, message: String) -> void:
	_set_status("Model %s %d%% - %s" % [status.capitalize(), roundi(progress * 100.0), message])


func _on_model_repaint_failed(_job_id: String, message: String) -> void:
	_set_status("Model retexture failed: %s" % message)
	_apply_button.disabled = false
	_set_generation_buttons_disabled(false)


func _on_model_repaint_ready(preview_result: Dictionary) -> void:
	_current_preview = _normalized_preview_result(preview_result)
	_set_status("Model retexture ready. Downloading generated GLB...")
	await _apply_generated_repaint_model(preview_result)
	_apply_button.disabled = _current_preview.is_empty()
	_set_generation_buttons_disabled(false)


func _has_generated_base_color(result: Dictionary) -> bool:
	return typeof(result.get("base_color_url", null)) == TYPE_STRING and not String(result["base_color_url"]).strip_edges().is_empty()


func _is_dry_run_result(result: Dictionary) -> bool:
	return bool(result.get("dry_run", false))


func _apply_generated_repaint_texture(result: Dictionary) -> void:
	if _repaint_client == null or not _repaint_client.has_method("download_result_texture"):
		_set_status("UV texture result ready, but no texture downloader is available.")
		return

	var texture_path: Variant = await _repaint_client.call("download_result_texture", result)
	if typeof(texture_path) != TYPE_STRING or String(texture_path).is_empty():
		_set_status("UV texture result did not include a usable base-color image.")
		return

	var texture := _load_texture_from_file(String(texture_path))
	if texture == null:
		_set_status("Downloaded UV repaint texture could not be loaded.")
		return

	if _apply_body_texture(texture):
		if _is_dry_run_result(result):
			_set_status("Dry-run applied the original UV texture. Add FAL_KEY and disable proxy dry-run to use the prompt.")
		else:
			_set_status("Nano Banana 2 UV texture applied to preview car.")
	else:
		_set_status("Downloaded UV texture, but no body material target was found.")


func _apply_generated_repaint_model(result: Dictionary) -> void:
	if _model_repaint_client == null or not _model_repaint_client.has_method("download_result_model"):
		_set_status("Model result ready, but no model downloader is available.")
		return

	var model_path: Variant = await _model_repaint_client.call("download_result_model", result)
	if typeof(model_path) != TYPE_STRING or String(model_path).is_empty():
		_set_status("Model result did not include a usable GLB.")
		return

	var model_root := _load_model_node_from_file(String(model_path))
	if model_root == null:
		_set_status("Generated GLB downloaded, but could not be loaded at runtime.")
		return

	_replace_preview_car(model_root)
	_set_status("Meshy model retexture applied to turntable preview.")


func _load_model_node_from_file(model_path: String) -> Node3D:
	var clean_path := model_path.strip_edges()
	if clean_path.is_empty():
		return null

	var resource: Resource = null
	if ResourceLoader.exists(clean_path):
		resource = ResourceLoader.load(clean_path)

	if resource is PackedScene:
		return (resource as PackedScene).instantiate() as Node3D

	var gltf_document := GLTFDocument.new()
	var gltf_state := GLTFState.new()
	var error := gltf_document.append_from_file(clean_path, gltf_state)
	if error != OK:
		push_warning("CarCustomizeMenu: failed to load generated GLB '%s' with error %d" % [clean_path, error])
		return null

	var generated_scene := gltf_document.generate_scene(gltf_state)
	return generated_scene as Node3D


func _replace_preview_car(new_car: Node3D) -> void:
	if new_car == null or _turntable_root == null:
		return

	if _car_preview != null:
		_car_preview.queue_free()

	_car_preview = new_car
	_car_preview.name = "PreviewCar"
	_car_preview.position = preview_car_position
	_car_preview.rotation_degrees = preview_car_rotation_degrees
	_car_preview.scale = preview_car_scale
	_car_preview.process_mode = Node.PROCESS_MODE_DISABLED
	_preview_uses_loaded_asset = true
	_turntable_root.add_child(_car_preview)
	_disable_preview_motion(_car_preview)
	_ground_preview_car_on_platform()
	_configure_skin_applier()
	_refresh_preview_camera_target()
	_update_preview_camera()


func _load_texture_from_file(path: String) -> Texture2D:
	var image := Image.new()
	var error := image.load(path)
	if error != OK:
		push_warning("CarCustomizeMenu: failed to load repaint texture '%s' with error %d" % [path, error])
		return null
	return ImageTexture.create_from_image(image)


func _apply_body_texture(texture: Texture2D) -> bool:
	_ensure_skin_applier()
	if _skin_applier == null or not _skin_applier.has_method("apply_body_texture"):
		return false
	_skin_applier.call("apply_body_texture", texture)
	return true


func _consume_preview_result(preview_result: Variant) -> void:
	if preview_result is Dictionary:
		var result: Dictionary = preview_result
		_current_preview = _normalized_preview_result(result)
		_apply_preview_materials(_current_preview["primary"], _current_preview["accent"], _current_preview["metallic"], _current_preview["roughness"])
	elif preview_result is Color:
		_selected_primary = preview_result
		_current_preview = _build_preview_result()
		_apply_preview_materials(_current_preview["primary"], _current_preview["accent"], _current_preview["metallic"], _current_preview["roughness"])
	elif _current_preview.is_empty():
		_current_preview = _build_preview_result()


func _try_request_repaint_preview(preview_result: Dictionary) -> bool:
	if not _ensure_repaint_client():
		return false

	var options: Dictionary = {
		"primary": preview_result["primary"],
		"accent": preview_result["accent"],
		"metallic": preview_result["metallic"],
		"roughness": preview_result["roughness"],
		"target_node": _car_preview,
		"texture_url": uv_source_texture_url,
		"texture_path": uv_source_texture_path,
		"strength": uv_repaint_strength,
		"dry_run": uv_repaint_dry_run,
	}
	var prompt: String = _prompt_text()
	var called: bool = _call_first_supported_method(_repaint_client, PREVIEW_METHOD_NAMES, [
		[prompt, options],
		[prompt],
		[options],
		[],
	])
	return called


func _try_request_model_repaint(preview_result: Dictionary) -> bool:
	if not _ensure_model_repaint_client():
		return false

	var options: Dictionary = {
		"model_url": model_repaint_source_url,
		"model_path": model_repaint_source_path,
		"target_node": _car_preview,
		"primary": preview_result["primary"],
		"accent": preview_result["accent"],
	}
	var prompt: String = _model_repaint_prompt(_prompt_text())
	if _model_repaint_client.has_method("request_model_repaint"):
		_model_repaint_client.call("request_model_repaint", prompt, options)
		return true
	return false


func _model_repaint_prompt(prompt: String) -> String:
	var clean_prompt := prompt.strip_edges()
	if clean_prompt.is_empty():
		return "premium futuristic racing livery, preserve original model shape and proportions"

	return "%s. Preserve the original model shape, glass placement, wheel placement, UV layout, and racing-car proportions." % clean_prompt


func _set_generation_buttons_disabled(disabled: bool) -> void:
	if _generate_button != null:
		_generate_button.disabled = disabled
	if _generate_model_button != null:
		_generate_model_button.disabled = disabled


func _try_apply_skin(preview_result: Dictionary) -> bool:
	_ensure_skin_applier()
	if _skin_applier == null:
		return false

	if _skin_applier.has_method("apply_body_color"):
		_skin_applier.call("apply_body_color", preview_result["primary"], preview_result["metallic"], preview_result["roughness"])
		return true

	return _call_first_supported_method(_skin_applier, APPLY_METHOD_NAMES, [
		[preview_result, _car_preview],
		[_car_preview, preview_result],
		[preview_result],
		[_car_preview],
		[],
	])


func _call_first_supported_method(target: Node, method_names: Array[StringName], argument_sets: Array) -> bool:
	for method_name: StringName in method_names:
		if not target.has_method(method_name):
			continue
		var argument_count: int = _method_argument_count(target, method_name)
		for arguments: Array in argument_sets:
			if arguments.size() == argument_count:
				target.callv(method_name, arguments)
				return true
		if argument_count < 0:
			target.call(method_name)
			return true
	return false


func _method_argument_count(target: Object, method_name: StringName) -> int:
	for method_info: Dictionary in target.get_method_list():
		if StringName(str(method_info.get("name", ""))) == method_name:
			var args: Array = method_info.get("args", [])
			return args.size()
	return -1


func _build_preview_result() -> Dictionary:
	var primary: Color = _color_from_slider()
	if _prompt_text().length() > 0:
		primary = primary.lerp(_color_from_prompt(_prompt_text()), 0.22)
	var accent: Color = _selected_accent
	return {
		"mode": "mock",
		"prompt": _prompt_text(),
		"primary": primary,
		"accent": accent,
		"metallic": _metallic_value(),
		"roughness": _roughness_value(),
	}


func _normalized_preview_result(result: Dictionary) -> Dictionary:
	var normalized: Dictionary = _build_preview_result()
	for key: Variant in result.keys():
		normalized[key] = result[key]
	normalized["primary"] = _variant_to_color(normalized.get("primary", normalized.get("color", _selected_primary)), _selected_primary)
	normalized["accent"] = _variant_to_color(normalized.get("accent", _selected_accent), _selected_accent)
	normalized["metallic"] = clampf(float(normalized.get("metallic", _metallic_value())), 0.0, 1.0)
	normalized["roughness"] = clampf(float(normalized.get("roughness", _roughness_value())), 0.05, 1.0)
	return normalized


func _variant_to_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value
	if value is String:
		var parsed := Color.from_string(value, fallback)
		return parsed
	return fallback


func _color_from_slider() -> Color:
	if _hue_slider == null:
		return _selected_primary
	return Color.from_hsv(float(_hue_slider.value), 0.82, 0.94, 1.0)


func _color_from_prompt(prompt: String) -> Color:
	var hash_value: int = abs(hash(prompt))
	var hue: float = float(hash_value % 360) / 360.0
	var saturation_seed: int = int(float(hash_value) / 360.0) % 18
	var saturation: float = 0.68 + float(saturation_seed) / 100.0
	return Color.from_hsv(hue, saturation, 0.94, 1.0)


func _apply_preview_materials(primary: Color, accent: Color, metallic: float, roughness: float) -> void:
	if _car_preview == null:
		return
	if preserve_loaded_preview_materials and _preview_uses_loaded_asset:
		return

	_selected_primary = primary
	var body_material := _make_material(primary, metallic, roughness)
	var accent_material := _make_material(accent, minf(1.0, metallic + 0.12), maxf(0.1, roughness * 0.86))
	var dark_material := _make_material(Color(0.025, 0.027, 0.030, 1.0), 0.08, 0.42)

	for mesh_instance: MeshInstance3D in _collect_mesh_instances(_car_preview):
		var mesh_name: String = String(mesh_instance.name).to_lower()
		if mesh_name.contains("wheel") or mesh_name.contains("tire") or mesh_name.contains("tyre"):
			mesh_instance.material_override = dark_material.duplicate()
		elif mesh_name.contains("cabin") or mesh_name.contains("glass") or mesh_name.contains("splitter"):
			mesh_instance.material_override = dark_material.duplicate()
		elif mesh_name.contains("wing") or mesh_name.contains("nose") or mesh_name.contains("fin"):
			mesh_instance.material_override = accent_material.duplicate()
		else:
			mesh_instance.material_override = body_material.duplicate()


func _collect_mesh_instances(root: Node) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	for child: Node in root.get_children():
		if child is MeshInstance3D:
			meshes.append(child as MeshInstance3D)
		meshes.append_array(_collect_mesh_instances(child))
	return meshes


func _make_swatch_button(index: int) -> Button:
	var option: Dictionary = PAINT_SWATCHES[index]
	var button := Button.new()
	button.name = "Swatch%s" % str(option["label"]).replace(" ", "")
	button.text = str(option["label"])
	button.custom_minimum_size = Vector2(120, 42)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.toggle_mode = true
	button.add_theme_font_size_override("font_size", 15)
	var normal_text_color: Color = _readable_text_color(option["primary"])
	var pressed_text_color: Color = _readable_text_color(option["accent"])
	button.add_theme_color_override("font_color", normal_text_color)
	button.add_theme_color_override("font_hover_color", normal_text_color)
	button.add_theme_color_override("font_pressed_color", pressed_text_color)
	button.add_theme_stylebox_override("normal", _make_style(option["primary"], option["accent"], 2, 7))
	button.add_theme_stylebox_override("hover", _make_style(option["primary"].lightened(0.08), option["accent"], 2, 7))
	button.add_theme_stylebox_override("pressed", _make_style(option["accent"], option["primary"], 2, 7))
	button.pressed.connect(Callable(self, "_select_swatch").bind(index))
	_swatch_buttons.append(button)
	return button


func _select_swatch(index: int) -> void:
	if index < 0 or index >= PAINT_SWATCHES.size():
		return

	var option: Dictionary = PAINT_SWATCHES[index]
	_selected_primary = option["primary"]
	_selected_accent = option["accent"]
	if _hue_slider != null:
		_hue_slider.value = _selected_primary.h
	for button_index: int in range(_swatch_buttons.size()):
		_swatch_buttons[button_index].button_pressed = button_index == index
	_update_live_preview()


func _on_slider_changed(_value: float) -> void:
	_update_live_preview()


func _update_live_preview() -> void:
	_current_preview = _build_preview_result()
	_apply_preview_materials(_current_preview["primary"], _current_preview["accent"], _current_preview["metallic"], _current_preview["roughness"])
	if _apply_button != null:
		_apply_button.disabled = false
	if _status_label != null:
		_set_status("Live mock paint preview.")


func _make_title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 34)
	label.add_theme_color_override("font_color", Color(0.93, 0.91, 0.83, 1.0))
	return label


func _make_eyebrow(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.72, 0.67, 0.52, 1.0))
	return label


func _make_section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.77, 0.81, 0.80, 1.0))
	return label


func _make_button(text: String, callback: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(130, 44)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 16)
	if primary:
		button.add_theme_stylebox_override("normal", _make_style(Color(0.94, 0.66, 0.12, 1.0), Color(0.08, 0.09, 0.09, 1.0), 2, 8))
		button.add_theme_stylebox_override("hover", _make_style(Color(1.0, 0.76, 0.18, 1.0), Color(0.08, 0.09, 0.09, 1.0), 2, 8))
		button.add_theme_stylebox_override("pressed", _make_style(Color(0.78, 0.52, 0.08, 1.0), Color(0.08, 0.09, 0.09, 1.0), 2, 8))
		button.add_theme_color_override("font_color", Color(0.06, 0.07, 0.07, 1.0))
	else:
		button.add_theme_stylebox_override("normal", _make_style(Color(0.065, 0.074, 0.082, 1.0), Color(0.40, 0.42, 0.38, 1.0), 1, 8))
		button.add_theme_stylebox_override("hover", _make_style(Color(0.09, 0.103, 0.112, 1.0), Color(0.72, 0.67, 0.52, 1.0), 1, 8))
		button.add_theme_stylebox_override("pressed", _make_style(Color(0.035, 0.041, 0.047, 1.0), Color(0.95, 0.68, 0.12, 1.0), 1, 8))
		button.add_theme_color_override("font_color", Color(0.89, 0.91, 0.89, 1.0))
	button.pressed.connect(callback)
	return button


func _make_back_button() -> Button:
	var button := _make_button("< Back to Main Menu", Callable(self, "_go_back_to_main_menu"))
	button.name = "BackToMainMenu"
	button.custom_minimum_size = Vector2(180, 38)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 14)
	return button


func _make_slider(minimum: float, maximum: float, step: float, value: float) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(Callable(self, "_on_slider_changed"))
	return slider


func _make_slider_row(label_text: String, slider: HSlider) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "%sRow" % label_text
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(78, 30)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.70, 0.74, 0.74, 1.0))
	row.add_child(label)
	row.add_child(slider)
	return row


func _make_style(fill: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style


func _make_material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var paint_material := StandardMaterial3D.new()
	paint_material.albedo_color = color
	paint_material.metallic = metallic
	paint_material.roughness = roughness
	return paint_material


func _readable_text_color(fill: Color) -> Color:
	if fill.get_luminance() < 0.42:
		return Color(0.96, 0.98, 0.96, 1.0)
	return Color(0.05, 0.07, 0.07, 1.0)


func _add_spacer(parent: Node, height: float) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(1, height)
	parent.add_child(spacer)


func _prompt_text() -> String:
	if _prompt_edit == null:
		return ""
	return _prompt_edit.text.strip_edges()


func _metallic_value() -> float:
	if _metallic_slider == null:
		return 0.62
	return float(_metallic_slider.value)


func _roughness_value() -> float:
	if _roughness_slider == null:
		return 0.28
	return float(_roughness_slider.value)


func _set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text


func _integration_status_text() -> String:
	if _repaint_client != null and _skin_applier != null:
		return "UV image-to-image repaint client and CarSkinApplier connected. Proxy dry-run may still return the original texture."
	if _repaint_client != null:
		return "UV image-to-image repaint client connected. Apply will stay local until a skin applier is assigned."
	if _skin_applier != null:
		return "CarSkinApplier connected. Generate will use mock previews until a UV repaint client is assigned."
	return "Offline mock mode. Assign UVTextureRepaintClient and CarSkinApplier paths when integration lands."
