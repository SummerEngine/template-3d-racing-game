extends SceneTree

const GARAGE_SCENE_PATH: String = "res://scenes/ui/garage_showroom.tscn"
const PLATFORM_MODEL_PATH: String = "res://assets/ui/showroom/platform/rotation_platform.glb"
const PLATFORM_NODE_NAME: String = "RotationPlatformModel"
const TARGET_PLATFORM_DIAMETER: float = 5.25
const CAR_MOUNT_CLEARANCE: float = 0.03


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var garage_scene := ResourceLoader.load(GARAGE_SCENE_PATH) as PackedScene
	if garage_scene == null:
		push_error("Could not load %s" % GARAGE_SCENE_PATH)
		quit(1)
		return

	var platform_scene := ResourceLoader.load(PLATFORM_MODEL_PATH) as PackedScene
	if platform_scene == null:
		push_error("Could not load %s" % PLATFORM_MODEL_PATH)
		quit(1)
		return

	var root := garage_scene.instantiate() as Node
	var turntable := _find_node3d(root, &"Turntable")
	var car_mount := _find_node3d(root, &"CarMount")
	if turntable == null or car_mount == null:
		push_error("Garage scene must keep Turntable and CarMount nodes")
		quit(1)
		return

	_remove_child_if_present(turntable, &"RotatingRoundPlatform")
	_remove_child_if_present(turntable, &"PlatformTopHighlight")
	_remove_child_if_present(turntable, StringName(PLATFORM_NODE_NAME))

	var platform := platform_scene.instantiate() as Node3D
	platform.name = PLATFORM_NODE_NAME
	turntable.add_child(platform)
	turntable.move_child(platform, 0)

	var local_bounds := _calculate_local_aabb(platform, platform)
	if local_bounds.size.x <= 0.001 or local_bounds.size.z <= 0.001:
		push_error("Could not calculate platform bounds")
		quit(1)
		return

	var footprint: float = max(local_bounds.size.x, local_bounds.size.z)
	var platform_scale: float = TARGET_PLATFORM_DIAMETER / footprint
	platform.scale = Vector3.ONE * platform_scale
	platform.position = Vector3(-local_bounds.get_center().x * platform_scale, -local_bounds.position.y * platform_scale, -local_bounds.get_center().z * platform_scale)

	var fitted_bounds := _calculate_local_aabb(turntable, platform)
	car_mount.position.x = 0.0
	car_mount.position.y = fitted_bounds.position.y + fitted_bounds.size.y + CAR_MOUNT_CLEARANCE
	car_mount.position.z = 0.0

	_assign_owner_recursive(root, root)

	var packed_scene := PackedScene.new()
	var pack_error := packed_scene.pack(root)
	if pack_error != OK:
		push_error("Could not pack %s: %d" % [GARAGE_SCENE_PATH, pack_error])
		quit(1)
		return

	var save_error := ResourceSaver.save(packed_scene, GARAGE_SCENE_PATH)
	if save_error != OK:
		push_error("Could not save %s: %d" % [GARAGE_SCENE_PATH, save_error])
		quit(1)
		return

	print("Updated garage platform: scale %.4f, CarMount y %.4f" % [platform_scale, car_mount.position.y])
	quit(0)


func _find_node3d(root: Node, node_name: StringName) -> Node3D:
	if root.name == node_name and root is Node3D:
		return root as Node3D
	for child: Node in root.get_children():
		var found := _find_node3d(child, node_name)
		if found != null:
			return found
	return null


func _remove_child_if_present(parent: Node, child_name: StringName) -> void:
	var child := parent.get_node_or_null(NodePath(child_name))
	if child == null:
		return
	parent.remove_child(child)
	child.queue_free()


func _calculate_local_aabb(reference: Node3D, node: Node) -> AABB:
	var has_bounds := false
	var bounds := AABB()
	for mesh_instance: MeshInstance3D in _collect_mesh_instances(node):
		if mesh_instance.mesh == null:
			continue
		var mesh_aabb := mesh_instance.mesh.get_aabb()
		var local_transform := _get_transform_to_reference(reference, mesh_instance)
		var transformed := local_transform * mesh_aabb
		if not has_bounds:
			bounds = transformed
			has_bounds = true
		else:
			bounds = bounds.merge(transformed)
	return bounds


func _get_transform_to_reference(reference: Node3D, node: Node3D) -> Transform3D:
	var transform_to_reference := Transform3D.IDENTITY
	var cursor: Node = node
	while cursor != null and cursor != reference:
		if cursor is Node3D:
			transform_to_reference = (cursor as Node3D).transform * transform_to_reference
		cursor = cursor.get_parent()
	return transform_to_reference


func _collect_mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		meshes.append(node as MeshInstance3D)
	for child: Node in node.get_children():
		meshes.append_array(_collect_mesh_instances(child))
	return meshes


func _assign_owner_recursive(node: Node, owner_node: Node) -> void:
	for child: Node in node.get_children():
		child.owner = owner_node
		_assign_owner_recursive(child, owner_node)
