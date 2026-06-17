extends CanvasLayer

@export var race_manager_path: NodePath = ^"../Managers/RaceManager"
@export var main_menu_scene_path: String = "res://scenes/ui/main_menu.tscn"

var _race_manager: Node = null
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
	_overlay_root = Control.new()
	_overlay_root.name = "OverlayRoot"
	_overlay_root.process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_root.visible = false
	add_child(_overlay_root)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.02, 0.025, 0.03, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_root.add_child(dim)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_root.add_child(center)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(460, 360)
	panel.add_theme_stylebox_override("panel", _make_style(Color(0.94, 0.96, 0.95, 0.98), Color(0.07, 0.10, 0.11, 1.0), 2, 8))
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
	_title_label.add_theme_color_override("font_color", Color(0.07, 0.10, 0.11, 1.0))
	box.add_child(_title_label)

	_body_label = Label.new()
	_body_label.name = "Body"
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.add_theme_font_size_override("font_size", 17)
	_body_label.add_theme_color_override("font_color", Color(0.22, 0.28, 0.30, 1.0))
	_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_body_label)

	_resume_button = _make_button("Resume", Callable(self, "_resume_race"), true)
	_restart_button = _make_button("Restart", Callable(self, "_restart_race"))
	_main_menu_button = _make_button("Main Menu", Callable(self, "_return_to_main_menu"))
	box.add_child(_resume_button)
	box.add_child(_restart_button)
	box.add_child(_main_menu_button)


func _connect_race_manager() -> void:
	_race_manager = get_node_or_null(race_manager_path)
	if _race_manager == null:
		_race_manager = _find_node_by_name(get_tree().current_scene, &"RaceManager")
	if _race_manager != null and _race_manager.has_signal("race_finished"):
		if not _race_manager.race_finished.is_connected(Callable(self, "_on_race_finished")):
			_race_manager.race_finished.connect(Callable(self, "_on_race_finished"))


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
	_results_visible = true
	_title_label.text = "Results"
	_body_label.text = _format_results(results)
	_resume_button.visible = false
	_overlay_root.visible = true
	get_tree().paused = true
	_restart_button.grab_focus()


func _format_results(results: Array) -> String:
	if results.is_empty():
		return "Race complete."

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
		var placement: int = int(row.get("placement", lines.size() + 1))
		var display_name: String = str(row.get("display_name", "Racer"))
		var formatted_time: String = str(row.get("formatted_total_time", "--:--.---"))
		lines.append("%d. %s  %s" % [placement, display_name, formatted_time])

	if lines.is_empty():
		return "Race complete."
	return "\n".join(lines)


func _make_button(text: String, callback: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.custom_minimum_size = Vector2(260, 44)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 18)
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
