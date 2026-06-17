class_name LapTracker
extends RefCounted

var lap_wrap_threshold_ratio: float = 0.55
var allow_lap_rewind: bool = false


func update_progress(
	progress: RaceParticipantProgress,
	distance_m: float,
	race_time_msec: int,
	track_length_m: float,
	total_laps: int,
	checkpoint_count: int = 0,
	checkpoint_index: int = -1
) -> Dictionary:
	var result: Dictionary = {
		"progress_changed": false,
		"lap_changed": false,
		"checkpoint_changed": false,
		"finished": false,
		"previous_lap": progress.get_display_lap(),
		"previous_completed_laps": progress.completed_laps,
		"previous_checkpoint_index": progress.checkpoint_index,
	}
	if progress.is_finished:
		return result

	var safe_track_length_m: float = max(1.0, track_length_m)
	progress.total_laps = max(1, total_laps)
	progress.track_length_m = safe_track_length_m
	progress.checkpoint_count = max(0, checkpoint_count)

	var wrapped_distance_m: float = fposmod(distance_m, safe_track_length_m)
	if progress.has_distance_sample:
		var delta_m: float = wrapped_distance_m - progress.last_distance_on_lap_m
		if delta_m < -safe_track_length_m * lap_wrap_threshold_ratio:
			progress.completed_laps += 1
			result["lap_changed"] = true
		elif allow_lap_rewind and delta_m > safe_track_length_m * lap_wrap_threshold_ratio:
			progress.completed_laps = max(0, progress.completed_laps - 1)
			result["lap_changed"] = true

	progress.has_distance_sample = true
	progress.last_distance_on_lap_m = wrapped_distance_m
	progress.distance_on_lap_m = wrapped_distance_m
	progress.normalized_lap_progress = clamp(wrapped_distance_m / safe_track_length_m, 0.0, 1.0)

	if checkpoint_index >= 0:
		progress.checkpoint_index = clamp(checkpoint_index, 0, max(0, checkpoint_count - 1))
	elif checkpoint_count > 0:
		var checkpoint_length_m: float = safe_track_length_m / float(checkpoint_count)
		progress.checkpoint_index = clamp(int(floor(wrapped_distance_m / checkpoint_length_m)), 0, checkpoint_count - 1)
	else:
		progress.checkpoint_index = 0

	progress.current_lap = progress.get_display_lap()
	progress.total_progress_m = float(progress.completed_laps) * safe_track_length_m + wrapped_distance_m
	result["checkpoint_changed"] = progress.checkpoint_index != int(result["previous_checkpoint_index"])
	result["progress_changed"] = true

	if progress.completed_laps >= progress.total_laps:
		progress.mark_finished(race_time_msec)
		result["finished"] = true
		result["lap_changed"] = true

	return result
