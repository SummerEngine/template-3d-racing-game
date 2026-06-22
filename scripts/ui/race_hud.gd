class_name RaceHUD
extends CanvasLayer

const FigmaUIFontScript := preload("res://scripts/ui/figma_ui_fonts.gd")

@export var race_manager_path: NodePath
@export var player_car_path: NodePath
@export var auto_discover_nodes: bool = true
@export var race_manager_name: StringName = &"RaceManager"
@export var player_car_name: StringName = &"PlayerCar"

@export_group("Camera Overlay")
@export var use_default_camera_overlay: bool = true
@export var hide_legacy_fallback_panel: bool = true
@export var overlay_reference_size: Vector2 = Vector2(1152.0, 648.0)
@export_range(0.5, 2.0, 0.01) var overlay_min_scale: float = 0.72
@export_range(0.5, 2.0, 0.01) var overlay_max_scale: float = 1.35

@export_group("Labels")
@export var speed_label_path: NodePath
@export var mode_label_path: NodePath
@export var phase_label_path: NodePath
@export var countdown_label_path: NodePath
@export var lap_label_path: NodePath
@export var position_label_path: NodePath
@export var time_label_path: NodePath
@export var results_label_path: NodePath
@export var fallback_label_path: NodePath

@export_group("Label Names")
@export var speed_label_name: StringName = &"SpeedLabel"
@export var mode_label_name: StringName = &"ModeLabel"
@export var phase_label_name: StringName = &"PhaseLabel"
@export var countdown_label_name: StringName = &"CountdownLabel"
@export var lap_label_name: StringName = &"LapLabel"
@export var position_label_name: StringName = &"PositionLabel"
@export var time_label_name: StringName = &"TimeLabel"
@export var results_label_name: StringName = &"ResultsLabel"
@export var fallback_label_name: StringName = &"Readout"

var _race_manager: Node = null
var _player_car: Node = null
var _speed_label: Label = null
var _mode_label: Label = null
var _phase_label: Label = null
var _countdown_label: Label = null
var _lap_label: Label = null
var _position_label: Label = null
var _time_label: Label = null
var _results_label: Label = null
var _fallback_label: Label = null
var _camera_overlay_root: Control = null
var _top_shade: ColorRect = null
var _bottom_shade: ColorRect = null
var _speed_panel: Control = null
var _summary_panel: Control = null
var _position_panel: Control = null
var _gear_panel: Control = null
var _gear_label: Label = null
var _rpm_container: HBoxContainer = null
var _rpm_blocks: Array[ColorRect] = []
var _last_overlay_viewport_size: Vector2 = Vector2.ZERO


func _ready() -> void:
	_resolve_nodes()
	_resolve_labels()
	_ensure_default_camera_overlay()
	FigmaUIFontScript.apply_tree(self)
	_update_hud()


func _process(_delta: float) -> void:
	_update_hud()


func _update_hud() -> void:
	_resolve_nodes()
	_resolve_labels()

	var snapshot: Dictionary = _get_race_snapshot()
	var speed_kmh: int = _get_speed_kmh()
	var mode_text: String = _get_mode_text()
	var phase_text: String = _get_phase_text(snapshot)
	var countdown_text: String = _get_countdown_text(snapshot)
	var lap_text: String = _get_lap_text(snapshot)
	var position_text: String = _get_position_text(snapshot)
	var time_text: String = _get_time_text(snapshot)
	var results_text: String = _get_results_text(snapshot)

	if _camera_overlay_root != null:
		_update_camera_overlay_layout()
		_set_label_text(_speed_label, str(speed_kmh))
		_set_label_text(_lap_label, _format_lap_for_overlay(lap_text))
		_set_label_text(_position_label, _get_position_badge_text(snapshot, position_text))
		_set_label_text(_time_label, _strip_prefix(time_text, "Time ").to_upper())
		_set_label_text(_gear_label, str(_gear_for_readout(speed_kmh)))
		_update_rpm_blocks(_rpm_for_speed(speed_kmh))
	else:
		_set_label_text(_speed_label, "Speed %03d km/h" % speed_kmh)
		_set_label_text(_lap_label, lap_text)
		_set_label_text(_position_label, position_text)
		_set_label_text(_time_label, time_text)
	_set_label_text(_mode_label, "Mode %s" % mode_text)
	_set_label_text(_phase_label, "Race %s" % phase_text)
	_set_label_text(_countdown_label, countdown_text)
	_set_label_text(_results_label, results_text)

	if _fallback_label != null:
		_fallback_label.text = _build_fallback_text(
			speed_kmh,
			mode_text,
			phase_text,
			countdown_text,
			lap_text,
			position_text,
			time_text,
			results_text
		)


func _resolve_nodes() -> void:
	if _race_manager == null:
		_race_manager = _resolve_exported_node(race_manager_path, race_manager_name)
	if _player_car == null:
		_player_car = _resolve_exported_node(player_car_path, player_car_name)


func _resolve_labels() -> void:
	if _speed_label == null:
		_speed_label = _resolve_label(speed_label_path, speed_label_name)
	if _mode_label == null:
		_mode_label = _resolve_label(mode_label_path, mode_label_name)
	if _phase_label == null:
		_phase_label = _resolve_label(phase_label_path, phase_label_name)
	if _countdown_label == null:
		_countdown_label = _resolve_label(countdown_label_path, countdown_label_name)
	if _lap_label == null:
		_lap_label = _resolve_label(lap_label_path, lap_label_name)
	if _position_label == null:
		_position_label = _resolve_label(position_label_path, position_label_name)
	if _time_label == null:
		_time_label = _resolve_label(time_label_path, time_label_name)
	if _results_label == null:
		_results_label = _resolve_label(results_label_path, results_label_name)
	if _fallback_label == null:
		_fallback_label = _resolve_label(fallback_label_path, fallback_label_name)
	if _fallback_label == null and not _has_detailed_labels():
		_fallback_label = _find_first_label(self)


func _ensure_default_camera_overlay() -> void:
	if not use_default_camera_overlay or _camera_overlay_root != null:
		return
	if _has_detailed_labels():
		return

	_camera_overlay_root = Control.new()
	_camera_overlay_root.name = "CameraOverlay"
	_camera_overlay_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_camera_overlay_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_camera_overlay_root)

	_top_shade = _make_shade("TopShade", Color(0.012, 0.016, 0.04, 0.88))
	_bottom_shade = _make_shade("BottomShade", Color(0.012, 0.016, 0.04, 0.90))

	_position_panel = _make_overlay_panel(_camera_overlay_root, "PositionPanel", Color(0.86, 0.0, 0.16, 0.16), Color(0.86, 0.0, 0.16, 0.52))
	var position_box := VBoxContainer.new()
	position_box.name = "PositionBox"
	position_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	position_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_position_panel.add_child(position_box)
	position_box.add_child(_make_overlay_label("PositionCaption", "POS", 10, Color(0.91, 0.0, 0.18, 1.0), HORIZONTAL_ALIGNMENT_CENTER))
	_position_label = _make_overlay_label(String(position_label_name), "P1", 30, Color(0.94, 0.94, 0.94, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	_position_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	position_box.add_child(_position_label)

	_summary_panel = _make_overlay_panel(_camera_overlay_root, "RaceSummaryPanel", Color(0.012, 0.016, 0.04, 0.28), Color(1.0, 1.0, 1.0, 0.08))
	var summary_box := HBoxContainer.new()
	summary_box.name = "RaceSummaryBox"
	summary_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	summary_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	summary_box.add_theme_constant_override("separation", 16)
	_summary_panel.add_child(summary_box)

	summary_box.add_child(_make_stat_group("LAP", String(lap_label_name), "1 / 3", 19, Color(0.94, 0.94, 0.94, 1.0)))
	summary_box.add_child(_make_divider())
	summary_box.add_child(_make_stat_group("TIME", String(time_label_name), "00:00.000", 19, Color(0.94, 0.94, 0.94, 1.0)))

	_speed_panel = _make_overlay_panel(_camera_overlay_root, "SpeedCluster", Color(0.012, 0.016, 0.04, 0.0), Color(1.0, 1.0, 1.0, 0.0))
	var speed_root := VBoxContainer.new()
	speed_root.name = "SpeedRoot"
	speed_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speed_root.alignment = BoxContainer.ALIGNMENT_END
	speed_root.add_theme_constant_override("separation", 8)
	_speed_panel.add_child(speed_root)

	_rpm_container = HBoxContainer.new()
	_rpm_container.name = "RpmBar"
	_rpm_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rpm_container.alignment = BoxContainer.ALIGNMENT_END
	_rpm_container.add_theme_constant_override("separation", 3)
	speed_root.add_child(_rpm_container)
	_rpm_blocks.clear()
	for block_index: int in range(18):
		var block := ColorRect.new()
		block.name = "RpmBlock%d" % [block_index + 1]
		block.mouse_filter = Control.MOUSE_FILTER_IGNORE
		block.custom_minimum_size = Vector2(8.0, 13.0)
		_rpm_blocks.append(block)
		_rpm_container.add_child(block)

	var speed_row := HBoxContainer.new()
	speed_row.name = "SpeedRow"
	speed_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speed_row.alignment = BoxContainer.ALIGNMENT_END
	speed_row.add_theme_constant_override("separation", 9)
	speed_root.add_child(speed_row)

	var speed_box := VBoxContainer.new()
	speed_box.name = "SpeedBox"
	speed_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speed_box.alignment = BoxContainer.ALIGNMENT_END
	speed_row.add_child(speed_box)
	_speed_label = _make_overlay_label(String(speed_label_name), "0", 60, Color(0.94, 0.94, 0.94, 1.0), HORIZONTAL_ALIGNMENT_RIGHT)
	speed_box.add_child(_speed_label)
	var speed_caption := _make_overlay_label("SpeedCaption", "KM/H", 12, Color(0.29, 0.29, 0.42, 1.0), HORIZONTAL_ALIGNMENT_RIGHT)
	speed_box.add_child(speed_caption)

	_gear_panel = _make_overlay_panel(speed_row, "GearPanel", Color(0.86, 0.0, 0.16, 0.16), Color(0.86, 0.0, 0.16, 0.48))
	var gear_box := VBoxContainer.new()
	gear_box.name = "GearBox"
	gear_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gear_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_gear_panel.add_child(gear_box)
	gear_box.add_child(_make_overlay_label("GearCaption", "GEAR", 9, Color(0.91, 0.0, 0.18, 1.0), HORIZONTAL_ALIGNMENT_CENTER))
	_gear_label = _make_overlay_label("GearLabel", "1", 25, Color(0.94, 0.94, 0.94, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	gear_box.add_child(_gear_label)

	if hide_legacy_fallback_panel:
		_set_legacy_fallback_visible(false)

	_update_camera_overlay_layout(true)


func _make_overlay_panel(parent: Node, panel_name: String, fill: Color, border: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = panel_name
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _make_panel_style(fill, border))
	parent.add_child(panel)
	return panel


func _make_shade(shade_name: String, color: Color) -> ColorRect:
	var shade := ColorRect.new()
	shade.name = shade_name
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.color = color
	_camera_overlay_root.add_child(shade)
	return shade


func _make_panel_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0.0, 3.0)
	return style


func _make_overlay_label(label_name: String, text: String, font_size: int, color: Color, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.name = label_name
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.62))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label


func _make_stat_group(caption: String, label_name: String, value: String, value_size: int, value_color: Color) -> VBoxContainer:
	var group := VBoxContainer.new()
	group.name = "%sGroup" % caption.replace(" ", "")
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	group.alignment = BoxContainer.ALIGNMENT_CENTER
	group.add_theme_constant_override("separation", 1)
	var caption_label := _make_overlay_label("%sCaption" % group.name, caption, 10, Color(0.29, 0.29, 0.42, 1.0), HORIZONTAL_ALIGNMENT_LEFT)
	group.add_child(caption_label)
	var value_label := _make_overlay_label(label_name, value, value_size, value_color, HORIZONTAL_ALIGNMENT_LEFT)
	group.add_child(value_label)
	if label_name == String(lap_label_name):
		_lap_label = value_label
	elif label_name == String(time_label_name):
		_time_label = value_label
	return group


func _make_divider() -> ColorRect:
	var divider := ColorRect.new()
	divider.name = "Divider"
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	divider.color = Color(0.38, 0.82, 1.0, 0.55)
	divider.custom_minimum_size = Vector2(1.0, 28.0)
	return divider


func _update_camera_overlay_layout(force: bool = false) -> void:
	if _camera_overlay_root == null:
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if not force and viewport_size == _last_overlay_viewport_size:
		return
	_last_overlay_viewport_size = viewport_size

	var reference: Vector2 = overlay_reference_size
	if reference.x <= 0.0 or reference.y <= 0.0:
		reference = Vector2(1152.0, 648.0)
	var ui_scale: float = clampf(minf(viewport_size.x / reference.x, viewport_size.y / reference.y), overlay_min_scale, overlay_max_scale)

	_layout_bar(_top_shade, true, 94.0, ui_scale)
	_layout_bar(_bottom_shade, false, 156.0, ui_scale)
	_layout_panel_top_left(_position_panel, Vector2(16.0, 10.0), Vector2(72.0, 58.0), ui_scale)
	_layout_panel_top_left(_summary_panel, Vector2(104.0, 10.0), Vector2(292.0, 58.0), ui_scale)
	_layout_panel_bottom_right(_speed_panel, Vector2(16.0, 16.0), Vector2(286.0, 96.0), ui_scale)

	_apply_overlay_margins(_speed_panel, 16, 10, 16, 12, ui_scale)
	_apply_overlay_margins(_summary_panel, 18, 10, 18, 10, ui_scale)
	_apply_overlay_margins(_position_panel, 14, 8, 14, 8, ui_scale)
	_apply_overlay_margins(_gear_panel, 8, 6, 8, 6, ui_scale)
	_set_control_minimum(_gear_panel, Vector2(50.0, 50.0), ui_scale)
	_set_label_font(_speed_label, 60, ui_scale, 34, 80)
	_set_label_font(_lap_label, 19, ui_scale, 13, 28)
	_set_label_font(_time_label, 19, ui_scale, 13, 28)
	_set_label_font(_position_label, 30, ui_scale, 20, 42)
	_set_label_font(_gear_label, 25, ui_scale, 18, 36)
	if _rpm_container != null:
		_rpm_container.add_theme_constant_override("separation", max(2, roundi(3.0 * ui_scale)))
	for block: ColorRect in _rpm_blocks:
		block.custom_minimum_size = Vector2(roundf(8.0 * ui_scale), roundf(13.0 * ui_scale))


func _layout_bar(bar: Control, at_top: bool, height: float, ui_scale: float) -> void:
	if bar == null:
		return
	bar.anchor_left = 0.0
	bar.anchor_right = 1.0
	bar.offset_left = 0.0
	bar.offset_right = 0.0
	if at_top:
		bar.anchor_top = 0.0
		bar.anchor_bottom = 0.0
		bar.offset_top = 0.0
		bar.offset_bottom = roundf(height * ui_scale)
	else:
		bar.anchor_top = 1.0
		bar.anchor_bottom = 1.0
		bar.offset_top = -roundf(height * ui_scale)
		bar.offset_bottom = 0.0


func _layout_panel_top_left(panel: Control, margin: Vector2, size: Vector2, ui_scale: float) -> void:
	if panel == null:
		return
	panel.anchor_left = 0.0
	panel.anchor_right = 0.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = roundf(margin.x * ui_scale)
	panel.offset_right = roundf((margin.x + size.x) * ui_scale)
	panel.offset_top = roundf(margin.y * ui_scale)
	panel.offset_bottom = roundf((margin.y + size.y) * ui_scale)


func _layout_panel_bottom_right(panel: Control, margin: Vector2, size: Vector2, ui_scale: float) -> void:
	if panel == null:
		return
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -roundf((margin.x + size.x) * ui_scale)
	panel.offset_right = -roundf(margin.x * ui_scale)
	panel.offset_top = -roundf((margin.y + size.y) * ui_scale)
	panel.offset_bottom = -roundf(margin.y * ui_scale)


func _apply_overlay_margins(panel: Control, left: int, top: int, right: int, bottom: int, ui_scale: float) -> void:
	if panel == null:
		return
	panel.add_theme_constant_override("margin_left", roundi(float(left) * ui_scale))
	panel.add_theme_constant_override("margin_top", roundi(float(top) * ui_scale))
	panel.add_theme_constant_override("margin_right", roundi(float(right) * ui_scale))
	panel.add_theme_constant_override("margin_bottom", roundi(float(bottom) * ui_scale))


func _set_label_font(label: Label, base_size: int, ui_scale: float, min_size: int, max_size: int) -> void:
	if label == null:
		return
	label.add_theme_font_size_override("font_size", clampi(roundi(float(base_size) * ui_scale), min_size, max_size))


func _set_control_minimum(control: Control, base_size: Vector2, ui_scale: float) -> void:
	if control == null:
		return
	control.custom_minimum_size = Vector2(roundf(base_size.x * ui_scale), roundf(base_size.y * ui_scale))


func _set_legacy_fallback_visible(fallback_visible: bool) -> void:
	var legacy_margin: CanvasItem = get_node_or_null("Margin") as CanvasItem
	if legacy_margin != null:
		legacy_margin.visible = fallback_visible


func _resolve_exported_node(path: NodePath, node_name: StringName) -> Node:
	if not path.is_empty():
		var node: Node = get_node_or_null(path)
		if node != null:
			return node
	if auto_discover_nodes:
		var current_scene: Node = get_tree().current_scene
		if current_scene != null:
			var scene_match: Node = _find_node_by_name(current_scene, node_name)
			if scene_match != null:
				return scene_match
		return _find_node_by_name(get_tree().root, node_name)
	return null


func _resolve_label(path: NodePath, label_name: StringName) -> Label:
	if not path.is_empty():
		var path_node: Node = get_node_or_null(path)
		var path_label: Label = path_node as Label
		if path_label != null:
			return path_label
	if label_name != &"":
		return _find_label_by_name(self, label_name)
	return null


func _get_race_snapshot() -> Dictionary:
	if _race_manager == null:
		return {}
	if _race_manager.has_method("get_ui_snapshot"):
		var snapshot_value: Variant = _race_manager.call("get_ui_snapshot")
		if snapshot_value is Dictionary:
			return snapshot_value

	var snapshot: Dictionary = {}
	if _race_manager.has_method("get_phase_name"):
		snapshot["phase_name"] = str(_race_manager.call("get_phase_name"))
	if _race_manager.has_method("get_countdown_seconds_remaining"):
		var countdown_value: Variant = _race_manager.call("get_countdown_seconds_remaining")
		if countdown_value is float or countdown_value is int:
			snapshot["countdown_seconds"] = float(countdown_value)
	if _race_manager.has_method("get_race_time_msec"):
		var time_value: Variant = _race_manager.call("get_race_time_msec")
		if time_value is int or time_value is float:
			snapshot["race_time_msec"] = int(time_value)
	return snapshot


func _get_speed_kmh() -> int:
	return roundi(_get_speed_mps() * 3.6)


func _get_speed_mps() -> float:
	if _player_car == null:
		return 0.0
	if _player_car.has_method("get_speed"):
		var speed_value: Variant = _player_car.call("get_speed")
		if speed_value is float or speed_value is int:
			return max(0.0, float(speed_value))
	if _has_property(_player_car, &"velocity"):
		var velocity_value: Variant = _player_car.get("velocity")
		if velocity_value is Vector3:
			var velocity_3d: Vector3 = velocity_value
			return Vector3(velocity_3d.x, 0.0, velocity_3d.z).length()
		if velocity_value is Vector2:
			return (velocity_value as Vector2).length()
	return 0.0


func _get_mode_text() -> String:
	return "DRIFT" if _is_drifting() else "GRIP"


func _is_drifting() -> bool:
	if _player_car == null:
		return false
	if _has_property(_player_car, &"is_drifting"):
		return bool(_player_car.get("is_drifting"))
	var drift_intensity: float = _get_drift_intensity()
	return drift_intensity > 0.05


func _get_drift_intensity() -> float:
	if _player_car == null:
		return 0.0
	var method_names: Array[StringName] = [
		&"get_drift_intensity",
		&"get_effective_drift_intensity",
		&"get_effective_drift",
	]
	for method_name: StringName in method_names:
		if _player_car.has_method(method_name):
			var method_value: Variant = _player_car.call(method_name)
			if method_value is float or method_value is int:
				return clampf(float(method_value), 0.0, 1.0)

	var property_names: Array[StringName] = [
		&"drift_intensity",
		&"effective_drift_intensity",
		&"effective_drift",
	]
	for property_name: StringName in property_names:
		if _has_property(_player_car, property_name):
			var property_value: Variant = _player_car.get(property_name)
			if property_value is float or property_value is int:
				return clampf(float(property_value), 0.0, 1.0)
	return 0.0


func _get_phase_text(snapshot: Dictionary) -> String:
	var phase_name: String = str(snapshot.get("phase_name", "setup"))
	if phase_name.is_empty():
		phase_name = "setup"
	return phase_name.to_upper()


func _get_countdown_text(snapshot: Dictionary) -> String:
	var countdown_seconds: float = _get_float(snapshot, "countdown_seconds", 0.0)
	if countdown_seconds <= 0.0:
		return ""
	var phase_name: String = str(snapshot.get("phase_name", ""))
	if not phase_name.is_empty() and phase_name.to_lower() != "countdown":
		return ""
	return "Start %d" % int(ceil(countdown_seconds))


func _get_lap_text(snapshot: Dictionary) -> String:
	if not snapshot.has("lap") and not snapshot.has("lap_count"):
		return "Lap --/--"
	var lap: int = _get_int(snapshot, "lap", 1)
	var lap_count: int = _get_int(snapshot, "lap_count", 1)
	return "Lap %d/%d" % [max(1, lap), max(1, lap_count)]


func _get_position_text(snapshot: Dictionary) -> String:
	var position: int = _get_int(snapshot, "focused_position", 0)
	var participant_count: int = _get_int(snapshot, "participant_count", 0)
	if position <= 0 and participant_count <= 0:
		return "Pos --/--"
	if position <= 0:
		return "Pos --/%d" % participant_count
	if participant_count <= 0:
		return "Pos %d" % position
	return "Pos %d/%d" % [position, participant_count]


func _get_time_text(snapshot: Dictionary) -> String:
	var race_time_msec: int = _get_int(snapshot, "race_time_msec", -1)
	if race_time_msec < 0:
		return "Time --:--.---"
	return "Time %s" % _format_time_msec(race_time_msec)


func _get_results_text(snapshot: Dictionary) -> String:
	var results_value: Variant = snapshot.get("results", [])
	if not (results_value is Array):
		return ""
	var results: Array = results_value
	if results.is_empty():
		return ""

	var lines: Array[String] = ["Results"]
	var max_rows: int = min(results.size(), 4)
	for index in range(max_rows):
		var row_value: Variant = results[index]
		if not (row_value is Dictionary):
			continue
		var row: Dictionary = row_value
		var placement: int = _get_int(row, "placement", index + 1)
		var display_name: String = str(row.get("display_name", row.get("participant_id", "Racer")))
		var formatted_time: String = str(row.get("formatted_total_time", ""))
		if formatted_time.is_empty() and row.has("total_time_msec"):
			formatted_time = _format_time_msec(_get_int(row, "total_time_msec", -1))
		lines.append("%d %s %s" % [placement, display_name, formatted_time])
	return "\n".join(lines)


func _build_fallback_text(
	speed_kmh: int,
	mode_text: String,
	phase_text: String,
	countdown_text: String,
	lap_text: String,
	position_text: String,
	time_text: String,
	results_text: String
) -> String:
	var phase_line: String = "Race %s" % phase_text
	if not countdown_text.is_empty():
		phase_line = "%s  %s" % [phase_line, countdown_text]

	var lines: Array[String] = [
		"Speed %03d km/h" % speed_kmh,
		"Mode %s" % mode_text,
		phase_line,
		lap_text,
		position_text,
		time_text,
	]
	if not results_text.is_empty():
		lines.append(results_text)
	return "\n".join(lines)


func _set_label_text(label: Label, text: String) -> void:
	if label == null:
		return
	label.text = text


func _format_lap_for_overlay(lap_text: String) -> String:
	var text: String = _strip_prefix(lap_text, "Lap ").strip_edges()
	if text.is_empty() or text == "--/--":
		return "-- / --"
	return text.replace("/", " / ").to_upper()


func _get_position_badge_text(snapshot: Dictionary, position_text: String) -> String:
	var position: int = _get_int(snapshot, "focused_position", 0)
	if position > 0:
		return "P%d" % position

	var text: String = _strip_prefix(position_text, "Pos ").strip_edges()
	if text.contains("/"):
		text = text.get_slice("/", 0).strip_edges()
	if text.is_valid_int() and text.to_int() > 0:
		return "P%d" % text.to_int()
	return "P--"


func _gear_for_speed(speed_kmh: int) -> int:
	if speed_kmh < 60:
		return 1
	if speed_kmh < 110:
		return 2
	if speed_kmh < 155:
		return 3
	if speed_kmh < 195:
		return 4
	if speed_kmh < 230:
		return 5
	return 6


func _gear_for_readout(speed_kmh: int) -> int:
	if _player_car != null and _player_car.has_method("get_current_gear"):
		var gear_value: Variant = _player_car.call("get_current_gear")
		if gear_value is int or gear_value is float:
			return clampi(int(gear_value), 1, 8)
	return _gear_for_speed(speed_kmh)


func _rpm_for_speed(speed_kmh: int) -> float:
	if _player_car != null and _player_car.has_method("get_current_gear_ratio"):
		var ratio_value: Variant = _player_car.call("get_current_gear_ratio")
		if ratio_value is int or ratio_value is float:
			var throttle_amount: float = 0.0
			if _player_car.has_method("get_throttle_amount"):
				var throttle_value: Variant = _player_car.call("get_throttle_amount")
				if throttle_value is float or throttle_value is int:
					throttle_amount = clampf(float(throttle_value), 0.0, 1.0)
			return clampf(float(ratio_value) * 0.78 + throttle_amount * 0.22, 0.0, 1.0)

	var gear: int = _gear_for_speed(speed_kmh)
	var low: float = 0.0
	var high: float = 60.0
	match gear:
		2:
			low = 60.0
			high = 110.0
		3:
			low = 110.0
			high = 155.0
		4:
			low = 155.0
			high = 195.0
		5:
			low = 195.0
			high = 230.0
		6:
			low = 230.0
			high = 260.0

	var gear_span: float = maxf(high - low, 1.0)
	var gear_progress: float = clampf((float(speed_kmh) - low) / gear_span, 0.0, 1.0)
	var throttle: float = 0.0
	if _player_car != null and _player_car.has_method("get_throttle_amount"):
		var throttle_value: Variant = _player_car.call("get_throttle_amount")
		if throttle_value is float or throttle_value is int:
			throttle = clampf(float(throttle_value), 0.0, 1.0)
	return clampf(gear_progress * 0.76 + throttle * 0.24, 0.0, 1.0)


func _update_rpm_blocks(rpm: float) -> void:
	if _rpm_blocks.is_empty():
		return
	var safe_rpm: float = clampf(rpm, 0.0, 1.0)
	var active_count: int = clampi(ceili(safe_rpm * float(_rpm_blocks.size())), 0, _rpm_blocks.size())
	var yellow_start: int = floori(float(_rpm_blocks.size()) * 0.62)
	var red_start: int = floori(float(_rpm_blocks.size()) * 0.82)
	for index: int in range(_rpm_blocks.size()):
		var block: ColorRect = _rpm_blocks[index]
		if index >= active_count:
			block.color = Color(0.13, 0.13, 0.19, 0.70)
		elif index >= red_start:
			block.color = Color(0.91, 0.0, 0.18, 1.0)
		elif index >= yellow_start:
			block.color = Color(1.0, 0.84, 0.0, 1.0)
		else:
			block.color = Color(0.0, 0.81, 1.0, 1.0)


func _has_detailed_labels() -> bool:
	return _speed_label != null \
		or _mode_label != null \
		or _phase_label != null \
		or _countdown_label != null \
		or _lap_label != null \
		or _position_label != null \
		or _time_label != null \
		or _results_label != null


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


func _find_label_by_name(root: Node, label_name: StringName) -> Label:
	if root == null or label_name == &"":
		return null
	if root.name == label_name:
		return root as Label
	for child: Node in root.get_children():
		var found: Label = _find_label_by_name(child, label_name)
		if found != null:
			return found
	return null


func _find_first_label(root: Node) -> Label:
	if root == null:
		return null
	var label: Label = root as Label
	if label != null:
		return label
	for child: Node in root.get_children():
		var found: Label = _find_first_label(child)
		if found != null:
			return found
	return null


func _has_property(target: Object, property_name: StringName) -> bool:
	if target == null:
		return false
	for property: Dictionary in target.get_property_list():
		if String(property.get("name", "")) == String(property_name):
			return true
	return false


func _get_int(source: Dictionary, key: String, fallback: int) -> int:
	var value: Variant = source.get(key, fallback)
	if value is int:
		return value
	if value is float:
		return int(value)
	return fallback


func _get_float(source: Dictionary, key: String, fallback: float) -> float:
	var value: Variant = source.get(key, fallback)
	if value is float or value is int:
		return float(value)
	return fallback


func _format_time_msec(time_msec: int) -> String:
	if time_msec < 0:
		return "--:--.---"
	var total_seconds: int = int(float(time_msec) / 1000.0)
	var minutes: int = int(float(total_seconds) / 60.0)
	var seconds: int = total_seconds % 60
	var millis: int = time_msec % 1000
	return "%02d:%02d.%03d" % [minutes, seconds, millis]


func _strip_prefix(text: String, prefix: String) -> String:
	if text.begins_with(prefix):
		return text.substr(prefix.length())
	return text
