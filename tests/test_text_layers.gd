extends SceneTree
const Dock := preload("res://addons/GDDraw/gddraw_dock.gd")
const Canvas := preload("res://addons/GDDraw/gddraw_canvas.gd")
const Document := preload("res://addons/GDDraw/gddraw_layer_document.gd")
const Session := preload("res://addons/GDDraw/gddraw_layer_session.gd")
class PreferenceSettings:
	extends RefCounted
	var values := {}
	func get_project_metadata(section: String, key: String, fallback: Variant = null) -> Variant:
		return values.get(section + "/" + key, fallback)
	func set_project_metadata(section: String, key: String, value: Variant) -> void:
		values[section + "/" + key] = value
class PreferenceDock:
	extends "res://addons/GDDraw/gddraw_dock.gd"
	var settings: Object
	func _get_editor_settings() -> Object: return settings
var assertions := 0
var failures := 0
func _initialize(): _run.call_deferred()
func check(value: bool, message: String):
	assertions += 1
	if not value:
		failures += 1
		push_error(message)
func settle():
	for i in range(5): await process_frame
func click_pixel(canvas: Control, pixel: Vector2i):
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = canvas._image_pixels_to_local_rect(Rect2i(pixel, Vector2i.ONE)).get_center()
	event.pressed = true
	canvas._gui_input(event)
	event.pressed = false
	canvas._gui_input(event)
func _run():
	var settings := PreferenceSettings.new()
	var preference_dock := PreferenceDock.new()
	preference_dock.settings = settings
	check(preference_dock._get_text_default_new_layer(), "Text output defaults to editable layer")
	preference_dock._on_text_default_output_selected(1)
	var restored_preferences := PreferenceDock.new()
	restored_preferences.settings = settings
	check(not restored_preferences._get_text_default_new_layer(), "Text preference persists across dock recreation")
	settings.values["GDDraw/text_default_new_layer"] = "invalid"
	check(restored_preferences._get_text_default_new_layer(), "invalid Text preference falls back to new layer")
	preference_dock.free()
	restored_preferences.free()
	var dock := Dock.new()
	root.add_child(dock)
	dock.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await settle()
	dock._layer_session.initialize_2d(Vector2i(128, 96))
	dock._sync_canvas_to_active_layer()
	dock._select_tool(Canvas.ToolMode.TEXT)
	var canvas = dock._canvas
	var target = dock._layer_session.get_active_target()
	var base_id: String = target.selected_layer_id
	var base_pixels: PackedByteArray = target.get_selected_layer().image.get_data()
	var tools_tab := dock._settings_panel.find_child("Tools", true, false)
	check(tools_tab.is_ancestor_of(dock._text_output_mode) and not dock._text_options.is_ancestor_of(dock._text_output_mode), "Text output lives in Tools preferences")
	dock._on_text_default_output_selected(1)
	check(not canvas.text_layer_mode, "paint preference enables raster text on paint layer")
	canvas.create_text_draft(Rect2i(8,8,100,64), "Raster")
	dock._on_text_default_output_selected(0)
	check(not canvas.text_layer_mode, "preference change preserves active draft destination")
	canvas.commit_text_draft()
	check(target.selected_layer_id == base_id and target.get_paint_layer_count() == 1 and not target.get_selected_layer().image.is_invisible(), "raster output paints existing layer")
	check(canvas.text_layer_mode, "changed preference applies after draft finishes")
	dock._undo()
	target = dock._layer_session.get_active_target()
	check(target.get_selected_layer().image.is_invisible(), "raster text remains undoable")
	canvas.brush_color = Color(0.2, 0.5, 0.9, 0.7)
	canvas.text_font_size = 18
	canvas.text_alignment = Canvas.TextAlignment.CENTER
	canvas.create_text_draft(Rect2i(8, 10, 100, 64), "Editable\ntext")
	canvas.rotate_text_draft_degrees(10)
	check(canvas.commit_text_draft(), "commit succeeds")
	var id: String = target.selected_layer_id
	var node = target.get_selected_layer()
	check(id != base_id and node.is_text_layer(), "commit creates a separate Text layer")
	check(target.find_node(base_id).image.get_data() == base_pixels, "base pixels remain unchanged")
	check(node.text_recipe.text == "Editable\ntext" and node.text_recipe.alignment == Canvas.TextAlignment.CENTER, "text and alignment are retained")
	check(not canvas.has_text_draft(), "commit finishes editor without reopening")
	check(not canvas.editing_enabled and canvas.text_editing_enabled, "paint blocked while text remains editable")
	dock._on_text_default_output_selected(1)
	check(canvas.text_layer_mode and not dock._text_default_new_layer, "existing Text layer stays editable without overwriting preference")
	dock._on_text_default_output_selected(0)
	check(not node.image.is_invisible(), "Text layer has cached rendered pixels")
	var original_recipe: Dictionary = node.text_recipe.duplicate(true)
	check(not str(original_recipe.font_data).is_empty(), "font bytes captured for portable editing")
	var original_pixels: PackedByteArray = node.image.get_data()
	var ink_pixel := Vector2i.ZERO
	for y in range(node.image.get_height()):
		for x in range(node.image.get_width()):
			if node.image.get_pixel(x, y).a > 0:
				ink_pixel = Vector2i(x, y)
				break
		if ink_pixel != Vector2i.ZERO: break
	await settle()
	click_pixel(canvas, ink_pixel)
	check(canvas.has_text_draft() and canvas._text_layer_editing and canvas._text_editor.text == original_recipe.text, "clicking letters reopens saved text")
	check(target.selected_layer_id == id and target.get_paint_layer_count() == 2, "reopening does not create another layer")
	canvas.cancel_text_draft()
	# An empty point inside the rotated text box should work as well.
	var box_center := Vector2(58, 42)
	var empty_pixel := Vector2i((Vector2(10, 12) - box_center).rotated(float(original_recipe.rotation)) + box_center)
	click_pixel(canvas, empty_pixel)
	check(canvas.has_text_draft() and canvas._text_layer_editing, "empty space in rotated text box reopens handles")
	canvas.cancel_text_draft()
	dock._select_tool(Canvas.ToolMode.BRUSH)
	click_pixel(canvas, ink_pixel)
	check(canvas.active_tool == Canvas.ToolMode.BRUSH and not canvas.has_text_draft() and target.get_paint_layer_count() == 3, "explicit Brush paints on a new layer when clicking text")
	dock._undo()
	target = dock._layer_session.get_active_target()
	node = target.find_node(id)
	dock._select_tool(Canvas.ToolMode.TEXT)
	canvas.cancel_text_draft()
	click_pixel(canvas, Vector2i(125, 90))
	check(canvas.has_text_draft() and not canvas._text_layer_editing, "clicking outside saved text starts a fresh box")
	canvas.cancel_text_draft()
	dock._select_tool(Canvas.ToolMode.TEXT)
	check(canvas.has_text_draft() and canvas._text_layer_editing, "selecting text resumes existing layer")
	check(canvas._text_editor.text == original_recipe.text and canvas.text_font_size == 18, "saved toolbar and content restore")
	canvas._text_editor.text = "Canceled"
	canvas._on_text_editor_text_changed()
	canvas.cancel_text_draft()
	check(node.text_recipe == original_recipe and node.image.get_data() == original_pixels, "cancel preserves saved recipe and pixels")
	dock._select_tool(Canvas.ToolMode.TEXT)
	canvas._text_editor.text = "Updated"
	canvas._on_text_editor_text_changed()
	canvas.commit_text_draft()
	check(target.selected_layer_id == id and target.get_paint_layer_count() == 2 and node.text_recipe.text == "Updated", "edit replaces selected Text layer")
	dock._undo()
	target = dock._layer_session.get_active_target()
	check(target.find_node(id).text_recipe.text == original_recipe.text, "undo restores text recipe")
	dock._redo()
	target = dock._layer_session.get_active_target()
	check(target.find_node(id).text_recipe.text == "Updated", "redo restores text edit")
	canvas.cancel_text_draft()
	dock._select_tool(Canvas.ToolMode.TEXT)
	canvas._text_editor.text = "Tool switch"
	canvas._on_text_editor_text_changed()
	dock._select_tool(Canvas.ToolMode.BRUSH)
	check(not canvas.has_text_draft() and target.find_node(id).text_recipe.text == "Tool switch", "tool switch finishes text")
	check(not canvas.editing_enabled, "switching tools does not allow painting on Text")
	var path := "user://text_layer_roundtrip.gddraw"
	check(Document.save_session(dock._layer_session, path).ok, "save Text layer")
	var restored := Session.new()
	check(Document.load_into_session(path, restored).ok, "load Text layer")
	var restored_node = restored.get_active_target().find_node(id)
	check(restored_node.is_text_layer() and preload("res://addons/GDDraw/gddraw_text_recipe.gd").equivalent(restored_node.text_recipe, target.find_node(id).text_recipe), "recipe including font bytes round trips")
	check(restored_node.image.get_data() == target.find_node(id).image.get_data(), "cached text pixels round trip")
	canvas.load_text_layer(restored_node.text_recipe, restored_node.origin)
	var reopened: Dictionary = canvas._get_text_layer_payload()
	check(reopened.image.get_data() == restored_node.image.get_data(), "embedded font reproduces saved pixels")
	canvas.cancel_text_draft()
	var bad_recipe: Dictionary = restored_node.text_recipe.duplicate(true)
	bad_recipe.box[2] = -1
	check(not target.update_text_layer(id, bad_recipe, restored_node.image, restored_node.origin), "invalid recipe is rejected")
	var duplicate_id: String = target.duplicate_node(id)
	check(target.find_node(duplicate_id).is_text_layer() and target.find_node(duplicate_id).text_recipe == target.find_node(id).text_recipe, "duplication retains editable text")
	target.set_node_locked(id, true)
	check(not target.rasterize_text_layer(id), "locked text cannot rasterize")
	target.set_node_locked(id, false)
	target.select_layer(id)
	dock._sync_canvas_to_active_layer()
	canvas.cancel_text_draft()
	var context := {"kind": "paint", "target_id": target.target_id, "node_id": id}
	dock._rasterize_text_layer(context)
	check(not target.find_node(id).is_text_layer() and target.find_node(id).text_recipe.is_empty(), "rasterize clears recipe")
	dock._undo()
	target = dock._layer_session.get_active_target()
	check(target.find_node(id).is_text_layer(), "undo rasterize restores editable Text")
	canvas.cancel_text_draft()
	dock._select_tool(Canvas.ToolMode.TEXT)
	canvas.commit_text_draft()
	canvas.create_text_draft(Rect2i(12, 55, 100, 30), "Another")
	canvas.commit_text_draft()
	check(target.selected_layer_id != id and target.get_selected_layer().is_text_layer(), "new box on a Text layer creates a new sibling")
	# A background-filled box gives deterministic mask and opacity samples.
	canvas._has_selection = true
	canvas._selection_rect = Rect2i(24, 24, 16, 16)
	canvas._selection_mask = null
	canvas.text_fill_mode = Canvas.TextFillMode.BACKGROUND
	canvas.background_color = Color.RED
	canvas.brush_color = Color.RED
	canvas.create_text_draft(Rect2i(16, 16, 64, 48), "Mask")
	canvas.commit_text_draft()
	var masked = target.get_selected_layer()
	check(masked.text_mask != null and masked.image.get_pixel(25,25) == Color.RED and masked.image.get_pixel(20,20).a == 0, "new Text respects selection mask")
	canvas._has_selection = false
	canvas._selection_mask = null
	target.set_node_opacity(masked.id, 0.5)
	dock._sync_canvas_to_active_layer()
	check(canvas._text_layer_mask != null, "editing restores original selection mask")
	canvas._text_editor.text = "Changed mask"
	canvas._on_text_editor_text_changed()
	canvas.commit_text_draft()
	check(masked.image.get_pixel(25,25) == Color.RED and masked.image.get_pixel(20,20).a == 0, "mask survives text edits after selection cleared")
	check(Document.save_session(dock._layer_session, path).ok and Document.load_into_session(path, restored).ok, "masked Text round trip")
	check(restored.get_active_target().get_selected_layer().text_mask.get_data() == masked.text_mask.get_data(), "saved selection mask matches")
	target.set_node_locked(masked.id, true)
	dock._sync_canvas_to_active_layer()
	check(not canvas.has_text_draft() and not canvas.text_editing_enabled, "locked Text does not open editor")
	target.set_node_locked(masked.id, false)
	dock._sync_canvas_to_active_layer()
	canvas.cancel_text_draft()
	var scaled := Session.new()
	check(scaled.restore_state(dock._layer_session.capture_state()), "copy session for resize")
	check(scaled.get_active_target().scale_layers(Vector2i(256,192), Image.INTERPOLATE_NEAREST), "scale document containing Text")
	var scaled_node = scaled.get_active_target().get_selected_layer()
	check(scaled_node.is_text_layer() and scaled_node.text_recipe.font_size == masked.text_recipe.font_size * 2 and scaled_node.text_mask.get_size() == Vector2i(256,192), "scale retains Text recipe and mask dimensions")
	var scaled_raster := preload("res://addons/GDDraw/gddraw_text_recipe.gd").render(scaled_node.text_recipe, scaled_node.image.get_size(), scaled_node.text_mask)
	check(scaled_raster.get_data() == scaled_node.image.get_data(), "scaled text cache matches reopened layout")
	check(scaled.get_active_target().crop_layers(Rect2i(8, 8, 128, 96)) and scaled_node.is_text_layer(), "crop retains editable Text")
	if "--screenshot" in OS.get_cmdline_user_args():
		dock._panel_host.activate_panel("layers")
		dock._select_tool(Canvas.ToolMode.TEXT)
		await settle()
		root.get_texture().get_image().save_png("res://text_layers_review.png")
	dock.queue_free()
	await settle()
	await texture_checks()
	print("Text layers: %d assertions, %d failures" % [assertions, failures])
	quit(1 if failures else 0)

func texture_checks():
	var source := MeshInstance3D.new()
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(Image.create_empty(32, 32, false, Image.FORMAT_RGBA8))
	mesh.surface_set_material(0, material)
	source.mesh = mesh
	root.add_child(source)
	var dock := Dock.new()
	root.add_child(dock)
	await settle()
	var discovery := preload("res://addons/GDDraw/gddraw_3d_layer_discovery.gd").new()
	dock._begin_3d_layer_session(discovery.discover([source], discovery.Scope.SELECTED_HIERARCHY), false, false)
	dock._on_view_mode_selected(2)
	await settle()
	dock._select_tool(Canvas.ToolMode.TEXT)
	var canvas = dock._canvas
	var target = dock._layer_session.get_active_target()
	var base_id: String = target.selected_layer_id
	var before: bool = dock._texture_3d_layer_coordinator.is_dirty()
	canvas.text_fill_mode = Canvas.TextFillMode.BACKGROUND
	canvas.background_color = Color.RED
	canvas.brush_color = Color.RED
	canvas.create_text_draft(Rect2i(0, 0, 32, 32), "T")
	if DisplayServer.get_name() != "headless":
		dock._on_text_fill_toggled(false)
		check(canvas._text_layer_texture.get_image().get_pixel(31,31).a == 0, "fill off immediately refreshes new text preview")
		dock._on_text_fill_toggled(true)
		check(canvas._text_layer_texture.get_image().get_pixel(31,31) == Color.RED, "fill on immediately refreshes new text preview")
		canvas.background_color = Color.BLUE
		check(canvas._text_layer_texture.get_image().get_pixel(31,31) == Color.BLUE, "background color immediately refreshes filled text preview")
		canvas.background_color = Color.RED
	check(dock._texture_3d_layer_coordinator.is_dirty() == before, "text draft leaves 3D texture unchanged")
	canvas.commit_text_draft()
	await settle()
	check(target.get_selected_layer().is_text_layer() and dock._texture_3d_layer_coordinator.is_dirty(), "Text commit dirties 3D session")
	check(target.find_node(base_id).image.is_invisible(), "Text leaves 3D base intact")
	check(canvas.get_document_display_image_copy().get_pixel(0,0) == Color.RED, "Text updates texture composite")
	if DisplayServer.get_name() != "headless":
		check(dock._paint_3d_texture.get_image().get_pixel(0,0) == Color.RED, "Text updates rendered 3D texture")
	target.set_node_opacity(target.selected_layer_id, 0.5)
	dock._sync_canvas_to_active_layer()
	if DisplayServer.get_name() != "headless":
		check(absf(canvas._text_layer_texture.get_image().get_pixel(0,0).a - 0.5) < 0.01, "editing preview uses layer opacity")
		dock._on_text_fill_toggled(false)
		check(canvas._text_layer_texture.get_image().get_pixel(31,31).a == 0, "fill toggle refreshes reopened text without stale saved background")
		check(target.get_selected_layer().image.get_pixel(31,31) == Color.RED, "live fill preview does not commit saved layer")
		dock._on_text_fill_toggled(true)
	canvas.background_color = Color.BLUE
	canvas.brush_color = Color.BLUE
	canvas.cancel_text_draft()
	check(target.get_selected_layer().image.get_pixel(0,0) == Color.RED, "cancel restores saved texture pixels")
	dock.queue_free()
	source.queue_free()
	await settle()
