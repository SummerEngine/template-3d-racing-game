extends Control

const MAIN_MENU_SCENE_PATH: String = "res://scenes/ui/main_menu.tscn"

var _label: Label = null
var _progress: ProgressBar = null
var _paths: Array[String] = []
var _loaded_count: int = 0
var _complete: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	var session := get_node_or_null("/root/GameSession")
	if session != null and session.has_method("get_boot_loading_manifest"):
		var value: Variant = session.call("get_boot_loading_manifest")
		if value is Array:
			for item: Variant in value:
				_paths.append(str(item))
	if not _paths.has(MAIN_MENU_SCENE_PATH):
		_paths.append(MAIN_MENU_SCENE_PATH)
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
	call_deferred("_enter_main_menu")


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.012, 0.014, 0.017, 1.0)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var stack := VBoxContainer.new()
	stack.custom_minimum_size = Vector2(420.0, 0.0)
	stack.add_theme_constant_override("separation", 14)
	center.add_child(stack)

	var title := Label.new()
	title.text = "APEX RACING"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.96, 0.97, 0.93, 1.0))
	stack.add_child(title)

	_label = Label.new()
	_label.text = "Loading 0%"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_color", Color(0.46, 0.84, 1.0, 1.0))
	stack.add_child(_label)

	_progress = ProgressBar.new()
	_progress.min_value = 0.0
	_progress.max_value = 100.0
	_progress.show_percentage = false
	_progress.custom_minimum_size = Vector2(1.0, 12.0)
	stack.add_child(_progress)


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
		_label.text = "Loading %d%%" % roundi(ratio * 100.0)


func _enter_main_menu() -> void:
	var scene: PackedScene = null
	var session := get_node_or_null("/root/GameSession")
	if session != null and session.has_method("get_preloaded_resource"):
		scene = session.call("get_preloaded_resource", MAIN_MENU_SCENE_PATH) as PackedScene
	if scene == null:
		scene = load(MAIN_MENU_SCENE_PATH) as PackedScene
	if scene != null:
		get_tree().change_scene_to_packed(scene)
	else:
		get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
