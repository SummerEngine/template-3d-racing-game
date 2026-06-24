extends Node

signal selections_changed
signal settings_changed

const RaceConfigScript := preload("res://scripts/race/race_config.gd")

const DEFAULT_CAR_ID: StringName = &"vanta_r49"
const DEFAULT_SKIN_ID: StringName = &"vanta_r49_midnight"
const STORM_COAST_TRACK_SCENE_PATH: String = "res://scenes/race/storm_coast_preview_race.tscn"
const SHOWCASE_TRACK_SCENE_PATH: String = "res://scenes/tracks/manual_track_authoring.tscn"
const DEFAULT_TRACK_ID: StringName = &"storm_coast"
const DEFAULT_TRACK_SCENE_PATH: String = STORM_COAST_TRACK_SCENE_PATH
const DEFAULT_PLAYER_SCENE_PATH: String = "res://scenes/player_car.tscn"
const DEFAULT_CAR_MODEL_PATH: String = "res://assets/cars/player_hypercar.glb"
const DEFAULT_TRANSMISSION_MODE: String = "automatic"
const SETTINGS_PATH: String = "user://racing_template_settings.cfg"
const MIN_WINDOW_SIZE: Vector2i = Vector2i(1080, 720)

const COLOR_VARIANTS: Array[String] = ["blue", "red", "green", "yellow"]
const DIFFICULTIES: Array[String] = ["easy", "medium", "hard"]
const TRANSMISSION_MODES: Array[String] = ["automatic", "manual"]

const SKIN_PRESETS: Array[Dictionary] = [
	{
		"id": &"vanta_r49_midnight",
		"display_name": "Midnight Blue",
		"color_variant": "blue",
		"swatch": Color(0.05, 0.12, 0.28, 1.0),
	},
	{
		"id": &"vanta_r49_crimson",
		"display_name": "Crimson Graphite",
		"color_variant": "red",
		"swatch": Color(0.64, 0.03, 0.06, 1.0),
	},
	{
		"id": &"astra_r50_aurora",
		"display_name": "Aurora Green",
		"color_variant": "green",
		"swatch": Color(0.02, 0.66, 0.40, 1.0),
	},
	{
		"id": &"astra_r50_solar",
		"display_name": "Solar White",
		"color_variant": "yellow",
		"swatch": Color(1.0, 0.82, 0.18, 1.0),
	},
]

const CAR_OPTIONS: Array[Dictionary] = [
	{
		"id": DEFAULT_CAR_ID,
		"display_name": "Vanta R49",
		"short_name": "Vanta R49",
		"vehicle_class": "Prototype GT",
		"description": "Low, planted concept coupe with stable braking and a confident high-speed line.",
		"scene_path": DEFAULT_PLAYER_SCENE_PATH,
		"preview_scene_path": "res://assets/vehicles/vanta_r49/vanta_r49.glb",
			"model_path": "res://assets/vehicles/vanta_r49/vanta_r49.glb",
			"preview_texture_path": "res://assets/ui/car_cards/vanta_r49_card.png",
			"preferred_scene_path": "res://assets/vehicles/vanta_r49/vanta_r49.tscn",
		"preferred_preview_scene_path": "res://assets/vehicles/vanta_r49/vanta_r49.glb",
		"preferred_model_path": "res://assets/vehicles/vanta_r49/vanta_r49.glb",
		"fallback_scene_path": DEFAULT_PLAYER_SCENE_PATH,
		"fallback_preview_scene_path": DEFAULT_CAR_MODEL_PATH,
		"fallback_model_path": DEFAULT_CAR_MODEL_PATH,
		"model_mount_position": Vector3(0.0, 0.03, -0.40),
		"model_mount_rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"model_mount_scale": Vector3(0.94, 0.94, 0.94),
		"preview_scale_multiplier": 1.0,
		"source": "Sketchfab",
		"source_url": "https://sketchfab.com/3d-models/free-ai-based-conceptcar-049-public-domain-cc0-72547082a35946878d3f59101ab583fa",
		"source_asset_number": "049",
		"source_license": "Public Domain CC0",
		"default_skin_id": DEFAULT_SKIN_ID,
		"skin_ids": [&"vanta_r49_midnight", &"vanta_r49_crimson"],
		"stats": {
			"speed": 82,
			"launch": 76,
			"braking": 84,
			"cornering": 80,
		},
		"driving_overrides": {
			"max_speed": 96.0,
			"acceleration": 42.0,
			"brake_force": 78.0,
			"normal_lateral_grip": 62.0,
			"high_speed_turn_rate": 1.0,
			"rear_drive_power_oversteer": 3.6,
		},
	},
	{
		"id": &"astra_r50",
		"display_name": "Astra R50",
		"short_name": "Astra R50",
		"vehicle_class": "Aero Sprint",
		"description": "Sharper concept racer with stronger launch, lighter exits, and a livelier corner attitude.",
		"scene_path": DEFAULT_PLAYER_SCENE_PATH,
		"preview_scene_path": "res://assets/vehicles/astra_r50/astra_r50.glb",
			"model_path": "res://assets/vehicles/astra_r50/astra_r50.glb",
			"preview_texture_path": "res://assets/ui/car_cards/astra_r50_card.png",
			"preferred_scene_path": "res://assets/vehicles/astra_r50/astra_r50.tscn",
		"preferred_preview_scene_path": "res://assets/vehicles/astra_r50/astra_r50.glb",
		"preferred_model_path": "res://assets/vehicles/astra_r50/astra_r50.glb",
		"fallback_scene_path": DEFAULT_PLAYER_SCENE_PATH,
		"fallback_preview_scene_path": DEFAULT_CAR_MODEL_PATH,
		"fallback_model_path": DEFAULT_CAR_MODEL_PATH,
		"model_mount_position": Vector3(0.0, 0.03, 0.05),
		"model_mount_rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"model_mount_scale": Vector3(0.93, 0.93, 0.93),
		"preview_scale_multiplier": 1.9,
		"source": "Sketchfab",
		"source_url": "https://sketchfab.com/3d-models/free-ai-based-conceptcar-050-public-domain-cc0-3f7a98a53efe48068adddf0c0f3ddbae",
		"source_asset_number": "050",
		"source_license": "Public Domain CC0",
		"default_skin_id": &"astra_r50_aurora",
		"skin_ids": [&"astra_r50_aurora", &"astra_r50_solar"],
		"stats": {
			"speed": 86,
			"launch": 88,
			"braking": 72,
			"cornering": 76,
		},
		"driving_overrides": {
			"max_speed": 100.0,
			"acceleration": 54.0,
			"brake_force": 66.0,
			"normal_lateral_grip": 52.0,
			"high_speed_turn_rate": 0.90,
			"rear_drive_power_oversteer": 5.4,
		},
	},
]

const TRACK_OPTIONS: Array[Dictionary] = [
	{
		"id": &"storm_coast",
		"display_name": "Storm Coast",
		"short_name": "Storm Coast",
		"description": "Premium coastal mountain route with wet-road lighting, ocean haze, elevation, and fast readable corners.",
		"scene_path": STORM_COAST_TRACK_SCENE_PATH,
		"music_key": &"storm_coast_premium_arcade_drive",
		"environment": &"coastal_mountain",
		"lap_count": 1,
		"target_length_m": 2200.0,
		"preview_texture_path": "res://assets/ui/figma_tracks/figma_track_speedway.jpg",
		"is_available": true,
		"locked": false,
	},
	{
		"id": &"showcase_circuit",
		"display_name": "Showcase Circuit",
		"short_name": "Showcase",
		"description": "Manual test circuit that instances the authoring scene directly for driving, NPC, and camera validation.",
		"scene_path": SHOWCASE_TRACK_SCENE_PATH,
		"music_key": &"showcase_race_loop",
		"environment": &"test_circuit",
		"lap_count": 1,
		"target_length_m": 4000.0,
		"preview_texture_path": "res://assets/ui/figma_tracks/figma_track_oval.jpg",
		"is_available": true,
		"locked": false,
	},
]

const TRANSMISSION_OPTIONS: Array[Dictionary] = [
	{
		"id": DEFAULT_TRANSMISSION_MODE,
		"display_name": "Automatic",
		"description": "Session default. Uses the full speed range without requiring gear input.",
	},
	{
		"id": "manual",
		"display_name": "Manual",
		"description": "Keeps the existing shift-up and shift-down controls active.",
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
		"description": "Sharper NPC lines, fewer mistakes, and more assertive pressure.",
		"npc_speed_multiplier": 1.04,
	},
]

@export var selected_car_id: StringName = DEFAULT_CAR_ID
@export var selected_skin_id: StringName = DEFAULT_SKIN_ID
@export var selected_car_color: String = "blue"
@export var selected_track_id: StringName = DEFAULT_TRACK_ID
@export var selected_track_scene_path: String = DEFAULT_TRACK_SCENE_PATH
@export var selected_difficulty: String = "medium"
@export var selected_transmission_mode: String = DEFAULT_TRANSMISSION_MODE
@export_range(0.0, 1.0, 0.01) var master_volume: float = 1.0
@export_range(0.0, 1.0, 0.01) var music_volume: float = 0.82
@export_range(0.0, 1.0, 0.01) var sfx_volume: float = 0.86
@export_range(0.65, 1.35, 0.01) var brightness: float = 1.0

var _pending_loading_target: String = DEFAULT_TRACK_SCENE_PATH
var _preloaded_resources: Dictionary = {}


func _ready() -> void:
	_apply_minimum_window_size()
	_ensure_audio_buses()
	_load_settings()
	_normalize_state()
	apply_audio_settings()


func _apply_minimum_window_size() -> void:
	DisplayServer.window_set_min_size(MIN_WINDOW_SIZE)
	var current_size := DisplayServer.window_get_size()
	var clamped_size := Vector2i(
			maxi(current_size.x, MIN_WINDOW_SIZE.x),
			maxi(current_size.y, MIN_WINDOW_SIZE.y)
	)
	if clamped_size != current_size:
		DisplayServer.window_set_size(clamped_size)


func set_car(car_id: Variant) -> void:
	var normalized: StringName = _normalize_car_id(car_id)
	var option: Dictionary = get_car_option(normalized)
	var next_skin_id: StringName = _normalize_skin_id(option.get("default_skin_id", DEFAULT_SKIN_ID), option)
	if selected_car_id == normalized and selected_skin_id == next_skin_id:
		return
	selected_car_id = normalized
	selected_skin_id = next_skin_id
	selected_car_color = _color_for_skin(selected_skin_id)
	_save_settings()
	selections_changed.emit()


func get_car_id() -> StringName:
	return selected_car_id


func set_car_skin(car_id: Variant, skin_id: Variant) -> void:
	var normalized_car_id: StringName = _normalize_car_id(car_id)
	var car_option: Dictionary = get_car_option(normalized_car_id)
	var normalized_skin_id: StringName = _normalize_skin_id(skin_id, car_option)
	if selected_car_id == normalized_car_id and selected_skin_id == normalized_skin_id:
		return
	selected_car_id = normalized_car_id
	selected_skin_id = normalized_skin_id
	selected_car_color = _color_for_skin(selected_skin_id)
	_save_settings()
	selections_changed.emit()


func get_car_skin_id() -> StringName:
	return selected_skin_id


func set_car_color(value: String) -> void:
	var normalized: String = _normalize_color(value)
	if selected_car_color == normalized:
		return
	selected_car_color = normalized
	selected_skin_id = _skin_id_for_color(normalized, selected_skin_id, get_selected_car_option())
	_save_settings()
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
	_save_settings()
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
	_save_settings()
	selections_changed.emit()


func get_difficulty() -> String:
	return selected_difficulty


func set_transmission_mode(value: Variant) -> void:
	var normalized: String = _normalize_transmission_mode(value)
	if selected_transmission_mode == normalized:
		return
	selected_transmission_mode = normalized
	_save_settings()
	settings_changed.emit()


func get_transmission_mode() -> String:
	return selected_transmission_mode


func is_automatic_transmission() -> bool:
	return selected_transmission_mode == DEFAULT_TRANSMISSION_MODE


func get_car_options() -> Array[Dictionary]:
	return _car_options_copy(CAR_OPTIONS)


func get_skin_presets() -> Array[Dictionary]:
	return _options_copy(SKIN_PRESETS)


func get_track_options() -> Array[Dictionary]:
	return _options_copy(TRACK_OPTIONS)


func get_difficulty_options() -> Array[Dictionary]:
	return _options_copy(DIFFICULTY_OPTIONS)


func get_transmission_options() -> Array[Dictionary]:
	return _options_copy(TRANSMISSION_OPTIONS)


func get_car_option(car_id: Variant) -> Dictionary:
	var option: Dictionary = _option_by_id(CAR_OPTIONS, _variant_to_string_name(car_id, selected_car_id), DEFAULT_CAR_ID)
	return _resolve_car_option_paths(option) if not option.is_empty() else {}


func get_selected_car_option() -> Dictionary:
	return get_car_option(selected_car_id)


func get_skin_preset(skin_id: Variant) -> Dictionary:
	return _option_by_id(SKIN_PRESETS, _variant_to_string_name(skin_id, selected_skin_id), DEFAULT_SKIN_ID)


func get_selected_skin_preset() -> Dictionary:
	return get_skin_preset(selected_skin_id)


func get_track_option(track_id: Variant) -> Dictionary:
	return _option_by_id(TRACK_OPTIONS, _variant_to_string_name(track_id, selected_track_id), DEFAULT_TRACK_ID)


func get_selected_track_option() -> Dictionary:
	return get_track_option(selected_track_id)


func get_difficulty_option(difficulty_id: Variant) -> Dictionary:
	return _option_by_id(DIFFICULTY_OPTIONS, _variant_to_string_name(difficulty_id, StringName(selected_difficulty)), StringName(selected_difficulty))


func get_selected_difficulty_option() -> Dictionary:
	return get_difficulty_option(selected_difficulty)


func get_car_scene_path() -> String:
	return str(get_selected_car_option().get("scene_path", DEFAULT_PLAYER_SCENE_PATH))


func get_car_preview_scene_path() -> String:
	return str(get_selected_car_option().get("preview_scene_path", get_car_scene_path()))


func get_car_model_path() -> String:
	return str(get_selected_car_option().get("model_path", get_car_preview_scene_path()))


func set_master_volume(value: float) -> void:
	var normalized: float = clampf(value, 0.0, 1.0)
	if is_equal_approx(master_volume, normalized):
		return
	master_volume = normalized
	_save_settings()
	apply_audio_settings()
	settings_changed.emit()


func get_master_volume() -> float:
	return master_volume


func set_music_volume(value: float) -> void:
	var normalized: float = clampf(value, 0.0, 1.0)
	if is_equal_approx(music_volume, normalized):
		return
	music_volume = normalized
	_save_settings()
	apply_audio_settings()
	settings_changed.emit()


func get_music_volume() -> float:
	return music_volume


func set_sfx_volume(value: float) -> void:
	var normalized: float = clampf(value, 0.0, 1.0)
	if is_equal_approx(sfx_volume, normalized):
		return
	sfx_volume = normalized
	_save_settings()
	apply_audio_settings()
	settings_changed.emit()


func get_sfx_volume() -> float:
	return sfx_volume


func set_brightness(value: float) -> void:
	var normalized: float = clampf(value, 0.65, 1.35)
	if is_equal_approx(brightness, normalized):
		return
	brightness = normalized
	_save_settings()
	settings_changed.emit()


func get_brightness() -> float:
	return brightness


func set_brightness_percent(value: float) -> void:
	set_brightness(lerpf(0.65, 1.35, clampf(value, 0.0, 100.0) / 100.0))


func get_brightness_percent() -> float:
	return roundf(inverse_lerp(0.65, 1.35, brightness) * 100.0)


func build_race_config() -> Resource:
	var config = RaceConfigScript.new()
	config.set_difficulty_id(StringName(selected_difficulty))
	var track_option: Dictionary = get_selected_track_option()
	var lap_count_value: int = int(track_option.get("lap_count", config.lap_count))
	var track_length_value: float = float(track_option.get("target_length_m", config.default_track_length_m))
	config.lap_count = max(1, lap_count_value)
	config.default_track_length_m = maxf(1.0, track_length_value)
	return config


func apply_selected_car_to_vehicle(vehicle: Node) -> void:
	if vehicle == null:
		return
	var skin: Dictionary = get_selected_skin_preset()
	var color_variant: String = _normalize_color(str(skin.get("color_variant", selected_car_color)))
	if vehicle.has_method("set_car_color_variant"):
		vehicle.call("set_car_color_variant", color_variant)
	else:
		_set_if_property(vehicle, &"car_color_variant", color_variant)

	var overrides: Dictionary = get_selected_car_option().get("driving_overrides", {})
	for property_name: String in overrides.keys():
		_set_if_property(vehicle, StringName(property_name), overrides[property_name])
	_apply_transmission_mode_to_vehicle(vehicle)
	_apply_selected_visual_model_to_vehicle(vehicle)


func get_selection_snapshot() -> Dictionary:
	var car_option: Dictionary = get_selected_car_option()
	var skin_option: Dictionary = get_selected_skin_preset()
	var track_option: Dictionary = get_selected_track_option()
	return {
		"car_id": selected_car_id,
		"car_skin_id": selected_skin_id,
		"car_color": selected_car_color,
		"car_display_name": str(car_option.get("display_name", "")),
		"car_skin_display_name": str(skin_option.get("display_name", "")),
		"car_scene_path": get_car_scene_path(),
		"car_preview_scene_path": get_car_preview_scene_path(),
		"car_model_path": get_car_model_path(),
		"car_source": str(car_option.get("source", "")),
		"car_source_url": str(car_option.get("source_url", "")),
		"car_source_asset_number": str(car_option.get("source_asset_number", "")),
		"car_source_license": str(car_option.get("source_license", "")),
		"track_id": selected_track_id,
		"track_display_name": str(track_option.get("display_name", "")),
		"track_scene_path": get_track_scene_path(),
		"track_music_key": track_option.get("music_key", &""),
		"difficulty": selected_difficulty,
		"transmission_mode": selected_transmission_mode,
	}


func get_settings_snapshot() -> Dictionary:
	return {
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"brightness": brightness,
		"brightness_percent": get_brightness_percent(),
		"transmission_mode": selected_transmission_mode,
	}


func get_boot_loading_manifest() -> Array[String]:
	return _dedupe_paths([
		"res://scenes/ui/main_menu.tscn",
		"res://assets/ui/menu_showroom_background.png",
		"res://assets/audio/music/race_loop_arcade_drift.mp3",
		DEFAULT_PLAYER_SCENE_PATH,
		DEFAULT_CAR_MODEL_PATH,
	])


func prepare_race_loading() -> void:
	_pending_loading_target = get_track_scene_path()


func get_pending_loading_target() -> String:
	return _pending_loading_target if not _pending_loading_target.is_empty() else get_track_scene_path()


func get_race_loading_manifest() -> Array[String]:
	var paths: Array[String] = [
		get_track_scene_path(),
		get_car_scene_path(),
		get_car_model_path(),
		"res://assets/audio/music/race_loop_arcade_drift.mp3",
		"res://assets/audio/sfx/countdown_start_stinger.mp3",
		"res://assets/audio/sfx/race_finish_stinger.mp3",
		"res://assets/audio/sfx/engine_hybrid_idle_loop.mp3",
		"res://assets/audio/sfx/vehicles/premium_engine_acceleration_loop.wav",
		"res://assets/audio/sfx/vehicles/premium_braking_deceleration_loop.wav",
		"res://assets/audio/sfx/vehicles/premium_drift_tire_scrub_loop.wav",
	]
	return _dedupe_paths(paths)


func remember_preloaded_resource(path: String, resource: Resource) -> void:
	if path.is_empty() or resource == null:
		return
	_preloaded_resources[path] = resource


func get_preloaded_resource(path: String) -> Resource:
	return _preloaded_resources.get(path, null) as Resource


func clear_preloaded_resources() -> void:
	_preloaded_resources.clear()


func apply_audio_settings() -> void:
	_ensure_audio_buses()
	_apply_bus_volume("Master", master_volume)
	_apply_bus_volume("Music", music_volume)
	_apply_bus_volume("SFX", sfx_volume)


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
	selected_car_id = _normalize_car_id(selected_car_id)
	var selected_car_option: Dictionary = get_selected_car_option()
	selected_skin_id = _normalize_skin_id(selected_skin_id, selected_car_option)
	selected_car_color = _color_for_skin(selected_skin_id)
	selected_difficulty = _normalize_difficulty(selected_difficulty)
	selected_transmission_mode = _normalize_transmission_mode(selected_transmission_mode)
	selected_track_id = _normalize_track_id(selected_track_id)
	var selected_track_option: Dictionary = get_selected_track_option()
	var normalized_track_scene_path: String = str(selected_track_option.get("scene_path", DEFAULT_TRACK_SCENE_PATH))
	selected_track_scene_path = normalized_track_scene_path if not normalized_track_scene_path.is_empty() else DEFAULT_TRACK_SCENE_PATH
	master_volume = clampf(master_volume, 0.0, 1.0)
	music_volume = clampf(music_volume, 0.0, 1.0)
	sfx_volume = clampf(sfx_volume, 0.0, 1.0)
	brightness = clampf(brightness, 0.65, 1.35)
	_pending_loading_target = get_track_scene_path()


func _normalize_car_id(value: Variant) -> StringName:
	var normalized: StringName = _variant_to_string_name(value, DEFAULT_CAR_ID)
	if _has_option_id(CAR_OPTIONS, normalized):
		return normalized
	return DEFAULT_CAR_ID


func _normalize_skin_id(value: Variant, car_option: Dictionary) -> StringName:
	var normalized: StringName = _variant_to_string_name(value, DEFAULT_SKIN_ID)
	var allowed_skins: Array = car_option.get("skin_ids", [])
	if allowed_skins.has(normalized) and _has_option_id(SKIN_PRESETS, normalized):
		return normalized
	var default_skin: StringName = _variant_to_string_name(car_option.get("default_skin_id", DEFAULT_SKIN_ID), DEFAULT_SKIN_ID)
	if _has_option_id(SKIN_PRESETS, default_skin):
		return default_skin
	return DEFAULT_SKIN_ID


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


func _normalize_transmission_mode(value: Variant) -> String:
	var normalized: String = str(value).to_lower()
	if TRANSMISSION_MODES.has(normalized):
		return normalized
	return DEFAULT_TRANSMISSION_MODE


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


func _car_options_copy(options: Array[Dictionary]) -> Array[Dictionary]:
	var copied_options: Array[Dictionary] = []
	for option: Dictionary in options:
		copied_options.append(_resolve_car_option_paths(option))
	return copied_options


func _resolve_car_option_paths(option: Dictionary) -> Dictionary:
	var resolved: Dictionary = option.duplicate(true)
	resolved["scene_path"] = _resolve_resource_path(
			str(resolved.get("preferred_scene_path", "")),
			str(resolved.get("fallback_scene_path", resolved.get("scene_path", DEFAULT_PLAYER_SCENE_PATH)))
	)
	resolved["preview_scene_path"] = _resolve_resource_path(
			str(resolved.get("preferred_preview_scene_path", "")),
			str(resolved.get("fallback_preview_scene_path", resolved.get("preview_scene_path", resolved["scene_path"])))
	)
	resolved["model_path"] = _resolve_resource_path(
			str(resolved.get("preferred_model_path", "")),
			str(resolved.get("fallback_model_path", resolved.get("model_path", resolved["preview_scene_path"])))
	)
	return resolved


func _resolve_resource_path(preferred_path: String, fallback_path: String) -> String:
	if _resource_path_ready(preferred_path):
		return preferred_path
	return fallback_path


func _resource_path_ready(path: String) -> bool:
	if path.is_empty() or not ResourceLoader.exists(path):
		return false
	var extension: String = path.get_extension().to_lower()
	if extension in ["glb", "gltf", "obj", "fbx"]:
		return FileAccess.file_exists("%s.import" % path)
	return true


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


func _color_for_skin(skin_id: StringName) -> String:
	var skin: Dictionary = get_skin_preset(skin_id)
	return _normalize_color(str(skin.get("color_variant", "blue")))


func _skin_id_for_color(color_variant: String, fallback_id: StringName, car_option: Dictionary = {}) -> StringName:
	var normalized: String = _normalize_color(color_variant)
	var allowed_skins: Array = car_option.get("skin_ids", [])
	for option: Dictionary in SKIN_PRESETS:
		var skin_id: StringName = StringName(option.get("id", fallback_id))
		if not allowed_skins.is_empty() and not allowed_skins.has(skin_id):
			continue
		if str(option.get("color_variant", "")).to_lower() == normalized:
			return skin_id
	return fallback_id


func _apply_transmission_mode_to_vehicle(vehicle: Node) -> void:
	var automatic_enabled: bool = selected_transmission_mode == DEFAULT_TRANSMISSION_MODE
	if vehicle.has_method("set_automatic_transmission_enabled"):
		vehicle.call("set_automatic_transmission_enabled", automatic_enabled)
	elif vehicle.has_method("set_manual_transmission_enabled"):
		vehicle.call("set_manual_transmission_enabled", not automatic_enabled)
	else:
		_set_if_property(vehicle, &"automatic_transmission", automatic_enabled)


func _apply_selected_visual_model_to_vehicle(vehicle: Node) -> void:
	var vehicle_node := vehicle as Node
	if vehicle_node == null:
		return
	var mount := vehicle_node.get_node_or_null("VisualRoot/ModelMount") as Node3D
	if mount == null:
		return
	var model_path: String = get_car_model_path()
	if model_path.is_empty() or model_path == DEFAULT_CAR_MODEL_PATH:
		return
	if not _resource_path_ready(model_path):
		return
	if str(mount.get_meta(&"session_model_path", "")) == model_path:
		mount.transform = _selected_model_mount_transform()
		return

	var packed := load(model_path) as PackedScene
	if packed == null:
		return
	for child: Node in mount.get_children():
		mount.remove_child(child)
		child.queue_free()
	mount.transform = _selected_model_mount_transform()
	var instance := packed.instantiate()
	instance.name = "SelectedCarModel"
	mount.add_child(instance)
	mount.set_meta(&"session_model_path", model_path)


func _selected_model_mount_transform() -> Transform3D:
	var car: Dictionary = get_selected_car_option()
	var position: Vector3 = _variant_to_vector3(car.get("model_mount_position", Vector3.ZERO), Vector3.ZERO)
	var rotation_degrees: Vector3 = _variant_to_vector3(car.get("model_mount_rotation_degrees", Vector3.ZERO), Vector3.ZERO)
	var scale: Vector3 = _variant_to_vector3(car.get("model_mount_scale", Vector3.ONE), Vector3.ONE)
	var rotation_radians := Vector3(
			deg_to_rad(rotation_degrees.x),
			deg_to_rad(rotation_degrees.y),
			deg_to_rad(rotation_degrees.z)
	)
	var basis := Basis.from_euler(rotation_radians)
	basis = basis.scaled(scale)
	return Transform3D(basis, position)


func _variant_to_vector3(value: Variant, fallback: Vector3) -> Vector3:
	if value is Vector3:
		return value
	if value is Vector2:
		var vector2_value := value as Vector2
		return Vector3(vector2_value.x, vector2_value.y, fallback.z)
	if value is float or value is int:
		var scalar := float(value)
		return Vector3(scalar, scalar, scalar)
	if value is Array:
		var array_value: Array = value
		if array_value.size() >= 3:
			return Vector3(float(array_value[0]), float(array_value[1]), float(array_value[2]))
	return fallback


func _dedupe_paths(paths: Array[String]) -> Array[String]:
	var result: Array[String] = []
	var seen: Dictionary = {}
	for path: String in paths:
		if path.is_empty() or seen.has(path):
			continue
		seen[path] = true
		result.append(path)
	return result


func _ensure_audio_buses() -> void:
	_ensure_audio_bus("Music")
	_ensure_audio_bus("SFX")


func _ensure_audio_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var bus_index: int = AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(bus_index, bus_name)
	AudioServer.set_bus_send(bus_index, "Master")


func _apply_bus_volume(bus_name: String, linear_volume: float) -> void:
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	var safe_volume: float = clampf(linear_volume, 0.0, 1.0)
	AudioServer.set_bus_mute(bus_index, safe_volume <= 0.001)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(safe_volume, 0.001)))


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	selected_car_id = _variant_to_string_name(config.get_value("selection", "car_id", selected_car_id), selected_car_id)
	selected_skin_id = _variant_to_string_name(config.get_value("selection", "skin_id", selected_skin_id), selected_skin_id)
	selected_track_id = _variant_to_string_name(config.get_value("selection", "track_id", selected_track_id), selected_track_id)
	selected_track_scene_path = str(config.get_value("selection", "track_scene_path", selected_track_scene_path))
	if selected_track_id == &"showcase_circuit" and selected_track_scene_path == SHOWCASE_TRACK_SCENE_PATH:
		selected_track_id = DEFAULT_TRACK_ID
		selected_track_scene_path = DEFAULT_TRACK_SCENE_PATH
	selected_difficulty = str(config.get_value("selection", "difficulty", selected_difficulty))
	selected_transmission_mode = _normalize_transmission_mode(config.get_value("driving", "transmission_mode", selected_transmission_mode))
	master_volume = float(config.get_value("audio", "master_volume", master_volume))
	music_volume = float(config.get_value("audio", "music_volume", music_volume))
	sfx_volume = float(config.get_value("audio", "sfx_volume", sfx_volume))
	brightness = float(config.get_value("display", "brightness", brightness))


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("selection", "car_id", String(selected_car_id))
	config.set_value("selection", "skin_id", String(selected_skin_id))
	config.set_value("selection", "track_id", String(selected_track_id))
	config.set_value("selection", "track_scene_path", get_track_scene_path())
	config.set_value("selection", "difficulty", selected_difficulty)
	config.set_value("driving", "transmission_mode", selected_transmission_mode)
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("display", "brightness", brightness)
	config.save(SETTINGS_PATH)


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


func _object_float_property(target: Object, property_name: StringName, fallback: float) -> float:
	if target == null:
		return fallback
	for property: Dictionary in target.get_property_list():
		if String(property.get("name", "")) == String(property_name):
			return float(target.get(property_name))
	return fallback
