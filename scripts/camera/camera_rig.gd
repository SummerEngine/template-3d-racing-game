class_name CameraRig
extends Node3D

const CameraViewProfileScript := preload("res://scripts/camera/camera_view_profile.gd")

const VIEW_ROLE_PRIMARY := 0
const VIEW_ROLE_TEMPORARY_OVERRIDE := 1
const ROLL_MODE_NONE := 0
const ROLL_MODE_STEER_BIAS := 1
const ROLL_MODE_MATCH_TARGET_UP := 2
const ROLL_MODE_MATCH_TRACK_UP := 3
const COLLISION_MODE_DISABLED := 0

signal primary_view_changed(view_id: StringName)
signal effective_view_changed(view_id: StringName, temporary: bool)

@export_category("Target")
@export var target_path: NodePath
@export var target_marker_name: StringName = &"CameraTarget"
@export var camera_path: NodePath = NodePath("Camera3D")
@export var track_query_provider_path: NodePath
@export var orientation_provider_path: NodePath

@export_category("Input Actions")
@export var input_enabled: bool = true
@export var camera_toggle_primary_action: StringName = &"camera_toggle_primary"
@export var camera_look_back_action: StringName = &"camera_look_back"

@export_category("View Profiles")
@export var chase_profile: Resource = null
@export var cockpit_profile: Resource = null
@export var look_back_profile: Resource = null
@export var default_primary_view_id: StringName = &"chase"

@export_category("Runtime Camera")
@export var make_camera_current_on_ready: bool = true
@export var create_camera_if_missing: bool = true
@export var created_camera_name: String = "ViewCamera"

var _camera: Camera3D = null
var _target: Node3D = null
var _target_marker: Node3D = null
var _track_query_provider: Object = null
var _orientation_provider: Object = null
var _primary_view_id: StringName = &"chase"
var _look_back_active: bool = false
var _last_effective_view_id: StringName = &""
var _current_roll: float = 0.0
var _last_anchor_position: Vector3 = Vector3.ZERO
var _estimated_velocity: Vector3 = Vector3.ZERO


func _ready() -> void:
	_ensure_default_profiles()
	_primary_view_id = default_primary_view_id
	_resolve_references()

	if _camera != null and make_camera_current_on_ready:
		_camera.make_current()

	if _target != null and _camera != null:
		_snap_to_profile(_effective_profile())


func _process(delta: float) -> void:
	_resolve_references()
	_handle_input()
	_update_camera(delta)


func set_target(target: Node3D) -> void:
	_target = target
	_target_marker = null
	if _target != null:
		_last_anchor_position = _anchor_position()


func set_primary_view_id(view_id: StringName) -> void:
	if _profile_for_id(view_id) == null:
		return
	if _primary_view_id == view_id:
		return

	_primary_view_id = view_id
	primary_view_changed.emit(_primary_view_id)
	_emit_effective_view_if_changed()


func get_primary_view_id() -> StringName:
	return _primary_view_id


func get_effective_view_id() -> StringName:
	return _profile_view_id(_effective_profile())


func is_look_back_active() -> bool:
	return _look_back_active


func toggle_primary_view() -> void:
	_ensure_default_profiles()
	var chase_id: StringName = _profile_view_id(chase_profile, &"chase")
	var cockpit_id: StringName = _profile_view_id(cockpit_profile, &"cockpit")
	if _primary_view_id == chase_id:
		set_primary_view_id(cockpit_id)
	else:
		set_primary_view_id(chase_id)


func get_profile(view_id: StringName) -> Resource:
	return _profile_for_id(view_id)


func _ensure_default_profiles() -> void:
	if chase_profile == null:
		chase_profile = _create_chase_profile()
	if cockpit_profile == null:
		cockpit_profile = _create_cockpit_placeholder_profile()
	if look_back_profile == null:
		look_back_profile = _create_look_back_profile()


func _create_chase_profile() -> Resource:
	var profile: Resource = CameraViewProfileScript.new()
	profile.set("view_id", &"chase")
	profile.set("display_name", "Chase")
	profile.set("view_role", VIEW_ROLE_PRIMARY)
	profile.set("camera_offset_local", Vector3(0.0, 3.8, 10.5))
	profile.set("view_yaw_degrees", 0.0)
	profile.set("fov_degrees", 67.0)
	profile.set("high_speed_fov_degrees", 82.0)
	profile.set("position_damping", 11.0)
	profile.set("rotation_damping", 13.0)
	profile.set("roll_mode", ROLL_MODE_STEER_BIAS)
	profile.set("roll_degrees", 3.5)
	profile.set("drift_roll_bonus_degrees", 2.0)
	profile.set("preview_distance_low_speed_m", 7.5)
	profile.set("preview_distance_high_speed_m", 17.0)
	profile.set("preview_height_m", 1.4)
	profile.set("corner_preview_lateral_m", 2.0)
	profile.set("velocity_preview_bias", 0.25)
	return profile


func _create_cockpit_placeholder_profile() -> Resource:
	var profile: Resource = CameraViewProfileScript.new()
	profile.set("view_id", &"cockpit")
	profile.set("display_name", "Cockpit Placeholder")
	profile.set("view_role", VIEW_ROLE_PRIMARY)
	profile.set("anchor_offset_local", Vector3(0.0, 0.25, 0.0))
	profile.set("camera_offset_local", Vector3(0.0, 0.15, -0.65))
	profile.set("view_yaw_degrees", 0.0)
	profile.set("fov_degrees", 74.0)
	profile.set("high_speed_fov_degrees", 82.0)
	profile.set("position_damping", 24.0)
	profile.set("rotation_damping", 20.0)
	profile.set("roll_mode", ROLL_MODE_MATCH_TARGET_UP)
	profile.set("roll_degrees", 0.0)
	profile.set("preview_distance_low_speed_m", 10.0)
	profile.set("preview_distance_high_speed_m", 24.0)
	profile.set("preview_height_m", 0.35)
	profile.set("corner_preview_lateral_m", 1.1)
	profile.set("velocity_preview_bias", 0.12)
	profile.set("collision_mode", COLLISION_MODE_DISABLED)
	return profile


func _create_look_back_profile() -> Resource:
	var profile: Resource = CameraViewProfileScript.new()
	profile.set("view_id", &"look_back")
	profile.set("display_name", "Look Back")
	profile.set("view_role", VIEW_ROLE_TEMPORARY_OVERRIDE)
	profile.set("camera_offset_local", Vector3(0.0, 3.0, -7.0))
	profile.set("view_yaw_degrees", 180.0)
	profile.set("fov_degrees", 72.0)
	profile.set("high_speed_fov_degrees", 78.0)
	profile.set("position_damping", 18.0)
	profile.set("rotation_damping", 18.0)
	profile.set("roll_mode", ROLL_MODE_MATCH_TARGET_UP)
	profile.set("roll_degrees", 0.0)
	profile.set("preview_distance_low_speed_m", 8.0)
	profile.set("preview_distance_high_speed_m", 13.0)
	profile.set("preview_height_m", 1.0)
	profile.set("corner_preview_lateral_m", 0.0)
	profile.set("velocity_preview_bias", 0.0)
	return profile


func _resolve_references() -> void:
	if _target == null and not String(target_path).is_empty():
		_target = get_node_or_null(target_path) as Node3D

	_ensure_camera()

	if _track_query_provider == null and not String(track_query_provider_path).is_empty():
		_track_query_provider = get_node_or_null(track_query_provider_path)

	if _orientation_provider == null and not String(orientation_provider_path).is_empty():
		_orientation_provider = get_node_or_null(orientation_provider_path)


func _ensure_camera() -> void:
	if _camera != null and is_instance_valid(_camera):
		return

	_camera = null
	if not String(camera_path).is_empty():
		_camera = get_node_or_null(camera_path) as Camera3D

	if _camera == null:
		for child: Node in get_children():
			if child is Camera3D:
				_camera = child as Camera3D
				break

	if _camera == null and create_camera_if_missing:
		_camera = Camera3D.new()
		_camera.name = created_camera_name
		add_child(_camera)


func _handle_input() -> void:
	if not input_enabled:
		_set_look_back_active(false)
		return

	if _is_action_just_pressed(camera_toggle_primary_action):
		toggle_primary_view()

	_set_look_back_active(_is_action_pressed(camera_look_back_action))


func _set_look_back_active(active: bool) -> void:
	if _look_back_active == active:
		return
	_look_back_active = active
	_emit_effective_view_if_changed()


func _update_camera(delta: float) -> void:
	if _camera == null or _target == null:
		return

	_refresh_target_marker()

	var profile: Resource = _effective_profile()
	if profile == null:
		return

	var anchor: Vector3 = _anchor_position()
	_update_estimated_velocity(anchor, delta)

	var frame_basis: Basis = _camera_frame_basis(anchor, profile)
	var desired_position: Vector3 = _desired_camera_position(anchor, frame_basis, profile)
	desired_position = _apply_collision(anchor, desired_position, profile)

	var next_position: Vector3 = _smoothed_position(
			_camera.global_position,
			desired_position,
			_profile_float(profile, &"position_damping", 11.0),
			delta
	)
	var max_follow_lag_m: float = _profile_float(profile, &"max_follow_lag_m", 4.0)
	if max_follow_lag_m > 0.0:
		var lag: Vector3 = next_position - desired_position
		if lag.length() > max_follow_lag_m:
			next_position = desired_position + lag.normalized() * max_follow_lag_m

	var look_position: Vector3 = _desired_look_position(anchor, frame_basis, profile)
	var desired_basis: Basis = _look_basis(next_position, look_position, _up_for_profile(frame_basis, profile))
	desired_basis = _with_profile_roll(desired_basis, profile, delta)

	var next_basis: Basis = desired_basis
	if delta > 0.0:
		var rotation_damping: float = _profile_float(profile, &"rotation_damping", 13.0)
		var rotation_weight: float = _exp_weight(rotation_damping, delta)
		next_basis = _camera.global_transform.basis.slerp(desired_basis, rotation_weight).orthonormalized()

	_camera.global_transform = Transform3D(next_basis, next_position)

	var target_fov: float = _profile_target_fov(profile, _speed_ratio())
	if delta <= 0.0:
		_camera.fov = target_fov
	else:
		var fov_damping: float = _profile_float(profile, &"fov_damping", 4.0)
		_camera.fov = lerpf(_camera.fov, target_fov, _exp_weight(fov_damping, delta))

	_last_anchor_position = anchor
	_emit_effective_view_if_changed()


func _snap_to_profile(profile: Resource) -> void:
	if profile == null or _camera == null or _target == null:
		return

	_refresh_target_marker()
	var anchor: Vector3 = _anchor_position()
	_last_anchor_position = anchor
	var frame_basis: Basis = _camera_frame_basis(anchor, profile)
	var desired_position: Vector3 = _desired_camera_position(anchor, frame_basis, profile)
	var look_position: Vector3 = _desired_look_position(anchor, frame_basis, profile)
	var desired_basis: Basis = _look_basis(desired_position, look_position, _up_for_profile(frame_basis, profile))
	_current_roll = 0.0
	_camera.global_transform = Transform3D(desired_basis, desired_position)
	_camera.fov = _profile_target_fov(profile, _speed_ratio())
	_emit_effective_view_if_changed()


func _effective_profile() -> Resource:
	if _look_back_active and look_back_profile != null:
		return look_back_profile

	var profile: Resource = _profile_for_id(_primary_view_id)
	if profile != null:
		return profile
	return chase_profile


func _profile_for_id(view_id: StringName) -> Resource:
	_ensure_default_profiles()
	for profile: Resource in [chase_profile, cockpit_profile, look_back_profile]:
		if profile != null and _profile_view_id(profile) == view_id:
			return profile
	return null


func _desired_camera_position(anchor: Vector3, frame_basis: Basis, profile: Resource) -> Vector3:
	return (
			anchor
			+ frame_basis * _profile_vector3(profile, &"anchor_offset_local", Vector3.ZERO)
			+ frame_basis * _profile_vector3(profile, &"camera_offset_local", Vector3(0.0, 3.8, 10.5))
	)


func _desired_look_position(anchor: Vector3, frame_basis: Basis, profile: Resource) -> Vector3:
	var view_yaw_degrees: float = _profile_float(profile, &"view_yaw_degrees", 0.0)
	var view_basis: Basis = frame_basis.rotated(frame_basis.y.normalized(), deg_to_rad(view_yaw_degrees)).orthonormalized()
	var speed_ratio: float = _speed_ratio()
	var preview_forward: Vector3 = -view_basis.z.normalized()
	var velocity_direction: Vector3 = _velocity_preview_direction(preview_forward)
	var velocity_preview_bias: float = _profile_float(profile, &"velocity_preview_bias", 0.25)
	var velocity_weight: float = velocity_preview_bias * smoothstep(0.08, 0.35, speed_ratio)
	if velocity_direction.length_squared() > 0.0001:
		preview_forward = preview_forward.lerp(velocity_direction, velocity_weight).normalized()

	var corner_preview_lateral_m: float = _profile_float(profile, &"corner_preview_lateral_m", 2.0)
	var preview_height_m: float = _profile_float(profile, &"preview_height_m", 1.4)
	var lateral_bias: float = _effective_steer(speed_ratio) * corner_preview_lateral_m
	return (
			anchor
			+ frame_basis * _profile_vector3(profile, &"anchor_offset_local", Vector3.ZERO)
			+ preview_forward * _profile_preview_distance(profile, speed_ratio)
			+ view_basis.x.normalized() * lateral_bias
			+ view_basis.y.normalized() * preview_height_m
	)


func _camera_frame_basis(anchor: Vector3, profile: Resource) -> Basis:
	var target_basis: Basis = _safe_target_basis()
	var provider_basis_result: Dictionary = _provider_basis(anchor)
	if not provider_basis_result.has("basis"):
		return target_basis

	var provider_basis: Basis = provider_basis_result["basis"]
	var weight: float = clampf(_profile_float(profile, &"track_orientation_weight", 0.0), 0.0, 1.0)
	if weight <= 0.0:
		return target_basis
	if weight >= 1.0:
		return provider_basis.orthonormalized()
	return target_basis.slerp(provider_basis, weight).orthonormalized()


func _provider_basis(anchor: Vector3) -> Dictionary:
	var provider: Object = _orientation_provider
	if provider == null:
		provider = _track_query_provider
	if provider == null:
		return {}

	if provider.has_method("get_camera_basis"):
		return _basis_result(provider.call("get_camera_basis", _target, anchor))

	if provider.has_method("get_camera_frame"):
		return _basis_result(provider.call("get_camera_frame", _target, anchor))

	if provider.has_method("closest_distance_for_position") and provider.has_method("sample_at_distance"):
		var distance: float = float(provider.call("closest_distance_for_position", anchor))
		return _basis_result(provider.call("sample_at_distance", distance))

	return {}


func _basis_result(value: Variant) -> Dictionary:
	if value is Basis:
		var basis_value: Basis = value
		return {"basis": basis_value.orthonormalized()}
	if value is Transform3D:
		var transform_value: Transform3D = value
		return {"basis": transform_value.basis.orthonormalized()}
	if value is Dictionary:
		var dictionary: Dictionary = value
		if dictionary.has("basis") and dictionary["basis"] is Basis:
			var dictionary_basis: Basis = dictionary["basis"]
			return {"basis": dictionary_basis.orthonormalized()}
		if dictionary.has("transform") and dictionary["transform"] is Transform3D:
			var dictionary_transform: Transform3D = dictionary["transform"]
			return {"basis": dictionary_transform.basis.orthonormalized()}
		return _basis_from_direction_dictionary(dictionary)
	return {}


func _basis_from_direction_dictionary(dictionary: Dictionary) -> Dictionary:
	var forward: Vector3 = Vector3.ZERO
	if dictionary.has("forward") and dictionary["forward"] is Vector3:
		forward = dictionary["forward"]
	elif dictionary.has("tangent") and dictionary["tangent"] is Vector3:
		forward = dictionary["tangent"]

	var up: Vector3 = Vector3.ZERO
	if dictionary.has("up") and dictionary["up"] is Vector3:
		up = dictionary["up"]
	elif dictionary.has("road_up") and dictionary["road_up"] is Vector3:
		up = dictionary["road_up"]
	elif dictionary.has("surface_up") and dictionary["surface_up"] is Vector3:
		up = dictionary["surface_up"]

	if forward.length_squared() <= 0.0001 or up.length_squared() <= 0.0001:
		return {}
	return {"basis": _basis_from_forward_up(forward, up)}


func _safe_target_basis() -> Basis:
	if _target == null:
		return Basis.IDENTITY

	var target_basis: Basis = _target.global_transform.basis.orthonormalized()
	var forward: Vector3 = -target_basis.z
	var up: Vector3 = target_basis.y

	if forward.length_squared() <= 0.0001:
		forward = _estimated_velocity
	if forward.length_squared() <= 0.0001:
		forward = Vector3.FORWARD

	if up.length_squared() <= 0.0001:
		up = Vector3.UP

	return _basis_from_forward_up(forward, up)


func _basis_from_forward_up(forward: Vector3, up: Vector3) -> Basis:
	var safe_forward: Vector3 = forward.normalized()
	var safe_up: Vector3 = up.normalized()
	if absf(safe_forward.dot(safe_up)) > 0.98:
		safe_up = Vector3.UP
		if absf(safe_forward.dot(safe_up)) > 0.98:
			safe_up = Vector3.RIGHT

	var back: Vector3 = -safe_forward
	var right: Vector3 = safe_up.cross(back)
	if right.length_squared() <= 0.0001:
		right = Vector3.RIGHT
	right = right.normalized()
	safe_up = back.cross(right).normalized()
	return Basis(right, safe_up, back).orthonormalized()


func _up_for_profile(frame_basis: Basis, profile: Resource) -> Vector3:
	match _profile_int(profile, &"roll_mode", ROLL_MODE_STEER_BIAS):
		ROLL_MODE_NONE:
			return frame_basis.y.normalized()
		ROLL_MODE_MATCH_TARGET_UP:
			return _safe_target_basis().y.normalized()
		ROLL_MODE_MATCH_TRACK_UP:
			return frame_basis.y.normalized()
		_:
			return frame_basis.y.normalized()


func _look_basis(camera_position: Vector3, look_position: Vector3, up: Vector3) -> Basis:
	if camera_position.distance_squared_to(look_position) <= 0.0001:
		return _camera.global_transform.basis.orthonormalized() if _camera != null else Basis.IDENTITY
	return Transform3D(Basis.IDENTITY, camera_position).looking_at(look_position, up).basis.orthonormalized()


func _with_profile_roll(desired_basis: Basis, profile: Resource, delta: float) -> Basis:
	var target_roll: float = 0.0
	if _profile_int(profile, &"roll_mode", ROLL_MODE_STEER_BIAS) == ROLL_MODE_STEER_BIAS:
		var drift_intensity: float = _drift_intensity()
		var roll_degrees: float = _profile_float(profile, &"roll_degrees", 3.5)
		var drift_roll_bonus_degrees: float = _profile_float(profile, &"drift_roll_bonus_degrees", 2.0)
		var roll_strength: float = roll_degrees + drift_roll_bonus_degrees * drift_intensity
		target_roll = deg_to_rad(-_effective_steer(_speed_ratio()) * roll_strength)

	var roll_damping: float = _profile_float(profile, &"roll_damping", 8.0)
	var weight: float = 1.0 if delta <= 0.0 else _exp_weight(roll_damping, delta)
	_current_roll = lerp_angle(_current_roll, target_roll, weight)
	return (desired_basis * Basis(Vector3(0.0, 0.0, 1.0), _current_roll)).orthonormalized()


func _apply_collision(anchor: Vector3, desired_position: Vector3, profile: Resource) -> Vector3:
	if not _profile_uses_collision(profile) or get_world_3d() == null:
		return desired_position

	var direction: Vector3 = desired_position - anchor
	if direction.length_squared() <= 0.0001:
		return desired_position

	var query := PhysicsRayQueryParameters3D.create(anchor, desired_position)
	query.collision_mask = _profile_int(profile, &"collision_mask", 1)
	query.hit_from_inside = false
	if _target is CollisionObject3D:
		query.exclude = [(_target as CollisionObject3D).get_rid()]

	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not hit.has("position"):
		return desired_position

	var safe_direction: Vector3 = -direction.normalized()
	var hit_position: Vector3 = hit["position"]
	var collision_margin_m: float = _profile_float(profile, &"collision_margin_m", 0.35)
	var collision_radius_m: float = _profile_float(profile, &"collision_radius_m", 0.25)
	return hit_position + safe_direction * maxf(collision_margin_m, collision_radius_m)


func _smoothed_position(
	current_position: Vector3,
	desired_position: Vector3,
	damping: float,
	delta: float
) -> Vector3:
	if delta <= 0.0:
		return desired_position
	return current_position.lerp(desired_position, _exp_weight(damping, delta))


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
	if _target != null:
		return _target.global_position
	return global_position


func _update_estimated_velocity(anchor: Vector3, delta: float) -> void:
	if delta <= 0.0:
		_estimated_velocity = Vector3.ZERO
		return
	_estimated_velocity = (anchor - _last_anchor_position) / delta


func _velocity_preview_direction(preview_forward: Vector3) -> Vector3:
	var velocity_direction: Vector3 = _estimated_velocity
	if _target is CharacterBody3D:
		velocity_direction = (_target as CharacterBody3D).velocity
	if velocity_direction.length_squared() <= 0.0001:
		return Vector3.ZERO
	velocity_direction = velocity_direction.normalized()
	if velocity_direction.dot(preview_forward) < -0.2:
		return Vector3.ZERO
	return velocity_direction


func _speed_ratio() -> float:
	if _target == null or not _target.has_method("get_speed_ratio"):
		return 0.0
	return clampf(float(_target.call("get_speed_ratio")), 0.0, 1.0)


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


func _is_action_pressed(action: StringName) -> bool:
	if String(action).is_empty() or not InputMap.has_action(action):
		return false
	return Input.is_action_pressed(action)


func _is_action_just_pressed(action: StringName) -> bool:
	if String(action).is_empty() or not InputMap.has_action(action):
		return false
	return Input.is_action_just_pressed(action)


func _emit_effective_view_if_changed() -> void:
	var profile: Resource = _effective_profile()
	var view_id: StringName = _profile_view_id(profile)
	if _last_effective_view_id == view_id:
		return
	_last_effective_view_id = view_id
	effective_view_changed.emit(view_id, _profile_is_temporary_override(profile))


func _profile_view_id(profile: Resource, fallback: StringName = &"") -> StringName:
	if profile == null:
		return fallback
	var value: Variant = profile.get("view_id")
	if value == null:
		return fallback
	if value is StringName:
		return value
	return StringName(String(value))


func _profile_is_temporary_override(profile: Resource) -> bool:
	if profile == null:
		return false
	if profile.has_method("is_temporary_override"):
		return bool(profile.call("is_temporary_override"))
	return _profile_int(profile, &"view_role", VIEW_ROLE_PRIMARY) == VIEW_ROLE_TEMPORARY_OVERRIDE


func _profile_uses_collision(profile: Resource) -> bool:
	if profile == null:
		return false
	if profile.has_method("uses_collision"):
		return bool(profile.call("uses_collision"))
	return _profile_int(profile, &"collision_mode", COLLISION_MODE_DISABLED) != COLLISION_MODE_DISABLED


func _profile_target_fov(profile: Resource, speed_ratio: float) -> float:
	if profile != null and profile.has_method("get_target_fov"):
		return float(profile.call("get_target_fov", speed_ratio))

	var safe_ratio: float = clampf(speed_ratio, 0.0, 1.0)
	var fov_degrees: float = _profile_float(profile, &"fov_degrees", 67.0)
	var high_speed_fov_degrees: float = _profile_float(profile, &"high_speed_fov_degrees", fov_degrees)
	var fov_speed_power: float = _profile_float(profile, &"fov_speed_power", 0.75)
	return lerpf(fov_degrees, high_speed_fov_degrees, pow(safe_ratio, fov_speed_power))


func _profile_preview_distance(profile: Resource, speed_ratio: float) -> float:
	if profile != null and profile.has_method("get_preview_distance"):
		return float(profile.call("get_preview_distance", speed_ratio))
	if not _profile_bool(profile, &"road_preview_enabled", true):
		return _profile_float(profile, &"preview_distance_low_speed_m", 7.5)
	return lerpf(
			_profile_float(profile, &"preview_distance_low_speed_m", 7.5),
			_profile_float(profile, &"preview_distance_high_speed_m", 17.0),
			clampf(speed_ratio, 0.0, 1.0)
	)


func _profile_float(profile: Resource, property_name: StringName, fallback: float) -> float:
	if profile == null:
		return fallback
	var value: Variant = profile.get(property_name)
	if value == null:
		return fallback
	return float(value)


func _profile_int(profile: Resource, property_name: StringName, fallback: int) -> int:
	if profile == null:
		return fallback
	var value: Variant = profile.get(property_name)
	if value == null:
		return fallback
	return int(value)


func _profile_bool(profile: Resource, property_name: StringName, fallback: bool) -> bool:
	if profile == null:
		return fallback
	var value: Variant = profile.get(property_name)
	if value == null:
		return fallback
	return bool(value)


func _profile_vector3(profile: Resource, property_name: StringName, fallback: Vector3) -> Vector3:
	if profile == null:
		return fallback
	var value: Variant = profile.get(property_name)
	if value is Vector3:
		return value
	return fallback


func _exp_weight(damping: float, delta: float) -> float:
	if damping <= 0.0:
		return 1.0
	return 1.0 - exp(-damping * delta)
