class_name RaceResult
extends RefCounted

var participant_id: StringName = &""
var display_name: String = ""
var placement: int = 0
var total_time_msec: int = -1
var completed_laps: int = 0
var is_player: bool = false
var metadata: Dictionary = {}


func _init(participant: RaceParticipant = null, new_placement: int = 0) -> void:
	if participant == null:
		return
	participant_id = participant.participant_id
	display_name = participant.display_name
	placement = new_placement
	total_time_msec = participant.progress.finish_time_msec
	completed_laps = participant.progress.completed_laps
	is_player = participant.is_player
	metadata = participant.metadata.duplicate(true)


func get_total_time_seconds() -> float:
	if total_time_msec < 0:
		return -1.0
	return float(total_time_msec) / 1000.0


func get_formatted_total_time() -> String:
	return format_time_msec(total_time_msec)


static func format_time_msec(time_msec: int) -> String:
	if time_msec < 0:
		return "--:--.---"
	var total_seconds: int = int(float(time_msec) / 1000.0)
	var minutes: int = int(float(total_seconds) / 60.0)
	var seconds: int = total_seconds % 60
	var millis: int = time_msec % 1000
	return "%02d:%02d.%03d" % [minutes, seconds, millis]


func to_dictionary() -> Dictionary:
	return {
		"participant_id": participant_id,
		"display_name": display_name,
		"placement": placement,
		"total_time_msec": total_time_msec,
		"formatted_total_time": get_formatted_total_time(),
		"completed_laps": completed_laps,
		"is_player": is_player,
		"metadata": metadata.duplicate(true),
	}
