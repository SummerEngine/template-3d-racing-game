extends Control

const RACE_LOADING_SCENE_PATH: String = "res://scenes/ui/race_loading.tscn"
const MENU_AUDIO_CONTROLLER_SCRIPT_PATH: String = "res://scripts/audio/menu_audio_controller.gd"
const MENU_BACKGROUND_TEXTURE_PATH: String = "res://assets/ui/menu_showroom_background.png"
const DEFAULT_CAR_CARD_TEXTURE_PATH: String = MENU_BACKGROUND_TEXTURE_PATH

const VIEW_HOME: StringName = &"home"
const VIEW_CAR_SELECT: StringName = &"car_select"
const VIEW_TRACK_SELECT: StringName = &"track_select"
const STAT_ORDER: Array[String] = ["speed", "launch", "braking", "cornering"]
const STAT_LABELS: Dictionary = {
	"speed": "Top Speed",
	"launch": "Launch",
	"braking": "Braking",
	"cornering": "Cornering",
}
const STAT_COLORS: Dictionary = {
	"speed": Color(0.92, 0.08, 0.13, 1.0),
	"launch": Color(1.0, 0.72, 0.18, 1.0),
	"braking": Color(0.12, 0.74, 1.0, 1.0),
	"cornering": Color(0.12, 0.84, 0.42, 1.0),
}
const CHOICE_CARD_SIDE_RATIO: float = 0.10
const CARD_SCROLL_TWEEN_SECONDS: float = 0.24
const PREVIEW_CAMERA_ELEVATION_DEGREES: float = 45.0
const PREVIEW_CAMERA_DISTANCE: float = 7.4
const COLOR_PANEL_DARK: Color = Color(0.020, 0.024, 0.031, 0.92)
const COLOR_PANEL_LIGHT: Color = Color(0.055, 0.064, 0.078, 0.86)
const COLOR_RACING_RED: Color = Color(0.92, 0.04, 0.10, 1.0)
const COLOR_RACING_RED_HOVER: Color = Color(1.0, 0.14, 0.18, 1.0)
const COLOR_RACING_BLUE: Color = Color(0.36, 0.82, 1.0, 1.0)
const COLOR_TEXT_MAIN: Color = Color(0.96, 0.97, 0.93, 1.0)
const COLOR_TEXT_MUTED: Color = Color(0.74, 0.77, 0.78, 1.0)

var _active_view: StringName = VIEW_HOME
var _settings_visible: bool = false
var _selected_car_id: StringName = &""
var _selected_skin_id: StringName = &""
var _selected_track_id: StringName = &""
var _preview_car_id: StringName = &""
var _preview_track_id: StringName = &""
var _selected_difficulty_id: String = "medium"
var _menu_audio: Node = null
var _menu_background_texture: Texture2D = null
var _car_card_texture: Texture2D = null
var _rebuild_queued: bool = false

var _home_view: Control = null
var _car_select_view: Control = null
var _track_select_view: Control = null
var _settings_panel: Control = null
var _master_slider: HSlider = null
var _music_slider: HSlider = null
var _sfx_slider: HSlider = null
var _brightness_slider: HSlider = null
var _master_value_label: Label = null
var _music_value_label: Label = null
var _sfx_value_label: Label = null
var _brightness_value_label: Label = null
var _car_name_label: Label = null
var _car_class_label: Label = null
var _car_description_label: Label = null
var _track_name_label: Label = null
var _track_description_label: Label = null
var _track_meta_label: Label = null
var _track_preview_texture_rect: TextureRect = null
var _preview_subviewport: SubViewport = null
var _preview_turntable: Node3D = null
var _preview_car_mount: Node3D = null
var _preview_camera: Camera3D = null
var _preview_dragging: bool = false
var _preview_last_mouse: Vector2 = Vector2.ZERO
var _car_cards_scroll: ScrollContainer = null
var _track_cards_scroll: ScrollContainer = null
var _car_cards_scroll_tween: Tween = null
var _track_cards_scroll_tween: Tween = null
var _car_cards_leading_spacer: Control = null
var _car_cards_trailing_spacer: Control = null
var _track_cards_leading_spacer: Control = null
var _track_cards_trailing_spacer: Control = null
var _car_prev_button: Button = null
var _car_next_button: Button = null
var _track_prev_button: Button = null
var _track_next_button: Button = null
var _car_buttons: Dictionary = {}
var _skin_buttons: Dictionary = {}
var _track_buttons: Dictionary = {}
var _difficulty_buttons: Dictionary = {}
var _car_stat_labels: Dictionary = {}
var _car_stat_bars: Dictionary = {}
var _car_preview_scene_cache: Dictionary = {}
var _difficulty_description_label: Label = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_sync_from_session()
	_build_interface()
	call_deferred("_start_menu_audio")


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_inside_tree():
		_queue_rebuild()
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_back()


func _build_interface() -> void:
	_kill_card_scroll_tweens()
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_car_buttons.clear()
	_skin_buttons.clear()
	_track_buttons.clear()
	_difficulty_buttons.clear()
	_car_stat_labels.clear()
	_car_stat_bars.clear()
	_track_preview_texture_rect = null
	_difficulty_description_label = null

	_add_background()

	_home_view = _build_home_view()
	_car_select_view = _build_car_select_view()
	_track_select_view = _build_track_select_view()
	add_child(_home_view)
	add_child(_car_select_view)
	add_child(_track_select_view)

	_show_view(_active_view, false)
	_sync_all_ui()
	call_deferred("_bind_menu_audio")


func _add_background() -> void:
	var base := ColorRect.new()
	base.name = "Background"
	base.color = Color(0.012, 0.014, 0.017, 1.0)
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(base)

	var texture := TextureRect.new()
	texture.name = "ShowroomBackground"
	texture.texture = _get_menu_background_texture()
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	texture.modulate = Color(0.88, 0.92, 1.0, 0.82)
	texture.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(texture)

	var shade := ColorRect.new()
	shade.name = "CinematicScrim"
	shade.color = Color(0.0, 0.0, 0.0, 0.56)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var left_vignette := ColorRect.new()
	left_vignette.name = "LeftVignette"
	left_vignette.color = Color(0.0, 0.0, 0.0, 0.34)
	left_vignette.anchor_left = 0.0
	left_vignette.anchor_top = 0.0
	left_vignette.anchor_right = 0.38
	left_vignette.anchor_bottom = 1.0
	add_child(left_vignette)

	var bottom_strip := ColorRect.new()
	bottom_strip.name = "BottomRedAccent"
	bottom_strip.color = Color(0.88, 0.02, 0.08, 0.30)
	bottom_strip.anchor_left = 0.0
	bottom_strip.anchor_top = 1.0
	bottom_strip.anchor_right = 1.0
	bottom_strip.anchor_bottom = 1.0
	bottom_strip.offset_top = -_space(4, 8)
	add_child(bottom_strip)


func _build_home_view() -> Control:
	var root := Control.new()
	root.name = "Home"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_make_home_background_overlay())

	var center := CenterContainer.new()
	center.name = "HomeCenter"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var actions := VBoxContainer.new()
	actions.name = "HomePrimaryStack"
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.custom_minimum_size = Vector2(_vw(0.43, 520.0, 820.0), 0.0)
	actions.add_theme_constant_override("separation", _space(14, 24))
	center.add_child(actions)

	actions.add_child(_make_home_eyebrow())
	actions.add_child(_make_home_brand())

	var subtitle := _make_label("PUSH BEYOND THE LIMIT", _font_px(12, 18, 0.016), Color(0.52, 0.50, 0.66, 1.0), false)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	actions.add_child(subtitle)

	var button_gap := Control.new()
	button_gap.custom_minimum_size = Vector2(1.0, _space(24, 42))
	actions.add_child(button_gap)

	var start_button := _make_button("START RACE", true, _font_px(19, 28, 0.026), _vh(0.070, 58.0, 78.0))
	start_button.custom_minimum_size.x = _vw(0.24, 320.0, 460.0)
	start_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start_button.pressed.connect(Callable(self, "_show_car_select"))
	actions.add_child(start_button)

	var settings_button := _make_home_settings_button()
	settings_button.pressed.connect(Callable(self, "_toggle_settings"))
	actions.add_child(settings_button)

	_settings_panel = _build_settings_panel()
	_settings_panel.visible = _settings_visible
	_settings_panel.anchor_left = 0.70
	_settings_panel.anchor_top = 0.20
	_settings_panel.anchor_right = 0.96
	_settings_panel.anchor_bottom = 0.88
	_settings_panel.offset_left = 0.0
	_settings_panel.offset_top = 0.0
	_settings_panel.offset_right = 0.0
	_settings_panel.offset_bottom = 0.0
	root.add_child(_settings_panel)
	return root


func _make_home_background_overlay() -> Control:
	var overlay := Control.new()
	overlay.name = "HomeFigmaOverlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)

	var dark := ColorRect.new()
	dark.name = "DarkGridBase"
	dark.color = Color(0.006, 0.007, 0.011, 0.94)
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dark)

	var red_core := ColorRect.new()
	red_core.name = "RedCoreGlow"
	red_core.color = Color(0.22, 0.0, 0.035, 0.045)
	red_core.mouse_filter = Control.MOUSE_FILTER_IGNORE
	red_core.anchor_left = 0.22
	red_core.anchor_top = 0.26
	red_core.anchor_right = 0.78
	red_core.anchor_bottom = 0.62
	overlay.add_child(red_core)

	for index: int in range(1, 16):
		var line := ColorRect.new()
		line.name = "VerticalGridLine"
		line.color = Color(1.0, 0.05, 0.12, 0.045)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ratio := float(index) / 16.0
		line.anchor_left = ratio
		line.anchor_right = ratio
		line.anchor_top = 0.0
		line.anchor_bottom = 1.0
		line.offset_right = 1.0
		overlay.add_child(line)

	for index: int in range(1, 10):
		var line := ColorRect.new()
		line.name = "HorizontalGridLine"
		line.color = Color(1.0, 0.05, 0.12, 0.040)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ratio := float(index) / 10.0
		line.anchor_left = 0.0
		line.anchor_right = 1.0
		line.anchor_top = ratio
		line.anchor_bottom = ratio
		line.offset_bottom = 1.0
		overlay.add_child(line)

	return overlay


func _make_home_eyebrow() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "HomeEyebrow"
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", _space(10, 18))

	for side: int in range(2):
		if side == 1:
			var label := _make_label("RACING SERIES", _font_px(9, 13, 0.012), COLOR_RACING_RED, false)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			row.add_child(label)
		var line := ColorRect.new()
		line.color = Color(COLOR_RACING_RED, 0.66)
		line.custom_minimum_size = Vector2(_space(42, 68), 1.0)
		row.add_child(line)
	return row


func _make_home_brand() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "HomeBrand"
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 0)

	var apex := _make_label("APEX", _font_px(62, 112, 0.096), Color(0.86, 0.85, 0.86, 1.0), true)
	apex.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(apex)

	var drive := _make_label("DRIVE", _font_px(62, 112, 0.096), COLOR_RACING_RED, true)
	drive.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(drive)
	return row


func _make_home_settings_button() -> Button:
	var button := Button.new()
	button.name = "SettingsButton"
	button.text = "SETTINGS"
	button.custom_minimum_size = Vector2(_vw(0.24, 320.0, 460.0), _vh(0.052, 42.0, 58.0))
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", _font_px(13, 19, 0.018))
	button.add_theme_stylebox_override("normal", _make_panel_style(Color(0.0, 0.0, 0.0, 0.0), Color(0.36, 0.34, 0.48, 0.35), 1, 0))
	button.add_theme_stylebox_override("hover", _make_panel_style(Color(0.08, 0.075, 0.12, 0.34), Color(0.62, 0.60, 0.80, 0.62), 1, 0))
	button.add_theme_stylebox_override("pressed", _make_panel_style(Color(0.12, 0.020, 0.035, 0.44), COLOR_RACING_RED, 1, 0))
	button.add_theme_stylebox_override("focus", _make_panel_style(Color.TRANSPARENT, COLOR_RACING_BLUE, 2, 0))
	button.add_theme_color_override("font_color", Color(0.58, 0.56, 0.72, 1.0))
	button.add_theme_color_override("font_hover_color", COLOR_TEXT_MAIN)
	button.add_theme_color_override("font_pressed_color", COLOR_TEXT_MAIN)
	return button


func _build_settings_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "SettingsPanel"
	panel.custom_minimum_size = Vector2(_vw(0.19, 280.0, 390.0), 0.0)
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.045, 0.052, 0.065, 0.94), Color(1.0, 1.0, 1.0, 0.16), 1, 8))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", _space(16, 24))
	margin.add_theme_constant_override("margin_top", _space(16, 24))
	margin.add_theme_constant_override("margin_right", _space(16, 24))
	margin.add_theme_constant_override("margin_bottom", _space(16, 24))
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", _space(12, 18))
	margin.add_child(content)
	content.add_child(_make_label("SETTINGS", _font_px(24, 36, 0.034), Color(0.96, 0.97, 0.93, 1.0), true))
	var master_row := _make_slider_row("Global", Callable(self, "_on_master_percent_changed"))
	_master_slider = master_row["slider"]
	_master_value_label = master_row["value_label"]
	content.add_child(master_row["root"])
	var music_row := _make_slider_row("Music", Callable(self, "_on_music_percent_changed"))
	_music_slider = music_row["slider"]
	_music_value_label = music_row["value_label"]
	content.add_child(music_row["root"])
	var sfx_row := _make_slider_row("SFX", Callable(self, "_on_sfx_percent_changed"))
	_sfx_slider = sfx_row["slider"]
	_sfx_value_label = sfx_row["value_label"]
	content.add_child(sfx_row["root"])
	var brightness_row := _make_slider_row("Brightness", Callable(self, "_on_brightness_percent_changed"))
	_brightness_slider = brightness_row["slider"]
	_brightness_value_label = brightness_row["value_label"]
	content.add_child(brightness_row["root"])
	return panel


func _build_car_select_view() -> Control:
	var root := Control.new()
	root.name = "CarSelect"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var top_bar := _make_logo_top_bar()

	var safe := _make_safe_area()
	root.add_child(safe)
	var rows := _make_selection_rows("CarSelectRows", VIEW_CAR_SELECT)
	safe.add_child(_make_selection_shell(rows))

	var top := rows.get_node("TopContent") as Control
	_add_top_column(top, _build_car_details_column(), 0)
	_add_top_column(top, _build_car_preview_column(), 1)
	_add_top_column(top, _build_car_stats_column(), 2)

	var cards := rows.get_node("CardsRow/CardViewport/CardsList") as HBoxContainer
	_car_cards_leading_spacer = _make_card_spacer("LeadingCardSpacer")
	cards.add_child(_car_cards_leading_spacer)
	for option: Dictionary in _car_options():
		cards.add_child(_build_car_card(option))
	_car_cards_trailing_spacer = _make_card_spacer("TrailingCardSpacer")
	cards.add_child(_car_cards_trailing_spacer)

	var bottom := rows.get_node("BottomActions") as CenterContainer
	var action_row := _make_bottom_action_row()
	bottom.add_child(action_row)
	var back_button := _make_button("BACK", false, _font_px(20, 32, 0.030), _vh(0.07, 58.0, 86.0))
	back_button.size_flags_stretch_ratio = 0.78
	back_button.pressed.connect(Callable(self, "_show_home"))
	action_row.add_child(back_button)
	var continue_button := _make_button("CONTINUE", true, _font_px(24, 38, 0.034), _vh(0.07, 58.0, 86.0))
	continue_button.size_flags_stretch_ratio = 1.22
	continue_button.pressed.connect(Callable(self, "_show_track_select"))
	action_row.add_child(continue_button)
	root.add_child(top_bar)
	return root


func _build_track_select_view() -> Control:
	var root := Control.new()
	root.name = "TrackSelect"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var top_bar := _make_logo_top_bar()

	var safe := _make_safe_area()
	root.add_child(safe)
	var rows := _make_selection_rows("TrackSelectRows", VIEW_TRACK_SELECT)
	safe.add_child(_make_selection_shell(rows))

	var top := rows.get_node("TopContent") as Control
	_add_top_column(top, _build_track_title_column(), 0)
	_add_top_column(top, _build_track_preview_column(), 1)
	_add_top_column(top, _build_track_description_column(), 2)

	var cards := rows.get_node("CardsRow/CardViewport/CardsList") as HBoxContainer
	_track_cards_leading_spacer = _make_card_spacer("LeadingCardSpacer")
	cards.add_child(_track_cards_leading_spacer)
	for option: Dictionary in _track_options():
		cards.add_child(_build_track_card(option))
	_track_cards_trailing_spacer = _make_card_spacer("TrailingCardSpacer")
	cards.add_child(_track_cards_trailing_spacer)

	var bottom := rows.get_node("BottomActions") as CenterContainer
	var action_row := _make_bottom_action_row()
	bottom.add_child(action_row)
	var back_button := _make_button("BACK", false, _font_px(20, 32, 0.030), _vh(0.07, 58.0, 86.0))
	back_button.size_flags_stretch_ratio = 0.78
	back_button.pressed.connect(Callable(self, "_show_car_select"))
	action_row.add_child(back_button)
	var start_button := _make_button("START RACE", true, _font_px(24, 38, 0.034), _vh(0.07, 58.0, 86.0))
	start_button.size_flags_stretch_ratio = 1.22
	start_button.pressed.connect(Callable(self, "_start_race_loading"))
	action_row.add_child(start_button)
	root.add_child(top_bar)
	return root


func _make_selection_shell(rows: VBoxContainer) -> HBoxContainer:
	var shell := HBoxContainer.new()
	shell.name = "SelectionShell"
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_theme_constant_override("separation", 0)

	var left_gutter := Control.new()
	left_gutter.name = "LeftThinColumn"
	left_gutter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_gutter.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_gutter.size_flags_stretch_ratio = 0.42
	shell.add_child(left_gutter)

	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.size_flags_stretch_ratio = 12.0
	shell.add_child(rows)

	var right_gutter := Control.new()
	right_gutter.name = "RightThinColumn"
	right_gutter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_gutter.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_gutter.size_flags_stretch_ratio = 0.42
	shell.add_child(right_gutter)
	return shell


func _make_selection_rows(node_name: String, card_group: StringName) -> VBoxContainer:
	var rows := VBoxContainer.new()
	rows.name = node_name
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", _space(10, 18))

	var top_padding := Control.new()
	top_padding.name = "TopPadding"
	top_padding.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_padding.size_flags_stretch_ratio = 1.0
	rows.add_child(top_padding)

	var top := Control.new()
	top.name = "TopContent"
	top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top.size_flags_stretch_ratio = 4.0
	top.clip_contents = true
	rows.add_child(top)

	var selection_gap := Control.new()
	selection_gap.name = "SelectionGap"
	selection_gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	selection_gap.size_flags_stretch_ratio = 1.0
	rows.add_child(selection_gap)

	var cards := HBoxContainer.new()
	cards.name = "CardsRow"
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards.size_flags_stretch_ratio = 2.0
	cards.add_theme_constant_override("separation", _space(10, 16))

	var previous_button := _make_arrow_button("<")
	previous_button.pressed.connect(Callable(self, "_scroll_cards").bind(card_group, -1))
	cards.add_child(previous_button)

	var viewport := ScrollContainer.new()
	viewport.name = "CardViewport"
	viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	viewport.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cards.add_child(viewport)

	var cards_list := HBoxContainer.new()
	cards_list.name = "CardsList"
	cards_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards_list.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_list.add_theme_constant_override("separation", _card_gap())
	viewport.add_child(cards_list)

	var next_button := _make_arrow_button(">")
	next_button.pressed.connect(Callable(self, "_scroll_cards").bind(card_group, 1))
	cards.add_child(next_button)

	if card_group == VIEW_CAR_SELECT:
		_car_cards_scroll = viewport
		_car_prev_button = previous_button
		_car_next_button = next_button
	else:
		_track_cards_scroll = viewport
		_track_prev_button = previous_button
		_track_next_button = next_button
	rows.add_child(cards)

	var bottom := CenterContainer.new()
	bottom.name = "BottomActions"
	bottom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom.size_flags_stretch_ratio = 2.0
	rows.add_child(bottom)
	return rows


func _add_top_column(top: Control, column: Control, index: int) -> void:
	var slot := Control.new()
	slot.name = "%sSlot" % column.name
	var column_count := 3.0
	var gap := float(_space(12, 22))
	slot.anchor_left = float(index) / column_count
	slot.anchor_right = float(index + 1) / column_count
	slot.anchor_top = 0.0
	slot.anchor_bottom = 1.0
	slot.offset_left = gap * float(index) / column_count
	slot.offset_right = -gap * float(int(column_count) - 1 - index) / column_count
	slot.offset_top = 0.0
	slot.offset_bottom = 0.0
	slot.clip_contents = true
	slot.custom_minimum_size = Vector2.ZERO
	top.add_child(slot)

	column.anchor_left = 0.0
	column.anchor_right = 1.0
	column.anchor_top = 0.0
	column.anchor_bottom = 1.0
	column.offset_left = 0.0
	column.offset_right = 0.0
	column.offset_top = 0.0
	column.offset_bottom = 0.0
	column.clip_contents = true
	column.custom_minimum_size = Vector2.ZERO
	slot.add_child(column)


func _build_car_details_column() -> VBoxContainer:
	var column := _make_equal_top_column("CarDetails")
	_car_name_label = _make_label("", _font_px(34, 58, 0.052), Color(0.96, 0.97, 0.93, 1.0), true)
	_car_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_configure_top_title_label(_car_name_label)
	column.add_child(_car_name_label)
	_car_class_label = _make_label("", _font_px(16, 22, 0.020), Color(0.46, 0.84, 1.0, 1.0), false)
	_car_class_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_car_class_label)
	_car_description_label = _make_label("", _font_px(15, 20, 0.018), Color(0.76, 0.80, 0.82, 1.0), false)
	_car_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_car_description_label)
	var swatches := GridContainer.new()
	swatches.name = "SkinSwatches"
	swatches.columns = 2
	swatches.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	swatches.add_theme_constant_override("h_separation", _space(8, 14))
	swatches.add_theme_constant_override("v_separation", _space(8, 14))
	column.add_child(swatches)
	for skin: Dictionary in _skin_options_for_selected_car():
		var button := _make_skin_button(skin)
		_skin_buttons[StringName(skin.get("id", &""))] = button
		swatches.add_child(button)
	return column


func _build_car_preview_column() -> PanelContainer:
	var panel := _make_panel("CarPreviewColumn")
	panel.size_flags_stretch_ratio = 1.0
	var preview := SubViewportContainer.new()
	preview.name = "CarPreview"
	preview.stretch = true
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.gui_input.connect(Callable(self, "_on_preview_gui_input"))
	panel.add_child(preview)

	_preview_subviewport = SubViewport.new()
	_preview_subviewport.name = "PreviewViewport"
	_preview_subviewport.disable_3d = false
	_preview_subviewport.transparent_bg = true
	_preview_subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	preview.add_child(_preview_subviewport)

	var root3d := Node3D.new()
	root3d.name = "StageRoot"
	_preview_subviewport.add_child(root3d)
	var light := DirectionalLight3D.new()
	light.name = "KeyLight"
	light.light_energy = 2.8
	light.rotation_degrees = Vector3(-48.0, -35.0, 0.0)
	root3d.add_child(light)
	var fill := OmniLight3D.new()
	fill.name = "FillLight"
	fill.light_energy = 1.2
	fill.position = Vector3(2.0, 2.4, 3.5)
	root3d.add_child(fill)
	_build_preview_room(root3d)
	_preview_turntable = Node3D.new()
	_preview_turntable.name = "Turntable"
	root3d.add_child(_preview_turntable)
	_build_preview_platform(_preview_turntable)
	_preview_car_mount = Node3D.new()
	_preview_car_mount.name = "CarMount"
	_preview_car_mount.position = Vector3(0.0, 0.14, 0.0)
	_preview_turntable.add_child(_preview_car_mount)
	_preview_camera = Camera3D.new()
	_preview_camera.name = "PreviewCamera"
	_preview_camera.fov = 42.0
	root3d.add_child(_preview_camera)
	_position_preview_camera()
	_rebuild_car_preview()
	return panel


func _build_car_stats_column() -> VBoxContainer:
	var column := _make_equal_top_column("CarStats")
	column.add_child(_make_label("PERFORMANCE", _font_px(15, 20, 0.018), Color(0.46, 0.84, 1.0, 1.0), true))
	var stats: Dictionary = _displayed_car_option().get("stats", {})
	for stat_name: String in STAT_ORDER:
		var row := _make_stat_row(STAT_LABELS.get(stat_name, stat_name), int(stats.get(stat_name, 0)), STAT_COLORS.get(stat_name, Color.WHITE))
		_car_stat_labels[stat_name] = row.get_child(0)
		_car_stat_bars[stat_name] = row.get_child(1)
		column.add_child(row)
	return column


func _build_preview_room(root3d: Node3D) -> void:
	var floor_node := MeshInstance3D.new()
	floor_node.name = "PreviewRoomFloor"
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(8.7, 0.08, 7.9)
	floor_node.mesh = floor_mesh
	floor_node.position = Vector3(0.0, -0.08, 0.0)
	floor_node.material_override = _make_preview_material(Color(0.035, 0.040, 0.048, 1.0), 0.12, 0.46)
	root3d.add_child(floor_node)

	var back_wall := MeshInstance3D.new()
	back_wall.name = "PreviewRoomBackWall"
	var back_mesh := BoxMesh.new()
	back_mesh.size = Vector3(8.7, 2.8, 0.10)
	back_wall.mesh = back_mesh
	back_wall.position = Vector3(0.0, 1.32, -3.65)
	back_wall.material_override = _make_preview_material(Color(0.055, 0.065, 0.078, 1.0), 0.0, 0.62)
	root3d.add_child(back_wall)

	var side_wall_left := MeshInstance3D.new()
	side_wall_left.name = "PreviewRoomLeftWall"
	var side_mesh_left := BoxMesh.new()
	side_mesh_left.size = Vector3(0.10, 2.3, 7.3)
	side_wall_left.mesh = side_mesh_left
	side_wall_left.position = Vector3(-3.75, 1.06, 0.0)
	side_wall_left.material_override = _make_preview_material(Color(0.038, 0.047, 0.058, 1.0), 0.0, 0.68)
	root3d.add_child(side_wall_left)

	var side_wall_right := MeshInstance3D.new()
	side_wall_right.name = "PreviewRoomRightWall"
	var side_mesh_right := BoxMesh.new()
	side_mesh_right.size = Vector3(0.10, 2.3, 7.3)
	side_wall_right.mesh = side_mesh_right
	side_wall_right.position = Vector3(3.75, 1.06, 0.0)
	side_wall_right.material_override = _make_preview_material(Color(0.038, 0.047, 0.058, 1.0), 0.0, 0.68)
	root3d.add_child(side_wall_right)


func _build_preview_platform(parent: Node3D) -> void:
	var base := MeshInstance3D.new()
	base.name = "RotatingRoundPlatform"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 2.55
	mesh.bottom_radius = 2.65
	mesh.height = 0.24
	mesh.radial_segments = 64
	base.mesh = mesh
	base.position = Vector3(0.0, 0.02, 0.0)
	base.material_override = _make_preview_material(Color(0.11, 0.12, 0.13, 1.0), 0.5, 0.24)
	parent.add_child(base)

	var highlight := MeshInstance3D.new()
	highlight.name = "PlatformTopHighlight"
	var highlight_mesh := CylinderMesh.new()
	highlight_mesh.top_radius = 2.40
	highlight_mesh.bottom_radius = 2.40
	highlight_mesh.height = 0.025
	highlight_mesh.radial_segments = 64
	highlight.mesh = highlight_mesh
	highlight.position = Vector3(0.0, 0.155, 0.0)
	highlight.material_override = _make_preview_material(Color(0.19, 0.22, 0.25, 1.0), 0.35, 0.28)
	parent.add_child(highlight)


func _make_preview_material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var preview_material := StandardMaterial3D.new()
	preview_material.albedo_color = color
	preview_material.metallic = metallic
	preview_material.roughness = roughness
	return preview_material


func _build_car_card(option: Dictionary) -> Button:
	var car_id := StringName(option.get("id", &""))
	var card := _make_card_button("CarCard")
	card.tooltip_text = str(option.get("display_name", "Car"))
	card.mouse_entered.connect(Callable(self, "_preview_car").bind(car_id))
	card.mouse_exited.connect(Callable(self, "_clear_car_preview").bind(car_id))
	card.focus_entered.connect(Callable(self, "_preview_car").bind(car_id))
	card.focus_exited.connect(Callable(self, "_clear_car_preview").bind(car_id))
	card.pressed.connect(Callable(self, "_select_car").bind(car_id))
	_car_buttons[car_id] = card
	var image := _card_image(card)
	image.texture = _load_car_card_texture(option)
	return card


func _build_track_title_column() -> VBoxContainer:
	var column := _make_equal_top_column("TrackTitle")
	_track_name_label = _make_label("", _font_px(34, 58, 0.052), Color(0.96, 0.97, 0.93, 1.0), true)
	_track_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_configure_top_title_label(_track_name_label)
	column.add_child(_track_name_label)
	_track_meta_label = _make_label("", _font_px(16, 22, 0.020), Color(0.46, 0.84, 1.0, 1.0), false)
	_track_meta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_track_meta_label)
	column.add_child(_make_label("TRACK SELECT", _font_px(15, 20, 0.018), Color(0.76, 0.80, 0.82, 1.0), true))
	return column


func _build_track_preview_column() -> PanelContainer:
	var panel := _make_panel("TrackPreviewColumn")
	var texture := TextureRect.new()
	texture.name = "TrackPreview"
	texture.texture = _load_track_preview_texture(_displayed_track_option())
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	texture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texture.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_track_preview_texture_rect = texture
	panel.add_child(texture)
	return panel


func _build_track_description_column() -> VBoxContainer:
	var column := _make_equal_top_column("TrackDetails")
	column.add_child(_make_label("ROUTE BRIEF", _font_px(15, 20, 0.018), COLOR_RACING_BLUE, true))
	_track_description_label = _make_label("", _font_px(16, 22, 0.020), Color(0.82, 0.85, 0.86, 1.0), false)
	_track_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_track_description_label)
	var difficulty_gap := Control.new()
	difficulty_gap.custom_minimum_size = Vector2(1.0, _space(8, 18))
	column.add_child(difficulty_gap)
	column.add_child(_make_label("RIVAL DIFFICULTY", _font_px(15, 20, 0.018), COLOR_RACING_BLUE, true))
	var difficulty_row := HBoxContainer.new()
	difficulty_row.name = "DifficultyRow"
	difficulty_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	difficulty_row.add_theme_constant_override("separation", _space(8, 12))
	column.add_child(difficulty_row)
	for difficulty: Dictionary in _difficulty_options():
		var button := _make_difficulty_button(difficulty)
		_difficulty_buttons[StringName(difficulty.get("id", &""))] = button
		difficulty_row.add_child(button)
	_difficulty_description_label = _make_label("", _font_px(14, 19, 0.017), COLOR_TEXT_MUTED, false)
	_difficulty_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_difficulty_description_label)
	return column


func _build_track_card(option: Dictionary) -> Button:
	var track_id := StringName(option.get("id", &""))
	var card := _make_card_button("TrackCard")
	card.tooltip_text = str(option.get("display_name", "Track"))
	card.mouse_entered.connect(Callable(self, "_preview_track").bind(track_id))
	card.mouse_exited.connect(Callable(self, "_clear_track_preview").bind(track_id))
	card.focus_entered.connect(Callable(self, "_preview_track").bind(track_id))
	card.focus_exited.connect(Callable(self, "_clear_track_preview").bind(track_id))
	card.pressed.connect(Callable(self, "_select_track").bind(track_id))
	_track_buttons[track_id] = card
	var image := _card_image(card)
	image.texture = _load_track_preview_texture(option)
	return card


func _make_safe_area() -> MarginContainer:
	var safe := MarginContainer.new()
	safe.name = "SafeArea"
	safe.set_anchors_preset(Control.PRESET_FULL_RECT)
	safe.add_theme_constant_override("margin_left", _space(36, 70))
	safe.add_theme_constant_override("margin_top", _space(84, 112))
	safe.add_theme_constant_override("margin_right", _space(36, 70))
	safe.add_theme_constant_override("margin_bottom", _space(24, 44))
	return safe


func _make_logo_top_bar() -> PanelContainer:
	var bar := PanelContainer.new()
	bar.name = "TopStatusBar"
	bar.anchor_left = 0.0
	bar.anchor_top = 0.0
	bar.anchor_right = 1.0
	bar.anchor_bottom = 0.0
	bar.offset_bottom = _vh(0.085, 66.0, 92.0)
	bar.add_theme_stylebox_override("panel", _make_panel_style(Color(0.010, 0.012, 0.016, 0.60), Color(1.0, 1.0, 1.0, 0.08), 1, 0))

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", _space(32, 56))
	margin.add_theme_constant_override("margin_right", _space(32, 56))
	margin.add_theme_constant_override("margin_top", _space(8, 14))
	margin.add_theme_constant_override("margin_bottom", _space(8, 14))
	bar.add_child(margin)

	var center := CenterContainer.new()
	center.name = "TopBarLogoCenter"
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(center)

	var brand := _make_label("APEXDRIVE", _font_px(24, 40, 0.036), COLOR_TEXT_MAIN, true)
	brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	brand.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center.add_child(brand)
	return bar


func _make_top_bar_badge(text: String, fill: Color, border: Color) -> PanelContainer:
	var badge := PanelContainer.new()
	badge.name = "TopBarBadge"
	badge.custom_minimum_size = Vector2(_space(72, 128), 1.0)
	badge.size_flags_vertical = Control.SIZE_EXPAND_FILL
	badge.add_theme_stylebox_override("panel", _make_panel_style(fill, border, 1, 5))
	var label := _make_label(text, _font_px(12, 17, 0.016), COLOR_TEXT_MAIN, true)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(label)
	return badge


func _make_top_bar_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(_space(86, 136), 1.0)
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", _font_px(12, 17, 0.016))
	button.add_theme_stylebox_override("normal", _make_panel_style(Color(0.045, 0.050, 0.062, 0.80), Color(1.0, 1.0, 1.0, 0.22), 1, 5))
	button.add_theme_stylebox_override("hover", _make_panel_style(Color(0.10, 0.11, 0.13, 0.92), COLOR_RACING_BLUE, 1, 5))
	button.add_theme_stylebox_override("pressed", _make_panel_style(Color(0.16, 0.035, 0.045, 0.96), COLOR_RACING_RED_HOVER, 1, 5))
	button.add_theme_stylebox_override("focus", _make_panel_style(Color.TRANSPARENT, COLOR_RACING_BLUE, 2, 5))
	button.add_theme_color_override("font_color", COLOR_TEXT_MAIN)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	return button


func _make_equal_top_column(node_name: String) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.name = node_name
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.size_flags_stretch_ratio = 1.0
	column.custom_minimum_size = Vector2.ZERO
	column.clip_contents = true
	column.add_theme_constant_override("separation", _space(8, 14))
	return column


func _make_panel(node_name: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.0
	panel.custom_minimum_size = Vector2.ZERO
	panel.clip_contents = true
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.035, 0.042, 0.054, 0.78), Color(1.0, 1.0, 1.0, 0.12), 1, 8))
	return panel


func _make_card_button(node_name: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = ""
	button.toggle_mode = true
	var side := _selection_card_width()
	button.custom_minimum_size = Vector2(side, side)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.clip_contents = true
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_choice_card_style(button)
	return button


func _make_arrow_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(_space(68, 92), 1.0)
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", _font_px(34, 52, 0.046))
	_apply_arrow_button_style(button)
	return button


func _make_card_spacer(node_name: String) -> Control:
	var spacer := Control.new()
	spacer.name = node_name
	spacer.custom_minimum_size = Vector2(1.0, 1.0)
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return spacer


func _make_bottom_action_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "BottomActionRow"
	row.custom_minimum_size = Vector2(_vw(0.34, 360.0, 660.0), 0.0)
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_theme_constant_override("separation", _space(12, 22))
	return row


func _card_content(card: Button) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", _space(8, 14))
	margin.add_theme_constant_override("margin_top", _space(8, 14))
	margin.add_theme_constant_override("margin_right", _space(8, 14))
	margin.add_theme_constant_override("margin_bottom", _space(8, 14))
	card.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", _space(5, 8))
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(content)
	return content


func _card_image(card: Button) -> TextureRect:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", _space(5, 8))
	margin.add_theme_constant_override("margin_top", _space(5, 8))
	margin.add_theme_constant_override("margin_right", _space(5, 8))
	margin.add_theme_constant_override("margin_bottom", _space(5, 8))
	card.add_child(margin)

	var image := TextureRect.new()
	image.name = "PreviewImage"
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	image.size_flags_vertical = Control.SIZE_EXPAND_FILL
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(image)
	return image


func _make_skin_button(skin: Dictionary) -> Button:
	var button := Button.new()
	button.toggle_mode = true
	button.text = ""
	button.tooltip_text = str(skin.get("display_name", "Skin"))
	button.custom_minimum_size = Vector2(1.0, _vh(0.055, 46.0, 68.0))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", _font_px(13, 18, 0.016))
	var swatch := _safe_color(skin.get("swatch", Color.WHITE))
	button.add_theme_stylebox_override("normal", _make_panel_style(swatch.darkened(0.28), swatch, 1, 8))
	button.add_theme_stylebox_override("hover", _make_panel_style(swatch.darkened(0.12), Color.WHITE, 1, 8))
	button.add_theme_stylebox_override("pressed", _make_panel_style(swatch.darkened(0.38), Color.WHITE, 2, 8))
	button.add_theme_stylebox_override("focus", _make_panel_style(Color.TRANSPARENT, Color.WHITE, 2, 8))
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.pressed.connect(Callable(self, "_select_skin").bind(StringName(skin.get("id", &""))))
	return button


func _make_difficulty_button(difficulty: Dictionary) -> Button:
	var difficulty_id := StringName(difficulty.get("id", &""))
	var button := Button.new()
	button.name = "DifficultyButton"
	button.toggle_mode = true
	button.text = str(difficulty.get("display_name", difficulty_id)).to_upper()
	button.tooltip_text = str(difficulty.get("description", ""))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(1.0, _vh(0.050, 42.0, 62.0))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", _font_px(12, 17, 0.016))
	_apply_difficulty_button_style(button, false)
	button.pressed.connect(Callable(self, "_select_difficulty").bind(difficulty_id))
	return button


func _make_slider_row(label_text: String, callback: Callable) -> Dictionary:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", _space(5, 8))
	var header := HBoxContainer.new()
	root.add_child(header)
	var label := _make_label(label_text, _font_px(15, 20, 0.018), Color(0.86, 0.89, 0.90, 1.0), false)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(label)
	var value_label := _make_label("100", _font_px(15, 20, 0.018), Color(0.46, 0.84, 1.0, 1.0), true)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.custom_minimum_size = Vector2(_space(42, 58), 1.0)
	header.add_child(value_label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(1.0, _space(30, 40))
	slider.value_changed.connect(callback)
	root.add_child(slider)
	return {"root": root, "slider": slider, "value_label": value_label}


func _make_label(text: String, font_size: int, color: Color, bold: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if bold:
		label.add_theme_constant_override("outline_size", 1)
		label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.32))
	return label


func _configure_top_title_label(label: Label) -> void:
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.max_lines_visible = 2


func _make_button(text: String, primary: bool, font_size: int, height: float) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(1.0, height)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", font_size)
	_apply_button_style(button, primary)
	return button


func _make_stat_row(label_text: String, value: int, accent: Color) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", _space(4, 7))
	var label := _make_label("%s  %d" % [label_text.to_upper(), value], _font_px(14, 20, 0.018), Color(0.88, 0.90, 0.90, 1.0), false)
	box.add_child(label)
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = value
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(1.0, _space(8, 12))
	bar.add_theme_stylebox_override("background", _make_panel_style(Color(0.18, 0.19, 0.21, 1.0), Color.TRANSPARENT, 0, 4))
	bar.add_theme_stylebox_override("fill", _make_panel_style(accent, accent, 0, 4))
	box.add_child(bar)
	return box


func _make_mini_stat_bar(value: int, accent: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = value
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(1.0, _space(6, 9))
	bar.add_theme_stylebox_override("background", _make_panel_style(Color(0.16, 0.17, 0.19, 1.0), Color.TRANSPARENT, 0, 3))
	bar.add_theme_stylebox_override("fill", _make_panel_style(accent, accent, 0, 3))
	return bar


func _apply_choice_card_style(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _make_panel_style(Color(0.035, 0.045, 0.055, 0.90), Color(1.0, 1.0, 1.0, 0.18), 1, 10))
	button.add_theme_stylebox_override("hover", _make_panel_style(Color(0.055, 0.075, 0.090, 1.0), Color(0.46, 0.84, 1.0, 0.88), 2, 10))
	button.add_theme_stylebox_override("pressed", _make_panel_style(Color(0.12, 0.035, 0.045, 1.0), Color(1.0, 0.16, 0.20, 1.0), 4, 10))
	button.add_theme_stylebox_override("hover_pressed", _make_panel_style(Color(0.17, 0.045, 0.055, 1.0), Color(1.0, 0.72, 0.72, 1.0), 4, 10))
	button.add_theme_stylebox_override("focus", _make_panel_style(Color.TRANSPARENT, Color(0.46, 0.84, 1.0, 1.0), 2, 10))
	button.add_theme_color_override("font_color", Color.TRANSPARENT)
	button.add_theme_color_override("font_hover_color", Color.TRANSPARENT)
	button.add_theme_color_override("font_pressed_color", Color.TRANSPARENT)


func _apply_difficulty_button_style(button: Button, selected: bool) -> void:
	var normal_fill := Color(0.045, 0.052, 0.064, 0.88)
	var normal_border := Color(1.0, 1.0, 1.0, 0.16)
	if selected:
		normal_fill = Color(0.18, 0.025, 0.040, 0.96)
		normal_border = COLOR_RACING_RED_HOVER
	button.add_theme_stylebox_override("normal", _make_panel_style(normal_fill, normal_border, 1 if not selected else 2, 6))
	button.add_theme_stylebox_override("hover", _make_panel_style(Color(0.11, 0.040, 0.050, 0.96), COLOR_RACING_RED_HOVER, 2, 6))
	button.add_theme_stylebox_override("pressed", _make_panel_style(Color(0.22, 0.025, 0.040, 1.0), Color(1.0, 0.68, 0.62, 1.0), 2, 6))
	button.add_theme_stylebox_override("hover_pressed", _make_panel_style(Color(0.24, 0.030, 0.045, 1.0), Color(1.0, 0.72, 0.66, 1.0), 2, 6))
	button.add_theme_stylebox_override("focus", _make_panel_style(Color.TRANSPARENT, COLOR_RACING_BLUE, 2, 6))
	button.add_theme_color_override("font_color", COLOR_TEXT_MAIN)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)


func _apply_button_style(button: Button, primary: bool) -> void:
	var normal_fill := Color(0.075, 0.088, 0.108, 0.96)
	var hover_fill := Color(0.11, 0.13, 0.16, 1.0)
	var pressed_fill := Color(0.15, 0.17, 0.20, 1.0)
	var border := Color(1.0, 1.0, 1.0, 0.18)
	var font_color := Color(0.92, 0.94, 0.92, 1.0)
	if primary:
		normal_fill = COLOR_RACING_RED
		hover_fill = COLOR_RACING_RED_HOVER
		pressed_fill = Color(0.72, 0.04, 0.08, 1.0)
		border = Color(1.0, 0.78, 0.70, 0.52)
		font_color = Color(1.0, 0.98, 0.93, 1.0)
	button.add_theme_stylebox_override("normal", _make_panel_style(normal_fill, border, 1, 8))
	button.add_theme_stylebox_override("hover", _make_panel_style(hover_fill, Color(0.46, 0.84, 1.0, 0.55), 1, 8))
	button.add_theme_stylebox_override("pressed", _make_panel_style(pressed_fill, Color(0.46, 0.84, 1.0, 0.75), 1, 8))
	var focus_border := Color(0.46, 0.84, 1.0, 0.95)
	if primary:
		focus_border = Color(1.0, 0.78, 0.70, 0.52)
	button.add_theme_stylebox_override("focus", _make_panel_style(Color.TRANSPARENT, focus_border, 2, 8))
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)


func _apply_arrow_button_style(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _make_panel_style(Color(0.02, 0.18, 0.27, 0.96), Color(0.46, 0.84, 1.0, 0.72), 2, 8))
	button.add_theme_stylebox_override("hover", _make_panel_style(Color(0.05, 0.32, 0.45, 1.0), Color(0.80, 0.94, 1.0, 0.96), 2, 8))
	button.add_theme_stylebox_override("pressed", _make_panel_style(Color(0.01, 0.12, 0.19, 1.0), Color(1.0, 1.0, 1.0, 0.85), 2, 8))
	button.add_theme_stylebox_override("disabled", _make_panel_style(Color(0.06, 0.07, 0.08, 0.38), Color(1.0, 1.0, 1.0, 0.08), 1, 8))
	button.add_theme_stylebox_override("focus", _make_panel_style(Color.TRANSPARENT, Color(0.46, 0.84, 1.0, 0.95), 2, 8))
	button.add_theme_color_override("font_color", Color(0.92, 0.98, 1.0, 1.0))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(0.72, 0.76, 0.78, 0.62))


func _make_panel_style(fill: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = _space(8, 12)
	style.content_margin_right = _space(8, 12)
	style.content_margin_top = _space(6, 10)
	style.content_margin_bottom = _space(6, 10)
	return style


func _show_view(view_name: StringName, sync: bool = true) -> void:
	_active_view = view_name
	if _home_view != null:
		_home_view.visible = view_name == VIEW_HOME
	if _car_select_view != null:
		_car_select_view.visible = view_name == VIEW_CAR_SELECT
	if _track_select_view != null:
		_track_select_view.visible = view_name == VIEW_TRACK_SELECT
	if sync:
		_sync_all_ui()


func _show_home() -> void:
	_show_view(VIEW_HOME)


func _show_car_select() -> void:
	_show_view(VIEW_CAR_SELECT)


func _show_track_select() -> void:
	_show_view(VIEW_TRACK_SELECT)


func _toggle_settings() -> void:
	_settings_visible = not _settings_visible
	if _settings_panel != null:
		_settings_panel.visible = _settings_visible


func _select_car(car_id: StringName) -> void:
	_preview_car_id = &""
	var session := _session()
	if session != null and session.has_method("set_car"):
		session.call("set_car", car_id)
	_sync_from_session()
	_rebuild_car_select()


func _select_skin(skin_id: StringName) -> void:
	_preview_car_id = &""
	var session := _session()
	if session != null and session.has_method("set_car_skin"):
		session.call("set_car_skin", _selected_car_id, skin_id)
	_sync_from_session()
	_rebuild_car_select()


func _select_track(track_id: StringName) -> void:
	_preview_track_id = &""
	var track := _track_option(track_id)
	if track.is_empty():
		return
	var session := _session()
	if session != null and session.has_method("set_track"):
		session.call("set_track", track_id, str(track.get("scene_path", "")))
	_sync_from_session()
	_rebuild_track_select()


func _select_difficulty(difficulty_id: StringName) -> void:
	var session := _session()
	if session != null and session.has_method("set_difficulty"):
		session.call("set_difficulty", str(difficulty_id))
	_sync_from_session()
	_sync_difficulty_ui()


func _preview_car(car_id: StringName) -> void:
	if car_id == &"" or car_id == _preview_car_id:
		return
	_preview_car_id = car_id
	_sync_car_labels()
	_rebuild_car_preview()


func _clear_car_preview(car_id: StringName) -> void:
	if _preview_car_id != car_id:
		return
	_preview_car_id = &""
	_sync_car_labels()
	_rebuild_car_preview()


func _preview_track(track_id: StringName) -> void:
	if track_id == &"" or track_id == _preview_track_id:
		return
	_preview_track_id = track_id
	_sync_track_labels()


func _clear_track_preview(track_id: StringName) -> void:
	if _preview_track_id != track_id:
		return
	_preview_track_id = &""
	_sync_track_labels()


func _scroll_cards(card_group: StringName, direction: int) -> void:
	var scroll := _car_cards_scroll if card_group == VIEW_CAR_SELECT else _track_cards_scroll
	if scroll == null:
		return
	var step := _selection_card_width() + float(_card_gap())
	var next_position := float(scroll.scroll_horizontal) + step * float(direction)
	var horizontal_bar := scroll.get_h_scroll_bar()
	if horizontal_bar != null:
		next_position = clampf(next_position, horizontal_bar.min_value, horizontal_bar.max_value)
	next_position = maxf(0.0, next_position)
	_animate_cards_scroll(card_group, scroll, next_position)


func _animate_cards_scroll(card_group: StringName, scroll: ScrollContainer, target_position: float) -> void:
	var existing_tween := _car_cards_scroll_tween if card_group == VIEW_CAR_SELECT else _track_cards_scroll_tween
	if existing_tween != null:
		existing_tween.kill()
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(scroll, "scroll_horizontal", roundi(target_position), CARD_SCROLL_TWEEN_SECONDS)
	if card_group == VIEW_CAR_SELECT:
		_car_cards_scroll_tween = tween
	else:
		_track_cards_scroll_tween = tween


func _kill_card_scroll_tweens() -> void:
	if _car_cards_scroll_tween != null:
		_car_cards_scroll_tween.kill()
		_car_cards_scroll_tween = null
	if _track_cards_scroll_tween != null:
		_track_cards_scroll_tween.kill()
		_track_cards_scroll_tween = null


func _start_race_loading() -> void:
	var session := _session()
	if session != null and session.has_method("prepare_race_loading"):
		session.call("prepare_race_loading")
	_stop_menu_audio(0.25)
	get_tree().change_scene_to_file(RACE_LOADING_SCENE_PATH)


func _on_master_percent_changed(value: float) -> void:
	if _master_value_label != null:
		_master_value_label.text = str(roundi(value))
	var session := _session()
	if session != null and session.has_method("set_master_volume"):
		session.call("set_master_volume", value / 100.0)


func _on_music_percent_changed(value: float) -> void:
	if _music_value_label != null:
		_music_value_label.text = str(roundi(value))
	var session := _session()
	if session != null and session.has_method("set_music_volume"):
		session.call("set_music_volume", value / 100.0)


func _on_sfx_percent_changed(value: float) -> void:
	if _sfx_value_label != null:
		_sfx_value_label.text = str(roundi(value))
	var session := _session()
	if session != null and session.has_method("set_sfx_volume"):
		session.call("set_sfx_volume", value / 100.0)


func _on_brightness_percent_changed(value: float) -> void:
	if _brightness_value_label != null:
		_brightness_value_label.text = str(roundi(value))
	var session := _session()
	if session != null and session.has_method("set_brightness_percent"):
		session.call("set_brightness_percent", value)


func _sync_from_session() -> void:
	var session := _session()
	if session == null:
		return
	if session.has_method("get_car_id"):
		_selected_car_id = StringName(str(session.call("get_car_id")))
	if session.has_method("get_car_skin_id"):
		_selected_skin_id = StringName(str(session.call("get_car_skin_id")))
	if session.has_method("get_track_id"):
		_selected_track_id = StringName(str(session.call("get_track_id")))
	if session.has_method("get_difficulty"):
		_selected_difficulty_id = str(session.call("get_difficulty"))


func _sync_all_ui() -> void:
	_sync_settings_ui()
	_sync_card_buttons()
	_sync_car_labels()
	_sync_track_labels()
	_sync_difficulty_ui()
	_rebuild_car_preview()


func _sync_settings_ui() -> void:
	var session := _session()
	if session == null:
		return
	if _master_slider != null and session.has_method("get_master_volume"):
		var master_percent := roundf(float(session.call("get_master_volume")) * 100.0)
		_master_slider.set_value_no_signal(master_percent)
		_master_value_label.text = str(roundi(master_percent))
	if _music_slider != null and session.has_method("get_music_volume"):
		var music_percent := roundf(float(session.call("get_music_volume")) * 100.0)
		_music_slider.set_value_no_signal(music_percent)
		_music_value_label.text = str(roundi(music_percent))
	if _sfx_slider != null and session.has_method("get_sfx_volume"):
		var sfx_percent := roundf(float(session.call("get_sfx_volume")) * 100.0)
		_sfx_slider.set_value_no_signal(sfx_percent)
		_sfx_value_label.text = str(roundi(sfx_percent))
	if _brightness_slider != null and session.has_method("get_brightness_percent"):
		var brightness_percent := roundf(float(session.call("get_brightness_percent")))
		_brightness_slider.set_value_no_signal(brightness_percent)
		_brightness_value_label.text = str(roundi(brightness_percent))


func _sync_card_buttons() -> void:
	for key: Variant in _car_buttons.keys():
		var button := _car_buttons[key] as Button
		if button != null:
			button.button_pressed = StringName(key) == _selected_car_id
	for key: Variant in _skin_buttons.keys():
		var button := _skin_buttons[key] as Button
		if button != null:
			button.button_pressed = StringName(key) == _selected_skin_id
	for key: Variant in _track_buttons.keys():
		var button := _track_buttons[key] as Button
		if button != null:
			button.button_pressed = StringName(key) == _selected_track_id
	for key: Variant in _difficulty_buttons.keys():
		var button := _difficulty_buttons[key] as Button
		if button != null:
			var selected := StringName(key) == StringName(_selected_difficulty_id)
			button.button_pressed = selected
			_apply_difficulty_button_style(button, selected)
	_sync_card_nav()


func _sync_card_nav() -> void:
	var car_needs_arrows := _car_options().size() > _visible_card_capacity()
	var track_needs_arrows := _track_options().size() > _visible_card_capacity()
	for button: Button in [_car_prev_button, _car_next_button]:
		if button != null:
			button.disabled = not car_needs_arrows
	for button: Button in [_track_prev_button, _track_next_button]:
		if button != null:
			button.disabled = not track_needs_arrows


func _sync_car_labels() -> void:
	var car := _displayed_car_option()
	var skin := _displayed_skin_option()
	if _car_name_label != null:
		_car_name_label.text = str(car.get("display_name", ""))
	if _car_class_label != null:
		_car_class_label.text = "%s  /  %s" % [str(car.get("vehicle_class", "")), str(skin.get("display_name", ""))]
	if _car_description_label != null:
		_car_description_label.text = str(car.get("description", ""))
	var stats: Dictionary = car.get("stats", {})
	for stat_name: String in STAT_ORDER:
		var label := _car_stat_labels.get(stat_name, null) as Label
		if label != null:
			label.text = "%s  %d" % [STAT_LABELS.get(stat_name, stat_name).to_upper(), int(stats.get(stat_name, 0))]
		var bar := _car_stat_bars.get(stat_name, null) as ProgressBar
		if bar != null:
			bar.value = int(stats.get(stat_name, 0))


func _sync_track_labels() -> void:
	var track := _displayed_track_option()
	if _track_name_label != null:
		_track_name_label.text = str(track.get("display_name", ""))
	if _track_meta_label != null:
		_track_meta_label.text = "%d laps  /  %.0fm" % [int(track.get("lap_count", 1)), float(track.get("target_length_m", 0.0))]
	if _track_description_label != null:
		_track_description_label.text = str(track.get("description", ""))
	if _track_preview_texture_rect != null:
		_track_preview_texture_rect.texture = _load_track_preview_texture(track)


func _sync_difficulty_ui() -> void:
	var difficulty := _selected_difficulty_option()
	for key: Variant in _difficulty_buttons.keys():
		var button := _difficulty_buttons[key] as Button
		if button == null:
			continue
		var selected := StringName(key) == StringName(_selected_difficulty_id)
		button.button_pressed = selected
		_apply_difficulty_button_style(button, selected)
	if _difficulty_description_label != null:
		_difficulty_description_label.text = str(difficulty.get("description", ""))


func _rebuild_car_select() -> void:
	_sync_all_ui()
	if _active_view == VIEW_CAR_SELECT:
		_build_interface()


func _rebuild_track_select() -> void:
	_sync_all_ui()
	if _active_view == VIEW_TRACK_SELECT:
		_build_interface()


func _rebuild_car_preview() -> void:
	if _preview_car_mount == null:
		return
	for child: Node in _preview_car_mount.get_children():
		_preview_car_mount.remove_child(child)
		child.queue_free()
	var scene_path := _car_preview_instance_path()
	var packed := _load_preview_packed_scene(scene_path)
	if packed == null:
		return
	var car := packed.instantiate()
	_preview_car_mount.add_child(car)
	_disable_preview_processing(car)
	if car is Node3D:
		var car3d := car as Node3D
		car3d.scale = Vector3.ONE
		car3d.rotation_degrees = Vector3.ZERO
		_fit_preview_model_to_platform(car3d)
		car3d.rotation_degrees = Vector3(0.0, -35.0, 0.0)
	if car.has_method("set_controls_enabled"):
		car.call("set_controls_enabled", false)
	if car.has_method("set_car_color_variant"):
		car.call("set_car_color_variant", _displayed_car_color())


func _load_preview_packed_scene(scene_path: String) -> PackedScene:
	if scene_path.is_empty():
		return null
	if _car_preview_scene_cache.has(scene_path):
		return _car_preview_scene_cache[scene_path] as PackedScene
	var packed := load(scene_path) as PackedScene
	if packed != null:
		_car_preview_scene_cache[scene_path] = packed
	return packed


func _fit_preview_model_to_platform(root: Node3D) -> void:
	var bounds_info := _calculate_preview_bounds(root)
	if not bool(bounds_info.get("has_bounds", false)):
		return
	var bounds := bounds_info.get("bounds", AABB()) as AABB
	var horizontal_size := maxf(bounds.size.x, bounds.size.z)
	if horizontal_size <= 0.001:
		return
	var scale_factor := clampf(4.15 / horizontal_size, 0.08, 9.0)
	var center := bounds.get_center()
	root.scale *= scale_factor
	root.position = Vector3(-center.x * scale_factor, -bounds.position.y * scale_factor, -center.z * scale_factor)


func _calculate_preview_bounds(root: Node3D) -> Dictionary:
	var mesh_instances: Array[MeshInstance3D] = []
	_collect_preview_mesh_instances(root, mesh_instances)
	var has_bounds := false
	var bounds := AABB()
	for mesh_instance: MeshInstance3D in mesh_instances:
		if mesh_instance.mesh == null:
			continue
		var local_transform := _local_transform_to_root(root, mesh_instance)
		var local_bounds := _transform_aabb(local_transform, mesh_instance.mesh.get_aabb())
		if not has_bounds:
			bounds = local_bounds
			has_bounds = true
		else:
			bounds = bounds.merge(local_bounds)
	return {"has_bounds": has_bounds, "bounds": bounds}


func _collect_preview_mesh_instances(root: Node, output: Array[MeshInstance3D]) -> void:
	if root is MeshInstance3D:
		output.append(root as MeshInstance3D)
	for child: Node in root.get_children():
		_collect_preview_mesh_instances(child, output)


func _local_transform_to_root(root: Node3D, node: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != root:
		if current is Node3D:
			result = (current as Node3D).transform * result
		current = current.get_parent()
	return result


func _transform_aabb(transform: Transform3D, source: AABB) -> AABB:
	var has_point := false
	var transformed := AABB()
	for index: int in range(8):
		var point := transform * source.get_endpoint(index)
		if not has_point:
			transformed = AABB(point, Vector3.ZERO)
			has_point = true
		else:
			transformed = transformed.expand(point)
	return transformed


func _disable_preview_processing(root: Node) -> void:
	root.process_mode = Node.PROCESS_MODE_DISABLED
	root.set_process(false)
	root.set_physics_process(false)
	root.set_process_input(false)
	root.set_process_unhandled_input(false)
	for child: Node in root.get_children():
		_disable_preview_processing(child)


func _position_preview_camera() -> void:
	if _preview_camera == null:
		return
	var elevation_radians := deg_to_rad(PREVIEW_CAMERA_ELEVATION_DEGREES)
	var camera_position := Vector3(0.0, sin(elevation_radians) * PREVIEW_CAMERA_DISTANCE, cos(elevation_radians) * PREVIEW_CAMERA_DISTANCE)
	_preview_camera.look_at_from_position(camera_position, Vector3(0.0, 0.85, 0.0), Vector3.UP)


func _on_preview_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			_preview_dragging = mouse_button.pressed
			_preview_last_mouse = mouse_button.position
	elif event is InputEventMouseMotion and _preview_dragging and _preview_turntable != null:
		var motion := event as InputEventMouseMotion
		var delta := motion.position - _preview_last_mouse
		_preview_turntable.rotation_degrees.y += delta.x * 0.35
		_preview_last_mouse = motion.position


func _go_back() -> void:
	if _active_view == VIEW_TRACK_SELECT:
		_show_view(VIEW_CAR_SELECT)
	elif _active_view == VIEW_CAR_SELECT:
		_show_view(VIEW_HOME)
	elif _settings_visible:
		_toggle_settings()


func _queue_rebuild() -> void:
	if _rebuild_queued:
		return
	_rebuild_queued = true
	call_deferred("_rebuild_after_resize")


func _rebuild_after_resize() -> void:
	_rebuild_queued = false
	_build_interface()


func _start_menu_audio() -> void:
	var menu_audio_controller_script := load(MENU_AUDIO_CONTROLLER_SCRIPT_PATH) as Script
	if menu_audio_controller_script == null:
		return
	_menu_audio = menu_audio_controller_script.call("resolve", self) as Node
	if _menu_audio == null:
		return
	if _menu_audio.has_method("play_menu_music"):
		_menu_audio.call("play_menu_music")
	_bind_menu_audio()


func _bind_menu_audio() -> void:
	if _menu_audio != null and _menu_audio.has_method("bind_buttons"):
		_menu_audio.call("bind_buttons", self)


func _stop_menu_audio(fade_seconds: float) -> void:
	if _menu_audio != null and _menu_audio.has_method("stop_menu_music"):
		_menu_audio.call("stop_menu_music", fade_seconds)


func _session() -> Node:
	return get_node_or_null("/root/GameSession")


func _car_options() -> Array:
	var session := _session()
	if session != null and session.has_method("get_car_options"):
		var value: Variant = session.call("get_car_options")
		if value is Array:
			return value
	return []


func _track_options() -> Array:
	var session := _session()
	if session != null and session.has_method("get_track_options"):
		var value: Variant = session.call("get_track_options")
		if value is Array:
			return value
	return []


func _difficulty_options() -> Array:
	var session := _session()
	if session != null and session.has_method("get_difficulty_options"):
		var value: Variant = session.call("get_difficulty_options")
		if value is Array:
			return value
	return []


func _skin_presets() -> Array:
	var session := _session()
	if session != null and session.has_method("get_skin_presets"):
		var value: Variant = session.call("get_skin_presets")
		if value is Array:
			return value
	return []


func _selected_car_option() -> Dictionary:
	return _car_option(_selected_car_id)


func _displayed_car_option() -> Dictionary:
	return _car_option(_preview_car_id) if _preview_car_id != &"" else _selected_car_option()


func _selected_skin_option() -> Dictionary:
	var session := _session()
	if session != null and session.has_method("get_selected_skin_preset"):
		var value: Variant = session.call("get_selected_skin_preset")
		if value is Dictionary:
			return value
	return {}


func _displayed_skin_option() -> Dictionary:
	var car := _displayed_car_option()
	var car_id := StringName(car.get("id", &""))
	if car_id == _selected_car_id:
		return _selected_skin_option()
	return _skin_option(StringName(car.get("default_skin_id", _selected_skin_id)))


func _selected_track_option() -> Dictionary:
	return _track_option(_selected_track_id)


func _displayed_track_option() -> Dictionary:
	return _track_option(_preview_track_id) if _preview_track_id != &"" else _selected_track_option()


func _selected_difficulty_option() -> Dictionary:
	return _difficulty_option(StringName(_selected_difficulty_id))


func _car_option(car_id: StringName) -> Dictionary:
	for option: Dictionary in _car_options():
		if StringName(option.get("id", &"")) == car_id:
			return option
	var options := _car_options()
	return options[0] if not options.is_empty() else {}


func _track_option(track_id: StringName) -> Dictionary:
	for option: Dictionary in _track_options():
		if StringName(option.get("id", &"")) == track_id:
			return option
	var options := _track_options()
	return options[0] if not options.is_empty() else {}


func _difficulty_option(difficulty_id: StringName) -> Dictionary:
	for option: Dictionary in _difficulty_options():
		if StringName(option.get("id", &"")) == difficulty_id:
			return option
	var options := _difficulty_options()
	return options[0] if not options.is_empty() else {}


func _skin_option(skin_id: StringName) -> Dictionary:
	for skin: Dictionary in _skin_presets():
		if StringName(skin.get("id", &"")) == skin_id:
			return skin
	return _selected_skin_option()


func _skin_options_for_selected_car() -> Array:
	var car := _selected_car_option()
	var allowed: Array = car.get("skin_ids", [])
	var result: Array = []
	for skin: Dictionary in _skin_presets():
		if allowed.has(StringName(skin.get("id", &""))):
			result.append(skin)
	return result


func _selected_car_color() -> String:
	var session := _session()
	if session != null and session.has_method("get_car_color"):
		return str(session.call("get_car_color"))
	return "blue"


func _displayed_car_color() -> String:
	var skin := _displayed_skin_option()
	if not skin.is_empty():
		return str(skin.get("color_variant", _selected_car_color()))
	return _selected_car_color()


func _car_preview_instance_path() -> String:
	var car := _displayed_car_option()
	return str(car.get("preview_scene_path", car.get("scene_path", "res://scenes/player_car.tscn")))


func _swatch_for_car(car: Dictionary) -> Color:
	var default_skin_id := StringName(car.get("default_skin_id", &""))
	for skin: Dictionary in _skin_presets():
		if StringName(skin.get("id", &"")) == default_skin_id:
			return _safe_color(skin.get("swatch", Color.WHITE))
	return Color(0.46, 0.84, 1.0, 1.0)


func _safe_color(value: Variant) -> Color:
	if value is Color:
		return value
	return Color.WHITE


func _load_track_preview_texture(track: Dictionary) -> Texture2D:
	var path := str(track.get("preview_texture_path", ""))
	if path.is_empty():
		return _get_menu_background_texture()
	var texture := load(path) as Texture2D
	return texture if texture != null else _get_menu_background_texture()


func _load_car_card_texture(car: Dictionary) -> Texture2D:
	var path := str(car.get("preview_texture_path", DEFAULT_CAR_CARD_TEXTURE_PATH))
	if path.is_empty():
		path = DEFAULT_CAR_CARD_TEXTURE_PATH
	var texture := load(path) as Texture2D
	if texture != null:
		return texture
	if _car_card_texture == null and ResourceLoader.exists(DEFAULT_CAR_CARD_TEXTURE_PATH):
		_car_card_texture = load(DEFAULT_CAR_CARD_TEXTURE_PATH) as Texture2D
	return _car_card_texture if _car_card_texture != null else _get_menu_background_texture()


func _get_menu_background_texture() -> Texture2D:
	if _menu_background_texture == null and ResourceLoader.exists(MENU_BACKGROUND_TEXTURE_PATH):
		_menu_background_texture = load(MENU_BACKGROUND_TEXTURE_PATH) as Texture2D
	return _menu_background_texture


func _selection_card_width() -> float:
	var usable_width := _estimated_card_viewport_width()
	return clampf(usable_width * CHOICE_CARD_SIDE_RATIO, 68.0, 138.0)


func _estimated_card_viewport_width() -> float:
	var viewport_width := get_viewport_rect().size.x
	var estimated_safe_margins := float(_space(36, 70) * 2)
	var estimated_thin_columns := float(_space(34, 62) * 2)
	var estimated_arrows := float(_space(68, 92) * 2)
	var usable_width := maxf(1.0, viewport_width - estimated_safe_margins - estimated_thin_columns - estimated_arrows)
	return usable_width


func _visible_card_capacity() -> int:
	var step := _selection_card_width() + float(_card_gap())
	if step <= 0.001:
		return 1
	return maxi(1, floori(_estimated_card_viewport_width() / step))


func _card_gap() -> int:
	return _space(14, 28)


func _font_px(minimum: int, maximum: int, vh_ratio: float) -> int:
	return roundi(clampf(get_viewport_rect().size.y * vh_ratio, float(minimum), float(maximum)))


func _space(minimum: int, maximum: int) -> int:
	var ui_scale := clampf(get_viewport_rect().size.y / 1080.0, 0.72, 1.35)
	return roundi(clampf(float(maximum) * ui_scale, float(minimum), float(maximum)))


func _vh(ratio: float, minimum: float, maximum: float) -> float:
	return clampf(get_viewport_rect().size.y * ratio, minimum, maximum)


func _vw(ratio: float, minimum: float, maximum: float) -> float:
	return clampf(get_viewport_rect().size.x * ratio, minimum, maximum)
