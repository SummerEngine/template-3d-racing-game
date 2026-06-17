class_name EnvironmentKitProfile
extends Resource

@export var kit_id: StringName = &""
@export var display_name: String = ""
@export var environment_type: StringName = &""
@export var style_tags: PackedStringArray = PackedStringArray()
@export var module_scenes: PackedStringArray = PackedStringArray()
@export var roadside_props: PackedStringArray = PackedStringArray()
@export var background_props: PackedStringArray = PackedStringArray()
@export var landmark_scenes: PackedStringArray = PackedStringArray()
@export var lighting_overrides: Dictionary = {}
@export var audio_ambience: StringName = &""
@export var weather_support_tags: PackedStringArray = PackedStringArray()
@export var performance_budget: Dictionary = {}
@export_multiline var notes: String = ""


func get_profile_id() -> StringName:
	return kit_id


func includes_module(scene_path: String) -> bool:
	return module_scenes.has(scene_path)


func get_budget_value(key: StringName, fallback: float = 0.0) -> float:
	if performance_budget.has(key):
		return float(performance_budget[key])
	var key_as_string := String(key)
	if performance_budget.has(key_as_string):
		return float(performance_budget[key_as_string])
	return fallback
