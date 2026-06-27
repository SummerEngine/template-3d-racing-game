extends SceneTree

const AUTHORING_SCENE_PATH: String = "res://scenes/tracks/storm_coast/storm_coast_authoring.tscn"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_scene := load(AUTHORING_SCENE_PATH) as PackedScene
	if packed_scene == null:
		push_error("Could not load %s" % AUTHORING_SCENE_PATH)
		quit(1)
		return

	var root := packed_scene.instantiate()
	if root == null:
		push_error("Could not instantiate %s" % AUTHORING_SCENE_PATH)
		quit(1)
		return

	get_root().add_child(root)
	await process_frame

	if not root.has_method("bake_editable"):
		push_error("%s has no bake_editable() method" % AUTHORING_SCENE_PATH)
		quit(1)
		return

	var records: Variant = root.call("bake_editable")
	var saved_scene := PackedScene.new()
	var pack_error := saved_scene.pack(root)
	if pack_error != OK:
		push_error("Could not pack %s: %d" % [AUTHORING_SCENE_PATH, pack_error])
		quit(1)
		return

	var save_error := ResourceSaver.save(saved_scene, AUTHORING_SCENE_PATH)
	if save_error != OK:
		push_error("Could not save %s: %d" % [AUTHORING_SCENE_PATH, save_error])
		quit(1)
		return

	var road_point_count: int = 0
	if records is Dictionary:
		road_point_count = (records as Dictionary).get("road_points", []).size()
	print("Storm Coast authoring baked and saved from %d road points." % road_point_count)
	quit(0)
