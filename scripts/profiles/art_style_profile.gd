class_name ArtStyleProfile
extends Resource

@export var style_id: StringName = &""
@export var display_name: String = ""
@export var realism_target: StringName = &"premium_arcade_realism"
@export var style_tags: PackedStringArray = PackedStringArray()
@export var palette: Dictionary = {}
@export var material_language: Dictionary = {}
@export var readability_targets: Dictionary = {}
@export var forbidden_style_tags: PackedStringArray = PackedStringArray()
@export_multiline var intent: String = ""
@export_multiline var notes: String = ""


func get_profile_id() -> StringName:
	return style_id


func has_style_tag(tag: StringName) -> bool:
	return style_tags.has(String(tag))


func forbids_style_tag(tag: StringName) -> bool:
	return forbidden_style_tags.has(String(tag))
