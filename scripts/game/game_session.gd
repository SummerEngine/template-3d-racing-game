extends Node

signal selections_changed
signal settings_changed

const RaceConfigScript := preload("res://scripts/race/race_config.gd")

const DEFAULT_TRACK_ID: StringName = &"showcase_circuit"
const DEFAULT_TRACK_SCENE_PATH: String = "res://scenes/race/showcase_circuit_race.tscn"
const COLOR_VARIANTS: Array[String] = ["blue", "red", "green", "yellow"]
const DIFFICULTIES: Array[String] = ["easy", "medium", "hard"]

@export var selected_car_color: String = "blue"
@export var selected_track_id: StringName = DEFAULT_TRACK_ID
@export var selected_track_scene_path: String = DEFAULT_TRACK_SCENE_PATH
@export var selected_difficulty: String = "medium"
@export_range(0.0, 1.0, 0.01) var master_volume: float = 0.85
@export_range(0.65, 1.35, 0.01) var brightness: float = 1.0


func _ready() -> void:
	_normalize_state()
	apply_audio_settings()


func set_car_color(value: String) -> void:
	var normalized: String = _normalize_color(value)
	if selected_car_color == normalized:
		return
	selected_car_color = normalized
	selections_changed.emit()


func get_car_color() -> String:
	return selected_car_color


func set_track(track_id: StringName, scene_path: String) -> void:
	var safe_track_id: StringName = track_id if track_id != &"" else DEFAULT_TRACK_ID
	var safe_scene_path: String = scene_path if not scene_path.is_empty() else DEFAULT_TRACK_SCENE_PATH
	if selected_track_id == safe_track_id and selected_track_scene_path == safe_scene_path:
		return
	selected_track_id = safe_track_id
	selected_track_scene_path = safe_scene_path
	selections_changed.emit()


func get_track_id() -> StringName:
	return selected_track_id


func get_track_scene_path() -> String:
	return selected_track_scene_path if not selected_track_scene_path.is_empty() else DEFAULT_TRACK_SCENE_PATH


func set_difficulty(value: String) -> void:
	var normalized: String = _normalize_difficulty(value)
	if selected_difficulty == normalized:
		return
	selected_difficulty = normalized
	selections_changed.emit()


func get_difficulty() -> String:
	return selected_difficulty


func set_master_volume(value: float) -> void:
	var normalized: float = clampf(value, 0.0, 1.0)
	if is_equal_approx(master_volume, normalized):
		return
	master_volume = normalized
	apply_audio_settings()
	settings_changed.emit()


func get_master_volume() -> float:
	return master_volume


func set_brightness(value: float) -> void:
	var normalized: float = clampf(value, 0.65, 1.35)
	if is_equal_approx(brightness, normalized):
		return
	brightness = normalized
	settings_changed.emit()


func get_brightness() -> float:
	return brightness


func build_race_config() -> Resource:
	var config = RaceConfigScript.new()
	config.set_difficulty_id(StringName(selected_difficulty))
	return config


func get_selection_snapshot() -> Dictionary:
	return {
		"car_color": selected_car_color,
		"track_id": selected_track_id,
		"track_scene_path": get_track_scene_path(),
		"difficulty": selected_difficulty,
	}


func get_settings_snapshot() -> Dictionary:
	return {
		"master_volume": master_volume,
		"brightness": brightness,
	}


func apply_audio_settings() -> void:
	var master_bus_index: int = AudioServer.get_bus_index("Master")
	if master_bus_index < 0:
		return
	AudioServer.set_bus_mute(master_bus_index, master_volume <= 0.001)
	var linear_volume: float = maxf(master_volume, 0.001)
	AudioServer.set_bus_volume_db(master_bus_index, linear_to_db(linear_volume))


func apply_brightness_to_scene(root: Node) -> void:
	if root == null:
		return
	var environments: Array[WorldEnvironment] = []
	_collect_world_environments(root, environments)
	for world_environment: WorldEnvironment in environments:
		if world_environment.environment == null:
			continue
		_set_if_property(world_environment.environment, &"adjustment_enabled", true)
		_set_if_property(world_environment.environment, &"adjustment_brightness", brightness)


func _normalize_state() -> void:
	selected_car_color = _normalize_color(selected_car_color)
	selected_difficulty = _normalize_difficulty(selected_difficulty)
	if selected_track_id == &"":
		selected_track_id = DEFAULT_TRACK_ID
	if selected_track_scene_path.is_empty():
		selected_track_scene_path = DEFAULT_TRACK_SCENE_PATH
	master_volume = clampf(master_volume, 0.0, 1.0)
	brightness = clampf(brightness, 0.65, 1.35)


func _normalize_color(value: String) -> String:
	var normalized: String = value.to_lower()
	if COLOR_VARIANTS.has(normalized):
		return normalized
	return "blue"


func _normalize_difficulty(value: String) -> String:
	var normalized: String = value.to_lower()
	if DIFFICULTIES.has(normalized):
		return normalized
	return "medium"


func _collect_world_environments(root: Node, result: Array[WorldEnvironment]) -> void:
	if root is WorldEnvironment:
		result.append(root as WorldEnvironment)
	for child: Node in root.get_children():
		_collect_world_environments(child, result)


func _set_if_property(target: Object, property_name: StringName, value: Variant) -> void:
	if target == null:
		return
	for property: Dictionary in target.get_property_list():
		if String(property.get("name", "")) == String(property_name):
			target.set(property_name, value)
			return
