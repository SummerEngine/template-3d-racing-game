class_name RoadSurfaceProfile
extends Resource

enum SurfaceKind {
	ASPHALT,
	WET_ASPHALT,
	BRIDGE,
	TUNNEL,
	RAMP,
	JUMP,
}

@export var surface_id: StringName = &""
@export var display_name: String = ""
@export var surface_kind: SurfaceKind = SurfaceKind.WET_ASPHALT
@export var material_key: StringName = &""
@export var base_material: Resource = null
@export var skid_decal_material: Resource = null
@export var scrape_decal_material: Resource = null
@export_range(0.1, 2.0, 0.001) var grip_multiplier: float = 0.92
@export_range(0.0, 1.0, 0.001) var wetness: float = 0.85
@export_range(0.0, 1.0, 0.001) var reflection_strength: float = 0.72
@export_range(0.1, 32.0, 0.01) var uv_meters_per_tile: float = 8.0
@export_range(0.0, 1.0, 0.001) var lane_marking_contrast: float = 0.82
@export var supports_tire_spray: bool = true
@export var supports_scrape_decals: bool = true
@export var surface_tags: PackedStringArray = PackedStringArray()
@export_multiline var notes: String = ""


func get_profile_id() -> StringName:
	return surface_id


func get_surface_type_name() -> StringName:
	match surface_kind:
		SurfaceKind.ASPHALT:
			return &"asphalt"
		SurfaceKind.WET_ASPHALT:
			return &"wet_asphalt"
		SurfaceKind.BRIDGE:
			return &"bridge"
		SurfaceKind.TUNNEL:
			return &"tunnel"
		SurfaceKind.RAMP:
			return &"ramp"
		SurfaceKind.JUMP:
			return &"jump"
	return &""


func is_wet() -> bool:
	return wetness > 0.0
