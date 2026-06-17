class_name RaceManager
extends Node

const LapTrackerScript = preload("res://scripts/race/lap_tracker.gd")
const PositionSorterScript = preload("res://scripts/race/position_sorter.gd")
const RaceConfigScript = preload("res://scripts/race/race_config.gd")
const RaceParticipantScript = preload("res://scripts/race/race_participant.gd")
const RaceTrackProgressProviderScript = preload("res://scripts/race/race_track_progress_provider.gd")

signal race_phase_changed(previous_phase: int, new_phase: int)
signal countdown_changed(time_remaining_seconds: float, whole_seconds: int)
signal race_started
signal participant_registered(participant: RaceParticipant)
signal participant_unregistered(participant_id: StringName)
signal participant_progress_changed(participant: RaceParticipant, progress: Dictionary)
signal lap_changed(participant: RaceParticipant, current_lap: int, total_laps: int)
signal checkpoint_changed(participant: RaceParticipant, checkpoint_index: int)
signal position_changed(ordered_participant_ids: Array[StringName], position_map: Dictionary)
signal participant_finished(participant: RaceParticipant, placement: int)
signal race_finished(results: Array)

enum RacePhase {
	SETUP,
	COUNTDOWN,
	RACING,
	FINISHED,
}

@export var race_config: RaceConfig
@export var track_query_path: NodePath
@export var poll_registered_nodes: bool = true
@export var auto_start_countdown: bool = false

var _phase: int = RacePhase.SETUP
var _track_query: Object = null
var _lap_tracker: RefCounted = LapTrackerScript.new()
var _participants: Dictionary = {}
var _registration_order: Array[StringName] = []
var _current_position_order: Array[StringName] = []
var _race_results: Array[RaceResult] = []
var _countdown_remaining_seconds: float = 0.0
var _race_time_msec: int = 0


func _ready() -> void:
	_ensure_config()
	_resolve_track_query()
	reset_race()
	if auto_start_countdown:
		start_countdown()


func _process(delta: float) -> void:
	if _phase == RacePhase.COUNTDOWN:
		_tick_countdown(delta)
	elif _phase == RacePhase.RACING:
		_race_time_msec += int(round(delta * 1000.0))
		if poll_registered_nodes:
			update_registered_node_progress()


func configure(new_config: RaceConfig) -> void:
	race_config = new_config
	_ensure_config()
	reset_race()


func set_track_progress_provider(provider: Object) -> void:
	_track_query = provider
	_reset_all_progress()


func register_participant(
	participant_id: StringName,
	display_name: String,
	participant_node: Node = null,
	is_player: bool = false,
	metadata: Dictionary = {}
) -> RaceParticipant:
	_ensure_config()
	var safe_participant_id: StringName = participant_id
	if safe_participant_id == &"":
		safe_participant_id = _make_participant_id(participant_node)

	var is_new_participant: bool = not _participants.has(safe_participant_id)
	var registration_index: int = _registration_order.size()
	if not is_new_participant:
		var existing_participant: RaceParticipant = _participants[safe_participant_id]
		registration_index = existing_participant.registration_index

	var participant: RaceParticipant = RaceParticipantScript.new(
		safe_participant_id,
		display_name,
		participant_node,
		is_player,
		registration_index,
		metadata
	)
	participant.reset_progress(race_config.get_lap_count(), _get_track_length_m(), race_config.get_checkpoint_count())
	_participants[safe_participant_id] = participant
	if is_new_participant:
		_registration_order.append(safe_participant_id)

	participant_registered.emit(participant)
	_resort_positions()
	return participant


func register_participant_node(
	participant_node: Node,
	display_name: String = "",
	participant_id: StringName = &"",
	is_player: bool = false,
	metadata: Dictionary = {}
) -> RaceParticipant:
	var resolved_name: String = display_name
	if resolved_name.is_empty() and participant_node != null:
		resolved_name = String(participant_node.name)
	return register_participant(participant_id, resolved_name, participant_node, is_player, metadata)


func register_npc_slot(slot_index: int, participant_node: Node = null, display_name: String = "") -> RaceParticipant:
	_ensure_config()
	var metadata: Dictionary = race_config.get_npc_metadata(slot_index)
	var participant_id: StringName = StringName("npc_%d" % [slot_index + 1])
	var resolved_name: String = display_name
	if resolved_name.is_empty():
		resolved_name = "NPC %d" % [slot_index + 1]
	return register_participant(participant_id, resolved_name, participant_node, false, metadata)


func unregister_participant(participant_id: StringName) -> void:
	if not _participants.has(participant_id):
		return
	_participants.erase(participant_id)
	_registration_order.erase(participant_id)
	participant_unregistered.emit(participant_id)
	_resort_positions()


func reset_race() -> void:
	_ensure_config()
	_countdown_remaining_seconds = race_config.get_countdown_seconds()
	_race_time_msec = 0
	_race_results.clear()
	_reset_all_progress()
	_set_phase(RacePhase.SETUP)
	_resort_positions()


func start_countdown() -> void:
	_ensure_config()
	_countdown_remaining_seconds = race_config.get_countdown_seconds()
	if _countdown_remaining_seconds <= 0.0:
		start_race_immediately()
		return
	_set_phase(RacePhase.COUNTDOWN)
	countdown_changed.emit(_countdown_remaining_seconds, int(ceil(_countdown_remaining_seconds)))


func start_race_immediately() -> void:
	_race_time_msec = 0
	_countdown_remaining_seconds = 0.0
	_set_phase(RacePhase.RACING)
	countdown_changed.emit(0.0, 0)
	race_started.emit()


func finish_race() -> void:
	if _phase == RacePhase.FINISHED:
		return
	_race_results = PositionSorterScript.build_results(_get_participant_list())
	_set_phase(RacePhase.FINISHED)
	race_finished.emit(get_race_results())


func update_registered_node_progress() -> void:
	_resolve_track_query()
	if not RaceTrackProgressProviderScript.is_valid_provider(_track_query):
		return
	for participant_id in _registration_order:
		var participant: RaceParticipant = _participants.get(participant_id, null)
		if participant == null:
			continue
		var world_position: Variant = participant.get_world_position_or_null()
		if world_position is Vector3:
			update_participant_position(participant_id, world_position)


func update_participant_position(participant_id: StringName, world_position: Vector3) -> void:
	_resolve_track_query()
	if not RaceTrackProgressProviderScript.is_valid_provider(_track_query):
		return
	var track_length_m: float = _get_track_length_m()
	var distance_m: float = RaceTrackProgressProviderScript.closest_distance_for_position(_track_query, world_position, track_length_m)
	var checkpoint_index: int = RaceTrackProgressProviderScript.checkpoint_index_for_position(
		_track_query,
		world_position,
		distance_m,
		race_config.get_checkpoint_count()
	)
	update_participant_distance(participant_id, distance_m, checkpoint_index)


func update_participant_distance(participant_id: StringName, distance_m: float, checkpoint_index: int = -1) -> void:
	if not _participants.has(participant_id):
		return
	var participant: RaceParticipant = _participants[participant_id]
	var track_length_m: float = _get_track_length_m()
	var result: Dictionary = _lap_tracker.update_progress(
		participant.progress,
		distance_m,
		_race_time_msec,
		track_length_m,
		race_config.get_lap_count(),
		race_config.get_checkpoint_count(),
		checkpoint_index
	)

	if bool(result.get("progress_changed", false)):
		participant_progress_changed.emit(participant, participant.progress.to_dictionary())
	if bool(result.get("checkpoint_changed", false)):
		checkpoint_changed.emit(participant, participant.progress.checkpoint_index)
	if bool(result.get("lap_changed", false)):
		lap_changed.emit(participant, participant.progress.get_display_lap(), race_config.get_lap_count())

	_resort_positions()

	if bool(result.get("finished", false)):
		var placement: int = get_participant_position(participant_id)
		participant_finished.emit(participant, placement)
		_maybe_finish_race(participant)


func get_phase() -> int:
	return _phase


func get_phase_name() -> String:
	return RaceManager.phase_to_string(_phase)


func get_countdown_seconds_remaining() -> float:
	return _countdown_remaining_seconds


func get_race_time_msec() -> int:
	return _race_time_msec


func get_difficulty_hooks() -> Dictionary:
	_ensure_config()
	return race_config.get_difficulty_hooks()


func get_participant(participant_id: StringName) -> RaceParticipant:
	return _participants.get(participant_id, null)


func get_player_participant() -> RaceParticipant:
	for participant_id in _registration_order:
		var participant: RaceParticipant = _participants.get(participant_id, null)
		if participant != null and participant.is_player:
			return participant
	return null


func get_participant_progress(participant_id: StringName) -> RaceParticipantProgress:
	var participant: RaceParticipant = get_participant(participant_id)
	if participant == null:
		return null
	return participant.progress


func get_participant_position(participant_id: StringName) -> int:
	var positions: Dictionary = get_position_map()
	return int(positions.get(participant_id, 0))


func get_position_order() -> Array[StringName]:
	var copy: Array[StringName] = []
	for participant_id in _current_position_order:
		copy.append(participant_id)
	return copy


func get_position_map() -> Dictionary:
	return PositionSorterScript.build_position_map(_get_participant_list())


func get_race_results() -> Array[RaceResult]:
	var copy: Array[RaceResult] = []
	for result in _race_results:
		copy.append(result)
	return copy


func get_ui_snapshot(player_id: StringName = &"") -> Dictionary:
	var focused_participant: RaceParticipant = null
	if player_id != &"":
		focused_participant = get_participant(player_id)
	if focused_participant == null:
		focused_participant = get_player_participant()
	if focused_participant == null and not _registration_order.is_empty():
		focused_participant = get_participant(_registration_order[0])

	var progress_snapshot: Dictionary = {}
	var focused_id: StringName = &""
	var focused_position: int = 0
	if focused_participant != null:
		focused_id = focused_participant.participant_id
		progress_snapshot = focused_participant.progress.to_dictionary()
		focused_position = get_participant_position(focused_id)

	var result_rows: Array[Dictionary] = []
	for result in _race_results:
		result_rows.append(result.to_dictionary())

	return {
		"phase": _phase,
		"phase_name": get_phase_name(),
		"countdown_seconds": _countdown_remaining_seconds,
		"countdown_whole_seconds": int(ceil(_countdown_remaining_seconds)),
		"race_time_msec": _race_time_msec,
		"difficulty": race_config.get_difficulty_id(),
		"focused_participant_id": focused_id,
		"focused_position": focused_position,
		"participant_count": _participants.size(),
		"lap": progress_snapshot.get("current_lap", 1),
		"lap_count": race_config.get_lap_count(),
		"progress": progress_snapshot,
		"position_order": get_position_order(),
		"position_map": get_position_map(),
		"results": result_rows,
	}


static func phase_to_string(phase: int) -> String:
	match phase:
		RacePhase.SETUP:
			return "setup"
		RacePhase.COUNTDOWN:
			return "countdown"
		RacePhase.RACING:
			return "racing"
		RacePhase.FINISHED:
			return "finished"
		_:
			return "unknown"


func _tick_countdown(delta: float) -> void:
	var previous_whole_seconds: int = int(ceil(_countdown_remaining_seconds))
	_countdown_remaining_seconds = max(0.0, _countdown_remaining_seconds - delta)
	var whole_seconds: int = int(ceil(_countdown_remaining_seconds))
	if previous_whole_seconds != whole_seconds:
		countdown_changed.emit(_countdown_remaining_seconds, whole_seconds)
	if _countdown_remaining_seconds <= 0.0:
		start_race_immediately()


func _maybe_finish_race(finished_participant: RaceParticipant) -> void:
	if _phase != RacePhase.RACING:
		return
	if race_config.finish_when_player_finishes and finished_participant.is_player:
		finish_race()
		return

	for participant_id in _registration_order:
		var participant: RaceParticipant = _participants.get(participant_id, null)
		if participant != null and not participant.progress.is_finished:
			return
	finish_race()


func _set_phase(new_phase: int) -> void:
	if _phase == new_phase:
		return
	var previous_phase: int = _phase
	_phase = new_phase
	race_phase_changed.emit(previous_phase, new_phase)


func _ensure_config() -> void:
	if race_config == null:
		race_config = RaceConfigScript.new()


func _resolve_track_query() -> void:
	if _track_query != null:
		return
	if not track_query_path.is_empty():
		_track_query = get_node_or_null(track_query_path)


func _get_track_length_m() -> float:
	_ensure_config()
	_resolve_track_query()
	return RaceTrackProgressProviderScript.get_track_length_m(_track_query, race_config.get_default_track_length_m())


func _reset_all_progress() -> void:
	var track_length_m: float = _get_track_length_m()
	for participant_id in _registration_order:
		var participant: RaceParticipant = _participants.get(participant_id, null)
		if participant != null:
			participant.reset_progress(race_config.get_lap_count(), track_length_m, race_config.get_checkpoint_count())


func _resort_positions() -> void:
	var new_order: Array[StringName] = PositionSorterScript.build_ordered_ids(_get_participant_list())
	if new_order == _current_position_order:
		return
	_current_position_order = new_order
	position_changed.emit(get_position_order(), get_position_map())


func _get_participant_list() -> Array:
	var participants: Array = []
	for participant_id in _registration_order:
		var participant: RaceParticipant = _participants.get(participant_id, null)
		if participant != null:
			participants.append(participant)
	return participants


func _make_participant_id(participant_node: Node) -> StringName:
	var base_name: String = "participant_%d" % [_registration_order.size() + 1]
	if participant_node != null and not String(participant_node.name).is_empty():
		base_name = String(participant_node.name).to_lower().replace(" ", "_")
	var candidate: StringName = StringName(base_name)
	var suffix: int = 2
	while _participants.has(candidate):
		candidate = StringName("%s_%d" % [base_name, suffix])
		suffix += 1
	return candidate
