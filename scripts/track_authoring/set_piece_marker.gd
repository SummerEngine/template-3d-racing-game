@tool
class_name SetPieceMarker
extends "res://scripts/track_authoring/track_authoring_marker.gd"

enum SetPieceKind { JUMP, LOOP, WALL_RIDE, TUNNEL, BRIDGE, LANDMARK }
enum SocketAnchorMode { ROAD_DISTANCE, WORLD_LOCKED, SOCKET_LOCKED }

@export var set_piece_id: StringName = &"cliffside_jump_01"
@export var set_piece_kind: SetPieceKind = SetPieceKind.JUMP
@export_file("*.tscn") var scene_path: String = ""
@export var entry_socket: StringName = &"EntrySocket"
@export var exit_socket: StringName = &"ExitSocket"
@export var landing_socket: StringName = &"LandingSocket"
@export var reset_zone_socket: StringName = &"ResetZone"
@export var anchor_mode: SocketAnchorMode = SocketAnchorMode.ROAD_DISTANCE
@export_range(0.0, 120.0, 0.1) var min_speed_mps: float = 38.0
@export var recommended_camera_mode: StringName = &"chase"
@export var surface_gravity_mode: StringName = &"track_relative"
@export_range(0, 5, 1) var risk_rating: int = 3
@export var blocks_generator_through_span: bool = true


func get_marker_kind() -> StringName:
	return &"set_piece_marker"


func get_socket_record(socket_name: StringName) -> Dictionary:
	return {
		"set_piece_id": set_piece_id,
		"socket": socket_name,
		"anchor_mode": SocketAnchorMode.keys()[anchor_mode],
		"marker_transform": global_transform,
	}


func get_authoring_record() -> Dictionary:
	var record: Dictionary = super.get_authoring_record()
	record.merge({
		"set_piece_id": set_piece_id,
		"set_piece_kind": SetPieceKind.keys()[set_piece_kind],
		"scene_path": scene_path,
		"entry_socket": entry_socket,
		"exit_socket": exit_socket,
		"landing_socket": landing_socket,
		"reset_zone_socket": reset_zone_socket,
		"anchor_mode": SocketAnchorMode.keys()[anchor_mode],
		"min_speed_mps": min_speed_mps,
		"recommended_camera_mode": recommended_camera_mode,
		"surface_gravity_mode": surface_gravity_mode,
		"risk_rating": risk_rating,
		"blocks_generator_through_span": blocks_generator_through_span,
	}, true)
	return record
