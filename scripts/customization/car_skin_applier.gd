class_name CarSkinApplier
extends Node

const _INVALID_SURFACE_INDEX := -1
const _DEFAULT_METALLIC := 0.85
const _DEFAULT_ROUGHNESS := 0.28
const _NON_BODY_NAME_HINTS: Array[String] = [
	"glass",
	"window",
	"windshield",
	"windscreen",
	"wheel",
	"tire",
	"tyre",
	"rim",
	"brake",
	"light",
	"headlight",
	"taillight",
	"tail_light",
	"lamp",
	"interior",
	"seat",
	"cockpit",
	"mirror",
	"rubber",
]
const _SHADER_TEXTURE_PARAMETER_HINTS: Array[String] = [
	"albedo_texture",
	"base_color_texture",
	"base_texture",
	"diffuse_texture",
	"paint_texture",
	"body_texture",
	"texture_albedo",
]
const _SHADER_COLOR_PARAMETER_HINTS: Array[String] = [
	"albedo",
	"albedo_color",
	"base_color",
	"diffuse_color",
	"paint_color",
	"body_color",
	"color",
]
const _SHADER_METALLIC_PARAMETER_HINTS: Array[String] = ["metallic", "metalness"]
const _SHADER_ROUGHNESS_PARAMETER_HINTS: Array[String] = ["roughness"]

@export var target_root_path: NodePath = ^"."
@export var body_material_name_hints: Array[String] = ["BodyPaint", "body", "paint", "car_body", "exterior"]
@export var fallback_mesh_name_hints: Array[String] = ["Body", "ImportedHypercarModel"]
@export var preserve_non_body_materials: bool = true

var _target_root: Node = null
var _original_material_entries: Array[Dictionary] = []
var _original_slot_keys: Dictionary = {}


class MaterialSlot:
	var mesh_instance: MeshInstance3D = null
	var surface_index: int = _INVALID_SURFACE_INDEX
	var uses_material_override: bool = false

	func _init(slot_mesh_instance: MeshInstance3D, slot_surface_index: int, slot_uses_material_override: bool) -> void:
		mesh_instance = slot_mesh_instance
		surface_index = slot_surface_index
		uses_material_override = slot_uses_material_override


func _ready() -> void:
	_resolve_target_root()


func set_target(root: Node) -> void:
	if root == null:
		push_warning("CarSkinApplier: set_target called with a null root")
		return

	if _target_root != root:
		reset_preview()
	_target_root = root


func apply_body_texture(texture: Texture2D) -> void:
	if texture == null:
		push_warning("CarSkinApplier: apply_body_texture called with a null texture")
		return

	var slots: Array[MaterialSlot] = _find_body_slots()
	if slots.is_empty():
		push_warning("CarSkinApplier: no body material slot found for texture application")
		return

	for slot: MaterialSlot in slots:
		var material: Material = _material_with_texture(_current_slot_material(slot), texture)
		_assign_slot_material(slot, material)


func apply_body_color(color: Color, metallic: float = _DEFAULT_METALLIC, roughness: float = _DEFAULT_ROUGHNESS) -> void:
	var slots: Array[MaterialSlot] = _find_body_slots()
	if slots.is_empty():
		push_warning("CarSkinApplier: no body material slot found for color application")
		return

	var safe_metallic: float = clampf(metallic, 0.0, 1.0)
	var safe_roughness: float = clampf(roughness, 0.0, 1.0)
	for slot: MaterialSlot in slots:
		var material: Material = _material_with_color(_current_slot_material(slot), color, safe_metallic, safe_roughness)
		_assign_slot_material(slot, material)


func reset_preview() -> void:
	for entry: Dictionary in _original_material_entries:
		var mesh_ref: WeakRef = entry.get("mesh_ref", null) as WeakRef
		if mesh_ref == null:
			continue
		var mesh_instance: MeshInstance3D = mesh_ref.get_ref() as MeshInstance3D
		if mesh_instance == null:
			continue

		if bool(entry.get("uses_material_override", false)):
			mesh_instance.material_override = entry.get("material", null) as Material
		else:
			var surface_index: int = int(entry.get("surface_index", _INVALID_SURFACE_INDEX))
			if _is_valid_surface_index(mesh_instance, surface_index):
				mesh_instance.set_surface_override_material(surface_index, entry.get("material", null) as Material)

	_original_material_entries.clear()
	_original_slot_keys.clear()


func _find_body_slots() -> Array[MaterialSlot]:
	var target_root: Node = _resolve_target_root()
	if target_root == null:
		push_warning("CarSkinApplier: no target root assigned")
		return []

	var mesh_instances: Array[MeshInstance3D] = _collect_mesh_instances(target_root)
	if mesh_instances.is_empty():
		push_warning("CarSkinApplier: target root has no MeshInstance3D descendants")
		return []

	var visible_meshes: Array[MeshInstance3D] = []
	for mesh_instance: MeshInstance3D in mesh_instances:
		if _is_effectively_visible(mesh_instance, target_root):
			visible_meshes.append(mesh_instance)

	var material_matches: Array[MaterialSlot] = _find_material_name_matches(visible_meshes, target_root)
	if not material_matches.is_empty():
		return material_matches

	var fallback_slots: Array[MaterialSlot] = _find_fallback_slots(mesh_instances, visible_meshes, target_root)
	if fallback_slots.is_empty():
		return []

	push_warning(
		"CarSkinApplier: no visible body material names matched %s; using fallback mesh '%s'. Configure body_material_name_hints if this targets the wrong part."
		% [str(body_material_name_hints), fallback_slots[0].mesh_instance.get_path()]
	)
	return fallback_slots


func _find_material_name_matches(mesh_instances: Array[MeshInstance3D], target_root: Node) -> Array[MaterialSlot]:
	var matches: Array[MaterialSlot] = []
	for mesh_instance: MeshInstance3D in mesh_instances:
		if _node_or_ancestor_has_non_body_name(mesh_instance, target_root):
			continue

		if mesh_instance.material_override != null:
			var override_names: Array[String] = _names_for_material(mesh_instance.material_override, mesh_instance, _INVALID_SURFACE_INDEX)
			if _matches_body_names(override_names):
				matches.append(MaterialSlot.new(mesh_instance, _INVALID_SURFACE_INDEX, true))
			continue

		var surface_count: int = _surface_count(mesh_instance)
		for surface_index: int in range(surface_count):
			var material: Material = _surface_source_material(mesh_instance, surface_index)
			var names: Array[String] = _names_for_material(material, mesh_instance, surface_index)
			if _matches_body_names(names):
				matches.append(MaterialSlot.new(mesh_instance, surface_index, false))
	return matches


func _find_fallback_slots(
	mesh_instances: Array[MeshInstance3D],
	visible_meshes: Array[MeshInstance3D],
	target_root: Node
) -> Array[MaterialSlot]:
	var fallback_mesh: MeshInstance3D = _find_visible_mesh_by_fallback_hint(visible_meshes, target_root)
	if fallback_mesh == null:
		fallback_mesh = _find_placeholder_body_mesh(mesh_instances)
	if fallback_mesh == null:
		fallback_mesh = _first_conservative_visible_mesh(visible_meshes, target_root)
	if fallback_mesh == null:
		push_warning("CarSkinApplier: no conservative fallback mesh found")
		return []

	var slot: MaterialSlot = _fallback_slot_for_mesh(fallback_mesh)
	if slot == null:
		push_warning("CarSkinApplier: fallback mesh '%s' has no material surfaces to modify" % fallback_mesh.get_path())
		return []
	return [slot]


func _find_visible_mesh_by_fallback_hint(mesh_instances: Array[MeshInstance3D], target_root: Node) -> MeshInstance3D:
	for hint: String in fallback_mesh_name_hints:
		for mesh_instance: MeshInstance3D in mesh_instances:
			if _node_or_ancestor_matches_hint(mesh_instance, target_root, [hint]):
				if not _node_or_ancestor_has_non_body_name(mesh_instance, target_root):
					return mesh_instance
	return null


func _find_placeholder_body_mesh(mesh_instances: Array[MeshInstance3D]) -> MeshInstance3D:
	for mesh_instance: MeshInstance3D in mesh_instances:
		if mesh_instance.name.to_lower() == "body":
			return mesh_instance
	return null


func _first_conservative_visible_mesh(mesh_instances: Array[MeshInstance3D], target_root: Node) -> MeshInstance3D:
	for mesh_instance: MeshInstance3D in mesh_instances:
		if not _node_or_ancestor_has_non_body_name(mesh_instance, target_root):
			return mesh_instance
	return null


func _fallback_slot_for_mesh(mesh_instance: MeshInstance3D) -> MaterialSlot:
	if not preserve_non_body_materials:
		return MaterialSlot.new(mesh_instance, _INVALID_SURFACE_INDEX, true)

	if mesh_instance.material_override != null:
		return MaterialSlot.new(mesh_instance, _INVALID_SURFACE_INDEX, true)

	var surface_count: int = _surface_count(mesh_instance)
	if surface_count <= 0:
		return null

	for surface_index: int in range(surface_count):
		var material: Material = _surface_source_material(mesh_instance, surface_index)
		var names: Array[String] = _names_for_material(material, mesh_instance, surface_index)
		if not _matches_non_body_names(names):
			return MaterialSlot.new(mesh_instance, surface_index, false)

	return MaterialSlot.new(mesh_instance, 0, false)


func _assign_slot_material(slot: MaterialSlot, material: Material) -> void:
	if slot == null or slot.mesh_instance == null or material == null:
		return

	_store_original_slot(slot)
	if slot.uses_material_override:
		slot.mesh_instance.material_override = material
	else:
		slot.mesh_instance.set_surface_override_material(slot.surface_index, material)


func _store_original_slot(slot: MaterialSlot) -> void:
	var key: String = _slot_key(slot)
	if _original_slot_keys.has(key):
		return

	var original_material: Material = null
	if slot.uses_material_override:
		original_material = slot.mesh_instance.material_override
	else:
		original_material = slot.mesh_instance.get_surface_override_material(slot.surface_index)

	_original_slot_keys[key] = true
	_original_material_entries.append({
		"mesh_ref": weakref(slot.mesh_instance),
		"surface_index": slot.surface_index,
		"uses_material_override": slot.uses_material_override,
		"material": original_material,
	})


func _slot_key(slot: MaterialSlot) -> String:
	return "%d:%d:%s" % [slot.mesh_instance.get_instance_id(), slot.surface_index, str(slot.uses_material_override)]


func _material_with_texture(source_material: Material, texture: Texture2D) -> Material:
	var material: Material = _duplicate_or_default_material(source_material)
	if material is BaseMaterial3D:
		var base_material := material as BaseMaterial3D
		base_material.albedo_texture = texture
		base_material.albedo_color = Color.WHITE
		base_material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		return _named_preview_material(base_material, source_material, "Texture")

	if material is ShaderMaterial:
		var shader_material := material as ShaderMaterial
		if _try_set_shader_parameter(shader_material, _SHADER_TEXTURE_PARAMETER_HINTS, texture):
			_try_set_shader_parameter(shader_material, _SHADER_COLOR_PARAMETER_HINTS, Color.WHITE)
			return _named_preview_material(shader_material, source_material, "Texture")
		push_warning("CarSkinApplier: shader material has no recognized albedo texture parameter; replacing it with StandardMaterial3D")

	var standard_material: StandardMaterial3D = _new_standard_body_material()
	standard_material.albedo_texture = texture
	standard_material.albedo_color = Color.WHITE
	standard_material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	return _named_preview_material(standard_material, source_material, "Texture")


func _material_with_color(source_material: Material, color: Color, metallic: float, roughness: float) -> Material:
	var material: Material = _duplicate_or_default_material(source_material)
	if material is BaseMaterial3D:
		var base_material := material as BaseMaterial3D
		base_material.albedo_texture = null
		base_material.albedo_color = color
		base_material.metallic = metallic
		base_material.roughness = roughness
		return _named_preview_material(base_material, source_material, "Color")

	if material is ShaderMaterial:
		var shader_material := material as ShaderMaterial
		var applied_color: bool = _try_set_shader_parameter(shader_material, _SHADER_COLOR_PARAMETER_HINTS, color)
		_try_set_shader_parameter(shader_material, _SHADER_METALLIC_PARAMETER_HINTS, metallic)
		_try_set_shader_parameter(shader_material, _SHADER_ROUGHNESS_PARAMETER_HINTS, roughness)
		if applied_color:
			return _named_preview_material(shader_material, source_material, "Color")
		push_warning("CarSkinApplier: shader material has no recognized body color parameter; replacing it with StandardMaterial3D")

	var standard_material: StandardMaterial3D = _new_standard_body_material()
	standard_material.albedo_color = color
	standard_material.metallic = metallic
	standard_material.roughness = roughness
	return _named_preview_material(standard_material, source_material, "Color")


func _duplicate_or_default_material(source_material: Material) -> Material:
	if source_material != null:
		var duplicate := source_material.duplicate() as Material
		if duplicate != null:
			return duplicate
	return _new_standard_body_material()


func _new_standard_body_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = "LiveRepaintBodyMaterial"
	material.metallic = _DEFAULT_METALLIC
	material.roughness = _DEFAULT_ROUGHNESS
	return material


func _named_preview_material(material: Material, source_material: Material, suffix: String) -> Material:
	var source_name: String = "BodyMaterial"
	if source_material != null and not source_material.resource_name.is_empty():
		source_name = source_material.resource_name
	material.resource_name = "%s_LiveRepaint%s" % [source_name, suffix]
	return material


func _try_set_shader_parameter(shader_material: ShaderMaterial, parameter_hints: Array[String], value: Variant) -> bool:
	if shader_material.shader == null:
		return false

	var uniform_list: Array = shader_material.shader.get_shader_uniform_list()
	for uniform: Dictionary in uniform_list:
		var uniform_name: String = String(uniform.get("name", ""))
		if _matches_any_hint(uniform_name, parameter_hints):
			shader_material.set_shader_parameter(StringName(uniform_name), value)
			return true
	return false


func _current_slot_material(slot: MaterialSlot) -> Material:
	if slot == null or slot.mesh_instance == null:
		return null
	if slot.uses_material_override:
		return slot.mesh_instance.material_override
	return _surface_source_material(slot.mesh_instance, slot.surface_index)


func _surface_source_material(mesh_instance: MeshInstance3D, surface_index: int) -> Material:
	if not _is_valid_surface_index(mesh_instance, surface_index):
		return null

	var surface_override: Material = mesh_instance.get_surface_override_material(surface_index)
	if surface_override != null:
		return surface_override

	if mesh_instance.mesh == null:
		return null
	return mesh_instance.mesh.surface_get_material(surface_index)


func _names_for_material(material: Material, mesh_instance: MeshInstance3D, surface_index: int) -> Array[String]:
	var names: Array[String] = [mesh_instance.name]
	if material != null:
		if not material.resource_name.is_empty():
			names.append(material.resource_name)
		if not material.resource_path.is_empty():
			names.append(material.resource_path.get_file().get_basename())

	if _is_valid_surface_index(mesh_instance, surface_index):
		var surface_name: String = mesh_instance.mesh.surface_get_name(surface_index)
		if not surface_name.is_empty():
			names.append(surface_name)
	return names


func _matches_body_names(names: Array[String]) -> bool:
	return _matches_any_name(names, body_material_name_hints) and not _matches_non_body_names(names)


func _matches_non_body_names(names: Array[String]) -> bool:
	return _matches_any_name(names, _NON_BODY_NAME_HINTS)


func _matches_any_name(names: Array[String], hints: Array[String]) -> bool:
	for name: String in names:
		if _matches_any_hint(name, hints):
			return true
	return false


func _matches_any_hint(name: String, hints: Array[String]) -> bool:
	var normalized_name: String = name.to_lower()
	for hint: String in hints:
		var normalized_hint: String = hint.to_lower()
		if normalized_hint.is_empty():
			continue
		if normalized_name.find(normalized_hint) >= 0:
			return true
	return false


func _node_or_ancestor_has_non_body_name(mesh_instance: MeshInstance3D, target_root: Node) -> bool:
	var node: Node = mesh_instance
	while node != null:
		if _matches_any_hint(node.name, _NON_BODY_NAME_HINTS):
			return true
		if node == target_root:
			break
		node = node.get_parent()
	return false


func _node_or_ancestor_matches_hint(mesh_instance: MeshInstance3D, target_root: Node, hints: Array[String]) -> bool:
	var node: Node = mesh_instance
	while node != null:
		if _matches_any_hint(node.name, hints):
			return true
		if node == target_root:
			break
		node = node.get_parent()
	return false


func _collect_mesh_instances(root: Node) -> Array[MeshInstance3D]:
	var mesh_instances: Array[MeshInstance3D] = []
	_collect_mesh_instances_recursive(root, mesh_instances)
	return mesh_instances


func _collect_mesh_instances_recursive(node: Node, mesh_instances: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		mesh_instances.append(node as MeshInstance3D)
	for child: Node in node.get_children():
		_collect_mesh_instances_recursive(child, mesh_instances)


func _surface_count(mesh_instance: MeshInstance3D) -> int:
	if mesh_instance.mesh == null:
		return 0
	return mesh_instance.mesh.get_surface_count()


func _is_valid_surface_index(mesh_instance: MeshInstance3D, surface_index: int) -> bool:
	return mesh_instance != null and mesh_instance.mesh != null and surface_index >= 0 and surface_index < mesh_instance.mesh.get_surface_count()


func _is_effectively_visible(mesh_instance: MeshInstance3D, target_root: Node) -> bool:
	var node: Node = mesh_instance
	while node != null:
		if node is Node3D and not (node as Node3D).visible:
			return false
		if node == target_root:
			return true
		node = node.get_parent()
	return true


func _resolve_target_root() -> Node:
	if is_instance_valid(_target_root):
		return _target_root

	if String(target_root_path).is_empty():
		return null

	_target_root = get_node_or_null(target_root_path)
	return _target_root
