@tool
class_name GDDrawSpriteCreatorHelper
extends RefCounted

const StoragePaths := preload("res://addons/GDDraw/gddraw_storage_paths.gd")

enum CSGShape {
	BOX,
	SPHERE,
	CYLINDER,
}

const SUCCESS := "success"
const MESSAGE := "message"
const NODE := "node"
const MATERIAL := "material"
const TEXTURE := "texture"
const TEXTURE_PATH := "texture_path"

const OPTION_SHAPE := "shape"
const OPTION_ASSIGN_CURRENT_IMAGE := "assign_current_image"
const OPTION_SELECT_CREATED_NODE := "select_created_node"
const OPTION_ENABLE_COLLISION := "enable_collision"

const _SHAPE_CONFIGS := {
	CSGShape.BOX: {
		"label": "Box",
		"class_name": "CSGBox3D",
		"node_name": "GDDrawCSGBox3D",
		"file_stem": "csg_box",
		"uv_scale": Vector3(-1.0, 1.0, 1.0),
		"uv_offset": Vector3(1.0, 0.0, 0.0),
	},
	CSGShape.SPHERE: {
		"label": "Sphere",
		"class_name": "CSGSphere3D",
		"node_name": "GDDrawCSGSphere3D",
		"file_stem": "csg_sphere",
		"uv_scale": Vector3.ONE,
		"uv_offset": Vector3.ZERO,
	},
	CSGShape.CYLINDER: {
		"label": "Cylinder",
		"class_name": "CSGCylinder3D",
		"node_name": "GDDrawCSGCylinder3D",
		"file_stem": "csg_cylinder",
		"uv_scale": Vector3(-1.0, 1.0, 1.0),
		"uv_offset": Vector3(1.0, 0.0, 0.0),
	},
}


func create_sprite(plugin: EditorPlugin, image: Image) -> Dictionary:
	if not plugin:
		return _make_result(false, "Plugin is not ready yet.")

	var root := plugin.get_editor_interface().get_edited_scene_root()
	if not root:
		return _make_result(false, "Open a scene before creating a Sprite2D.")

	var texture := ImageTexture.create_from_image(image)
	var sprite := Sprite2D.new()
	sprite.name = "GDDrawSprite"
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var undo_redo := plugin.get_undo_redo()
	undo_redo.create_action("Create GDDraw Sprite2D")
	undo_redo.add_do_method(root, "add_child", sprite)
	undo_redo.add_do_method(sprite, "set_owner", root)
	undo_redo.add_do_reference(sprite)
	undo_redo.add_undo_method(root, "remove_child", sprite)
	undo_redo.commit_action()
	return _make_result(true, "Created Sprite2D in the current scene.")


func create_textured_csg(plugin: EditorPlugin, image: Image, texture_dir: String, options := {}) -> Dictionary:
	var validation := validate_csg_creation(plugin, image, texture_dir, options)
	if not validation.get(SUCCESS, false):
		return validation

	var editor_interface := plugin.get_editor_interface()
	return _create_csg_for_context(
		plugin,
		editor_interface.get_edited_scene_root(),
		plugin.get_undo_redo(),
		editor_interface.get_selection(),
		image,
		texture_dir,
		_normalize_csg_options(options)
	)


# Compatibility entry point retained for callers from the original box-only workflow.
func create_csg_box(plugin: EditorPlugin, image: Image, texture_dir: String) -> Dictionary:
	return create_textured_csg(plugin, image, texture_dir, {
		OPTION_SHAPE: CSGShape.BOX,
		OPTION_ASSIGN_CURRENT_IMAGE: true,
		OPTION_SELECT_CREATED_NODE: false,
		OPTION_ENABLE_COLLISION: false,
	})


func validate_csg_creation(plugin: EditorPlugin, image: Image, texture_dir: String, options := {}) -> Dictionary:
	if not plugin:
		return _make_result(false, "Plugin is not ready yet.")
	var editor_interface := plugin.get_editor_interface()
	if not editor_interface or not editor_interface.get_edited_scene_root():
		return _make_result(false, "Open a scene before creating a textured CSG3D node.")
	return _validate_csg_context(image, texture_dir, _normalize_csg_options(options))


# Kept separate from EditorPlugin lookup so the transactional construction path can
# be covered with deterministic test doubles for undo/redo and editor selection.
func _create_csg_for_context(
	plugin: EditorPlugin,
	root: Node,
	undo_redo: Object,
	editor_selection: Object,
	image: Image,
	texture_dir: String,
	options := {}
) -> Dictionary:
	var normalized_options := _normalize_csg_options(options)
	if not root:
		return _make_result(false, "Open a scene before creating a textured CSG3D node.")
	if not undo_redo:
		return _make_result(false, "Editor undo/redo is not available.")
	var validation := _validate_csg_context(image, texture_dir, normalized_options)
	if not validation.get(SUCCESS, false):
		return validation

	var shape: int = normalized_options[OPTION_SHAPE]
	var config: Dictionary = _SHAPE_CONFIGS[shape]
	var assign_image: bool = normalized_options[OPTION_ASSIGN_CURRENT_IMAGE]
	var texture: Texture2D
	var material: StandardMaterial3D
	var texture_path := ""

	if assign_image:
		var normalized_dir := StoragePaths.normalize_path(texture_dir)
		var absolute_dir := ProjectSettings.globalize_path(normalized_dir)
		var dir_error: int = DirAccess.make_dir_recursive_absolute(absolute_dir)
		if dir_error != OK:
			return _make_result(false, "Could not create texture folder. Error: " + str(dir_error))
		if not DirAccess.dir_exists_absolute(absolute_dir):
			return _make_result(false, "The configured texture folder is not available.")

		var texture_image := image.duplicate()
		if texture_image.has_mipmaps():
			texture_image.clear_mipmaps()
		if texture_image.get_format() != Image.FORMAT_RGBA8:
			texture_image.convert(Image.FORMAT_RGBA8)
		texture_path = _make_unique_texture_path(normalized_dir, str(config["file_stem"]))
		var save_error: int = texture_image.save_png(texture_path)
		if save_error != OK:
			# The path was chosen only after confirming it did not already exist,
			# so a partial file here can only belong to this failed transaction.
			if FileAccess.file_exists(texture_path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(texture_path))
			return _make_result(
				false,
				"Could not save the %s texture PNG. Error: %s" % [config["label"], save_error]
			)

		texture = _make_path_backed_texture(plugin, texture_image, texture_path)
		material = StandardMaterial3D.new()
		material.resource_name = "GDDraw %s Material" % config["class_name"]
		material.resource_local_to_scene = true
		material.albedo_color = Color.WHITE
		material.albedo_texture = texture
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		# Godot's generated primitives do not share one orientation convention.
		# Sphere UVs are authored top-to-bottom and CCW for images; Box and
		# Cylinder reference exteriors need U mirrored around the texture center.
		material.uv1_scale = config["uv_scale"]
		material.uv1_offset = config["uv_offset"]

	var csg := _make_csg_node(shape)
	if not csg:
		return _make_result(false, "The requested CSG shape is not supported.")
	csg.name = _make_unique_node_name(root, str(config["node_name"]))
	csg.use_collision = normalized_options[OPTION_ENABLE_COLLISION]
	if material:
		csg.set_material(material)

	var select_created: bool = normalized_options[OPTION_SELECT_CREATED_NODE] and editor_selection != null
	undo_redo.create_action("Create GDDraw %s" % config["class_name"])
	undo_redo.add_do_method(root, "add_child", csg)
	undo_redo.add_do_method(csg, "set_owner", root)
	if select_created:
		undo_redo.add_do_method(editor_selection, "clear")
		undo_redo.add_do_method(editor_selection, "add_node", csg)
	undo_redo.add_do_reference(csg)
	# Undo operations execute in registration order. Remove selection first so
	# the editor never retains a reference to a node that is no longer in scene.
	if select_created:
		undo_redo.add_undo_method(editor_selection, "remove_node", csg)
	undo_redo.add_undo_method(root, "remove_child", csg)
	undo_redo.commit_action()

	var message := "Created %s." % config["class_name"]
	if assign_image:
		message = "Created %s with %s." % [config["class_name"], texture_path.get_file()]
	var result := _make_result(true, message)
	result[NODE] = csg
	result[MATERIAL] = material
	result[TEXTURE] = texture
	result[TEXTURE_PATH] = texture_path
	return result


func _validate_csg_context(image: Image, texture_dir: String, options: Dictionary) -> Dictionary:
	var shape: int = options[OPTION_SHAPE]
	if not _SHAPE_CONFIGS.has(shape):
		return _make_result(false, "Choose Box, Sphere, or Cylinder.")
	if not options[OPTION_ASSIGN_CURRENT_IMAGE]:
		return _make_result(true, "Ready to create %s without a texture." % _SHAPE_CONFIGS[shape]["class_name"])
	if not _image_has_visible_pixels(image):
		return _make_result(false, "Draw or load visible pixels, or disable Assign Current Image.")
	var normalized_dir := StoragePaths.normalize_path(texture_dir)
	if not StoragePaths.is_writable_project_path(normalized_dir):
		return _make_result(false, "The configured save location must be inside res:// and outside res://addons/GDDraw.")
	return _make_result(true, "Ready to create textured %s." % _SHAPE_CONFIGS[shape]["class_name"])


func _normalize_csg_options(options: Dictionary) -> Dictionary:
	return {
		OPTION_SHAPE: int(options.get(OPTION_SHAPE, CSGShape.BOX)),
		OPTION_ASSIGN_CURRENT_IMAGE: bool(options.get(OPTION_ASSIGN_CURRENT_IMAGE, true)),
		OPTION_SELECT_CREATED_NODE: bool(options.get(OPTION_SELECT_CREATED_NODE, true)),
		OPTION_ENABLE_COLLISION: bool(options.get(OPTION_ENABLE_COLLISION, false)),
	}


func _make_csg_node(shape: int) -> CSGShape3D:
	match shape:
		CSGShape.BOX:
			return CSGBox3D.new()
		CSGShape.SPHERE:
			return CSGSphere3D.new()
		CSGShape.CYLINDER:
			return CSGCylinder3D.new()
	return null


func _image_has_visible_pixels(image: Image) -> bool:
	if not image or image.is_empty():
		return false
	var rgba := image.duplicate()
	if rgba.get_format() != Image.FORMAT_RGBA8:
		rgba.convert(Image.FORMAT_RGBA8)
	return rgba.get_used_rect().has_area()


func _make_path_backed_texture(plugin: EditorPlugin, image: Image, path: String) -> Texture2D:
	if plugin:
		var resource_filesystem := plugin.get_editor_interface().get_resource_filesystem()
		if resource_filesystem:
			resource_filesystem.update_file(path)
	if ResourceLoader.exists(path, "Texture2D"):
		var imported := ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_REPLACE)
		if imported is Texture2D:
			return imported
	var image_texture := ImageTexture.create_from_image(image)
	image_texture.take_over_path(path)
	return image_texture


func _make_unique_texture_path(dir_path: String, source_name: String) -> String:
	var safe_name := source_name.to_snake_case()
	if safe_name.is_empty():
		safe_name = "texture"
	for index in range(1, 1000):
		var suffix := "" if index == 1 else "_%03d" % index
		var candidate := "%s/%s_albedo%s.png" % [dir_path.trim_suffix("/"), safe_name, suffix]
		if not FileAccess.file_exists(candidate):
			return candidate
	return "%s/%s_albedo_%d.png" % [dir_path.trim_suffix("/"), safe_name, Time.get_unix_time_from_system()]


func _make_unique_node_name(root: Node, base_name: String) -> String:
	if not root.get_node_or_null(NodePath(base_name)):
		return base_name
	for index in range(2, 1000):
		var candidate := "%s%d" % [base_name, index]
		if not root.get_node_or_null(NodePath(candidate)):
			return candidate
	return "%s%d" % [base_name, Time.get_unix_time_from_system()]


func _make_result(success: bool, message: String) -> Dictionary:
	return {
		SUCCESS: success,
		MESSAGE: message,
	}
