extends Control

const CUSTOMIZE_SCENE_PATH: String = "res://scenes/ui/car_customize_menu.tscn"
const DEFAULT_TRACK_ID: String = "storm_coast"
const DEFAULT_TRACK_SCENE: String = "res://scenes/race/storm_coast_preview_race.tscn"
const MenuAudioControllerScript := preload("res://scripts/audio/menu_audio_controller.gd")
const MENU_BACKGROUND_TEXTURE: Texture2D = preload("res://assets/ui/menu_showroom_background.png")

const CAR_OPTIONS: Array[Dictionary] = [
	{
		"id": "apex_gt_blue",
		"name": "Apex GT Prototype",
		"class": "Prototype Hybrid",
		"finish": "Electric Blue",
		"color": Color(0.10, 0.42, 1.0, 1.0),
		"speed": 91,
		"grip": 82,
		"acceleration": 88,
	},
	{
		"id": "ion_r_repaint",
		"name": "Ion R Repaint",
		"class": "AI Livery Prototype",
		"finish": "Generated Paint",
		"color": Color(1.0, 0.12, 0.10, 1.0),
		"speed": 87,
		"grip": 76,
		"acceleration": 94,
	},
	{
		"id": "velocity_x_red",
		"name": "Velocity X",
		"class": "Endurance Special",
		"finish": "Red Metallic",
		"color": Color(0.92, 0.07, 0.04, 1.0),
		"speed": 84,
		"grip": 90,
		"acceleration": 80,
	},
]

const TRACK_OPTIONS: Array[Dictionary] = [
	{
		"id": "storm_coast",
		"name": "Storm Coast",
		"tag": "Coastal mountain road",
		"scene": "res://scenes/race/storm_coast_preview_race.tscn",
		"distance": "Preview loop",
		"mood": "Sun glare, ocean haze, elevation",
		"available": true,
	},
	{
		"id": "showcase_circuit",
		"name": "Showcase Circuit",
		"tag": "Closed proving ground",
		"scene": "res://scenes/race/showcase_circuit_race.tscn",
		"distance": "3 lap race",
		"mood": "Clean barriers, readable apexes",
		"available": true,
	},
	{
		"id": "industrial_run",
		"name": "Industrial Run",
		"tag": "Night factory belt",
		"scene": "",
		"distance": "Coming next",
		"mood": "Wet asphalt, sodium lights",
		"available": false,
	},
]

const DIFFICULTY_OPTIONS: Array[Dictionary] = [
	{"id": "easy", "name": "Easy", "description": "Forgiving rivals"},
	{"id": "medium", "name": "Medium", "description": "Balanced pressure"},
	{"id": "hard", "name": "Hard", "description": "Aggressive pace"},
]

var _home_view: Control = null
var _setup_view: Control = null
var _settings_view: Control = null
var _selection_label: Label = null
var _hero_car_name_label: Label = null
var _hero_track_label: Label = null
var _hero_difficulty_label: Label = null
var _hero_finish_swatch: ColorRect = null
var _volume_slider: HSlider = null
var _brightness_slider: HSlider = null
var _car_buttons: Dictionary = {}
var _track_buttons: Dictionary = {}
var _difficulty_buttons: Dictionary = {}
var _selected_car_id: String = "apex_gt_blue"
var _selected_track_id: String = DEFAULT_TRACK_ID
var _selected_difficulty_id: String = "medium"
var _menu_audio: Node = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_interface()
	call_deferred("_start_menu_audio")
	_sync_from_session()
	_show_view(_home_view)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_back()


func _build_interface() -> void:
	for child: Node in get_children():
		child.queue_free()

	_car_buttons.clear()
	_track_buttons.clear()
	_difficulty_buttons.clear()

	_add_background()

	var safe_area := MarginContainer.new()
	safe_area.name = "SafeArea"
	safe_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	safe_area.add_theme_constant_override("margin_left", 46)
	safe_area.add_theme_constant_override("margin_top", 34)
	safe_area.add_theme_constant_override("margin_right", 46)
	safe_area.add_theme_constant_override("margin_bottom", 34)
	add_child(safe_area)

	var layout := HBoxContainer.new()
	layout.name = "Layout"
	layout.add_theme_constant_override("separation", 34)
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	safe_area.add_child(layout)

	layout.add_child(_build_sidebar())

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


func _add_background() -> void:
	var base := ColorRect.new()
	base.name = "Background"
	base.color = Color(0.015, 0.018, 0.022, 1.0)
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(base)

	var showroom := TextureRect.new()
	showroom.name = "ShowroomBackground"
	showroom.texture = MENU_BACKGROUND_TEXTURE
	showroom.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	showroom.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	showroom.modulate = Color(0.9, 0.94, 1.0, 0.82)
	showroom.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(showroom)

	var shade := ColorRect.new()
	shade.name = "BackgroundShade"
	shade.color = Color(0.0, 0.0, 0.0, 0.48)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var asphalt_band := ColorRect.new()
	asphalt_band.name = "AsphaltBand"
	asphalt_band.color = Color(0.015, 0.018, 0.022, 0.72)
	asphalt_band.anchor_left = 0.50
	asphalt_band.anchor_top = -0.24
	asphalt_band.anchor_right = 0.77
	asphalt_band.anchor_bottom = 1.24
	asphalt_band.rotation_degrees = -10.0
	add_child(asphalt_band)

	var red_accent := ColorRect.new()
	red_accent.name = "RedAccent"
	red_accent.color = Color(0.92, 0.08, 0.11, 0.88)
	red_accent.anchor_left = 0.74
	red_accent.anchor_top = -0.24
	red_accent.anchor_right = 0.755
	red_accent.anchor_bottom = 1.24
	red_accent.rotation_degrees = -10.0
	add_child(red_accent)

	var cyan_accent := ColorRect.new()
	cyan_accent.name = "CyanAccent"
	cyan_accent.color = Color(0.0, 0.72, 1.0, 0.28)
	cyan_accent.anchor_left = 0.22
	cyan_accent.anchor_top = 0.90
	cyan_accent.anchor_right = 0.98
	cyan_accent.anchor_bottom = 0.915
	add_child(cyan_accent)


func _build_sidebar() -> VBoxContainer:
	var sidebar := VBoxContainer.new()
	sidebar.name = "Sidebar"
	sidebar.custom_minimum_size = Vector2(310, 0)
	sidebar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_theme_constant_override("separation", 12)

	var eyebrow := Label.new()
	eyebrow.name = "Eyebrow"
	eyebrow.text = "PROTOTYPE BUILD"
	eyebrow.add_theme_font_size_override("font_size", 13)
	eyebrow.add_theme_color_override("font_color", Color(0.44, 0.82, 1.0, 1.0))
	sidebar.add_child(eyebrow)

	var title := Label.new()
	title.name = "Title"
	title.text = "APEX\nDRIFT"
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", Color(0.96, 0.96, 0.91, 1.0))
	title.add_theme_constant_override("line_spacing", -3)
	sidebar.add_child(title)

	var subtitle := Label.new()
	subtitle.name = "Subtitle"
	subtitle.text = "Premium racing slice"
	subtitle.add_theme_font_size_override("font_size", 17)
	subtitle.add_theme_color_override("font_color", Color(0.66, 0.71, 0.76, 1.0))
	sidebar.add_child(subtitle)

	_add_spacer(sidebar, 20)
	sidebar.add_child(_make_nav_button("Start Race", Callable(self, "_start_race"), true))
	sidebar.add_child(_make_nav_button("Race Setup", Callable(self, "_show_setup")))
	sidebar.add_child(_make_nav_button("Garage / Customize", Callable(self, "_open_garage")))
	sidebar.add_child(_make_nav_button("Settings", Callable(self, "_show_settings")))
	sidebar.add_child(_make_nav_button("Quit", Callable(self, "_quit_game")))

	_add_spacer(sidebar, 14)
	var separator := HSeparator.new()
	separator.add_theme_color_override("separator", Color(1.0, 1.0, 1.0, 0.14))
	sidebar.add_child(separator)

	_selection_label = Label.new()
	_selection_label.name = "SelectionSummary"
	_selection_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_selection_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_selection_label.add_theme_font_size_override("font_size", 15)
	_selection_label.add_theme_color_override("font_color", Color(0.76, 0.80, 0.83, 1.0))
	sidebar.add_child(_selection_label)

	return sidebar


func _build_home_view() -> Control:
	var root := Control.new()
	root.name = "HomeView"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.name = "HeroPanel"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.055, 0.065, 0.078, 0.96), Color(1.0, 1.0, 1.0, 0.14), 1, 8))
	root.add_child(panel)

	var margin := MarginContainer.new()
	margin.name = "HeroMargin"
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_top", 34)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_bottom", 34)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.name = "HeroContent"
	content.add_theme_constant_override("separation", 18)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(content)

	var top_row := HBoxContainer.new()
	top_row.name = "TopRow"
	top_row.add_theme_constant_override("separation", 16)
	content.add_child(top_row)

	var heading_box := VBoxContainer.new()
	heading_box.name = "Heading"
	heading_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(heading_box)
	heading_box.add_child(_make_micro_label("SELECTED DRIVE"))
	_hero_car_name_label = _make_title_label("Apex R77")
	heading_box.add_child(_hero_car_name_label)
	_hero_track_label = _make_body_label("Storm Coast")
	heading_box.add_child(_hero_track_label)

	var launch_button := _make_nav_button("Launch", Callable(self, "_start_race"), true)
	launch_button.custom_minimum_size = Vector2(190, 52)
	top_row.add_child(launch_button)

	content.add_child(_build_car_showcase())

	var bottom_row := HBoxContainer.new()
	bottom_row.name = "BottomRow"
	bottom_row.add_theme_constant_override("separation", 16)
	content.add_child(bottom_row)
	bottom_row.add_child(_make_info_tile("Garage", "AI repaint and turntable preview", Callable(self, "_open_garage")))
	bottom_row.add_child(_make_info_tile("Race Setup", "Cars, tracks, NPC difficulty", Callable(self, "_show_setup")))
	bottom_row.add_child(_make_info_tile("Settings", "Volume and brightness", Callable(self, "_show_settings")))

	return root


func _build_car_showcase() -> PanelContainer:
	var stage := PanelContainer.new()
	stage.name = "CarShowcase"
	stage.custom_minimum_size = Vector2(0, 360)
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.add_theme_stylebox_override("panel", _make_panel_style(Color(0.02, 0.026, 0.034, 0.72), Color(1.0, 1.0, 1.0, 0.10), 1, 8))

	var margin := MarginContainer.new()
	margin.name = "StageMargin"
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_bottom", 24)
	stage.add_child(margin)

	var layout := HBoxContainer.new()
	layout.name = "StageLayout"
	layout.add_theme_constant_override("separation", 26)
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(layout)

	var visual := Control.new()
	visual.name = "VehicleSilhouette"
	visual.custom_minimum_size = Vector2(460, 260)
	visual.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	visual.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(visual)
	_add_silhouette_piece(visual, "Body", Color(0.08, 0.16, 0.25, 1.0), 0.10, 0.45, 0.88, 0.66)
	_add_silhouette_piece(visual, "Cabin", Color(0.70, 0.82, 0.88, 0.22), 0.36, 0.31, 0.67, 0.47)
	_add_silhouette_piece(visual, "Splitter", Color(0.0, 0.72, 1.0, 0.76), 0.08, 0.64, 0.92, 0.67)
	_add_silhouette_piece(visual, "RearWing", Color(0.92, 0.08, 0.11, 0.72), 0.70, 0.25, 0.96, 0.30)
	_add_silhouette_piece(visual, "FrontWheel", Color(0.01, 0.012, 0.014, 1.0), 0.22, 0.60, 0.34, 0.82)
	_add_silhouette_piece(visual, "RearWheel", Color(0.01, 0.012, 0.014, 1.0), 0.70, 0.60, 0.82, 0.82)

	var stats := VBoxContainer.new()
	stats.name = "Stats"
	stats.custom_minimum_size = Vector2(250, 0)
	stats.add_theme_constant_override("separation", 15)
	layout.add_child(stats)
	stats.add_child(_make_micro_label("PERFORMANCE"))
	stats.add_child(_make_stat_row("Speed", 91, Color(0.92, 0.08, 0.11, 1.0)))
	stats.add_child(_make_stat_row("Grip", 82, Color(0.0, 0.72, 1.0, 1.0)))
	stats.add_child(_make_stat_row("Launch", 88, Color(1.0, 0.74, 0.18, 1.0)))

	_hero_finish_swatch = ColorRect.new()
	_hero_finish_swatch.name = "FinishSwatch"
	_hero_finish_swatch.custom_minimum_size = Vector2(1, 16)
	stats.add_child(_hero_finish_swatch)

	_hero_difficulty_label = _make_body_label("NPC Difficulty: Medium")
	stats.add_child(_hero_difficulty_label)
	return stage


func _build_setup_view() -> Control:
	var root := Control.new()
	root.name = "SetupView"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.name = "SetupPanel"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.055, 0.065, 0.078, 0.96), Color(1.0, 1.0, 1.0, 0.14), 1, 8))
	root.add_child(panel)

	var margin := MarginContainer.new()
	margin.name = "SetupMargin"
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_bottom", 30)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.name = "SetupContent"
	content.add_theme_constant_override("separation", 18)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(content)

	content.add_child(_make_micro_label("RACE SETUP"))
	content.add_child(_make_title_label("Choose car, track, and rival pressure"))

	var columns := HBoxContainer.new()
	columns.name = "SetupColumns"
	columns.add_theme_constant_override("separation", 18)
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(columns)

	columns.add_child(_build_car_picker())
	columns.add_child(_build_track_picker())
	columns.add_child(_build_difficulty_picker())

	var action_row := HBoxContainer.new()
	action_row.name = "ActionRow"
	action_row.add_theme_constant_override("separation", 12)
	content.add_child(action_row)
	action_row.add_child(_make_nav_button("Back", Callable(self, "_show_home")))
	action_row.add_child(_make_nav_button("Garage", Callable(self, "_open_garage")))
	action_row.add_child(_make_nav_button("Start Race", Callable(self, "_start_race"), true))

	return root


func _build_car_picker() -> VBoxContainer:
	var box := _make_column("Car")
	for option: Dictionary in CAR_OPTIONS:
		var button := _make_option_button(str(option["name"]), "%s  /  %s" % [str(option["class"]), str(option["finish"])])
		button.pressed.connect(Callable(self, "_select_car").bind(str(option["id"])))
		_car_buttons[str(option["id"])] = button
		box.add_child(button)
	return box


func _build_track_picker() -> VBoxContainer:
	var box := _make_column("Track")
	for option: Dictionary in TRACK_OPTIONS:
		var detail := "%s  /  %s" % [str(option["tag"]), str(option["distance"])]
		var button := _make_option_button(str(option["name"]), detail, not bool(option["available"]))
		button.tooltip_text = str(option["mood"])
		if bool(option["available"]):
			button.pressed.connect(Callable(self, "_select_track").bind(str(option["id"])))
		_track_buttons[str(option["id"])] = button
		box.add_child(button)
	return box


func _build_difficulty_picker() -> VBoxContainer:
	var box := _make_column("NPC Difficulty")
	for option: Dictionary in DIFFICULTY_OPTIONS:
		var button := _make_option_button(str(option["name"]), str(option["description"]))
		button.pressed.connect(Callable(self, "_select_difficulty").bind(str(option["id"])))
		_difficulty_buttons[str(option["id"])] = button
		box.add_child(button)
	return box


func _build_settings_view() -> Control:
	var root := Control.new()
	root.name = "SettingsView"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.name = "SettingsPanel"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.055, 0.065, 0.078, 0.96), Color(1.0, 1.0, 1.0, 0.14), 1, 8))
	root.add_child(panel)

	var margin := MarginContainer.new()
	margin.name = "SettingsMargin"
	margin.add_theme_constant_override("margin_left", 38)
	margin.add_theme_constant_override("margin_top", 34)
	margin.add_theme_constant_override("margin_right", 38)
	margin.add_theme_constant_override("margin_bottom", 34)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.name = "SettingsContent"
	content.add_theme_constant_override("separation", 18)
	margin.add_child(content)
	content.add_child(_make_micro_label("SETTINGS"))
	content.add_child(_make_title_label("Audio and display"))

	content.add_child(_make_section_label("Master Volume"))
	_volume_slider = _make_slider(0.0, 1.0, 0.01)
	_volume_slider.value_changed.connect(Callable(self, "_on_volume_changed"))
	content.add_child(_volume_slider)

	content.add_child(_make_section_label("Brightness"))
	_brightness_slider = _make_slider(0.65, 1.35, 0.01)
	_brightness_slider.value_changed.connect(Callable(self, "_on_brightness_changed"))
	content.add_child(_brightness_slider)

	_add_spacer(content, 18)
	content.add_child(_make_nav_button("Back", Callable(self, "_show_home")))
	return root


func _make_column(title: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = "%sColumn" % title.replace(" ", "")
	box.custom_minimum_size = Vector2(230, 0)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	box.add_child(_make_section_label(title))
	return box


func _make_info_tile(title: String, body: String, callback: Callable) -> Button:
	var button := Button.new()
	button.name = "%sTile" % title.replace(" ", "")
	button.text = "%s\n%s" % [title.to_upper(), body]
	button.custom_minimum_size = Vector2(190, 96)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size", 15)
	_apply_button_style(button, false)
	button.pressed.connect(callback)
	return button


func _make_nav_button(text: String, callback: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(180, 48)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 17)
	_apply_button_style(button, primary)
	button.pressed.connect(callback)
	return button


func _make_option_button(title: String, subtitle: String, locked: bool = false) -> Button:
	var button := Button.new()
	button.toggle_mode = true
	button.text = "%s\n%s" % [title, subtitle]
	button.custom_minimum_size = Vector2(220, 76)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size", 15)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_button_style(button, false)
	if locked:
		button.text = "%s\nLOCKED - %s" % [title, subtitle]
		button.disabled = true
	return button


func _make_micro_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.48, 0.82, 1.0, 1.0))
	return label


func _make_title_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 34)
	label.add_theme_color_override("font_color", Color(0.96, 0.96, 0.91, 1.0))
	return label


func _make_body_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", Color(0.72, 0.76, 0.80, 1.0))
	return label


func _make_section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text.to_upper()
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.96, 0.96, 0.91, 1.0))
	return label


func _make_stat_row(label_text: String, value: int, accent: Color) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = "%sStat" % label_text
	box.add_theme_constant_override("separation", 5)

	var label := Label.new()
	label.text = "%s  %d" % [label_text.to_upper(), value]
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.86, 0.88, 0.88, 1.0))
	box.add_child(label)

	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = value
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(1, 9)
	bar.add_theme_stylebox_override("background", _make_panel_style(Color(0.18, 0.19, 0.21, 1.0), Color.TRANSPARENT, 0, 3))
	bar.add_theme_stylebox_override("fill", _make_panel_style(accent, accent, 0, 3))
	box.add_child(bar)
	return box


func _make_slider(minimum: float, maximum: float, step: float) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.custom_minimum_size = Vector2(360, 38)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return slider


func _apply_button_style(button: Button, primary: bool) -> void:
	var normal_fill: Color = Color(0.09, 0.105, 0.125, 0.95)
	var hover_fill: Color = Color(0.13, 0.155, 0.18, 1.0)
	var pressed_fill: Color = Color(0.17, 0.19, 0.21, 1.0)
	var border: Color = Color(1.0, 1.0, 1.0, 0.20)
	var font_color: Color = Color(0.91, 0.92, 0.90, 1.0)
	if primary:
		normal_fill = Color(0.92, 0.08, 0.13, 1.0)
		hover_fill = Color(1.0, 0.15, 0.22, 1.0)
		pressed_fill = Color(0.72, 0.04, 0.08, 1.0)
		border = Color(1.0, 0.78, 0.70, 0.55)
		font_color = Color(1.0, 0.98, 0.93, 1.0)
	button.add_theme_stylebox_override("normal", _make_panel_style(normal_fill, border, 1, 6))
	button.add_theme_stylebox_override("hover", _make_panel_style(hover_fill, Color(0.44, 0.82, 1.0, 0.55), 1, 6))
	button.add_theme_stylebox_override("pressed", _make_panel_style(pressed_fill, Color(0.44, 0.82, 1.0, 0.75), 1, 6))
	button.add_theme_stylebox_override("focus", _make_panel_style(Color.TRANSPARENT, Color(0.44, 0.82, 1.0, 0.95), 2, 6))
	button.add_theme_stylebox_override("disabled", _make_panel_style(Color(0.05, 0.055, 0.064, 0.82), Color(1.0, 1.0, 1.0, 0.08), 1, 6))
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.48, 0.50, 0.52, 1.0))


func _make_panel_style(fill: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _add_silhouette_piece(parent: Control, piece_name: String, color: Color, left: float, top: float, right: float, bottom: float) -> void:
	var piece := ColorRect.new()
	piece.name = piece_name
	piece.color = color
	piece.anchor_left = left
	piece.anchor_top = top
	piece.anchor_right = right
	piece.anchor_bottom = bottom
	parent.add_child(piece)


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
	if session != null:
		if session.has_method("get_car_id"):
			_selected_car_id = _call_string(session, "get_car_id", _selected_car_id)
		elif session.has_method("get_car_color"):
			_selected_car_id = _call_string(session, "get_car_color", _selected_car_id)
		_selected_difficulty_id = _call_string(session, "get_difficulty", _selected_difficulty_id)
		if session.has_method("get_track_id"):
			var session_track_id: String = str(session.call("get_track_id"))
			if _find_track_option(session_track_id).size() > 0:
				_selected_track_id = session_track_id
		if _volume_slider != null and session.has_method("get_master_volume"):
			_volume_slider.set_value_no_signal(float(session.call("get_master_volume")))
		if _brightness_slider != null and session.has_method("get_brightness"):
			_brightness_slider.set_value_no_signal(float(session.call("get_brightness")))

	_sync_buttons()
	_sync_summary()


func _sync_buttons() -> void:
	for car_id: String in _car_buttons.keys():
		var button: Button = _car_buttons[car_id]
		button.button_pressed = car_id == _selected_car_id
	for track_id: String in _track_buttons.keys():
		var button: Button = _track_buttons[track_id]
		button.button_pressed = track_id == _selected_track_id
	for difficulty_id: String in _difficulty_buttons.keys():
		var button: Button = _difficulty_buttons[difficulty_id]
		button.button_pressed = difficulty_id == _selected_difficulty_id


func _sync_summary() -> void:
	var car := _find_car_option(_selected_car_id)
	var track := _find_track_option(_selected_track_id)
	var difficulty := _find_difficulty_option(_selected_difficulty_id)
	if car.is_empty():
		car = CAR_OPTIONS[0]
	if track.is_empty():
		track = TRACK_OPTIONS[0]
	if difficulty.is_empty():
		difficulty = DIFFICULTY_OPTIONS[1]

	if _selection_label != null:
		_selection_label.text = "Car: %s\nFinish: %s\nTrack: %s\nNPCs: %s" % [
			str(car["name"]),
			str(car["finish"]),
			str(track["name"]),
			str(difficulty["name"]),
		]
	if _hero_car_name_label != null:
		_hero_car_name_label.text = str(car["name"])
	if _hero_track_label != null:
		_hero_track_label.text = "%s  /  %s" % [str(track["name"]), str(track["mood"])]
	if _hero_difficulty_label != null:
		_hero_difficulty_label.text = "NPC Difficulty: %s" % str(difficulty["name"])
	if _hero_finish_swatch != null:
		_hero_finish_swatch.color = car["color"]


func _select_car(car_id: String) -> void:
	if _find_car_option(car_id).is_empty():
		return
	_selected_car_id = car_id
	var session: Node = _session()
	if session != null and session.has_method("set_car"):
		session.call("set_car", StringName(car_id))
	elif session != null and session.has_method("set_car_color"):
		session.call("set_car_color", _car_color_for_id(car_id))
	_sync_from_session()


func _select_track(track_id: String) -> void:
	var track := _find_track_option(track_id)
	if track.is_empty() or not bool(track["available"]):
		return
	_selected_track_id = track_id
	var session: Node = _session()
	if session != null and session.has_method("set_track"):
		session.call("set_track", StringName(track_id), str(track["scene"]))
	_sync_from_session()


func _select_difficulty(difficulty_id: String) -> void:
	if _find_difficulty_option(difficulty_id).is_empty():
		return
	_selected_difficulty_id = difficulty_id
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
	var race_scene_path: String = _selected_track_scene_path()
	var session: Node = _session()
	if session != null:
		var track := _find_track_option(_selected_track_id)
		if not track.is_empty() and session.has_method("set_track"):
			session.call("set_track", StringName(_selected_track_id), str(track["scene"]))
		if session.has_method("get_track_scene_path"):
			race_scene_path = str(session.call("get_track_scene_path"))
	if race_scene_path.is_empty():
		race_scene_path = DEFAULT_TRACK_SCENE
	_stop_menu_audio(0.25)
	get_tree().change_scene_to_file(race_scene_path)


func _open_garage() -> void:
	_stop_menu_audio(0.15)
	get_tree().change_scene_to_file(CUSTOMIZE_SCENE_PATH)


func _quit_game() -> void:
	get_tree().quit()


func _go_back() -> void:
	if _home_view != null and _home_view.visible:
		return
	_show_home()


func _selected_track_scene_path() -> String:
	var track := _find_track_option(_selected_track_id)
	if track.is_empty() or str(track["scene"]).is_empty():
		return DEFAULT_TRACK_SCENE
	return str(track["scene"])


func _find_car_option(car_id: String) -> Dictionary:
	for option: Dictionary in CAR_OPTIONS:
		if str(option["id"]) == car_id:
			return option
	return {}


func _car_color_for_id(car_id: String) -> String:
	match car_id:
		"ion_r_repaint":
			return "red"
		"velocity_x_red":
			return "yellow"
		_:
			return "blue"


func _find_track_option(track_id: String) -> Dictionary:
	for option: Dictionary in TRACK_OPTIONS:
		if str(option["id"]) == track_id:
			return option
	return {}


func _find_difficulty_option(difficulty_id: String) -> Dictionary:
	for option: Dictionary in DIFFICULTY_OPTIONS:
		if str(option["id"]) == difficulty_id:
			return option
	return {}


func _session() -> Node:
	return get_node_or_null("/root/GameSession")


func _call_string(target: Node, method_name: String, fallback: String) -> String:
	if target == null or not target.has_method(method_name):
		return fallback
	return str(target.call(method_name))


func _start_menu_audio() -> void:
	_menu_audio = MenuAudioControllerScript.resolve(self)
	if _menu_audio == null:
		return
	if _menu_audio.has_method("play_menu_music"):
		_menu_audio.call("play_menu_music")
	if _menu_audio.has_method("bind_buttons"):
		_menu_audio.call("bind_buttons", self)


func _stop_menu_audio(fade_seconds: float) -> void:
	if _menu_audio == null:
		return
	if _menu_audio.has_method("stop_menu_music"):
		_menu_audio.call("stop_menu_music", fade_seconds)
