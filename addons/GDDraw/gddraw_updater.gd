@tool
extends Node

signal state_changed(state: int, details: Dictionary)
signal progress_changed(downloaded_bytes: int, total_bytes: int)

enum State {
	IDLE,
	CHECKING,
	CURRENT,
	INSTALLED_AHEAD_OF_RELEASE,
	UPDATE_AVAILABLE,
	DOWNLOADING,
	VERIFYING,
	READY_TO_INSTALL,
	INSTALLING,
	RESTART_REQUIRED,
	RECOVERING,
	FAILED,
}

const UPDATE_ROOT := "user://gddraw/updates"
const DOWNLOADS_DIR := UPDATE_ROOT + "/downloads"
const STAGED_DIR := UPDATE_ROOT + "/staged"
const BACKUPS_DIR := UPDATE_ROOT + "/backups"
const TRANSACTION_PATH := UPDATE_ROOT + "/installation-transaction.json"
const PLUGIN_ROOT := "res://addons/GDDraw"
const PACKAGE_PREFIX := "addons/GDDraw/"
const MAX_ARCHIVE_BYTES := 64 * 1024 * 1024
const MAX_EXTRACTED_BYTES := 256 * 1024 * 1024
const MAX_FILE_BYTES := 64 * 1024 * 1024
const DOWNLOAD_TIMEOUT_SECONDS := 45.0
const USER_AGENT := "Godot-Editor-Updater/1.0"
const REDIRECT_HOST_ALLOWLIST := [
	"release-assets.githubusercontent.com",
	"objects.githubusercontent.com",
	"github-releases.githubusercontent.com",
]
const REQUIRED_FILES := [
	"addons/GDDraw/plugin.cfg",
	"addons/GDDraw/GDDraw.gd",
	"addons/GDDraw/gddraw_dock.gd",
	"addons/GDDraw/gddraw_update_checker.gd",
	"addons/GDDraw/gddraw_updater.gd",
	"addons/GDDraw/gddraw_dock.tscn",
	"addons/GDDraw/gddraw_canvas.gd",
	"addons/GDDraw/gddraw_history.gd",
	"addons/GDDraw/gddraw_png_io.gd",
	"addons/GDDraw/gddraw_shortcuts.gd",
	"addons/GDDraw/gddraw_storage_paths.gd",
	"addons/GDDraw/gddraw_3d_surface_target.gd",
	"addons/GDDraw/gddraw_3d_texture_session.gd",
	"addons/GDDraw/gddraw_mesh_paint_cache.gd",
	"addons/GDDraw/gddraw_uv_overlay.gd",
	"addons/GDDraw/editor_integration/gddraw_sprite_creator.gd",
]
const FORBIDDEN_NATIVE_EXTENSIONS := [
	"dll", "so", "dylib", "exe", "com", "bat", "cmd", "ps1", "app", "msi", "dmg", "pkg",
]

var state := State.IDLE
var details: Dictionary = {}
var last_recovery_result: Dictionary = {}

var _http_request: HTTPRequest
var _download_active := false
var _install_active := false
var _cancel_requested := false
var _partial_path := ""
var _archive_path := ""
var _redirect_count := 0
var _download_headers := PackedStringArray()
var _release: Dictionary = {}
var _installed_version := ""
var _staging_manifest: Dictionary = {}
var _editor_interface: Object

var _update_root := UPDATE_ROOT
var _plugin_root := PLUGIN_ROOT
var _network_start_override := Callable()
var _archive_factory_override := Callable()
var _restart_override := Callable()
var _filesystem_adapter: Object


func _ready() -> void:
	set_process(false)


func set_editor_interface(editor_interface: Object) -> void:
	_editor_interface = editor_interface


func set_paths_for_tests(update_root: String, plugin_root: String) -> void:
	_update_root = update_root.trim_suffix("/")
	_plugin_root = plugin_root.trim_suffix("/")


func set_adapters_for_tests(
	network_start := Callable(),
	archive_factory := Callable(),
	restart_request := Callable(),
	filesystem_adapter: Object = null
) -> void:
	_network_start_override = network_start
	_archive_factory_override = archive_factory
	_restart_override = restart_request
	_filesystem_adapter = filesystem_adapter


func is_busy() -> bool:
	return _download_active or _install_active or state in [State.VERIFYING, State.RECOVERING]


func mark_checking(automatic: bool) -> void:
	if not is_busy():
		_set_state(State.CHECKING, {"automatic": automatic})


func mark_current(latest_version: String, automatic: bool) -> void:
	if not is_busy():
		_set_state(State.CURRENT, {"latest_version": latest_version, "automatic": automatic})


func mark_installed_ahead(latest_version: String, automatic: bool) -> void:
	if not is_busy():
		_set_state(State.INSTALLED_AHEAD_OF_RELEASE, {"latest_version": latest_version, "automatic": automatic})


func prepare_release(release_result: Dictionary, installed_version: String) -> bool:
	if is_busy():
		return false
	var validation := validate_release_descriptor(release_result, installed_version)
	if not bool(validation.get("ok", false)):
		_fail(str(validation.get("message", "The release metadata is not safe to use.")), true)
		return false
	_release = validation.release
	_installed_version = installed_version
	_set_state(State.UPDATE_AVAILABLE, _release.duplicate(true))
	return true


static func validate_release_descriptor(release_result: Dictionary, installed_version: String) -> Dictionary:
	var checker = load("res://addons/GDDraw/gddraw_update_checker.gd")
	if not checker:
		return {"ok": false, "message": "The version checker is unavailable."}
	var target := str(release_result.get("latest_version", ""))
	if checker.parse_semantic_version(target).is_empty():
		return {"ok": false, "message": "The release tag is not a semantic version."}
	if not checker.is_newer_version(target, installed_version):
		return {"ok": false, "message": "Only a newer GDDraw release can be installed."}
	var release_url := str(release_result.get("release_url", ""))
	if not checker.is_valid_release_url(release_url):
		return {"ok": false, "message": "The release page URL is not trusted."}
	var asset = release_result.get("asset", {})
	if not asset is Dictionary:
		return {"ok": false, "message": "The release has no validated update asset."}
	var expected_name: String = checker.ASSET_NAME_TEMPLATE % target
	var expected_tag := "v%s" % target
	if str(asset.get("name", "")) != expected_name:
		return {"ok": false, "message": "The release asset name does not match the release tag."}
	if not checker.is_valid_asset_download_url(str(asset.get("url", "")), expected_tag, expected_name):
		return {"ok": false, "message": "The release asset URL is not trusted."}
	var size := int(asset.get("size", -1))
	if size <= 0 or size > MAX_ARCHIVE_BYTES:
		return {"ok": false, "message": "The release asset size is invalid."}
	var digest := str(asset.get("sha256", "")).to_lower()
	if not _is_sha256(digest):
		return {"ok": false, "message": "The release asset has no valid external SHA-256 digest."}
	return {"ok": true, "release": {
		"installed_version": installed_version,
		"target_version": target,
		"release_url": release_url,
		"asset_name": expected_name,
		"asset_url": str(asset.get("url", "")),
		"asset_size": size,
		"expected_sha256": digest,
	}}


static func is_allowed_redirect_url(url: String) -> bool:
	if not url.begins_with("https://") or url.contains("\\"):
		return false
	var remainder := url.trim_prefix("https://")
	var slash := remainder.find("/")
	var authority := remainder if slash < 0 else remainder.substr(0, slash)
	if authority.contains("@") or authority.contains(":"):
		return false
	return authority.to_lower() in REDIRECT_HOST_ALLOWLIST


func download_update() -> bool:
	if is_busy() or state != State.UPDATE_AVAILABLE or _release.is_empty():
		return false
	if not _ensure_update_directory(_downloads_dir()):
		_fail("GDDraw could not create its update download directory.", true)
		return false
	var token := _unique_token()
	_partial_path = _downloads_dir().path_join("%s-%s.zip.part" % [_release.target_version, token])
	_archive_path = _partial_path.trim_suffix(".part")
	_redirect_count = 0
	_cancel_requested = false
	_download_active = true
	_set_state(State.DOWNLOADING, {
		"target_version": _release.target_version,
		"downloaded_bytes": 0,
		"total_bytes": int(_release.asset_size),
	})
	progress_changed.emit(0, int(_release.asset_size))
	set_process(true)
	_download_headers = PackedStringArray([
		"Accept: application/octet-stream",
		"User-Agent: %s" % USER_AGENT,
	])
	var error := _start_download_transport(str(_release.asset_url))
	if error != OK:
		_finish_download_failure("The update download could not be started.", true)
	return error == OK


func _start_download_transport(url: String) -> int:
	if _network_start_override.is_valid():
		return int(_network_start_override.call(url, _download_headers, _partial_path))
	_ensure_http_request()
	_http_request.download_file = _partial_path
	return _http_request.request(url, _download_headers, HTTPClient.METHOD_GET)


func complete_download_for_tests(request_result: int, response_code: int, headers := PackedStringArray()) -> void:
	_on_download_completed(request_result, response_code, headers, PackedByteArray())


func report_download_progress_for_tests(downloaded_bytes: int, total_bytes: int) -> void:
	_report_progress(downloaded_bytes, total_bytes)


func cancel_download() -> bool:
	if not _download_active:
		return false
	_cancel_requested = true
	if _http_request:
		_http_request.cancel_request()
	_download_active = false
	set_process(false)
	_remove_file_if_present(_partial_path)
	_partial_path = ""
	_set_state(State.UPDATE_AVAILABLE, _release.duplicate(true))
	return true


func _process(_delta: float) -> void:
	if not _download_active or not _http_request:
		set_process(false)
		return
	_report_progress(_http_request.get_downloaded_bytes(), _http_request.get_body_size())


func _report_progress(downloaded_bytes: int, reported_total: int) -> void:
	if not _download_active:
		return
	var total := reported_total if reported_total > 0 else int(_release.get("asset_size", -1))
	if downloaded_bytes > MAX_ARCHIVE_BYTES or (total > MAX_ARCHIVE_BYTES):
		if _http_request:
			_http_request.cancel_request()
		_finish_download_failure("The update archive exceeds the maximum allowed size.", true)
		return
	details["downloaded_bytes"] = downloaded_bytes
	details["total_bytes"] = total
	progress_changed.emit(downloaded_bytes, total)


func _ensure_http_request() -> void:
	if _http_request:
		return
	_http_request = HTTPRequest.new()
	_http_request.name = "GDDraw Update Download"
	_http_request.timeout = DOWNLOAD_TIMEOUT_SECONDS
	_http_request.use_threads = true
	# Redirects are handled here so every destination host is validated.
	_http_request.max_redirects = 0
	_http_request.request_completed.connect(_on_download_completed)
	add_child(_http_request)


func _on_download_completed(
	request_result: int,
	response_code: int,
	_headers: PackedStringArray,
	_body: PackedByteArray
) -> void:
	if not _download_active:
		return
	if response_code in [301, 302, 303, 307, 308]:
		var redirect_url := _get_header_value(_headers, "location")
		if _redirect_count >= 3 or not is_allowed_redirect_url(redirect_url):
			_finish_download_failure("The release asset redirected to an untrusted host.", true)
			return
		_redirect_count += 1
		_remove_file_if_present(_partial_path)
		var redirect_error := _start_download_transport(redirect_url)
		if redirect_error != OK:
			_finish_download_failure("The trusted release-asset redirect could not be followed.", true)
		return
	_download_active = false
	set_process(false)
	if _cancel_requested:
		_remove_file_if_present(_partial_path)
		_set_state(State.UPDATE_AVAILABLE, _release.duplicate(true))
		return
	if request_result != HTTPRequest.RESULT_SUCCESS:
		_finish_download_failure("The update download was interrupted or timed out.", true)
		return
	if response_code != 200:
		_finish_download_failure("The update server returned HTTP %d." % response_code, true)
		return
	var downloaded_size := _file_size(_partial_path)
	if downloaded_size <= 0 or downloaded_size != int(_release.asset_size):
		_finish_download_failure("The downloaded update is incomplete.", true)
		return
	if downloaded_size > MAX_ARCHIVE_BYTES:
		_finish_download_failure("The update archive exceeds the maximum allowed size.", true)
		return
	if _rename_path(_partial_path, _archive_path) != OK:
		_finish_download_failure("GDDraw could not finalize the downloaded archive.", true)
		return
	_partial_path = ""
	verify_downloaded_archive()


static func _get_header_value(headers: PackedStringArray, name: String) -> String:
	var prefix := name.to_lower() + ":"
	for header in headers:
		if header.to_lower().begins_with(prefix):
			return header.substr(header.find(":") + 1).strip_edges()
	return ""


func verify_downloaded_archive() -> bool:
	if state not in [State.DOWNLOADING, State.FAILED] or _archive_path.is_empty():
		return false
	_set_state(State.VERIFYING, {"target_version": _release.target_version})
	var result := validate_and_stage_archive(_archive_path, _release, _installed_version)
	if not bool(result.get("ok", false)):
		_fail(str(result.get("message", "The update package could not be validated.")), true)
		return false
	_staging_manifest = result.manifest
	_set_state(State.READY_TO_INSTALL, {
		"installed_version": _installed_version,
		"target_version": _release.target_version,
		"staging_dir": str(_staging_manifest.get("staging_dir", "")),
	})
	return true


func validate_and_stage_archive(archive_path: String, release: Dictionary, installed_version: String) -> Dictionary:
	if not _is_descendant_path(archive_path, _downloads_dir()):
		return {"ok": false, "message": "The update archive is outside the download directory."}
	var actual_digest := _sha256_file(archive_path)
	var expected_digest := str(release.get("expected_sha256", "")).to_lower()
	if actual_digest.is_empty() or actual_digest != expected_digest:
		return {"ok": false, "message": "The update archive SHA-256 digest does not match the release metadata."}
	var reader = _make_archive_reader()
	if not reader or int(reader.open(archive_path)) != OK:
		return {"ok": false, "message": "The update archive is not a readable ZIP file."}
	var entries: PackedStringArray = reader.get_files()
	var inspection := inspect_archive_entries(entries)
	if not bool(inspection.get("ok", false)):
		reader.close()
		return inspection
	var files: Array[String] = inspection.files
	for required in REQUIRED_FILES:
		if required not in files:
			reader.close()
			return {"ok": false, "message": "The update archive is missing %s." % required}
	var plugin_text: String = reader.read_file("addons/GDDraw/GDDraw.gd").get_string_from_utf8()
	var cfg_text: String = reader.read_file("addons/GDDraw/plugin.cfg").get_string_from_utf8()
	var package_version := parse_plugin_script_version(plugin_text)
	var cfg_version := parse_plugin_cfg_version(cfg_text)
	var target_version := str(release.get("target_version", ""))
	if package_version != target_version or cfg_version != target_version:
		reader.close()
		return {"ok": false, "message": "The release tag, asset, PLUGIN_VERSION, and plugin.cfg version do not agree."}
	var checker = load("res://addons/GDDraw/gddraw_update_checker.gd")
	if not checker or not checker.is_newer_version(target_version, installed_version):
		reader.close()
		return {"ok": false, "message": "The package is not newer than the installed GDDraw version."}
	var staging_dir := _staged_dir().path_join(target_version).path_join(_unique_token())
	var package_dir := staging_dir.path_join("package")
	if not _ensure_update_directory(package_dir):
		reader.close()
		return {"ok": false, "message": "GDDraw could not create the staging directory."}
	var file_manifest: Array[Dictionary] = []
	var extracted_bytes := 0
	for entry in files:
		var buffer: PackedByteArray = reader.read_file(entry)
		if buffer.size() > MAX_FILE_BYTES:
			reader.close()
			_remove_tree_scoped(staging_dir, _staged_dir())
			return {"ok": false, "message": "An update file exceeds the allowed size."}
		extracted_bytes += buffer.size()
		if extracted_bytes > MAX_EXTRACTED_BYTES:
			reader.close()
			_remove_tree_scoped(staging_dir, _staged_dir())
			return {"ok": false, "message": "The expanded update package is too large."}
		var output_path := package_dir.path_join(entry)
		if not _is_descendant_path(output_path, package_dir):
			reader.close()
			_remove_tree_scoped(staging_dir, _staged_dir())
			return {"ok": false, "message": "An archive entry escaped the staging directory."}
		if not _write_bytes(output_path, buffer):
			reader.close()
			_remove_tree_scoped(staging_dir, _staged_dir())
			return {"ok": false, "message": "GDDraw could not extract the validated update package."}
		file_manifest.push_back({"path": entry, "size": buffer.size(), "sha256": _sha256_bytes(buffer)})
	reader.close()
	file_manifest.sort_custom(func(a: Dictionary, b: Dictionary): return str(a.path) < str(b.path))
	var manifest := {
		"schema": 1,
		"installed_version": installed_version,
		"target_version": target_version,
		"release_url": str(release.get("release_url", "")),
		"asset_name": str(release.get("asset_name", "")),
		"expected_sha256": expected_digest,
		"actual_sha256": actual_digest,
		"files": file_manifest,
		"validation_timestamp": Time.get_datetime_string_from_system(true),
		"updater_state": "ready_to_install",
		"staging_dir": staging_dir,
		"package_dir": package_dir.path_join("addons/GDDraw"),
	}
	if not _write_json(staging_dir.path_join("manifest.json"), manifest):
		_remove_tree_scoped(staging_dir, _staged_dir())
		return {"ok": false, "message": "GDDraw could not write the staging manifest."}
	return {"ok": true, "manifest": manifest}


static func inspect_archive_entries(entries: PackedStringArray) -> Dictionary:
	if entries.is_empty():
		return {"ok": false, "message": "The update archive is empty."}
	var files: Array[String] = []
	var seen := {}
	for original in entries:
		var validation := validate_archive_entry_path(original)
		if not bool(validation.get("ok", false)):
			return validation
		if original.ends_with("/"):
			continue
		var folded := original.to_lower()
		if seen.has(folded):
			return {"ok": false, "message": "The update archive contains duplicate file paths."}
		seen[folded] = true
		files.push_back(original)
	files.sort()
	return {"ok": true, "files": files}


static func validate_archive_entry_path(path: String) -> Dictionary:
	if path.is_empty() or path.strip_edges() != path or path.contains("\\") or path.contains("%"):
		return {"ok": false, "message": "The update archive contains an unsafe path."}
	if path.begins_with("/") or path.begins_with("//") or path.contains(":"):
		return {"ok": false, "message": "The update archive contains an absolute or drive-letter path."}
	if path.contains("//"):
		return {"ok": false, "message": "The update archive contains a malformed path."}
	# ZIP tools commonly synthesize these two directory markers. They contain no
	# data and extraction ignores every directory entry.
	if path in ["addons/", "addons/GDDraw/"]:
		return {"ok": true}
	var trimmed := path.trim_suffix("/")
	var components := trimmed.split("/", false)
	if components.is_empty() or "." in components or ".." in components:
		return {"ok": false, "message": "The update archive contains path traversal."}
	if not trimmed.begins_with(PACKAGE_PREFIX) or trimmed == PACKAGE_PREFIX.trim_suffix("/"):
		return {"ok": false, "message": "The update archive has an unexpected root."}
	var lower := trimmed.to_lower()
	if lower.contains("/.godot/") or lower.ends_with("/.godot") or lower.contains("user://"):
		return {"ok": false, "message": "The update archive contains generated or user-data content."}
	if lower.ends_with(".import") or lower.ends_with(".lnk") or lower.ends_with(".symlink"):
		return {"ok": false, "message": "The update archive contains generated or link-like content."}
	if lower.get_extension() in FORBIDDEN_NATIVE_EXTENSIONS:
		return {"ok": false, "message": "The update archive contains an unexpected executable or native library."}
	return {"ok": true}


static func parse_plugin_script_version(text: String) -> String:
	var regex := RegEx.new()
	if regex.compile("(?m)^const\\s+PLUGIN_VERSION\\s*:?=\\s*\"([0-9]+\\.[0-9]+\\.[0-9]+)\"\\s*$") != OK:
		return ""
	var match := regex.search(text)
	return match.get_string(1) if match else ""


static func parse_plugin_cfg_version(text: String) -> String:
	var regex := RegEx.new()
	if regex.compile("(?m)^version\\s*=\\s*\"([0-9]+\\.[0-9]+\\.[0-9]+)\"\\s*$") != OK:
		return ""
	var match := regex.search(text)
	return match.get_string(1) if match else ""


func install_and_restart() -> bool:
	if is_busy() or state != State.READY_TO_INSTALL or _staging_manifest.is_empty():
		return false
	_install_active = true
	_set_state(State.INSTALLING, {"target_version": _staging_manifest.target_version})
	var result := _install_transaction()
	_install_active = false
	if not bool(result.get("ok", false)):
		_fail(str(result.get("message", "The update could not be installed.")), bool(result.get("retry_safe", false)))
		return false
	_set_state(State.RESTART_REQUIRED, {
		"target_version": _staging_manifest.target_version,
		"restart_requested": true,
		"message": "Godot restart was requested. The update becomes active only after the restarted editor validates it.",
	})
	return true


func _install_transaction() -> Dictionary:
	var revalidation := validate_staged_manifest(_staging_manifest)
	if not bool(revalidation.get("ok", false)):
		return revalidation
	var installed_now := read_package_version(_plugin_root)
	if installed_now != str(_staging_manifest.installed_version):
		return {"ok": false, "message": "The installed GDDraw version changed after staging."}
	var target_now := parse_plugin_script_version(_read_text(str(_staging_manifest.package_dir).path_join("GDDraw.gd")))
	if target_now != str(_staging_manifest.target_version):
		return {"ok": false, "message": "The staged GDDraw version changed after validation."}
	var token := _unique_token()
	var backup_dir := _backups_dir().path_join("v%s-%s" % [installed_now, token])
	var backup_package := backup_dir.path_join("package")
	if not _ensure_update_directory(backup_package):
		return {"ok": false, "message": "GDDraw could not create the backup directory."}
	var installed_bytes := _tree_size(_plugin_root)
	var staged_bytes := _tree_size(str(_staging_manifest.package_dir))
	if installed_bytes < 0 or staged_bytes < 0:
		return {"ok": false, "message": "GDDraw could not measure the packages before installation."}
	var update_space := _space_left(backup_package)
	if update_space > 0 and update_space < installed_bytes:
		return {"ok": false, "message": "There is not enough user-data disk space for the required backup."}
	var project_space := _space_left(_plugin_root.get_base_dir())
	if project_space > 0 and project_space < staged_bytes:
		return {"ok": false, "message": "There is not enough project disk space for the replacement candidate."}
	var backup_copy := _copy_tree(_plugin_root, backup_package)
	if not bool(backup_copy.get("ok", false)):
		return {"ok": false, "message": "GDDraw could not back up the installed package."}
	var backup_files := _build_file_manifest(backup_package)
	if backup_files.is_empty() or not _verify_file_manifest(backup_package, backup_files, false):
		return {"ok": false, "message": "The installed-package backup could not be verified."}
	var backup_manifest := {
		"version": installed_now,
		"package_dir": backup_package,
		"files": backup_files,
		"created_at": Time.get_datetime_string_from_system(true),
	}
	if not _write_json(backup_dir.path_join("manifest.json"), backup_manifest):
		return {"ok": false, "message": "GDDraw could not record the verified backup."}
	var parent := _plugin_root.get_base_dir()
	var candidate := parent.path_join(".GDDraw-update-%s" % token)
	var holding := parent.path_join(".GDDraw-previous-%s" % token)
	if _path_exists(candidate) or _path_exists(holding):
		return {"ok": false, "message": "A safe replacement path is unexpectedly occupied."}
	var transaction := {
		"schema": 1,
		"id": token,
		"state": "preparing_candidate",
		"installed_version": installed_now,
		"target_version": str(_staging_manifest.target_version),
		"plugin_root": _plugin_root,
		"plugin_root_absolute": _canonical_absolute(_plugin_root),
		"candidate_dir": candidate,
		"holding_dir": holding,
		"backup_dir": backup_dir,
		"backup_manifest": backup_manifest,
		"target_manifest": _staging_manifest,
		"created_at": Time.get_datetime_string_from_system(true),
	}
	if not _write_json(_transaction_path(), transaction):
		return {"ok": false, "message": "GDDraw could not record the installation transaction."}
	var candidate_copy := _copy_tree(str(_staging_manifest.package_dir), candidate)
	if not bool(candidate_copy.get("ok", false)) or not _verify_file_manifest(candidate, _staging_manifest.files, true, PACKAGE_PREFIX):
		_remove_tree_scoped(candidate, parent)
		transaction.state = "aborted_before_package_mutation"
		_write_json(_update_root.path_join("aborted-%s.json" % token), transaction)
		_remove_file_if_present(_transaction_path())
		return {"ok": false, "message": "The replacement candidate could not be verified."}
	transaction.state = "prepared"
	if not _write_json(_transaction_path(), transaction):
		_remove_tree_scoped(candidate, parent)
		return {"ok": false, "message": "GDDraw could not prepare the installation transaction."}
	transaction.state = "mutating"
	if not _write_json(_transaction_path(), transaction):
		return {"ok": false, "message": "GDDraw could not enter the installation transaction."}
	if _rename_path(_plugin_root, holding) != OK:
		return {"ok": false, "message": "The installed package could not be moved into the rollback slot.", "retry_safe": true}
	if _rename_path(candidate, _plugin_root) != OK:
		var rollback_error := _rename_path(holding, _plugin_root)
		if rollback_error == OK:
			_remove_tree_scoped(candidate, parent)
		return {"ok": false, "message": "The new package could not be activated; the previous package was restored." if rollback_error == OK else "Package replacement and immediate rollback both failed. Use the preserved backup for manual recovery."}
	if not _verify_file_manifest(_plugin_root, _staging_manifest.files, true, PACKAGE_PREFIX):
		var rollback := _rollback_from_backup(transaction)
		return {"ok": false, "message": "Installed-file verification failed; the verified backup was restored." if rollback else "Installed-file verification and automatic rollback failed. All recovery data was preserved."}
	transaction.state = "installed_pending_restart"
	if not _write_json(_transaction_path(), transaction):
		var descriptor_rollback := _rollback_from_backup(transaction)
		return {"ok": false, "message": "The restart transaction could not be recorded; the previous package was restored." if descriptor_rollback else "The restart transaction could not be recorded and automatic rollback failed."}
	if not _request_editor_restart():
		var restart_rollback := _rollback_from_backup(transaction)
		return {"ok": false, "message": "Godot could not prepare a safe restart; the previous package was restored." if restart_rollback else "Godot could not prepare a restart and automatic rollback failed."}
	_remove_tree_scoped(holding, parent)
	return {"ok": true, "backup_dir": backup_dir}


func recover_incomplete_transaction() -> Dictionary:
	if is_busy() or not _file_exists(_transaction_path()):
		return {"status": "none"}
	_set_state(State.RECOVERING, {})
	var transaction := _read_json(_transaction_path())
	if transaction.is_empty():
		last_recovery_result = {"status": "manual_recovery", "message": "The update transaction descriptor is unreadable. Staged and backup data were preserved."}
		_fail(last_recovery_result.message, false)
		return last_recovery_result
	if str(transaction.get("plugin_root_absolute", "")) != _canonical_absolute(_plugin_root):
		last_recovery_result = {"status": "manual_recovery", "message": "The incomplete update belongs to a different project path. No files were changed; recovery data was preserved."}
		_fail(last_recovery_result.message, false)
		return last_recovery_result
	var target_manifest = transaction.get("target_manifest", {})
	if target_manifest is Dictionary and bool(validate_staged_manifest(target_manifest, _plugin_root).get("ok", false)):
		transaction.state = "completed"
		transaction.completed_at = Time.get_datetime_string_from_system(true)
		var completed_path := _update_root.path_join("completed-%s.json" % str(transaction.get("id", _unique_token())))
		_write_json(completed_path, transaction)
		_remove_file_if_present(_transaction_path())
		last_recovery_result = {"status": "completed", "target_version": str(transaction.get("target_version", "")), "backup_dir": str(transaction.get("backup_dir", ""))}
		_set_state(State.IDLE, last_recovery_result)
		return last_recovery_result
	if _rollback_from_backup(transaction):
		transaction.state = "rolled_back"
		transaction.rolled_back_at = Time.get_datetime_string_from_system(true)
		_write_json(_update_root.path_join("rolled-back-%s.json" % str(transaction.get("id", _unique_token()))), transaction)
		_remove_file_if_present(_transaction_path())
		last_recovery_result = {"status": "rolled_back", "message": "An incomplete GDDraw update was rolled back to the verified previous package."}
		_set_state(State.IDLE, last_recovery_result)
		return last_recovery_result
	last_recovery_result = {"status": "manual_recovery", "message": "Neither the target package nor the backup could be validated. No further files were changed; all recovery data was preserved."}
	_fail(last_recovery_result.message, false)
	return last_recovery_result


func validate_staged_manifest(manifest: Dictionary, root_override := "") -> Dictionary:
	if manifest.is_empty() or not manifest.get("files", []) is Array:
		return {"ok": false, "message": "The staging manifest is invalid."}
	var root := root_override if not root_override.is_empty() else str(manifest.get("package_dir", ""))
	var prefix := PACKAGE_PREFIX
	if root.is_empty() or not _verify_file_manifest(root, manifest.files, true, prefix):
		return {"ok": false, "message": "The staged package no longer matches its validated manifest."}
	var version := read_package_version(root)
	if version != str(manifest.get("target_version", "")):
		return {"ok": false, "message": "The staged package version changed after validation."}
	return {"ok": true}


func read_package_version(package_root: String) -> String:
	return parse_plugin_script_version(_read_text(package_root.path_join("GDDraw.gd")))


func _rollback_from_backup(transaction: Dictionary) -> bool:
	var backup_manifest = transaction.get("backup_manifest", {})
	if not backup_manifest is Dictionary:
		return false
	var backup_package := str(backup_manifest.get("package_dir", ""))
	var backup_files = backup_manifest.get("files", [])
	if backup_package.is_empty() or not backup_files is Array or not _verify_file_manifest(backup_package, backup_files, true):
		return false
	var parent := _plugin_root.get_base_dir()
	var token := str(transaction.get("id", _unique_token()))
	var restore_candidate := parent.path_join(".GDDraw-restore-%s" % token)
	var failed_package := parent.path_join(".GDDraw-failed-%s" % token)
	if _path_exists(restore_candidate) or _path_exists(failed_package):
		return false
	if not bool(_copy_tree(backup_package, restore_candidate).get("ok", false)):
		return false
	if not _verify_file_manifest(restore_candidate, backup_files, true):
		_remove_tree_scoped(restore_candidate, parent)
		return false
	if _path_exists(_plugin_root) and _rename_path(_plugin_root, failed_package) != OK:
		return false
	if _rename_path(restore_candidate, _plugin_root) != OK:
		if _path_exists(failed_package):
			_rename_path(failed_package, _plugin_root)
		return false
	if not _verify_file_manifest(_plugin_root, backup_files, true):
		return false
	_remove_tree_scoped(failed_package, parent)
	var holding := str(transaction.get("holding_dir", ""))
	if not holding.is_empty():
		_remove_tree_scoped(holding, parent)
	var candidate := str(transaction.get("candidate_dir", ""))
	if not candidate.is_empty():
		_remove_tree_scoped(candidate, parent)
	return true


func _request_editor_restart() -> bool:
	if _restart_override.is_valid():
		return bool(_restart_override.call(true))
	if not _editor_interface or not _editor_interface.has_method("restart_editor"):
		return false
	_editor_interface.call("restart_editor", true)
	return true


func _make_archive_reader():
	if _archive_factory_override.is_valid():
		return _archive_factory_override.call()
	return ZIPReader.new()


func _copy_tree(source: String, destination: String) -> Dictionary:
	if _filesystem_adapter and _filesystem_adapter.has_method("copy_tree"):
		return _filesystem_adapter.call("copy_tree", source, destination)
	if not _path_exists(source):
		return {"ok": false}
	if DirAccess.make_dir_recursive_absolute(destination) != OK:
		return {"ok": false}
	var dir := DirAccess.open(source)
	if not dir:
		return {"ok": false}
	for directory in dir.get_directories():
		var nested := _copy_tree(source.path_join(directory), destination.path_join(directory))
		if not bool(nested.get("ok", false)):
			return nested
	for file_name in dir.get_files():
		if DirAccess.copy_absolute(source.path_join(file_name), destination.path_join(file_name)) != OK:
			return {"ok": false}
	return {"ok": true}


func _build_file_manifest(root: String) -> Array[Dictionary]:
	var files: Array[String] = []
	_collect_files(root, root, files)
	files.sort()
	var manifest: Array[Dictionary] = []
	for relative in files:
		var path := root.path_join(relative)
		manifest.push_back({"path": relative, "size": _file_size(path), "sha256": _sha256_file(path)})
	return manifest


func _tree_size(root: String) -> int:
	var files: Array[String] = []
	_collect_files(root, root, files)
	if files.is_empty() and not DirAccess.dir_exists_absolute(root):
		return -1
	var total := 0
	for relative in files:
		var size := _file_size(root.path_join(relative))
		if size < 0:
			return -1
		total += size
	return total


func _space_left(path: String) -> int:
	var dir := DirAccess.open(path)
	return dir.get_space_left() if dir else -1


func _collect_files(root: String, current: String, output: Array[String]) -> void:
	var dir := DirAccess.open(current)
	if not dir:
		return
	for directory in dir.get_directories():
		_collect_files(root, current.path_join(directory), output)
	for file_name in dir.get_files():
		output.push_back(current.path_join(file_name).trim_prefix(root + "/"))


func _verify_file_manifest(root: String, manifest: Array, require_exact := true, strip_prefix := "") -> bool:
	var expected: Array[String] = []
	for value in manifest:
		if not value is Dictionary:
			return false
		var relative := str(value.get("path", ""))
		if not strip_prefix.is_empty():
			if not relative.begins_with(strip_prefix):
				return false
			relative = relative.trim_prefix(strip_prefix)
		if relative.is_empty() or relative.begins_with("/") or relative.contains("..") or relative.contains("\\"):
			return false
		var path := root.path_join(relative)
		if not _is_descendant_path(path, root) or _file_size(path) != int(value.get("size", -1)):
			return false
		if _sha256_file(path) != str(value.get("sha256", "")).to_lower():
			return false
		expected.push_back(relative)
	if require_exact:
		var actual: Array[String] = []
		_collect_files(root, root, actual)
		actual.sort()
		expected.sort()
		if actual != expected:
			return false
	return true


func _write_bytes(path: String, bytes: PackedByteArray) -> bool:
	if _filesystem_adapter and _filesystem_adapter.has_method("write_bytes"):
		return bool(_filesystem_adapter.call("write_bytes", path, bytes))
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK:
		return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return false
	file.store_buffer(bytes)
	return file.get_error() == OK


func _write_json(path: String, value: Dictionary) -> bool:
	return _write_bytes(path, JSON.stringify(value, "  ").to_utf8_buffer())


func _read_text(path: String) -> String:
	if _filesystem_adapter and _filesystem_adapter.has_method("read_text"):
		return str(_filesystem_adapter.call("read_text", path))
	return FileAccess.get_file_as_string(path)


func _read_json(path: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(_read_text(path)) != OK or not json.data is Dictionary:
		return {}
	return json.data


func _sha256_file(path: String) -> String:
	if _filesystem_adapter and _filesystem_adapter.has_method("sha256_file"):
		return str(_filesystem_adapter.call("sha256_file", path)).to_lower()
	return FileAccess.get_sha256(path).to_lower()


static func _sha256_bytes(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	context.update(bytes)
	return context.finish().hex_encode()


func _file_size(path: String) -> int:
	if _filesystem_adapter and _filesystem_adapter.has_method("file_size"):
		return int(_filesystem_adapter.call("file_size", path))
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_length() if file else -1


func _file_exists(path: String) -> bool:
	if _filesystem_adapter and _filesystem_adapter.has_method("file_exists"):
		return bool(_filesystem_adapter.call("file_exists", path))
	return FileAccess.file_exists(path)


func _path_exists(path: String) -> bool:
	return _file_exists(path) or DirAccess.dir_exists_absolute(path)


func _rename_path(source: String, destination: String) -> int:
	if _filesystem_adapter and _filesystem_adapter.has_method("rename_path"):
		return int(_filesystem_adapter.call("rename_path", source, destination))
	return DirAccess.rename_absolute(source, destination)


func _remove_file_if_present(path: String) -> void:
	if path.is_empty() or not _file_exists(path):
		return
	if _filesystem_adapter and _filesystem_adapter.has_method("remove_file"):
		_filesystem_adapter.call("remove_file", path)
	else:
		DirAccess.remove_absolute(path)


func _remove_tree_scoped(path: String, allowed_root: String) -> bool:
	if path.is_empty() or not _is_descendant_path(path, allowed_root):
		return false
	if not _path_exists(path):
		return true
	if _filesystem_adapter and _filesystem_adapter.has_method("remove_tree"):
		return bool(_filesystem_adapter.call("remove_tree", path, allowed_root))
	if _file_exists(path):
		return DirAccess.remove_absolute(path) == OK
	var dir := DirAccess.open(path)
	if not dir:
		return false
	for directory in dir.get_directories():
		if not _remove_tree_scoped(path.path_join(directory), allowed_root):
			return false
	for file_name in dir.get_files():
		if DirAccess.remove_absolute(path.path_join(file_name)) != OK:
			return false
	return DirAccess.remove_absolute(path) == OK


func _ensure_update_directory(path: String) -> bool:
	if not _is_same_or_descendant_path(path, _update_root):
		return false
	if _filesystem_adapter and _filesystem_adapter.has_method("make_dir_recursive"):
		return bool(_filesystem_adapter.call("make_dir_recursive", path))
	return DirAccess.make_dir_recursive_absolute(path) == OK


func _downloads_dir() -> String:
	return _update_root.path_join("downloads")


func _staged_dir() -> String:
	return _update_root.path_join("staged")


func _backups_dir() -> String:
	return _update_root.path_join("backups")


func _transaction_path() -> String:
	return _update_root.path_join("installation-transaction.json")


static func _is_sha256(value: String) -> bool:
	if value.length() != 64:
		return false
	for index in range(value.length()):
		var code := value.unicode_at(index)
		if not (code >= 48 and code <= 57) and not (code >= 97 and code <= 102):
			return false
	return true


static func _canonical_absolute(path: String) -> String:
	if path.is_empty():
		return ""
	return ProjectSettings.globalize_path(path).replace("\\", "/").simplify_path().trim_suffix("/").to_lower()


static func _is_descendant_path(path: String, root: String) -> bool:
	var absolute_path := _canonical_absolute(path)
	var absolute_root := _canonical_absolute(root)
	return not absolute_path.is_empty() and not absolute_root.is_empty() and absolute_path.begins_with(absolute_root + "/")


static func _is_same_or_descendant_path(path: String, root: String) -> bool:
	return _canonical_absolute(path) == _canonical_absolute(root) or _is_descendant_path(path, root)


func _unique_token() -> String:
	return "%d-%08x" % [Time.get_unix_time_from_system(), randi()]


func _finish_download_failure(message: String, retry_safe: bool) -> void:
	_download_active = false
	set_process(false)
	_remove_file_if_present(_partial_path)
	_partial_path = ""
	_fail(message, retry_safe)


func _fail(message: String, retry_safe: bool) -> void:
	_set_state(State.FAILED, {
		"message": message,
		"retry_safe": retry_safe,
		"release_url": str(_release.get("release_url", "")),
		"target_version": str(_release.get("target_version", "")),
	})


func _set_state(new_state: int, new_details: Dictionary) -> void:
	state = new_state
	details = new_details.duplicate(true)
	state_changed.emit(state, details.duplicate(true))


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _download_active:
		if _http_request:
			_http_request.cancel_request()
		_remove_file_if_present(_partial_path)
