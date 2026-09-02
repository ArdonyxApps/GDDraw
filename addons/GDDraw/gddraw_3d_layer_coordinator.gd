@tool
class_name GDDraw3DLayerCoordinator
extends RefCounted

const LayerSession := preload("res://addons/GDDraw/gddraw_layer_session.gd")
const TextureSession := preload("res://addons/GDDraw/gddraw_3d_texture_session.gd")
const StoragePaths := preload("res://addons/GDDraw/gddraw_storage_paths.gd")

const STATUS := "status"
const MESSAGE := "message"
const STATUS_OK := "ok"
const STATUS_NEEDS_CREATE := "needs_create"
const STATUS_ERROR := "error"

var layer_session
var texture_sessions: Dictionary = {}
var target_descriptors: Dictionary = {}
var target_members: Dictionary = {}
var binding_targets: Dictionary = {}
var _target_dirty_cache: Dictionary = {}


func begin(
	discovery: Dictionary,
	editor_plugin: EditorPlugin,
	create_missing := false,
	create_dir := StoragePaths.DEFAULT_IMAGE_DIR,
	texture_size := TextureSession.DEFAULT_TEXTURE_SIZE
) -> Dictionary:
	clear()
	if str(discovery.get(STATUS, STATUS_ERROR)) != STATUS_OK:
		return _result(STATUS_ERROR, str(discovery.get(MESSAGE, "3D target discovery did not succeed.")))
	var descriptors: Array = discovery.get("targets", [])
	if descriptors.is_empty():
		return _result(STATUS_ERROR, "The discovery result contains no paint targets.")

	var prepared: Array[Dictionary] = []
	var pending: Array[Dictionary] = []
	for descriptor_value in descriptors:
		if not descriptor_value is Dictionary:
			clear()
			return _result(STATUS_ERROR, "The discovery result contains an invalid target descriptor.")
		var descriptor: Dictionary = descriptor_value
		var source: Node = descriptor.get("source_node", null)
		if not is_instance_valid(source):
			clear()
			return _result(STATUS_ERROR, "%s is no longer available in the edited scene." % descriptor.get("label", "A discovered target"))
		var candidate := TextureSession.new()
		var result: Dictionary = candidate.begin_from_target(
			source,
			editor_plugin,
			false,
			create_dir,
			texture_size,
			int(descriptor.get("material_slot", 0))
		)
		var status := str(result.get(STATUS, STATUS_ERROR))
		if status == STATUS_NEEDS_CREATE:
			pending.push_back({"descriptor": descriptor, "session": candidate, "result": result})
			continue
		if status != STATUS_OK:
			clear()
			return _result(STATUS_ERROR, str(result.get(MESSAGE, "Could not prepare a discovered paint target.")))
		prepared.push_back({"descriptor": descriptor, "session": candidate, "result": result})

	if not pending.is_empty() and not create_missing:
		var response := _result(
			STATUS_NEEDS_CREATE,
			"%d discovered target(s) need a material or texture. Confirm once to create all listed targets." % pending.size()
		)
		response["pending_targets"] = _pending_descriptors(pending)
		clear()
		return response

	for pending_entry in pending:
		var descriptor: Dictionary = pending_entry.get("descriptor", {})
		var candidate = pending_entry.get("session")
		var result: Dictionary = candidate.begin_from_target(
			descriptor.get("source_node", null),
			editor_plugin,
			true,
			create_dir,
			texture_size,
			int(descriptor.get("material_slot", 0))
		)
		if str(result.get(STATUS, STATUS_ERROR)) != STATUS_OK:
			clear()
			return _result(STATUS_ERROR, str(result.get(MESSAGE, "Could not create a missing 3D paint target.")))
		prepared.push_back({"descriptor": descriptor, "session": candidate, "result": result})

	if not _build_layer_session(discovery.get("groups", []), prepared):
		_clear_prepared_sessions(prepared)
		clear()
		return _result(STATUS_ERROR, "Could not build a coherent layer session from the discovered targets.")
	return _result(
		STATUS_OK,
		"Opened %d 3D paint target(s) from %d scene binding(s)." % [texture_sessions.size(), prepared.size()]
	)


func restore_session(saved_session, editor_plugin: EditorPlugin, scene_root: Node) -> Dictionary:
	if not saved_session or saved_session.session_kind != "3d" or not scene_root:
		return _result(STATUS_ERROR, "A saved 3D layer session and active scene tree are required.")
	var restored_texture_sessions: Dictionary = {}
	var restored_descriptors: Dictionary = {}
	var restored_members: Dictionary = {}
	var restored_bindings: Dictionary = {}
	var restored_prepared: Array[Dictionary] = []
	var all_candidates := {}
	for paint_target in saved_session.paint_targets:
		var binding: Dictionary = paint_target.binding
		var target_id: String = paint_target.target_id
		var saved_members: Array = binding.get("members", [])
		if saved_members.is_empty():
			saved_members = [binding]
		var runtime_members: Array[Dictionary] = []
		for saved_member_value in saved_members:
			if not saved_member_value is Dictionary:
				_clear_candidate_sessions(all_candidates)
				return _result(STATUS_ERROR, "A saved 3D target contains an invalid scene binding.")
			var saved_member: Dictionary = saved_member_value
			var source_key := str(saved_member.get("source_key", ""))
			var source_relative_path := str(saved_member.get("source_relative_path", ""))
			var source := _resolve_saved_source(scene_root, source_relative_path, source_key)
			if not is_instance_valid(source):
				_clear_candidate_sessions(all_candidates)
				return _result(
					STATUS_ERROR,
					"Could not reattach %s because scene node %s is not currently available." % [paint_target.label, source_key]
				)
			var texture_session := TextureSession.new()
			all_candidates[texture_session.get_instance_id()] = texture_session
			var result: Dictionary = texture_session.begin_from_target(
				source,
				editor_plugin,
				false,
				StoragePaths.DEFAULT_IMAGE_DIR,
				paint_target.size,
				int(saved_member.get("material_slot", 0))
			)
			if str(result.get(STATUS, STATUS_ERROR)) != STATUS_OK:
				_clear_candidate_sessions(all_candidates)
				return _result(STATUS_ERROR, str(result.get(MESSAGE, "A saved 3D target could not be reattached.")))
			var texture_image: Image = result.get(TextureSession.IMAGE, null)
			if not texture_image or texture_image.get_size() != paint_target.size:
				_clear_candidate_sessions(all_candidates)
				return _result(STATUS_ERROR, "%s no longer matches the saved layer dimensions." % paint_target.label)
			var binding_key := str(saved_member.get("key", ""))
			var descriptor := {
				"key": binding_key,
				"source_key": source_key,
				"source_relative_path": source_relative_path,
				"source_node": source,
				"source_class": source.get_class(),
				"material_slot": int(saved_member.get("material_slot", 0)),
				"channel": str(saved_member.get("channel", "albedo")),
				"uv_set": int(saved_member.get("uv_set", 0)),
				"label": paint_target.label,
			}
			runtime_members.push_back({"descriptor": descriptor, "session": texture_session})
			if not binding_key.is_empty():
				restored_bindings[binding_key] = target_id
		if runtime_members.is_empty():
			_clear_candidate_sessions(all_candidates)
			return _result(STATUS_ERROR, "A saved 3D target contains no scene bindings.")
		var primary_member: Dictionary = runtime_members[0]
		var primary_session = primary_member.get("session")
		restored_texture_sessions[target_id] = primary_session
		restored_prepared.push_back({"session": primary_session})
		restored_descriptors[target_id] = primary_member.get("descriptor", {})
		restored_members[target_id] = runtime_members
	if restored_texture_sessions.size() != saved_session.paint_targets.size():
		_clear_candidate_sessions(all_candidates)
		return _result(STATUS_ERROR, "Not every saved 3D paint target could be reattached.")
	var duplicate_destination := _find_duplicate_texture_destination(restored_prepared)
	if not duplicate_destination.is_empty():
		_clear_candidate_sessions(all_candidates)
		return _result(
			STATUS_ERROR,
			"The saved session resolves multiple independent targets to %s. Reattachment stopped to prevent an overwrite." % duplicate_destination
		)
	clear()
	layer_session = saved_session
	texture_sessions = restored_texture_sessions
	target_descriptors = restored_descriptors
	target_members = restored_members
	binding_targets = restored_bindings
	return _result(
		STATUS_OK,
		"Reopened %d layered 3D paint target(s) with %d scene binding(s)." % [texture_sessions.size(), restored_bindings.size()]
	)


func clear() -> void:
	var candidates := {}
	for member_entries_value in target_members.values():
		for member_entry_value in member_entries_value:
			if member_entry_value is Dictionary:
				var member_candidate = member_entry_value.get("session")
				if member_candidate:
					candidates[member_candidate.get_instance_id()] = member_candidate
	for candidate in texture_sessions.values():
		if candidate:
			candidates[candidate.get_instance_id()] = candidate
	for candidate in candidates.values():
		if candidate and candidate.has_method("clear"):
			candidate.clear()
	layer_session = null
	texture_sessions.clear()
	target_descriptors.clear()
	target_members.clear()
	binding_targets.clear()
	_target_dirty_cache.clear()


func _clear_candidate_sessions(candidates: Dictionary) -> void:
	for candidate in candidates.values():
		if candidate and candidate.has_method("clear"):
			candidate.clear()


func _clear_prepared_sessions(prepared: Array[Dictionary]) -> void:
	var candidates := {}
	for entry in prepared:
		var candidate = entry.get("session")
		if candidate:
			candidates[candidate.get_instance_id()] = candidate
	_clear_candidate_sessions(candidates)


func _find_duplicate_texture_destination(prepared: Array[Dictionary]) -> String:
	var owners := {}
	for entry in prepared:
		var texture_session = entry.get("session")
		if not texture_session:
			continue
		var path := str(texture_session.texture_path).strip_edges()
		if path.is_empty():
			continue
		var normalized := path.replace("\\", "/").to_lower()
		if owners.has(normalized):
			return path
		owners[normalized] = true
	return ""


func has_active_session() -> bool:
	return layer_session != null and not texture_sessions.is_empty() and get_active_texture_session() != null


func get_active_texture_session():
	if not layer_session:
		return null
	return texture_sessions.get(layer_session.active_target_id)


func get_texture_session(target_id: String):
	return texture_sessions.get(target_id)


func get_preview_entries() -> Array[Dictionary]:
	var previews: Array[Dictionary] = []
	for target_id_value in texture_sessions:
		var target_id := str(target_id_value)
		var members: Array = target_members.get(target_id, [])
		if members.is_empty():
			previews.push_back({
				"target_id": target_id,
				"binding_key": str(target_descriptors.get(target_id, {}).get("key", "")),
				"session": texture_sessions.get(target_id),
				"descriptor": target_descriptors.get(target_id, {}),
				"is_primary": true,
			})
			continue
		for index in range(members.size()):
			var member: Dictionary = members[index]
			var descriptor: Dictionary = member.get("descriptor", {})
			previews.push_back({
				"target_id": target_id,
				"binding_key": str(descriptor.get("key", "")),
				"session": member.get("session"),
				"descriptor": descriptor,
				"is_primary": index == 0,
			})
	return previews


func activate_target(target_id: String) -> bool:
	return layer_session != null and texture_sessions.has(target_id) and layer_session.activate_target(target_id)


func route_binding(binding_key: String) -> bool:
	if not layer_session:
		return false
	var target_id := str(binding_targets.get(binding_key, ""))
	return not target_id.is_empty() and layer_session.route_hit_to_target(target_id)


func get_target_id_for_binding(binding_key: String) -> String:
	return str(binding_targets.get(binding_key, ""))


func get_binding_for_source_node(source_node: Node) -> Dictionary:
	if not is_instance_valid(source_node):
		return {}
	var exact_matches: Array[Dictionary] = []
	var descendant_matches: Array[Dictionary] = []
	for target_id_value in target_members:
		var target_id := str(target_id_value)
		for member_value in target_members.get(target_id, []):
			if not member_value is Dictionary:
				continue
			var member: Dictionary = member_value
			var descriptor: Dictionary = member.get("descriptor", {})
			var member_source: Node = descriptor.get("source_node", null)
			if not is_instance_valid(member_source):
				continue
			var match := {
				"target_id": target_id,
				"binding_key": str(descriptor.get("key", "")),
				"group_key": str(descriptor.get("group_key", descriptor.get("source_key", ""))),
				"source_node": member_source,
			}
			if member_source == source_node:
				exact_matches.push_back(match)
			elif source_node.is_ancestor_of(member_source):
				descendant_matches.push_back(match)
	var matches := exact_matches if not exact_matches.is_empty() else descendant_matches
	if matches.is_empty():
		return {}
	var resolved_target_id := str(matches[0].get("target_id", ""))
	for match in matches:
		if str(match.get("target_id", "")) != resolved_target_id:
			return {}
	return matches[0].duplicate(true)


func get_binding(binding_key: String) -> Dictionary:
	if binding_key.is_empty():
		return {}
	var target_id := str(binding_targets.get(binding_key, ""))
	for member_value in target_members.get(target_id, []):
		if not member_value is Dictionary:
			continue
		var descriptor: Dictionary = member_value.get("descriptor", {})
		if str(descriptor.get("key", "")) == binding_key:
			return {
				"target_id": target_id,
				"binding_key": binding_key,
				"group_key": str(descriptor.get("group_key", descriptor.get("source_key", ""))),
				"source_node": descriptor.get("source_node", null),
			}
	return {}


func get_primary_binding_for_target(target_id: String) -> Dictionary:
	var members: Array = target_members.get(target_id, [])
	if members.is_empty() or not members[0] is Dictionary:
		return {}
	var descriptor: Dictionary = members[0].get("descriptor", {})
	return get_binding(str(descriptor.get("key", "")))


func is_dirty(active_target_image: Image = null) -> bool:
	return not get_dirty_target_ids(active_target_image).is_empty()


func get_dirty_target_ids(active_target_image: Image = null) -> PackedStringArray:
	var dirty := PackedStringArray()
	if not layer_session:
		return dirty
	for target_id in texture_sessions:
		var target = layer_session.get_target(str(target_id))
		var texture_session = texture_sessions[target_id]
		if not target or not texture_session:
			continue
		var cache_key := _make_target_dirty_cache_key(target, texture_session)
		var cached: Dictionary = _target_dirty_cache.get(str(target_id), {})
		var target_is_dirty: bool
		if str(cached.get("key", "")) == cache_key:
			target_is_dirty = bool(cached.get("dirty", false))
		else:
			var composite_image: Image = (
				active_target_image
				if active_target_image and str(target_id) == layer_session.active_target_id
				else target.composite()
			)
			target_is_dirty = texture_session.is_dirty(composite_image)
			_target_dirty_cache[str(target_id)] = {
				"key": cache_key,
				"dirty": target_is_dirty,
			}
		if target_is_dirty:
			dirty.push_back(str(target_id))
	return dirty


func _make_target_dirty_cache_key(target, texture_session) -> String:
	var baseline: Image = texture_session.baseline_image if texture_session else null
	var parts := PackedStringArray([
		str(target.size),
		"baseline=" + (str(baseline.get_instance_id()) if baseline else "null"),
		"revision=" + str(target.get_content_revision() if target.has_method("get_content_revision") else 0),
	])
	for node in target.nodes:
		_append_target_dirty_cache_key(parts, node)
	return "|".join(parts)


func _append_target_dirty_cache_key(parts: PackedStringArray, node) -> void:
	parts.push_back(str(node.id))
	parts.push_back(str(node.visible))
	parts.push_back(str(node.opacity))
	if node.is_paint_layer():
		parts.push_back(str(node.origin))
		parts.push_back(str(node.image.get_instance_id()) if node.image else "null")
		return
	for child in node.children:
		_append_target_dirty_cache_key(parts, child)
	parts.push_back("group_end")


func _build_layer_session(group_descriptors: Array, prepared: Array[Dictionary]) -> bool:
	var session := LayerSession.new()
	session.clear()
	session.session_kind = "3d"
	var group_ids := {}
	for group_value in group_descriptors:
		if not group_value is Dictionary:
			return false
		var group: Dictionary = group_value
		var key := str(group.get("key", ""))
		var parent_key := str(group.get("parent_key", ""))
		var parent_id := str(group_ids.get(parent_key, ""))
		if key.is_empty() or (not parent_key.is_empty() and parent_id.is_empty()):
			return false
		group_ids[key] = session.add_object_group(
			str(group.get("label", "Object")),
			parent_id,
			key,
			str(group.get("class_name", ""))
		)
		if str(group_ids[key]).is_empty():
			return false

	var shared_entries := {}
	var shared_order := PackedStringArray()
	for prepared_index in range(prepared.size()):
		var entry: Dictionary = prepared[prepared_index]
		var descriptor: Dictionary = entry.get("descriptor", {})
		var texture_session = entry.get("session")
		var destination_key := _get_shared_destination_key(texture_session, descriptor, prepared_index)
		if not shared_entries.has(destination_key):
			shared_entries[destination_key] = []
			shared_order.push_back(destination_key)
		(shared_entries[destination_key] as Array).push_back(entry)

	for destination_key in shared_order:
		var entries: Array = shared_entries.get(destination_key, [])
		if entries.is_empty():
			return false
		var primary_entry: Dictionary = entries[0]
		var primary_descriptor: Dictionary = primary_entry.get("descriptor", {})
		var primary_result: Dictionary = primary_entry.get("result", {})
		var primary_texture_session = primary_entry.get("session")
		var primary_group_id := str(group_ids.get(str(primary_descriptor.get("group_key", "")), ""))
		var image: Image = primary_result.get(TextureSession.IMAGE, null)
		if primary_group_id.is_empty() or not image or not primary_texture_session:
			return false
		var member_bindings: Array[Dictionary] = []
		for member_entry_value in entries:
			var member_entry: Dictionary = member_entry_value
			var member_descriptor: Dictionary = member_entry.get("descriptor", {})
			var member_session = member_entry.get("session")
			var member_result: Dictionary = member_entry.get("result", {})
			var member_image: Image = member_result.get(TextureSession.IMAGE, null)
			if not member_session or not member_image or member_image.get_size() != image.get_size():
				return false
			member_bindings.push_back(_make_persistent_binding(member_descriptor, member_session))
		var binding: Dictionary = member_bindings[0].duplicate(true)
		binding["members"] = member_bindings.duplicate(true)
		var target = session.create_target(
			primary_group_id,
			image.get_size(),
			image,
			str(primary_descriptor.get("label", "Albedo")),
			str(primary_descriptor.get("channel", "albedo")),
			binding
		)
		if not target:
			return false
		var initial_layer = target.get_selected_layer()
		var texture_layer_name := _get_texture_layer_name(primary_texture_session, primary_descriptor)
		if initial_layer and not texture_layer_name.is_empty():
			initial_layer.name = texture_layer_name
		var runtime_members: Array[Dictionary] = []
		for member_entry_value in entries:
			var member_entry: Dictionary = member_entry_value
			var member_descriptor: Dictionary = member_entry.get("descriptor", {})
			var member_session = member_entry.get("session")
			var member_group_id := str(group_ids.get(str(member_descriptor.get("group_key", "")), ""))
			if member_group_id.is_empty() or not session.add_target_reference(member_group_id, target.target_id):
				return false
			runtime_members.push_back({
				"descriptor": member_descriptor.duplicate(true),
				"session": member_session,
			})
			binding_targets[str(member_descriptor.get("key", ""))] = target.target_id
		texture_sessions[target.target_id] = primary_texture_session
		target_descriptors[target.target_id] = primary_descriptor.duplicate(true)
		target_members[target.target_id] = runtime_members

	layer_session = session
	if layer_session.has_method("mark_layered_saved"):
		layer_session.mark_layered_saved()
	return layer_session.get_active_target() != null


func _get_texture_layer_name(texture_session, descriptor: Dictionary) -> String:
	var texture_path := str(texture_session.texture_path).strip_edges() if texture_session else ""
	if texture_path.is_empty():
		texture_path = str(descriptor.get("texture_path", "")).strip_edges()
	return texture_path.get_file() if not texture_path.is_empty() else "Base"


func _get_shared_destination_key(texture_session, descriptor: Dictionary, fallback_index: int) -> String:
	if texture_session:
		var path := str(texture_session.texture_path).strip_edges().replace("\\", "/").to_lower()
		if not path.is_empty():
			return "path:" + path
	return "binding:%s:%d" % [str(descriptor.get("key", "")), fallback_index]


func _make_persistent_binding(descriptor: Dictionary, texture_session) -> Dictionary:
	return {
		"key": str(descriptor.get("key", "")),
		"source_key": str(descriptor.get("source_key", "")),
		"source_relative_path": str(descriptor.get("source_relative_path", "")),
		"source_class": str(descriptor.get("source_class", "Node3D")),
		"material_slot": int(descriptor.get("material_slot", 0)),
		"channel": str(descriptor.get("channel", "albedo")),
		"uv_set": int(descriptor.get("uv_set", 0)),
		"texture_path": str(texture_session.texture_path) if texture_session else "",
	}


func _resolve_saved_source(scene_root: Node, relative_path: String, source_key: String) -> Node:
	if not scene_root:
		return null
	if not relative_path.is_empty():
		if relative_path == ".":
			return scene_root
		var relative_source := scene_root.get_node_or_null(NodePath(relative_path))
		if is_instance_valid(relative_source):
			return relative_source
	if source_key.is_empty():
		return null
	var legacy_source := scene_root.get_node_or_null(NodePath(source_key))
	if is_instance_valid(legacy_source):
		return legacy_source
	var tree := scene_root.get_tree()
	return tree.root.get_node_or_null(NodePath(source_key)) if tree else null


func _pending_descriptors(pending: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in pending:
		var descriptor: Dictionary = entry.get("descriptor", {})
		result.push_back({
			"key": str(descriptor.get("key", "")),
			"label": str(descriptor.get("label", "3D paint target")),
			"missing_material": bool(descriptor.get("missing_material", false)),
			"missing_texture": bool(descriptor.get("missing_texture", false)),
		})
	return result


func _result(status: String, message: String) -> Dictionary:
	return {STATUS: status, MESSAGE: message}
