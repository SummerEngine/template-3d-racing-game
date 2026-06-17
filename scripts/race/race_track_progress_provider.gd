class_name RaceTrackProgressProvider
extends RefCounted

## Duck-typed expectation for the track architecture agent.
##
## Required methods on the provider object:
## - closest_distance_for_position(position: Vector3) -> float
## - get_track_length_m() -> float
##
## Optional race-state helpers:
## - checkpoint_index_for_distance(distance: float) -> int
## - checkpoint_index_for_position(position: Vector3) -> int
##
## Race scripts should call through this adapter instead of reading track internals.


static func is_valid_provider(provider: Object) -> bool:
	return provider != null \
		and provider.has_method("closest_distance_for_position") \
		and provider.has_method("get_track_length_m")


static func get_track_length_m(provider: Object, fallback_length_m: float) -> float:
	if provider != null and provider.has_method("get_track_length_m"):
		var value: Variant = provider.call("get_track_length_m")
		if value is float or value is int:
			return max(1.0, float(value))
	return max(1.0, fallback_length_m)


static func closest_distance_for_position(provider: Object, position: Vector3, track_length_m: float) -> float:
	if provider != null and provider.has_method("closest_distance_for_position"):
		var value: Variant = provider.call("closest_distance_for_position", position)
		if value is float or value is int:
			return fposmod(float(value), max(1.0, track_length_m))
	return 0.0


static func checkpoint_index_for_distance(provider: Object, distance_m: float, checkpoint_count: int) -> int:
	if checkpoint_count <= 0:
		return 0
	if provider != null and provider.has_method("checkpoint_index_for_distance"):
		var value: Variant = provider.call("checkpoint_index_for_distance", distance_m)
		if value is int:
			return int(clamp(value, 0, checkpoint_count - 1))
	return -1


static func checkpoint_index_for_position(provider: Object, position: Vector3, distance_m: float, checkpoint_count: int) -> int:
	if checkpoint_count <= 0:
		return 0
	if provider != null and provider.has_method("checkpoint_index_for_position"):
		var value: Variant = provider.call("checkpoint_index_for_position", position)
		if value is int:
			return int(clamp(value, 0, checkpoint_count - 1))
	return checkpoint_index_for_distance(provider, distance_m, checkpoint_count)
