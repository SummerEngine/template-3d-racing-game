class_name ProceduralSceneryPropFactory
extends RefCounted

const Palette := preload("res://scripts/procedural/procedural_scenery_palette.gd")
const BILLBOARD_AD_TEXTURES: Array[Texture2D] = [
	preload("res://assets/billboards/billboard_ad_turbo_drink.png"),
	preload("res://assets/billboards/billboard_ad_neon_tires.png"),
	preload("res://assets/billboards/billboard_ad_rocket_garage.png"),
	preload("res://assets/billboards/billboard_ad_cosmic_pizza.png"),
	preload("res://assets/billboards/billboard_ad_drift_school.png"),
]


static func create_prop(kind: String, prop_seed: int = 0, options: Dictionary = {}) -> Node3D:
	var normalized_kind := kind.to_lower()
	if normalized_kind == "house" or normalized_kind == "suburban_house":
		return create_suburban_house(prop_seed, options.get("size", Vector3(11.0, 5.2, 8.0)))
	if normalized_kind == "billboard" or normalized_kind == "highway_billboard":
		return create_highway_billboard(prop_seed, options.get("panel_size", Vector2(10.0, 4.0)), float(options.get("clearance", 5.5)))
	if normalized_kind == "crop" or normalized_kind == "crop_block":
		return create_crop_block(prop_seed, options.get("size", Vector2(36.0, 24.0)), int(options.get("row_count", 7)), float(options.get("crop_height", 0.75)))
	if normalized_kind == "factory" or normalized_kind == "industrial_factory":
		return create_industrial_factory(prop_seed, options.get("size", Vector3(22.0, 8.0, 16.0)))
	if normalized_kind == "container" or normalized_kind == "shipping_container":
		return create_shipping_container(prop_seed, options.get("size", Vector3(13.0, 3.0, 3.2)))

	var root := Node3D.new()
	root.name = "UnknownSceneryProp"
	root.set_meta("scenery_kind", kind)
	root.set_meta("scenery_seed", prop_seed)
	return root


static func create_suburban_house(prop_seed: int = 0, size: Vector3 = Vector3(11.0, 5.2, 8.0)) -> Node3D:
	var root := _root("SuburbanHouse", "suburban_house", prop_seed)
	var wall_variant: int = _variant(prop_seed, 1)
	var roof_variant: int = _variant(prop_seed, 2)

	_add_box(root, "HouseBody", size, "house_wall", wall_variant, Vector3(0.0, size.y * 0.5, 0.0))

	var roof_height: float = maxf(size.y * 0.42, 2.0)
	var overhang: float = 0.55
	var roof_span: float = size.x * 0.5 + overhang
	var roof_depth: float = size.z + overhang * 2.0
	var roof_angle: float = atan2(roof_height, roof_span)
	var roof_length: float = sqrt(roof_span * roof_span + roof_height * roof_height)
	var roof_thickness: float = 0.45

	var left_roof := _add_box(root, "RoofLeft", Vector3(roof_length, roof_thickness, roof_depth), "roof", roof_variant, Vector3(-roof_span * 0.5, size.y + roof_height * 0.5, 0.0))
	left_roof.rotation_degrees.z = -rad_to_deg(roof_angle)
	var right_roof := _add_box(root, "RoofRight", Vector3(roof_length, roof_thickness, roof_depth), "roof", roof_variant, Vector3(roof_span * 0.5, size.y + roof_height * 0.5, 0.0))
	right_roof.rotation_degrees.z = rad_to_deg(roof_angle)

	_add_box(root, "Door", Vector3(1.25, 2.3, 0.12), "door", prop_seed, Vector3(-size.x * 0.27, 1.15, -size.z * 0.5 - 0.07))
	_add_box(root, "WindowFrontA", Vector3(1.45, 1.05, 0.1), "glass", prop_seed, Vector3(size.x * 0.16, size.y * 0.56, -size.z * 0.5 - 0.08))
	_add_box(root, "WindowFrontB", Vector3(1.45, 1.05, 0.1), "glass", prop_seed + 1, Vector3(size.x * 0.34, size.y * 0.56, -size.z * 0.5 - 0.08))
	_add_box(root, "GarageHint", Vector3(2.8, 1.65, 0.1), "concrete", prop_seed, Vector3(size.x * 0.28, 0.85, -size.z * 0.5 - 0.09))

	var chimney := _add_box(root, "Chimney", Vector3(0.85, 2.1, 0.85), "roof", roof_variant + 1, Vector3(size.x * 0.24, size.y + roof_height * 0.72, size.z * 0.18))
	chimney.rotation_degrees.y = 6.0 * float(_variant(prop_seed, 3) % 3 - 1)
	return root


static func create_highway_billboard(prop_seed: int = 0, panel_size: Vector2 = Vector2(10.0, 4.0), clearance: float = 5.5) -> Node3D:
	var root := _root("HighwayBillboard", "highway_billboard", prop_seed)
	var post_height: float = clearance + panel_size.y
	var post_size := Vector3(0.35, post_height, 0.35)
	var post_offset: float = panel_size.x * 0.36

	_add_box(root, "PostLeft", post_size, "metal", prop_seed, Vector3(-post_offset, post_height * 0.5, 0.1))
	_add_box(root, "PostRight", post_size, "metal", prop_seed, Vector3(post_offset, post_height * 0.5, 0.1))
	var panel := _add_box(root, "Panel", Vector3(panel_size.x, panel_size.y, 0.32), "billboard_panel", prop_seed, Vector3(0.0, clearance + panel_size.y * 0.5, 0.0))
	_apply_billboard_ad_material(panel, prop_seed)
	_add_box(root, "TopTrim", Vector3(panel_size.x + 0.45, 0.22, 0.42), "billboard_trim", prop_seed, Vector3(0.0, clearance + panel_size.y + 0.13, 0.0))
	_add_box(root, "BottomTrim", Vector3(panel_size.x + 0.45, 0.22, 0.42), "billboard_trim", prop_seed, Vector3(0.0, clearance - 0.13, 0.0))
	_add_box(root, "AccentBar", Vector3(panel_size.x * 0.74, 0.35, 0.34), "billboard_trim", prop_seed, Vector3(0.0, clearance + panel_size.y * 0.22, -0.18))
	return root


static func create_crop_block(prop_seed: int = 0, size: Vector2 = Vector2(36.0, 24.0), row_count: int = 7, crop_height: float = 0.75) -> Node3D:
	var root := _root("CropBlock", "crop_block", prop_seed)
	var safe_rows: int = maxi(row_count, 1)
	_add_box(root, "SoilPatch", Vector3(size.x, 0.08, size.y), "crop_soil", prop_seed, Vector3(0.0, 0.04, 0.0))

	var row_spacing: float = size.y / float(safe_rows + 1)
	for row_index: int in range(safe_rows):
		var z: float = -size.y * 0.5 + row_spacing * float(row_index + 1)
		var row_width: float = 0.38 + 0.1 * float((prop_seed + row_index) % 3)
		var row_height: float = crop_height * (0.82 + 0.08 * float((prop_seed + row_index) % 4))
		_add_box(root, "CropRow%02d" % (row_index + 1), Vector3(size.x * 0.9, row_height, row_width), "crop", prop_seed + row_index, Vector3(0.0, row_height * 0.5 + 0.08, z))
	return root


static func create_industrial_factory(prop_seed: int = 0, size: Vector3 = Vector3(22.0, 8.0, 16.0)) -> Node3D:
	var root := _root("IndustrialFactory", "industrial_factory", prop_seed)
	var wall_variant: int = _variant(prop_seed, 4)
	_add_box(root, "FactoryHall", size, "factory_wall", wall_variant, Vector3(0.0, size.y * 0.5, 0.0))
	_add_box(root, "FactoryRoof", Vector3(size.x + 0.8, 0.7, size.z + 0.8), "factory_roof", prop_seed, Vector3(0.0, size.y + 0.35, 0.0))

	for bay_index: int in range(3):
		var x: float = -size.x * 0.3 + float(bay_index) * size.x * 0.3
		_add_box(root, "RoofMonitor%02d" % (bay_index + 1), Vector3(size.x * 0.18, 1.2, size.z * 0.55), "factory_roof", prop_seed + bay_index, Vector3(x, size.y + 1.25, 0.0))

	var stack_x: float = size.x * 0.42
	var stack_z: float = size.z * 0.28
	_add_box(root, "SmokeStack", Vector3(1.2, size.y * 1.45, 1.2), "factory_roof", prop_seed + 2, Vector3(stack_x, size.y * 1.45 * 0.5, stack_z))
	_add_box(root, "LoadingDoor", Vector3(size.x * 0.24, size.y * 0.42, 0.16), "concrete", prop_seed, Vector3(-size.x * 0.18, size.y * 0.22, -size.z * 0.5 - 0.09))
	_add_box(root, "WindowStrip", Vector3(size.x * 0.58, size.y * 0.12, 0.14), "glass", prop_seed + 1, Vector3(0.0, size.y * 0.68, -size.z * 0.5 - 0.1))
	return root


static func create_shipping_container(prop_seed: int = 0, size: Vector3 = Vector3(13.0, 3.0, 3.2)) -> Node3D:
	var root := _root("ShippingContainer", "shipping_container", prop_seed)
	_add_box(root, "ContainerBody", size, "container", prop_seed, Vector3(0.0, size.y * 0.5, 0.0), 0.62, 0.0)

	var rib_count: int = 7
	for rib_index: int in range(rib_count):
		var x: float = -size.x * 0.5 + size.x * float(rib_index) / float(rib_count - 1)
		_add_box(root, "SideRibFront%02d" % (rib_index + 1), Vector3(0.12, size.y + 0.08, 0.12), "container", prop_seed + 1, Vector3(x, size.y * 0.5, -size.z * 0.5 - 0.07), 0.68, 0.0)
		_add_box(root, "SideRibBack%02d" % (rib_index + 1), Vector3(0.12, size.y + 0.08, 0.12), "container", prop_seed + 1, Vector3(x, size.y * 0.5, size.z * 0.5 + 0.07), 0.68, 0.0)

	_add_box(root, "DoorSeam", Vector3(0.12, size.y + 0.1, 0.16), "billboard_trim", prop_seed, Vector3(size.x * 0.42, size.y * 0.5, -size.z * 0.5 - 0.1))
	_add_box(root, "TopRail", Vector3(size.x + 0.15, 0.16, 0.16), "billboard_trim", prop_seed, Vector3(0.0, size.y + 0.08, -size.z * 0.5 - 0.09))
	_add_box(root, "BottomRail", Vector3(size.x + 0.15, 0.16, 0.16), "billboard_trim", prop_seed, Vector3(0.0, 0.08, -size.z * 0.5 - 0.09))
	return root


static func _root(node_name: String, kind: String, prop_seed: int) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	root.set_meta("scenery_kind", kind)
	root.set_meta("scenery_seed", prop_seed)
	return root


static func _add_box(parent: Node3D, node_name: String, size: Vector3, material_key: String, variant: int, position: Vector3, roughness: float = -1.0, metallic: float = 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size

	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.material_override = Palette.material(material_key, variant, roughness, metallic)
	node.position = position
	parent.add_child(node)
	return node


static func _apply_billboard_ad_material(panel: MeshInstance3D, prop_seed: int) -> void:
	if BILLBOARD_AD_TEXTURES.is_empty():
		return
	var texture_index: int = absi(prop_seed) % BILLBOARD_AD_TEXTURES.size()
	var ad_texture: Texture2D = BILLBOARD_AD_TEXTURES[texture_index]
	var material := StandardMaterial3D.new()
	material.albedo_texture = ad_texture
	material.roughness = 0.82
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	panel.material_override = material
	panel.set_meta("billboard_ad_texture", ad_texture.resource_path)


static func _variant(prop_seed: int, salt: int) -> int:
	return prop_seed * 37 + salt * 101
