class_name ArcadeCarController
extends CharacterBody3D

const VehicleCommandScript := preload("res://scripts/vehicles/vehicle_command.gd")
const PlayerDriverScript := preload("res://scripts/vehicles/player_driver.gd")

signal drift_started(intensity: float)
signal drift_ended
signal drift_intensity_changed(intensity: float)
signal wall_scraped(intensity: float, contact_position: Vector3, contact_normal: Vector3)
signal vehicle_bumped(intensity: float, contact_position: Vector3, contact_normal: Vector3)

@export_category("Speed")
@export var max_speed: float = 92.0
@export var reverse_speed: float = 18.0
@export var acceleration: float = 42.0
@export var reverse_acceleration: float = 24.0
@export var brake_force: float = 70.0
@export var rolling_drag: float = 18.0

@export_category("Handling")
@export var low_speed_turn_rate: float = 1.8
@export var high_speed_turn_rate: float = 0.95
@export var min_steer_speed: float = 2.0
@export var reverse_turn_multiplier: float = 0.72
@export var normal_lateral_grip: float = 58.0
@export var ground_stick_force: float = 4.0
@export var gravity: float = 28.0

@export_category("Rear-Wheel Drive")
@export var rear_drive_turn_assist: float = 0.28
@export var rear_drive_power_oversteer: float = 4.0

@export_category("Drift")
@export var drift_min_speed: float = 12.0
@export var drift_lateral_grip: float = 14.0
@export var drift_side_slip: float = 11.0
@export var drift_turn_multiplier: float = 1.45
@export var drift_steering_gain: float = 0.75

@export_category("Visual Feel")
@export var body_roll_degrees: float = 7.5
@export var drift_roll_degrees: float = 10.0
@export var pitch_degrees: float = 3.5
@export var wheel_spin_multiplier: float = 2.8
@export var front_wheel_steer_degrees: float = 28.0
@export_enum("blue", "red", "green", "yellow") var car_color_variant: String = "blue"

@export_category("Imported Model Material")
@export var apply_imported_model_material_override: bool = true
@export_file("*.png", "*.jpg", "*.jpeg", "*.webp") var imported_model_albedo_texture_path: String = "res://assets/cars/player_hypercar_red_metallic_studio_texture.png"
@export_file("*.png", "*.jpg", "*.jpeg", "*.webp") var imported_model_normal_texture_path: String = "res://assets/cars/player_hypercar_normal.png"
@export var imported_model_albedo_tint: Color = Color(1.0, 1.0, 1.0, 1.0)
@export_range(0.0, 1.0, 0.01) var imported_model_metallic: float = 0.72
@export_range(0.02, 1.0, 0.01) var imported_model_roughness: float = 0.22

@export_category("Command Source")
@export var driver_path: NodePath = NodePath("")
@export var use_default_player_driver: bool = true
@export var controls_enabled: bool = true

@onready var visual_root: Node3D = get_node_or_null("VisualRoot")
@onready var wheel_nodes: Array[Node3D] = [
	_find_first_node3d([
		"VisualRoot/SteeringPivotFL/WheelFL",
		"VisualRoot/WheelPivotFL/WheelFL",
		"VisualRoot/WheelFLPivot/WheelFL",
		"VisualRoot/FrontLeftSteeringPivot/WheelFL",
		"VisualRoot/FrontLeftWheelPivot/WheelFL",
		"VisualRoot/WheelFL/WheelMesh",
		"VisualRoot/WheelFL",
	]),
	_find_first_node3d([
		"VisualRoot/SteeringPivotFR/WheelFR",
		"VisualRoot/WheelPivotFR/WheelFR",
		"VisualRoot/WheelFRPivot/WheelFR",
		"VisualRoot/FrontRightSteeringPivot/WheelFR",
		"VisualRoot/FrontRightWheelPivot/WheelFR",
		"VisualRoot/WheelFR/WheelMesh",
		"VisualRoot/WheelFR",
	]),
	_find_first_node3d([
		"VisualRoot/WheelRL/WheelMesh",
		"VisualRoot/WheelRL",
		"VisualRoot/RearLeftWheel",
	]),
	_find_first_node3d([
		"VisualRoot/WheelRR/WheelMesh",
		"VisualRoot/WheelRR",
		"VisualRoot/RearRightWheel",
	]),
]
@onready var front_wheel_steering_nodes: Array[Node3D] = [
	_find_first_node3d([
		"VisualRoot/SteeringPivotFL",
		"VisualRoot/WheelPivotFL",
		"VisualRoot/WheelFLPivot",
		"VisualRoot/FrontLeftSteeringPivot",
		"VisualRoot/FrontLeftWheelPivot",
		"VisualRoot/WheelFL",
	]),
	_find_first_node3d([
		"VisualRoot/SteeringPivotFR",
		"VisualRoot/WheelPivotFR",
		"VisualRoot/FrontRightSteeringPivot",
		"VisualRoot/FrontRightWheelPivot",
		"VisualRoot/WheelFR",
	]),
]

var steering_input: float = 0.0
var steer_amount: float = 0.0
var effective_steer_amount: float = 0.0
var throttle_amount: float = 0.0
var brake_amount: float = 0.0
var is_drifting: bool = false
var drift_intensity: float = 0.0
var vehicle_command: RefCounted = VehicleCommandScript.new()

var _driver_node: Node = null
var _drift_input_active: bool = false
var _forward_speed: float = 0.0
var _side_speed: float = 0.0
var _wheel_spin: float = 0.0
var _front_wheel_rest_y: Array[float] = []
var _fallback_player_driver: Node = null
var _was_drifting: bool = false
var _last_reported_drift_intensity: float = 0.0
var _wall_scrape_cooldown: float = 0.0
var _vehicle_bump_cooldown: float = 0.0


func _ready() -> void:
	_resolve_driver()
	_apply_car_color_variant()
	_apply_imported_model_material_override()
	_front_wheel_rest_y.clear()
	for steering_node: Node3D in front_wheel_steering_nodes:
		var rest_y: float = 0.0
		if steering_node != null:
			rest_y = steering_node.rotation.y
		_front_wheel_rest_y.append(rest_y)


func _exit_tree() -> void:
	if _fallback_player_driver != null:
		_fallback_player_driver.free()
		_fallback_player_driver = null


func _physics_process(delta: float) -> void:
	if not _is_finite_float(delta) or delta <= 0.0:
		return
	_sanitize_physics_state()
	var previous_planar_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	_wall_scrape_cooldown = maxf(0.0, _wall_scrape_cooldown - delta)
	_vehicle_bump_cooldown = maxf(0.0, _vehicle_bump_cooldown - delta)
	_read_command()
	_update_planar_velocity(delta)
	_update_visuals(delta)
	move_and_slide()
	_emit_drift_feedback()
	_emit_collision_feedback(previous_planar_velocity)


func get_speed() -> float:
	var planar_velocity := Vector3(velocity.x, 0.0, velocity.z)
	if not planar_velocity.is_finite():
		return 0.0
	return planar_velocity.length()


func get_speed_ratio() -> float:
	if not _is_finite_float(max_speed) or max_speed <= 0.0:
		return 0.0
	return clampf(get_speed() / max_speed, 0.0, 1.0)


func get_forward_speed() -> float:
	return _forward_speed if _is_finite_float(_forward_speed) else 0.0


func get_effective_steering() -> float:
	return effective_steer_amount if _is_finite_float(effective_steer_amount) else 0.0


func get_effective_steer_amount() -> float:
	return effective_steer_amount if _is_finite_float(effective_steer_amount) else 0.0


func get_drift_intensity() -> float:
	return drift_intensity if _is_finite_float(drift_intensity) else 0.0


func set_vehicle_command(next_command: RefCounted) -> void:
	vehicle_command.copy_from(next_command)
	_sync_command_state()


func get_vehicle_command() -> RefCounted:
	return vehicle_command.duplicate_command()


func set_controls_enabled(enabled: bool) -> void:
	controls_enabled = enabled
	if not controls_enabled:
		vehicle_command.clear()
		_sync_command_state()


func set_car_color_variant(variant_id: String) -> void:
	car_color_variant = variant_id
	_apply_car_color_variant()


func _resolve_driver() -> void:
	_driver_node = null
	if not String(driver_path).is_empty():
		_driver_node = get_node_or_null(driver_path)


func _read_command() -> void:
	if not controls_enabled:
		vehicle_command.clear()
		_sync_command_state()
		return

	var command_written: bool = false
	if _driver_node == null and not String(driver_path).is_empty():
		_resolve_driver()

	if _driver_node != null:
		if _driver_node.has_method("write_command"):
			_driver_node.call("write_command", vehicle_command)
			command_written = true
		elif _driver_node.has_method("get_command"):
			var next_command: Variant = _driver_node.call("get_command")
			if next_command is RefCounted and next_command.has_method("copy_from"):
				vehicle_command.copy_from(next_command as RefCounted)
				command_written = true

	if not command_written:
		if use_default_player_driver:
			if _fallback_player_driver == null:
				_fallback_player_driver = PlayerDriverScript.new()
			_fallback_player_driver.write_command(vehicle_command)
		else:
			vehicle_command.clear()

	_sync_command_state()


func _sync_command_state() -> void:
	throttle_amount = clampf(_finite_or(vehicle_command.throttle, 0.0), 0.0, 1.0)
	brake_amount = clampf(_finite_or(vehicle_command.brake, 0.0), 0.0, 1.0)
	steering_input = clampf(_finite_or(vehicle_command.steer, 0.0), -1.0, 1.0)
	_drift_input_active = vehicle_command.drift


func _update_planar_velocity(delta: float) -> void:
	var forward: Vector3 = _flat_forward()
	var right: Vector3 = _flat_right()
	var vertical_speed: float = _finite_or(velocity.y, 0.0)

	_forward_speed = velocity.dot(forward)
	_side_speed = velocity.dot(right)
	_forward_speed = _finite_or(_forward_speed, 0.0)
	_side_speed = _finite_or(_side_speed, 0.0)

	var safe_max_speed: float = maxf(_finite_or(max_speed, 1.0), 1.0)
	var speed_ratio: float = clampf(absf(_forward_speed) / safe_max_speed, 0.0, 1.0)
	var forward_speed_ratio: float = clampf(_forward_speed / safe_max_speed, 0.0, 1.0)
	var can_steer: bool = absf(_forward_speed) >= min_steer_speed
	effective_steer_amount = steering_input if can_steer else 0.0
	steer_amount = effective_steer_amount

	is_drifting = _drift_input_active and _forward_speed >= drift_min_speed
	if is_drifting:
		var drift_speed_range: float = maxf(max_speed - drift_min_speed, 1.0)
		var drift_speed_ratio: float = clampf((_forward_speed - drift_min_speed) / drift_speed_range, 0.0, 1.0)
		var steering_bonus: float = clampf(0.45 + absf(effective_steer_amount) * drift_steering_gain, 0.0, 1.0)
		drift_intensity = drift_speed_ratio * steering_bonus
	else:
		drift_intensity = 0.0

	var turn_rate: float = lerpf(low_speed_turn_rate, high_speed_turn_rate, speed_ratio)
	if is_drifting:
		turn_rate *= drift_turn_multiplier * (1.0 + absf(effective_steer_amount) * drift_steering_gain)
	else:
		turn_rate *= 1.0 + throttle_amount * rear_drive_turn_assist * forward_speed_ratio

	var driving_direction: float = signf(_forward_speed)
	if not can_steer:
		driving_direction = 0.0
	var reverse_steer_scale: float = reverse_turn_multiplier if driving_direction < 0.0 else 1.0
	rotate_y(-effective_steer_amount * turn_rate * driving_direction * reverse_steer_scale * delta)

	forward = _flat_forward()
	right = _flat_right()

	if throttle_amount > 0.0:
		_forward_speed = move_toward(_forward_speed, max_speed, acceleration * throttle_amount * delta)
	elif brake_amount > 0.0:
		if _forward_speed > 2.0:
			_forward_speed = move_toward(_forward_speed, 0.0, brake_force * brake_amount * delta)
		else:
			_forward_speed = move_toward(_forward_speed, -reverse_speed, reverse_acceleration * brake_amount * delta)
	else:
		_forward_speed = move_toward(_forward_speed, 0.0, rolling_drag * delta)

	var target_side_speed: float = 0.0
	var grip: float = normal_lateral_grip
	if is_drifting:
		grip = drift_lateral_grip
		target_side_speed = -effective_steer_amount * drift_side_slip * (0.35 + drift_intensity)
	elif throttle_amount > 0.0:
		target_side_speed = -effective_steer_amount * rear_drive_power_oversteer * throttle_amount * speed_ratio
	_side_speed = move_toward(_side_speed, target_side_speed, grip * delta)

	if is_on_floor():
		vertical_speed = -ground_stick_force
	else:
		vertical_speed -= gravity * delta

	velocity = forward * _forward_speed + right * _side_speed
	velocity.y = vertical_speed
	if not velocity.is_finite():
		velocity = Vector3.ZERO


func _update_visuals(delta: float) -> void:
	if visual_root != null:
		var roll_strength: float = lerpf(body_roll_degrees, drift_roll_degrees, drift_intensity)
		var target_roll: float = deg_to_rad(-effective_steer_amount * roll_strength)
		var target_pitch: float = deg_to_rad(-throttle_amount * pitch_degrees + brake_amount * pitch_degrees)
		visual_root.rotation.z = lerp_angle(visual_root.rotation.z, target_roll, 1.0 - exp(-10.0 * delta))
		visual_root.rotation.x = lerp_angle(visual_root.rotation.x, target_pitch, 1.0 - exp(-8.0 * delta))

	var target_front_wheel_yaw: float = deg_to_rad(effective_steer_amount * front_wheel_steer_degrees)
	var wheel_steer_weight: float = 1.0 - exp(-14.0 * delta)
	for i: int in range(front_wheel_steering_nodes.size()):
		var steering_node: Node3D = front_wheel_steering_nodes[i]
		if steering_node != null:
			var rest_y: float = 0.0
			if i < _front_wheel_rest_y.size():
				rest_y = _front_wheel_rest_y[i]
			steering_node.rotation.y = lerp_angle(steering_node.rotation.y, rest_y + target_front_wheel_yaw, wheel_steer_weight)

	_wheel_spin += _forward_speed * wheel_spin_multiplier * delta
	for wheel: Node3D in wheel_nodes:
		if wheel != null:
			wheel.rotation.x = _wheel_spin


func _apply_car_color_variant() -> void:
	if visual_root == null:
		return
	var colors: Dictionary = _variant_colors(car_color_variant)
	var primary: Color = colors["primary"]
	var accent: Color = colors["accent"]
	var dark: Color = colors["dark"]

	_apply_mesh_color("VisualRoot/Body", primary, 0.42)
	_apply_mesh_color("VisualRoot/SidePodL", primary, 0.42)
	_apply_mesh_color("VisualRoot/SidePodR", primary, 0.42)
	_apply_mesh_color("VisualRoot/NoseCone", accent, 0.35)
	_apply_mesh_color("VisualRoot/RearWing", accent, 0.35)
	_apply_mesh_color("VisualRoot/CenterFin", accent, 0.35)
	_apply_mesh_color("VisualRoot/Cabin", dark, 0.18)
	_apply_mesh_color("VisualRoot/FrontSplitter", dark, 0.28)
	_apply_mesh_color("VisualRoot/RearWingPostL", dark, 0.28)
	_apply_mesh_color("VisualRoot/RearWingPostR", dark, 0.28)


func _variant_colors(variant_id: String) -> Dictionary:
	match variant_id.to_lower():
		"red":
			return {
				"primary": Color(0.94, 0.12, 0.08, 1.0),
				"accent": Color(1.0, 0.78, 0.12, 1.0),
				"dark": Color(0.06, 0.055, 0.075, 1.0),
			}
		"green":
			return {
				"primary": Color(0.08, 0.74, 0.32, 1.0),
				"accent": Color(0.95, 0.96, 0.18, 1.0),
				"dark": Color(0.035, 0.07, 0.055, 1.0),
			}
		"yellow":
			return {
				"primary": Color(1.0, 0.82, 0.08, 1.0),
				"accent": Color(0.18, 0.42, 0.95, 1.0),
				"dark": Color(0.07, 0.06, 0.04, 1.0),
			}
		_:
			return {
				"primary": Color(0.08, 0.24, 0.9, 1.0),
				"accent": Color(1.0, 0.12, 0.08, 1.0),
				"dark": Color(0.05, 0.07, 0.09, 1.0),
			}


func _apply_mesh_color(path: String, color: Color, roughness: float) -> void:
	var mesh_node: MeshInstance3D = get_node_or_null(path) as MeshInstance3D
	if mesh_node == null:
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	mesh_node.material_override = material


func _apply_imported_model_material_override() -> void:
	if not apply_imported_model_material_override:
		return
	var model_mount: Node = get_node_or_null("VisualRoot/ModelMount")
	if model_mount == null:
		return

	var material := StandardMaterial3D.new()
	material.resource_name = "RedMetallicImportedCarMaterial"
	material.albedo_color = imported_model_albedo_tint
	material.metallic = imported_model_metallic
	material.roughness = imported_model_roughness

	var albedo_texture: Texture2D = _load_texture(imported_model_albedo_texture_path)
	if albedo_texture != null:
		material.albedo_texture = albedo_texture

	var normal_texture: Texture2D = _load_texture(imported_model_normal_texture_path)
	if normal_texture != null:
		material.normal_enabled = true
		material.normal_texture = normal_texture

	for mesh_instance: MeshInstance3D in _collect_mesh_instances(model_mount):
		mesh_instance.material_override = material.duplicate()


func _collect_mesh_instances(root: Node) -> Array[MeshInstance3D]:
	var mesh_instances: Array[MeshInstance3D] = []
	for child: Node in root.get_children():
		if child is MeshInstance3D:
			mesh_instances.append(child as MeshInstance3D)
		mesh_instances.append_array(_collect_mesh_instances(child))
	return mesh_instances


func _load_texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path) as Texture2D


func _emit_drift_feedback() -> void:
	if is_drifting and not _was_drifting:
		drift_started.emit(drift_intensity)
	elif not is_drifting and _was_drifting:
		drift_ended.emit()

	if absf(drift_intensity - _last_reported_drift_intensity) >= 0.04:
		drift_intensity_changed.emit(drift_intensity)
		_last_reported_drift_intensity = drift_intensity
	_was_drifting = is_drifting


func _emit_collision_feedback(previous_planar_velocity: Vector3) -> void:
	var impact_speed: float = previous_planar_velocity.length()
	if impact_speed < 4.0:
		return

	for collision_index: int in range(get_slide_collision_count()):
		var collision: KinematicCollision3D = get_slide_collision(collision_index)
		if collision == null:
			continue
		var collider: Object = collision.get_collider()
		var contact_normal: Vector3 = collision.get_normal()
		var normal_impact: float = maxf(0.0, -previous_planar_velocity.dot(contact_normal))
		var side_impact: float = absf(_side_speed)
		var intensity: float = clampf((normal_impact + side_impact * 0.65) / 34.0, 0.08, 1.0)
		var contact_position: Vector3 = collision.get_position()

		if _is_vehicle_collider(collider):
			if _vehicle_bump_cooldown <= 0.0:
				vehicle_bumped.emit(intensity, contact_position, contact_normal)
				_vehicle_bump_cooldown = 0.24
		elif _is_guardrail_collider(collider):
			if _wall_scrape_cooldown <= 0.0:
				wall_scraped.emit(intensity, contact_position, contact_normal)
				_wall_scrape_cooldown = 0.12


func _is_vehicle_collider(collider: Object) -> bool:
	if collider == null:
		return false
	if collider is ArcadeCarController:
		return true
	if collider is CharacterBody3D:
		var collider_name: String = String((collider as Node).name).to_lower()
		return collider_name.contains("car")
	return false


func _is_guardrail_collider(collider: Object) -> bool:
	if collider == null or not (collider is Node):
		return false
	var node: Node = collider as Node
	while node != null:
		var node_name: String = String(node.name).to_lower()
		if node_name.contains("guardrail"):
			return true
		node = node.get_parent()
	return false


func _find_first_node3d(paths: Array[String]) -> Node3D:
	for path: String in paths:
		var node: Node = get_node_or_null(path)
		if node is Node3D:
			return node as Node3D
	return null


func _flat_forward() -> Vector3:
	var forward: Vector3 = -global_transform.basis.z
	forward.y = 0.0
	if not forward.is_finite() or forward.length_squared() <= 0.0001:
		return Vector3(0.0, 0.0, -1.0)
	return forward.normalized()


func _flat_right() -> Vector3:
	var right: Vector3 = global_transform.basis.x
	right.y = 0.0
	if not right.is_finite() or right.length_squared() <= 0.0001:
		return Vector3.RIGHT
	return right.normalized()


func _sanitize_physics_state() -> void:
	if not velocity.is_finite():
		velocity = Vector3.ZERO
		_forward_speed = 0.0
		_side_speed = 0.0

	var current_basis: Basis = global_transform.basis
	if not current_basis.x.is_finite() or not current_basis.y.is_finite() or not current_basis.z.is_finite() \
			or current_basis.x.length_squared() <= 0.0001 \
			or current_basis.y.length_squared() <= 0.0001 \
			or current_basis.z.length_squared() <= 0.0001:
		var safe_origin: Vector3 = global_transform.origin if global_transform.origin.is_finite() else Vector3.ZERO
		global_transform = Transform3D(Basis.IDENTITY, safe_origin)
		velocity = Vector3.ZERO
		_forward_speed = 0.0
		_side_speed = 0.0
		return

	global_transform.basis = current_basis.orthonormalized()


func _is_finite_float(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)


func _finite_or(value: float, fallback: float) -> float:
	if is_nan(value) or is_inf(value):
		return fallback
	return value
