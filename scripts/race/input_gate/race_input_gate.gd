class_name RaceInputGate
extends RefCounted

const PermissionProfileScript := preload("res://scripts/race/input_gate/race_input_permission_profile.gd")
const VehicleCommandScript := preload("res://scripts/vehicles/vehicle_command.gd")

const PHASE_SETUP: StringName = &"setup"
const PHASE_COUNTDOWN: StringName = &"countdown"
const PHASE_RACING: StringName = &"racing"
const PHASE_FINISHED: StringName = &"finished"

var setup_profile: Resource = PermissionProfileScript.create_vehicle_locked_profile()
var countdown_profile: Resource = PermissionProfileScript.create_countdown_profile()
var racing_profile: Resource = PermissionProfileScript.create_open_profile()
var finished_profile: Resource = PermissionProfileScript.create_vehicle_locked_profile()


func filter_command(
		raw_command: RefCounted,
		race_phase: Variant = PHASE_RACING,
		target_command: RefCounted = null
) -> RefCounted:
	return filter_command_with_profile(raw_command, get_permission_profile_for_phase(race_phase), target_command)


func filter_command_with_profile(
		raw_command: RefCounted,
		permission_profile: Resource,
		target_command: RefCounted = null
) -> RefCounted:
	var profile: Resource = permission_profile
	if profile == null:
		profile = racing_profile

	var throttle: float = _command_float(raw_command, &"throttle")
	var brake: float = _command_float(raw_command, &"brake")
	var steer: float = _command_float(raw_command, &"steer")
	var drift: bool = _command_bool(raw_command, &"drift")

	if not profile.allows_action(PermissionProfileScript.ACTION_ACCELERATE):
		throttle = 0.0
	if not profile.allows_action(PermissionProfileScript.ACTION_BRAKE):
		brake = 0.0
	if not profile.allows_action(PermissionProfileScript.ACTION_STEER):
		steer = 0.0
	if not profile.allows_action(PermissionProfileScript.ACTION_DRIFT) \
			or not profile.allows_action(PermissionProfileScript.ACTION_HAND_BRAKE):
		drift = false

	var output: RefCounted = target_command
	if output == null:
		output = VehicleCommandScript.new()

	if output.has_method("set_values"):
		output.call("set_values", throttle, brake, steer, drift)
	else:
		output.set("throttle", clampf(throttle, 0.0, 1.0))
		output.set("brake", clampf(brake, 0.0, 1.0))
		output.set("steer", clampf(steer, -1.0, 1.0))
		output.set("drift", drift)
	return output


func get_permission_profile_for_phase(race_phase: Variant) -> Resource:
	match normalize_phase(race_phase):
		PHASE_SETUP:
			return setup_profile
		PHASE_COUNTDOWN:
			return countdown_profile
		PHASE_FINISHED:
			return finished_profile
		_:
			return racing_profile


func set_permission_profile_for_phase(race_phase: Variant, permission_profile: Resource) -> void:
	if permission_profile == null:
		return

	match normalize_phase(race_phase):
		PHASE_SETUP:
			setup_profile = permission_profile
		PHASE_COUNTDOWN:
			countdown_profile = permission_profile
		PHASE_FINISHED:
			finished_profile = permission_profile
		_:
			racing_profile = permission_profile


func is_action_allowed(race_phase: Variant, action: Variant) -> bool:
	var profile: Resource = get_permission_profile_for_phase(race_phase)
	if profile == null:
		return true
	return profile.allows_action(action)


static func normalize_phase(race_phase: Variant) -> StringName:
	if race_phase is int:
		match int(race_phase):
			0:
				return PHASE_SETUP
			1:
				return PHASE_COUNTDOWN
			2:
				return PHASE_RACING
			3:
				return PHASE_FINISHED
			_:
				return PHASE_RACING

	var text: String = String(race_phase).to_lower()
	if text in ["setup", "pre_race", "pre-race"]:
		return PHASE_SETUP
	if text in ["countdown", "starting"]:
		return PHASE_COUNTDOWN
	if text in ["finished", "complete", "results"]:
		return PHASE_FINISHED
	return PHASE_RACING


static func _command_float(raw_command: RefCounted, property_name: StringName) -> float:
	if raw_command == null:
		return 0.0
	var value: Variant = raw_command.get(property_name)
	if value is float or value is int:
		return float(value)
	return 0.0


static func _command_bool(raw_command: RefCounted, property_name: StringName) -> bool:
	if raw_command == null:
		return false
	var value: Variant = raw_command.get(property_name)
	if value is bool:
		return value
	return false
