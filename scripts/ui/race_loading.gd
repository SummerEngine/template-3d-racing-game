extends Control

const FigmaUIFontScript := preload("res://scripts/ui/figma_ui_fonts.gd")
const FALLBACK_RACE_SCENE_PATH: String = "res://scenes/race/storm_coast_preview_race.tscn"
const MENU_BACKGROUND_TEXTURE_PATH: String = "res://assets/ui/menu_showroom_background.png"
const TIPS: Array[String] = [
	"Brake before the corner, then accelerate through the exit.",
	"Feather throttle on corner exit to keep the rear planted.",
	"Use the rear view before defending a racing line.",
]
const UI_REFERENCE_SIZE: Vector2 = Vector2(1920.0, 1080.0)
const UI_MIN_SCALE: float = 0.50
const UI_MAX_SCALE: float = 2.25

var _label: Label = null
var _percent_label: Label = null
var _progress: ProgressBar = null
var _paths: Array[String] = []
var _target_scene_path: String = FALLBACK_RACE_SCENE_PATH
var _loaded_count: int = 0
var _complete: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	var session := get_node_or_null("/root/GameSession")
	if session != null:
		if session.has_method("get_pending_loading_target"):
			_target_scene_path = str(session.call("get_pending_loading_target"))
		if session.has_method("get_race_loading_manifest"):
			var value: Variant = session.call("get_race_loading_manifest")
			if value is Array:
				for item: Variant in value:
					_paths.append(str(item))
	if _target_scene_path.is_empty():
		_target_scene_path = FALLBACK_RACE_SCENE_PATH
	if not _paths.has(_target_scene_path):
		_paths.append(_target_scene_path)
	_update_progress()


func _process(_delta: float) -> void:
	if _complete:
		return
	if _loaded_count < _paths.size():
		_load_path(_paths[_loaded_count])
		_loaded_count += 1
		_update_progress()
		return
	_complete = true
	_update_progress()
	call_deferred("_enter_race")


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.025, 0.028, 0.050, 1.0)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var texture := TextureRect.new()
	texture.texture = _selected_track_texture()
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	texture.modulate = Color(1.0, 1.0, 1.0, 0.09)
	texture.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(texture)

	var vignette := ColorRect.new()
	vignette.color = Color(0.0, 0.0, 0.0, 0.42)
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(vignette)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var stack := VBoxContainer.new()
	stack.custom_minimum_size = Vector2(_loading_vw(0.30, 360.0, 720.0), 0.0)
	stack.add_theme_constant_override("separation", _loading_space(14, 24))
	center.add_child(stack)

	stack.add_child(_make_loading_summary("VEHICLE", _selected_car_name(), "CIRCUIT", _selected_track_name()))
	stack.add_child(_make_centered_rule_label("LOADING"))

	_label = Label.new()
	_label.text = "PREPARING RACE"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_label.add_theme_font_size_override("font_size", _loading_font_px(9, 13, 0.012))
	_label.add_theme_color_override("font_color", Color(0.34, 0.34, 0.48, 1.0))

	_progress = ProgressBar.new()
	_progress.min_value = 0.0
	_progress.max_value = 100.0
	_progress.show_percentage = false
	_progress.custom_minimum_size = Vector2(1.0, _loading_space(4, 8))
	_progress.add_theme_stylebox_override("background", _make_style(Color(1.0, 1.0, 1.0, 0.07), Color.TRANSPARENT, 0, 2))
	_progress.add_theme_stylebox_override("fill", _make_style(Color(0.90, 0.0, 0.18, 1.0), Color(0.90, 0.0, 0.18, 1.0), 0, 2))
	stack.add_child(_progress)

	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", _loading_space(8, 14))
	stack.add_child(status_row)
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_row.add_child(_label)
	_percent_label = Label.new()
	_percent_label.text = "0%"
	_percent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_percent_label.add_theme_font_size_override("font_size", _loading_font_px(9, 13, 0.012))
	_percent_label.add_theme_color_override("font_color", Color(0.90, 0.0, 0.18, 1.0))
	status_row.add_child(_percent_label)

	var tip_caption := Label.new()
	tip_caption.text = "DRIVER TIP"
	tip_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip_caption.add_theme_font_size_override("font_size", _loading_font_px(8, 12, 0.011))
	tip_caption.add_theme_color_override("font_color", Color(0.24, 0.24, 0.34, 1.0))
	stack.add_child(tip_caption)
	var tip := Label.new()
	tip.text = TIPS[1]
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.add_theme_font_size_override("font_size", _loading_font_px(13, 22, 0.020))
	tip.add_theme_color_override("font_color", Color(0.48, 0.48, 0.62, 1.0))
	stack.add_child(tip)
	FigmaUIFontScript.apply_tree(self)


func _load_path(path: String) -> void:
	if path.is_empty():
		return
	var resource := load(path)
	var session := get_node_or_null("/root/GameSession")
	if session != null and session.has_method("remember_preloaded_resource") and resource is Resource:
		session.call("remember_preloaded_resource", path, resource)


func _update_progress() -> void:
	var ratio := 1.0 if _paths.is_empty() else float(_loaded_count) / float(_paths.size())
	if _progress != null:
		_progress.value = ratio * 100.0
	if _label != null:
		_label.text = "READY" if ratio >= 1.0 else "PREPARING RACE"
	if _percent_label != null:
		_percent_label.text = "%d%%" % roundi(ratio * 100.0)


func _enter_race() -> void:
	var session := get_node_or_null("/root/GameSession")
	var scene: PackedScene = null
	if session != null and session.has_method("get_preloaded_resource"):
		scene = session.call("get_preloaded_resource", _target_scene_path) as PackedScene
	if scene == null:
		scene = load(_target_scene_path) as PackedScene
	if scene != null:
		get_tree().change_scene_to_packed(scene)
	else:
		get_tree().change_scene_to_file(_target_scene_path)


func _make_loading_summary(left_label: String, left_value: String, right_label: String, right_value: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", _loading_space(10, 18))
	row.add_child(_make_summary_stack(left_label, left_value, HORIZONTAL_ALIGNMENT_RIGHT))
	var divider := ColorRect.new()
	divider.color = Color(1.0, 1.0, 1.0, 0.10)
	divider.custom_minimum_size = Vector2(maxf(1.0, _loading_scale()), _loading_space(30, 48))
	row.add_child(divider)
	row.add_child(_make_summary_stack(right_label, right_value, HORIZONTAL_ALIGNMENT_LEFT))
	return row


func _make_summary_stack(label_text: String, value_text: String, alignment: HorizontalAlignment) -> VBoxContainer:
	var stack := VBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.horizontal_alignment = alignment
	label.add_theme_font_size_override("font_size", _loading_font_px(8, 12, 0.011))
	label.add_theme_color_override("font_color", Color(0.30, 0.30, 0.42, 1.0))
	stack.add_child(label)
	var value := Label.new()
	value.text = value_text
	value.horizontal_alignment = alignment
	value.add_theme_font_size_override("font_size", _loading_font_px(11, 17, 0.016))
	value.add_theme_color_override("font_color", Color(0.48, 0.48, 0.62, 1.0))
	stack.add_child(value)
	return stack


func _make_centered_rule_label(text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", _loading_space(10, 18))
	for side: int in range(3):
		if side == 1:
			var label := Label.new()
			label.text = text
			label.add_theme_font_size_override("font_size", _loading_font_px(9, 13, 0.012))
			label.add_theme_color_override("font_color", Color(0.34, 0.34, 0.48, 1.0))
			row.add_child(label)
		else:
			var line := ColorRect.new()
			line.color = Color(1.0, 1.0, 1.0, 0.14)
			line.custom_minimum_size = Vector2(_loading_space(26, 52), maxf(1.0, _loading_scale()))
			row.add_child(line)
	return row


func _make_style(fill: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style


func _loading_font_px(minimum: int, maximum: int, vh_ratio: float) -> int:
	var ui_scale := _loading_scale()
	var scaled_size := float(maximum) * ui_scale
	var scaled_minimum := maxf(8.0, float(minimum) * minf(ui_scale, 1.0))
	var scaled_maximum := float(maximum) * maxf(ui_scale, 1.0)
	var height_size := get_viewport_rect().size.y * vh_ratio
	return roundi(clampf(minf(scaled_size, height_size), scaled_minimum, scaled_maximum))


func _loading_space(minimum: int, maximum: int) -> int:
	var ui_scale := _loading_scale()
	var scaled_minimum := maxf(1.0, float(minimum) * minf(ui_scale, 1.0))
	var scaled_maximum := float(maximum) * maxf(ui_scale, 1.0)
	return roundi(clampf(float(maximum) * ui_scale, scaled_minimum, scaled_maximum))


func _loading_vw(ratio: float, minimum: float, maximum: float) -> float:
	var ui_scale := _loading_scale()
	return clampf(get_viewport_rect().size.x * ratio, minimum * minf(ui_scale, 1.0), maximum * maxf(ui_scale, 1.0))


func _loading_scale() -> float:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return 1.0
	return clampf(
		minf(viewport_size.x / UI_REFERENCE_SIZE.x, viewport_size.y / UI_REFERENCE_SIZE.y),
		UI_MIN_SCALE,
		UI_MAX_SCALE
	)


func _selected_car_name() -> String:
	var session := get_node_or_null("/root/GameSession")
	if session != null and session.has_method("get_selected_car_option"):
		var car: Variant = session.call("get_selected_car_option")
		if car is Dictionary:
			var car_dict: Dictionary = car
			return str(car_dict.get("short_name", car_dict.get("display_name", "Apex GT")))
	return "Apex GT"


func _selected_track_name() -> String:
	var session := get_node_or_null("/root/GameSession")
	if session != null and session.has_method("get_selected_track_option"):
		var track: Variant = session.call("get_selected_track_option")
		if track is Dictionary:
			var track_dict: Dictionary = track
			return str(track_dict.get("short_name", track_dict.get("display_name", "Storm Coast")))
	return "Storm Coast"


func _selected_track_texture() -> Texture2D:
	var texture_path := MENU_BACKGROUND_TEXTURE_PATH
	var session := get_node_or_null("/root/GameSession")
	if session != null and session.has_method("get_selected_track_option"):
		var track: Variant = session.call("get_selected_track_option")
		if track is Dictionary:
			var track_dict: Dictionary = track
			texture_path = str(track_dict.get("preview_texture_path", texture_path))
	var texture := _load_texture_safely(texture_path)
	if texture == null:
		texture = _load_texture_safely(MENU_BACKGROUND_TEXTURE_PATH)
	return texture


func _load_texture_safely(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if FileAccess.file_exists("%s.import" % path):
		var imported_texture := load(path) as Texture2D
		if imported_texture != null:
			return imported_texture
	var image := Image.new()
	var error := image.load(ProjectSettings.globalize_path(path))
	if error != OK:
		return null
	return ImageTexture.create_from_image(image)
