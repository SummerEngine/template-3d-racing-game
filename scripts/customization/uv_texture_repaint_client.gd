class_name UVTextureRepaintClient
extends RepaintClient

signal repaint_preview_ready(preview_result: Dictionary)
signal preview_ready(preview_result: Dictionary)

@export var source_texture_url: String = ""
@export_file("*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp", "*.tga") var source_texture_path: String = "res://assets/cars/player_hypercar_Image_0.jpg"
@export_range(0.0, 1.0, 0.01) var strength: float = 0.65
@export var dry_run: bool = true


func _ready() -> void:
	super._ready()
	repaint_succeeded.connect(_on_texture_repaint_succeeded)


func request_repaint_preview(prompt: String = "", options: Dictionary = {}) -> int:
	return submit_texture_repaint(
		prompt,
		_texture_url_from_options(options),
		_texture_path_from_options(options),
		_strength_from_options(options),
		_dry_run_from_options(options)
	)


func generate_repaint_preview(prompt: String = "", options: Dictionary = {}) -> int:
	return request_repaint_preview(prompt, options)


func submit_texture_repaint(
	prompt: String,
	texture_url: String = "",
	texture_path: String = "",
	repaint_strength: float = -1.0,
	force_dry_run: bool = true
) -> int:
	_ensure_children()

	if has_active_job() or not _request_kind.is_empty():
		_emit_failure(_active_job_id, "A UV texture repaint request is already in progress.")
		return ERR_BUSY

	var clean_prompt := prompt.strip_edges()
	if clean_prompt.is_empty():
		_emit_failure("", "UV texture repaint prompt cannot be empty.")
		return ERR_INVALID_PARAMETER

	var clean_texture_url := texture_url.strip_edges()
	var clean_texture_path := texture_path.strip_edges()
	if clean_texture_url.is_empty() and clean_texture_path.is_empty():
		clean_texture_url = source_texture_url.strip_edges()
		clean_texture_path = source_texture_path.strip_edges()

	if not clean_texture_url.is_empty():
		clean_texture_path = ""
	if clean_texture_url.is_empty() and clean_texture_path.is_empty():
		_emit_failure("", "UV texture repaint needs source_texture_url or source_texture_path.")
		return ERR_INVALID_PARAMETER

	var payload: Dictionary = {
		"prompt": clean_prompt,
		"strength": clampf(repaint_strength if repaint_strength >= 0.0 else strength, 0.0, 1.0),
		"dry_run": force_dry_run,
		"mode": "uv_texture_img2img",
	}
	if clean_texture_url.is_empty():
		payload["texture_path"] = clean_texture_path
	else:
		payload["texture_url"] = clean_texture_url

	return _start_api_request(
		"submit",
		_build_url("/api/repaint-texture"),
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)


func _request_job_status(job_id: String) -> int:
	return _start_api_request(
		"poll",
		_build_url("/api/repaint-texture/%s" % job_id.uri_encode()),
		HTTPClient.METHOD_GET
	)


func _on_texture_repaint_succeeded(job_id: String, result: Dictionary) -> void:
	var preview_result: Dictionary = result.duplicate(true)
	preview_result["mode"] = "uv_texture_img2img"
	preview_result["job_id"] = job_id
	repaint_preview_ready.emit(preview_result)
	preview_ready.emit(preview_result)


func _texture_url_from_options(options: Dictionary) -> String:
	var value: Variant = options.get("texture_url", source_texture_url)
	return String(value) if typeof(value) == TYPE_STRING else source_texture_url


func _texture_path_from_options(options: Dictionary) -> String:
	var value: Variant = options.get("texture_path", source_texture_path)
	return String(value) if typeof(value) == TYPE_STRING else source_texture_path


func _strength_from_options(options: Dictionary) -> float:
	var value: Variant = options.get("strength", options.get("repaint_strength", strength))
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return clampf(float(value), 0.0, 1.0)
	return strength


func _dry_run_from_options(options: Dictionary) -> bool:
	var value: Variant = options.get("dry_run", dry_run)
	if typeof(value) == TYPE_BOOL:
		return bool(value)
	return dry_run
