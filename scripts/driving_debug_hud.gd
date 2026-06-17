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
	label.text = "Speed %03d km/h\nMode %s\nW/Up accelerate  S/Down brake/reverse\nA/D steer while moving  Shift drift" % [
		speed_kmh,
		drift_text,
	]


func _has_property(node: Node, property_name: StringName) -> bool:
	for property: Dictionary in node.get_property_list():
		if String(property.get("name", "")) == String(property_name):
			return true
	return false
