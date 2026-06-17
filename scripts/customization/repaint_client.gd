class_name RepaintClient
extends Node

signal repaint_submitted(job_id: String)
signal repaint_progress(job_id: String, status: String, progress: float, message: String)
signal repaint_succeeded(job_id: String, result: Dictionary)
signal repaint_failed(job_id: String, message: String)

@export var base_url: String = "http://127.0.0.1:8787"
@export_range(0.25, 30.0, 0.25, "or_greater") var poll_interval_s: float = 1.0
@export_range(1.0, 120.0, 0.5, "or_greater") var request_timeout_s: float = 15.0

const RepaintJobScript := preload("res://scripts/customization/repaint_job.gd")
const CACHE_DIR: String = "user://ai_repaint_cache"
const REQUEST_HEALTH: String = "health"
const REQUEST_SUBMIT: String = "submit"
const REQUEST_POLL: String = "poll"
const TEXTURE_URL_KEYS: Array[String] = [
	"base_color_url",
	"roughness_url",
	"metallic_url",
	"normal_url",
]
const DOWNLOAD_EXTENSIONS: Array[String] = [
	"png",
	"jpg",
	"jpeg",
	"webp",
	"bmp",
	"tga",
	"ktx",
	"exr",
]

var _request: HTTPRequest = null
var _poll_timer: Timer = null
var _request_kind: String = ""
var _active_job_id: String = ""


func _ready() -> void:
	_ensure_children()


func submit_repaint(prompt: String, model_url: String) -> int:
	_ensure_children()

	if has_active_job() or not _request_kind.is_empty():
		_emit_failure(_active_job_id, "A repaint request is already in progress.")
		return ERR_BUSY

	var clean_prompt := prompt.strip_edges()
	var clean_model_url := model_url.strip_edges()
	if clean_prompt.is_empty():
		_emit_failure("", "Repaint prompt cannot be empty.")
		return ERR_INVALID_PARAMETER
	if clean_model_url.is_empty():
		_emit_failure("", "Repaint model_url cannot be empty.")
		return ERR_INVALID_PARAMETER

	var payload := {
		"prompt": clean_prompt,
		"model_url": clean_model_url,
		"mode": "retexture",
	}
	var body := JSON.stringify(payload)
	return _start_api_request(
		REQUEST_SUBMIT,
		_build_url("/api/repaint"),
		HTTPClient.METHOD_POST,
		body
	)


func poll_repaint(job_id: String) -> int:
	_ensure_children()

	var clean_job_id := job_id.strip_edges()
	if clean_job_id.is_empty():
		_emit_failure("", "Cannot poll repaint status without a job id.")
		return ERR_INVALID_PARAMETER
	if not _request_kind.is_empty():
		_emit_failure(_active_job_id, "A repaint HTTP request is already in progress.")
		return ERR_BUSY
	if has_active_job() and _active_job_id != clean_job_id:
		_emit_failure(_active_job_id, "A different repaint job is already active.")
		return ERR_BUSY

	_active_job_id = clean_job_id
	_stop_poll_timer()
	return _request_job_status(clean_job_id)


func cancel_repaint() -> void:
	_stop_poll_timer()
	if _request != null and not _request_kind.is_empty():
		_request.cancel_request()
	_request_kind = ""
	_active_job_id = ""


func has_active_job() -> bool:
	return not _active_job_id.is_empty()


func check_health() -> bool:
	var response := await _request_url(
		_build_url("/health"),
		PackedStringArray(),
		HTTPClient.METHOD_GET,
		"",
		REQUEST_HEALTH
	)
	return bool(response["ok"])


func download_texture(url: String) -> String:
	var clean_url := url.strip_edges()
	if clean_url.is_empty():
		return ""

	var cache_error := _ensure_cache_dir()
	if cache_error != OK:
		_emit_failure(_active_job_id, "Could not create AI repaint cache directory.")
		return ""

	var target_path := _cache_path_for_url(clean_url)
	var response := await _request_url(
		clean_url,
		PackedStringArray(),
		HTTPClient.METHOD_GET,
		"",
		"download"
	)
	if not bool(response["ok"]):
		_emit_failure(_active_job_id, str(response["message"]))
		return ""

	var file := FileAccess.open(target_path, FileAccess.WRITE)
	if file == null:
		_emit_failure(_active_job_id, "Could not write downloaded repaint texture to cache.")
		return ""

	var body: PackedByteArray = response["body"]
	file.store_buffer(body)
	file.close()
	return target_path


func download_result_texture(result: Dictionary) -> String:
	if not result.has("base_color_url"):
		return ""
	if typeof(result["base_color_url"]) != TYPE_STRING:
		_emit_failure(_active_job_id, "Repaint result base_color_url is not a string.")
		return ""
	return await download_texture(String(result["base_color_url"]))


func download_result_textures(result: Dictionary) -> Dictionary:
	var downloaded: Dictionary = {}
	for key: String in TEXTURE_URL_KEYS:
		if not result.has(key) or result[key] == null:
			continue
		if typeof(result[key]) != TYPE_STRING:
			_emit_failure(_active_job_id, "Repaint result %s is not a string." % key)
			return {}

		var local_path := await download_texture(String(result[key]))
		if local_path.is_empty():
			return downloaded
		downloaded[key] = local_path
	return downloaded


func _ensure_children() -> void:
	if _request == null:
		_request = HTTPRequest.new()
		_request.name = "AIRepaintRequest"
		add_child(_request)
		_request.request_completed.connect(_on_request_completed)
	_request.timeout = request_timeout_s

	if _poll_timer == null:
		_poll_timer = Timer.new()
		_poll_timer.name = "AIRepaintPollTimer"
		_poll_timer.one_shot = true
		add_child(_poll_timer)
		_poll_timer.timeout.connect(_on_poll_timer_timeout)
	_poll_timer.wait_time = maxf(poll_interval_s, 0.01)


func _start_api_request(kind: String, url: String, method: HTTPClient.Method, body: String = "") -> int:
	var headers := PackedStringArray()
	if method == HTTPClient.METHOD_POST:
		headers.append("Content-Type: application/json")

	_request.timeout = request_timeout_s
	_request_kind = kind
	var error := _request.request(url, headers, method, body)
	if error != OK:
		_request_kind = ""
		_emit_failure(_active_job_id, "Could not start repaint HTTP request.")
	return error


func _request_job_status(job_id: String) -> int:
	return _start_api_request(
		REQUEST_POLL,
		_build_url("/api/repaint/%s" % job_id.uri_encode()),
		HTTPClient.METHOD_GET
	)


func _on_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	var kind := _request_kind
	_request_kind = ""

	if result != HTTPRequest.RESULT_SUCCESS:
		_emit_failure(_active_job_id, "Repaint proxy request failed before receiving a response.")
		_active_job_id = ""
		return
	if not _is_success_code(response_code):
		_emit_failure(_active_job_id, "Repaint proxy returned HTTP %d." % response_code)
		_active_job_id = ""
		return

	var parsed := _parse_json_body(body)
	if not bool(parsed["ok"]):
		_emit_failure(_active_job_id, str(parsed["message"]))
		_active_job_id = ""
		return

	var job = RepaintJobScript.from_variant(parsed["data"])
	if not job.is_valid():
		_emit_failure(_active_job_id, job.error_message)
		_active_job_id = ""
		return

	if kind == REQUEST_SUBMIT:
		_handle_submitted_job(job)
	elif kind == REQUEST_POLL:
		_handle_polled_job(job)


func _handle_submitted_job(job) -> void:
	_active_job_id = job.job_id
	repaint_submitted.emit(job.job_id)
	_emit_job_update(job)


func _handle_polled_job(job) -> void:
	if not _active_job_id.is_empty() and job.job_id != _active_job_id:
		_emit_failure(_active_job_id, "Repaint proxy returned a mismatched job id.")
		_active_job_id = ""
		return

	_active_job_id = job.job_id
	_emit_job_update(job)


func _emit_job_update(job) -> void:
	repaint_progress.emit(job.job_id, job.status, job.progress, job.message)

	if job.status == RepaintJobScript.STATUS_SUCCEEDED:
		repaint_succeeded.emit(job.job_id, job.result)
		_active_job_id = ""
	elif job.status == RepaintJobScript.STATUS_FAILED:
		_emit_failure(job.job_id, _job_failure_message(job))
		_active_job_id = ""
	elif job.is_pending():
		_schedule_poll()


func _schedule_poll() -> void:
	if _active_job_id.is_empty() or _poll_timer == null:
		return
	_poll_timer.wait_time = maxf(poll_interval_s, 0.01)
	_poll_timer.start()


func _stop_poll_timer() -> void:
	if _poll_timer != null:
		_poll_timer.stop()


func _on_poll_timer_timeout() -> void:
	if _active_job_id.is_empty():
		return
	if not _request_kind.is_empty():
		_schedule_poll()
		return

	var error := _request_job_status(_active_job_id)
	if error != OK:
		_active_job_id = ""


func _parse_json_body(body: PackedByteArray) -> Dictionary:
	var text := body.get_string_from_utf8()
	if text.strip_edges().is_empty():
		return {
			"ok": false,
			"message": "Repaint proxy returned an empty response.",
			"data": null,
		}

	var json := JSON.new()
	var error := json.parse(text)
	if error != OK:
		return {
			"ok": false,
			"message": "Repaint proxy returned malformed JSON: %s." % json.get_error_message(),
			"data": null,
		}

	return {
		"ok": true,
		"message": "",
		"data": json.data,
	}


func _request_url(
	url: String,
	headers: PackedStringArray,
	method: HTTPClient.Method,
	body: String,
	request_name: String
) -> Dictionary:
	if not is_inside_tree():
		return {
			"ok": false,
			"message": "RepaintClient must be inside the scene tree before making HTTP requests.",
			"body": PackedByteArray(),
		}

	var http_request := HTTPRequest.new()
	http_request.name = "AIRepaint%sRequest" % request_name.capitalize()
	http_request.timeout = request_timeout_s
	add_child(http_request)

	var error := http_request.request(url, headers, method, body)
	if error != OK:
		http_request.queue_free()
		return {
			"ok": false,
			"message": "Could not start HTTP request to %s." % url,
			"body": PackedByteArray(),
		}

	var completed: Array = await http_request.request_completed
	http_request.queue_free()

	var result_code := int(completed[0])
	var response_code := int(completed[1])
	var response_body: PackedByteArray = completed[3]
	if result_code != HTTPRequest.RESULT_SUCCESS:
		return {
			"ok": false,
			"message": "HTTP request to %s failed before receiving a response." % url,
			"body": PackedByteArray(),
		}
	if not _is_success_code(response_code):
		return {
			"ok": false,
			"message": "HTTP request to %s returned HTTP %d." % [url, response_code],
			"body": PackedByteArray(),
		}

	return {
		"ok": true,
		"message": "",
		"body": response_body,
	}


func _build_url(endpoint: String) -> String:
	var clean_base := base_url.strip_edges()
	while clean_base.ends_with("/"):
		clean_base = clean_base.left(clean_base.length() - 1)

	if endpoint.begins_with("/"):
		return "%s%s" % [clean_base, endpoint]
	return "%s/%s" % [clean_base, endpoint]


func _is_success_code(response_code: int) -> bool:
	return response_code >= 200 and response_code < 300


func _job_failure_message(job) -> String:
	if job.message.strip_edges().is_empty():
		return "Repaint job failed."
	return job.message


func _emit_failure(job_id: String, failure_message: String) -> void:
	repaint_failed.emit(job_id, failure_message)


func _ensure_cache_dir() -> int:
	if DirAccess.dir_exists_absolute(CACHE_DIR):
		return OK
	return DirAccess.make_dir_recursive_absolute(CACHE_DIR)


func _cache_path_for_url(url: String) -> String:
	var clean_url := url.split("?")[0].split("#")[0]
	var extension := clean_url.get_extension().to_lower()
	if not DOWNLOAD_EXTENSIONS.has(extension):
		extension = "png"

	var file_name := "texture_%d.%s" % [abs(url.hash()), extension]
	return CACHE_DIR.path_join(file_name)
