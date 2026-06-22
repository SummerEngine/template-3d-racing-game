class_name PlayerDriver
extends Node

const VehicleCommandScript := preload("res://scripts/vehicles/vehicle_command.gd")
const DEVICE_KEYBOARD := &"keyboard"
const DEVICE_CONTROLLER := &"controller"
const DEVICE_NONE := &"none"

@export_category("Input Actions")
@export var accelerate_action: StringName = &"drive_accelerate"
@export var brake_action: StringName = &"drive_brake"
@export var steer_left_action: StringName = &"drive_left"
@export var steer_right_action: StringName = &"drive_right"
@export var drift_action: StringName = &"drive_drift"
@export var shift_down_action: StringName = &"drive_shift_down"
@export var shift_up_action: StringName = &"drive_shift_up"

@export_category("Controller")
@export var controller_enabled: bool = true
@export var controller_steer_axis: int = JOY_AXIS_LEFT_X
@export var controller_accelerate_axis: int = JOY_AXIS_TRIGGER_RIGHT
@export var controller_brake_axis: int = JOY_AXIS_TRIGGER_LEFT
@export var controller_drift_buttons: Array[int] = [JOY_BUTTON_A, JOY_BUTTON_LEFT_SHOULDER]
@export var controller_shift_down_buttons: Array[int] = []
@export var controller_shift_up_buttons: Array[int] = []
@export_range(0.0, 0.6, 0.01) var stick_deadzone: float = 0.18
@export_range(0.0, 0.6, 0.01) var trigger_deadzone: float = 0.08

@export_category("Response")
@export_range(0.5, 3.0, 0.05) var controller_steer_exponent: float = 1.35
@export_range(0.5, 3.0, 0.05) var keyboard_steer_exponent: float = 1.0
@export_range(0.1, 24.0, 0.1) var steer_rise_speed: float = 5.8
@export_range(0.1, 30.0, 0.1) var steer_return_speed: float = 9.5
@export_range(0.1, 36.0, 0.1) var steer_counter_speed: float = 14.0
@export_range(0.1, 18.0, 0.1) var throttle_rise_speed: float = 4.4
@export_range(0.1, 24.0, 0.1) var throttle_release_speed: float = 8.0
@export_range(0.1, 24.0, 0.1) var brake_rise_speed: float = 8.5
@export_range(0.1, 24.0, 0.1) var brake_release_speed: float = 10.0
@export_range(0.0, 0.35, 0.01) var input_activation_threshold: float = 0.04
@export_range(0.0, 0.35, 0.01) var pedal_conflict_threshold: float = 0.08
@export_enum("brake_priority", "stronger_axis", "neutral") var pedal_conflict_mode: String = "brake_priority"

var _command: RefCounted = VehicleCommandScript.new()
var _smoothed_throttle: float = 0.0
var _smoothed_brake: float = 0.0
var _smoothed_steer: float = 0.0
var _last_input_device: StringName = DEVICE_NONE
var _last_controller_device: int = -1
var _trigger_neutral_values: Dictionary = {}


func get_command() -> RefCounted:
	return sample_command_delta(1.0 / 60.0)


func sample_command() -> RefCounted:
	return sample_command_delta(1.0 / 60.0)


func sample_command_delta(delta: float) -> RefCounted:
	delta = _safe_delta(delta)
	var input_sample: Dictionary = _sample_active_input()
	var throttle: float = float(input_sample.get("throttle", 0.0))
	var brake: float = float(input_sample.get("brake", 0.0))
	var steer: float = float(input_sample.get("steer", 0.0))
	var gear_delta: int = int(input_sample.get("gear_delta", 0))
	var source: StringName = input_sample.get("device", DEVICE_NONE)

	var pedals: Vector2 = _resolve_pedal_conflict(throttle, brake)
	throttle = pedals.x
	brake = pedals.y
	steer = _shape_axis(steer, controller_steer_exponent if source == DEVICE_CONTROLLER else keyboard_steer_exponent)

	_smoothed_throttle = _smooth_axis(_smoothed_throttle, throttle, throttle_rise_speed, throttle_release_speed, delta)
	_smoothed_brake = _smooth_axis(_smoothed_brake, brake, brake_rise_speed, brake_release_speed, delta)
	_smoothed_steer = _smooth_steer(_smoothed_steer, steer, delta)

	return _command.set_values(
			_smoothed_throttle,
			_smoothed_brake,
			_smoothed_steer,
			bool(input_sample.get("drift", false)),
			gear_delta
	)


func write_command(target: RefCounted) -> void:
	write_command_with_delta(target, 1.0 / 60.0)


func write_command_with_delta(target: RefCounted, delta: float) -> void:
	if target == null:
		return
	target.copy_from(sample_command_delta(delta))


func clear_input_state() -> void:
	_smoothed_throttle = 0.0
	_smoothed_brake = 0.0
	_smoothed_steer = 0.0
	_last_input_device = DEVICE_NONE
	_last_controller_device = -1
	_command.clear()


func get_last_input_device() -> StringName:
	return _last_input_device


func get_last_controller_device() -> int:
	return _last_controller_device


func _sample_active_input() -> Dictionary:
	var keyboard_sample: Dictionary = _sample_keyboard_input()
	var controller_sample: Dictionary = _sample_controller_input()
	var keyboard_magnitude: float = float(keyboard_sample.get("magnitude", 0.0))
	var controller_magnitude: float = float(controller_sample.get("magnitude", 0.0))

	if controller_magnitude > input_activation_threshold and controller_magnitude >= keyboard_magnitude:
		_last_input_device = DEVICE_CONTROLLER
		_last_controller_device = int(controller_sample.get("controller_device", -1))
		return controller_sample

	if keyboard_magnitude > input_activation_threshold:
		_last_input_device = DEVICE_KEYBOARD
		return keyboard_sample

	if _last_input_device == DEVICE_CONTROLLER and controller_magnitude > 0.0:
		return controller_sample
	if _last_input_device == DEVICE_KEYBOARD and keyboard_magnitude > 0.0:
		return keyboard_sample

	return {
		"device": DEVICE_NONE,
		"controller_device": -1,
		"throttle": 0.0,
		"brake": 0.0,
		"steer": 0.0,
		"drift": false,
		"gear_delta": 0,
		"magnitude": 0.0,
	}


func _sample_keyboard_input() -> Dictionary:
	var throttle: float = Input.get_action_strength(accelerate_action)
	var brake: float = Input.get_action_strength(brake_action)
	var steer: float = Input.get_action_strength(steer_right_action) - Input.get_action_strength(steer_left_action)
	var drift: bool = Input.is_action_pressed(drift_action)
	var gear_delta: int = _keyboard_gear_delta()
	var magnitude: float = maxf(maxf(throttle, brake), absf(steer))
	if drift:
		magnitude = maxf(magnitude, 1.0)
	if gear_delta != 0:
		magnitude = maxf(magnitude, 1.0)
	return {
		"device": DEVICE_KEYBOARD,
		"controller_device": -1,
		"throttle": throttle,
		"brake": brake,
		"steer": steer,
		"drift": drift,
		"gear_delta": gear_delta,
		"magnitude": magnitude,
	}


func _sample_controller_input() -> Dictionary:
	var best_sample: Dictionary = {
		"device": DEVICE_CONTROLLER,
		"controller_device": -1,
		"throttle": 0.0,
		"brake": 0.0,
		"steer": 0.0,
		"drift": false,
		"gear_delta": 0,
		"magnitude": 0.0,
	}
	if not controller_enabled:
		return best_sample

	for device_id: int in Input.get_connected_joypads():
		var steer: float = _apply_deadzone(Input.get_joy_axis(device_id, controller_steer_axis), stick_deadzone)
		var throttle: float = _controller_trigger_strength(device_id, controller_accelerate_axis)
		var brake: float = _controller_trigger_strength(device_id, controller_brake_axis)
		var drift: bool = _is_controller_drift_pressed(device_id)
		var gear_delta: int = _controller_gear_delta(device_id)
		var magnitude: float = maxf(maxf(throttle, brake), absf(steer))
		if drift:
			magnitude = maxf(magnitude, 1.0)
		if gear_delta != 0:
			magnitude = maxf(magnitude, 1.0)
		if magnitude > float(best_sample.get("magnitude", 0.0)):
			best_sample = {
				"device": DEVICE_CONTROLLER,
				"controller_device": device_id,
				"throttle": throttle,
				"brake": brake,
				"steer": steer,
				"drift": drift,
				"gear_delta": gear_delta,
				"magnitude": magnitude,
			}
	return best_sample


func _keyboard_gear_delta() -> int:
	var up_pressed: bool = Input.is_action_just_pressed(shift_up_action)
	var down_pressed: bool = Input.is_action_just_pressed(shift_down_action)
	if up_pressed == down_pressed:
		return 0
	return 1 if up_pressed else -1


func _controller_gear_delta(device_id: int) -> int:
	var up_pressed: bool = _is_controller_button_just_pressed(device_id, controller_shift_up_buttons)
	var down_pressed: bool = _is_controller_button_just_pressed(device_id, controller_shift_down_buttons)
	if up_pressed == down_pressed:
		return 0
	return 1 if up_pressed else -1


func _is_controller_drift_pressed(device_id: int) -> bool:
	for button_index: int in controller_drift_buttons:
		if Input.is_joy_button_pressed(device_id, button_index):
			return true
	return false


func _is_controller_button_just_pressed(device_id: int, button_indices: Array[int]) -> bool:
	for button_index: int in button_indices:
		if Input.is_joy_button_pressed(device_id, button_index):
			var key: String = "button:%d:%d" % [device_id, button_index]
			var was_pressed: bool = bool(_trigger_neutral_values.get(key, false))
			_trigger_neutral_values[key] = true
			if not was_pressed:
				return true
		else:
			_trigger_neutral_values["button:%d:%d" % [device_id, button_index]] = false
	return false


func _controller_trigger_strength(device_id: int, axis: int) -> float:
	var raw_value: float = Input.get_joy_axis(device_id, axis)
	var key: String = "%d:%d" % [device_id, axis]
	if not _trigger_neutral_values.has(key):
		_trigger_neutral_values[key] = raw_value if absf(raw_value) > 0.35 else 0.0

	var neutral: float = float(_trigger_neutral_values.get(key, 0.0))
	var normalized: float = 0.0
	if neutral < -0.35:
		normalized = inverse_lerp(neutral, 1.0, raw_value)
	else:
		normalized = raw_value
	return _apply_deadzone(clampf(normalized, 0.0, 1.0), trigger_deadzone)


func _resolve_pedal_conflict(throttle: float, brake: float) -> Vector2:
	if throttle <= pedal_conflict_threshold or brake <= pedal_conflict_threshold:
		return Vector2(throttle, brake)

	match pedal_conflict_mode:
		"stronger_axis":
			if throttle > brake:
				return Vector2(throttle, 0.0)
			if brake > throttle:
				return Vector2(0.0, brake)
			return Vector2.ZERO
		"neutral":
			return Vector2.ZERO
		_:
			return Vector2(0.0, brake)


func _smooth_steer(current: float, target: float, delta: float) -> float:
	var speed: float = steer_rise_speed
	if absf(target) <= 0.001:
		speed = steer_return_speed
	elif absf(current) > 0.001 and signf(current) != signf(target):
		speed = steer_counter_speed
	return move_toward(current, target, speed * delta)


func _smooth_axis(current: float, target: float, rise_speed: float, release_speed: float, delta: float) -> float:
	var speed: float = rise_speed if target > current else release_speed
	return move_toward(current, target, speed * delta)


func _shape_axis(value: float, exponent: float) -> float:
	value = clampf(_finite_or(value, 0.0), -1.0, 1.0)
	exponent = maxf(_finite_or(exponent, 1.0), 0.01)
	return signf(value) * pow(absf(value), exponent)


func _apply_deadzone(value: float, deadzone: float) -> float:
	value = clampf(_finite_or(value, 0.0), -1.0, 1.0)
	deadzone = clampf(_finite_or(deadzone, 0.0), 0.0, 0.95)
	var magnitude: float = absf(value)
	if magnitude <= deadzone:
		return 0.0
	return signf(value) * ((magnitude - deadzone) / (1.0 - deadzone))


func _safe_delta(delta: float) -> float:
	if is_nan(delta) or is_inf(delta) or delta <= 0.0:
		return 1.0 / 60.0
	return clampf(delta, 1.0 / 240.0, 1.0 / 20.0)


func _finite_or(value: float, fallback: float) -> float:
	if is_nan(value) or is_inf(value):
		return fallback
	return value
