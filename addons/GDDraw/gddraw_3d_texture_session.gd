@tool
class_name GDDraw3DTextureSessionResource
extends RefCounted

const STATUS := "status"
const MESSAGE := "message"
const IMAGE := "image"
const LABEL := "label"
const UV_EDGES := "uv_edges"
const UV_VERTICES := "uv_vertices"
const CHOICES := "choices"
const MESH_LABEL := "mesh_label"

const STATUS_OK := "ok"
const STATUS_NEEDS_CREATE := "needs_create"
const STATUS_ERROR := "error"
const CHANNEL_ALBEDO := "albedo"
const DEFAULT_TEXTURE_SIZE := Vector2i(1024, 1024)
const UV_OVERLAY_SCRIPT_PATH := "res://addons/GDDraw/gddraw_uv_overlay.gd"
const SURFACE_TARGET_SCRIPT_PATH := "res://addons/GDDraw/gddraw_3d_surface_target.gd"
const StoragePaths := preload("res://addons/GDDraw/gddraw_storage_paths.gd")

var target
var source_node: Node3D
var mesh_snapshot: Mesh
# Kept as a compatibility alias for existing MeshInstance3D integrations/tests.
var mesh_instance: MeshInstance3D
var material: StandardMaterial3D
var material_slot := 0
var texture_path := ""
var texture: Texture2D
var base_image: Image
var baseline_image: Image
var uv_edges: Array = []
var uv_vertices := PackedVector2Array()
var preview_orientation_adjustment := Transform3D.IDENTITY
var preview_translation_adjustment := Vector3.ZERO
var session_start_source_transform := Transform3D.IDENTITY
var live_source_transform := Transform3D.IDENTITY
var imported_source_transform := Transform3D.IDENTITY
var scene_transform_linked := false
var _preview_transform_state_initialized := false

var _uv_overlay


func discover_mesh(mesh: MeshInstance3D) -> Dictionary:
	return discover_target(mesh)


func discover_target(node: Node) -> Dictionary:
	var candidate = _make_target()
	if not candidate:
		return _result(STATUS_ERROR, "Could not load the editable 3D surface target helper.")
	var inspection: Dictionary = candidate.inspect(node)
	if inspection.get(STATUS, STATUS_ERROR) != STATUS_OK:
		return inspection
	return {
		STATUS: STATUS_OK,
		MESSAGE: "Choose an editable texture for %s." % candidate.get_source_label(),
		MESH_LABEL: candidate.get_source_label(),
		CHOICES: candidate.discover_material_slots(),
	}


func begin_from_mesh(mesh: MeshInstance3D, editor_plugin: EditorPlugin, create_if_missing := false, create_dir := StoragePaths.DEFAULT_IMAGE_DIR, texture_size := DEFAULT_TEXTURE_SIZE, material_slot_index := 0) -> Dictionary:
	return begin_from_target(mesh, editor_plugin, create_if_missing, create_dir, texture_size, material_slot_index)


func begin_from_target(node: Node, editor_plugin: EditorPlugin, create_if_missing := false, create_dir := StoragePaths.DEFAULT_IMAGE_DIR, texture_size := DEFAULT_TEXTURE_SIZE, material_slot_index := 0) -> Dictionary:
	_ensure_uv_overlay()
	clear()
	target = _make_target()
	if not target:
		return _result(STATUS_ERROR, "Could not load the editable 3D surface target helper.")
	var inspection: Dictionary = target.inspect(node)
	if inspection.get(STATUS, STATUS_ERROR) != STATUS_OK:
		clear()
		return inspection
	source_node = target.source_node
	mesh_instance = source_node as MeshInstance3D
	mesh_snapshot = target.mesh_snapshot
	material_slot = material_slot_index
	var selection: Dictionary = target.select_material(material_slot)
	if selection.get(STATUS, STATUS_ERROR) != STATUS_OK:
		clear()
		return selection
	material = target.material
	_capture_preview_transform_state()
	texture = material.albedo_texture if material else null
	texture_path = _get_editable_texture_path(texture)
	if texture_path.is_empty() and material and material.has_meta("gddraw_texture_path"):
		var remembered_path := str(material.get_meta("gddraw_texture_path", "")).strip_edges()
		if remembered_path.begins_with("res://"):
			texture_path = remembered_path
	_refresh_uv_data()

	if not texture and not create_if_missing:
		return {
			STATUS: STATUS_NEEDS_CREATE,
			MESSAGE: (
				"%s has no material. Create a StandardMaterial3D and PNG albedo texture?"
				if not material
				else "%s has no albedo texture. Create one?"
			) % source_node.name,
			UV_EDGES: uv_edges,
			UV_VERTICES: uv_vertices,
			"missing_material": material == null,
		}

	if not texture:
		var create_result := _create_and_assign_albedo_texture(editor_plugin, create_dir, texture_size)
		if create_result.get(STATUS, STATUS_ERROR) != STATUS_OK:
			clear()
			return create_result

	var image := _load_active_texture_image()
	if not image or image.is_empty():
		clear()
		return _result(STATUS_ERROR, "Could not load a readable albedo texture image.")
	base_image = image.duplicate()
	baseline_image = image.duplicate()
	return {
		STATUS: STATUS_OK,
		MESSAGE: "Editing %s albedo texture." % source_node.name,
		IMAGE: image,
		LABEL: texture_path if not texture_path.is_empty() else "3D albedo texture",
		UV_EDGES: uv_edges,
		UV_VERTICES: uv_vertices,
	}


func save_image(image: Image, _editor_plugin: EditorPlugin) -> Dictionary:
	if not has_active_session():
		return _result(STATUS_ERROR, "No active 3D texture session.")
	if texture_path.is_empty() and material:
		texture_path = _get_editable_texture_path(material.albedo_texture)
		if texture_path.is_empty() and material.has_meta("gddraw_texture_path"):
			texture_path = str(material.get_meta("gddraw_texture_path", "")).strip_edges()
	if texture_path.is_empty():
		return _result(STATUS_ERROR, "The active material texture has no editable resource path.")
	var write_result := _write_image(image, texture_path)
	if write_result.get(STATUS, STATUS_ERROR) != STATUS_OK:
		return write_result
	var editable_image: Image = write_result.get(IMAGE)
	# Normal Save keeps the existing material/texture identity. Save As is the
	# only operation that needs to create and assign a different texture.
	if texture is ImageTexture:
		(texture as ImageTexture).update(editable_image)
	baseline_image = editable_image.duplicate()
	return _result(STATUS_OK, "Saved " + texture_path)


func save_image_as(image: Image, path: String, editor_plugin: EditorPlugin) -> Dictionary:
	# Compatibility convenience for callers that are not executing inside a
	# FileDialog signal. The dock uses write_image_as() and
	# assign_saved_image_as() as separate ordered stages.
	var write_result := write_image_as(image, path)
	if write_result.get(STATUS, STATUS_ERROR) != STATUS_OK:
		return write_result
	var editable_image: Image = write_result.get(IMAGE)
	var updated_texture := _make_path_backed_texture(editable_image, path, editor_plugin)
	return assign_saved_image_as(editable_image, path, updated_texture, editor_plugin)


func write_image_as(image: Image, path: String) -> Dictionary:
	if not has_active_session():
		return _result(STATUS_ERROR, "No active 3D texture session.")
	if not image or image.is_empty():
		return _result(STATUS_ERROR, "Canvas image is empty.")
	if path.is_empty() or not path.begins_with("res://"):
		return _result(STATUS_ERROR, "Choose a texture path inside res://.")
	if path.get_extension().to_lower() != "png":
		return _result(STATUS_ERROR, "3D texture Save As currently writes PNG files.")
	var dir_error := _ensure_resource_dir(path.get_base_dir())
	if dir_error != OK:
		return _result(STATUS_ERROR, "Could not create texture folder. Error: " + str(dir_error))
	return _write_image(image, path)


func assign_saved_image_as(image: Image, path: String, next_texture: Texture2D, editor_plugin: EditorPlugin) -> Dictionary:
	if not has_active_session():
		return _result(STATUS_ERROR, "No active 3D texture session.")
	if not image or image.is_empty() or not next_texture:
		return _result(STATUS_ERROR, "The saved PNG could not be prepared as a texture.")
	var editable_image := _make_editable_image(image)
	var assigned := _assign_active_texture(editor_plugin, next_texture)
	if not assigned:
		return {
			STATUS: STATUS_ERROR,
			MESSAGE: "Saved %s, but Godot could not update the active material reference." % path,
			"file_saved": true,
			"assignment_failed": true,
		}
	if target:
		material = target.material
	texture_path = path
	texture = next_texture
	baseline_image = editable_image.duplicate()
	if material:
		material.set_meta("gddraw_texture_path", path)
	return _result(STATUS_OK, "Saved as " + texture_path)


func has_active_session() -> bool:
	# The private session owns a retained mesh snapshot, material, texture, and
	# editable image. Scene-tab switches can temporarily detach the source node,
	# and closing its scene can free it permanently; neither event invalidates
	# the independent painting session.
	return material != null and mesh_snapshot != null


func is_dirty(image: Image) -> bool:
	if not has_active_session() or not baseline_image:
		return false
	var editable_image := _make_editable_image(image)
	return editable_image == null or not _images_equal_rgba8(editable_image, baseline_image)


func get_identity_text() -> String:
	if not has_active_session():
		return ""
	var texture_name := texture_path.get_file() if not texture_path.is_empty() else "albedo texture"
	var material_name := material.resource_name if not material.resource_name.is_empty() else "slot %d" % material_slot
	var source_label: String = target.get_source_label() if target else str(mesh_instance.name)
	return "Editing %s · %s · %s" % [source_label, material_name, texture_name]


func rotate_preview_orientation(axis: Vector3, angle_radians: float) -> void:
	if axis.length_squared() <= 0.000001 or is_zero_approx(angle_radians):
		return
	var rotation := Transform3D(Basis(axis.normalized(), angle_radians), Vector3.ZERO)
	var adjustment: Transform3D = (
		preview_orientation_adjustment
		if preview_orientation_adjustment is Transform3D
		else Transform3D.IDENTITY
	)
	preview_orientation_adjustment = adjustment * rotation


func set_preview_orientation(adjustment: Transform3D) -> void:
	# Preview orientation is intentionally plain session state. Interactive gizmo
	# updates must never participate in image or editor undo history.
	preview_orientation_adjustment = Transform3D(adjustment.basis.orthonormalized(), Vector3.ZERO)


func get_preview_orientation() -> Transform3D:
	return (
		preview_orientation_adjustment
		if preview_orientation_adjustment is Transform3D
		else Transform3D.IDENTITY
	)


func reset_preview_orientation() -> void:
	preview_orientation_adjustment = Transform3D.IDENTITY


func set_preview_translation(adjustment: Vector3) -> void:
	preview_translation_adjustment = adjustment


func get_preview_translation() -> Vector3:
	return preview_translation_adjustment


func get_preview_adjustment() -> Transform3D:
	return Transform3D(get_preview_orientation().basis, preview_translation_adjustment)


func set_preview_adjustment(adjustment: Transform3D) -> void:
	set_preview_orientation(adjustment)
	set_preview_translation(adjustment.origin)


func ensure_preview_transform_state() -> void:
	if not _preview_transform_state_initialized:
		_capture_preview_transform_state()


func _capture_preview_transform_state() -> void:
	var source_transform: Transform3D = target.get_transform() if target else Transform3D.IDENTITY
	session_start_source_transform = source_transform
	live_source_transform = source_transform
	imported_source_transform = source_transform
	preview_orientation_adjustment = Transform3D.IDENTITY
	preview_translation_adjustment = Vector3.ZERO
	scene_transform_linked = false
	_preview_transform_state_initialized = true


func update_live_source_transform(source_transform: Transform3D) -> bool:
	ensure_preview_transform_state()
	live_source_transform = source_transform
	if not scene_transform_linked or imported_source_transform.is_equal_approx(source_transform):
		return false
	imported_source_transform = source_transform
	return true


func set_scene_transform_linked(linked: bool, source_transform := Transform3D.IDENTITY) -> bool:
	ensure_preview_transform_state()
	scene_transform_linked = linked
	if not linked:
		return false
	live_source_transform = source_transform
	var changed := (
		not imported_source_transform.is_equal_approx(source_transform)
		or not get_preview_adjustment().is_equal_approx(Transform3D.IDENTITY)
	)
	imported_source_transform = source_transform
	# Re-linking is an explicit request to mirror the live scene exactly. Any
	# private edits remain isolated, but are discarded for this new link epoch.
	preview_orientation_adjustment = Transform3D.IDENTITY
	preview_translation_adjustment = Vector3.ZERO
	return changed


func is_scene_transform_linked() -> bool:
	return scene_transform_linked


func reset_preview_transform() -> void:
	ensure_preview_transform_state()
	scene_transform_linked = false
	imported_source_transform = session_start_source_transform
	preview_orientation_adjustment = Transform3D.IDENTITY
	preview_translation_adjustment = Vector3.ZERO


func get_preview_transform() -> Transform3D:
	ensure_preview_transform_state()
	return imported_source_transform * get_preview_adjustment()


func refresh_geometry() -> Dictionary:
	if not target:
		return _result(STATUS_ERROR, "No active editable 3D surface target.")
	var result: Dictionary = target.refresh_geometry()
	if result.get(STATUS, STATUS_ERROR) != STATUS_OK:
		return result
	mesh_snapshot = target.mesh_snapshot
	material = target.material
	if bool(result.get("changed", false)):
		_refresh_uv_data()
	return result


func clear() -> void:
	target = null
	source_node = null
	mesh_snapshot = null
	mesh_instance = null
	material = null
	material_slot = 0
	texture_path = ""
	texture = null
	base_image = null
	baseline_image = null
	uv_edges.clear()
	uv_vertices = PackedVector2Array()
	preview_orientation_adjustment = Transform3D.IDENTITY
	preview_translation_adjustment = Vector3.ZERO
	session_start_source_transform = Transform3D.IDENTITY
	live_source_transform = Transform3D.IDENTITY
	imported_source_transform = Transform3D.IDENTITY
	scene_transform_linked = false
	_preview_transform_state_initialized = false


func _create_and_assign_albedo_texture(editor_plugin: EditorPlugin, create_dir: String, texture_size: Vector2i) -> Dictionary:
	texture_size = Vector2i(maxi(16, texture_size.x), maxi(16, texture_size.y))
	var dir_error := _ensure_resource_dir(create_dir)
	if dir_error != OK:
		return _result(STATUS_ERROR, "Could not create texture folder. Error: " + str(dir_error))
	texture_path = _make_unique_texture_path(create_dir, source_node.name)
	var image := Image.create_empty(texture_size.x, texture_size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var save_error := image.save_png(texture_path)
	if save_error != OK:
		texture_path = ""
		return _result(STATUS_ERROR, "Could not create albedo texture. Error: " + str(save_error))
	var new_texture := _make_path_backed_texture(image, texture_path, editor_plugin)
	var assigned: bool = target.assign_new_material_and_texture(editor_plugin, new_texture) if not material else target.assign_texture(editor_plugin, new_texture)
	if not assigned:
		var written_path := texture_path
		texture_path = ""
		return {
			STATUS: STATUS_ERROR,
			MESSAGE: "Created %s, but could not safely assign the new material or texture; no session was started." % written_path,
			"file_saved": true,
			"assignment_failed": true,
		}
	material = target.material
	texture = new_texture
	_scan_filesystem(editor_plugin)
	return _result(STATUS_OK, "Created " + texture_path)


func _refresh_uv_data() -> void:
	if not _uv_overlay:
		_ensure_uv_overlay()
	var slots: PackedInt32Array = target.preview_surface_slots if target else PackedInt32Array()
	var uv_data: Dictionary = _uv_overlay.extract_from_mesh(mesh_snapshot, slots)
	uv_edges = uv_data.get("edges", [])
	uv_vertices = uv_data.get("vertices", PackedVector2Array())


func _ensure_uv_overlay() -> void:
	if _uv_overlay:
		return
	var script = load(UV_OVERLAY_SCRIPT_PATH)
	if script and script.has_method("new"):
		_uv_overlay = script.call("new")


func _make_target():
	var script = load(SURFACE_TARGET_SCRIPT_PATH)
	return script.call("new") if script and script.has_method("new") else null


func _assign_active_texture(editor_plugin: EditorPlugin, next_texture: Texture2D) -> bool:
	if target:
		if not is_instance_valid(target.source_node):
			# A closed source scene has no live scene property to participate in
			# editor undo/redo. Keep Save As useful by updating only the retained
			# private-session material; reopening the old scene is intentionally
			# treated as a new source until the user chooses it again.
			material.albedo_texture = next_texture
			target.material = material
			return material.albedo_texture == next_texture
		var previous_material := material
		var assigned: bool = target.assign_texture(editor_plugin, next_texture)
		var active_material := target.get_material_for_slot(material_slot) as StandardMaterial3D
		if assigned and active_material and active_material.albedo_texture == next_texture:
			material = active_material
			target.material = active_material
			return true
		# Assignment failure must not turn a valid session into a partially
		# inactive one. Recover the material currently authoritative on the
		# source surface, falling back to the pre-assignment session material.
		material = active_material if active_material else previous_material
		target.material = material
		return false
	if not material:
		return false
	var previous_texture := material.albedo_texture
	var undo_redo := editor_plugin.get_undo_redo() if editor_plugin else null
	if undo_redo:
		undo_redo.create_action("Assign GDDraw Albedo Texture")
		undo_redo.add_do_property(material, "albedo_texture", next_texture)
		undo_redo.add_undo_property(material, "albedo_texture", previous_texture)
		undo_redo.commit_action()
	else:
		material.albedo_texture = next_texture
	if material.albedo_texture != next_texture:
		material.albedo_texture = next_texture
	return material.albedo_texture == next_texture


func _load_active_texture_image() -> Image:
	if texture:
		var texture_image := _make_editable_image(texture.get_image())
		if texture_image:
			return texture_image
	return _load_image_file(texture_path)


func _load_image_file(path: String) -> Image:
	if path.is_empty() or not FileAccess.file_exists(path):
		return null
	if ResourceLoader.exists(path, "Texture2D"):
		var loaded := ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_REPLACE)
		if loaded is Texture2D:
			var loaded_image := _make_editable_image((loaded as Texture2D).get_image())
			if loaded_image:
				return loaded_image
	var image := Image.new()
	return _make_editable_image(image) if image.load(path) == OK else null


func _make_editable_image(source_image: Image) -> Image:
	if not source_image or source_image.is_empty():
		return null
	var image := source_image.duplicate()
	if image.is_compressed() and image.decompress() != OK:
		return null
	if image.has_mipmaps():
		image.clear_mipmaps()
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	return image


func _images_equal_rgba8(left: Image, right: Image) -> bool:
	if not left or not right or left.get_size() != right.get_size():
		return false
	var left_rgba := _make_editable_image(left)
	var right_rgba := _make_editable_image(right)
	return left_rgba != null and right_rgba != null and left_rgba.get_data() == right_rgba.get_data()


func _make_path_backed_texture(image: Image, path: String, _editor_plugin: EditorPlugin) -> Texture2D:
	var image_texture := ImageTexture.create_from_image(image)
	# Never start an editor import from the Save As callback. The dock schedules
	# that work after the dialog/message-queue transaction has fully completed.
	# Until then, keep the exact saved pixels and their persistent source path.
	image_texture.set_meta("gddraw_source_path", path)
	return image_texture


func _get_editable_texture_path(source_texture: Texture2D) -> String:
	if not source_texture:
		return ""
	if target:
		return target.get_editable_texture_path(source_texture)
	var path := source_texture.resource_path.strip_edges()
	if path.is_empty() and source_texture.has_meta("gddraw_source_path"):
		path = str(source_texture.get_meta("gddraw_source_path", "")).strip_edges()
	if path.ends_with(".import"):
		path = path.trim_suffix(".import")
	return path if path.begins_with("res://") and path.get_extension().to_lower() in ["png", "jpg", "jpeg", "webp"] else ""


func _save_image_to_texture_path(image: Image, path: String) -> int:
	match path.get_extension().to_lower():
		"png":
			return image.save_png(path)
		"jpg", "jpeg":
			return image.save_jpg(path)
		"webp":
			return image.save_webp(path)
	return ERR_UNAVAILABLE


func _write_image(image: Image, path: String) -> Dictionary:
	if not image or image.is_empty():
		return _result(STATUS_ERROR, "Canvas image is empty.")
	if not StoragePaths.is_writable_project_path(path):
		return _result(STATUS_ERROR, "Texture writes must stay outside the GDDraw plugin package.")
	var editable_image := _make_editable_image(image)
	if not editable_image:
		return _result(STATUS_ERROR, "Canvas image could not be converted to editable RGBA8 pixels.")
	var error := _save_image_to_texture_path(editable_image, path)
	if error != OK:
		return _result(STATUS_ERROR, "Could not save texture. Error: " + str(error))
	return {
		STATUS: STATUS_OK,
		MESSAGE: "Wrote " + path,
		IMAGE: editable_image,
		"path": path,
		"file_saved": true,
	}


func _scan_filesystem(editor_plugin: EditorPlugin) -> void:
	if editor_plugin:
		editor_plugin.get_editor_interface().get_resource_filesystem().scan()


func _ensure_resource_dir(path: String) -> int:
	if not StoragePaths.is_writable_project_path(path):
		return ERR_INVALID_PARAMETER
	return DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(StoragePaths.normalize_path(path)))


func _make_unique_texture_path(dir_path: String, source_name: String) -> String:
	var safe_name := source_name.to_snake_case()
	if safe_name.is_empty():
		safe_name = "surface"
	for index in range(1, 1000):
		var suffix := "" if index == 1 else "_%03d" % index
		var candidate := "%s/%s_albedo%s.png" % [dir_path.trim_suffix("/"), safe_name, suffix]
		if not FileAccess.file_exists(candidate):
			return candidate
	return "%s/%s_albedo_%d.png" % [dir_path.trim_suffix("/"), safe_name, Time.get_unix_time_from_system()]


func _result(status: String, message: String) -> Dictionary:
	return {STATUS: status, MESSAGE: message}
