class_name RepaintJob
extends RefCounted

const STATUS_QUEUED: String = "queued"
const STATUS_RUNNING: String = "running"
const STATUS_SUCCEEDED: String = "succeeded"
const STATUS_FAILED: String = "failed"
const VALID_STATUSES: Array[String] = [
	STATUS_QUEUED,
	STATUS_RUNNING,
	STATUS_SUCCEEDED,
	STATUS_FAILED,
]
const RESULT_URL_KEYS: Array[String] = [
	"model_url",
	"preview_url",
	"base_color_url",
	"roughness_url",
	"metallic_url",
	"normal_url",
]

var job_id: String = ""
var status: String = ""
var progress: float = 0.0
var message: String = ""
var result: Dictionary = {}
var error_message: String = ""


static func from_variant(payload: Variant) -> RepaintJob:
	var job := RepaintJob.new()
	job._read_payload(payload)
	return job


func is_valid() -> bool:
	return error_message.is_empty()


func is_pending() -> bool:
	return status == STATUS_QUEUED or status == STATUS_RUNNING


func is_terminal() -> bool:
	return status == STATUS_SUCCEEDED or status == STATUS_FAILED


func _read_payload(payload: Variant) -> void:
	if typeof(payload) != TYPE_DICTIONARY:
		error_message = "Repaint proxy returned a non-object response."
		return

	var data: Dictionary = payload
	if not _read_job_id(data):
		return
	if not _read_status(data):
		return
	if not _read_progress(data):
		return
	if not _read_message(data):
		return
	if not _read_result(data):
		return


func _read_job_id(data: Dictionary) -> bool:
	if not data.has("job_id") or typeof(data["job_id"]) != TYPE_STRING:
		error_message = "Repaint proxy response is missing job_id."
		return false

	job_id = String(data["job_id"]).strip_edges()
	if job_id.is_empty():
		error_message = "Repaint proxy response contains an empty job_id."
		return false
	return true


func _read_status(data: Dictionary) -> bool:
	if not data.has("status") or typeof(data["status"]) != TYPE_STRING:
		error_message = "Repaint proxy response is missing status."
		return false

	status = String(data["status"]).strip_edges()
	if not VALID_STATUSES.has(status):
		error_message = "Repaint proxy returned unknown status '%s'." % status
		return false
	return true


func _read_progress(data: Dictionary) -> bool:
	if not data.has("progress"):
		error_message = "Repaint proxy response is missing progress."
		return false

	var raw_progress: Variant = data["progress"]
	var raw_type := typeof(raw_progress)
	if raw_type != TYPE_FLOAT and raw_type != TYPE_INT:
		error_message = "Repaint proxy response progress is not numeric."
		return false

	progress = clampf(float(raw_progress), 0.0, 1.0)
	return true


func _read_message(data: Dictionary) -> bool:
	if not data.has("message"):
		message = ""
		return true

	if typeof(data["message"]) != TYPE_STRING:
		error_message = "Repaint proxy response message is not a string."
		return false

	message = String(data["message"])
	return true


func _read_result(data: Dictionary) -> bool:
	if not data.has("result") or data["result"] == null:
		if status == STATUS_SUCCEEDED:
			error_message = "Succeeded repaint response is missing result."
			return false
		result = {}
		return true

	if typeof(data["result"]) != TYPE_DICTIONARY:
		error_message = "Repaint proxy response result is not an object."
		return false

	result = {}
	var raw_result: Dictionary = data["result"]
	for key: String in RESULT_URL_KEYS:
		if not raw_result.has(key) or raw_result[key] == null:
			continue

		if typeof(raw_result[key]) != TYPE_STRING:
			error_message = "Repaint proxy response result.%s is not a string." % key
			return false

		var url := String(raw_result[key]).strip_edges()
		if not url.is_empty():
			result[key] = url
	return true
