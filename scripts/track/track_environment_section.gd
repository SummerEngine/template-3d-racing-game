class_name TrackEnvironmentSection
extends Resource

@export var environment: Resource = null
@export_range(0.0, 1.0, 0.001) var start_distance_ratio: float = 0.0
@export_range(0.0, 1.0, 0.001) var end_distance_ratio: float = 1.0
@export_multiline var notes: String = ""


func contains_ratio(ratio: float) -> bool:
	var wrapped_ratio: float = _wrap01(ratio)
	var start_ratio: float = _wrap01(start_distance_ratio)
	var end_ratio: float = _wrap01(end_distance_ratio)

	if is_equal_approx(start_ratio, end_ratio):
		return true
	if start_ratio < end_ratio:
		return wrapped_ratio >= start_ratio and wrapped_ratio < end_ratio
	return wrapped_ratio >= start_ratio or wrapped_ratio < end_ratio


func length_ratio() -> float:
	var start_ratio: float = _wrap01(start_distance_ratio)
	var end_ratio: float = _wrap01(end_distance_ratio)
	if is_equal_approx(start_ratio, end_ratio):
		return 1.0
	if end_ratio > start_ratio:
		return end_ratio - start_ratio
	return 1.0 - start_ratio + end_ratio


func length_m(track_length_m: float) -> float:
	return length_ratio() * track_length_m


func environment_id() -> StringName:
	if environment == null:
		return &""
	var value = environment.get("environment_id")
	if value is StringName:
		return value
	return StringName(String(value))


func _wrap01(value: float) -> float:
	return fposmod(value, 1.0)
