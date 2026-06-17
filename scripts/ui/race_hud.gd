class_name RaceHUD
extends CanvasLayer

@export var race_manager_path: NodePath
@export var player_car_path: NodePath
@export var auto_discover_nodes: bool = true
@export var race_manager_name: StringName = &"RaceManager"
@export var player_car_name: StringName = &"PlayerCar"

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


func _ready() -> void:
	_resolve_nodes()
	_resolve_labels()
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

	_set_label_text(_speed_label, "Speed %03d km/h" % speed_kmh)
	_set_label_text(_mode_label, "Mode %s" % mode_text)
	_set_label_text(_phase_label, "Race %s" % phase_text)
	_set_label_text(_countdown_label, countdown_text)
	_set_label_text(_lap_label, lap_text)
	_set_label_text(_position_label, position_text)
	_set_label_text(_time_label, time_text)
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
