class_name VFXStyleProfile
extends Resource

@export var vfx_style_id: StringName = &""
@export var display_name: String = ""
@export var weather_preset_id: StringName = &""
@export_range(0.0, 1.0, 0.001) var rain_intensity: float = 0.35
@export_range(0.0, 1.0, 0.001) var mist_density: float = 0.45
@export var tire_spray_color: Color = Color(0.78, 0.84, 0.88, 0.72)
@export_range(0.0, 4.0, 0.01) var tire_spray_scale: float = 1.0
@export_range(0.0, 1.0, 0.001) var headlight_readability: float = 0.85
@export var scrape_decal_material: Resource = null
@export var scrape_spark_color: Color = Color(1.0, 0.76, 0.42, 1.0)
@export var decal_pool_budget: Dictionary = {}
@export_range(0.1, 120.0, 0.1) var skid_mark_lifetime_seconds: float = 40.0
@export var effect_tags: PackedStringArray = PackedStringArray()
@export_multiline var notes: String = ""


func get_profile_id() -> StringName:
	return vfx_style_id


func uses_weather_vfx() -> bool:
	return rain_intensity > 0.0 or mist_density > 0.0
