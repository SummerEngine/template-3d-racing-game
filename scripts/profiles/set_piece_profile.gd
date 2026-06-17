class_name SetPieceProfile
extends Resource

@export var set_piece_id: StringName = &""
@export var display_name: String = ""
@export var scene_path: String = ""
@export var entry_socket: StringName = &"EntrySocket"
@export var exit_socket: StringName = &"ExitSocket"
@export_range(0.0, 120.0, 0.1) var min_speed_mps: float = 0.0
@export_enum("chase", "cockpit", "look_back", "set_piece_preview") var recommended_camera_mode: String = "chase"
@export var surface_gravity_mode: StringName = &"track_relative"
@export var ai_strategy: StringName = &"follow_track_query"
@export_range(0, 5, 1) var risk_rating: int = 1
@export_range(0.0, 500.0, 0.1) var warning_distance_m: float = 90.0
@export_range(0.0, 500.0, 0.1) var approach_distance_m: float = 160.0
@export_range(0.0, 500.0, 0.1) var recovery_distance_m: float = 130.0
@export_range(0.0, 80.0, 0.1) var landing_width_m: float = 18.0
@export var fail_safe_volume_id: StringName = &""
@export var vfx_cue_ids: PackedStringArray = PackedStringArray()
@export var audio_cue_ids: PackedStringArray = PackedStringArray()
@export_multiline var notes: String = ""


func get_profile_id() -> StringName:
	return set_piece_id


func requires_speed_warning() -> bool:
	return min_speed_mps > 0.0 and warning_distance_m > 0.0
