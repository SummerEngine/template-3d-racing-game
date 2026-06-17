extends Control

const SHOWCASE_TRACK_ID: StringName = &"showcase_circuit"
const SHOWCASE_TRACK_SCENE: String = "res://scenes/race/showcase_circuit_race.tscn"

const COLOR_OPTIONS: Array[Dictionary] = [
	{"id": "blue", "label": "Blue", "color": Color(0.13, 0.46, 1.0, 1.0)},
	{"id": "red", "label": "Red", "color": Color(1.0, 0.18, 0.14, 1.0)},
	{"id": "green", "label": "Green", "color": Color(0.18, 0.78, 0.34, 1.0)},
	{"id": "yellow", "label": "Yellow", "color": Color(1.0, 0.78, 0.13, 1.0)},
]

const DIFFICULTY_OPTIONS: Array[Dictionary] = [
	{"id": "easy", "label": "Easy"},
	{"id": "medium", "label": "Medium"},
	{"id": "hard", "label": "Hard"},
]

var _home_view: Control = null
var _setup_view: Control = null
var _settings_view: Control = null
var _color_buttons: Dictionary = {}
var _difficulty_buttons: Dictionary = {}
var _volume_slider: HSlider = null
var _brightness_slider: HSlider = null
var _selection_label: Label = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_interface()
	_sync_from_session()
	_show_view(_home_view)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_back()


func _build_interface() -> void:
	for child: Node in get_children():
		child.queue_free()

	var background := ColorRect.new()
	background.name = "Background"
	background.color = Color(0.10, 0.12, 0.13, 1.0)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var road_band := ColorRect.new()
	road_band.name = "RoadBand"
	road_band.color = Color(0.03, 0.035, 0.04, 1.0)
	road_band.anchor_left = 0.52
	road_band.anchor_top = -0.2
	road_band.anchor_right = 0.72
	road_band.anchor_bottom = 1.2
	road_band.rotation_degrees = -9.0
	add_child(road_band)

	var accent_band := ColorRect.new()
	accent_band.name = "AccentBand"
	accent_band.color = Color(1.0, 0.72, 0.10, 1.0)
	accent_band.anchor_left = 0.66
	accent_band.anchor_top = -0.2
	accent_band.anchor_right = 0.675
	accent_band.anchor_bottom = 1.2
	accent_band.rotation_degrees = -9.0
	add_child(accent_band)

	var margin := MarginContainer.new()
	margin.name = "SafeArea"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 54)
	margin.add_theme_constant_override("margin_top", 42)
	margin.add_theme_constant_override("margin_right", 54)
	margin.add_theme_constant_override("margin_bottom", 42)
	add_child(margin)

	var layout := HBoxContainer.new()
	layout.name = "Layout"
	layout.add_theme_constant_override("separation", 42)
	margin.add_child(layout)

	var sidebar := VBoxContainer.new()
	sidebar.name = "Sidebar"
	sidebar.custom_minimum_size = Vector2(310, 0)
	sidebar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_theme_constant_override("separation", 18)
	layout.add_child(sidebar)

	var title := Label.new()
	title.name = "Title"
	title.text = "Arcade Drift"
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0, 1.0))
	sidebar.add_child(title)

	var subtitle := Label.new()
	subtitle.name = "Subtitle"
	subtitle.text = "Showcase Circuit"
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.68, 0.77, 0.83, 1.0))
	sidebar.add_child(subtitle)

	_add_spacer(sidebar, 16)
	sidebar.add_child(_make_button("New Race", Callable(self, "_show_setup")))
	sidebar.add_child(_make_button("Settings", Callable(self, "_show_settings")))
	sidebar.add_child(_make_button("Quit", Callable(self, "_quit_game")))

	_selection_label = Label.new()
	_selection_label.name = "SelectionSummary"
	_selection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_selection_label.add_theme_font_size_override("font_size", 16)
	_selection_label.add_theme_color_override("font_color", Color(0.78, 0.84, 0.86, 1.0))
	_selection_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_child(_selection_label)

	var view_host := Control.new()
	view_host.name = "ViewHost"
	view_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(view_host)

	_home_view = _build_home_view()
	_setup_view = _build_setup_view()
	_settings_view = _build_settings_view()
	view_host.add_child(_home_view)
	view_host.add_child(_setup_view)
	view_host.add_child(_settings_view)


func _build_home_view() -> Control:
	var panel := _make_panel("HomeView")
	var box := _make_panel_box(panel)
	box.add_child(_make_heading("3 laps. Four cars. One readable, toy-like drift slice."))
	box.add_child(_make_body_label("A focused vertical slice built for feel first: road preview, quick recovery, readable rivals, and bright contact feedback."))
	_add_spacer(box, 18)
	box.add_child(_make_button("Set Up Race", Callable(self, "_show_setup")))
	return panel


func _build_setup_view() -> Control:
	var panel := _make_panel("SetupView")
	var box := _make_panel_box(panel)
	box.add_child(_make_heading("New Race"))

	box.add_child(_make_section_label("Car Color"))
	var color_grid := GridContainer.new()
	color_grid.name = "ColorGrid"
	color_grid.columns = 2
	color_grid.add_theme_constant_override("h_separation", 12)
	color_grid.add_theme_constant_override("v_separation", 12)
	box.add_child(color_grid)
	for option: Dictionary in COLOR_OPTIONS:
		color_grid.add_child(_make_color_option(option))

	box.add_child(_make_section_label("Circuit"))
	var track_button := _make_toggle_button("Showcase Circuit", true)
	track_button.disabled = true
	box.add_child(track_button)

	box.add_child(_make_section_label("Difficulty"))
	var difficulty_row := HBoxContainer.new()
	difficulty_row.name = "DifficultyRow"
	difficulty_row.add_theme_constant_override("separation", 12)
	box.add_child(difficulty_row)
	for option: Dictionary in DIFFICULTY_OPTIONS:
		var button := _make_toggle_button(str(option["label"]), false)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(Callable(self, "_select_difficulty").bind(str(option["id"])))
		_difficulty_buttons[str(option["id"])] = button
		difficulty_row.add_child(button)

	_add_spacer(box, 14)
	var action_row := HBoxContainer.new()
	action_row.name = "ActionRow"
	action_row.add_theme_constant_override("separation", 12)
	box.add_child(action_row)
	action_row.add_child(_make_button("Back", Callable(self, "_show_home")))
	action_row.add_child(_make_button("Start Race", Callable(self, "_start_race"), true))
	return panel


func _build_settings_view() -> Control:
	var panel := _make_panel("SettingsView")
	var box := _make_panel_box(panel)
	box.add_child(_make_heading("Settings"))
	box.add_child(_make_section_label("Volume"))
	_volume_slider = _make_slider(0.0, 1.0, 0.01)
	_volume_slider.value_changed.connect(Callable(self, "_on_volume_changed"))
	box.add_child(_volume_slider)

	box.add_child(_make_section_label("Brightness"))
	_brightness_slider = _make_slider(0.65, 1.35, 0.01)
	_brightness_slider.value_changed.connect(Callable(self, "_on_brightness_changed"))
	box.add_child(_brightness_slider)

	_add_spacer(box, 20)
	box.add_child(_make_button("Back", Callable(self, "_show_home")))
	return panel


func _make_panel(panel_name: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = panel_name
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", _make_style(Color(0.93, 0.96, 0.96, 0.95), Color(0.08, 0.11, 0.12, 1.0), 2, 8))
	return panel


func _make_panel_box(panel: PanelContainer) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.name = "Content"
	box.add_theme_constant_override("separation", 14)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(box)
	return box


func _make_heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(0.08, 0.11, 0.12, 1.0))
	return label


func _make_body_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.25, 0.31, 0.34, 1.0))
	return label


func _make_section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", Color(0.17, 0.22, 0.24, 1.0))
	return label


func _make_color_option(option: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Color%s" % str(option["label"])
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var swatch := ColorRect.new()
	swatch.name = "Swatch"
	swatch.color = option["color"]
	swatch.custom_minimum_size = Vector2(34, 34)
	row.add_child(swatch)

	var button := _make_toggle_button(str(option["label"]), false)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(Callable(self, "_select_color").bind(str(option["id"])))
	_color_buttons[str(option["id"])] = button
	row.add_child(button)
	return row


func _make_button(text: String, callback: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(180, 44)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 18)
	if primary:
		button.add_theme_stylebox_override("normal", _make_style(Color(1.0, 0.72, 0.1, 1.0), Color(0.08, 0.09, 0.09, 1.0), 2, 8))
		button.add_theme_color_override("font_color", Color(0.06, 0.07, 0.07, 1.0))
	button.pressed.connect(callback)
	return button


func _make_toggle_button(text: String, pressed: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.button_pressed = pressed
	button.custom_minimum_size = Vector2(120, 40)
	button.add_theme_font_size_override("font_size", 16)
	return button


func _make_slider(minimum: float, maximum: float, step: float) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.custom_minimum_size = Vector2(320, 36)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return slider


func _make_style(fill: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style


func _add_spacer(parent: Node, height: float) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(1, height)
	parent.add_child(spacer)


func _show_home() -> void:
	_show_view(_home_view)


func _show_setup() -> void:
	_show_view(_setup_view)


func _show_settings() -> void:
	_show_view(_settings_view)


func _show_view(view: Control) -> void:
	for candidate: Control in [_home_view, _setup_view, _settings_view]:
		if candidate != null:
			candidate.visible = candidate == view
	_sync_from_session()


func _sync_from_session() -> void:
	var session: Node = _session()
	if session == null:
		return
	var selected_color: String = _call_string(session, "get_car_color", "blue")
	var selected_difficulty: String = _call_string(session, "get_difficulty", "medium")

	for color_id: String in _color_buttons.keys():
		var button: Button = _color_buttons[color_id]
		button.button_pressed = color_id == selected_color
	for difficulty_id: String in _difficulty_buttons.keys():
		var button: Button = _difficulty_buttons[difficulty_id]
		button.button_pressed = difficulty_id == selected_difficulty
	if _volume_slider != null and session.has_method("get_master_volume"):
		_volume_slider.value = float(session.call("get_master_volume"))
	if _brightness_slider != null and session.has_method("get_brightness"):
		_brightness_slider.value = float(session.call("get_brightness"))
	if _selection_label != null:
		_selection_label.text = "Car %s\nDifficulty %s" % [selected_color.capitalize(), selected_difficulty.capitalize()]


func _select_color(color_id: String) -> void:
	var session: Node = _session()
	if session != null and session.has_method("set_car_color"):
		session.call("set_car_color", color_id)
	_sync_from_session()


func _select_difficulty(difficulty_id: String) -> void:
	var session: Node = _session()
	if session != null and session.has_method("set_difficulty"):
		session.call("set_difficulty", difficulty_id)
	_sync_from_session()


func _on_volume_changed(value: float) -> void:
	var session: Node = _session()
	if session != null and session.has_method("set_master_volume"):
		session.call("set_master_volume", value)


func _on_brightness_changed(value: float) -> void:
	var session: Node = _session()
	if session != null and session.has_method("set_brightness"):
		session.call("set_brightness", value)


func _start_race() -> void:
	var session: Node = _session()
	var race_scene_path: String = SHOWCASE_TRACK_SCENE
	if session != null:
		if session.has_method("set_track"):
			session.call("set_track", SHOWCASE_TRACK_ID, SHOWCASE_TRACK_SCENE)
		if session.has_method("get_track_scene_path"):
			race_scene_path = str(session.call("get_track_scene_path"))
	get_tree().change_scene_to_file(race_scene_path)


func _quit_game() -> void:
	get_tree().quit()


func _go_back() -> void:
	if _home_view != null and _home_view.visible:
		return
	_show_home()


func _session() -> Node:
	return get_node_or_null("/root/GameSession")


func _call_string(target: Node, method_name: String, fallback: String) -> String:
	if target == null or not target.has_method(method_name):
		return fallback
	return str(target.call(method_name))
