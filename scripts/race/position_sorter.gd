class_name PositionSorter
extends RefCounted

const RaceResultScript = preload("res://scripts/race/race_result.gd")


static func sort_participants(participants: Array) -> Array:
	var sorted_participants: Array = participants.duplicate()
	sorted_participants.sort_custom(func(a: Variant, b: Variant) -> bool:
		return PositionSorter.compare_participants(a as RaceParticipant, b as RaceParticipant) < 0
	)
	return sorted_participants


static func compare_participants(a: RaceParticipant, b: RaceParticipant) -> int:
	if a == null and b == null:
		return 0
	if a == null:
		return 1
	if b == null:
		return -1

	if a.progress.is_finished and b.progress.is_finished:
		var a_time: int = a.progress.finish_time_msec
		var b_time: int = b.progress.finish_time_msec
		if a_time != b_time:
			return -1 if a_time < b_time else 1
	elif a.progress.is_finished != b.progress.is_finished:
		return -1 if a.progress.is_finished else 1

	var progress_delta: float = b.progress.get_sort_progress_m() - a.progress.get_sort_progress_m()
	if not is_equal_approx(progress_delta, 0.0):
		return -1 if progress_delta < 0.0 else 1

	if a.progress.checkpoint_index != b.progress.checkpoint_index:
		return -1 if a.progress.checkpoint_index > b.progress.checkpoint_index else 1

	if a.registration_index != b.registration_index:
		return -1 if a.registration_index < b.registration_index else 1

	return String(a.participant_id).naturalnocasecmp_to(String(b.participant_id))


static func build_position_map(participants: Array) -> Dictionary:
	var sorted_participants: Array = sort_participants(participants)
	var positions: Dictionary = {}
	for index in range(sorted_participants.size()):
		var participant: RaceParticipant = sorted_participants[index] as RaceParticipant
		if participant != null:
			positions[participant.participant_id] = index + 1
	return positions


static func build_ordered_ids(participants: Array) -> Array[StringName]:
	var sorted_participants: Array = sort_participants(participants)
	var ordered_ids: Array[StringName] = []
	for participant_variant in sorted_participants:
		var participant: RaceParticipant = participant_variant as RaceParticipant
		if participant != null:
			ordered_ids.append(participant.participant_id)
	return ordered_ids


static func build_results(participants: Array) -> Array[RaceResult]:
	var sorted_participants: Array = sort_participants(participants)
	var results: Array[RaceResult] = []
	for index in range(sorted_participants.size()):
		var participant: RaceParticipant = sorted_participants[index] as RaceParticipant
		if participant != null:
			results.append(RaceResultScript.new(participant, index + 1))
	return results
