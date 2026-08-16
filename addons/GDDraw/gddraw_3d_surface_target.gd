@tool
class_name GDDraw3DSurfaceTarget
extends RefCounted

const STATUS := "status"
const MESSAGE := "message"
const STATUS_OK := "ok"
const STATUS_ERROR := "error"

var source_node: Node3D
var source_name := "3D Surface"
var source_class_name := "Node3D"
var mesh_snapshot: Mesh
var source_transform := Transform3D.IDENTITY
var is_csg := false
var material_slot := 0
var material: StandardMaterial3D
var geometry_signature := ""
var preview_surface_slots := PackedInt32Array()


static func from_node(node: Node) -> GDDraw3DSurfaceTarget:
	if not node or not (node is MeshInstance3D or node is CSGShape3D):
		return null
	var target := GDDraw3DSurfaceTarget.new()
	if target._capture(node as Node3D).get(STATUS, STATUS_ERROR) != STATUS_OK:
		return null
	return target


func inspect(node: Node) -> Dictionary:
	return _capture(node as Node3D if node is Node3D else null)


func refresh_geometry() -> Dictionary:
	if not is_instance_valid(source_node):
		return _result(STATUS_ERROR, "The source 3D node was removed from the scene.")
	var previous_signature := geometry_signature
	var previous_slot := material_slot
	var capture_result := _capture(source_node)
	if capture_result.get(STATUS, STATUS_ERROR) != STATUS_OK:
		return capture_result
	# _capture() deliberately resets material while rebuilding the geometry
	# snapshot. A live texture session must reselect its authoritative material
	# slot before an asynchronous Save As assignment can continue.
	var selection_result := select_material(previous_slot)
	if selection_result.get(STATUS, STATUS_ERROR) != STATUS_OK:
		return selection_result
	return {
		STATUS: STATUS_OK,
		MESSAGE: "",
		"changed": previous_signature != geometry_signature,
	}


func get_source_label() -> String:
	if not is_instance_valid(source_node):
		return "%s (%s)" % [source_name, source_class_name]
	return "%s (%s)" % [source_node.name, source_node.get_class()]


func get_source_name() -> String:
	return str(source_node.name) if is_instance_valid(source_node) else source_name


func get_mesh_label() -> String:
	if not mesh_snapshot:
		return "generated mesh" if is_csg else "mesh"
	if not mesh_snapshot.resource_name.is_empty():
		return mesh_snapshot.resource_name
	return "generated CSG mesh" if is_csg else "mesh"


func get_transform() -> Transform3D:
	return source_transform


func refresh_source_transform() -> bool:
	if not is_instance_valid(source_node):
		source_transform = Transform3D.IDENTITY
		return false
	source_transform = _get_source_scene_transform()
	return true


func get_material_for_slot(slot: int) -> Material:
	if not is_instance_valid(source_node):
		return null
	if is_csg:
		return source_node.call("get_material") as Material if source_node.has_method("get_material") else null
	var mesh_instance := source_node as MeshInstance3D
	if slot < 0:
		return mesh_instance.material_override
	if not mesh_instance.mesh or slot >= mesh_instance.mesh.get_surface_count():
		return null
	return mesh_instance.get_active_material(slot)


func discover_material_slots() -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	if not mesh_snapshot:
		return choices
	if is_csg:
		var configuration_error := _get_csg_configuration_error()
		var candidate := get_material_for_slot(0)
		choices.push_back(_make_choice(0, "CSG Material", candidate, configuration_error, candidate == null))
		return choices
	var mesh_instance := source_node as MeshInstance3D
	var surface_count := mesh_snapshot.get_surface_count()
	if surface_count == 0:
		choices.push_back(_make_choice(-1, "Material Override", mesh_instance.material_override, "", false))
		return choices
	for slot in range(surface_count):
		var slot_name := "Material %d" % slot
		var surface_name: String = mesh_snapshot.surface_get_name(slot)
		if not surface_name.is_empty():
			slot_name += " (%s)" % surface_name
		choices.push_back(_make_choice(slot, slot_name, mesh_instance.get_active_material(slot), "", false))
	return choices


func select_material(slot: int) -> Dictionary:
	material_slot = slot
	var geometry_result := validate_geometry(slot)
	if geometry_result.get(STATUS, STATUS_ERROR) != STATUS_OK:
		return geometry_result
	var candidate := get_material_for_slot(slot)
	if candidate is StandardMaterial3D:
		material = candidate
		return _result(STATUS_OK, "")
	if candidate:
		return _result(STATUS_ERROR, "GDDraw supports StandardMaterial3D albedo textures for 3D painting.")
	if is_csg:
		material = null
		return _result(STATUS_OK, "")
	return _result(STATUS_ERROR, "This mesh slot has no material. Assign a StandardMaterial3D in the Inspector first.")


func validate_geometry(slot := -2) -> Dictionary:
	if not mesh_snapshot or mesh_snapshot.get_surface_count() == 0:
		return _result(STATUS_ERROR, "%s has no generated triangle geometry with usable UV data." % get_source_label())
	var slots := PackedInt32Array()
	if is_csg:
		for surface_index in range(mesh_snapshot.get_surface_count()):
			slots.push_back(surface_index)
	elif slot >= 0:
		slots.push_back(slot)
	else:
		for surface_index in range(mesh_snapshot.get_surface_count()):
			slots.push_back(surface_index)
	preview_surface_slots = slots
	var usable_surfaces := 0
	for surface_index in slots:
		if surface_index < 0 or surface_index >= mesh_snapshot.get_surface_count():
			continue
		if mesh_snapshot.surface_get_primitive_type(surface_index) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arrays := mesh_snapshot.surface_get_arrays(surface_index)
		if arrays.size() <= Mesh.ARRAY_TEX_UV:
			continue
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		if vertices.size() < 3 or uvs.size() != vertices.size():
			continue
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array else PackedInt32Array()
		if not indices.is_empty() and (indices.size() < 3 or indices.size() % 3 != 0):
			continue
		usable_surfaces += 1
	if usable_surfaces == 0:
		return _result(
			STATUS_ERROR,
			"%s has no usable triangle UV data and cannot currently be texture-painted. GDDraw will not fabricate UV coordinates."
			% get_source_label()
		)
	return _result(STATUS_OK, "")


func assign_texture(editor_plugin: EditorPlugin, next_texture: Texture2D) -> bool:
	if not material or not next_texture or not is_instance_valid(source_node):
		return false
	if is_csg:
		var previous := get_material_for_slot(0)
		var replacement := material.duplicate(true) as StandardMaterial3D
		if not replacement:
			return false
		replacement.resource_name = "%s GDDraw Material" % source_node.name
		replacement.resource_local_to_scene = true
		replacement.albedo_texture = next_texture
		if not _assign_csg_material(editor_plugin, previous, replacement):
			return false
		material = replacement
		return true
	var mesh_instance := source_node as MeshInstance3D
	if mesh_instance.mesh and material_slot >= 0 and material_slot < mesh_instance.mesh.get_surface_count():
		var existing_override := mesh_instance.get_surface_override_material(material_slot)
		if existing_override is StandardMaterial3D:
			var override_material := existing_override as StandardMaterial3D
			if not _assign_material_texture(editor_plugin, override_material, next_texture):
				return false
			# Read back through the MeshInstance rather than trusting a cached
			# material reference from an imported or inherited scene.
			var assigned_override := mesh_instance.get_surface_override_material(material_slot) as StandardMaterial3D
			if assigned_override != override_material:
				mesh_instance.set_surface_override_material(material_slot, override_material)
				assigned_override = mesh_instance.get_surface_override_material(material_slot) as StandardMaterial3D
			material = assigned_override
			return material != null and material.albedo_texture == next_texture
		var active_material := mesh_instance.get_active_material(material_slot) as StandardMaterial3D
		if active_material:
			var override_material := active_material.duplicate(true) as StandardMaterial3D
			if not override_material:
				return false
			override_material.resource_name = "%s GDDraw Surface %d" % [mesh_instance.name, material_slot]
			override_material.resource_local_to_scene = true
			override_material.albedo_texture = next_texture
			if not _assign_mesh_surface_material(editor_plugin, existing_override, override_material):
				return false
			material = mesh_instance.get_surface_override_material(material_slot) as StandardMaterial3D
			return material != null and material.albedo_texture == next_texture
	return _assign_material_texture(editor_plugin, material, next_texture)


func assign_new_material_and_texture(editor_plugin: EditorPlugin, next_texture: Texture2D) -> bool:
	if not is_csg or not next_texture or not is_instance_valid(source_node):
		return false
	var previous := get_material_for_slot(0)
	var replacement := StandardMaterial3D.new()
	replacement.resource_name = "%s GDDraw Material" % source_node.name
	replacement.resource_local_to_scene = true
	replacement.albedo_texture = next_texture
	if not _assign_csg_material(editor_plugin, previous, replacement):
		return false
	material = replacement
	return true


func _capture(node: Node3D) -> Dictionary:
	source_node = node
	mesh_snapshot = null
	material = null
	preview_surface_slots = PackedInt32Array()
	if not is_instance_valid(source_node):
		return _result(STATUS_ERROR, "Select or drop an editable MeshInstance3D or CSG shape.")
	source_name = str(source_node.name)
	source_class_name = source_node.get_class()
	is_csg = source_node is CSGShape3D
	# The preview lives in an isolated World3D, so it needs the complete scene
	# transform rather than the node-local transform. This preserves authored
	# orientation, parent transforms, non-uniform scale, and mirrored scale
	# without touching the source hierarchy.
	source_transform = _get_source_scene_transform()
	if source_node is MeshInstance3D:
		mesh_snapshot = (source_node as MeshInstance3D).mesh
	elif is_csg:
		if not source_node.has_method("get_material") or not source_node.has_method("set_material"):
			return _result(
				STATUS_ERROR,
				"%s is a CSG combiner or unsupported CSG configuration. Select a material-bearing CSG primitive descendant instead."
				% get_source_label()
			)
		mesh_snapshot = (source_node as CSGShape3D).bake_static_mesh()
	if not mesh_snapshot:
		return _result(STATUS_ERROR, "%s has no readable generated mesh snapshot." % get_source_label())
	geometry_signature = _make_geometry_signature(mesh_snapshot)
	return validate_geometry()


func _get_source_scene_transform() -> Transform3D:
	if not is_instance_valid(source_node):
		return Transform3D.IDENTITY
	# Detached nodes have no inherited transform. Falling back to their local
	# transform keeps discovery/tests safe without weakening scene behavior.
	return source_node.global_transform if source_node.is_inside_tree() else source_node.transform


func _get_csg_configuration_error() -> String:
	var material_ids := {}
	for surface_index in range(mesh_snapshot.get_surface_count()):
		var surface_material := mesh_snapshot.surface_get_material(surface_index)
		var key := 0 if surface_material == null else surface_material.get_instance_id()
		material_ids[key] = true
	if material_ids.size() > 1:
		return (
			"This CSG result contains multiple generated materials. GDDraw will not choose one arbitrarily; "
			+ "select a single-material CSG primitive or simplify the CSG material configuration."
		)
	return ""


func _make_choice(slot: int, slot_name: String, candidate: Material, configuration_error: String, allow_material_creation: bool) -> Dictionary:
	if not configuration_error.is_empty():
		return _choice(slot, "%s · Multi-material CSG (unsupported)" % slot_name, false, configuration_error, true, false, "")
	if not candidate:
		if allow_material_creation:
			return _choice(
				slot,
				"%s · No material or texture" % slot_name,
				true,
				"Choose Open, then explicitly confirm creation of a StandardMaterial3D and new PNG albedo texture.",
				true,
				true,
				""
			)
		return _choice(
			slot,
			"%s · No material" % slot_name,
			false,
			"Assign a StandardMaterial3D in the Inspector before editing.",
			true,
			false,
			""
		)
	if not candidate is StandardMaterial3D:
		return _choice(
			slot,
			"%s · %s (unsupported)" % [slot_name, candidate.get_class()],
			false,
			"Only StandardMaterial3D albedo textures are currently safe to edit.",
			true,
			false,
			""
		)
	var standard := candidate as StandardMaterial3D
	var path := get_editable_texture_path(standard.albedo_texture)
	var missing := standard.albedo_texture == null
	var recoverable := not missing and path.is_empty() and _texture_has_readable_image(standard.albedo_texture)
	var supported := missing or not path.is_empty() or recoverable
	var texture_label := "Albedo · Missing texture" if missing else "Albedo · %s" % (path.get_file() if not path.is_empty() else "non-file texture")
	var reason := ""
	if missing:
		reason = "Choose Open, then explicitly confirm creation of a new PNG texture."
	elif not path.is_empty():
		reason = "Ready to edit."
	elif recoverable:
		reason = "Open this readable in-memory texture, then use Save As to create a PNG."
	else:
		reason = "The albedo texture must be readable or backed by a res:// PNG, JPG, JPEG, or WebP file."
	return _choice(slot, "%s · %s" % [slot_name, texture_label], supported, reason, missing, false, path)


func _choice(slot: int, label: String, supported: bool, reason: String, missing_texture: bool, missing_material: bool, texture_path: String) -> Dictionary:
	return {
		"slot": slot,
		"label": label,
		"channel": "albedo",
		"supported": supported,
		"reason": reason,
		"missing_texture": missing_texture,
		"missing_material": missing_material,
		"texture_path": texture_path,
	}


func _assign_csg_material(editor_plugin: EditorPlugin, previous: Material, next: Material) -> bool:
	var undo_redo := editor_plugin.get_undo_redo() if editor_plugin else null
	if undo_redo:
		undo_redo.create_action("Assign GDDraw CSG Material")
		undo_redo.add_do_method(source_node, "set_material", next)
		undo_redo.add_undo_method(source_node, "set_material", previous)
		undo_redo.commit_action()
	else:
		source_node.call("set_material", next)
	# Imported/instanced scene nodes do not always receive an editor undo action
	# synchronously. Apply the same value directly when commit_action() has not
	# done so yet; the recorded undo/redo action still owns later undo and redo.
	if source_node.call("get_material") != next:
		source_node.call("set_material", next)
	return source_node.call("get_material") == next


func _assign_mesh_surface_material(editor_plugin: EditorPlugin, previous: Material, next: Material) -> bool:
	var mesh_instance := source_node as MeshInstance3D
	var undo_redo := editor_plugin.get_undo_redo() if editor_plugin else null
	if undo_redo:
		undo_redo.create_action("Assign GDDraw 3D Material")
		undo_redo.add_do_method(mesh_instance, "set_surface_override_material", material_slot, next)
		undo_redo.add_undo_method(mesh_instance, "set_surface_override_material", material_slot, previous)
		undo_redo.commit_action()
	else:
		mesh_instance.set_surface_override_material(material_slot, next)
	if mesh_instance.get_surface_override_material(material_slot) != next:
		mesh_instance.set_surface_override_material(material_slot, next)
	return mesh_instance.get_surface_override_material(material_slot) == next


func _assign_material_texture(editor_plugin: EditorPlugin, target_material: StandardMaterial3D, next_texture: Texture2D) -> bool:
	var previous_texture := target_material.albedo_texture
	var undo_redo := editor_plugin.get_undo_redo() if editor_plugin else null
	if undo_redo:
		undo_redo.create_action("Assign GDDraw Albedo Texture")
		undo_redo.add_do_property(target_material, "albedo_texture", next_texture)
		undo_redo.add_undo_property(target_material, "albedo_texture", previous_texture)
		undo_redo.commit_action()
	else:
		target_material.albedo_texture = next_texture
	if target_material.albedo_texture != next_texture:
		target_material.albedo_texture = next_texture
	return target_material.albedo_texture == next_texture


func _texture_has_readable_image(source_texture: Texture2D) -> bool:
	if not source_texture:
		return false
	var image := source_texture.get_image()
	if not image or image.is_empty():
		return false
	if image.is_compressed() and image.decompress() != OK:
		return false
	return true


func get_editable_texture_path(source_texture: Texture2D) -> String:
	if not source_texture:
		return ""
	var path := source_texture.resource_path.strip_edges()
	if path.is_empty() and source_texture.has_meta("gddraw_source_path"):
		path = str(source_texture.get_meta("gddraw_source_path", "")).strip_edges()
	if path.ends_with(".import"):
		path = path.trim_suffix(".import")
	if path.begins_with("res://") and path.get_extension().to_lower() in ["png", "jpg", "jpeg", "webp"]:
		return path
	return ""


func _make_geometry_signature(mesh: Mesh) -> String:
	var parts := PackedStringArray([
		str(mesh.get_surface_count()),
	])
	for surface_index in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface_index)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] if arrays.size() > Mesh.ARRAY_VERTEX else PackedVector3Array()
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays.size() > Mesh.ARRAY_TEX_UV else PackedVector2Array()
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays.size() > Mesh.ARRAY_INDEX and arrays[Mesh.ARRAY_INDEX] is PackedInt32Array else PackedInt32Array()
		parts.push_back("%d:%d:%d:%s:%s" % [
			vertices.size(),
			uvs.size(),
			indices.size(),
			str(hash(vertices)),
			"%s:%s" % [hash(uvs), hash(indices)],
		])
	return "|".join(parts)


func _result(status: String, message: String) -> Dictionary:
	return {STATUS: status, MESSAGE: message}
