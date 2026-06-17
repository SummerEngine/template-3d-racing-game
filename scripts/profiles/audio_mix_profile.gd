class_name AudioMixProfile
extends Resource

@export var audio_mix_id: StringName = &""
@export var display_name: String = ""
@export var music_profile_key: StringName = &""
@export var ambience_key: StringName = &""
@export var bus_names: Dictionary = {}
@export var volume_db: Dictionary = {}
@export var ducking_settings: Dictionary = {}
@export var cue_keys: Dictionary = {}
@export_range(-80.0, 12.0, 0.1) var master_gain_db: float = 0.0
@export_range(0.0, 1.0, 0.001) var wet_environment_reverb_send: float = 0.22
@export_multiline var notes: String = ""


func get_profile_id() -> StringName:
	return audio_mix_id


func get_bus(bus_key: StringName, fallback: StringName = &"Master") -> StringName:
	if bus_names.has(bus_key):
		return _as_string_name(bus_names[bus_key])
	var key_as_string := String(bus_key)
	if bus_names.has(key_as_string):
		return _as_string_name(bus_names[key_as_string])
	return fallback


func get_volume_db(volume_key: StringName, fallback_db: float = 0.0) -> float:
	if volume_db.has(volume_key):
		return float(volume_db[volume_key])
	var key_as_string := String(volume_key)
	if volume_db.has(key_as_string):
		return float(volume_db[key_as_string])
	return fallback_db


func _as_string_name(value) -> StringName:
	if value is StringName:
		return value
	return StringName(String(value))
