class_name RaceInputGateDriver
extends Node

const RaceInputGateScript := preload("res://scripts/race/input_gate/race_input_gate.gd")
const VehicleCommandScript := preload("res://scripts/vehicles/vehicle_command.gd")

@export var raw_driver_path: NodePath = NodePath("")
@export var race_manager_path: NodePath = NodePath("")
@export var fallback_phase: StringName = &"racing"

var _gate: RefCounted = RaceInputGateScript.new()
var _raw_command: RefCounted = VehicleCommandScript.new()
var _filtered_command: RefCounted = VehicleCommandScript.new()
var _raw_driver: Node = null
var _race_manager: Node = null


func get_command() -> RefCounted:
	return _sample_filtered_command(_filtered_command)


func write_command(target_command: RefCounted) -> void:
	if target_command == null:
		return
	_sample_filtered_command(target_command)


func is_action_allowed(action: Variant) -> bool:
	return bool(_gate.call("is_action_allowed", _current_phase(), action))


func get_permission_profile_for_current_phase() -> Resource:
	return _gate.call("get_permission_profile_for_phase", _current_phase())


func _sample_filtered_command(target_command: RefCounted) -> RefCounted:
	_sample_raw_command()
	return _gate.call("filter_command", _raw_command, _current_phase(), target_command)


func _sample_raw_command() -> void:
	_raw_command.clear()
	var raw_driver: Node = _resolve_raw_driver()
	if raw_driver == null:
		return

	if raw_driver.has_method("write_command"):
		raw_driver.call("write_command", _raw_command)
	elif raw_driver.has_method("get_command"):
		var command_value: Variant = raw_driver.call("get_command")
		if command_value is RefCounted and command_value.has_method("copy_from"):
			_raw_command.copy_from(command_value)


func _current_phase() -> Variant:
	var race_manager: Node = _resolve_race_manager()
	if race_manager == null:
		return fallback_phase
	if race_manager.has_method("get_phase"):
		return race_manager.call("get_phase")
	if race_manager.has_method("get_phase_name"):
		return race_manager.call("get_phase_name")
	return fallback_phase


func _resolve_raw_driver() -> Node:
	if _raw_driver != null and is_instance_valid(_raw_driver):
		return _raw_driver
	_raw_driver = _node_at_path(raw_driver_path)
	return _raw_driver


func _resolve_race_manager() -> Node:
	if _race_manager != null and is_instance_valid(_race_manager):
		return _race_manager
	_race_manager = _node_at_path(race_manager_path)
	return _race_manager


func _node_at_path(path: NodePath) -> Node:
	if String(path).is_empty():
		return null
	return get_node_or_null(path)
