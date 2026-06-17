@tool
class_name TrackAuthoringProfile
extends Resource

@export var track_id: StringName = &"storm_coast"
@export var display_name: String = "Storm Coast Circuit"
@export var authoring_scene_path: String = "res://scenes/tracks/storm_coast/storm_coast_authoring.tscn"
@export_range(100.0, 10000.0, 1.0) var target_length_m: float = 1100.0
@export_range(1, 12, 1) var lap_count: int = 3
@export_range(4.0, 32.0, 0.1) var default_road_width_m: float = 12.5
@export_range(1, 6, 1) var lane_count: int = 2
@export var closed_loop: bool = true

@export_group("Profiles")
@export var environment_kit_id: StringName = &"mountain_coastal_wet"
@export var road_surface_profile_id: StringName = &"wet_asphalt"
@export var weather_profile_id: StringName = &"light_rain_wet_road"
@export var lighting_profile_id: StringName = &"storm_late_afternoon"
@export var music_profile_id: StringName = &"storm_coast_race"

@export_group("Authoring Branches")
@export var authoring_branch: NodePath = NodePath("Authoring")
@export var generated_branch: NodePath = NodePath("Generated")
@export var manual_overrides_branch: NodePath = NodePath("ManualOverrides")
@export var set_pieces_branch: NodePath = NodePath("SetPieces")

@export_group("Tool State")
@export var tool_api_version: StringName = &"storm_coast_authoring_v1"
@export var preview_resource_path: String = "res://resources/tracks/storm_coast/storm_coast_preview_snapshot.tres"
@export_multiline var last_tool_summary: String = "No authoring tool action has run yet."
@export var frozen_final: bool = false
@export_multiline var notes: String = ""


func get_tool_api_names() -> PackedStringArray:
	return PackedStringArray([
		"preview_regenerate",
		"bake_editable",
		"freeze_final",
	])


func get_branch_paths() -> Dictionary:
	return {
		"authoring": authoring_branch,
		"generated": generated_branch,
		"manual_overrides": manual_overrides_branch,
		"set_pieces": set_pieces_branch,
	}


func validate_marker_counts(marker_counts: Dictionary) -> PackedStringArray:
	var warnings := PackedStringArray()
	if int(marker_counts.get("road_points", 0)) < 5:
		warnings.append("Storm Coast needs at least 5 RoadPoint markers for the first authoring slice.")
	if int(marker_counts.get("width_markers", 0)) < 1:
		warnings.append("Add at least one WidthMarker to prove variable road width.")
	if int(marker_counts.get("banking_markers", 0)) < 1:
		warnings.append("Add at least one BankingMarker to prove banked sections.")
	if int(marker_counts.get("elevation_markers", 0)) < 1:
		warnings.append("Add at least one ElevationMarker to prove vertical variation.")
	if int(marker_counts.get("start_grid_markers", 0)) < 1:
		warnings.append("Add a StartGridMarker for preset spawn slots.")
	if int(marker_counts.get("set_piece_markers", 0)) < 1:
		warnings.append("Add a SetPieceMarker for the cliffside jump socket.")
	return warnings
