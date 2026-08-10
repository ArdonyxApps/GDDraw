@tool
class_name GDDrawSpriteCreatorHelper
extends RefCounted

const SUCCESS := "success"
const MESSAGE := "message"


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


func create_csg_box(plugin: EditorPlugin, image: Image, texture_dir: String) -> Dictionary:
	if not plugin:
		return _make_result(false, "Plugin is not ready yet.")
	if not image or image.is_empty():
		return _make_result(false, "Draw or load visible pixels before creating a CSGBox3D.")

	var root := plugin.get_editor_interface().get_edited_scene_root()
	if not root:
		return _make_result(false, "Open a scene before creating a CSGBox3D.")

	var normalized_dir := texture_dir.strip_edges()
	if normalized_dir.is_empty() or not normalized_dir.begins_with("res://"):
		return _make_result(false, "Default save location must be inside res://.")
	var dir_error: int = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(normalized_dir))
	if dir_error != OK:
		return _make_result(false, "Could not create texture folder. Error: " + str(dir_error))

	var texture_image := image.duplicate()
	if texture_image.has_mipmaps():
		texture_image.clear_mipmaps()
	if texture_image.get_format() != Image.FORMAT_RGBA8:
		texture_image.convert(Image.FORMAT_RGBA8)
	var texture_path := _make_unique_texture_path(normalized_dir, "csg_box")
	var save_error: int = texture_image.save_png(texture_path)
	if save_error != OK:
		return _make_result(false, "Could not create CSGBox3D texture. Error: " + str(save_error))

	var texture := _make_path_backed_texture(plugin, texture_image, texture_path)
	var material := StandardMaterial3D.new()
	material.resource_name = "GDDraw CSGBox3D Material"
	material.resource_local_to_scene = true
	material.albedo_color = Color.WHITE
	material.albedo_texture = texture
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	# CSGBox3D's generated outward-facing UVs read a conventional 2D image
	# backwards on the reference face. Mirror U around the texture center so
	# the outside of the box, rather than the inside, matches the canvas.
	material.uv1_scale = Vector3(-1.0, 1.0, 1.0)
	material.uv1_offset = Vector3(1.0, 0.0, 0.0)

	var box := CSGBox3D.new()
	box.name = "GDDrawCSGBox3D"
	box.set_material(material)

	var undo_redo := plugin.get_undo_redo()
	undo_redo.create_action("Create GDDraw CSGBox3D")
	undo_redo.add_do_method(root, "add_child", box)
	undo_redo.add_do_method(box, "set_owner", root)
	undo_redo.add_do_reference(box)
	undo_redo.add_undo_method(root, "remove_child", box)
	undo_redo.commit_action()
	return _make_result(true, "Created CSGBox3D with " + texture_path.get_file() + ".")


func _make_path_backed_texture(plugin: EditorPlugin, image: Image, path: String) -> Texture2D:
	var resource_filesystem := plugin.get_editor_interface().get_resource_filesystem()
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


func _make_result(success: bool, message: String) -> Dictionary:
	return {
		SUCCESS: success,
		MESSAGE: message,
	}
