class_name VehicleFeedbackEmitter
extends Node3D

@export var vehicle_root_path: NodePath = ^".."
@export var rear_left_wheel_path: NodePath = ^"VisualRoot/WheelRL"
@export var rear_right_wheel_path: NodePath = ^"VisualRoot/WheelRR"
@export var smoke_interval: float = 0.08
@export var streak_interval: float = 0.09
@export var max_smoke_intensity: float = 1.0
@export var speed_streak_threshold: float = 0.68

var _vehicle: Node3D = null
var _rear_left_wheel: Node3D = null
var _rear_right_wheel: Node3D = null
var _smoke_timer: float = 0.0
var _streak_timer: float = 0.0
var _spark_material: StandardMaterial3D = null
var _smoke_material: StandardMaterial3D = null
var _streak_material: StandardMaterial3D = null


func _ready() -> void:
	_vehicle = get_node_or_null(vehicle_root_path) as Node3D
	if _vehicle == null:
		_vehicle = get_parent() as Node3D
	if _vehicle == null:
		push_warning("VehicleFeedbackEmitter: no vehicle root found")
		return

	_rear_left_wheel = _vehicle.get_node_or_null(rear_left_wheel_path) as Node3D
	_rear_right_wheel = _vehicle.get_node_or_null(rear_right_wheel_path) as Node3D
	_smoke_material = _make_translucent_material(Color(0.84, 0.88, 0.9, 0.46), false)
	_spark_material = _make_emissive_material(Color(1.0, 0.76, 0.22, 1.0), 1.9)
	_streak_material = _make_translucent_material(Color(0.62, 0.86, 1.0, 0.34), true)
	_connect_vehicle_signals()


func _process(delta: float) -> void:
	if _vehicle == null:
		return

	_smoke_timer -= delta
	_streak_timer -= delta
	var drift_intensity: float = _vehicle_drift_intensity()
	if drift_intensity > 0.06 and _smoke_timer <= 0.0:
		_emit_drift_smoke(drift_intensity)
		_smoke_timer = lerpf(smoke_interval, smoke_interval * 0.45, clampf(drift_intensity, 0.0, 1.0))

	var speed_ratio: float = _vehicle_speed_ratio()
	if speed_ratio >= speed_streak_threshold and _streak_timer <= 0.0:
		_emit_speed_streak(speed_ratio)
		_streak_timer = streak_interval


func _connect_vehicle_signals() -> void:
	if _vehicle.has_signal("wall_scraped"):
		_vehicle.connect("wall_scraped", _on_wall_scraped)
	if _vehicle.has_signal("vehicle_bumped"):
		_vehicle.connect("vehicle_bumped", _on_vehicle_bumped)


func _emit_drift_smoke(intensity: float) -> void:
	var safe_intensity: float = clampf(intensity, 0.0, max_smoke_intensity)
	_spawn_smoke_at(_wheel_position(_rear_left_wheel), safe_intensity)
	_spawn_smoke_at(_wheel_position(_rear_right_wheel), safe_intensity)


func _spawn_smoke_at(world_position: Vector3, intensity: float) -> void:
	var puff := MeshInstance3D.new()
	puff.name = "DriftSmokePuff"
	var mesh := SphereMesh.new()
	mesh.radius = 0.35 + intensity * 0.18
	mesh.height = 0.26 + intensity * 0.12
	puff.mesh = mesh
	puff.material_override = _smoke_material.duplicate()
	puff.scale = Vector3.ONE * (0.55 + intensity * 0.35)
	_world_effect_root().add_child(puff)
	puff.global_position = world_position + Vector3(0.0, 0.08, 0.0)

	var drift_offset: Vector3 = -_vehicle.global_transform.basis.z.normalized() * (0.85 + intensity * 0.55)
	drift_offset.y = 0.3 + intensity * 0.25
	var tween: Tween = puff.create_tween()
	tween.set_parallel(true)
	tween.tween_property(puff, "global_position", puff.global_position + drift_offset, 0.72)
	tween.tween_property(puff, "scale", puff.scale * (1.8 + intensity), 0.72)
	tween.tween_property(puff.material_override, "albedo_color", Color(0.84, 0.88, 0.9, 0.0), 0.72)
	tween.chain().tween_callback(Callable(puff, "queue_free"))


func _emit_speed_streak(speed_ratio: float) -> void:
	var streak := MeshInstance3D.new()
	streak.name = "SpeedStreak"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.08, 0.08, 2.8 + speed_ratio * 1.8)
	streak.mesh = mesh
	streak.material_override = _streak_material.duplicate()
	var side: float = -1.0 if randi() % 2 == 0 else 1.0
	var back: Vector3 = _vehicle.global_transform.basis.z.normalized()
	var right: Vector3 = _vehicle.global_transform.basis.x.normalized()
	_world_effect_root().add_child(streak)
	streak.global_transform = Transform3D(_vehicle.global_transform.basis, _vehicle.global_position)
	streak.global_position += back * (2.4 + randf() * 0.9) + right * side * randf_range(0.9, 1.7) + Vector3(0.0, randf_range(0.5, 1.1), 0.0)

	var tween: Tween = streak.create_tween()
	tween.set_parallel(true)
	tween.tween_property(streak, "global_position", streak.global_position + back * 3.0, 0.22)
	tween.tween_property(streak.material_override, "albedo_color", Color(0.62, 0.86, 1.0, 0.0), 0.22)
	tween.chain().tween_callback(Callable(streak, "queue_free"))


func _on_wall_scraped(intensity: float, contact_position: Vector3, contact_normal: Vector3) -> void:
	_spawn_sparks(contact_position, contact_normal, clampf(intensity, 0.0, 1.0), 8)


func _on_vehicle_bumped(intensity: float, contact_position: Vector3, contact_normal: Vector3) -> void:
	_spawn_sparks(contact_position, contact_normal, clampf(intensity, 0.0, 1.0), 5)


func _spawn_sparks(contact_position: Vector3, contact_normal: Vector3, intensity: float, count: int) -> void:
	var spark_count: int = maxi(1, roundi(float(count) * (0.45 + intensity)))
	for spark_index: int in range(spark_count):
		var spark := MeshInstance3D.new()
		spark.name = "ArcadeSpark"
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.06, 0.06, 0.36 + intensity * 0.28)
		spark.mesh = mesh
		spark.material_override = _spark_material.duplicate()
		spark.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		_world_effect_root().add_child(spark)
		spark.global_position = contact_position + contact_normal * 0.08

		var scatter: Vector3 = (contact_normal + Vector3(randf_range(-0.6, 0.6), randf_range(0.25, 1.2), randf_range(-0.6, 0.6))).normalized()
		var tween: Tween = spark.create_tween()
		tween.set_parallel(true)
		tween.tween_property(spark, "global_position", spark.global_position + scatter * randf_range(0.55, 1.35), 0.28)
		tween.tween_property(spark, "scale", Vector3.ONE * 0.05, 0.28)
		tween.tween_property(spark.material_override, "albedo_color", Color(1.0, 0.45, 0.05, 0.0), 0.28)
		tween.chain().tween_callback(Callable(spark, "queue_free"))


func _vehicle_drift_intensity() -> float:
	if _vehicle != null and _vehicle.has_method("get_drift_intensity"):
		return clampf(float(_vehicle.call("get_drift_intensity")), 0.0, 1.0)
	if _vehicle != null and _vehicle.get("drift_intensity") != null:
		return clampf(float(_vehicle.get("drift_intensity")), 0.0, 1.0)
	return 0.0


func _vehicle_speed_ratio() -> float:
	if _vehicle != null and _vehicle.has_method("get_speed_ratio"):
		return clampf(float(_vehicle.call("get_speed_ratio")), 0.0, 1.0)
	return 0.0


func _wheel_position(wheel: Node3D) -> Vector3:
	if wheel != null:
		return wheel.global_position
	return _vehicle.global_position - _vehicle.global_transform.basis.z * 1.2


func _world_effect_root() -> Node:
	var current_scene: Node = get_tree().current_scene
	return current_scene if current_scene != null else get_tree().root


func _make_translucent_material(color: Color, unshaded: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if unshaded else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	return material


func _make_emissive_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material
