extends SceneTree

const AUTHORING_SCENE_PATH := "res://scenes/tracks/storm_coast/storm_coast_authoring.tscn"


func _initialize() -> void:
	call_deferred("_bake_authoring_scene")


func _bake_authoring_scene() -> void:
	var packed_scene := load(AUTHORING_SCENE_PATH) as PackedScene
	if packed_scene == null:
		push_error("Could not load %s" % AUTHORING_SCENE_PATH)
		quit(1)
		return

	var scene_root := packed_scene.instantiate() as Node3D
	if scene_root == null:
		push_error("Could not instantiate %s" % AUTHORING_SCENE_PATH)
		quit(1)
		return

	var generator := scene_root.get_node_or_null("Generated/StormCoastTrackGenerator")
	if generator == null:
		push_error("StormCoastTrackGenerator was not found.")
		quit(1)
		return

	generator.set("generate_on_ready", false)
	generator.set("assign_owner_in_editor", true)
	generator.set("generate_surrounding_terrain", true)
	generator.set("terrain_width_m", 88.0)
	generator.set("terrain_outer_drop_m", 3.0)
	generator.set("terrain_roughness_m", 3.2)
	generator.set("terrain_edge_gap_m", 1.35)
	generator.set("terrain_band_count", 7)
	generator.set("terrain_mountain_height_m", 18.0)
	generator.set("terrain_ridge_position", 0.58)
	generator.set("guardrail_sample_spacing_m", 2.0)
	generator.set("guardrail_seam_gap_m", 0.0)
	generator.set("generate_guardrail_markers", false)

	root.add_child(scene_root)
	scene_root.owner = null
	await process_frame

	if scene_root.has_method("bake_editable"):
		scene_root.call("bake_editable")
	elif generator.has_method("regenerate_track"):
		generator.call("regenerate_track")
	else:
		push_error("No terrain bake/regenerate method was available.")
		quit(1)
		return

	generator.set("generate_on_ready", false)
	generator.set("assign_owner_in_editor", true)
	_assign_owner_recursive(scene_root, scene_root)

	var repacked := PackedScene.new()
	var pack_error := repacked.pack(scene_root)
	if pack_error != OK:
		push_error("Could not pack %s: %d" % [AUTHORING_SCENE_PATH, pack_error])
		quit(1)
		return

	var save_error := ResourceSaver.save(repacked, AUTHORING_SCENE_PATH)
	if save_error != OK:
		push_error("Could not save %s: %d" % [AUTHORING_SCENE_PATH, save_error])
		quit(1)
		return

	print("Baked editor-owned Storm Coast terrain into %s" % AUTHORING_SCENE_PATH)
	quit()


func _assign_owner_recursive(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		child.owner = owner_node
		_assign_owner_recursive(child, owner_node)
