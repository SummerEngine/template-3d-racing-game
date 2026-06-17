class_name LightingProfile
extends Resource

@export var lighting_id: StringName = &""
@export var display_name: String = ""
@export_enum("neutral_preview", "overcast_late_afternoon", "storm_dusk", "night_wet") var time_of_day: String = "overcast_late_afternoon"
@export var weather_preset_id: StringName = &""
@export var sky_color: Color = Color(0.28, 0.32, 0.36, 1.0)
@export var horizon_color: Color = Color(0.42, 0.45, 0.48, 1.0)
@export var ambient_light_color: Color = Color(0.46, 0.50, 0.54, 1.0)
@export_range(0.0, 4.0, 0.01) var ambient_energy: float = 0.8
@export var sun_color: Color = Color(0.78, 0.82, 0.86, 1.0)
@export_range(0.0, 8.0, 0.01) var sun_energy: float = 1.1
@export var sun_rotation_degrees: Vector3 = Vector3(-42.0, -28.0, 0.0)
@export_range(0.0, 16.0, 0.01) var shadow_softness: float = 5.0
@export var fog_enabled: bool = true
@export var fog_color: Color = Color(0.40, 0.45, 0.49, 1.0)
@export_range(0.0, 1.0, 0.001) var fog_density: float = 0.08
@export_range(0.0, 1.0, 0.001) var rain_intensity: float = 0.35
@export_range(0.0, 1.0, 0.001) var wetness_multiplier: float = 0.9
@export var reflection_probe_budget: Dictionary = {}
@export_multiline var notes: String = ""


func get_profile_id() -> StringName:
	return lighting_id


func uses_precipitation() -> bool:
	return rain_intensity > 0.0


func uses_fog() -> bool:
	return fog_enabled and fog_density > 0.0
