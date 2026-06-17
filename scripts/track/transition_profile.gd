class_name TransitionProfile
extends Resource

@export var from_environment: Resource = null
@export var to_environment: Resource = null
@export_range(0.0, 1.0, 0.001) var start_distance_ratio: float = 0.0
@export_range(0.0, 1.0, 0.001) var end_distance_ratio: float = 1.0
@export var blend_curve: Curve = null
@export var prop_crossfade_rules: Dictionary = {}
@export var audio_crossfade_rules: Dictionary = {}
@export var terrain_crossfade_rules: Dictionary = {}
@export_multiline var notes: String = ""


func contains_ratio(ratio: float) -> bool:
	var progress: float = normalized_progress_at_ratio(ratio)
	return progress >= 0.0 and progress <= 1.0


func normalized_progress_at_ratio(ratio: float) -> float:
	var wrapped_ratio: float = _wrap01(ratio)
	var start_ratio: float = _wrap01(start_distance_ratio)
	var end_ratio: float = _wrap01(end_distance_ratio)

	if is_equal_approx(start_ratio, end_ratio):
		return 0.0

	if start_ratio < end_ratio:
		if wrapped_ratio < start_ratio or wrapped_ratio > end_ratio:
			return -1.0
		return (wrapped_ratio - start_ratio) / maxf(end_ratio - start_ratio, 0.0001)

	if wrapped_ratio >= start_ratio:
		return (wrapped_ratio - start_ratio) / maxf(1.0 - start_ratio + end_ratio, 0.0001)
	if wrapped_ratio <= end_ratio:
		return (1.0 - start_ratio + wrapped_ratio) / maxf(1.0 - start_ratio + end_ratio, 0.0001)

	return -1.0


func to_environment_weight_at_ratio(ratio: float) -> float:
	var progress: float = normalized_progress_at_ratio(ratio)
	if progress < 0.0:
		return 0.0
	if blend_curve != null:
		return clampf(blend_curve.sample(clampf(progress, 0.0, 1.0)), 0.0, 1.0)
	return _smoothstep(progress)


func environment_weights_at_ratio(ratio: float) -> Dictionary:
	var to_weight: float = to_environment_weight_at_ratio(ratio)
	var from_weight: float = 1.0 - to_weight
	var result: Dictionary = {}

	if from_environment != null:
		result[_environment_id(from_environment)] = from_weight
	if to_environment != null:
		result[_environment_id(to_environment)] = to_weight

	return result


func transition_length_m(track_length_m: float) -> float:
	var start_ratio: float = _wrap01(start_distance_ratio)
	var end_ratio: float = _wrap01(end_distance_ratio)
	var ratio_length: float = end_ratio - start_ratio if end_ratio >= start_ratio else 1.0 - start_ratio + end_ratio
	return ratio_length * track_length_m


func _wrap01(value: float) -> float:
	return fposmod(value, 1.0)


func _smoothstep(value: float) -> float:
	var t: float = clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _environment_id(environment: Resource) -> StringName:
	var value = environment.get("environment_id")
	if value is StringName:
		return value
	return StringName(String(value))
