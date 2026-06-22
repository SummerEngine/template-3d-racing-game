extends CanvasLayer

@export var car_path: NodePath

@onready var label: Label = $Margin/Panel/Margin/Readout

var _car: Node


func _ready() -> void:
	_car = get_node_or_null(car_path)


func _process(_delta: float) -> void:
	if _car == null:
		return

	var speed: float = 0.0
	if _car.has_method("get_speed"):
		speed = float(_car.call("get_speed"))
	var speed_kmh: int = roundi(speed * 3.6)
	var drifting: bool = false
	if _has_property(_car, &"is_drifting"):
		drifting = bool(_car.get("is_drifting"))
	var drift_text: String = "DRIFT" if drifting else "GRIP"
	var throttle: float = _car_float("get_throttle_amount", &"throttle_amount")
	var brake: float = _car_float("get_brake_amount", &"brake_amount")
	var steer: float = _car_float("get_steering_input", &"steering_input")
	var drift_intensity: float = _car_float("get_drift_intensity", &"drift_intensity")
	var current_gear: int = roundi(_car_float("get_current_gear", &"current_gear", 1.0))
	var gear_limit_kmh: int = roundi(_car_float("get_current_gear_speed_limit_kmh", &"gear_speed_limit_kmh", 0.0))
	var controls_text: String = "ON" if _car_bool("are_controls_enabled", &"controls_enabled", true) else "OFF"
	var input_device: String = _car_text("get_last_input_device", "none").to_upper()
	label.text = "Speed %03d km/h\nMode %s  Drift %.0f%%\nInput %s  Controls %s\nGear %d  Limit %03d km/h\nThrottle %03d  Brake %03d  Steer %+03d\nW/Up accelerate  S/Down brake/reverse\nA/D steer  Shift drift  Q/E gears" % [
		speed_kmh,
		drift_text,
		drift_intensity * 100.0,
		input_device,
		controls_text,
		current_gear,
		gear_limit_kmh,
		roundi(throttle * 100.0),
		roundi(brake * 100.0),
		roundi(steer * 100.0),
	]


func _has_property(node: Node, property_name: StringName) -> bool:
	for property: Dictionary in node.get_property_list():
		if String(property.get("name", "")) == String(property_name):
			return true
	return false


func _car_float(method_name: StringName, property_name: StringName, fallback: float = 0.0) -> float:
	if _car.has_method(method_name):
		var method_value: Variant = _car.call(method_name)
		if method_value is float or method_value is int:
			return float(method_value)
	if _has_property(_car, property_name):
		var property_value: Variant = _car.get(property_name)
		if property_value is float or property_value is int:
			return float(property_value)
	return fallback


func _car_bool(method_name: StringName, property_name: StringName, fallback: bool = false) -> bool:
	if _car.has_method(method_name):
		var method_value: Variant = _car.call(method_name)
		if method_value is bool:
			return bool(method_value)
	if _has_property(_car, property_name):
		var property_value: Variant = _car.get(property_name)
		if property_value is bool:
			return bool(property_value)
	return fallback


func _car_text(method_name: StringName, fallback: String = "") -> String:
	if _car.has_method(method_name):
		return String(_car.call(method_name))
	return fallback
