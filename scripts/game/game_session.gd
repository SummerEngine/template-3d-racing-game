extends Node

signal selections_changed
signal settings_changed

const RaceConfigScript := preload("res://scripts/race/race_config.gd")

const DEFAULT_CAR_ID: StringName = &"apex_gt"
const DEFAULT_SKIN_ID: StringName = &"electric_blue"
const DEFAULT_TRACK_ID: StringName = &"storm_coast"
const DEFAULT_TRACK_SCENE_PATH: String = "res://scenes/race/storm_coast_preview_race.tscn"
const DEFAULT_PLAYER_SCENE_PATH: String = "res://scenes/player_car.tscn"
const DEFAULT_CAR_MODEL_PATH: String = "res://assets/cars/player_hypercar.glb"
const SETTINGS_PATH: String = "user://racing_template_settings.cfg"

const COLOR_VARIANTS: Array[String] = ["blue", "red", "green", "yellow"]
const DIFFICULTIES: Array[String] = ["easy", "medium", "hard"]

const SKIN_PRESETS: Array[Dictionary] = [
	{
		"id": &"electric_blue",
		"display_name": "Electric Blue",
		"color_variant": "blue",
		"swatch": Color(0.08, 0.24, 0.9, 1.0),
	},
	{
		"id": &"pulse_red",
		"display_name": "Pulse Red",
		"color_variant": "red",
		"swatch": Color(0.94, 0.12, 0.08, 1.0),
	},
	{
		"id": &"volt_lime",
		"display_name": "Volt Lime",
		"color_variant": "green",
		"swatch": Color(0.08, 0.74, 0.32, 1.0),
	},
	{
		"id": &"solar_yellow",
		"display_name": "Solar Yellow",
		"color_variant": "yellow",
		"swatch": Color(1.0, 0.82, 0.08, 1.0),
	},
]

const CAR_OPTIONS: Array[Dictionary] = [
	{
		"id": DEFAULT_CAR_ID,
		"display_name": "Apex GT Prototype",
		"short_name": "Apex GT",
		"vehicle_class": "Prototype Hybrid",
		"description": "Balanced fictional prototype for the first premium racing slice.",
		"scene_path": DEFAULT_PLAYER_SCENE_PATH,
		"preview_scene_path": DEFAULT_CAR_MODEL_PATH,
		"model_path": DEFAULT_CAR_MODEL_PATH,
		"default_skin_id": DEFAULT_SKIN_ID,
		"skin_ids": [&"electric_blue", &"pulse_red", &"volt_lime", &"solar_yellow"],
		"stats": {
			"speed": 78,
			"launch": 74,
			"braking": 76,
			"cornering": 72,
		},
		"driving_overrides": {
			"max_speed": 92.0,
			"acceleration": 42.0,
			"brake_force": 70.0,
			"normal_lateral_grip": 58.0,
			"high_speed_turn_rate": 0.95,
			"rear_drive_power_oversteer": 4.0,
		},
	},
	{
		"id": &"ion_r",
		"display_name": "Ion R",
		"short_name": "Ion R",
		"vehicle_class": "Sprint Special",
		"description": "Fast launch and lighter corner exits for punchier arcade racing.",
		"scene_path": DEFAULT_PLAYER_SCENE_PATH,
		"preview_scene_path": DEFAULT_CAR_MODEL_PATH,
		"model_path": DEFAULT_CAR_MODEL_PATH,
		"default_skin_id": &"pulse_red",
		"skin_ids": [&"pulse_red", &"electric_blue", &"solar_yellow", &"volt_lime"],
		"stats": {
			"speed": 82,
			"launch": 88,
			"braking": 70,
			"cornering": 68,
		},
		"driving_overrides": {
			"max_speed": 96.0,
			"acceleration": 50.0,
			"brake_force": 64.0,
			"normal_lateral_grip": 53.0,
			"high_speed_turn_rate": 0.88,
			"rear_drive_power_oversteer": 5.2,
		},
	},
	{
		"id": &"velocity_x",
		"display_name": "Velocity X",
		"short_name": "Velocity X",
		"vehicle_class": "Endurance Special",
		"description": "Higher top-end stability with more deliberate acceleration.",
		"scene_path": DEFAULT_PLAYER_SCENE_PATH,
		"preview_scene_path": DEFAULT_CAR_MODEL_PATH,
		"model_path": DEFAULT_CAR_MODEL_PATH,
		"default_skin_id": &"solar_yellow",
		"skin_ids": [&"solar_yellow", &"electric_blue", &"pulse_red", &"volt_lime"],
		"stats": {
			"speed": 88,
			"launch": 68,
			"braking": 84,
			"cornering": 80,
		},
		"driving_overrides": {
			"max_speed": 102.0,
			"acceleration": 37.0,
			"brake_force": 78.0,
			"normal_lateral_grip": 62.0,
			"high_speed_turn_rate": 1.02,
			"rear_drive_power_oversteer": 3.2,
		},
	},
	{
		"id": &"mirage_s",
		"display_name": "Mirage S",
		"short_name": "Mirage S",
		"vehicle_class": "Aero Coupe",
		"description": "Stable high-speed test entry with gentle cornering for menu-card scroll checks.",
		"scene_path": DEFAULT_PLAYER_SCENE_PATH,
		"preview_scene_path": DEFAULT_CAR_MODEL_PATH,
		"model_path": DEFAULT_CAR_MODEL_PATH,
		"default_skin_id": &"volt_lime",
		"skin_ids": [&"volt_lime", &"electric_blue", &"pulse_red", &"solar_yellow"],
		"stats": {
			"speed": 74,
			"launch": 72,
			"braking": 86,
			"cornering": 84,
		},
		"driving_overrides": {
			"max_speed": 88.0,
			"acceleration": 40.0,
			"brake_force": 82.0,
			"normal_lateral_grip": 64.0,
			"high_speed_turn_rate": 1.08,
			"rear_drive_power_oversteer": 2.8,
		},
	},
	{
		"id": &"rift_rs",
		"display_name": "Rift RS",
		"short_name": "Rift RS",
		"vehicle_class": "Street Prototype",
		"description": "Aggressive acceleration and looser exits for testing fast-looking stat bars.",
		"scene_path": DEFAULT_PLAYER_SCENE_PATH,
		"preview_scene_path": DEFAULT_CAR_MODEL_PATH,
		"model_path": DEFAULT_CAR_MODEL_PATH,
		"default_skin_id": &"pulse_red",
		"skin_ids": [&"pulse_red", &"solar_yellow", &"electric_blue", &"volt_lime"],
		"stats": {
			"speed": 80,
			"launch": 92,
			"braking": 66,
			"cornering": 70,
		},
		"driving_overrides": {
			"max_speed": 94.0,
			"acceleration": 54.0,
			"brake_force": 60.0,
			"normal_lateral_grip": 52.0,
			"high_speed_turn_rate": 0.90,
			"rear_drive_power_oversteer": 6.0,
		},
	},
	{
		"id": &"nova_v",
		"display_name": "Nova V",
		"short_name": "Nova V",
		"vehicle_class": "Grand Tourer",
		"description": "Heavier balanced test car for checking long names and middle-range stats.",
		"scene_path": DEFAULT_PLAYER_SCENE_PATH,
		"preview_scene_path": DEFAULT_CAR_MODEL_PATH,
		"model_path": DEFAULT_CAR_MODEL_PATH,
		"default_skin_id": &"electric_blue",
		"skin_ids": [&"electric_blue", &"solar_yellow", &"pulse_red", &"volt_lime"],
		"stats": {
			"speed": 84,
			"launch": 64,
			"braking": 78,
			"cornering": 76,
		},
		"driving_overrides": {
			"max_speed": 98.0,
			"acceleration": 35.0,
			"brake_force": 72.0,
			"normal_lateral_grip": 59.0,
			"high_speed_turn_rate": 0.98,
			"rear_drive_power_oversteer": 3.7,
		},
	},
	{
		"id": &"pulse_xr",
		"display_name": "Pulse XR",
		"short_name": "Pulse XR",
		"vehicle_class": "Track Special",
		"description": "Sharp cornering and braking profile for testing card selection feedback.",
		"scene_path": DEFAULT_PLAYER_SCENE_PATH,
		"preview_scene_path": DEFAULT_CAR_MODEL_PATH,
		"model_path": DEFAULT_CAR_MODEL_PATH,
		"default_skin_id": &"solar_yellow",
		"skin_ids": [&"solar_yellow", &"volt_lime", &"electric_blue", &"pulse_red"],
		"stats": {
			"speed": 76,
			"launch": 76,
			"braking": 90,
			"cornering": 88,
		},
		"driving_overrides": {
			"max_speed": 90.0,
			"acceleration": 43.0,
			"brake_force": 86.0,
			"normal_lateral_grip": 67.0,
			"high_speed_turn_rate": 1.12,
			"rear_drive_power_oversteer": 2.5,
		},
	},
	{
		"id": &"zenith_lm",
		"display_name": "Zenith LM",
		"short_name": "Zenith LM",
		"vehicle_class": "Endurance Prototype",
		"description": "Fast and composed long-distance placeholder for scroll stress testing.",
		"scene_path": DEFAULT_PLAYER_SCENE_PATH,
		"preview_scene_path": DEFAULT_CAR_MODEL_PATH,
		"model_path": DEFAULT_CAR_MODEL_PATH,
		"default_skin_id": &"electric_blue",
		"skin_ids": [&"electric_blue", &"pulse_red", &"solar_yellow", &"volt_lime"],
		"stats": {
			"speed": 92,
			"launch": 70,
			"braking": 82,
			"cornering": 82,
		},
		"driving_overrides": {
			"max_speed": 108.0,
			"acceleration": 38.0,
			"brake_force": 76.0,
			"normal_lateral_grip": 63.0,
			"high_speed_turn_rate": 1.04,
			"rear_drive_power_oversteer": 3.0,
		},
	},
	{
		"id": &"ember_gt",
		"display_name": "Ember GT",
		"short_name": "Ember GT",
		"vehicle_class": "Power Coupe",
		"description": "High-power placeholder with weaker braking for a more varied stat silhouette.",
		"scene_path": DEFAULT_PLAYER_SCENE_PATH,
		"preview_scene_path": DEFAULT_CAR_MODEL_PATH,
		"model_path": DEFAULT_CAR_MODEL_PATH,
		"default_skin_id": &"pulse_red",
		"skin_ids": [&"pulse_red", &"volt_lime", &"electric_blue", &"solar_yellow"],
		"stats": {
			"speed": 86,
			"launch": 84,
			"braking": 62,
			"cornering": 74,
		},
		"driving_overrides": {
			"max_speed": 100.0,
			"acceleration": 48.0,
			"brake_force": 58.0,
			"normal_lateral_grip": 57.0,
			"high_speed_turn_rate": 0.94,
			"rear_drive_power_oversteer": 5.6,
		},
	},
]

const TRACK_OPTIONS: Array[Dictionary] = [
	{
		"id": DEFAULT_TRACK_ID,
		"display_name": "Storm Coast",
		"short_name": "Storm Coast",
		"description": "Premium coastal mountain route with wet-road lighting, ocean haze, elevation, and fast readable corners.",
		"scene_path": DEFAULT_TRACK_SCENE_PATH,
		"music_key": &"storm_coast_premium_arcade_drive",
		"environment": &"coastal_mountain",
		"lap_count": 1,
		"target_length_m": 2200.0,
		"preview_texture_path": "res://assets/ui/menu_showroom_background.png",
	},
	{
		"id": &"showcase_circuit",
		"display_name": "Showcase Circuit",
		"short_name": "Showcase",
		"description": "Closed-loop proving ground for handling, NPC tuning, and menu-to-race flow.",
		"scene_path": "res://scenes/race/showcase_circuit_race.tscn",
		"music_key": &"showcase_race_loop",
		"environment": &"test_circuit",
		"lap_count": 3,
		"target_length_m": 1800.0,
		"preview_texture_path": "res://assets/ui/menu_showroom_background.png",
	},
	{
		"id": &"glass_city",
		"display_name": "Glass City Run",
		"short_name": "Glass City",
		"description": "Placeholder urban night route card for testing long track descriptions and horizontal scrolling.",
		"scene_path": DEFAULT_TRACK_SCENE_PATH,
		"music_key": &"storm_coast_premium_arcade_drive",
		"environment": &"city_night",
		"lap_count": 2,
		"target_length_m": 2400.0,
		"preview_texture_path": "res://assets/ui/menu_showroom_background.png",
	},
	{
		"id": &"solar_pass",
		"display_name": "Solar Pass",
		"short_name": "Solar Pass",
		"description": "Warm desert pass placeholder with fast sweepers and broad open scenery.",
		"scene_path": DEFAULT_TRACK_SCENE_PATH,
		"music_key": &"storm_coast_premium_arcade_drive",
		"environment": &"desert_pass",
		"lap_count": 3,
		"target_length_m": 2100.0,
		"preview_texture_path": "res://assets/ui/menu_showroom_background.png",
	},
	{
		"id": &"neon_harbor",
		"display_name": "Neon Harbor",
		"short_name": "Neon Harbor",
		"description": "Wet dockside placeholder card for testing compact names and blue-heavy previews.",
		"scene_path": "res://scenes/race/showcase_circuit_race.tscn",
		"music_key": &"showcase_race_loop",
		"environment": &"industrial_harbor",
		"lap_count": 4,
		"target_length_m": 1650.0,
		"preview_texture_path": "res://assets/ui/menu_showroom_background.png",
	},
	{
		"id": &"alpine_link",
		"display_name": "Alpine Link",
		"short_name": "Alpine Link",
		"description": "Mountain connector placeholder with elevation changes and tight visual rhythm.",
		"scene_path": DEFAULT_TRACK_SCENE_PATH,
		"music_key": &"storm_coast_premium_arcade_drive",
		"environment": &"alpine_road",
		"lap_count": 2,
		"target_length_m": 2750.0,
		"preview_texture_path": "res://assets/ui/menu_showroom_background.png",
	},
	{
		"id": &"metro_loop",
		"display_name": "Metro Loop",
		"short_name": "Metro Loop",
		"description": "Short technical city-loop placeholder for testing card scrolling with many options.",
		"scene_path": "res://scenes/race/showcase_circuit_race.tscn",
		"music_key": &"showcase_race_loop",
		"environment": &"metro_loop",
		"lap_count": 5,
		"target_length_m": 1300.0,
		"preview_texture_path": "res://assets/ui/menu_showroom_background.png",
	},
	{
		"id": &"aurora_ring",
		"display_name": "Aurora Ring",
		"short_name": "Aurora Ring",
		"description": "High-contrast twilight ring placeholder for testing the final offscreen cards.",
		"scene_path": DEFAULT_TRACK_SCENE_PATH,
		"music_key": &"storm_coast_premium_arcade_drive",
		"environment": &"twilight_ring",
		"lap_count": 3,
		"target_length_m": 1950.0,
		"preview_texture_path": "res://assets/ui/menu_showroom_background.png",
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
@export_range(0.0, 1.0, 0.01) var master_volume: float = 1.0
@export_range(0.0, 1.0, 0.01) var music_volume: float = 0.82
@export_range(0.0, 1.0, 0.01) var sfx_volume: float = 0.86
@export_range(0.65, 1.35, 0.01) var brightness: float = 1.0

var _pending_loading_target: String = DEFAULT_TRACK_SCENE_PATH
var _preloaded_resources: Dictionary = {}


func _ready() -> void:
	_ensure_audio_buses()
	_load_settings()
	_normalize_state()
	apply_audio_settings()


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
	selected_skin_id = _skin_id_for_color(normalized, selected_skin_id)
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


func get_car_options() -> Array[Dictionary]:
	return _options_copy(CAR_OPTIONS)


func get_skin_presets() -> Array[Dictionary]:
	return _options_copy(SKIN_PRESETS)


func get_track_options() -> Array[Dictionary]:
	return _options_copy(TRACK_OPTIONS)


func get_difficulty_options() -> Array[Dictionary]:
	return _options_copy(DIFFICULTY_OPTIONS)


func get_car_option(car_id: Variant) -> Dictionary:
	return _option_by_id(CAR_OPTIONS, _variant_to_string_name(car_id, selected_car_id), DEFAULT_CAR_ID)


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
		"track_id": selected_track_id,
		"track_display_name": str(track_option.get("display_name", "")),
		"track_scene_path": get_track_scene_path(),
		"track_music_key": track_option.get("music_key", &""),
		"difficulty": selected_difficulty,
	}


func get_settings_snapshot() -> Dictionary:
	return {
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"brightness": brightness,
		"brightness_percent": get_brightness_percent(),
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
	var track_option: Dictionary = get_selected_track_option()
	var paths: Array[String] = [
		get_track_scene_path(),
		get_car_scene_path(),
		get_car_model_path(),
		"res://assets/audio/music/race_loop_arcade_drift.mp3",
		"res://assets/audio/sfx/countdown_start_stinger.mp3",
		"res://assets/audio/sfx/race_finish_stinger.mp3",
		"res://assets/audio/sfx/engine_hybrid_idle_loop.mp3",
		"res://assets/audio/sfx/engine_hybrid_accel_loop.mp3",
		"res://assets/audio/sfx/engine_hybrid_high_rpm_loop.mp3",
	]
	var preview_texture_path: String = str(track_option.get("preview_texture_path", ""))
	if not preview_texture_path.is_empty():
		paths.append(preview_texture_path)
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
	selected_track_id = _normalize_track_id(selected_track_id)
	var selected_track_option: Dictionary = get_selected_track_option()
	if selected_track_scene_path.is_empty() or not _has_option_id(TRACK_OPTIONS, selected_track_id):
		selected_track_scene_path = str(selected_track_option.get("scene_path", DEFAULT_TRACK_SCENE_PATH))
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


func _color_for_skin(skin_id: StringName) -> String:
	var skin: Dictionary = get_skin_preset(skin_id)
	return _normalize_color(str(skin.get("color_variant", "blue")))


func _skin_id_for_color(color_variant: String, fallback_id: StringName) -> StringName:
	var normalized: String = _normalize_color(color_variant)
	for option: Dictionary in SKIN_PRESETS:
		if str(option.get("color_variant", "")).to_lower() == normalized:
			return StringName(option.get("id", fallback_id))
	return fallback_id


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
	selected_difficulty = str(config.get_value("selection", "difficulty", selected_difficulty))
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
