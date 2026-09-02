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
var source_mesh: Mesh
var mesh_snapshot: Mesh
var source_skeleton: Skeleton3D
var skeleton_pose_baked := false
var source_transform := Transform3D.IDENTITY
var is_csg := false
var material_slot := 0
var material: StandardMaterial3D
var geometry_signature := ""
var preview_surface_slots := PackedInt32Array()
var _skeleton_pose_dirty := false


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
		"skeleton_pose_baked": skeleton_pose_baked,
	}


func has_source_mesh_changed() -> bool:
	return (
		not is_csg
		and is_instance_valid(source_node)
		and source_node is MeshInstance3D
		and (source_node as MeshInstance3D).mesh != source_mesh
	)


func has_pending_skeleton_pose_refresh() -> bool:
	return is_instance_valid(source_skeleton) and _skeleton_pose_dirty


func is_skeleton_pose_baked() -> bool:
	return skeleton_pose_baked


func release() -> void:
	_bind_source_skeleton(null)


func get_source_label() -> String:
	if not is_instance_valid(source_node):
		return "%s (%s)" % [source_name, source_class_name]
	return "%s (%s)" % [source_node.name, source_node.get_class()]


func get_source_name() -> String:
	return str(source_node.name) if is_instance_valid(source_node) else source_name


func get_mesh_label() -> String:
	var label_mesh := source_mesh if source_mesh else mesh_snapshot
	if not label_mesh:
		return "generated mesh" if is_csg else "mesh"
	if not label_mesh.resource_name.is_empty():
		return label_mesh.resource_name
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
	var surface_count := source_mesh.get_surface_count() if source_mesh else mesh_snapshot.get_surface_count()
	if surface_count == 0:
		choices.push_back(_make_choice(-1, "Material Override", mesh_instance.material_override, "", false))
		return choices
	for slot in range(surface_count):
		var slot_name := "Material %d" % slot
		var surface_name: String = source_mesh.surface_get_name(slot) if source_mesh else mesh_snapshot.surface_get_name(slot)
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
	source_mesh = null
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
		var mesh_instance := source_node as MeshInstance3D
		source_mesh = mesh_instance.mesh
		_bind_source_skeleton(_resolve_source_skeleton(mesh_instance))
		mesh_snapshot = _make_mesh_snapshot(mesh_instance)
	elif is_csg:
		_bind_source_skeleton(null)
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


func _resolve_source_skeleton(mesh_instance: MeshInstance3D) -> Skeleton3D:
	if not mesh_instance or mesh_instance.skeleton.is_empty():
		return null
	return mesh_instance.get_node_or_null(mesh_instance.skeleton) as Skeleton3D


func _bind_source_skeleton(next_skeleton: Skeleton3D) -> void:
	if source_skeleton == next_skeleton:
		return
	if is_instance_valid(source_skeleton) and source_skeleton.skeleton_updated.is_connected(_on_source_skeleton_updated):
		source_skeleton.skeleton_updated.disconnect(_on_source_skeleton_updated)
	source_skeleton = next_skeleton
	# Imported skins may not receive a valid RenderingServer skeleton RID until
	# the scene has advanced once. Keep the initial pose pending so the dock's
	# geometry poll retries instead of retaining bind-space vertices forever.
	_skeleton_pose_dirty = is_instance_valid(source_skeleton)
	if is_instance_valid(source_skeleton) and not source_skeleton.skeleton_updated.is_connected(_on_source_skeleton_updated):
		source_skeleton.skeleton_updated.connect(_on_source_skeleton_updated)


func _on_source_skeleton_updated() -> void:
	_skeleton_pose_dirty = true


func _make_mesh_snapshot(mesh_instance: MeshInstance3D) -> Mesh:
	skeleton_pose_baked = false
	if not source_mesh:
		_skeleton_pose_dirty = false
		return null
	if not _has_skeleton_pose_data(mesh_instance):
		_skeleton_pose_dirty = false
		return source_mesh
	var baked: ArrayMesh
	if _can_use_native_skeleton_pose_bake(mesh_instance):
		baked = mesh_instance.bake_mesh_from_current_skeleton_pose()
	if not baked:
		baked = _bake_current_skeleton_pose_on_cpu(mesh_instance)
	if not baked or baked.get_surface_count() != source_mesh.get_surface_count():
		_skeleton_pose_dirty = is_instance_valid(source_skeleton)
		return source_mesh
	# Godot's native pose bake intentionally omits materials and may omit
	# imported surface names. GDDraw owns preview materials separately, but the
	# original names remain useful in the material picker.
	for surface_index in range(baked.get_surface_count()):
		baked.surface_set_name(surface_index, source_mesh.surface_get_name(surface_index))
	skeleton_pose_baked = true
	_skeleton_pose_dirty = false
	return baked


func _has_skeleton_pose_data(mesh_instance: MeshInstance3D) -> bool:
	if (
		not mesh_instance
		or not mesh_instance.is_inside_tree()
		or not source_mesh is ArrayMesh
		or not is_instance_valid(source_skeleton)
		or not source_skeleton.is_inside_tree()
	):
		return false
	if mesh_instance.skin:
		return true
	for surface_index in range(source_mesh.get_surface_count()):
		var arrays := source_mesh.surface_get_arrays(surface_index)
		if (
			arrays.size() > Mesh.ARRAY_WEIGHTS
			and arrays[Mesh.ARRAY_BONES] is PackedInt32Array
			and arrays[Mesh.ARRAY_WEIGHTS] is PackedFloat32Array
			and not (arrays[Mesh.ARRAY_BONES] as PackedInt32Array).is_empty()
		):
			return true
	return false


func _can_use_native_skeleton_pose_bake(mesh_instance: MeshInstance3D) -> bool:
	var skin_reference := mesh_instance.get_skin_reference()
	return skin_reference != null and skin_reference.get_skeleton().is_valid()


func _bake_current_skeleton_pose_on_cpu(mesh_instance: MeshInstance3D) -> ArrayMesh:
	var source_array_mesh := source_mesh as ArrayMesh
	if not source_array_mesh or not is_instance_valid(source_skeleton):
		return null
	var skin: Skin = mesh_instance.skin
	var skeleton_to_mesh := mesh_instance.global_transform.affine_inverse() * source_skeleton.global_transform
	var baked := ArrayMesh.new()
	for surface_index in range(source_array_mesh.get_surface_count()):
		var source_arrays := source_array_mesh.surface_get_arrays(surface_index)
		var baked_arrays := source_arrays.duplicate(true)
		var vertices: PackedVector3Array = source_arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = (
			source_arrays[Mesh.ARRAY_BONES]
			if source_arrays[Mesh.ARRAY_BONES] is PackedInt32Array
			else PackedInt32Array()
		)
		var weights: PackedFloat32Array = (
			source_arrays[Mesh.ARRAY_WEIGHTS]
			if source_arrays[Mesh.ARRAY_WEIGHTS] is PackedFloat32Array
			else PackedFloat32Array()
		)
		if not vertices.is_empty() and bones.size() == weights.size() and bones.size() % vertices.size() == 0:
			var influences_per_vertex := bones.size() / vertices.size()
			var normals: PackedVector3Array = (
				source_arrays[Mesh.ARRAY_NORMAL]
				if source_arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array
				else PackedVector3Array()
			)
			var tangents: PackedFloat32Array = (
				source_arrays[Mesh.ARRAY_TANGENT]
				if source_arrays[Mesh.ARRAY_TANGENT] is PackedFloat32Array
				else PackedFloat32Array()
			)
			var baked_vertices := PackedVector3Array()
			baked_vertices.resize(vertices.size())
			var baked_normals := PackedVector3Array()
			if normals.size() == vertices.size():
				baked_normals.resize(normals.size())
			var baked_tangents := PackedFloat32Array()
			if tangents.size() == vertices.size() * 4:
				baked_tangents.resize(tangents.size())
			var transform_cache: Dictionary = {}
			for vertex_index in range(vertices.size()):
				var posed_vertex := Vector3.ZERO
				var posed_normal := Vector3.ZERO
				var posed_tangent := Vector3.ZERO
				var total_weight := 0.0
				for influence_index in range(influences_per_vertex):
					var array_index := vertex_index * influences_per_vertex + influence_index
					var weight := weights[array_index]
					if is_zero_approx(weight):
						continue
					var bind_index := bones[array_index]
					var pose_transform: Transform3D = transform_cache.get(bind_index, Transform3D())
					if not transform_cache.has(bind_index):
						pose_transform = _get_skin_pose_transform(skin, bind_index, skeleton_to_mesh)
						transform_cache[bind_index] = pose_transform
					posed_vertex += (pose_transform * vertices[vertex_index]) * weight
					if not baked_normals.is_empty():
						posed_normal += (pose_transform.basis * normals[vertex_index]) * weight
					if not baked_tangents.is_empty():
						var tangent_offset := vertex_index * 4
						var tangent := Vector3(
							tangents[tangent_offset],
							tangents[tangent_offset + 1],
							tangents[tangent_offset + 2]
						)
						posed_tangent += (pose_transform.basis * tangent) * weight
					total_weight += weight
				if total_weight > 0.0:
					baked_vertices[vertex_index] = posed_vertex / total_weight
					if not baked_normals.is_empty():
						baked_normals[vertex_index] = (posed_normal / total_weight).normalized()
					if not baked_tangents.is_empty():
						var tangent_offset := vertex_index * 4
						var normalized_tangent := (posed_tangent / total_weight).normalized()
						baked_tangents[tangent_offset] = normalized_tangent.x
						baked_tangents[tangent_offset + 1] = normalized_tangent.y
						baked_tangents[tangent_offset + 2] = normalized_tangent.z
						baked_tangents[tangent_offset + 3] = tangents[tangent_offset + 3]
				else:
					baked_vertices[vertex_index] = vertices[vertex_index]
					if not baked_normals.is_empty():
						baked_normals[vertex_index] = normals[vertex_index]
					if not baked_tangents.is_empty():
						var tangent_offset := vertex_index * 4
						for component in range(4):
							baked_tangents[tangent_offset + component] = tangents[tangent_offset + component]
			baked_arrays[Mesh.ARRAY_VERTEX] = baked_vertices
			if not baked_normals.is_empty():
				baked_arrays[Mesh.ARRAY_NORMAL] = baked_normals
			if not baked_tangents.is_empty():
				baked_arrays[Mesh.ARRAY_TANGENT] = baked_tangents
			# The preview snapshot already contains the posed vertices and must not
			# be skinned a second time if it is reused by another MeshInstance3D.
			baked_arrays[Mesh.ARRAY_BONES] = null
			baked_arrays[Mesh.ARRAY_WEIGHTS] = null
		baked.add_surface_from_arrays(source_array_mesh.surface_get_primitive_type(surface_index), baked_arrays)
	return baked


func _get_skin_pose_transform(skin: Skin, bind_index: int, skeleton_to_mesh: Transform3D) -> Transform3D:
	var skeleton_bone := bind_index
	var bind_pose := Transform3D.IDENTITY
	if skin and bind_index >= 0 and bind_index < skin.get_bind_count():
		skeleton_bone = skin.get_bind_bone(bind_index)
		if skeleton_bone < 0:
			var bind_name := skin.get_bind_name(bind_index)
			if not bind_name.is_empty():
				skeleton_bone = source_skeleton.find_bone(bind_name)
		bind_pose = skin.get_bind_pose(bind_index)
	if skeleton_bone < 0 or skeleton_bone >= source_skeleton.get_bone_count():
		return Transform3D.IDENTITY
	return skeleton_to_mesh * source_skeleton.get_bone_global_pose(skeleton_bone) * bind_pose


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
