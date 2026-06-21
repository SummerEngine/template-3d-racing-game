extends CanvasLayer

@export var race_manager_path: NodePath = ^"../Managers/RaceManager"
@export var main_menu_scene_path: String = "res://scenes/ui/main_menu.tscn"

const COUNTDOWN_TEXTURE_PATHS: Dictionary = {
	3: "res://assets/ui/countdown_3.png",
	2: "res://assets/ui/countdown_2.png",
	1: "res://assets/ui/countdown_1.png",
}

var _race_manager: Node = null
var _countdown_root: Control = null
var _countdown_texture: TextureRect = null
var _countdown_tween: Tween = null
var _last_countdown_whole_seconds: int = -1
var _overlay_root: Control = null
var _title_label: Label = null
var _body_label: Label = null
var _resume_button: Button = null
var _restart_button: Button = null
var _main_menu_button: Button = null
var _results_visible: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_build_interface()
	call_deferred("_connect_race_manager")


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
	panel.custom_minimum_size = Vector2(540, 420)
	panel.add_theme_stylebox_override("panel", _make_style(Color(0.035, 0.043, 0.052, 0.96), Color(0.86, 0.68, 0.36, 1.0), 2, 8))
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.name = "Content"
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)

	_title_label = Label.new()
	_title_label.name = "Title"
	_title_label.add_theme_font_size_override("font_size", 32)
	_title_label.add_theme_color_override("font_color", Color(0.96, 0.88, 0.66, 1.0))
	box.add_child(_title_label)

	_body_label = Label.new()
	_body_label.name = "Body"
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.add_theme_font_size_override("font_size", 17)
	_body_label.add_theme_color_override("font_color", Color(0.86, 0.90, 0.92, 1.0))
	_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_body_label)

	_resume_button = _make_button("Resume", Callable(self, "_resume_race"), true)
	_restart_button = _make_button("Restart", Callable(self, "_restart_race"))
	_main_menu_button = _make_button("Main Menu", Callable(self, "_return_to_main_menu"))
	box.add_child(_resume_button)
	box.add_child(_restart_button)
	box.add_child(_main_menu_button)


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
		if not _race_manager.race_started.is_connected(Callable(self, "_hide_countdown")):
			_race_manager.race_started.connect(Callable(self, "_hide_countdown"))


func _toggle_pause() -> void:
	if get_tree().paused:
		_resume_race()
	else:
		_show_pause()


func _show_pause() -> void:
	_results_visible = false
	_title_label.text = "Paused"
	_body_label.text = "Race time is frozen."
	_resume_button.visible = true
	_overlay_root.visible = true
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


func _return_to_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(main_menu_scene_path)


func _on_race_finished(results: Array) -> void:
	_hide_countdown()
	_results_visible = true
	_title_label.text = "Race Complete"
	_body_label.text = _format_results(results)
	_resume_button.visible = false
	_overlay_root.visible = true
	get_tree().paused = true
	_restart_button.grab_focus()


func _on_countdown_changed(_time_remaining_seconds: float, whole_seconds: int) -> void:
	if whole_seconds <= 0:
		_last_countdown_whole_seconds = 0
		_hide_countdown()
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
	_countdown_texture.texture = texture
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


func _hide_countdown_after_number(value: int) -> void:
	if _last_countdown_whole_seconds == value and _countdown_root != null:
		_countdown_root.visible = false


func _hide_countdown() -> void:
	if _countdown_tween != null:
		_countdown_tween.kill()
		_countdown_tween = null
	if _countdown_root != null:
		_countdown_root.visible = false


func _countdown_texture_path(value: int) -> String:
	return str(COUNTDOWN_TEXTURE_PATHS.get(value, ""))


func _countdown_sprite_side() -> float:
	var viewport_size := get_viewport().get_visible_rect().size
	return clampf(minf(viewport_size.x, viewport_size.y) * 0.28, 180.0, 420.0)


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


func _make_button(text: String, callback: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.custom_minimum_size = Vector2(320, 46)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_stylebox_override("normal", _make_style(Color(0.09, 0.11, 0.125, 1.0), Color(0.42, 0.47, 0.50, 1.0), 1, 6))
	button.add_theme_stylebox_override("hover", _make_style(Color(0.13, 0.15, 0.17, 1.0), Color(0.86, 0.68, 0.36, 1.0), 1, 6))
	button.add_theme_stylebox_override("pressed", _make_style(Color(0.04, 0.05, 0.06, 1.0), Color(0.96, 0.78, 0.42, 1.0), 1, 6))
	button.add_theme_color_override("font_color", Color(0.91, 0.94, 0.95, 1.0))
	if primary:
		button.add_theme_stylebox_override("normal", _make_style(Color(1.0, 0.72, 0.1, 1.0), Color(0.08, 0.09, 0.09, 1.0), 2, 8))
		button.add_theme_color_override("font_color", Color(0.06, 0.07, 0.07, 1.0))
	button.pressed.connect(callback)
	return button


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
