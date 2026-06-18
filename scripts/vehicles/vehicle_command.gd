class_name VehicleCommand
extends RefCounted

var throttle: float = 0.0
var brake: float = 0.0
var steer: float = 0.0
var drift: bool = false


func _init(
		p_throttle: float = 0.0,
		p_brake: float = 0.0,
		p_steer: float = 0.0,
		p_drift: bool = false
) -> void:
	set_values(p_throttle, p_brake, p_steer, p_drift)


func set_values(
		p_throttle: float,
		p_brake: float,
		p_steer: float,
		p_drift: bool
) -> RefCounted:
	throttle = clampf(_finite_or(p_throttle, 0.0), 0.0, 1.0)
	brake = clampf(_finite_or(p_brake, 0.0), 0.0, 1.0)
	steer = clampf(_finite_or(p_steer, 0.0), -1.0, 1.0)
	drift = p_drift
	return self


func copy_from(other: RefCounted) -> RefCounted:
	if other == null:
		return clear()
	return set_values(other.throttle, other.brake, other.steer, other.drift)


func clear() -> RefCounted:
	throttle = 0.0
	brake = 0.0
	steer = 0.0
	drift = false
	return self


func duplicate_command() -> RefCounted:
	var script: Script = get_script()
	return script.new(throttle, brake, steer, drift)


static func _finite_or(value: float, fallback: float) -> float:
	if is_nan(value) or is_inf(value):
		return fallback
	return value
