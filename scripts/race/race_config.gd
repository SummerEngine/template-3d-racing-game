class_name RaceConfig
extends Resource

const DIFFICULTY_EASY: StringName = &"easy"
const DIFFICULTY_MEDIUM: StringName = &"medium"
const DIFFICULTY_HARD: StringName = &"hard"

@export var lap_count: int = 3
@export var npc_count: int = 3
@export_enum("easy", "medium", "hard") var difficulty: String = "medium"
@export var countdown_seconds: float = 3.0
@export var default_track_length_m: float = 1800.0
@export var checkpoint_count: int = 0
@export var finish_when_player_finishes: bool = true
@export var npc_personality_ids: Array[StringName] = [&"technician", &"bully", &"showoff"]


func get_lap_count() -> int:
	return max(1, lap_count)


func get_npc_count() -> int:
	return max(0, npc_count)


func get_checkpoint_count() -> int:
	return max(0, checkpoint_count)


func get_countdown_seconds() -> float:
	return max(0.0, countdown_seconds)


func get_default_track_length_m() -> float:
	return max(1.0, default_track_length_m)


func get_difficulty_id() -> StringName:
	var normalized: String = difficulty.to_lower()
	if normalized == String(DIFFICULTY_EASY):
		return DIFFICULTY_EASY
	if normalized == String(DIFFICULTY_HARD):
		return DIFFICULTY_HARD
	return DIFFICULTY_MEDIUM


func set_difficulty_id(value: StringName) -> void:
	if value == DIFFICULTY_EASY or value == DIFFICULTY_MEDIUM or value == DIFFICULTY_HARD:
		difficulty = String(value)
	else:
		difficulty = String(DIFFICULTY_MEDIUM)


func get_difficulty_hooks() -> Dictionary:
	match get_difficulty_id():
		DIFFICULTY_EASY:
			return {
				"difficulty": DIFFICULTY_EASY,
				"npc_skill": {
					"speed_multiplier": 0.92,
					"racing_line_precision": 0.74,
					"mistake_frequency": 1.35,
					"overtake_assertiveness": 0.72,
					"turn_width_multiplier": 1.18,
				},
				"player_assists": {
					"wall_recovery_multiplier": 1.25,
					"anti_pileup_multiplier": 1.25,
					"car_bump_softness": 1.20,
				},
				"rubberbanding": {
					"allowed": false,
				},
			}
		DIFFICULTY_HARD:
			return {
				"difficulty": DIFFICULTY_HARD,
				"npc_skill": {
					"speed_multiplier": 1.04,
					"racing_line_precision": 1.15,
					"mistake_frequency": 0.70,
					"overtake_assertiveness": 1.20,
					"turn_width_multiplier": 0.92,
				},
				"player_assists": {
					"wall_recovery_multiplier": 0.85,
					"anti_pileup_multiplier": 0.85,
					"car_bump_softness": 0.90,
				},
				"rubberbanding": {
					"allowed": false,
				},
			}
		_:
			return {
				"difficulty": DIFFICULTY_MEDIUM,
				"npc_skill": {
					"speed_multiplier": 1.0,
					"racing_line_precision": 1.0,
					"mistake_frequency": 1.0,
					"overtake_assertiveness": 1.0,
					"turn_width_multiplier": 1.0,
				},
				"player_assists": {
					"wall_recovery_multiplier": 1.0,
					"anti_pileup_multiplier": 1.0,
					"car_bump_softness": 1.0,
				},
				"rubberbanding": {
					"allowed": false,
				},
			}


func get_npc_personality_id(slot_index: int) -> StringName:
	if npc_personality_ids.is_empty():
		return &"npc"
	var wrapped_index: int = posmod(slot_index, npc_personality_ids.size())
	return npc_personality_ids[wrapped_index]


func get_npc_metadata(slot_index: int) -> Dictionary:
	var hooks: Dictionary = get_difficulty_hooks()
	var npc_skill: Dictionary = hooks.get("npc_skill", {})
	var player_assists: Dictionary = hooks.get("player_assists", {})
	var rubberbanding: Dictionary = hooks.get("rubberbanding", {})
	return {
		"participant_kind": &"npc",
		"npc_slot": slot_index,
		"personality_id": get_npc_personality_id(slot_index),
		"racing_line_profile_id": get_npc_personality_id(slot_index),
		"difficulty": get_difficulty_id(),
		"npc_skill": npc_skill.duplicate(true),
		"player_assists": player_assists.duplicate(true),
		"rubberbanding": rubberbanding.duplicate(true),
	}
