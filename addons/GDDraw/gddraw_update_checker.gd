@tool
extends Node

signal check_completed(result: Dictionary)

const RELEASE_API_URL := "https://api.github.com/repos/ArdonyxApps/GDDraw/releases/latest"
const RELEASE_PAGE_URL := "https://github.com/ArdonyxApps/GDDraw/releases/latest"
const RELEASE_TAG_URL_PREFIX := "https://github.com/ArdonyxApps/GDDraw/releases/tag/"
const ASSET_DOWNLOAD_URL_PREFIX := "https://github.com/ArdonyxApps/GDDraw/releases/download/"
const ASSET_NAME_TEMPLATE := "GDDraw-v%s.zip"
const MAX_ARCHIVE_BYTES := 64 * 1024 * 1024
const USER_AGENT := "Godot-Editor-Updater/1.0"

const STATUS := "status"
const STATUS_UPDATE_AVAILABLE := "update_available"
const STATUS_UP_TO_DATE := "up_to_date"
const STATUS_INSTALLED_AHEAD := "installed_ahead_of_release"
const STATUS_IGNORED := "ignored"
const STATUS_ERROR := "error"
const LATEST_VERSION := "latest_version"
const RELEASE_URL := "release_url"
const RESPONSE_CODE := "response_code"
const ERROR_KIND := "error_kind"
const AUTOMATIC := "automatic"
const ASSET := "asset"

static var _automatic_check_started_this_session := false

var _http_request: HTTPRequest
var _request_active := false
var _installed_version := ""
var _request_was_automatic := false
var _request_start_override := Callable()


func _ready() -> void:
	_ensure_http_request()


func check_for_updates(installed_version: String, automatic := false) -> bool:
	if _request_active:
		return false
	if automatic:
		if _automatic_check_started_this_session:
			return false
		_automatic_check_started_this_session = true

	_request_active = true
	_installed_version = installed_version
	_request_was_automatic = automatic
	var headers := PackedStringArray([
		"Accept: application/vnd.github+json",
		"X-GitHub-Api-Version: 2022-11-28",
		"User-Agent: %s" % USER_AGENT,
	])
	var error := OK
	if _request_start_override.is_valid():
		error = int(_request_start_override.call(RELEASE_API_URL, headers))
	else:
		_ensure_http_request()
		if not _http_request or not is_inside_tree():
			error = ERR_UNCONFIGURED
		else:
			error = _http_request.request(RELEASE_API_URL, headers, HTTPClient.METHOD_GET)
	if error != OK:
		_finish_request({
			STATUS: STATUS_ERROR,
			ERROR_KIND: "request_start",
			RESPONSE_CODE: 0,
		})
	return true


func is_request_active() -> bool:
	return _request_active


func set_request_start_override_for_tests(request_start: Callable) -> void:
	_request_start_override = request_start


func complete_active_request_for_tests(
	request_result: int,
	response_code: int,
	body: PackedByteArray
) -> void:
	_on_request_completed(request_result, response_code, PackedStringArray(), body)


static func reset_session_state_for_tests() -> void:
	_automatic_check_started_this_session = false


static func parse_semantic_version(version: String) -> Array[int]:
	var normalized := version.strip_edges()
	if normalized.begins_with("v") or normalized.begins_with("V"):
		normalized = normalized.substr(1)
	var parts := normalized.split(".", false)
	if parts.size() != 3:
		return []
	var parsed: Array[int] = []
	for part in parts:
		if part.is_empty() or not _contains_only_ascii_digits(part):
			return []
		parsed.push_back(int(part))
	return parsed


static func compare_semantic_versions(left: String, right: String) -> int:
	var left_parts := parse_semantic_version(left)
	var right_parts := parse_semantic_version(right)
	if left_parts.is_empty() or right_parts.is_empty():
		return 0
	for index in range(3):
		if left_parts[index] > right_parts[index]:
			return 1
		if left_parts[index] < right_parts[index]:
			return -1
	return 0


static func is_newer_version(candidate: String, installed: String) -> bool:
	if parse_semantic_version(candidate).is_empty() or parse_semantic_version(installed).is_empty():
		return false
	return compare_semantic_versions(candidate, installed) > 0


static func normalized_version(version: String) -> String:
	var parts := parse_semantic_version(version)
	if parts.is_empty():
		return ""
	return "%d.%d.%d" % parts


static func parse_http_response(
	request_result: int,
	response_code: int,
	body: PackedByteArray,
	installed_version: String
) -> Dictionary:
	if request_result != HTTPRequest.RESULT_SUCCESS:
		return {
			STATUS: STATUS_ERROR,
			ERROR_KIND: "network",
			RESPONSE_CODE: response_code,
		}
	if response_code != 200:
		return {
			STATUS: STATUS_ERROR,
			ERROR_KIND: "http",
			RESPONSE_CODE: response_code,
		}
	if parse_semantic_version(installed_version).is_empty():
		return {
			STATUS: STATUS_ERROR,
			ERROR_KIND: "installed_version",
			RESPONSE_CODE: response_code,
		}

	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK or not json.data is Dictionary:
		return {
			STATUS: STATUS_ERROR,
			ERROR_KIND: "json",
			RESPONSE_CODE: response_code,
		}
	var release: Dictionary = json.data
	if bool(release.get("draft", false)) or bool(release.get("prerelease", false)):
		return {
			STATUS: STATUS_IGNORED,
			RESPONSE_CODE: response_code,
		}
	var tag_name := str(release.get("tag_name", ""))
	var latest_version := normalized_version(tag_name)
	if latest_version.is_empty() or tag_name != "v%s" % latest_version:
		return {
			STATUS: STATUS_ERROR,
			ERROR_KIND: "release_version",
			RESPONSE_CODE: response_code,
		}
	var release_url := str(release.get("html_url", ""))
	if not is_valid_release_url(release_url) or release_url != RELEASE_TAG_URL_PREFIX + tag_name:
		return {
			STATUS: STATUS_ERROR,
			ERROR_KIND: "release_url",
			RESPONSE_CODE: response_code,
		}
	var comparison := compare_semantic_versions(latest_version, installed_version)
	var status := STATUS_UP_TO_DATE
	if comparison > 0:
		status = STATUS_UPDATE_AVAILABLE
	elif comparison < 0:
		status = STATUS_INSTALLED_AHEAD
	var result := {
		STATUS: status,
		LATEST_VERSION: latest_version,
		RELEASE_URL: release_url,
		RESPONSE_CODE: response_code,
	}
	if status == STATUS_UPDATE_AVAILABLE:
		var asset_result := select_release_asset(release, tag_name)
		if not bool(asset_result.get("ok", false)):
			return {
				STATUS: STATUS_ERROR,
				ERROR_KIND: str(asset_result.get("error_kind", "release_asset")),
				LATEST_VERSION: latest_version,
				RELEASE_URL: release_url,
				RESPONSE_CODE: response_code,
			}
		result[ASSET] = asset_result.get(ASSET, {})
	return result


static func select_release_asset(release: Dictionary, tag_name: String) -> Dictionary:
	var version := normalized_version(tag_name)
	if version.is_empty() or tag_name != "v%s" % version:
		return {"ok": false, "error_kind": "release_version"}
	var expected_name := ASSET_NAME_TEMPLATE % version
	var matches: Array[Dictionary] = []
	var assets = release.get("assets", [])
	if not assets is Array:
		return {"ok": false, "error_kind": "release_assets"}
	for value in assets:
		if value is Dictionary and str(value.get("name", "")) == expected_name:
			matches.push_back(value)
	if matches.size() != 1:
		return {"ok": false, "error_kind": "release_asset_missing" if matches.is_empty() else "release_asset_ambiguous"}
	var candidate := matches[0]
	if str(candidate.get("state", "")) != "uploaded":
		return {"ok": false, "error_kind": "release_asset_state"}
	var size := int(candidate.get("size", -1))
	if size <= 0 or size > MAX_ARCHIVE_BYTES:
		return {"ok": false, "error_kind": "release_asset_size"}
	var content_type := str(candidate.get("content_type", "")).to_lower()
	if content_type not in ["application/zip", "application/x-zip-compressed", "application/octet-stream"]:
		return {"ok": false, "error_kind": "release_asset_content_type"}
	var download_url := str(candidate.get("browser_download_url", ""))
	if not is_valid_asset_download_url(download_url, tag_name, expected_name):
		return {"ok": false, "error_kind": "release_asset_url"}
	var digest := str(candidate.get("digest", "")).to_lower()
	if not _is_valid_sha256_digest(digest):
		return {"ok": false, "error_kind": "release_asset_digest"}
	return {
		"ok": true,
		ASSET: {
			"name": expected_name,
			"url": download_url,
			"size": size,
			"sha256": digest.trim_prefix("sha256:"),
			"content_type": content_type,
		},
	}


static func is_valid_asset_download_url(url: String, tag_name: String, asset_name: String) -> bool:
	if url.contains("?") or url.contains("#"):
		return false
	return url == ASSET_DOWNLOAD_URL_PREFIX + tag_name + "/" + asset_name


static func _is_valid_sha256_digest(digest: String) -> bool:
	if not digest.begins_with("sha256:"):
		return false
	var value := digest.trim_prefix("sha256:")
	if value.length() != 64:
		return false
	for index in range(value.length()):
		var code := value.unicode_at(index)
		if not (code >= 48 and code <= 57) and not (code >= 97 and code <= 102):
			return false
	return true


static func is_valid_release_url(url: String) -> bool:
	if url == RELEASE_PAGE_URL:
		return true
	if not url.begins_with(RELEASE_TAG_URL_PREFIX):
		return false
	var tag_name := url.trim_prefix(RELEASE_TAG_URL_PREFIX)
	return not tag_name.is_empty() and not normalized_version(tag_name).is_empty()


static func _contains_only_ascii_digits(value: String) -> bool:
	for index in range(value.length()):
		var code := value.unicode_at(index)
		if code < 48 or code > 57:
			return false
	return true


func _ensure_http_request() -> void:
	if _http_request:
		return
	_http_request = HTTPRequest.new()
	_http_request.name = "GDDraw Update Request"
	_http_request.timeout = 12.0
	_http_request.request_completed.connect(_on_request_completed)
	add_child(_http_request)


func _on_request_completed(
	request_result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	if not _request_active:
		return
	_finish_request(parse_http_response(request_result, response_code, body, _installed_version))


func _finish_request(result: Dictionary) -> void:
	if not _request_active:
		return
	_request_active = false
	result[AUTOMATIC] = _request_was_automatic
	_installed_version = ""
	_request_was_automatic = false
	check_completed.emit(result)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _request_active:
		_request_active = false
		if _http_request:
			_http_request.cancel_request()
