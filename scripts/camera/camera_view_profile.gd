class_name CameraViewProfile
extends Resource

enum ViewRole {
	PRIMARY,
	TEMPORARY_OVERRIDE,
}

enum RollMode {
	NONE,
	STEER_BIAS,
	MATCH_TARGET_UP,
	MATCH_TRACK_UP,
}

enum CollisionMode {
	DISABLED,
	RAYCAST,
}

@export var view_id: StringName = &"chase"
@export var display_name: String = "Chase"
@export_enum("Primary", "Temporary Override") var view_role: int = ViewRole.PRIMARY

@export_category("Composition")
@export var anchor_offset_local: Vector3 = Vector3.ZERO
@export var camera_offset_local: Vector3 = Vector3(0.0, 2.85, 7.4)
@export var view_yaw_degrees: float = 0.0
@export_range(35.0, 120.0, 0.1) var fov_degrees: float = 66.0
@export_range(35.0, 120.0, 0.1) var high_speed_fov_degrees: float = 74.0
@export_range(0.2, 2.0, 0.01) var fov_speed_power: float = 1.05

@export_category("Damping")
@export var position_damping: float = 15.0
@export var rotation_damping: float = 14.0
@export var fov_damping: float = 4.0
@export var roll_damping: float = 8.0
@export var collision_return_damping: float = 18.0
@export var max_follow_lag_m: float = 2.2

@export_category("Roll Behavior")
@export_enum("None", "Steer Bias", "Match Target Up", "Match Track Up") var roll_mode: int = RollMode.STEER_BIAS
@export var roll_degrees: float = 3.5
@export var drift_roll_bonus_degrees: float = 2.0
@export_range(0.0, 1.0, 0.01) var track_orientation_weight: float = 0.0
@export_range(0.0, 1.0, 0.01) var airborne_orientation_hold: float = 0.65

@export_category("Collision Behavior")
@export_enum("Disabled", "Raycast") var collision_mode: int = CollisionMode.RAYCAST
@export_flags_3d_physics var collision_mask: int = 1
@export var collision_radius_m: float = 0.25
@export var collision_margin_m: float = 0.35

@export_category("Road Preview Bias")
@export var road_preview_enabled: bool = true
@export var preview_distance_low_speed_m: float = 6.0
@export var preview_distance_high_speed_m: float = 12.0
@export var preview_height_m: float = 1.25
@export var corner_preview_lateral_m: float = 1.7
@export_range(0.0, 1.0, 0.01) var velocity_preview_bias: float = 0.20
@export var velocity_preview_damping: float = 7.0
@export_range(0.0, 1.0, 0.01) var velocity_preview_vertical_weight: float = 0.0
@export_range(0.0, 1.0, 0.01) var track_preview_weight: float = 0.0


func is_temporary_override() -> bool:
	return view_role == ViewRole.TEMPORARY_OVERRIDE


func uses_collision() -> bool:
	return collision_mode != CollisionMode.DISABLED


func get_target_fov(speed_ratio: float) -> float:
	var safe_ratio: float = clampf(speed_ratio, 0.0, 1.0)
	return lerpf(fov_degrees, high_speed_fov_degrees, pow(safe_ratio, fov_speed_power))


func get_preview_distance(speed_ratio: float) -> float:
	if not road_preview_enabled:
		return preview_distance_low_speed_m
	return lerpf(
			preview_distance_low_speed_m,
			preview_distance_high_speed_m,
			clampf(speed_ratio, 0.0, 1.0)
	)
