class_name VehicleCommand
extends RefCounted

var throttle: float = 0.0
var brake: float = 0.0
var steer: float = 0.0
var drift: bool = false
var gear_delta: int = 0


func _init(
		p_throttle: float = 0.0,
		p_brake: float = 0.0,
		p_steer: float = 0.0,
		p_drift: bool = false,
		p_gear_delta: int = 0
) -> void:
	set_values(p_throttle, p_brake, p_steer, p_drift, p_gear_delta)


func set_values(
		p_throttle: float,
		p_brake: float,
		p_steer: float,
		p_drift: bool,
		p_gear_delta: int = 0
) -> RefCounted:
	throttle = clampf(_finite_or(p_throttle, 0.0), 0.0, 1.0)
	brake = clampf(_finite_or(p_brake, 0.0), 0.0, 1.0)
	steer = clampf(_finite_or(p_steer, 0.0), -1.0, 1.0)
	drift = p_drift
	gear_delta = clampi(p_gear_delta, -1, 1)
	return self


func copy_from(other: RefCounted) -> RefCounted:
	if other == null:
		return clear()
	return set_values(other.throttle, other.brake, other.steer, other.drift, _gear_delta_from(other))


func clear() -> RefCounted:
	throttle = 0.0
	brake = 0.0
	steer = 0.0
	drift = false
	gear_delta = 0
	return self


func duplicate_command() -> RefCounted:
	var script: Script = get_script()
	return script.new(throttle, brake, steer, drift, gear_delta)


static func _gear_delta_from(command: RefCounted) -> int:
	if command == null:
		return 0
	var value: Variant = command.get(&"gear_delta")
	if value is int or value is float:
		return clampi(int(value), -1, 1)
	return 0


static func _finite_or(value: float, fallback: float) -> float:
	if is_nan(value) or is_inf(value):
		return fallback
	return value
