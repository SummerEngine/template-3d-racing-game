class_name PlayerDriver
extends Node

const VehicleCommandScript := preload("res://scripts/vehicles/vehicle_command.gd")

@export_category("Input Actions")
@export var accelerate_action: StringName = &"drive_accelerate"
@export var brake_action: StringName = &"drive_brake"
@export var steer_left_action: StringName = &"drive_left"
@export var steer_right_action: StringName = &"drive_right"
@export var drift_action: StringName = &"drive_drift"

var _command: RefCounted = VehicleCommandScript.new()


func get_command() -> RefCounted:
	return sample_command()


func sample_command() -> RefCounted:
	return _command.set_values(
			Input.get_action_strength(accelerate_action),
			Input.get_action_strength(brake_action),
			Input.get_action_strength(steer_right_action) - Input.get_action_strength(steer_left_action),
			Input.is_action_pressed(drift_action)
	)


func write_command(target: RefCounted) -> void:
	if target == null:
		return
	target.copy_from(sample_command())
