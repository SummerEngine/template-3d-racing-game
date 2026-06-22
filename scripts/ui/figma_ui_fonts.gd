class_name FigmaUIFont
extends RefCounted

const HEADING_FONT_PATH: String = "res://assets/fonts/Orbitron-VariableFont_wght.ttf"
const BODY_FONT_PATH: String = "res://assets/fonts/Rajdhani-Regular.ttf"
const BODY_SEMIBOLD_FONT_PATH: String = "res://assets/fonts/Rajdhani-SemiBold.ttf"


static func apply_tree(root: Node) -> void:
	if root == null:
		return
	if root is Control:
		_apply_control(root as Control)
	for child: Node in root.get_children():
		apply_tree(child)


static func heading_font() -> Font:
	return _load_font(HEADING_FONT_PATH)


static func body_font() -> Font:
	return _load_font(BODY_FONT_PATH)


static func body_semibold_font() -> Font:
	var font := _load_font(BODY_SEMIBOLD_FONT_PATH)
	return font if font != null else body_font()


static func apply_heading(control: Control) -> void:
	var font := heading_font()
	if control != null and font != null:
		control.add_theme_font_override("font", font)


static func apply_body(control: Control, semibold: bool = false) -> void:
	var font := body_semibold_font() if semibold else body_font()
	if control != null and font != null:
		control.add_theme_font_override("font", font)


static func _apply_control(control: Control) -> void:
	if control is Button:
		apply_heading(control)
		return
	if control is Label:
		if _should_use_heading_font(control as Label):
			apply_heading(control)
		else:
			apply_body(control)


static func _should_use_heading_font(label: Label) -> bool:
	var text := label.text.strip_edges()
	var font_size := _font_size(label)
	if font_size >= 18:
		return true
	if text.is_empty():
		return false
	if _looks_numeric(text):
		return true
	return text == text.to_upper() and text.length() <= 32


static func _font_size(control: Control) -> int:
	if control.has_theme_font_size_override("font_size"):
		return control.get_theme_font_size("font_size")
	return 0


static func _looks_numeric(text: String) -> bool:
	for index: int in range(text.length()):
		var character_code := text.unicode_at(index)
		if character_code >= 48 and character_code <= 57:
			return true
	return false


static func _load_font(path: String) -> Font:
	if path.is_empty():
		return null
	if FileAccess.file_exists("%s.import" % path):
		var imported_font := load(path) as Font
		if imported_font != null:
			return imported_font
	var font_file := FontFile.new()
	if not font_file.has_method("load_dynamic_font"):
		return null
	var error: Variant = font_file.call("load_dynamic_font", ProjectSettings.globalize_path(path))
	if error is int and int(error) == OK:
		return font_file
	return null
