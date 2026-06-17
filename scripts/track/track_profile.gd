class_name TrackProfile
extends Resource

const TransitionProfileScript := preload("res://scripts/track/transition_profile.gd")

@export var track_id: StringName = &""
@export var display_name: String = ""
@export var target_length_m: float = 1800.0
@export var road_width_m: float = 14.0
@export var road_material_key: StringName = &"toy_asphalt"
@export var road_color: Color = Color(0.015, 0.016, 0.018, 1.0)
@export var guardrail_settings: Resource = null
@export var environment_sections: Array[Resource] = []
@export var transitions: Array[Resource] = []
@export var auto_generate_transitions: bool = true
@export_range(0.0, 0.45, 0.001) var default_transition_fraction: float = 0.08
@export var music_key: StringName = &""
@export var music_path: String = ""
@export var lap_count: int = 3
@export var spawn_lane_count: int = 2
@export var spawn_lane_spacing_m: float = 3.6
@export var spawn_row_spacing_m: float = 7.5
@export var spawn_start_distance_m: float = 18.0
@export var spawn_vertical_offset_m: float = 0.14
@export var difficulty_defaults: Dictionary = {}
@export var closed_loop: bool = true
@export_multiline var notes: String = ""


func get_track_length_m() -> float:
	return target_length_m


func get_road_width_m() -> float:
	return road_width_m


func get_ordered_environment_sections() -> Array[Resource]:
	var ordered: Array[Resource] = []
	for section: Resource in environment_sections:
		if section == null or section.get("environment") == null:
			continue

		var inserted := false
		for i: int in range(ordered.size()):
			var existing: Resource = ordered[i]
			if float(section.get("start_distance_ratio")) < float(existing.get("start_distance_ratio")):
				ordered.insert(i, section)
				inserted = true
				break

		if not inserted:
			ordered.append(section)

	return ordered


func get_effective_transitions() -> Array[Resource]:
	if not transitions.is_empty():
		return transitions
	if not auto_generate_transitions:
		return []
	return create_default_transitions()


func create_default_transitions() -> Array[Resource]:
	var generated: Array[Resource] = []
	var sections: Array[Resource] = get_ordered_environment_sections()
	if sections.size() < 2:
		return generated

	var pair_count: int = sections.size() if closed_loop else sections.size() - 1
	for i: int in range(pair_count):
		var from_section: Resource = sections[i]
		var to_section: Resource = sections[(i + 1) % sections.size()]
		if _section_environment_id(from_section) == _section_environment_id(to_section):
			continue

		var full_fraction: float = _default_transition_fraction_for_pair(from_section, to_section)
		if full_fraction <= 0.0:
			continue

		var half_fraction: float = full_fraction * 0.5
		var transition: Resource = TransitionProfileScript.new()
		transition.set("from_environment", from_section.get("environment"))
		transition.set("to_environment", to_section.get("environment"))
		transition.set("start_distance_ratio", _wrap01(float(from_section.get("end_distance_ratio")) - half_fraction))
		transition.set("end_distance_ratio", _wrap01(float(from_section.get("end_distance_ratio")) + half_fraction))
		transition.set("notes", "Auto-generated blend between adjacent environment sections.")
		generated.append(transition)

	return generated


func environment_weights_at_distance(distance_m: float) -> Dictionary:
	if target_length_m <= 0.0:
		return {}
	return environment_weights_at_ratio(distance_m / target_length_m)


func environment_weights_at_ratio(ratio: float) -> Dictionary:
	var wrapped_ratio: float = _wrap01(ratio)
	for transition: Resource in get_effective_transitions():
		if transition != null and bool(transition.call("contains_ratio", wrapped_ratio)):
			return transition.call("environment_weights_at_ratio", wrapped_ratio)

	for section: Resource in get_ordered_environment_sections():
		if section != null and bool(section.call("contains_ratio", wrapped_ratio)):
			var section_result: Dictionary = {}
			section_result[_section_environment_id(section)] = 1.0
			return section_result

	if not environment_sections.is_empty() and environment_sections[0] != null:
		var fallback_result: Dictionary = {}
		fallback_result[_section_environment_id(environment_sections[0])] = 1.0
		return fallback_result

	return {}


func get_lane_offset_m(lane_index: int) -> float:
	var lane_count: int = maxi(spawn_lane_count, 1)
	var centered_index: float = float(clampi(lane_index, 0, lane_count - 1)) - float(lane_count - 1) * 0.5
	return centered_index * spawn_lane_spacing_m


func get_spawn_distance_m(grid_index: int) -> float:
	var lane_count: int = maxi(spawn_lane_count, 1)
	var row_index: int = floori(float(maxi(grid_index, 0)) / float(lane_count))
	return spawn_start_distance_m - float(row_index) * spawn_row_spacing_m


func _default_transition_fraction_for_pair(
	from_section: Resource,
	to_section: Resource
) -> float:
	var requested_fraction: float = clampf(default_transition_fraction, 0.0, 0.45)
	var max_fraction: float = minf(_section_length_ratio(from_section), _section_length_ratio(to_section)) * 0.7
	return minf(requested_fraction, max_fraction)


func _wrap01(value: float) -> float:
	return fposmod(value, 1.0)


func _section_environment_id(section: Resource) -> StringName:
	if section == null:
		return &""
	return section.call("environment_id")


func _section_length_ratio(section: Resource) -> float:
	if section == null:
		return 0.0
	return float(section.call("length_ratio"))
