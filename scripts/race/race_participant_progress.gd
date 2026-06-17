class_name RaceParticipantProgress
extends RefCounted

var total_laps: int = 3
var track_length_m: float = 1800.0
var checkpoint_count: int = 0
var completed_laps: int = 0
var current_lap: int = 1
var distance_on_lap_m: float = 0.0
var normalized_lap_progress: float = 0.0
var checkpoint_index: int = 0
var total_progress_m: float = 0.0
var has_distance_sample: bool = false
var last_distance_on_lap_m: float = 0.0
var is_finished: bool = false
var finish_time_msec: int = -1


func reset(new_total_laps: int, new_track_length_m: float, new_checkpoint_count: int = 0) -> void:
	total_laps = max(1, new_total_laps)
	track_length_m = max(1.0, new_track_length_m)
	checkpoint_count = max(0, new_checkpoint_count)
	completed_laps = 0
	current_lap = 1
	distance_on_lap_m = 0.0
	normalized_lap_progress = 0.0
	checkpoint_index = 0
	total_progress_m = 0.0
	has_distance_sample = false
	last_distance_on_lap_m = 0.0
	is_finished = false
	finish_time_msec = -1


func get_display_lap() -> int:
	if is_finished:
		return total_laps
	return int(clamp(completed_laps + 1, 1, total_laps))


func get_sort_progress_m() -> float:
	if is_finished:
		return float(total_laps) * track_length_m
	return total_progress_m


func mark_finished(race_time_msec: int) -> void:
	is_finished = true
	completed_laps = total_laps
	current_lap = total_laps
	distance_on_lap_m = 0.0
	normalized_lap_progress = 1.0
	total_progress_m = float(total_laps) * track_length_m
	if finish_time_msec < 0:
		finish_time_msec = max(0, race_time_msec)


func to_dictionary() -> Dictionary:
	return {
		"total_laps": total_laps,
		"completed_laps": completed_laps,
		"current_lap": get_display_lap(),
		"track_length_m": track_length_m,
		"distance_on_lap_m": distance_on_lap_m,
		"normalized_lap_progress": normalized_lap_progress,
		"checkpoint_index": checkpoint_index,
		"checkpoint_count": checkpoint_count,
		"total_progress_m": total_progress_m,
		"is_finished": is_finished,
		"finish_time_msec": finish_time_msec,
	}
