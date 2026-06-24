@tool
class_name TrackAuthoringSnapshot
extends Resource

@export var track_id: StringName = &""
@export var display_name: String = ""
@export var source_scene_path: String = ""
@export var created_at: String = ""
@export var tool_api_version: StringName = &""
@export var marker_counts: Dictionary = {}
@export var authoring_records: Dictionary = {}
@export var generator_settings: Dictionary = {}
@export_multiline var bake_summary: String = ""


func configure(
	track_profile: Resource,
	scene_path: String,
	records: Dictionary,
	counts: Dictionary,
	settings: Dictionary,
	summary: String
) -> void:
	if track_profile != null:
		track_id = _profile_string_name(track_profile, "track_id", track_id)
		display_name = String(track_profile.get("display_name"))
		tool_api_version = _profile_string_name(track_profile, "tool_api_version", tool_api_version)
	source_scene_path = scene_path
	created_at = Time.get_datetime_string_from_system(false, true)
	authoring_records = records.duplicate(true)
	marker_counts = counts.duplicate(true)
	generator_settings = settings.duplicate(true)
	bake_summary = summary


func get_road_point_count() -> int:
	return int(marker_counts.get("road_points", 0))


func _profile_string_name(track_profile: Resource, property_name: String, fallback: StringName) -> StringName:
	var value: Variant = track_profile.get(property_name)
	if value == null:
		return fallback
	if value is StringName:
		return value
	return StringName(String(value))
