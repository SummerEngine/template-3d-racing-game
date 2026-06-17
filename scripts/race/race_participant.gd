class_name RaceParticipant
extends RefCounted

const RaceParticipantProgressScript = preload("res://scripts/race/race_participant_progress.gd")

var participant_id: StringName = &""
var display_name: String = ""
var participant_node: Node = null
var participant_node_path: NodePath
var is_player: bool = false
var registration_index: int = 0
var metadata: Dictionary = {}
var progress: RaceParticipantProgress = RaceParticipantProgressScript.new()


func _init(
	new_participant_id: StringName = &"",
	new_display_name: String = "",
	new_participant_node: Node = null,
	new_is_player: bool = false,
	new_registration_index: int = 0,
	new_metadata: Dictionary = {}
) -> void:
	participant_id = new_participant_id
	display_name = new_display_name
	participant_node = new_participant_node
	is_player = new_is_player
	registration_index = new_registration_index
	metadata = new_metadata.duplicate(true)
	if participant_node != null:
		participant_node_path = participant_node.get_path()
	if display_name.is_empty():
		display_name = String(participant_id)


func reset_progress(lap_count: int, track_length_m: float, checkpoint_count: int = 0) -> void:
	progress.reset(lap_count, track_length_m, checkpoint_count)


func set_participant_node(new_participant_node: Node) -> void:
	participant_node = new_participant_node
	if participant_node != null:
		participant_node_path = participant_node.get_path()
	else:
		participant_node_path = NodePath()


func get_world_position_or_null() -> Variant:
	var node_3d: Node3D = participant_node as Node3D
	if node_3d == null:
		return null
	return node_3d.global_position


func get_personality_id() -> StringName:
	return StringName(str(metadata.get("personality_id", "")))


func get_racing_line_profile_id() -> StringName:
	return StringName(str(metadata.get("racing_line_profile_id", get_personality_id())))


func to_dictionary() -> Dictionary:
	return {
		"participant_id": participant_id,
		"display_name": display_name,
		"participant_node_path": participant_node_path,
		"is_player": is_player,
		"registration_index": registration_index,
		"metadata": metadata.duplicate(true),
		"progress": progress.to_dictionary(),
	}
