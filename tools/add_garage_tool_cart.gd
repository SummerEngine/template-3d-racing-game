extends SceneTree

const GARAGE_SCENE_PATH: String = "res://scenes/ui/garage_showroom.tscn"
const TOOL_CART_MODEL_PATH: String = "res://assets/ui/showroom/props/tool_cart.glb"
const TOOL_CART_NODE_NAME: String = "ToolCart"
const TARGET_TOOL_CART_HEIGHT: float = 0.92
const TOOL_CART_POSITION_XZ: Vector2 = Vector2(-4.25, -2.55)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var garage_scene := ResourceLoader.load(GARAGE_SCENE_PATH) as PackedScene
	if garage_scene == null:
		push_error("Could not load %s" % GARAGE_SCENE_PATH)
		quit(1)
		return

	var tool_cart_scene := ResourceLoader.load(TOOL_CART_MODEL_PATH) as PackedScene
	if tool_cart_scene == null:
		push_error("Could not load %s" % TOOL_CART_MODEL_PATH)
		quit(1)
		return

	var root := garage_scene.instantiate() as Node
	var props := _find_node3d(root, &"EditableProps")
	if props == null:
		props = Node3D.new()
		props.name = "EditableProps"
		root.add_child(props)

	_remove_child_if_present(props, StringName(TOOL_CART_NODE_NAME))

	var tool_cart := tool_cart_scene.instantiate() as Node3D
	tool_cart.name = TOOL_CART_NODE_NAME
	props.add_child(tool_cart)

	var local_bounds := _calculate_local_aabb(tool_cart, tool_cart)
	if local_bounds.size.y > 0.001:
		var scale_factor: float = TARGET_TOOL_CART_HEIGHT / local_bounds.size.y
		tool_cart.scale = Vector3.ONE * scale_factor
		tool_cart.position = Vector3(
			TOOL_CART_POSITION_XZ.x - local_bounds.get_center().x * scale_factor,
			-local_bounds.position.y * scale_factor,
			TOOL_CART_POSITION_XZ.y - local_bounds.get_center().z * scale_factor
		)
	else:
		tool_cart.position = Vector3(TOOL_CART_POSITION_XZ.x, 0.0, TOOL_CART_POSITION_XZ.y)

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

	print("Added editable ToolCart to %s" % GARAGE_SCENE_PATH)
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
		var transformed := _get_transform_to_reference(reference, mesh_instance) * mesh_instance.mesh.get_aabb()
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
