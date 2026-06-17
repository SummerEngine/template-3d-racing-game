class_name CarVisualProfile
extends Resource

@export var car_id: StringName = &""
@export var display_name: String = ""
@export var vehicle_class: StringName = &""
@export var body_material: Resource = null
@export var glass_material: Resource = null
@export var wheel_material: Resource = null
@export var damage_decal_material: Resource = null
@export var primary_paint_color: Color = Color(0.03, 0.04, 0.05, 1.0)
@export var secondary_paint_color: Color = Color(0.08, 0.12, 0.16, 1.0)
@export var emissive_accent_color: Color = Color(0.15, 0.62, 1.0, 1.0)
@export_range(0.0, 8.0, 0.01) var accent_emission_energy: float = 1.8
@export var silhouette_tags: PackedStringArray = PackedStringArray()
@export var material_tags: PackedStringArray = PackedStringArray()
@export var livery_slots: Dictionary = {}
@export_enum("none", "blocked_placeholder", "driver_readable", "full") var cockpit_detail_level: String = "blocked_placeholder"
@export_multiline var notes: String = ""


func get_profile_id() -> StringName:
	return car_id


func has_material_tag(tag: StringName) -> bool:
	return material_tags.has(String(tag))


func has_silhouette_tag(tag: StringName) -> bool:
	return silhouette_tags.has(String(tag))
