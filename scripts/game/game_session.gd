extends Node

signal selections_changed
signal settings_changed

const RaceConfigScript := preload("res://scripts/race/race_config.gd")

const DEFAULT_CAR_ID: StringName = &"apex_gt_blue"
const DEFAULT_TRACK_ID: StringName = &"showcase_circuit"
const DEFAULT_TRACK_SCENE_PATH: String = "res://scenes/race/showcase_circuit_race.tscn"
const COLOR_VARIANTS: Array[String] = ["blue", "red", "green", "yellow"]
const DIFFICULTIES: Array[String] = ["easy", "medium", "hard"]
const CAR_OPTIONS: Array[Dictionary] = [
	{
		"id": DEFAULT_CAR_ID,
		"display_name": "Apex GT Prototype",
		"short_name": "Apex GT",
		"description": "Balanced fictional prototype for the first premium vertical slice.",
		"color_variant": "blue",
		"scene_path": "res://scenes/player_car.tscn",
		"preview_scene_path": "res://assets/cars/customizable_hypercar_model3.glb",
		"model_path": "res://assets/cars/customizable_hypercar_model3.glb",
		"repaint_source_path": "res://assets/cars/customizable_hypercar_model3.glb",
		"uv_texture_path": "res://assets/cars/customizable_hypercar_model3_base_color.jpg",
		"stats": {
			"speed": 78,
			"grip": 72,
			"acceleration": 74,
			"drift": 70,
		},
	},
	{
		"id": &"ion_r_repaint",
		"display_name": "Ion R Repaint",
		"short_name": "Ion R",
		"description": "AI-retextured showcase car for prompt-driven paint experiments.",
		"color_variant": "red",
		"scene_path": "res://scenes/player_car.tscn",
		"preview_scene_path": "res://assets/cars/customizable_hypercar_model3_meshy_retexture.glb",
		"model_path": "res://assets/cars/customizable_hypercar_model3_meshy_retexture.glb",
		"repaint_source_path": "res://assets/cars/customizable_hypercar_model3.glb",
		"uv_texture_path": "res://assets/cars/customizable_hypercar_model3_meshy_base_color.png",
		"stats": {
			"speed": 82,
			"grip": 68,
			"acceleration": 79,
			"drift": 77,
		},
	},
	{
		"id": &"velocity_x_red",
		"display_name": "Velocity X",
		"short_name": "Velocity X",
		"description": "Imported hypercar placeholder with red-metallic texture support.",
		"color_variant": "yellow",
		"scene_path": "res://scenes/player_car.tscn",
		"preview_scene_path": "res://assets/cars/player_hypercar.glb",
		"model_path": "res://assets/cars/player_hypercar.glb",
		"repaint_source_path": "res://assets/cars/player_hypercar.glb",
		"uv_texture_path": "res://assets/cars/player_hypercar_red_metallic_studio_texture.png",
		"stats": {
			"speed": 86,
			"grip": 64,
			"acceleration": 84,
			"drift": 73,
		},
	},
]
const TRACK_OPTIONS: Array[Dictionary] = [
	{
		"id": DEFAULT_TRACK_ID,
		"display_name": "Showcase Circuit",
		"short_name": "Showcase",
		"description": "Closed-loop proving ground for handling, NPC tuning, and menu-to-race flow.",
		"scene_path": DEFAULT_TRACK_SCENE_PATH,
		"music_key": &"showcase_race_loop",
		"environment": &"test_circuit",
		"lap_count": 3,
		"target_length_m": 1800.0,
	},
	{
		"id": &"storm_coast",
		"display_name": "Storm Coast",
		"short_name": "Storm Coast",
		"description": "Premium coastal mountain route with wet-road lighting and dramatic elevation.",
		"scene_path": "res://scenes/race/storm_coast_preview_race.tscn",
		"music_key": &"storm_coast_premium_arcade_drive",
		"environment": &"coastal_mountain",
		"lap_count": 1,
		"target_length_m": 2200.0,
	},
]
const DIFFICULTY_OPTIONS: Array[Dictionary] = [
	{
		"id": &"easy",
		"display_name": "Easy",
		"description": "Forgiving NPC pace with wider racing lines and more mistakes.",
		"npc_speed_multiplier": 0.92,
	},
	{
		"id": &"medium",
		"display_name": "Medium",
		"description": "Baseline NPC pace for tuning the first vertical slice.",
		"npc_speed_multiplier": 1.0,
	},
	{
		"id": &"hard",
		"display_name": "Hard",
		"description": "Sharper NPC lines, fewer mistakes, and more assertive overtakes.",
		"npc_speed_multiplier": 1.04,
	},
]

@export var selected_car_id: StringName = DEFAULT_CAR_ID
@export var selected_car_color: String = "blue"
@export var selected_track_id: StringName = DEFAULT_TRACK_ID
@export var selected_track_scene_path: String = DEFAULT_TRACK_SCENE_PATH
@export var selected_difficulty: String = "medium"
@export_range(0.0, 1.0, 0.01) var master_volume: float = 0.85
@export_range(0.65, 1.35, 0.01) var brightness: float = 1.0


func _ready() -> void:
	_normalize_state()
	apply_audio_settings()


func set_car(car_id: Variant) -> void:
	var normalized: StringName = _normalize_car_id(car_id)
	var option: Dictionary = get_car_option(normalized)
	var color_variant: String = _normalize_color(str(option.get("color_variant", selected_car_color)))
	if selected_car_id == normalized and selected_car_color == color_variant:
		return
	selected_car_id = normalized
	selected_car_color = color_variant
	selections_changed.emit()


func get_car_id() -> StringName:
	return selected_car_id


func set_car_color(value: String) -> void:
	var normalized: String = _normalize_color(value)
	var matching_car_id: StringName = _car_id_for_color(normalized, selected_car_id)
	if selected_car_color == normalized and selected_car_id == matching_car_id:
		return
	selected_car_color = normalized
	selected_car_id = matching_car_id
	selections_changed.emit()


func get_car_color() -> String:
	return selected_car_color


func set_track(track_id: Variant, scene_path: String = "") -> void:
	var requested_track_id: StringName = _variant_to_string_name(track_id, DEFAULT_TRACK_ID)
	var track_option: Dictionary = _option_by_id_or_empty(TRACK_OPTIONS, requested_track_id)
	var safe_track_id: StringName = requested_track_id if requested_track_id != &"" else DEFAULT_TRACK_ID
	var safe_scene_path: String = scene_path
	if not track_option.is_empty():
		safe_track_id = StringName(track_option.get("id", safe_track_id))
		if safe_scene_path.is_empty():
			safe_scene_path = str(track_option.get("scene_path", DEFAULT_TRACK_SCENE_PATH))
	if safe_scene_path.is_empty():
		safe_scene_path = DEFAULT_TRACK_SCENE_PATH
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


func get_car_options() -> Array[Dictionary]:
	return _options_copy(CAR_OPTIONS)


func get_track_options() -> Array[Dictionary]:
	return _options_copy(TRACK_OPTIONS)


func get_difficulty_options() -> Array[Dictionary]:
	return _options_copy(DIFFICULTY_OPTIONS)


func get_car_option(car_id: Variant) -> Dictionary:
	return _option_by_id(CAR_OPTIONS, _variant_to_string_name(car_id, selected_car_id), DEFAULT_CAR_ID)


func get_selected_car_option() -> Dictionary:
	return get_car_option(selected_car_id)


func get_track_option(track_id: Variant) -> Dictionary:
	return _option_by_id(TRACK_OPTIONS, _variant_to_string_name(track_id, selected_track_id), DEFAULT_TRACK_ID)


func get_selected_track_option() -> Dictionary:
	return get_track_option(selected_track_id)


func get_difficulty_option(difficulty_id: Variant) -> Dictionary:
	return _option_by_id(DIFFICULTY_OPTIONS, _variant_to_string_name(difficulty_id, StringName(selected_difficulty)), StringName(selected_difficulty))


func get_selected_difficulty_option() -> Dictionary:
	return get_difficulty_option(selected_difficulty)


func get_car_scene_path() -> String:
	return str(get_selected_car_option().get("scene_path", "res://scenes/player_car.tscn"))


func get_car_preview_scene_path() -> String:
	return str(get_selected_car_option().get("preview_scene_path", get_car_scene_path()))


func get_car_model_path() -> String:
	return str(get_selected_car_option().get("model_path", get_car_preview_scene_path()))


func get_car_repaint_source_path() -> String:
	return str(get_selected_car_option().get("repaint_source_path", get_car_model_path()))


func get_car_uv_texture_path() -> String:
	return str(get_selected_car_option().get("uv_texture_path", ""))


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
	var track_option: Dictionary = get_selected_track_option()
	var lap_count_value: int = int(track_option.get("lap_count", config.lap_count))
	var track_length_value: float = float(track_option.get("target_length_m", config.default_track_length_m))
	config.lap_count = max(1, lap_count_value)
	config.default_track_length_m = maxf(1.0, track_length_value)
	return config


func get_selection_snapshot() -> Dictionary:
	var car_option: Dictionary = get_selected_car_option()
	var track_option: Dictionary = get_selected_track_option()
	return {
		"car_id": selected_car_id,
		"car_color": selected_car_color,
		"car_display_name": str(car_option.get("display_name", "")),
		"car_scene_path": get_car_scene_path(),
		"car_preview_scene_path": get_car_preview_scene_path(),
		"car_model_path": get_car_model_path(),
		"car_repaint_source_path": get_car_repaint_source_path(),
		"car_uv_texture_path": get_car_uv_texture_path(),
		"track_id": selected_track_id,
		"track_display_name": str(track_option.get("display_name", "")),
		"track_scene_path": get_track_scene_path(),
		"track_music_key": track_option.get("music_key", &""),
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
	selected_car_id = _normalize_car_id(selected_car_id)
	var selected_car_option: Dictionary = get_selected_car_option()
	selected_car_color = _normalize_color(str(selected_car_option.get("color_variant", selected_car_color)))
	selected_difficulty = _normalize_difficulty(selected_difficulty)
	selected_track_id = _normalize_track_id(selected_track_id)
	if selected_track_scene_path.is_empty():
		var selected_track_option: Dictionary = get_selected_track_option()
		selected_track_scene_path = str(selected_track_option.get("scene_path", DEFAULT_TRACK_SCENE_PATH))
	master_volume = clampf(master_volume, 0.0, 1.0)
	brightness = clampf(brightness, 0.65, 1.35)


func _normalize_car_id(value: Variant) -> StringName:
	var normalized: StringName = _variant_to_string_name(value, DEFAULT_CAR_ID)
	if _has_option_id(CAR_OPTIONS, normalized):
		return normalized
	return _car_id_for_color(selected_car_color, DEFAULT_CAR_ID)


func _normalize_track_id(value: Variant) -> StringName:
	var normalized: StringName = _variant_to_string_name(value, DEFAULT_TRACK_ID)
	if _has_option_id(TRACK_OPTIONS, normalized):
		return normalized
	return DEFAULT_TRACK_ID


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


func _variant_to_string_name(value: Variant, fallback: StringName) -> StringName:
	if value is StringName:
		var string_name_value: StringName = value
		return string_name_value if string_name_value != &"" else fallback
	var text: String = str(value)
	return StringName(text) if not text.is_empty() else fallback


func _options_copy(options: Array[Dictionary]) -> Array[Dictionary]:
	var copied_options: Array[Dictionary] = []
	for option: Dictionary in options:
		copied_options.append(option.duplicate(true))
	return copied_options


func _option_by_id(options: Array[Dictionary], option_id: StringName, fallback_id: StringName) -> Dictionary:
	var exact_option: Dictionary = _option_by_id_or_empty(options, option_id)
	if not exact_option.is_empty():
		return exact_option
	if option_id != fallback_id:
		return _option_by_id_or_empty(options, fallback_id)
	return {}


func _option_by_id_or_empty(options: Array[Dictionary], option_id: StringName) -> Dictionary:
	for option: Dictionary in options:
		if StringName(option.get("id", &"")) == option_id:
			return option.duplicate(true)
	return {}


func _has_option_id(options: Array[Dictionary], option_id: StringName) -> bool:
	for option: Dictionary in options:
		if StringName(option.get("id", &"")) == option_id:
			return true
	return false


func _car_id_for_color(color_variant: String, fallback_id: StringName) -> StringName:
	var normalized: String = _normalize_color(color_variant)
	for option: Dictionary in CAR_OPTIONS:
		if str(option.get("color_variant", "")).to_lower() == normalized:
			return StringName(option.get("id", fallback_id))
	return fallback_id


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
