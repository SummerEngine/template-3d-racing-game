class_name EnvironmentProfile
extends Resource

@export var display_name: String = ""
@export var environment_id: StringName = &""
@export var environment_type: StringName = &""
@export var terrain_palette: Dictionary = {}
@export var prop_rules: Array[Resource] = []
@export var ambient_audio_key: StringName = &""
@export var ambient_audio_path: String = ""
@export var coverage_targets: Dictionary = {}
@export var roadside_offset_rules: Dictionary = {}
@export var transition_prop_rules: Dictionary = {}
@export_multiline var notes: String = ""


func get_prop_rule(prop_id: StringName) -> Resource:
	for rule: Resource in prop_rules:
		if rule != null and _as_string_name(rule.get("prop_id")) == prop_id:
			return rule
	return null


func get_road_edge_offset_m(prop_id: StringName, fallback_m: float = 24.0) -> float:
	var rule: Resource = get_prop_rule(prop_id)
	if rule != null:
		return float(rule.get("road_edge_offset_m"))
	if roadside_offset_rules.has(prop_id):
		return float(roadside_offset_rules[prop_id])
	if roadside_offset_rules.has(String(prop_id)):
		return float(roadside_offset_rules[String(prop_id)])
	return fallback_m


func get_coverage_range(prop_id: StringName, fallback: Vector2 = Vector2(0.0, 1.0)) -> Vector2:
	var rule: Resource = get_prop_rule(prop_id)
	if rule != null:
		var coverage = rule.call("coverage_range_clamped")
		if coverage is Vector2:
			return coverage
	if coverage_targets.has(prop_id):
		return coverage_targets[prop_id]
	if coverage_targets.has(String(prop_id)):
		return coverage_targets[String(prop_id)]
	return fallback


func _as_string_name(value) -> StringName:
	if value is StringName:
		return value
	return StringName(String(value))
