@tool
class_name GDDrawLayerDocument
extends RefCounted

const LayerSession := preload("res://addons/GDDraw/gddraw_layer_session.gd")

const FORMAT_NAME := "gddraw-layered-document"
const FORMAT_VERSION := 2
const MANIFEST_PATH := "manifest.json"
const MAX_MANIFEST_BYTES := 4 * 1024 * 1024
const MAX_IMAGE_BYTES := 256 * 1024 * 1024
const MAX_TARGETS := 1024
const MAX_NODES_PER_TARGET := 4096
const MAX_IMAGE_DIMENSION := 16384


static func save_session(session, path: String) -> Dictionary:
	if not session or path.strip_edges().is_empty():
		return _result(false, "A layer session and destination path are required.")
	var build := _build_archive(session)
	if not bool(build.get("ok", false)):
		return build
	var requested_path := path.strip_edges()
	var destination := (
		ProjectSettings.globalize_path(requested_path)
		if requested_path.begins_with("res://") or requested_path.begins_with("user://")
		else requested_path
	)
	var base_dir := destination.get_base_dir()
	if not base_dir.is_empty() and DirAccess.make_dir_recursive_absolute(base_dir) != OK:
		return _result(false, "Could not create the layered document directory.")
	var token := "%d-%d" % [Time.get_ticks_usec(), randi()]
	# ZIPPacker validates the temporary filename as an archive path on some
	# platforms, so retain a .zip suffix until the atomic commit.
	var temporary_requested_path := requested_path + ".writing-" + token + ".zip"
	var temporary_path := (
		ProjectSettings.globalize_path(temporary_requested_path)
		if temporary_requested_path.begins_with("res://") or temporary_requested_path.begins_with("user://")
		else temporary_requested_path
	)
	var packer := ZIPPacker.new()
	var open_error := packer.open(temporary_requested_path)
	if open_error != OK:
		if FileAccess.file_exists(temporary_path):
			DirAccess.remove_absolute(temporary_path)
		return _result(false, "Could not open the layered document for writing (%s at %s)." % [error_string(open_error), temporary_path])
	var files: Dictionary = build.get("files", {})
	for entry_value in files:
		var entry := str(entry_value)
		var bytes: PackedByteArray = files[entry]
		if packer.start_file(entry) != OK or packer.write_file(bytes) != OK or packer.close_file() != OK:
			packer.close()
			DirAccess.remove_absolute(temporary_path)
			return _result(false, "Could not write %s into the layered document." % entry)
	if packer.close() != OK:
		DirAccess.remove_absolute(temporary_path)
		return _result(false, "Could not finish the layered document archive.")
	var commit := _commit_temporary_file(temporary_path, destination, token)
	if not bool(commit.get("ok", false)):
		return commit
	if session.has_method("mark_layered_saved"):
		session.mark_layered_saved()
	var response := _result(true, "Saved layered document.")
	response["path"] = requested_path
	return response


static func load_state(path: String) -> Dictionary:
	var reader := ZIPReader.new()
	if reader.open(path) != OK:
		return _result(false, "The selected file is not a readable GDDraw layered document.")
	var entries: PackedStringArray = reader.get_files()
	if MANIFEST_PATH not in entries:
		reader.close()
		return _result(false, "The layered document is missing its manifest.")
	var manifest_bytes := reader.read_file(MANIFEST_PATH)
	if manifest_bytes.is_empty() or manifest_bytes.size() > MAX_MANIFEST_BYTES:
		reader.close()
		return _result(false, "The layered document manifest is empty or exceeds the safety limit.")
	var manifest_value: Variant = JSON.parse_string(manifest_bytes.get_string_from_utf8())
	if not manifest_value is Dictionary:
		reader.close()
		return _result(false, "The layered document manifest is malformed JSON.")
	var manifest: Dictionary = manifest_value
	if str(manifest.get("format", "")) != FORMAT_NAME:
		reader.close()
		return _result(false, "This archive is not a GDDraw layered document.")
	if int(manifest.get("format_version", 0)) not in [1, FORMAT_VERSION]:
		reader.close()
		return _result(false, "This layered document version is not supported.")
	var session_manifest: Variant = manifest.get("session", null)
	if not session_manifest is Dictionary:
		reader.close()
		return _result(false, "The layered document has no valid session state.")
	var decoded := _decode_session_state(session_manifest, reader, entries)
	reader.close()
	return decoded


static func load_into_session(path: String, destination_session) -> Dictionary:
	if not destination_session:
		return _result(false, "A destination layer session is required.")
	var loaded := load_state(path)
	if not bool(loaded.get("ok", false)):
		return loaded
	var candidate := LayerSession.new()
	if not candidate.restore_state(loaded.get("state", {})):
		return _result(false, "The layered document hierarchy or image metadata is inconsistent.")
	if candidate.has_method("mark_layered_saved"):
		candidate.mark_layered_saved()
	# Restore only after every archive, schema, image, and model check passes, so
	# malformed files can never partially destroy the open document.
	if not destination_session.restore_state(candidate.capture_state()):
		return _result(false, "The layered document could not replace the current session.")
	var response := _result(true, "Opened layered document.")
	response["path"] = path
	return response


static func _build_archive(session) -> Dictionary:
	if not session.has_method("capture_state"):
		return _result(false, "The object does not expose layer-session state.")
	var state: Dictionary = session.capture_state()
	var target_states: Array = state.get("paint_targets", [])
	if target_states.is_empty() or target_states.size() > MAX_TARGETS:
		return _result(false, "The layer session has an invalid number of paint targets.")
	var files: Dictionary = {}
	var encoded_targets: Array = []
	for target_index in range(target_states.size()):
		var encoded := _encode_target_state(target_states[target_index], target_index, files)
		if not bool(encoded.get("ok", false)):
			return encoded
		encoded_targets.push_back(encoded.get("target", {}))
	var encoded_groups: Array = []
	for group_value in state.get("object_groups", []):
		if not group_value is Dictionary:
			return _result(false, "The layer session contains an invalid object group.")
		var group: Dictionary = group_value
		encoded_groups.push_back({
			"id": str(group.get("id", "")),
			"label": str(group.get("label", "Object")),
			"parent_id": str(group.get("parent_id", "")),
			"source_key": str(group.get("source_key", "")),
			"source_class": str(group.get("source_class", "")),
			"visible": bool(group.get("visible", true)),
			"target_ids": Array(group.get("target_ids", PackedStringArray())),
		})
	var session_manifest := {
		"format_version": 1,
		"session_kind": str(state.get("session_kind", "2d")),
		"source_scene_path": str(state.get("source_scene_path", "")),
		"source_scene_uid": str(state.get("source_scene_uid", "")),
		"object_groups": encoded_groups,
		"paint_targets": encoded_targets,
		"active_target_id": str(state.get("active_target_id", "")),
		"target_lock_enabled": bool(state.get("target_lock_enabled", false)),
		"next_group_serial": int(state.get("next_group_serial", 1)),
		"next_target_serial": int(state.get("next_target_serial", 1)),
	}
	var manifest := {
		"format": FORMAT_NAME,
		"format_version": FORMAT_VERSION,
		"session": session_manifest,
	}
	files[MANIFEST_PATH] = JSON.stringify(manifest, "\t").to_utf8_buffer()
	var response := _result(true, "Layered document archive prepared.")
	response["files"] = files
	return response


static func _encode_target_state(state: Dictionary, target_index: int, files: Dictionary) -> Dictionary:
	var target_size: Vector2i = state.get("size", Vector2i.ZERO)
	if not _valid_image_size(target_size):
		return _result(false, "A paint target has an invalid image size.")
	var node_counter := [0]
	var encoded_nodes := _encode_nodes(
		state.get("nodes", []),
		target_index,
		target_size,
		files,
		node_counter
	)
	if not bool(encoded_nodes.get("ok", false)):
		return encoded_nodes
	var baseline_path := ""
	var baseline: Image = state.get("saved_composite", null)
	if baseline:
		baseline_path = "images/target_%04d/saved_composite.png" % target_index
		var baseline_result := _store_png(files, baseline_path, baseline, target_size)
		if not bool(baseline_result.get("ok", false)):
			return baseline_result
	var response := _result(true, "Paint target encoded.")
	response["target"] = {
		"target_id": str(state.get("target_id", "")),
		"owner_group_id": str(state.get("owner_group_id", "")),
		"label": str(state.get("label", "Paint Target")),
		"channel_id": str(state.get("channel_id", "rgba")),
		"size": [target_size.x, target_size.y],
		"binding": _json_safe_value(state.get("binding", {})),
		"nodes": encoded_nodes.get("nodes", []),
		"selected_layer_id": str(state.get("selected_layer_id", "")),
		"next_node_serial": int(state.get("next_node_serial", 1)),
		"saved_composite_path": baseline_path,
	}
	return response


static func _encode_nodes(
	nodes: Array,
	target_index: int,
	target_size: Vector2i,
	files: Dictionary,
	node_counter: Array
) -> Dictionary:
	var encoded_nodes: Array = []
	for node_value in nodes:
		if not node_value is Dictionary:
			return _result(false, "A layer node is malformed.")
		node_counter[0] = int(node_counter[0]) + 1
		if int(node_counter[0]) > MAX_NODES_PER_TARGET:
			return _result(false, "A paint target exceeds the layer-node safety limit.")
		var state: Dictionary = node_value
		var kind := int(state.get("kind", 0))
		var encoded := {
			"id": str(state.get("id", "")),
			"kind": kind,
			"name": str(state.get("name", "Layer")),
			"visible": bool(state.get("visible", true)),
			"opacity": float(state.get("opacity", 1.0)),
			"locked": bool(state.get("locked", false)),
			"children": [],
		}
		if kind == 0:
			var serial := int(node_counter[0])
			var layer_image: Image = state.get("image", null)
			var eraser_image: Image = state.get("eraser_source", null)
			if not layer_image or not _valid_image_size(layer_image.get_size()):
				return _result(false, "A layer image has invalid dimensions.")
			var image_path := "images/target_%04d/layer_%04d.png" % [target_index, serial]
			var eraser_path := "images/target_%04d/eraser_%04d.png" % [target_index, serial]
			var image_result := _store_png(files, image_path, layer_image, layer_image.get_size())
			if not bool(image_result.get("ok", false)):
				return image_result
			var eraser_result := _store_png(files, eraser_path, eraser_image, layer_image.get_size())
			if not bool(eraser_result.get("ok", false)):
				return eraser_result
			encoded["image_path"] = image_path
			encoded["eraser_source_path"] = eraser_path
			encoded["image_size"] = [layer_image.get_width(), layer_image.get_height()]
			var layer_origin: Vector2i = state.get("origin", Vector2i.ZERO)
			encoded["origin"] = [layer_origin.x, layer_origin.y]
		else:
			var child_result := _encode_nodes(
				state.get("children", []),
				target_index,
				target_size,
				files,
				node_counter
			)
			if not bool(child_result.get("ok", false)):
				return child_result
			encoded["children"] = child_result.get("nodes", [])
		encoded_nodes.push_back(encoded)
	var response := _result(true, "Layer nodes encoded.")
	response["nodes"] = encoded_nodes
	return response


static func _decode_session_state(manifest: Dictionary, reader: ZIPReader, entries: PackedStringArray) -> Dictionary:
	if int(manifest.get("format_version", 0)) != 1:
		return _result(false, "The layered document session schema is unsupported.")
	var target_manifests: Variant = manifest.get("paint_targets", null)
	if not target_manifests is Array or target_manifests.is_empty() or target_manifests.size() > MAX_TARGETS:
		return _result(false, "The layered document has an invalid number of paint targets.")
	var targets: Array[Dictionary] = []
	for target_value in target_manifests:
		if not target_value is Dictionary:
			return _result(false, "A layered paint target is malformed.")
		var decoded := _decode_target_state(target_value, reader, entries)
		if not bool(decoded.get("ok", false)):
			return decoded
		targets.push_back(decoded.get("target", {}))
	var groups_value: Variant = manifest.get("object_groups", null)
	if not groups_value is Array:
		return _result(false, "The layered document object hierarchy is malformed.")
	var groups: Array[Dictionary] = []
	for group_value in groups_value:
		if not group_value is Dictionary:
			return _result(false, "A layered object group is malformed.")
		var group: Dictionary = group_value
		groups.push_back({
			"id": str(group.get("id", "")),
			"label": str(group.get("label", "Object")),
			"parent_id": str(group.get("parent_id", "")),
			"source_key": str(group.get("source_key", "")),
			"source_class": str(group.get("source_class", "")),
			"visible": bool(group.get("visible", true)),
			"target_ids": PackedStringArray(group.get("target_ids", [])),
		})
	var state := {
		"format_version": 1,
		"session_kind": str(manifest.get("session_kind", "2d")),
		"source_scene_path": str(manifest.get("source_scene_path", "")),
		"source_scene_uid": str(manifest.get("source_scene_uid", "")),
		"object_groups": groups,
		"paint_targets": targets,
		"active_target_id": str(manifest.get("active_target_id", "")),
		"target_lock_enabled": bool(manifest.get("target_lock_enabled", false)),
		"next_group_serial": int(manifest.get("next_group_serial", 1)),
		"next_target_serial": int(manifest.get("next_target_serial", 1)),
	}
	var response := _result(true, "Layered document decoded.")
	response["state"] = state
	return response


static func _decode_target_state(manifest: Dictionary, reader: ZIPReader, entries: PackedStringArray) -> Dictionary:
	var size_value: Variant = manifest.get("size", null)
	if not size_value is Array or size_value.size() != 2:
		return _result(false, "A layered paint target has invalid dimensions.")
	var target_size := Vector2i(int(size_value[0]), int(size_value[1]))
	if not _valid_image_size(target_size):
		return _result(false, "A layered paint target exceeds the image-size safety limit.")
	var counter := [0]
	var decoded_nodes := _decode_nodes(manifest.get("nodes", []), target_size, reader, entries, counter)
	if not bool(decoded_nodes.get("ok", false)):
		return decoded_nodes
	var saved_composite: Image
	var baseline_path := str(manifest.get("saved_composite_path", ""))
	if not baseline_path.is_empty():
		var baseline_result := _read_png(reader, entries, baseline_path, target_size)
		if not bool(baseline_result.get("ok", false)):
			return baseline_result
		saved_composite = baseline_result.get("image", null)
	var response := _result(true, "Paint target decoded.")
	var decoded_binding: Dictionary = manifest.get("binding", {}).duplicate(true)
	if decoded_binding.has("material_slot"):
		decoded_binding["material_slot"] = int(decoded_binding["material_slot"])
	if decoded_binding.has("uv_set"):
		decoded_binding["uv_set"] = int(decoded_binding["uv_set"])
	response["target"] = {
		"target_id": str(manifest.get("target_id", "")),
		"owner_group_id": str(manifest.get("owner_group_id", "")),
		"label": str(manifest.get("label", "Paint Target")),
		"channel_id": str(manifest.get("channel_id", "rgba")),
		"size": target_size,
		"binding": decoded_binding,
		"nodes": decoded_nodes.get("nodes", []),
		"selected_layer_id": str(manifest.get("selected_layer_id", "")),
		"next_node_serial": int(manifest.get("next_node_serial", 1)),
		"saved_composite": saved_composite,
	}
	return response


static func _decode_nodes(
	nodes_value: Variant,
	target_size: Vector2i,
	reader: ZIPReader,
	entries: PackedStringArray,
	node_counter: Array
) -> Dictionary:
	if not nodes_value is Array:
		return _result(false, "A layered node list is malformed.")
	var nodes: Array[Dictionary] = []
	for node_value in nodes_value:
		if not node_value is Dictionary:
			return _result(false, "A layered node is malformed.")
		node_counter[0] = int(node_counter[0]) + 1
		if int(node_counter[0]) > MAX_NODES_PER_TARGET:
			return _result(false, "A layered paint target exceeds the node safety limit.")
		var manifest: Dictionary = node_value
		var kind := int(manifest.get("kind", -1))
		if kind not in [0, 1]:
			return _result(false, "A layered node has an unknown type.")
		var state := {
			"id": str(manifest.get("id", "")),
			"kind": kind,
			"name": str(manifest.get("name", "Layer")),
			"visible": bool(manifest.get("visible", true)),
			"opacity": clampf(float(manifest.get("opacity", 1.0)), 0.0, 1.0),
			"locked": bool(manifest.get("locked", false)),
			"origin": Vector2i.ZERO,
			"image": null,
			"eraser_source": null,
			"children": [],
		}
		if kind == 0:
			var layer_size := target_size
			var layer_size_value: Variant = manifest.get("image_size", null)
			if layer_size_value is Array and layer_size_value.size() == 2:
				layer_size = Vector2i(int(layer_size_value[0]), int(layer_size_value[1]))
			if not _valid_image_size(layer_size):
				return _result(false, "A layered paint image exceeds the image-size safety limit.")
			var origin_value: Variant = manifest.get("origin", null)
			if origin_value is Array and origin_value.size() == 2:
				state["origin"] = Vector2i(int(origin_value[0]), int(origin_value[1]))
			var image_result := _read_png(reader, entries, str(manifest.get("image_path", "")), layer_size)
			if not bool(image_result.get("ok", false)):
				return image_result
			var eraser_result := _read_png(reader, entries, str(manifest.get("eraser_source_path", "")), layer_size)
			if not bool(eraser_result.get("ok", false)):
				return eraser_result
			state["image"] = image_result.get("image", null)
			state["eraser_source"] = eraser_result.get("image", null)
		else:
			var child_result := _decode_nodes(manifest.get("children", []), target_size, reader, entries, node_counter)
			if not bool(child_result.get("ok", false)):
				return child_result
			state["children"] = child_result.get("nodes", [])
		nodes.push_back(state)
	var response := _result(true, "Layer nodes decoded.")
	response["nodes"] = nodes
	return response


static func _store_png(files: Dictionary, path: String, image: Image, expected_size: Vector2i) -> Dictionary:
	if not image or image.is_empty() or image.get_size() != expected_size:
		return _result(false, "A layer image is missing or has inconsistent dimensions.")
	var bytes := image.save_png_to_buffer()
	if bytes.is_empty() or bytes.size() > MAX_IMAGE_BYTES:
		return _result(false, "A layer image could not be encoded within the safety limit.")
	files[path] = bytes
	return _result(true, "Layer image encoded.")


static func _read_png(
	reader: ZIPReader,
	entries: PackedStringArray,
	path: String,
	expected_size: Vector2i
) -> Dictionary:
	if not _is_safe_archive_path(path) or path not in entries:
		return _result(false, "A required layer image is missing or has an unsafe path.")
	var bytes := reader.read_file(path)
	if bytes.is_empty() or bytes.size() > MAX_IMAGE_BYTES:
		return _result(false, "A layer image is empty or exceeds the safety limit.")
	var image := Image.new()
	if image.load_png_from_buffer(bytes) != OK or image.is_empty() or image.get_size() != expected_size:
		return _result(false, "A layer image is corrupt or has inconsistent dimensions.")
	if image.has_mipmaps():
		image.clear_mipmaps()
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	var response := _result(true, "Layer image decoded.")
	response["image"] = image
	return response


static func _commit_temporary_file(temporary_path: String, destination: String, token: String) -> Dictionary:
	if not FileAccess.file_exists(destination):
		if DirAccess.rename_absolute(temporary_path, destination) == OK:
			return _result(true, "Layered document committed.")
		DirAccess.remove_absolute(temporary_path)
		return _result(false, "Could not move the completed layered document into place.")
	var backup_path := destination + ".replacing-" + token
	if DirAccess.rename_absolute(destination, backup_path) != OK:
		DirAccess.remove_absolute(temporary_path)
		return _result(false, "Could not prepare the existing layered document for replacement.")
	if DirAccess.rename_absolute(temporary_path, destination) != OK:
		var restore_error := DirAccess.rename_absolute(backup_path, destination)
		DirAccess.remove_absolute(temporary_path)
		if restore_error != OK:
			return _result(false, "Could not replace the layered document or restore its original; recovery copy remains at %s." % backup_path)
		return _result(false, "Could not replace the existing layered document; the original was restored.")
	var cleanup_error := DirAccess.remove_absolute(backup_path)
	if cleanup_error != OK:
		return _result(false, "The layered document was replaced, but its recovery copy could not be removed (%s)." % backup_path)
	return _result(true, "Layered document committed.")


static func _valid_image_size(size: Vector2i) -> bool:
	return (
		size.x > 0
		and size.y > 0
		and size.x <= MAX_IMAGE_DIMENSION
		and size.y <= MAX_IMAGE_DIMENSION
	)


static func _is_safe_archive_path(path: String) -> bool:
	var normalized := path.replace("\\", "/")
	return (
		not normalized.is_empty()
		and not normalized.begins_with("/")
		and not normalized.contains(":")
		and ".." not in normalized.split("/", false)
	)


static func _json_safe_value(value: Variant) -> Variant:
	if value is Dictionary:
		var result := {}
		for key in value:
			result[str(key)] = _json_safe_value(value[key])
		return result
	if value is Array or value is PackedStringArray or value is PackedInt32Array or value is PackedFloat32Array:
		var result: Array = []
		for item in value:
			result.push_back(_json_safe_value(item))
		return result
	if value is String or value is StringName or value is bool or value is int or value is float or value == null:
		return value
	return str(value)


static func _result(ok: bool, message: String) -> Dictionary:
	return {"ok": ok, "message": message}
