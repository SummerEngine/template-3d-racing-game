class_name TrackQuery
extends RefCounted

# Public read API for race, NPC, spawn, camera, HUD, and VFX systems.
# Keep consumers on these methods instead of exposing centerline arrays directly.

var profile: Resource = null
var path: RefCounted = null


func _init(track_profile: Resource = null, track_path: RefCounted = null) -> void:
	profile = track_profile
	path = track_path


func configure(track_profile: Resource, track_path: RefCounted) -> void:
	profile = track_profile
	path = track_path


func sample_at_distance(distance: float) -> Dictionary:
	if path == null:
		return {}

	var sample: Dictionary = path.call("sample_at_distance", distance)
	sample["road_width_m"] = get_road_width_m()
	if profile != null:
		sample["environment_weights"] = environment_weights_at_distance(distance)
	return sample


func lane_transform(distance: float, lane_index: int) -> Transform3D:
	if path == null:
		return Transform3D.IDENTITY

	var lane_offset_m: float = float(profile.call("get_lane_offset_m", lane_index)) if profile != null else 0.0
	return path.call("transform_at_distance", distance, lane_offset_m)


func closest_distance_for_position(position: Vector3) -> float:
	if path == null:
		return 0.0
	return path.call("closest_distance_for_position", position)


func environment_weights_at_distance(distance: float) -> Dictionary:
	if profile == null:
		return {}
	return profile.call("environment_weights_at_distance", distance)


func get_track_length_m() -> float:
	if path != null and float(path.call("get_length_m")) > 0.0:
		return path.call("get_length_m")
	if profile != null:
		return profile.call("get_track_length_m")
	return 0.0


func get_road_width_m() -> float:
	if profile == null:
		return 0.0
	return profile.call("get_road_width_m")


func get_spawn_transform(grid_index: int) -> Transform3D:
	if path == null:
		return Transform3D.IDENTITY

	var lane_count: int = maxi(int(profile.get("spawn_lane_count")), 1) if profile != null else 1
	var lane_index: int = maxi(grid_index, 0) % lane_count
	var spawn_distance_m: float = float(profile.call("get_spawn_distance_m", grid_index)) if profile != null else 0.0
	var vertical_offset_m: float = float(profile.get("spawn_vertical_offset_m")) if profile != null else 0.0
	var lane_offset_m: float = float(profile.call("get_lane_offset_m", lane_index)) if profile != null else 0.0
	return path.call("transform_at_distance", spawn_distance_m, lane_offset_m, vertical_offset_m)


func road_edge_position(distance: float, side: float, edge_offset_m: float = 0.0) -> Vector3:
	if path == null:
		return Vector3.ZERO
	return path.call("road_edge_position", distance, get_road_width_m(), side, edge_offset_m)
