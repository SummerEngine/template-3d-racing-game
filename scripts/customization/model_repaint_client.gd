class_name ModelRepaintClient
extends "res://scripts/customization/repaint_client.gd"

signal model_repaint_ready(preview_result: Dictionary)
signal repaint_preview_ready(preview_result: Dictionary)
signal preview_ready(preview_result: Dictionary)

@export var source_model_url: String = ""
@export_file("*.glb", "*.gltf", "*.obj") var source_model_path: String = "res://assets/cars/customizable_hypercar_model3.glb"


func _ready() -> void:
	super._ready()
	repaint_succeeded.connect(_on_model_repaint_succeeded)


func request_model_repaint(prompt: String = "", options: Dictionary = {}) -> int:
	return submit_model_repaint(
		prompt,
		_model_url_from_options(options),
		_model_path_from_options(options)
	)


func generate_model_repaint(prompt: String = "", options: Dictionary = {}) -> int:
	return request_model_repaint(prompt, options)


func submit_model_repaint(prompt: String, model_url: String = "", model_path: String = "") -> int:
	var clean_model_url := model_url.strip_edges()
	var clean_model_path := model_path.strip_edges()
	if clean_model_url.is_empty() and clean_model_path.is_empty():
		clean_model_url = source_model_url.strip_edges()
		clean_model_path = source_model_path.strip_edges()

	if not clean_model_url.is_empty():
		clean_model_path = ""

	return submit_repaint_from_source(prompt, clean_model_url, clean_model_path)


func _on_model_repaint_succeeded(job_id: String, result: Dictionary) -> void:
	var preview_result: Dictionary = result.duplicate(true)
	preview_result["mode"] = "model_retexture"
	preview_result["job_id"] = job_id
	model_repaint_ready.emit(preview_result)
	repaint_preview_ready.emit(preview_result)
	preview_ready.emit(preview_result)


func _model_url_from_options(options: Dictionary) -> String:
	var value: Variant = options.get("model_url", source_model_url)
	return String(value) if typeof(value) == TYPE_STRING else source_model_url


func _model_path_from_options(options: Dictionary) -> String:
	var value: Variant = options.get("model_path", source_model_path)
	return String(value) if typeof(value) == TYPE_STRING else source_model_path
