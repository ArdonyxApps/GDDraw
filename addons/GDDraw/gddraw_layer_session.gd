@tool
class_name GDDrawLayerSession
extends RefCounted

const PaintTarget := preload("res://addons/GDDraw/gddraw_paint_target.gd")

var session_kind := "2d"
var source_scene_path := ""
var source_scene_uid := ""
var object_groups: Array[Dictionary] = []
var paint_targets: Array = []
var active_target_id := ""
var target_lock_enabled := false

var _next_group_serial := 1
var _next_target_serial := 1
var _layered_saved_fingerprint := ""
var _image_fingerprint_cache: Dictionary = {}


func initialize_2d(initial_size: Vector2i, image: Image = null, document_label := "2D Document") -> bool:
	clear()
	session_kind = "2d"
	var group_id := add_object_group(document_label)
	var target := PaintTarget.new()
	if not target.initialize(initial_size, image, "RGBA", "rgba"):
		clear()
		return false
	var added := add_target(group_id, target)
	if added:
		mark_layered_saved()
	return added


func clear() -> void:
	session_kind = "2d"
	source_scene_path = ""
	source_scene_uid = ""
	object_groups.clear()
	paint_targets.clear()
	active_target_id = ""
	target_lock_enabled = false
	_next_group_serial = 1
	_next_target_serial = 1
	_layered_saved_fingerprint = ""
	_image_fingerprint_cache.clear()


func add_object_group(group_label: String, parent_group_id := "", source_key := "", source_class := "") -> String:
	if not parent_group_id.is_empty() and get_object_group(parent_group_id).is_empty():
		return ""
	var group_id := _allocate_group_id()
	object_groups.push_back({
		"id": group_id,
		"label": group_label.strip_edges() if not group_label.strip_edges().is_empty() else "Object",
		"parent_id": parent_group_id,
		"source_key": source_key,
		"source_class": source_class,
		"visible": true,
		"target_ids": PackedStringArray(),
	})
	return group_id


func add_target(group_id: String, target) -> bool:
	var group := get_object_group(group_id)
	if group.is_empty() or not target or not target.ensure_invariants():
		return false
	if target.target_id.is_empty():
		target.target_id = _allocate_target_id()
	if get_target(target.target_id):
		return false
	target.owner_group_id = group_id
	paint_targets.push_back(target)
	var target_ids: PackedStringArray = group.get("target_ids", PackedStringArray())
	target_ids.push_back(target.target_id)
	group["target_ids"] = target_ids
	if active_target_id.is_empty():
		active_target_id = target.target_id
	return true


func add_target_reference(group_id: String, target_id: String) -> bool:
	var group := get_object_group(group_id)
	if group.is_empty() or not get_target(target_id):
		return false
	var target_ids: PackedStringArray = group.get("target_ids", PackedStringArray())
	if target_id in target_ids:
		return true
	target_ids.push_back(target_id)
	group["target_ids"] = target_ids
	return true


func create_target(
	group_id: String,
	target_size: Vector2i,
	image: Image = null,
	target_label := "Paint Target",
	channel := "rgba",
	target_binding: Dictionary = {}
):
	var target := PaintTarget.new()
	if not target.initialize(target_size, image, target_label, channel):
		return null
	target.binding = target_binding.duplicate(true)
	return target if add_target(group_id, target) else null


func get_object_group(group_id: String) -> Dictionary:
	for group in object_groups:
		if str(group.get("id", "")) == group_id:
			return group
	return {}


func set_object_group_visible(group_id: String, visible: bool) -> bool:
	var group := get_object_group(group_id)
	if group.is_empty():
		return false
	group["visible"] = visible
	return true


func is_object_group_effectively_visible(group_id: String) -> bool:
	if group_id.is_empty():
		return false
	var current_id := group_id
	var visited := {}
	while not current_id.is_empty() and not visited.has(current_id):
		visited[current_id] = true
		var group := get_object_group(current_id)
		if group.is_empty():
			return false
		if not bool(group.get("visible", true)):
			return false
		current_id = str(group.get("parent_id", ""))
	return current_id.is_empty()


func get_target(target_id: String):
	for target in paint_targets:
		if target.target_id == target_id:
			return target
	return null


func get_active_target():
	return get_target(active_target_id)


func activate_target(target_id: String) -> bool:
	if not get_target(target_id):
		return false
	active_target_id = target_id
	return true


func route_hit_to_target(target_id: String) -> bool:
	if not get_target(target_id):
		return false
	if target_lock_enabled and not active_target_id.is_empty() and target_id != active_target_id:
		return false
	active_target_id = target_id
	return true


func set_target_lock_enabled(enabled: bool) -> void:
	target_lock_enabled = enabled and not active_target_id.is_empty()


func mark_layered_saved() -> void:
	_layered_saved_fingerprint = _make_layered_fingerprint()


func is_layered_dirty() -> bool:
	return _layered_saved_fingerprint.is_empty() or _layered_saved_fingerprint != _make_layered_fingerprint()


func requires_layered_persistence() -> bool:
	if paint_targets.size() != 1 or object_groups.size() != 1 or target_lock_enabled:
		return true
	var target = paint_targets[0]
	if target.nodes.size() != 1 or target.get_paint_layer_count() != 1:
		return true
	var node = target.nodes[0]
	var default_layer_name := "Base"
	if session_kind == "3d":
		var texture_path := str(target.binding.get("texture_path", "")).strip_edges()
		if not texture_path.is_empty():
			default_layer_name = texture_path.get_file()
	return (
		not node.is_paint_layer()
		or node.name != default_layer_name
		or not node.visible
		or not is_equal_approx(node.opacity, 1.0)
		or node.locked
	)


func capture_state() -> Dictionary:
	var target_states: Array[Dictionary] = []
	for target in paint_targets:
		target_states.push_back(target.capture_state())
	return {
		"format_version": 1,
		"session_kind": session_kind,
		"source_scene_path": source_scene_path,
		"source_scene_uid": source_scene_uid,
		"object_groups": object_groups.duplicate(true),
		"paint_targets": target_states,
		"active_target_id": active_target_id,
		"target_lock_enabled": target_lock_enabled,
		"next_group_serial": _next_group_serial,
		"next_target_serial": _next_target_serial,
		"layered_saved_fingerprint": _layered_saved_fingerprint,
	}


func capture_state_with_active_layer_image(layer_image: Image, layer_origin = null) -> Dictionary:
	var active_target = get_active_target()
	if not active_target:
		return {}
	var target_state: Dictionary = active_target.capture_state_with_selected_layer_image(layer_image, layer_origin)
	if target_state.is_empty():
		return {}
	var state := capture_state()
	var target_states: Array = state.get("paint_targets", [])
	for index in range(target_states.size()):
		if str(target_states[index].get("target_id", "")) == active_target_id:
			target_states[index] = target_state
			return state
	return {}


func capture_history_state_with_active_layer_image(layer_image: Image, layer_origin = null) -> Dictionary:
	var active_target = get_active_target()
	if not active_target:
		return {}
	var target_states: Array[Dictionary] = []
	for target in paint_targets:
		var target_state: Dictionary
		if target.target_id == active_target_id:
			target_state = target.capture_history_state_with_selected_layer_image(layer_image, layer_origin)
		else:
			target_state = target.capture_history_state()
		if target_state.is_empty():
			return {}
		target_states.push_back(target_state)
	return {
		"format_version": 1,
		"session_kind": session_kind,
		"source_scene_path": source_scene_path,
		"source_scene_uid": source_scene_uid,
		"object_groups": object_groups.duplicate(true),
		"paint_targets": target_states,
		"active_target_id": active_target_id,
		"target_lock_enabled": target_lock_enabled,
		"next_group_serial": _next_group_serial,
		"next_target_serial": _next_target_serial,
		"layered_saved_fingerprint": _layered_saved_fingerprint,
	}


func restore_state(state: Dictionary) -> bool:
	if int(state.get("format_version", 0)) != 1:
		return false
	var restored_groups: Array[Dictionary] = []
	for group_state in state.get("object_groups", []):
		if not group_state is Dictionary or str(group_state.get("id", "")).is_empty():
			return false
		var restored_group: Dictionary = group_state.duplicate(true)
		restored_group["visible"] = bool(restored_group.get("visible", true))
		restored_groups.push_back(restored_group)
	var restored_targets: Array = []
	for target_state in state.get("paint_targets", []):
		if not target_state is Dictionary:
			return false
		var target := PaintTarget.new()
		if not target.restore_state(target_state):
			return false
		restored_targets.push_back(target)
	if restored_groups.is_empty() or restored_targets.is_empty():
		return false
	_image_fingerprint_cache.clear()
	var restored_active_id := str(state.get("active_target_id", ""))
	var active_exists := false
	for target in restored_targets:
		if target.target_id == restored_active_id:
			active_exists = true
		break
	if not active_exists:
		restored_active_id = restored_targets[0].target_id
	session_kind = str(state.get("session_kind", "2d"))
	source_scene_path = str(state.get("source_scene_path", ""))
	source_scene_uid = str(state.get("source_scene_uid", ""))
	object_groups = restored_groups
	paint_targets = restored_targets
	active_target_id = restored_active_id
	target_lock_enabled = bool(state.get("target_lock_enabled", false))
	_next_group_serial = maxi(1, int(state.get("next_group_serial", 1)))
	_next_target_serial = maxi(1, int(state.get("next_target_serial", 1)))
	_layered_saved_fingerprint = str(state.get("layered_saved_fingerprint", ""))
	return _validate_ownership()


func _make_layered_fingerprint() -> String:
	var parts := PackedStringArray([
		"kind=" + session_kind,
		"source_scene_path=" + source_scene_path,
		"source_scene_uid=" + source_scene_uid,
		"active=" + active_target_id,
		"target_lock=" + str(target_lock_enabled),
		"group_serial=" + str(_next_group_serial),
		"target_serial=" + str(_next_target_serial),
	])
	for group in object_groups:
		parts.push_back("group")
		parts.push_back(str(group.get("id", "")))
		parts.push_back(str(group.get("label", "")))
		parts.push_back(str(group.get("parent_id", "")))
		parts.push_back(str(group.get("source_key", "")))
		parts.push_back(str(group.get("source_class", "")))
		parts.push_back("visible=" + str(bool(group.get("visible", true))))
		for target_id in group.get("target_ids", PackedStringArray()):
			parts.push_back("owns=" + str(target_id))
	for target in paint_targets:
		parts.push_back("target")
		parts.push_back(target.target_id)
		parts.push_back(target.owner_group_id)
		parts.push_back(target.label)
		parts.push_back(target.channel_id)
		parts.push_back(str(target.size))
		parts.push_back(_canonical_variant(target.binding))
		parts.push_back(target.selected_layer_id)
		parts.push_back(str(target._next_node_serial))
		_append_layer_fingerprint(parts, target.nodes)
	return _sha256_bytes("|".join(parts).to_utf8_buffer())


func _append_layer_fingerprint(parts: PackedStringArray, nodes: Array) -> void:
	for node in nodes:
		parts.push_back("node")
		parts.push_back(node.id)
		parts.push_back(str(node.kind))
		parts.push_back(node.name)
		parts.push_back(str(node.visible))
		parts.push_back(str(node.opacity))
		parts.push_back(str(node.locked))
		if node.is_paint_layer():
			parts.push_back(str(node.origin))
			parts.push_back(_image_fingerprint(node.image))
			parts.push_back(_image_fingerprint(node.eraser_source))
		else:
			_append_layer_fingerprint(parts, node.children)
		parts.push_back("node_end")


func _image_fingerprint(image: Image) -> String:
	if not image:
		return "null"
	var cache_key := "%d:%s:%s" % [image.get_instance_id(), image.get_size(), image.get_format()]
	if _image_fingerprint_cache.has(cache_key):
		return str(_image_fingerprint_cache[cache_key])
	var fingerprint := "%s:%s:%s" % [image.get_size(), image.get_format(), _sha256_bytes(image.get_data())]
	_image_fingerprint_cache[cache_key] = fingerprint
	return fingerprint


func _sha256_bytes(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK or context.update(bytes) != OK:
		return str(hash(bytes))
	return context.finish().hex_encode()


func _canonical_variant(value: Variant) -> String:
	if value is Dictionary:
		var keys: Array = value.keys()
		keys.sort_custom(func(left, right): return str(left) < str(right))
		var entries := PackedStringArray()
		for key in keys:
			entries.push_back("%s:%s" % [str(key), _canonical_variant(value[key])])
		return "{" + ",".join(entries) + "}"
	if value is Array or value is PackedStringArray or value is PackedInt32Array or value is PackedFloat32Array:
		var entries := PackedStringArray()
		for item in value:
			entries.push_back(_canonical_variant(item))
		return "[" + ",".join(entries) + "]"
	return "%s:%s" % [typeof(value), str(value)]


func _validate_ownership() -> bool:
	var group_ids := {}
	for group in object_groups:
		var group_id := str(group.get("id", ""))
		if group_ids.has(group_id):
			return false
		group_ids[group_id] = true
	for group in object_groups:
		var parent_id := str(group.get("parent_id", ""))
		if not parent_id.is_empty() and not group_ids.has(parent_id):
			return false
	var target_ids := {}
	for target in paint_targets:
		if target_ids.has(target.target_id) or not group_ids.has(target.owner_group_id):
			return false
		target_ids[target.target_id] = true
	for group in object_groups:
		for target_id in group.get("target_ids", PackedStringArray()):
			var target = get_target(target_id)
			if not target:
				return false
	for target in paint_targets:
		var primary_group := get_object_group(target.owner_group_id)
		if primary_group.is_empty() or not target.target_id in primary_group.get("target_ids", PackedStringArray()):
			return false
	return true


func _allocate_group_id() -> String:
	var next_id := "object_%d" % _next_group_serial
	_next_group_serial += 1
	while not get_object_group(next_id).is_empty():
		next_id = "object_%d" % _next_group_serial
		_next_group_serial += 1
	return next_id


func _allocate_target_id() -> String:
	var next_id := "target_%d" % _next_target_serial
	_next_target_serial += 1
	while get_target(next_id):
		next_id = "target_%d" % _next_target_serial
		_next_target_serial += 1
	return next_id
