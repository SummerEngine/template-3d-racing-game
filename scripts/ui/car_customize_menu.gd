class_name CarCustomizeMenu
extends Control

const PLAYER_CAR_SCENE_PATH: String = "res://scenes/player_car.tscn"
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
@export_range(0.0, 2.0, 0.01) var turntable_speed: float = 0.34

var _repaint_client: Node = null
var _skin_applier: Node = null
var _prompt_edit: TextEdit = null
var _generate_button: Button = null
var _apply_button: Button = null
var _status_label: Label = null
var _hue_slider: HSlider = null
var _metallic_slider: HSlider = null
var _roughness_slider: HSlider = null
var _swatch_buttons: Array[Button] = []
var _viewport: SubViewport = null
var _turntable_root: Node3D = null
var _car_preview: Node3D = null
var _current_preview: Dictionary = {}
var _selected_primary: Color = Color(0.08, 0.36, 0.95, 1.0)
var _selected_accent: Color = Color(1.0, 0.18, 0.12, 1.0)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_resolve_integration_nodes()
	_build_interface()
	_build_preview_scene()
	_select_swatch(3)
	_set_status(_integration_status_text())


func _process(delta: float) -> void:
	if _turntable_root != null:
		_turntable_root.rotate_y(turntable_speed * delta)


func _resolve_integration_nodes() -> void:
	_repaint_client = _resolve_optional_node(repaint_client_path)
	_skin_applier = _resolve_optional_node(skin_applier_path)
	_connect_preview_signals()


func _resolve_optional_node(path: NodePath) -> Node:
	if path.is_empty():
		return null
	return get_node_or_null(path)


func _connect_preview_signals() -> void:
	if _repaint_client == null:
		return
	for signal_name: StringName in PREVIEW_SIGNAL_NAMES:
		if _repaint_client.has_signal(signal_name):
			var callback := Callable(self, "_on_repaint_preview_ready")
			if not _repaint_client.is_connected(signal_name, callback):
				_repaint_client.connect(signal_name, callback)


func _build_interface() -> void:
	for child: Node in get_children():
		child.queue_free()

	var background := ColorRect.new()
	background.name = "WarehouseBackdrop"
	background.color = Color(0.055, 0.065, 0.07, 1.0)
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
	controls.add_theme_stylebox_override("panel", _make_style(Color(0.90, 0.93, 0.91, 0.98), Color(0.12, 0.16, 0.16, 1.0), 2, 8))
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

	controls_box.add_child(_make_title("AI Repaint Bay"))
	controls_box.add_child(_make_section_label("Prompt"))

	_prompt_edit = TextEdit.new()
	_prompt_edit.name = "Prompt"
	_prompt_edit.text = "midnight blue satin body, copper pinstripe, clean sponsor-free race livery"
	_prompt_edit.custom_minimum_size = Vector2(280, 116)
	_prompt_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_prompt_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_prompt_edit.add_theme_font_size_override("font_size", 14)
	controls_box.add_child(_prompt_edit)

	var action_row := HBoxContainer.new()
	action_row.name = "ActionRow"
	action_row.add_theme_constant_override("separation", 10)
	controls_box.add_child(action_row)

	_generate_button = _make_button("Generate Preview", Callable(self, "_on_generate_preview_pressed"), true)
	action_row.add_child(_generate_button)

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
	_status_label.add_theme_color_override("font_color", Color(0.20, 0.26, 0.27, 1.0))
	controls_box.add_child(_status_label)

	var preview_panel := PanelContainer.new()
	preview_panel.name = "PreviewPanel"
	preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_panel.size_flags_stretch_ratio = 2.0
	preview_panel.add_theme_stylebox_override("panel", _make_style(Color(0.025, 0.03, 0.034, 1.0), Color(0.18, 0.22, 0.22, 1.0), 2, 8))
	layout.add_child(preview_panel)

	var preview_margin := MarginContainer.new()
	preview_margin.name = "PreviewMargin"
	preview_margin.add_theme_constant_override("margin_left", 10)
	preview_margin.add_theme_constant_override("margin_top", 10)
	preview_margin.add_theme_constant_override("margin_right", 10)
	preview_margin.add_theme_constant_override("margin_bottom", 10)
	preview_panel.add_child(preview_margin)

	var preview_container := SubViewportContainer.new()
	preview_container.name = "CarPreview"
	preview_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_container.stretch = true
	preview_margin.add_child(preview_container)

	_viewport = SubViewport.new()
	_viewport.name = "PreviewViewport"
	_viewport.size = Vector2i(1280, 820)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	preview_container.add_child(_viewport)


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

	var camera := Camera3D.new()
	camera.name = "PreviewCamera"
	camera.fov = 46.0
	camera.look_at_from_position(Vector3(0.0, 2.35, 7.2), Vector3(0.0, 0.85, 0.0), Vector3.UP)
	camera.current = true
	stage_root.add_child(camera)


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

	var car_scene: PackedScene = null
	if ResourceLoader.exists(PLAYER_CAR_SCENE_PATH):
		car_scene = ResourceLoader.load(PLAYER_CAR_SCENE_PATH) as PackedScene

	if car_scene != null:
		_car_preview = car_scene.instantiate() as Node3D
	else:
		_car_preview = _make_fallback_car()

	if _car_preview == null:
		return

	_car_preview.name = "PreviewCar"
	_car_preview.position = Vector3(0.0, 0.19, 0.0)
	_car_preview.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	_car_preview.scale = Vector3(0.78, 0.78, 0.78)
	_car_preview.process_mode = Node.PROCESS_MODE_DISABLED
	_turntable_root.add_child(_car_preview)
	_disable_preview_motion(_car_preview)
	_apply_preview_materials(_selected_primary, _selected_accent, _metallic_value(), _roughness_value())


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
	_generate_button.disabled = true
	_apply_button.disabled = true
	_current_preview = _build_preview_result()
	_apply_preview_materials(_current_preview["primary"], _current_preview["accent"], _current_preview["metallic"], _current_preview["roughness"])

	if _try_request_repaint_preview(_current_preview):
		_set_status("Preview requested from RepaintClient.")
	else:
		_set_status("Mock preview ready. No RepaintClient is connected.")
		_apply_button.disabled = false

	_generate_button.disabled = false


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


func _on_repaint_preview_ready(preview_result: Variant = null) -> void:
	_consume_preview_result(preview_result)
	_apply_button.disabled = _current_preview.is_empty()
	_generate_button.disabled = false
	_set_status("Preview ready from RepaintClient.")


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
	if _repaint_client == null:
		return false

	var options: Dictionary = {
		"primary": preview_result["primary"],
		"accent": preview_result["accent"],
		"metallic": preview_result["metallic"],
		"roughness": preview_result["roughness"],
		"target_node": _car_preview,
	}
	var prompt: String = _prompt_text()
	var called: bool = _call_first_supported_method(_repaint_client, PREVIEW_METHOD_NAMES, [
		[prompt, options],
		[prompt],
		[options],
		[],
	])
	return called


func _try_apply_skin(preview_result: Dictionary) -> bool:
	if _skin_applier == null:
		return false

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
	label.add_theme_color_override("font_color", Color(0.08, 0.11, 0.12, 1.0))
	return label


func _make_section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.16, 0.21, 0.21, 1.0))
	return label


func _make_button(text: String, callback: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(130, 44)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 16)
	if primary:
		button.add_theme_stylebox_override("normal", _make_style(Color(0.94, 0.66, 0.12, 1.0), Color(0.08, 0.09, 0.09, 1.0), 2, 8))
		button.add_theme_color_override("font_color", Color(0.06, 0.07, 0.07, 1.0))
	button.pressed.connect(callback)
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
	label.add_theme_color_override("font_color", Color(0.22, 0.28, 0.29, 1.0))
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
		return "RepaintClient and CarSkinApplier connected."
	if _repaint_client != null:
		return "RepaintClient connected. Apply will stay local until a skin applier is assigned."
	if _skin_applier != null:
		return "CarSkinApplier connected. Generate will use mock previews until a repaint client is assigned."
	return "Offline mock mode. Assign RepaintClient and CarSkinApplier paths when integration lands."
