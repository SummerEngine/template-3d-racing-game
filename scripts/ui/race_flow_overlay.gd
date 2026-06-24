extends CanvasLayer

const FigmaUIFontScript := preload("res://scripts/ui/figma_ui_fonts.gd")

@export var race_manager_path: NodePath = ^"../Managers/RaceManager"
@export var main_menu_scene_path: String = "res://scenes/ui/main_menu.tscn"

const MENU_AUDIO_CONTROLLER_SCRIPT_PATH: String = "res://scripts/audio/menu_audio_controller.gd"
const COUNTDOWN_TEXTURE_PATHS: Dictionary = {
	3: "res://assets/ui/countdown_3.png",
	2: "res://assets/ui/countdown_2.png",
	1: "res://assets/ui/countdown_1.png",
}
const COLOR_RACING_RED: Color = Color(0.91, 0.0, 0.18, 1.0)
const COLOR_RACING_RED_HOVER: Color = Color(1.0, 0.10, 0.26, 1.0)
const COLOR_TEXT_MAIN: Color = Color(0.94, 0.94, 0.94, 1.0)
const COLOR_TEXT_MUTED: Color = Color(0.48, 0.48, 0.60, 1.0)
const RESULT_BACKGROUND_FALLBACK_PATH: String = "res://assets/ui/menu_showroom_background.png"
const RESULT_MAX_STANDINGS: int = 6
const UI_REFERENCE_SIZE: Vector2 = Vector2(1920.0, 1080.0)
const UI_MIN_SCALE: float = 0.52
const UI_MAX_SCALE: float = 2.25
const COUNTDOWN_GO_SECONDS: float = 0.64

var _race_manager: Node = null
var _countdown_root: Control = null
var _countdown_texture: TextureRect = null
var _countdown_text_label: Label = null
var _countdown_tween: Tween = null
var _last_countdown_whole_seconds: int = -1
var _countdown_showing_go: bool = false
var _overlay_root: Control = null
var _title_label: Label = null
var _body_label: Label = null
var _resume_button: Button = null
var _restart_button: Button = null
var _end_race_button: Button = null
var _main_menu_button: Button = null
var _master_slider: HSlider = null
var _music_slider: HSlider = null
var _sfx_slider: HSlider = null
var _brightness_slider: HSlider = null
var _master_slider_fill: ColorRect = null
var _music_slider_fill: ColorRect = null
var _sfx_slider_fill: ColorRect = null
var _brightness_slider_fill: ColorRect = null
var _master_value_label: Label = null
var _music_value_label: Label = null
var _sfx_value_label: Label = null
var _brightness_value_label: Label = null
var _ui_audio: Node = null
var _results_visible: bool = false
var _results_root: Control = null
var _results_background: TextureRect = null
var _results_title_label: Label = null
var _results_position_label: Label = null
var _results_car_value_label: Label = null
var _results_track_value_label: Label = null
var _results_time_value_label: Label = null
var _results_best_lap_value_label: Label = null
var _results_top_speed_value_label: Label = null
var _results_laps_value_label: Label = null
var _results_standings_list: VBoxContainer = null
var _results_main_menu_button: Button = null
var _results_race_again_button: Button = null
var _max_player_speed_kmh: int = 0
var _last_results: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	layer = 20
	if not get_viewport().size_changed.is_connected(Callable(self, "_refresh_overlay_sizing")):
		get_viewport().size_changed.connect(Callable(self, "_refresh_overlay_sizing"))
	_build_interface()
	call_deferred("_connect_race_manager")


func _process(_delta: float) -> void:
	if not _results_visible:
		_sample_player_top_speed()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _results_visible:
		get_viewport().set_input_as_handled()
		_toggle_pause()


func _build_interface() -> void:
	_build_countdown_interface()

	_overlay_root = Control.new()
	_overlay_root.name = "OverlayRoot"
	_overlay_root.process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_root.visible = false
	add_child(_overlay_root)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.01, 0.013, 0.018, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_root.add_child(dim)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_root.add_child(center)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = _pause_panel_size()
	panel.add_theme_stylebox_override("panel", _make_style(Color(0.050, 0.058, 0.094, 0.97), Color(1.0, 1.0, 1.0, 0.10), 1, 0))
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", _overlay_space(20, 34))
	margin.add_theme_constant_override("margin_top", _overlay_space(18, 30))
	margin.add_theme_constant_override("margin_right", _overlay_space(20, 34))
	margin.add_theme_constant_override("margin_bottom", _overlay_space(18, 30))
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.name = "Content"
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", _overlay_space(9, 16))
	margin.add_child(box)

	var header := HBoxContainer.new()
	header.name = "PauseHeader"
	header.add_theme_constant_override("separation", _overlay_space(9, 14))
	box.add_child(header)
	var accent := ColorRect.new()
	accent.color = COLOR_RACING_RED
	accent.custom_minimum_size = Vector2(maxf(3.0, _overlay_scale() * 3.0), _overlay_space(28, 42))
	header.add_child(accent)
	_title_label = Label.new()
	_title_label.name = "Title"
	_title_label.add_theme_font_size_override("font_size", _overlay_font_px(20, 32, 0.030))
	_title_label.add_theme_color_override("font_color", COLOR_TEXT_MAIN)
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)

	_body_label = Label.new()
	_body_label.name = "Body"
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.add_theme_font_size_override("font_size", _overlay_font_px(12, 18, 0.017))
	_body_label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	box.add_child(_body_label)
	box.add_child(_make_pause_spacer(0.7))

	_resume_button = _make_button("RESUME", Callable(self, "_resume_race"), true)
	box.add_child(_resume_button)
	box.add_child(_make_pause_spacer(0.6))

	box.add_child(_make_section_label("SETTINGS"))
	var master_row := _make_slider_row("Global", Callable(self, "_on_master_percent_changed"))
	_master_slider = master_row["slider"]
	_master_slider_fill = master_row["fill"]
	_master_value_label = master_row["value_label"]
	box.add_child(master_row["root"])
	var music_row := _make_slider_row("Music", Callable(self, "_on_music_percent_changed"))
	_music_slider = music_row["slider"]
	_music_slider_fill = music_row["fill"]
	_music_value_label = music_row["value_label"]
	box.add_child(music_row["root"])
	var sfx_row := _make_slider_row("SFX", Callable(self, "_on_sfx_percent_changed"))
	_sfx_slider = sfx_row["slider"]
	_sfx_slider_fill = sfx_row["fill"]
	_sfx_value_label = sfx_row["value_label"]
	box.add_child(sfx_row["root"])
	var brightness_row := _make_slider_row("Brightness", Callable(self, "_on_brightness_percent_changed"))
	_brightness_slider = brightness_row["slider"]
	_brightness_slider_fill = brightness_row["fill"]
	_brightness_value_label = brightness_row["value_label"]
	box.add_child(brightness_row["root"])
	box.add_child(_make_pause_spacer(0.9))

	box.add_child(_make_section_label("RACE"))
	_restart_button = _make_button("RESTART", Callable(self, "_restart_race"))
	_end_race_button = _make_button("END RACE", Callable(self, "_end_race"))
	_main_menu_button = _make_button("MAIN MENU", Callable(self, "_return_to_main_menu"))
	box.add_child(_restart_button)
	box.add_child(_end_race_button)
	box.add_child(_main_menu_button)
	FigmaUIFontScript.apply_tree(_overlay_root)
	_build_results_interface()
	FigmaUIFontScript.apply_tree(_results_root)
	call_deferred("_bind_ui_audio")


func _build_countdown_interface() -> void:
	_countdown_root = Control.new()
	_countdown_root.name = "CountdownRoot"
	_countdown_root.process_mode = Node.PROCESS_MODE_ALWAYS
	_countdown_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_countdown_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_countdown_root.visible = false
	add_child(_countdown_root)

	var center := CenterContainer.new()
	center.name = "CountdownCenter"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_countdown_root.add_child(center)

	_countdown_texture = TextureRect.new()
	_countdown_texture.name = "CountdownNumber"
	_countdown_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_countdown_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_countdown_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_countdown_texture.modulate = Color(1.0, 1.0, 1.0, 0.0)
	center.add_child(_countdown_texture)

	_countdown_text_label = Label.new()
	_countdown_text_label.name = "CountdownGo"
	_countdown_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_countdown_text_label.visible = false
	_countdown_text_label.text = "GO"
	_countdown_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_countdown_text_label.add_theme_color_override("font_color", COLOR_TEXT_MAIN)
	_countdown_text_label.add_theme_color_override("font_shadow_color", Color(0.91, 0.0, 0.18, 0.78))
	_countdown_text_label.add_theme_constant_override("shadow_offset_x", 0)
	_countdown_text_label.add_theme_constant_override("shadow_offset_y", 0)
	_countdown_text_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	center.add_child(_countdown_text_label)
	FigmaUIFontScript.apply_tree(_countdown_root)


func _build_results_interface() -> void:
	_results_root = Control.new()
	_results_root.name = "ResultsRoot"
	_results_root.process_mode = Node.PROCESS_MODE_ALWAYS
	_results_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_results_root.visible = false
	add_child(_results_root)

	_results_background = TextureRect.new()
	_results_background.name = "ResultsBackground"
	_results_background.texture = _selected_track_texture()
	_results_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_results_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_results_background.modulate = Color(0.54, 0.56, 0.62, 0.42)
	_results_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_results_root.add_child(_results_background)

	var scrim := ColorRect.new()
	scrim.name = "ResultsScrim"
	scrim.color = Color(0.010, 0.011, 0.016, 0.84)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_results_root.add_child(scrim)

	var red_strip := ColorRect.new()
	red_strip.name = "ResultsRedTopAccent"
	red_strip.color = Color(COLOR_RACING_RED, 0.82)
	red_strip.anchor_left = 0.43
	red_strip.anchor_top = 0.0
	red_strip.anchor_right = 0.57
	red_strip.anchor_bottom = 0.0
	red_strip.offset_bottom = _overlay_space(2, 4)
	_results_root.add_child(red_strip)

	var stage := Control.new()
	stage.name = "ResultsStage"
	stage.anchor_left = 0.10
	stage.anchor_top = 0.035
	stage.anchor_right = 0.90
	stage.anchor_bottom = 0.96
	_results_root.add_child(stage)

	_results_title_label = _make_result_label("CLASSIFIED", _overlay_font_px(64, 132, 0.105), COLOR_TEXT_MAIN, true, HORIZONTAL_ALIGNMENT_CENTER)
	_results_title_label.name = "ResultsTitle"
	_results_title_label.anchor_left = 0.0
	_results_title_label.anchor_top = 0.0
	_results_title_label.anchor_right = 1.0
	_results_title_label.anchor_bottom = 0.16
	_results_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stage.add_child(_results_title_label)

	var identity_row := HBoxContainer.new()
	identity_row.name = "ResultIdentityRow"
	identity_row.anchor_left = 0.18
	identity_row.anchor_top = 0.18
	identity_row.anchor_right = 0.82
	identity_row.anchor_bottom = 0.36
	identity_row.alignment = BoxContainer.ALIGNMENT_CENTER
	identity_row.add_theme_constant_override("separation", _overlay_space(28, 56))
	stage.add_child(identity_row)

	var position_card := PanelContainer.new()
	position_card.name = "PositionCard"
	position_card.custom_minimum_size = Vector2(_overlay_space(150, 240), _overlay_space(150, 240))
	position_card.add_theme_stylebox_override("panel", _make_style(Color(0.22, 0.025, 0.050, 0.64), Color(COLOR_RACING_RED, 0.78), 1, 0))
	identity_row.add_child(position_card)

	var position_box := VBoxContainer.new()
	position_box.alignment = BoxContainer.ALIGNMENT_CENTER
	position_box.add_theme_constant_override("separation", _overlay_space(6, 12))
	position_card.add_child(position_box)
	var medal := _make_result_label("MEDAL", _overlay_font_px(11, 18, 0.014), Color(1.0, 0.84, 0.0, 1.0), true, HORIZONTAL_ALIGNMENT_CENTER)
	position_box.add_child(medal)
	var position_caption := _make_result_label("P O S I T I O N", _overlay_font_px(11, 18, 0.014), Color(0.53, 0.52, 0.70, 1.0), false, HORIZONTAL_ALIGNMENT_CENTER)
	position_box.add_child(position_caption)
	_results_position_label = _make_result_label("P--", _overlay_font_px(52, 92, 0.074), COLOR_TEXT_MAIN, true, HORIZONTAL_ALIGNMENT_CENTER)
	position_box.add_child(_results_position_label)

	var identity_details := VBoxContainer.new()
	identity_details.name = "ResultIdentityDetails"
	identity_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity_details.alignment = BoxContainer.ALIGNMENT_CENTER
	identity_details.add_theme_constant_override("separation", _overlay_space(8, 16))
	identity_row.add_child(identity_details)
	identity_details.add_child(_make_result_label("C A R", _overlay_font_px(10, 17, 0.013), Color(0.42, 0.42, 0.58, 1.0), false, HORIZONTAL_ALIGNMENT_LEFT))
	_results_car_value_label = _make_result_label("--", _overlay_font_px(20, 34, 0.028), COLOR_TEXT_MAIN, true, HORIZONTAL_ALIGNMENT_LEFT)
	_configure_result_value_label(_results_car_value_label)
	identity_details.add_child(_results_car_value_label)
	identity_details.add_child(_make_result_label("C I R C U I T", _overlay_font_px(10, 17, 0.013), Color(0.42, 0.42, 0.58, 1.0), false, HORIZONTAL_ALIGNMENT_LEFT))
	_results_track_value_label = _make_result_label("--", _overlay_font_px(18, 30, 0.025), COLOR_TEXT_MAIN, true, HORIZONTAL_ALIGNMENT_LEFT)
	_configure_result_value_label(_results_track_value_label)
	identity_details.add_child(_results_track_value_label)

	var metrics_grid := GridContainer.new()
	metrics_grid.name = "ResultsMetrics"
	metrics_grid.columns = 2
	metrics_grid.anchor_left = 0.02
	metrics_grid.anchor_top = 0.39
	metrics_grid.anchor_right = 0.98
	metrics_grid.anchor_bottom = 0.57
	metrics_grid.add_theme_constant_override("h_separation", _overlay_space(16, 28))
	metrics_grid.add_theme_constant_override("v_separation", _overlay_space(14, 24))
	stage.add_child(metrics_grid)
	_results_time_value_label = _add_metric_card(metrics_grid, "R A C E  T I M E", "--:--.---", Color(0.92, 0.92, 0.95, 1.0))
	_results_best_lap_value_label = _add_metric_card(metrics_grid, "B E S T  L A P", "--:--.---", Color(0.0, 1.0, 0.48, 1.0))
	_results_top_speed_value_label = _add_metric_card(metrics_grid, "T O P  S P E E D", "-- km/h", Color(0.0, 0.80, 1.0, 1.0))
	_results_laps_value_label = _add_metric_card(metrics_grid, "L A P S", "-- / --", COLOR_TEXT_MAIN)

	var standings_title := _make_result_label("F I N A L  S T A N D I N G S", _overlay_font_px(11, 18, 0.014), Color(0.45, 0.44, 0.62, 1.0), false, HORIZONTAL_ALIGNMENT_LEFT)
	standings_title.anchor_left = 0.02
	standings_title.anchor_top = 0.61
	standings_title.anchor_right = 0.98
	standings_title.anchor_bottom = 0.65
	standings_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stage.add_child(standings_title)

	var standings_panel := PanelContainer.new()
	standings_panel.name = "StandingsPanel"
	standings_panel.anchor_left = 0.02
	standings_panel.anchor_top = 0.655
	standings_panel.anchor_right = 0.98
	standings_panel.anchor_bottom = 0.88
	standings_panel.add_theme_stylebox_override("panel", _make_style(Color(0.024, 0.026, 0.034, 0.74), Color(1.0, 1.0, 1.0, 0.10), 1, 0))
	stage.add_child(standings_panel)
	_results_standings_list = VBoxContainer.new()
	_results_standings_list.name = "StandingsList"
	_results_standings_list.add_theme_constant_override("separation", 0)
	standings_panel.add_child(_wrap_with_margin(_results_standings_list, _overlay_space(0, 0), _overlay_space(0, 0)))

	var button_row := HBoxContainer.new()
	button_row.name = "ResultsButtons"
	button_row.anchor_left = 0.02
	button_row.anchor_top = 0.92
	button_row.anchor_right = 0.98
	button_row.anchor_bottom = 1.0
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", _overlay_space(22, 42))
	stage.add_child(button_row)
	_results_main_menu_button = _make_button("<  MAIN MENU", Callable(self, "_return_to_main_menu"))
	_results_main_menu_button.custom_minimum_size = Vector2(_overlay_vw(0.22, 220.0, 420.0), _overlay_vh(0.058, 44.0, 68.0))
	_apply_result_button_typography(_results_main_menu_button)
	button_row.add_child(_results_main_menu_button)
	_results_race_again_button = _make_button(">  RACE AGAIN", Callable(self, "_restart_race"), true)
	_results_race_again_button.custom_minimum_size = Vector2(_overlay_vw(0.32, 280.0, 520.0), _overlay_vh(0.066, 50.0, 78.0))
	_apply_result_button_typography(_results_race_again_button)
	button_row.add_child(_results_race_again_button)


func _connect_race_manager() -> void:
	_race_manager = get_node_or_null(race_manager_path)
	if _race_manager == null:
		_race_manager = _find_node_by_name(get_tree().current_scene, &"RaceManager")
	if _race_manager != null and _race_manager.has_signal("race_finished"):
		if not _race_manager.race_finished.is_connected(Callable(self, "_on_race_finished")):
			_race_manager.race_finished.connect(Callable(self, "_on_race_finished"))
	if _race_manager != null and _race_manager.has_signal("countdown_changed"):
		if not _race_manager.countdown_changed.is_connected(Callable(self, "_on_countdown_changed")):
			_race_manager.countdown_changed.connect(Callable(self, "_on_countdown_changed"))
	if _race_manager != null and _race_manager.has_signal("race_started"):
		if not _race_manager.race_started.is_connected(Callable(self, "_on_race_started")):
			_race_manager.race_started.connect(Callable(self, "_on_race_started"))


func _toggle_pause() -> void:
	if get_tree().paused:
		_resume_race()
	else:
		_show_pause()


func _show_pause() -> void:
	_results_visible = false
	if _results_root != null:
		_results_root.visible = false
	_title_label.text = "PAUSED"
	_body_label.text = "PRESS ESC TO RESUME"
	_resume_button.visible = true
	if _end_race_button != null:
		_end_race_button.visible = true
	_overlay_root.visible = true
	_sync_settings_ui()
	get_tree().paused = true
	_resume_button.grab_focus()


func _resume_race() -> void:
	if _results_visible:
		return
	get_tree().paused = false
	_overlay_root.visible = false


func _restart_race() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _end_race() -> void:
	get_tree().paused = false
	if _race_manager == null:
		_connect_race_manager()
	if _race_manager != null and _race_manager.has_method("finish_race"):
		_race_manager.call("finish_race")
		return
	_return_to_main_menu()


func _return_to_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(main_menu_scene_path)


func _on_race_finished(results: Array) -> void:
	_hide_countdown()
	_results_visible = true
	_last_results = results.duplicate()
	_overlay_root.visible = false
	_show_results_screen(results)
	get_tree().paused = true
	if _results_race_again_button != null:
		_results_race_again_button.grab_focus()


func _on_race_started() -> void:
	_max_player_speed_kmh = 0
	_results_visible = false
	if _results_root != null:
		_results_root.visible = false
	if not _countdown_showing_go:
		_hide_countdown()


func _on_countdown_changed(_time_remaining_seconds: float, whole_seconds: int) -> void:
	if whole_seconds <= 0:
		if _last_countdown_whole_seconds != 0:
			_last_countdown_whole_seconds = 0
			_show_countdown_go()
			return
		_last_countdown_whole_seconds = 0
		return
	if whole_seconds > 3 or whole_seconds == _last_countdown_whole_seconds:
		return
	_last_countdown_whole_seconds = whole_seconds
	_show_countdown_number(whole_seconds)


func _show_countdown_number(value: int) -> void:
	if _countdown_root == null or _countdown_texture == null:
		return
	var texture_path := _countdown_texture_path(value)
	if texture_path.is_empty():
		return
	var texture := load(texture_path) as Texture2D
	if texture == null:
		return

	var side := _countdown_sprite_side()
	_countdown_showing_go = false
	if _countdown_text_label != null:
		_countdown_text_label.visible = false
	_countdown_texture.texture = texture
	_countdown_texture.visible = true
	_countdown_texture.custom_minimum_size = Vector2(side, side)
	_countdown_texture.pivot_offset = Vector2(side, side) * 0.5
	_countdown_texture.scale = Vector2(0.82, 0.82)
	_countdown_texture.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_countdown_root.visible = true

	if _countdown_tween != null:
		_countdown_tween.kill()
	_countdown_tween = create_tween()
	_countdown_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_countdown_tween.set_trans(Tween.TRANS_QUAD)
	_countdown_tween.set_ease(Tween.EASE_OUT)
	_countdown_tween.tween_property(_countdown_texture, "modulate:a", 1.0, 0.14)
	_countdown_tween.parallel().tween_property(_countdown_texture, "scale", Vector2(1.08, 1.08), 0.14)
	_countdown_tween.tween_interval(0.18)
	_countdown_tween.tween_property(_countdown_texture, "scale", Vector2(1.24, 1.24), 0.30)
	_countdown_tween.parallel().tween_property(_countdown_texture, "modulate:a", 0.0, 0.30)
	_countdown_tween.finished.connect(Callable(self, "_hide_countdown_after_number").bind(value))


func _show_countdown_go() -> void:
	if _countdown_root == null or _countdown_text_label == null:
		return
	var side := _countdown_sprite_side()
	_countdown_showing_go = true
	if _countdown_texture != null:
		_countdown_texture.visible = false
	_countdown_text_label.visible = true
	_countdown_text_label.text = "GO"
	_countdown_text_label.custom_minimum_size = Vector2(side * 1.45, side * 0.72)
	_countdown_text_label.pivot_offset = _countdown_text_label.custom_minimum_size * 0.5
	_countdown_text_label.add_theme_font_size_override("font_size", roundi(clampf(side * 0.38, 84.0, 180.0)))
	_countdown_text_label.scale = Vector2(0.82, 0.82)
	_countdown_text_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_countdown_root.visible = true

	if _countdown_tween != null:
		_countdown_tween.kill()
	_countdown_tween = create_tween()
	_countdown_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_countdown_tween.set_trans(Tween.TRANS_QUAD)
	_countdown_tween.set_ease(Tween.EASE_OUT)
	_countdown_tween.tween_property(_countdown_text_label, "modulate:a", 1.0, 0.12)
	_countdown_tween.parallel().tween_property(_countdown_text_label, "scale", Vector2(1.12, 1.12), 0.12)
	_countdown_tween.tween_interval(COUNTDOWN_GO_SECONDS * 0.32)
	_countdown_tween.tween_property(_countdown_text_label, "scale", Vector2(1.28, 1.28), COUNTDOWN_GO_SECONDS * 0.48)
	_countdown_tween.parallel().tween_property(_countdown_text_label, "modulate:a", 0.0, COUNTDOWN_GO_SECONDS * 0.48)
	_countdown_tween.finished.connect(Callable(self, "_hide_countdown_after_number").bind(0))


func _hide_countdown_after_number(value: int) -> void:
	if _last_countdown_whole_seconds == value and _countdown_root != null:
		_countdown_root.visible = false
		if value == 0:
			_countdown_showing_go = false


func _hide_countdown() -> void:
	if _countdown_tween != null:
		_countdown_tween.kill()
		_countdown_tween = null
	if _countdown_root != null:
		_countdown_root.visible = false
	if _countdown_text_label != null:
		_countdown_text_label.visible = false
	_countdown_showing_go = false


func _countdown_texture_path(value: int) -> String:
	return str(COUNTDOWN_TEXTURE_PATHS.get(value, ""))


func _countdown_sprite_side() -> float:
	var viewport_size := get_viewport().get_visible_rect().size
	return clampf(minf(viewport_size.x, viewport_size.y) * 0.28, 180.0, 420.0)


func _show_results_screen(results: Array) -> void:
	if _results_root == null:
		return
	var rows: Array[Dictionary] = _result_rows(results)
	var player_row: Dictionary = _player_result_row(rows)
	var placement: int = int(player_row.get("placement", 0))
	var participant_count: int = rows.size()
	if participant_count <= 0:
		participant_count = _race_participant_count()

	if _results_background != null:
		_results_background.texture = _selected_track_texture()
	if _results_title_label != null:
		_results_title_label.text = "CLASSIFIED" if placement > 0 and placement <= 3 else "GAME OVER"
	if _results_position_label != null:
		_results_position_label.text = "P%d" % placement if placement > 0 else "P--"
	if _results_car_value_label != null:
		_results_car_value_label.text = _selected_car_display_name()
	if _results_track_value_label != null:
		_results_track_value_label.text = _selected_track_display_name()
	if _results_time_value_label != null:
		_results_time_value_label.text = _race_time_text(player_row)
	if _results_best_lap_value_label != null:
		_results_best_lap_value_label.text = _best_lap_text(player_row)
	if _results_top_speed_value_label != null:
		_results_top_speed_value_label.text = _top_speed_text()
	if _results_laps_value_label != null:
		_results_laps_value_label.text = _laps_text(player_row)

	_populate_standings(rows)
	_results_root.visible = true


func _result_rows(results: Array) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for result_value: Variant in results:
		var row := _result_to_dictionary(result_value)
		if not row.is_empty():
			rows.append(row)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("placement", 9999)) < int(b.get("placement", 9999))
	)
	return rows


func _result_to_dictionary(result_value: Variant) -> Dictionary:
	if result_value == null:
		return {}
	if result_value is Dictionary:
		return (result_value as Dictionary).duplicate(true)
	if result_value is Object and (result_value as Object).has_method("to_dictionary"):
		var dictionary_value: Variant = (result_value as Object).call("to_dictionary")
		if dictionary_value is Dictionary:
			return (dictionary_value as Dictionary).duplicate(true)
	return {}


func _player_result_row(rows: Array[Dictionary]) -> Dictionary:
	for row: Dictionary in rows:
		if bool(row.get("is_player", false)):
			return row
	return rows[0] if not rows.is_empty() else {}


func _populate_standings(rows: Array[Dictionary]) -> void:
	if _results_standings_list == null:
		return
	for child: Node in _results_standings_list.get_children():
		_results_standings_list.remove_child(child)
		child.queue_free()
	if rows.is_empty():
		_results_standings_list.add_child(_make_empty_standing_row())
		return
	var leader_time_msec := _leader_time_msec(rows)
	for index: int in range(mini(rows.size(), RESULT_MAX_STANDINGS)):
		_results_standings_list.add_child(_make_standing_row(rows[index], leader_time_msec))


func _make_empty_standing_row() -> Control:
	var label := _make_result_label("No standings available yet.", _overlay_font_px(15, 24, 0.020), COLOR_TEXT_MUTED, false, HORIZONTAL_ALIGNMENT_CENTER)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(1.0, _overlay_space(44, 64))
	return label


func _make_standing_row(row: Dictionary, leader_time_msec: int) -> PanelContainer:
	var is_player := bool(row.get("is_player", false))
	var placement := int(row.get("placement", 0))
	var panel := PanelContainer.new()
	panel.name = "StandingRow"
	panel.custom_minimum_size = Vector2(1.0, _overlay_space(42, 68))
	var fill := Color(0.020, 0.022, 0.030, 0.58)
	var border := Color(1.0, 1.0, 1.0, 0.06)
	if is_player:
		fill = Color(COLOR_RACING_RED.r, COLOR_RACING_RED.g, COLOR_RACING_RED.b, 0.24)
		border = Color(COLOR_RACING_RED.r, COLOR_RACING_RED.g, COLOR_RACING_RED.b, 0.28)
	panel.add_theme_stylebox_override("panel", _make_style(fill, border, 1, 0))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", _overlay_space(20, 34))
	margin.add_theme_constant_override("margin_right", _overlay_space(20, 34))
	margin.add_theme_constant_override("margin_top", _overlay_space(4, 8))
	margin.add_theme_constant_override("margin_bottom", _overlay_space(4, 8))
	panel.add_child(margin)

	var row_box := HBoxContainer.new()
	row_box.alignment = BoxContainer.ALIGNMENT_CENTER
	row_box.add_theme_constant_override("separation", _overlay_space(16, 28))
	margin.add_child(row_box)

	var place_label := _make_result_label(str(placement), _overlay_font_px(17, 30, 0.024), COLOR_RACING_RED if is_player else Color(0.40, 0.39, 0.54, 1.0), true, HORIZONTAL_ALIGNMENT_CENTER)
	place_label.custom_minimum_size.x = _overlay_space(34, 52)
	row_box.add_child(place_label)

	var name_text := "YOU" if is_player else str(row.get("display_name", "Racer"))
	var name_label := _make_result_label(name_text, _overlay_font_px(15, 25, 0.021), COLOR_TEXT_MAIN if is_player else Color(0.56, 0.55, 0.72, 1.0), true, HORIZONTAL_ALIGNMENT_LEFT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_box.add_child(name_label)

	var time_label := _make_result_label(_standing_time_text(row, leader_time_msec), _overlay_font_px(15, 25, 0.021), Color(0.0, 1.0, 0.48, 1.0) if is_player else Color(0.40, 0.39, 0.54, 1.0), true, HORIZONTAL_ALIGNMENT_RIGHT)
	time_label.custom_minimum_size.x = _overlay_space(96, 150)
	row_box.add_child(time_label)
	return panel


func _leader_time_msec(rows: Array[Dictionary]) -> int:
	var leader_time := -1
	for row: Dictionary in rows:
		var time_msec := int(row.get("total_time_msec", -1))
		if time_msec < 0:
			continue
		if leader_time < 0 or time_msec < leader_time:
			leader_time = time_msec
	return leader_time


func _standing_time_text(row: Dictionary, leader_time_msec: int) -> String:
	var time_msec := int(row.get("total_time_msec", -1))
	if time_msec < 0:
		return "--:--.---"
	if leader_time_msec >= 0 and time_msec > leader_time_msec:
		return "+%.3f" % (float(time_msec - leader_time_msec) / 1000.0)
	return str(row.get("formatted_total_time", _format_time_msec(time_msec)))


func _race_time_text(player_row: Dictionary) -> String:
	var formatted := str(player_row.get("formatted_total_time", ""))
	if not formatted.is_empty() and formatted != "--:--.---":
		return formatted
	var race_time_msec := -1
	if _race_manager != null and _race_manager.has_method("get_race_time_msec"):
		var value: Variant = _race_manager.call("get_race_time_msec")
		if value is int or value is float:
			race_time_msec = int(value)
	return _format_time_msec(race_time_msec)


func _best_lap_text(player_row: Dictionary) -> String:
	var total_time_msec := int(player_row.get("total_time_msec", -1))
	var completed_laps := int(player_row.get("completed_laps", 0))
	if total_time_msec < 0:
		return "--:--.---"
	completed_laps = maxi(completed_laps, 1)
	return _format_time_msec(roundi(float(total_time_msec) / float(completed_laps)))


func _top_speed_text() -> String:
	if _max_player_speed_kmh > 0:
		return "%d km/h" % _max_player_speed_kmh
	var fallback_speed := _selected_car_max_speed_kmh()
	return "%d km/h" % fallback_speed if fallback_speed > 0 else "-- km/h"


func _laps_text(player_row: Dictionary) -> String:
	var completed := int(player_row.get("completed_laps", 0))
	var total := _selected_track_lap_count()
	if completed <= 0:
		completed = total if total > 0 else 0
	return "%d / %d" % [completed, total] if total > 0 else "%d / --" % completed


func _format_time_msec(time_msec: int) -> String:
	if time_msec < 0:
		return "--:--.---"
	var total_seconds := int(float(time_msec) / 1000.0)
	var minutes := int(float(total_seconds) / 60.0)
	var seconds := total_seconds % 60
	var millis := time_msec % 1000
	return "%02d:%02d.%03d" % [minutes, seconds, millis]


func _format_results(results: Array) -> String:
	if results.is_empty():
		return "Race complete."

	var rows: Array[Dictionary] = []
	var player_row: Dictionary = {}
	var lines: Array[String] = []
	for result_value: Variant in results:
		if result_value == null:
			continue
		var row: Dictionary = {}
		if result_value is Dictionary:
			row = result_value
		elif result_value.has_method("to_dictionary"):
			var dictionary_value: Variant = result_value.call("to_dictionary")
			if dictionary_value is Dictionary:
				row = dictionary_value
		if row.is_empty():
			continue
		rows.append(row)
		if bool(row.get("is_player", false)):
			player_row = row
		var placement: int = int(row.get("placement", lines.size() + 1))
		var display_name: String = str(row.get("display_name", "Racer"))
		var formatted_time: String = str(row.get("formatted_total_time", "--:--.---"))
		lines.append("%d. %s  %s" % [placement, display_name, formatted_time])

	if lines.is_empty():
		return "Race complete."

	if player_row.is_empty():
		return "Final Standings\n%s" % "\n".join(lines)

	var player_placement: int = int(player_row.get("placement", 0))
	var player_time: String = str(player_row.get("formatted_total_time", "--:--.---"))
	var player_feedback: String = _feedback_for_player_result(player_placement, rows.size())
	return "%s\n\nYour result: %s/%d\nTime: %s\n\nFinal Standings\n%s" % [
		player_feedback,
		ordinal(player_placement),
		rows.size(),
		player_time,
		"\n".join(lines),
	]


func _feedback_for_player_result(placement: int, participant_count: int) -> String:
	if placement <= 0:
		return "Race complete."
	if placement == 1:
		return "Victory. You controlled the race."
	if placement <= 3:
		return "Podium finish. Strong pace, a few places still on the table."
	if participant_count > 0 and placement == participant_count:
		return "Finished, but the field got away. Brake earlier, exit faster."
	return "Solid finish. Cleaner exits and fewer wall touches will move you up."


func _sample_player_top_speed() -> void:
	var player := _player_vehicle()
	if player == null:
		return
	var speed_mps := 0.0
	if player.has_method("get_speed"):
		var speed_value: Variant = player.call("get_speed")
		if speed_value is int or speed_value is float:
			speed_mps = maxf(0.0, float(speed_value))
	elif _has_property(player, &"velocity"):
		var velocity_value: Variant = player.get("velocity")
		if velocity_value is Vector3:
			var velocity_3d := velocity_value as Vector3
			speed_mps = Vector3(velocity_3d.x, 0.0, velocity_3d.z).length()
	_max_player_speed_kmh = maxi(_max_player_speed_kmh, roundi(speed_mps * 3.6))


func _player_vehicle() -> Node:
	if _race_manager == null:
		_connect_race_manager()
	if _race_manager != null and _race_manager.has_method("get_player_participant"):
		var participant: Variant = _race_manager.call("get_player_participant")
		if participant is Object:
			var node_value: Variant = (participant as Object).get("participant_node")
			if node_value is Node:
				return node_value as Node
	var current_scene := get_tree().current_scene
	var by_name := _find_node_by_name(current_scene, &"PlayerCar")
	if by_name != null:
		return by_name
	return _find_node_with_method(current_scene, &"get_speed")


func _find_node_with_method(root: Node, method_name: StringName) -> Node:
	if root == null:
		return null
	if root.has_method(String(method_name)):
		return root
	for child: Node in root.get_children():
		var found := _find_node_with_method(child, method_name)
		if found != null:
			return found
	return null


func _has_property(object: Object, property_name: StringName) -> bool:
	if object == null:
		return false
	for property: Dictionary in object.get_property_list():
		if StringName(property.get("name", &"")) == property_name:
			return true
	return false


func _race_participant_count() -> int:
	if _race_manager != null and _race_manager.has_method("get_ui_snapshot"):
		var snapshot_value: Variant = _race_manager.call("get_ui_snapshot")
		if snapshot_value is Dictionary:
			return int((snapshot_value as Dictionary).get("participant_count", 0))
	return 0


func _selected_car_display_name() -> String:
	var session := _session()
	if session != null and session.has_method("get_selected_car_option"):
		var value: Variant = session.call("get_selected_car_option")
		if value is Dictionary:
			return str((value as Dictionary).get("display_name", "Selected Car"))
	return "Selected Car"


func _selected_track_display_name() -> String:
	var session := _session()
	if session != null and session.has_method("get_selected_track_option"):
		var value: Variant = session.call("get_selected_track_option")
		if value is Dictionary:
			return str((value as Dictionary).get("display_name", "Selected Track"))
	return "Selected Track"


func _selected_track_lap_count() -> int:
	var session := _session()
	if session != null and session.has_method("get_selected_track_option"):
		var value: Variant = session.call("get_selected_track_option")
		if value is Dictionary:
			return int((value as Dictionary).get("lap_count", 0))
	return 0


func _selected_car_max_speed_kmh() -> int:
	var session := _session()
	if session != null and session.has_method("get_selected_car_option"):
		var value: Variant = session.call("get_selected_car_option")
		if value is Dictionary:
			var overrides: Dictionary = (value as Dictionary).get("driving_overrides", {})
			var max_speed_value: Variant = overrides.get("max_speed", 0.0)
			if max_speed_value is int or max_speed_value is float:
				return roundi(maxf(0.0, float(max_speed_value)) * 3.6)
	return 0


func _selected_track_texture() -> Texture2D:
	var session := _session()
	if session != null and session.has_method("get_selected_track_option"):
		var value: Variant = session.call("get_selected_track_option")
		if value is Dictionary:
			var path := str((value as Dictionary).get("preview_texture_path", ""))
			var track_texture := _load_texture_safely(path)
			if track_texture != null:
				return track_texture
	var fallback := _load_texture_safely(RESULT_BACKGROUND_FALLBACK_PATH)
	return fallback


func _load_texture_safely(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if FileAccess.file_exists("%s.import" % path):
		var imported_texture := load(path) as Texture2D
		if imported_texture != null:
			return imported_texture
	return _load_raw_texture(path)


func _load_raw_texture(path: String) -> Texture2D:
	var image := Image.new()
	var error := image.load(ProjectSettings.globalize_path(path))
	if error != OK:
		return null
	return ImageTexture.create_from_image(image)


func ordinal(value: int) -> String:
	var suffix := "th"
	var mod_100 := value % 100
	if mod_100 < 11 or mod_100 > 13:
		match value % 10:
			1:
				suffix = "st"
			2:
				suffix = "nd"
			3:
				suffix = "rd"
	return "%d%s" % [value, suffix]


func _make_result_label(text: String, font_size: int, color: Color, bold: bool, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = alignment
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if bold:
		label.add_theme_constant_override("outline_size", 1)
		label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.28))
	return label


func _configure_result_value_label(label: Label) -> void:
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.max_lines_visible = 2


func _add_metric_card(parent: Control, caption_text: String, value_text: String, accent: Color) -> Label:
	var panel := PanelContainer.new()
	panel.name = "ResultMetricCard"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(1.0, _overlay_space(74, 116))
	panel.add_theme_stylebox_override("panel", _make_style(Color(0.050, 0.052, 0.064, 0.38), Color(1.0, 1.0, 1.0, 0.10), 1, 0))
	parent.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", _overlay_space(18, 34))
	margin.add_theme_constant_override("margin_right", _overlay_space(18, 34))
	margin.add_theme_constant_override("margin_top", _overlay_space(12, 22))
	margin.add_theme_constant_override("margin_bottom", _overlay_space(10, 18))
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", _overlay_space(6, 12))
	margin.add_child(stack)

	var caption := _make_result_label(caption_text, _overlay_font_px(10, 17, 0.013), Color(0.45, 0.44, 0.60, 1.0), false, HORIZONTAL_ALIGNMENT_LEFT)
	stack.add_child(caption)
	var value := _make_result_label(value_text, _overlay_font_px(19, 34, 0.028), accent, true, HORIZONTAL_ALIGNMENT_LEFT)
	stack.add_child(value)
	return value


func _wrap_with_margin(child: Control, horizontal_margin: int, vertical_margin: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", horizontal_margin)
	margin.add_theme_constant_override("margin_right", horizontal_margin)
	margin.add_theme_constant_override("margin_top", vertical_margin)
	margin.add_theme_constant_override("margin_bottom", vertical_margin)
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	child.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(child)
	return margin


func _make_section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text.to_upper()
	label.add_theme_font_size_override("font_size", _overlay_font_px(9, 13, 0.012))
	label.add_theme_color_override("font_color", Color(0.34, 0.34, 0.48, 1.0))
	return label


func _make_pause_spacer(stretch_ratio: float = 1.0) -> Control:
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.custom_minimum_size = Vector2(1.0, _overlay_space(6, 12))
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.size_flags_stretch_ratio = maxf(stretch_ratio, 0.1)
	return spacer


func _pause_panel_size() -> Vector2:
	var viewport_size := get_viewport().get_visible_rect().size
	return Vector2(
		_overlay_vw(0.42, 300.0, 560.0),
		clampf(viewport_size.y * 0.86, 360.0 * minf(_overlay_scale(), 1.0), 600.0 * maxf(_overlay_scale(), 1.0))
	)


func _refresh_overlay_sizing() -> void:
	if _countdown_texture != null and _countdown_texture.texture != null:
		var side := _countdown_sprite_side()
		_countdown_texture.custom_minimum_size = Vector2(side, side)
		_countdown_texture.pivot_offset = Vector2(side, side) * 0.5
	if _countdown_text_label != null and _countdown_text_label.visible:
		var text_side := _countdown_sprite_side()
		_countdown_text_label.custom_minimum_size = Vector2(text_side * 1.45, text_side * 0.72)
		_countdown_text_label.pivot_offset = _countdown_text_label.custom_minimum_size * 0.5
		_countdown_text_label.add_theme_font_size_override("font_size", roundi(clampf(text_side * 0.38, 84.0, 180.0)))
	if _overlay_root != null:
		var panel := _overlay_root.get_node_or_null("Center/Panel") as PanelContainer
		if panel != null:
			panel.custom_minimum_size = _pause_panel_size()
	if _results_visible and _results_root != null:
		_show_results_screen(_last_results)


func _overlay_font_px(minimum: int, maximum: int, vh_ratio: float) -> int:
	var ui_scale := _overlay_scale()
	var scaled_size := float(maximum) * ui_scale
	var scaled_minimum := maxf(8.0, float(minimum) * minf(ui_scale, 1.0))
	var scaled_maximum := float(maximum) * maxf(ui_scale, 1.0)
	var height_size := get_viewport().get_visible_rect().size.y * vh_ratio
	return roundi(clampf(minf(scaled_size, height_size), scaled_minimum, scaled_maximum))


func _overlay_space(minimum: int, maximum: int) -> int:
	var ui_scale := _overlay_scale()
	var scaled_minimum := maxf(0.0, float(minimum) * minf(ui_scale, 1.0))
	var scaled_maximum := float(maximum) * maxf(ui_scale, 1.0)
	return roundi(clampf(float(maximum) * ui_scale, scaled_minimum, scaled_maximum))


func _overlay_vh(ratio: float, minimum: float, maximum: float) -> float:
	var ui_scale := _overlay_scale()
	return clampf(get_viewport().get_visible_rect().size.y * ratio, minimum * minf(ui_scale, 1.0), maximum * maxf(ui_scale, 1.0))


func _overlay_vw(ratio: float, minimum: float, maximum: float) -> float:
	var ui_scale := _overlay_scale()
	return clampf(get_viewport().get_visible_rect().size.x * ratio, minimum * minf(ui_scale, 1.0), maximum * maxf(ui_scale, 1.0))


func _overlay_scale() -> float:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return 1.0
	return clampf(
		minf(viewport_size.x / UI_REFERENCE_SIZE.x, viewport_size.y / UI_REFERENCE_SIZE.y),
		UI_MIN_SCALE,
		UI_MAX_SCALE
	)


func _make_slider_row(label_text: String, callback: Callable) -> Dictionary:
	var root := VBoxContainer.new()
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_theme_constant_override("separation", _overlay_space(3, 5))
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", _overlay_space(8, 12))
	root.add_child(header)

	var label := Label.new()
	label.text = label_text.to_upper()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", _overlay_font_px(10, 14, 0.013))
	label.add_theme_color_override("font_color", Color(0.76, 0.76, 0.84, 1.0))
	header.add_child(label)

	var value_label := Label.new()
	value_label.text = "100"
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.custom_minimum_size = Vector2(_overlay_space(44, 62), 1)
	value_label.add_theme_font_size_override("font_size", _overlay_font_px(11, 15, 0.014))
	value_label.add_theme_color_override("font_color", COLOR_RACING_RED)
	header.add_child(value_label)

	var track := Control.new()
	track.name = "%sTrack" % label_text.replace(" ", "")
	track.clip_contents = true
	track.custom_minimum_size = Vector2(1, _overlay_space(18, 26))
	track.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var track_base := ColorRect.new()
	track_base.name = "TrackBase"
	track_base.color = Color(1.0, 1.0, 1.0, 0.08)
	track_base.set_anchors_preset(Control.PRESET_FULL_RECT)
	track.add_child(track_base)

	var fill := ColorRect.new()
	fill.name = "TrackFill"
	fill.color = COLOR_RACING_RED
	fill.anchor_left = 0.0
	fill.anchor_top = 0.0
	fill.anchor_right = 1.0
	fill.anchor_bottom = 1.0
	fill.offset_left = 0.0
	fill.offset_top = 0.0
	fill.offset_right = 0.0
	fill.offset_bottom = 0.0
	track.add_child(fill)

	var slider := HSlider.new()
	slider.process_mode = Node.PROCESS_MODE_ALWAYS
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.set_anchors_preset(Control.PRESET_FULL_RECT)
	slider.add_theme_stylebox_override("slider", _make_style(Color.TRANSPARENT, Color.TRANSPARENT, 0, 3))
	slider.add_theme_stylebox_override("grabber_area", _make_style(Color.TRANSPARENT, Color.TRANSPARENT, 0, 3))
	slider.add_theme_stylebox_override("grabber_area_highlight", _make_style(COLOR_RACING_RED_HOVER, COLOR_RACING_RED_HOVER, 0, 3))
	slider.value_changed.connect(callback)
	track.add_child(slider)
	root.add_child(track)
	return {"root": root, "slider": slider, "value_label": value_label, "fill": fill}


func _sync_settings_ui() -> void:
	var session := _session()
	if session == null:
		return
	if _master_slider != null and session.has_method("get_master_volume"):
		var master_percent := roundf(float(session.call("get_master_volume")) * 100.0)
		_master_slider.set_value_no_signal(master_percent)
		_master_value_label.text = str(roundi(master_percent))
		_set_slider_fill(_master_slider_fill, master_percent)
	if _music_slider != null and session.has_method("get_music_volume"):
		var music_percent := roundf(float(session.call("get_music_volume")) * 100.0)
		_music_slider.set_value_no_signal(music_percent)
		_music_value_label.text = str(roundi(music_percent))
		_set_slider_fill(_music_slider_fill, music_percent)
	if _sfx_slider != null and session.has_method("get_sfx_volume"):
		var sfx_percent := roundf(float(session.call("get_sfx_volume")) * 100.0)
		_sfx_slider.set_value_no_signal(sfx_percent)
		_sfx_value_label.text = str(roundi(sfx_percent))
		_set_slider_fill(_sfx_slider_fill, sfx_percent)
	if _brightness_slider != null and session.has_method("get_brightness_percent"):
		var brightness_percent := roundf(float(session.call("get_brightness_percent")))
		_brightness_slider.set_value_no_signal(brightness_percent)
		_brightness_value_label.text = str(roundi(brightness_percent))
		_set_slider_fill(_brightness_slider_fill, brightness_percent)


func _on_master_percent_changed(value: float) -> void:
	if _master_value_label != null:
		_master_value_label.text = str(roundi(value))
	_set_slider_fill(_master_slider_fill, value)
	var session := _session()
	if session != null and session.has_method("set_master_volume"):
		session.call("set_master_volume", value / 100.0)


func _on_music_percent_changed(value: float) -> void:
	if _music_value_label != null:
		_music_value_label.text = str(roundi(value))
	_set_slider_fill(_music_slider_fill, value)
	var session := _session()
	if session != null and session.has_method("set_music_volume"):
		session.call("set_music_volume", value / 100.0)


func _on_sfx_percent_changed(value: float) -> void:
	if _sfx_value_label != null:
		_sfx_value_label.text = str(roundi(value))
	_set_slider_fill(_sfx_slider_fill, value)
	var session := _session()
	if session != null and session.has_method("set_sfx_volume"):
		session.call("set_sfx_volume", value / 100.0)


func _on_brightness_percent_changed(value: float) -> void:
	if _brightness_value_label != null:
		_brightness_value_label.text = str(roundi(value))
	_set_slider_fill(_brightness_slider_fill, value)
	var session := _session()
	if session != null and session.has_method("set_brightness_percent"):
		session.call("set_brightness_percent", value)
		if session.has_method("apply_brightness_to_scene"):
			session.call("apply_brightness_to_scene", get_tree().current_scene)


func _set_slider_fill(fill: ColorRect, value: float) -> void:
	if fill == null:
		return
	fill.anchor_right = clampf(value / 100.0, 0.0, 1.0)
	fill.offset_right = 0.0


func _session() -> Node:
	return get_node_or_null("/root/GameSession")


func _bind_ui_audio() -> void:
	var menu_audio_controller_script := load(MENU_AUDIO_CONTROLLER_SCRIPT_PATH) as Script
	if menu_audio_controller_script == null:
		return
	_ui_audio = menu_audio_controller_script.call("resolve", self) as Node
	if _ui_audio != null and _ui_audio.has_method("bind_buttons"):
		_ui_audio.call("bind_buttons", _overlay_root)
		if _results_root != null:
			_ui_audio.call("bind_buttons", _results_root)


func _make_button(text: String, callback: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.custom_minimum_size = Vector2(_overlay_vw(0.18, 280.0, 360.0), _overlay_vh(0.042, 36.0, 48.0))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", _overlay_font_px(14, 22, 0.020))
	button.add_theme_stylebox_override("normal", _make_style(Color(0.075, 0.088, 0.108, 0.96), Color(1.0, 1.0, 1.0, 0.18), 1, 4))
	button.add_theme_stylebox_override("hover", _make_style(Color(0.11, 0.13, 0.16, 1.0), Color(0.46, 0.84, 1.0, 0.55), 1, 4))
	button.add_theme_stylebox_override("pressed", _make_style(Color(0.15, 0.17, 0.20, 1.0), Color(0.46, 0.84, 1.0, 0.75), 1, 4))
	button.add_theme_color_override("font_color", COLOR_TEXT_MAIN)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	if primary:
		button.add_theme_stylebox_override("normal", _make_style(COLOR_RACING_RED, Color(1.0, 0.78, 0.70, 0.52), 1, 4))
		button.add_theme_stylebox_override("hover", _make_style(COLOR_RACING_RED_HOVER, Color(1.0, 0.90, 0.86, 0.62), 1, 4))
		button.add_theme_stylebox_override("pressed", _make_style(Color(0.72, 0.04, 0.08, 1.0), Color(1.0, 0.78, 0.70, 0.52), 1, 4))
	button.pressed.connect(callback)
	return button


func _apply_result_button_typography(button: Button) -> void:
	button.add_theme_font_size_override("font_size", _overlay_font_px(18, 32, 0.029))


func _make_style(fill: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style


func _find_node_by_name(root: Node, node_name: StringName) -> Node:
	if root == null or node_name == &"":
		return null
	if root.name == node_name:
		return root
	for child: Node in root.get_children():
		var found: Node = _find_node_by_name(child, node_name)
		if found != null:
			return found
	return null
