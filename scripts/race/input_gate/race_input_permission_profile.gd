class_name RaceInputPermissionProfile
extends Resource

const ACTION_ACCELERATE: StringName = &"accelerate"
const ACTION_BRAKE: StringName = &"brake"
const ACTION_STEER: StringName = &"steer"
const ACTION_DRIFT: StringName = &"drift"
const ACTION_HAND_BRAKE: StringName = &"handbrake"
const ACTION_CAMERA_TOGGLE_PRIMARY: StringName = &"camera_toggle_primary"
const ACTION_CAMERA_LOOK_BACK: StringName = &"camera_look_back"
const ACTION_PAUSE: StringName = &"pause"
const ACTION_RACE_MENU_OVERLAY: StringName = &"race_menu_overlay"

@export var allow_accelerate: bool = true
@export var allow_brake: bool = true
@export var allow_steer: bool = true
@export var allow_drift: bool = true
@export var allow_handbrake: bool = true
@export var allow_camera_toggle_primary: bool = true
@export var allow_camera_look_back: bool = true
@export var allow_pause: bool = true
@export var allow_race_menu_overlay: bool = true
@export var allow_unlisted_actions: bool = true


static func create_open_profile() -> RaceInputPermissionProfile:
	return RaceInputPermissionProfile.new()


static func create_countdown_profile() -> RaceInputPermissionProfile:
	var profile: RaceInputPermissionProfile = RaceInputPermissionProfile.new()
	profile.configure_countdown_permissions()
	return profile


static func create_vehicle_locked_profile() -> RaceInputPermissionProfile:
	var profile: RaceInputPermissionProfile = RaceInputPermissionProfile.new()
	profile.allow_accelerate = false
	profile.allow_brake = true
	profile.allow_steer = false
	profile.allow_drift = false
	profile.allow_handbrake = false
	profile.allow_camera_toggle_primary = true
	profile.allow_camera_look_back = true
	profile.allow_pause = true
	profile.allow_race_menu_overlay = true
	profile.allow_unlisted_actions = false
	return profile


func configure_countdown_permissions() -> RaceInputPermissionProfile:
	allow_accelerate = false
	allow_brake = true
	allow_steer = false
	allow_drift = false
	allow_handbrake = false
	allow_camera_toggle_primary = true
	allow_camera_look_back = true
	allow_pause = true
	allow_race_menu_overlay = true
	allow_unlisted_actions = false
	return self


func allows_action(action: Variant) -> bool:
	var normalized: StringName = normalize_action(action)

	if normalized in [&"accelerate", &"throttle", &"drive_accelerate"]:
		return allow_accelerate
	if normalized in [&"brake", &"drive_brake"]:
		return allow_brake
	if normalized in [&"steer", &"steering", &"drive_left", &"drive_right"]:
		return allow_steer
	if normalized in [&"drift", &"drive_drift"]:
		return allow_drift
	if normalized in [&"handbrake", &"hand_brake", &"drive_handbrake"]:
		return allow_handbrake
	if normalized in [&"camera_toggle_primary", &"camera_cycle", &"camera_toggle"]:
		return allow_camera_toggle_primary
	if normalized in [&"camera_look_back", &"look_back"]:
		return allow_camera_look_back
	if normalized in [&"pause", &"ui_cancel"]:
		return allow_pause
	if normalized in [&"race_menu_overlay", &"race_menu", &"menu_overlay"]:
		return allow_race_menu_overlay

	return allow_unlisted_actions


func to_dictionary() -> Dictionary:
	return {
		"accelerate": allow_accelerate,
		"brake": allow_brake,
		"steer": allow_steer,
		"drift": allow_drift,
		"handbrake": allow_handbrake,
		"camera_toggle_primary": allow_camera_toggle_primary,
		"camera_look_back": allow_camera_look_back,
		"pause": allow_pause,
		"race_menu_overlay": allow_race_menu_overlay,
		"unlisted_actions": allow_unlisted_actions,
	}


func duplicate_profile() -> RaceInputPermissionProfile:
	var copy: RaceInputPermissionProfile = RaceInputPermissionProfile.new()
	copy.allow_accelerate = allow_accelerate
	copy.allow_brake = allow_brake
	copy.allow_steer = allow_steer
	copy.allow_drift = allow_drift
	copy.allow_handbrake = allow_handbrake
	copy.allow_camera_toggle_primary = allow_camera_toggle_primary
	copy.allow_camera_look_back = allow_camera_look_back
	copy.allow_pause = allow_pause
	copy.allow_race_menu_overlay = allow_race_menu_overlay
	copy.allow_unlisted_actions = allow_unlisted_actions
	return copy


static func normalize_action(action: Variant) -> StringName:
	return StringName(String(action).to_lower())
