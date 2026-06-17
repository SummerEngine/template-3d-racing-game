class_name GeneratedPropBulkOperations
extends RefCounted

const GeneratedPropOverrideHelperScript := preload("res://scripts/track_authoring/generated_props/generated_prop_override_helper.gd")
const GeneratedPropStateScript := preload("res://scripts/track_authoring/generated_props/generated_prop_state.gd")
const GeneratedPropValidatorScript := preload("res://scripts/track_authoring/generated_props/generated_prop_validator.gd")

const STATE_META_KEY: StringName = &"generated_prop_state"


static func reset_selected(selected_items: Array) -> Dictionary:
	var changed_count: int = 0
	var skipped_count: int = 0
	for item: Variant in selected_items:
		var state: GeneratedPropStateScript = get_state(item)
		if state == null:
			skipped_count += 1
			continue
		state.reset_override()
		changed_count += 1
	return _summary(changed_count, skipped_count)


static func reset_all_overrides(prop_items: Array) -> Dictionary:
	return reset_selected(prop_items)


static func reset_all_props_from_rule(prop_items: Array, generator_rule_id: StringName) -> Dictionary:
	var changed_count: int = 0
	var skipped_count: int = 0
	for item: Variant in prop_items:
		var state: GeneratedPropStateScript = get_state(item)
		if state == null:
			skipped_count += 1
			continue
		if state.generator_rule_id != generator_rule_id:
			continue
		state.reset_override()
		changed_count += 1
	return _summary(changed_count, skipped_count)


static func convert_selected_road_relative(selected_items: Array, road_edge_provider: Object) -> Dictionary:
	var changed_count: int = 0
	var skipped_count: int = 0
	for item: Variant in selected_items:
		var state: GeneratedPropStateScript = get_state(item)
		var transform: Transform3D = get_world_transform(item)
		if state == null or road_edge_provider == null:
			skipped_count += 1
			continue
		if not GeneratedPropOverrideHelperScript.store_road_relative_override_from_transform(state, transform, road_edge_provider):
			skipped_count += 1
			continue
		changed_count += 1
	return _summary(changed_count, skipped_count)


static func convert_selected_world_locked(selected_items: Array) -> Dictionary:
	var changed_count: int = 0
	var skipped_count: int = 0
	for item: Variant in selected_items:
		var state: GeneratedPropStateScript = get_state(item)
		if state == null:
			skipped_count += 1
			continue
		state.set_world_locked(get_world_transform(item))
		changed_count += 1
	return _summary(changed_count, skipped_count)


static func validate_generated_props(
	prop_items: Array,
	road_edge_provider: Object,
	minimum_clearance_m: float = GeneratedPropValidatorScript.DEFAULT_MINIMUM_CLEARANCE_M
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for item: Variant in prop_items:
		var state: GeneratedPropStateScript = get_state(item)
		var node: Node3D = get_node(item)
		if node != null:
			results.append(GeneratedPropValidatorScript.validate_node(node, state, road_edge_provider, minimum_clearance_m))
		elif state != null:
			results.append(GeneratedPropValidatorScript.validate_state(state, road_edge_provider, minimum_clearance_m))
	return results


static func snap_invalid_props_back_outside_road_edge(
	prop_items: Array,
	road_edge_provider: Object,
	minimum_clearance_m: float = GeneratedPropValidatorScript.DEFAULT_MINIMUM_CLEARANCE_M
) -> Dictionary:
	var changed_count: int = 0
	var skipped_count: int = 0
	for item: Variant in prop_items:
		var state: GeneratedPropStateScript = get_state(item)
		var node: Node3D = get_node(item)
		if state == null:
			skipped_count += 1
			continue

		var result: Dictionary
		if node != null:
			result = GeneratedPropValidatorScript.validate_node(node, state, road_edge_provider, minimum_clearance_m)
		else:
			result = GeneratedPropValidatorScript.validate_state(state, road_edge_provider, minimum_clearance_m)

		if bool(result.get("valid", false)):
			continue

		var snap_transform: Transform3D = GeneratedPropValidatorScript.snap_back_transform(result)
		if node != null:
			node.global_transform = snap_transform

		if GeneratedPropOverrideHelperScript.store_road_relative_override_from_transform(state, snap_transform, road_edge_provider):
			changed_count += 1
		else:
			skipped_count += 1

	return _summary(changed_count, skipped_count)


static func get_state(item: Variant) -> GeneratedPropStateScript:
	if item is GeneratedPropStateScript:
		return item
	if item is Object and item.has_meta(STATE_META_KEY):
		var state_value: Variant = item.get_meta(STATE_META_KEY)
		if state_value is GeneratedPropStateScript:
			return state_value
	return null


static func get_node(item: Variant) -> Node3D:
	return item if item is Node3D else null


static func get_world_transform(item: Variant) -> Transform3D:
	if item is Node3D:
		return item.global_transform

	var state: GeneratedPropStateScript = get_state(item)
	if state != null:
		return state.world_locked_transform

	return Transform3D.IDENTITY


static func _summary(changed_count: int, skipped_count: int) -> Dictionary:
	return {
		"changed_count": changed_count,
		"skipped_count": skipped_count,
	}
