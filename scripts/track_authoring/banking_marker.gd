@tool
class_name BankingMarker
extends "res://scripts/track_authoring/track_authoring_marker.gd"

enum BankingBlendMode { STEP, LINEAR, SMOOTH }

@export_range(-45.0, 45.0, 0.1) var target_bank_degrees: float = 0.0
@export_range(0.0, 250.0, 0.1) var blend_before_m: float = 35.0
@export_range(0.0, 250.0, 0.1) var blend_after_m: float = 35.0
@export var blend_mode: BankingBlendMode = BankingBlendMode.SMOOTH
@export var preserve_road_normal: bool = true


func get_marker_kind() -> StringName:
	return &"banking_marker"


func get_authoring_record() -> Dictionary:
	var record: Dictionary = super.get_authoring_record()
	record.merge({
		"target_bank_degrees": target_bank_degrees,
		"blend_before_m": blend_before_m,
		"blend_after_m": blend_after_m,
		"blend_mode": BankingBlendMode.keys()[blend_mode],
		"preserve_road_normal": preserve_road_normal,
	}, true)
	return record
