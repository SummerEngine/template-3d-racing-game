class_name ElasticChaseCamera
extends Camera3D

@export var target_path: NodePath
@export var target_marker_name: StringName = &"CameraTarget"

@export_category("Composition")
@export_range(0.45, 0.85, 0.01) var target_screen_y: float = 0.70
@export var screen_y_correction: float = 10.0
@export var max_screen_vertical_correction: float = 5.0
@export var composition_smoothing: float = 7.0

@export_category("Distance")
@export var low_speed_distance: float = 8.2
@export var high_speed_distance: float = 7.2
@export var low_speed_height: float = 3.25
@export var high_speed_height: float = 2.8

@export_category("Road Preview")
@export var low_speed_look_ahead: float = 6.0
@export var high_speed_look_ahead: float = 12.0
@export var look_height: float = 1.25
@export var corner_look_offset: float = 1.7
@export_range(0.0, 1.0, 0.01) var grip_velocity_bias: float = 0.20
@export_range(0.0, 1.0, 0.01) var drift_velocity_bias: float = 0.55

@export_category("Smoothing")
@export var longitudinal_smoothing_low: float = 11.0
@export var longitudinal_smoothing_high: float = 24.0
@export var lateral_smoothing: float = 8.0
@export var vertical_smoothing: float = 7.0
@export var rotation_smoothing: float = 12.0
@export var max_follow_lag: float = 2.2

@export_category("Speed Feel")
@export var min_fov: float = 66.0
@export var max_fov: float = 74.0
@export var fov_speed_power: float = 1.05
@export var fov_smoothing: float = 4.0
@export var roll_degrees: float = 3.5
@export var drift_roll_bonus_degrees: float = 2.0
@export var roll_smoothing: float = 8.0

var _target: Node3D
var _target_marker: Node3D
var _current_roll: float = 0.0
var _composition_vertical_offset: float = 0.0
var _last_anchor_position: Vector3 = Vector3.ZERO
var _estimated_velocity: Vector3 = Vector3.ZERO


func _ready() -> void:
	_target = get_node_or_null(target_path) as Node3D
	_refresh_target_marker()
	if _target != null:
		var anchor: Vector3 = _anchor_position()
		_last_anchor_position = anchor
		var chase_forward: Vector3 = _chase_forward(0.0)
		global_position = _desired_position(anchor, chase_forward, 0.0)
		_update_look(anchor, chase_forward, 0.0)


func _process(delta: float) -> void:
	if _target == null:
		return

	_refresh_target_marker()
	var anchor: Vector3 = _anchor_position()
	_update_estimated_velocity(anchor, delta)
	var ratio: float = _speed_ratio()
	var chase_forward: Vector3 = _chase_forward(ratio)
	var desired_position: Vector3 = _desired_position(anchor, chase_forward, ratio)
	_smooth_position(desired_position, chase_forward, ratio, delta)

	var fov_ratio: float = pow(ratio, fov_speed_power)
	fov = lerpf(fov, lerpf(min_fov, max_fov, fov_ratio), 1.0 - exp(-fov_smoothing * delta))
	_update_look(anchor, chase_forward, delta)
	_last_anchor_position = anchor


func _desired_position(anchor: Vector3, chase_forward: Vector3, speed_ratio: float) -> Vector3:
	var distance: float = lerpf(low_speed_distance, high_speed_distance, speed_ratio)
	var height: float = lerpf(low_speed_height, high_speed_height, speed_ratio)
	return anchor - chase_forward * distance + Vector3.UP * height


func _smooth_position(desired_position: Vector3, chase_forward: Vector3, speed_ratio: float, delta: float) -> void:
	if delta <= 0.0:
		global_position = desired_position
		return

	var flat_forward: Vector3 = Vector3(chase_forward.x, 0.0, chase_forward.z)
	if flat_forward.length_squared() <= 0.0001:
		flat_forward = Vector3.FORWARD
	flat_forward = flat_forward.normalized()
	var right: Vector3 = Vector3.UP.cross(flat_forward).normalized()
	var up: Vector3 = Vector3.UP
	var offset: Vector3 = desired_position - global_position

	var longitudinal_weight: float = 1.0 - exp(-lerpf(longitudinal_smoothing_low, longitudinal_smoothing_high, speed_ratio) * delta)
	var lateral_weight: float = 1.0 - exp(-lateral_smoothing * delta)
	var vertical_weight: float = 1.0 - exp(-vertical_smoothing * delta)

	global_position += flat_forward * offset.dot(flat_forward) * longitudinal_weight
	global_position += right * offset.dot(right) * lateral_weight
	global_position += up * offset.dot(up) * vertical_weight

	var lag: Vector3 = global_position - desired_position
	if lag.length() > max_follow_lag:
		global_position = desired_position + lag.normalized() * max_follow_lag


func _update_look(anchor: Vector3, chase_forward: Vector3, delta: float) -> void:
	var ratio: float = _speed_ratio()
	var right: Vector3 = Vector3.UP.cross(chase_forward).normalized()
	var look_ahead: float = lerpf(low_speed_look_ahead, high_speed_look_ahead, ratio)
	var look_position: Vector3 = anchor + chase_forward * look_ahead + Vector3.UP * look_height
	look_position += right * _effective_steer(ratio) * corner_look_offset

	_update_screen_composition(anchor, delta)
	look_position += Vector3.UP * _composition_vertical_offset

	if delta <= 0.0:
		look_at(look_position, Vector3.UP)
	else:
		var current_basis: Basis = global_transform.basis
		look_at(look_position, Vector3.UP)
		var target_basis: Basis = global_transform.basis
		var rotation_weight: float = 1.0 - exp(-rotation_smoothing * delta)
		global_transform.basis = current_basis.slerp(target_basis, rotation_weight).orthonormalized()

	var steer: float = _effective_steer(ratio)
	var drift_intensity: float = _drift_intensity()
	var roll_strength: float = roll_degrees + drift_roll_bonus_degrees * drift_intensity
	var target_roll: float = deg_to_rad(-steer * roll_strength)
	var roll_weight: float = 1.0
	if delta > 0.0:
		roll_weight = 1.0 - exp(-roll_smoothing * delta)
	_current_roll = lerp_angle(_current_roll, target_roll, roll_weight)
	rotate_object_local(Vector3(0.0, 0.0, 1.0), _current_roll)


func _refresh_target_marker() -> void:
	if _target == null:
		_target_marker = null
		return
	if _target_marker != null and is_instance_valid(_target_marker):
		return
	_target_marker = _target.get_node_or_null(String(target_marker_name)) as Node3D


func _anchor_position() -> Vector3:
	if _target_marker != null and is_instance_valid(_target_marker):
		return _target_marker.global_position
	return _target.global_position


func _update_estimated_velocity(anchor: Vector3, delta: float) -> void:
	if delta <= 0.0:
		_estimated_velocity = Vector3.ZERO
		return
	_estimated_velocity = (anchor - _last_anchor_position) / delta


func _speed_ratio() -> float:
	if _target == null or not _target.has_method("get_speed_ratio"):
		return 0.0
	return float(_target.call("get_speed_ratio"))


func _effective_steer(speed_ratio: float) -> float:
	if _target == null:
		return 0.0
	if _target.has_method("get_effective_steer_amount"):
		return clampf(float(_target.call("get_effective_steer_amount")), -1.0, 1.0)
	if _target.has_method("get_effective_steering"):
		return clampf(float(_target.call("get_effective_steering")), -1.0, 1.0)
	if _target.has_method("get_effective_steer"):
		return clampf(float(_target.call("get_effective_steer")), -1.0, 1.0)
	if _target_has_property(&"effective_steer_amount"):
		return clampf(float(_target.get("effective_steer_amount")), -1.0, 1.0)
	if _target_has_property(&"effective_steering"):
		return clampf(float(_target.get("effective_steering")), -1.0, 1.0)
	if _target_has_property(&"effective_steer"):
		return clampf(float(_target.get("effective_steer")), -1.0, 1.0)

	if _target_has_property(&"steer_amount"):
		var raw_steer: float = float(_target.get("steer_amount"))
		return clampf(raw_steer * _raw_steer_roll_factor(speed_ratio), -1.0, 1.0)
	return 0.0


func _drift_intensity() -> float:
	if _target == null:
		return 0.0
	if _target.has_method("get_drift_intensity"):
		return clampf(float(_target.call("get_drift_intensity")), 0.0, 1.0)
	if _target.has_method("get_effective_drift_intensity"):
		return clampf(float(_target.call("get_effective_drift_intensity")), 0.0, 1.0)
	if _target.has_method("get_effective_drift"):
		return clampf(float(_target.call("get_effective_drift")), 0.0, 1.0)
	if _target_has_property(&"drift_intensity"):
		return clampf(float(_target.get("drift_intensity")), 0.0, 1.0)
	if _target_has_property(&"effective_drift_intensity"):
		return clampf(float(_target.get("effective_drift_intensity")), 0.0, 1.0)
	if _target_has_property(&"effective_drift"):
		return clampf(float(_target.get("effective_drift")), 0.0, 1.0)
	if _target_has_property(&"is_drifting"):
		return 1.0 if bool(_target.get("is_drifting")) else 0.0
	return 0.0


func _raw_steer_roll_factor(speed_ratio: float) -> float:
	var normalized: float = clampf((speed_ratio - 0.02) / 0.14, 0.0, 1.0)
	return normalized * normalized * (3.0 - 2.0 * normalized)


func _target_has_property(property_name: StringName) -> bool:
	if _target == null:
		return false
	for property: Dictionary in _target.get_property_list():
		if String(property.get("name", "")) == String(property_name):
			return true
	return false


func _chase_forward(speed_ratio: float) -> Vector3:
	var forward: Vector3 = _flat_target_forward()
	var velocity_direction: Vector3 = _flat_target_velocity()
	if velocity_direction.length_squared() <= 0.0001 or velocity_direction.dot(forward) < -0.2:
		return forward

	var velocity_bias: float = lerpf(grip_velocity_bias, drift_velocity_bias, _drift_intensity())
	velocity_bias *= smoothstep(0.08, 0.35, speed_ratio)
	var blended: Vector3 = forward.lerp(velocity_direction, velocity_bias)
	blended.y = 0.0
	if blended.length_squared() <= 0.0001:
		return forward
	return blended.normalized()


func _flat_target_forward() -> Vector3:
	var forward: Vector3 = -_target.global_transform.basis.z
	forward.y = 0.0
	return forward.normalized()


func _flat_target_velocity() -> Vector3:
	var target_velocity: Vector3 = _estimated_velocity
	if _target is CharacterBody3D:
		var body := _target as CharacterBody3D
		target_velocity = body.velocity
	target_velocity.y = 0.0
	if target_velocity.length_squared() <= 0.0001:
		return Vector3.ZERO
	return target_velocity.normalized()


func _update_screen_composition(anchor: Vector3, delta: float) -> void:
	if delta <= 0.0 or is_position_behind(anchor):
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.y <= 1.0:
		return

	var screen_position: Vector2 = unproject_position(anchor)
	var current_y: float = clampf(screen_position.y / viewport_size.y, 0.0, 1.0)
	var error: float = target_screen_y - current_y
	var target_offset: float = clampf(
		_composition_vertical_offset + error * screen_y_correction,
		-max_screen_vertical_correction,
		max_screen_vertical_correction
	)
	var weight: float = 1.0 - exp(-composition_smoothing * delta)
	_composition_vertical_offset = lerpf(_composition_vertical_offset, target_offset, weight)
