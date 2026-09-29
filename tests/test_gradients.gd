extends SceneTree
const Raster := preload("res://addons/GDDraw/gddraw_gradient.gd")
const Canvas := preload("res://addons/GDDraw/gddraw_canvas.gd")
const Dock := preload("res://addons/GDDraw/gddraw_dock.gd")
const Shortcuts := preload("res://addons/GDDraw/gddraw_shortcuts.gd")
const Discovery := preload("res://addons/GDDraw/gddraw_3d_layer_discovery.gd")
const LayerDocument := preload("res://addons/GDDraw/gddraw_layer_document.gd")
const LayerSession := preload("res://addons/GDDraw/gddraw_layer_session.gd")
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
	func _get_editor_settings() -> Object:
		return settings
var assertions := 0
var failures := 0
func _initialize(): _run.call_deferred()
func check(value: bool, message: String):
	assertions += 1
	if not value:
		failures += 1
		push_error(message)
func blank(w := 9, h := 5) -> Image:
	return Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
func options() -> Dictionary:
	return {"fg": Color.RED, "bg": Color.BLUE, "radial": false, "transparent": false, "reverse": false, "opacity": 1.0, "alpha_lock": false}
func near(a: Color, b: Color) -> bool:
	return absf(a.r-b.r) <= 0.012 and absf(a.g-b.g) <= 0.012 and absf(a.b-b.b) <= 0.012 and absf(a.a-b.a) <= 0.012
func settle():
	for i in range(5): await process_frame
func _run():
	var base := blank()
	var area := Rect2i(Vector2i.ZERO, base.get_size())
	var settings := options()
	var out := Raster.render(base, area, Vector2.ZERO, Vector2(8,0), settings)
	check(out.get_pixel(0,0) == Color.RED and out.get_pixel(8,0) == Color.BLUE, "linear endpoints")
	check(near(out.get_pixel(4,2), Color(0.5,0,0.5)), "linear midpoint")
	check(base.get_pixel(0,0).a == 0, "raster never changes base")
	for ends in [[Vector2(1,1),Vector2(7,3)], [Vector2(3,4),Vector2(3,0)], [Vector2(-3,0),Vector2(12,6)]]:
		out = Raster.render(base, area, ends[0], ends[1], settings)
		var delta: Vector2 = ends[1] - ends[0]
		for y in range(5):
			for x in range(9):
				var t := clampf((Vector2(x,y)-ends[0]).dot(delta)/delta.length_squared(), 0, 1)
				check(near(out.get_pixel(x,y), Color.RED.lerp(Color.BLUE,t)), "pixel-space linear projection %s" % Vector2i(x,y))
	settings.reverse = true
	out = Raster.render(base, area, Vector2.ZERO, Vector2(8,0), settings)
	check(out.get_pixel(0,0) == Color.BLUE and out.get_pixel(8,0) == Color.RED, "reverse swaps ends")
	settings.reverse = false
	settings.radial = true
	out = Raster.render(base, area, Vector2(4,2), Vector2(6,2), settings)
	check(out.get_pixel(4,2) == Color.RED and out.get_pixel(6,2) == Color.BLUE, "radial center and radius")
	check(near(out.get_pixel(5,2), out.get_pixel(4,3)), "radial remains circular on non-square canvas")
	check(out.get_pixel(0,0) == Color.BLUE, "radial extends final color")
	settings.radial = false
	settings.transparent = true
	out = Raster.render(base, area, Vector2.ZERO, Vector2(8,0), settings)
	check(near(out.get_pixel(4,0), Color(1,0,0,0.5)) and out.get_pixel(8,0).a == 0, "foreground fade preserves RGB and alpha")
	base.fill(Color.GREEN)
	out = Raster.render(base, area, Vector2.ZERO, Vector2(8,0), settings)
	check(out.get_pixel(8,0) == Color.GREEN and near(out.get_pixel(4,0), Color(0.5,0.5,0)), "transparent endpoint leaves base and blends over it")
	settings.opacity = 0
	check(Raster.render(base, area, Vector2.ZERO, Vector2(8,0), settings).get_data() == base.get_data(), "zero opacity no-op")
	settings.opacity = 0.5
	settings.alpha_lock = true
	base.fill(Color(0,1,0,0.25))
	base.set_pixel(0,0,Color.TRANSPARENT)
	out = Raster.render(base, area, Vector2.ZERO, Vector2(8,0), settings)
	check(out.get_pixel(0,0) == Color.TRANSPARENT, "alpha lock preserves empty pixels")
	check(out.get_pixel(2,0).a == base.get_pixel(2,0).a, "alpha lock preserves partial alpha")
	settings = options()
	base = blank()
	var mask := blank(3,2)
	mask.set_pixel(1,0,Color.WHITE)
	out = Raster.render(base, Rect2i(2,1,3,2), Vector2(2,1), Vector2(4,1), settings, mask, Vector2i(2,1))
	check(out.get_pixel(3,1).a == 1 and out.get_pixel(2,1).a == 0 and out.get_pixel(0,0).a == 0, "lasso mask and region clipping")
	check(Raster.render(base, area, Vector2.ONE, Vector2.ONE, settings).get_data() == base.get_data(), "zero length no-op")
	await stop_checks()
	preference_checks()
	await gradient_layer_checks()
	await automatic_workflow_checks()
	await canvas_checks()
	await dock_checks()
	await worker_checks()
	await texture_session_checks()
	var large := blank(2048,2048)
	var started := Time.get_ticks_msec()
	Raster.render(large, Rect2i(0,0,2048,2048), Vector2.ZERO, Vector2(2047,2047), options())
	print("Gradient 2048 raster ms: ", Time.get_ticks_msec()-started)
	started = Time.get_ticks_msec()
	Raster.render(large, Rect2i(0,0,2048,2048), Vector2.ZERO, Vector2(2047,2047), options(), null, Vector2i.ZERO, 512)
	print("Gradient 2048 preview ms: ", Time.get_ticks_msec()-started)
	var locked := options()
	locked.alpha_lock = true
	started = Time.get_ticks_msec()
	Raster.render(large, Rect2i(0,0,2048,2048), Vector2.ZERO, Vector2(2047,2047), locked, null, Vector2i.ZERO, 512)
	print("Gradient 2048 locked preview ms: ", Time.get_ticks_msec()-started)
	print("Gradients: %d assertions, %d failures" % [assertions, failures])
	quit(0 if failures == 0 else 1)
func edit_stop_alpha(panel: Control, text: String) -> void:
	var field: LineEdit = panel.rows[panel.canvas.gradient_selected_stop].alpha
	field.text = text
	field.text_submitted.emit(text)

func preference_checks():
	var settings := PreferenceSettings.new()
	var dock := PreferenceDock.new()
	dock.settings = settings
	check(dock._get_gradient_default_new_layer(), "gradient output defaults to new layer")
	check(not dock._get_gradient_always_show_panel(), "Gradient button is contextual by default")
	dock._on_gradient_always_show_panel_toggled(true)
	dock._on_gradient_default_output_selected(1)
	var restored := PreferenceDock.new()
	restored.settings = settings
	check(restored._get_gradient_always_show_panel(), "always-visible Gradient preference survives dock recreation")
	settings.values["GDDraw/gradient_always_show_panel"] = "invalid"
	check(not restored._get_gradient_always_show_panel(), "invalid visibility preference falls back to contextual")
	check(not restored._get_gradient_default_new_layer(), "gradient output preference survives dock recreation")
	restored._on_gradient_default_output_selected(0)
	check(dock._get_gradient_default_new_layer(), "new-layer output preference saves correctly")
	settings.values["GDDraw/gradient_default_new_layer"] = "invalid"
	check(dock._get_gradient_default_new_layer(), "invalid stored preference falls back to new layer")
	dock.free()
	restored.free()

func pointer_drag(canvas: Control, start: Vector2i, end: Vector2i) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = canvas._image_pixel_center_to_local(start)
	canvas._gui_input(event)
	var motion := InputEventMouseMotion.new()
	motion.position = canvas._image_pixel_center_to_local(end)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	canvas._gui_input(motion)
	event.position = motion.position
	event.pressed = false
	canvas._gui_input(event)

func automatic_workflow_checks():
	var dock := Dock.new()
	root.add_child(dock)
	dock.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await settle()
	dock._select_tool(Canvas.ToolMode.GRADIENT)
	var target = dock._layer_session.get_active_target()
	var count: int = target.get_paint_layer_count()
	var history: int = dock._history._undo_stack.size()
	pointer_drag(dock._canvas, Vector2i(10,10), Vector2i(90,10))
	var first: String = target.selected_layer_id
	check(target.get_paint_layer_count() == count + 1 and target.find_node(first).is_gradient_layer(), "mouse release automatically creates gradient layer")
	check(dock._history._undo_stack.size() == history + 1 and dock._canvas._gradient_base != null, "automatic creation is one undo step and keeps handles")
	var first_recipe: Dictionary = target.find_node(first).gradient_recipe.duplicate(true)
	pointer_drag(dock._canvas, Vector2i(10,60), Vector2i(90,60))
	var second: String = target.selected_layer_id
	check(first != second and target.get_paint_layer_count() == count + 2, "drag away from handles creates another layer without changing tools or selection first")
	check(target.find_node(first).gradient_recipe == first_recipe, "new drag preserves existing gradient")
	pointer_drag(dock._canvas, Vector2i(90,60), Vector2i(110,70))
	check(target.selected_layer_id == second and target.get_paint_layer_count() == count + 2 and target.find_node(second).gradient_recipe.end == [110.0,70.0], "existing endpoint drag updates same layer on release")
	check(dock._history._undo_stack.size() == history + 3, "handle gesture adds exactly one undo entry")
	pointer_drag(dock._canvas, Vector2i(40,100), Vector2i(40,100))
	check(target.get_paint_layer_count() == count + 2 and dock._canvas._gradient_base != null, "empty click creates no layer and restores existing handles")
	edit_stop_alpha(dock._gradient_panel, "40")
	await create_timer(0.4).timeout
	check(is_equal_approx(float(target.find_node(second).gradient_recipe.stops[dock._canvas.gradient_selected_stop].color[3]), 0.4), "panel changes automatically update saved layer")
	edit_stop_alpha(dock._gradient_panel, "60")
	dock._select_tool(Canvas.ToolMode.BRUSH)
	check(is_equal_approx(float(target.find_node(second).gradient_recipe.stops[dock._canvas.gradient_selected_stop].color[3]), 0.6), "switching tools flushes pending control changes")
	dock._undo()
	target = dock._layer_session.get_active_target()
	check(is_equal_approx(float(target.find_node(second).gradient_recipe.stops[dock._canvas.gradient_selected_stop].color[3]), 0.4), "automatic control edit can be undone")
	dock._select_tool(Canvas.ToolMode.BRUSH)
	edit_stop_alpha(dock._gradient_panel, "20")
	await create_timer(0.4).timeout
	check(dock._canvas.active_tool == Canvas.ToolMode.GRADIENT and is_equal_approx(float(target.find_node(second).gradient_recipe.stops[dock._canvas.gradient_selected_stop].color[3]), 0.2), "panel control resumes gradient editing from another tool and saves automatically")
	dock._canvas.begin_gradient(Vector2(30,100))
	dock._canvas.update_gradient(Vector2(100,100))
	dock._canvas.cancel_active_selection_or_preview()
	check(target.get_paint_layer_count() == count + 2 and target.selected_layer_id == second and dock._canvas._gradient_base != null and not dock._canvas._gradient_creating_layer, "canceling new gesture preserves previous layer and restores its handles")
	dock.free()

func gradient_layer_checks():
	var dock := Dock.new()
	root.add_child(dock)
	await settle()
	dock._select_tool(Canvas.ToolMode.GRADIENT)
	var target = dock._layer_session.get_active_target()
	var base_id: String = target.selected_layer_id
	var base_pixels: PackedByteArray = target.get_selected_layer_image().get_data()
	var history: int = dock._history._undo_stack.size()
	dock._canvas._has_selection = true
	dock._canvas._selection_rect = Rect2i(2,2,20,20)
	dock._canvas.begin_gradient(Vector2(2,2))
	dock._canvas.update_gradient(Vector2(21,2))
	dock._canvas.add_gradient_stop()
	dock._canvas.edit_gradient_stop(1, Color(1,0,0,0.5), 0.4)
	dock._canvas.commit_gradient()
	var node = target.get_selected_layer()
	var id: String = node.id
	check(node.is_gradient_layer() and id != base_id, "Apply creates a distinct editable gradient layer")
	dock._gradient_output_mode.select(1)
	dock._gradient_output_mode.item_selected.emit(1)
	check(dock._canvas.gradient_layer_mode and dock._gradient_output_mode.selected == 1 and not dock._gradient_output_mode.disabled, "editing existing gradient does not overwrite or disable output preference")
	dock._gradient_output_mode.select(0)
	dock._gradient_output_mode.item_selected.emit(0)
	check(dock._get_layer_thumbnail_texture(target, node).get_width() == Dock.LAYER_THUMBNAIL_SIZE + 12, "layer type indicator adds a narrow column outside thumbnail")
	check(target.find_node(base_id).image.get_data() == base_pixels, "new gradient leaves original paint pixels intact")
	check(node.gradient_recipe.stops.size() == 3 and node.gradient_mask.get_pixel(0,0).a == 0 and node.gradient_mask.get_pixel(2,2).a == 1, "recipe and fixed selection mask retained")
	check(dock._history._undo_stack.size() == history + 1, "gradient creation is one undo step")
	await settle()
	dock._panel_host._capture_scroll_states()
	dock._select_tool(Canvas.ToolMode.BRUSH)
	await settle()
	check(dock._panel_host.is_panel_open("gradient") and dock._canvas.active_tool == Canvas.ToolMode.BRUSH, "gradient layer keeps panel available after switching tools")
	check(target.get_selected_layer().is_gradient_layer(), "tool switch preserves editable gradient layer")
	dock._gradient_panel._select(dock._canvas.gradient_selected_stop)
	check(dock._canvas.active_tool == Canvas.ToolMode.GRADIENT and dock._canvas._gradient_base != null, "selecting an interactive stop resumes gradient editing")
	dock._select_tool(Canvas.ToolMode.BRUSH)
	dock._select_paint_layer(target.target_id, base_id)
	await settle()
	check(not dock._panel_host.panels.has("gradient") and not dock._panel_host._scroll_states.has("gradient"), "panel closes safely when neither tool nor selected layer is gradient")
	dock._select_tool(Canvas.ToolMode.GRADIENT)
	check(dock._panel_host.is_panel_open("gradient"), "gradient tool opens panel on an ordinary paint layer")
	dock._select_paint_layer(target.target_id, id)
	dock._canvas.commit_gradient()
	check(dock._history._undo_stack.size() == history + 1, "unchanged editable gradient adds no history")
	var initial: Dictionary = node.gradient_recipe.duplicate(true)
	dock._canvas._has_selection = false
	dock._select_paint_layer(target.target_id, id)
	check(dock._canvas._gradient_base != null and not dock._canvas.editing_enabled and dock._canvas.gradient_editing_enabled, "selecting gradient reopens controls and protects raster pixels")
	dock._canvas.edit_gradient_stop(1, Color.GREEN, 0.6)
	dock._canvas.cancel_gradient()
	check(node.gradient_recipe == initial, "Cancel preserves stored gradient settings")
	dock._select_paint_layer(target.target_id, id)
	dock._canvas.edit_gradient_stop(1, Color.GREEN, 0.6)
	dock._canvas.commit_gradient()
	check(target.selected_layer_id == id and node.gradient_recipe.stops[1].position == 0.6, "Apply updates existing gradient rather than adding a layer")
	check(node.image.get_pixel(0,0).a == 0, "reediting retains original selection mask")
	dock._undo()
	target = dock._layer_session.get_active_target()
	node = target.find_node(id)
	check(node.gradient_recipe == initial, "Undo restores editable recipe")
	dock._redo()
	target = dock._layer_session.get_active_target()
	node = target.find_node(id)
	check(node.gradient_recipe.stops[1].position == 0.6, "Redo restores edited recipe")
	dock._canvas.cancel_gradient()
	var path := "user://gradient_layer_roundtrip.gddraw"
	var saved := LayerDocument.save_session(dock._layer_session, path)
	check(saved.ok, "gradient document saves")
	var restored := LayerSession.new()
	var loaded := LayerDocument.load_into_session(path, restored)
	check(loaded.ok, "gradient document loads")
	var loaded_node = restored.get_active_target().find_node(id)
	check(loaded_node.is_gradient_layer() and loaded_node.gradient_recipe == node.gradient_recipe and loaded_node.gradient_mask.get_data() == node.gradient_mask.get_data(), "document roundtrip retains recipe and mask")
	check(loaded_node.image.get_data() == node.image.get_data(), "document roundtrip retains rendered pixels")
	var restored_target = restored.get_active_target()
	check(restored_target.scale_layers(restored_target.size * 2, Image.INTERPOLATE_NEAREST), "gradient document resizes")
	check(loaded_node.gradient_recipe.end[0] == node.gradient_recipe.end[0] * 2 and loaded_node.gradient_mask.get_size() == loaded_node.image.get_size(), "resize scales recipe coordinates and mask together")
	check(Raster.render_recipe(loaded_node.gradient_recipe, loaded_node.image.get_size(), loaded_node.gradient_mask).get_data() == loaded_node.image.get_data(), "resized cache matches editable recipe")
	var malformed := initial.duplicate(true)
	malformed.stops[1].position = NAN
	check(not Raster.valid_recipe(malformed), "invalid saved gradient stops rejected")
	target.set_node_locked(id, true)
	dock._select_paint_layer(target.target_id, id)
	check(not dock._canvas.gradient_editing_enabled and dock._canvas._gradient_base == null, "locked gradient cannot be edited")
	target.set_node_locked(id, false)
	dock._select_paint_layer(target.target_id, id)
	dock._canvas.cancel_gradient()
	var copy_id: String = target.duplicate_node(id)
	var copy = target.find_node(copy_id)
	check(copy.is_gradient_layer() and copy.gradient_recipe == node.gradient_recipe, "Duplicate retains editable type")
	copy.gradient_recipe.stops[1].position = 0.7
	check(node.gradient_recipe.stops[1].position == 0.6, "duplicate recipes are isolated")
	target.select_layer(id)
	dock._rasterize_gradient_layer({"target_id": target.target_id, "node_id": id, "kind": "paint"})
	check(not target.find_node(id).is_gradient_layer() and dock._canvas.editing_enabled, "Rasterize enables normal painting")
	dock._undo()
	target = dock._layer_session.get_active_target()
	check(target.find_node(id).is_gradient_layer(), "Undo rasterize restores gradient")
	dock._canvas.cancel_gradient()
	dock._layer_session.mark_layered_saved()
	target.find_node(id).gradient_recipe.opacity = 0.75
	check(dock._layer_session.is_layered_dirty(), "recipe-only changes mark document dirty")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	dock.free()

func stop_checks():
	var canvas := Canvas.new()
	root.add_child(canvas)
	canvas.set_image(blank())
	canvas.active_tool = Canvas.ToolMode.GRADIENT
	canvas.brush_color = Color.RED
	canvas.background_color = Color.BLUE
	canvas.begin_gradient(Vector2.ZERO)
	canvas.update_gradient(Vector2(8,0))
	canvas.add_gradient_stop()
	check(canvas.get_gradient_stops().size() == 3 and canvas.gradient_selected_stop == 1, "Add selects a new middle stop")
	check(near(canvas.get_gradient_stops()[1].color, Color(0.5,0,0.5)), "new stop samples original ramp")
	canvas.edit_gradient_stop(1, Color(0,1,0,0.5), 0.5)
	canvas._refresh_gradient_preview()
	check(near(canvas._gradient_preview.get_pixel(4,0), Color(0,1,0,0.5)), "multi-stop raster includes color and alpha")
	check(canvas.get_image_copy().get_pixel(4,0).a == 0, "stop editing does not write pixels")
	canvas.gradient_reverse = true
	canvas.edit_gradient_stop(1, Color.GREEN, 0.25)
	canvas._refresh_gradient_preview()
	check(near(canvas._gradient_preview.get_pixel(6,0), Color.GREEN), "reverse mirrors stop positions and colors")
	canvas.add_gradient_stop(true)
	check(canvas.get_gradient_stops().size() == 4 and canvas.get_gradient_stops()[2].color == Color.GREEN, "Duplicate retains selected color")
	canvas.edit_gradient_stop(2, Color.GREEN, -1)
	check(canvas.get_gradient_stops()[2].position > canvas.get_gradient_stops()[1].position, "stops cannot cross neighbors")
	canvas.delete_gradient_stop()
	check(canvas.get_gradient_stops().size() == 3, "Delete removes intermediate stop")
	canvas.select_gradient_stop(0)
	canvas.delete_gradient_stop()
	canvas.edit_gradient_stop(0, Color.YELLOW, 0.5)
	check(canvas.get_gradient_stops().size() == 3 and canvas.get_gradient_stops()[0].position == 0.0, "endpoint stops cannot be removed or shifted")
	canvas._gradient_drag_stop = 1
	canvas._drag_gradient_handle(Vector2(4,0), false)
	check(is_equal_approx(canvas.get_gradient_stops()[1].position, 0.5), "canvas stop dragging updates offset")
	canvas.cancel_gradient()
	check(canvas._gradient_drag_stop == -1 and canvas.get_image_copy().get_pixel(4,0).a == 0, "Cancel discards edited draft")
	canvas.reset_gradient_stops()
	check(canvas.get_gradient_stops().size() == 2 and canvas.get_gradient_stops()[0].color == Color.RED, "Reset restores linked drawing colors")
	canvas.free()

func canvas_checks():
	var canvas := Canvas.new()
	root.add_child(canvas)
	canvas.size = Vector2(600,400)
	canvas.set_image(blank())
	canvas.active_tool = Canvas.ToolMode.GRADIENT
	canvas.brush_color = Color.RED
	canvas.background_color = Color.BLUE
	var commits: Array = []
	canvas.stroke_committed.connect(func(previous: Image): commits.append(previous))
	check(canvas.begin_gradient(Vector2.ZERO), "begin preview")
	canvas.update_gradient(Vector2(8,0))
	canvas._refresh_gradient_preview()
	var preview: PackedByteArray = canvas._gradient_preview.get_data()
	check(canvas.get_image_copy().get_pixel(0,0).a == 0 and commits.is_empty(), "preview does not mutate pixels or history")
	check(canvas.commit_gradient() and commits.size() == 1, "one commit per gesture")
	check(canvas.get_image_copy().get_data() == preview, "preview exactly matches committed pixels")
	canvas.begin_gradient(Vector2.ZERO)
	canvas.update_gradient(Vector2(4,3),true)
	check(is_equal_approx(canvas._gradient_end.x,canvas._gradient_end.y), "Shift snaps 45 degrees")
	check(canvas.cancel_active_selection_or_preview() and commits.size() == 1 and canvas.get_image_copy().get_data() == preview, "Escape cancellation preserves pixels and history")
	canvas.begin_gradient(Vector2.ZERO)
	check(not canvas.commit_gradient() and commits.size() == 1, "click adds no history")
	canvas.begin_gradient(Vector2.ZERO)
	canvas.update_gradient(Vector2(2,2))
	canvas.active_tool = Canvas.ToolMode.BRUSH
	check(canvas._gradient_base == null, "tool change cancels preview")
	canvas.active_tool = Canvas.ToolMode.GRADIENT
	canvas.editing_enabled = false
	check(not canvas.begin_gradient(Vector2.ZERO), "locked layer refuses gradient")
	canvas.editing_enabled = true
	canvas.set_image(blank())
	canvas.active_tool = Canvas.ToolMode.SELECT
	canvas._has_selection = true
	canvas._selection_rect = Rect2i(2,1,3,2)
	canvas.active_tool = Canvas.ToolMode.GRADIENT
	check(canvas._has_selection, "switching to gradient preserves selection")
	canvas.begin_gradient(Vector2.ZERO)
	var arrow := InputEventKey.new()
	arrow.keycode = KEY_RIGHT
	arrow.pressed = true
	canvas._gui_input(arrow)
	check(canvas._selection_rect == Rect2i(2,1,3,2), "arrow keys cannot transform selection during gradient drag")
	canvas.update_gradient(Vector2(8,0))
	canvas.commit_gradient()
	check(canvas.get_image_copy().get_pixel(2,1).a == 1 and canvas.get_image_copy().get_pixel(1,1).a == 0, "canvas gradient respects selection")
	canvas.begin_gradient(Vector2.ZERO)
	canvas.update_gradient(Vector2(8,0))
	canvas.delete_active_selection()
	check(not canvas.commit_gradient() and canvas.get_image_copy().get_pixel(2,1).a == 0, "another pixel edit cancels gradient instead of being overwritten")
	canvas.set_image(blank())
	canvas._document_rect = Rect2i(2,1,3,2)
	canvas.begin_gradient(Vector2(2,1))
	canvas.update_gradient(Vector2(4,1))
	canvas.commit_gradient()
	check(canvas.get_image_copy().get_pixel(2,1).a == 1 and canvas.get_image_copy().get_pixel(1,1).a == 0, "document bounds clip larger workspace")
	canvas.set_image(blank())
	await settle()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = canvas._image_pixel_center_to_local(Vector2i.ZERO)
	canvas._gui_input(press)
	var motion := InputEventMouseMotion.new()
	motion.position = canvas._image_pixel_center_to_local(Vector2i(8,0))
	canvas._gui_input(motion)
	press.pressed = false
	press.position = motion.position
	canvas._gui_input(press)
	check(canvas._gradient_base == null and canvas.get_image_copy().get_pixel(0,0).a == 1, "release applies raster gradient")
	motion.position = canvas._image_pixel_center_to_local(Vector2i(4,4))
	canvas._gui_input(motion)
	check(canvas._gradient_end == Vector2(8,0), "idle pointer motion leaves endpoints unchanged")
	canvas.set_image(blank())
	canvas.begin_gradient(Vector2.ZERO)
	canvas.update_gradient(Vector2(8,0))
	canvas._gradient_drag_handle = 0
	canvas._drag_gradient_handle(Vector2(1,1), false)
	check(canvas._gradient_start == Vector2(1,1) and canvas._gradient_end == Vector2(8,0), "start handle can be repositioned independently")
	canvas._gradient_drag_handle = 1
	canvas._drag_gradient_handle(Vector2(7,1), false)
	check(canvas._gradient_start == Vector2(1,1) and canvas._gradient_end == Vector2(7,1), "end handle can be repositioned independently")
	canvas.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check(canvas._gradient_base != null, "color picker/window focus changes preserve draft")
	canvas.brush_color = Color(0,1,0,0.5)
	canvas.background_color = Color(1,0,1,0.8)
	canvas.gradient_opacity = 0.5
	canvas._refresh_gradient_preview()
	check(near(canvas._gradient_preview.get_pixel(1,1), Color(0,1,0,0.25)), "foreground alpha and opacity update existing draft")
	check(near(canvas._gradient_preview.get_pixel(7,1), Color(1,0,1,0.4)), "background alpha updates existing draft")
	canvas.gradient_reverse = true
	canvas._refresh_gradient_preview()
	check(near(canvas._gradient_preview.get_pixel(1,1), Color(1,0,1,0.4)), "reverse updates existing draft")
	canvas.gradient_reverse = false
	canvas.gradient_transparent = true
	canvas.gradient_radial = true
	canvas._refresh_gradient_preview()
	check(canvas._gradient_preview.get_pixel(7,1).a == 0 and canvas._gradient_settings.radial, "transparent and radial options update draft")
	var before_apply := commits.size()
	check(canvas.commit_gradient() and commits.size() == before_apply + 1, "all endpoint and option adjustments apply as one edit")
	check(near(canvas.get_image_copy().get_pixel(1,1), Color(0,1,0,0.25)), "Apply uses latest settings")
	canvas.free()

func worker_checks():
	var canvas := Canvas.new()
	root.add_child(canvas)
	canvas.set_image(blank(1024,1024))
	canvas.active_tool = Canvas.ToolMode.GRADIENT
	canvas.begin_gradient(Vector2.ZERO)
	canvas.update_gradient(Vector2(1023,0))
	var started := Time.get_ticks_msec()
	canvas._advance_gradient_preview()
	print("Gradient 1024 async launch ms: ", Time.get_ticks_msec()-started)
	check(canvas._gradient_worker != null, "large preview blends on worker")
	canvas.update_gradient(Vector2(0,1023))
	var deadline := Time.get_ticks_msec()+5000
	while (canvas._gradient_worker != null or canvas._gradient_pending) and Time.get_ticks_msec() < deadline:
		await create_timer(0.01).timeout
	check(canvas._gradient_preview != null and canvas._gradient_worker == null, "latest coalesced preview completes")
	check(canvas._gradient_preview.get_pixel(1023,0).r < 0.02 and canvas._gradient_preview.get_pixel(0,1023).r > 0.98, "superseded worker cannot replace latest gradient")
	canvas.update_gradient(Vector2(1023,1023))
	canvas._advance_gradient_preview()
	canvas.cancel_gradient()
	await create_timer(0.2).timeout
	check(canvas._gradient_preview == null and canvas.get_image_copy().get_pixel(0,0).a == 0, "cancel discards outstanding worker result")
	canvas.begin_gradient(Vector2.ZERO)
	canvas.update_gradient(Vector2(1023,0))
	canvas._advance_gradient_preview()
	canvas.free()
	await settle()
	check(true, "teardown joins worker without touching freed nodes; inspect logs")

func texture_session_checks():
	var source := MeshInstance3D.new()
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0,1,2])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(blank(16,16))
	mesh.surface_set_material(0,material)
	source.mesh = mesh
	root.add_child(source)
	var dock := Dock.new()
	root.add_child(dock)
	await settle()
	dock._begin_3d_layer_session(Discovery.new().discover([source], Discovery.Scope.SELECTED_HIERARCHY), false, false)
	dock._on_view_mode_selected(2)
	await settle()
	var original_layout: Dictionary = dock._panel_host.describe_layout()
	dock._select_tool(Canvas.ToolMode.GRADIENT)
	check(dock._panel_host.is_panel_active("gradient"), "Gradient tool opens temporary panel")
	check(dock._gradient_panel.rows.size() == 2, "panel lists endpoint stops")
	dock._gradient_panel.canvas.add_gradient_stop()
	check(dock._gradient_panel.rows.size() == 3 and not dock._gradient_panel.delete_button.disabled, "panel follows added stop selection")
	edit_stop_alpha(dock._gradient_panel, "25")
	check(is_equal_approx(dock._canvas.get_gradient_stops()[1].color.a, 0.25), "panel opacity updates stop")
	dock._canvas.reset_gradient_stops()
	dock._select_tool(Canvas.ToolMode.BRUSH)
	check(dock._panel_host.describe_layout() == original_layout and not dock._panel_host.panels.has("gradient"), "leaving Gradient restores exact prior panel layout")
	dock._select_tool(Canvas.ToolMode.GRADIENT)
	var target = dock._layer_session.get_active_target()
	var base_id: String = target.selected_layer_id
	var base_pixels: PackedByteArray = target.get_selected_layer_image().get_data()
	var added: String = target.add_paint_layer("Gradient")
	dock._gradient_output_mode.select(1)
	dock._gradient_output_mode.item_selected.emit(1)
	target.select_layer(added)
	target.set_node_opacity(added,0.5)
	dock._sync_canvas_to_active_layer()
	dock._canvas.brush_color = Color.RED
	dock._canvas.background_color = Color.BLUE
	var dirty_before: bool = dock._texture_3d_layer_coordinator.is_dirty()
	dock._canvas.begin_gradient(Vector2.ZERO)
	dock._canvas.update_gradient(Vector2(15,0))
	dock._canvas._refresh_gradient_preview()
	check(dock._texture_3d_layer_coordinator.is_dirty() == dirty_before, "gradient preview preserves 3D texture dirty state")
	var display: Image = dock._canvas._gradient_texture.get_image()
	check(near(display.get_pixel(0,0), Color(1,0,0,0.5)), "preview composites active layer opacity")
	dock._canvas.commit_gradient()
	await settle()
	check(dock._texture_3d_layer_coordinator.is_dirty(), "2D gradient commit dirties 3D session")
	# Dummy rendering retains ImageTexture's original upload on get_image().
	# Verify its updated pixels with a real renderer, plus the CPU composite in both.
	check(near(dock._canvas.get_document_display_image_copy().get_pixel(0,0), Color(1,0,0,0.5)), "committed composite respects layer opacity")
	if DisplayServer.get_name() != "headless":
		check(near(dock._paint_3d_texture.get_image().get_pixel(0,0), Color(1,0,0,0.5)), "3D preview reflects composited gradient")
	target.select_layer(base_id)
	check(target.get_selected_layer_image().get_data() == base_pixels, "gradient changes only active layer")
	target.select_layer(added)
	dock._sync_canvas_to_active_layer()
	dock._gradient_output_mode.select(0)
	dock._gradient_output_mode.item_selected.emit(0)
	dock._canvas.brush_color = Color.GREEN
	dock._canvas.background_color = Color.GREEN
	dock._canvas.begin_gradient(Vector2.ZERO)
	dock._canvas.update_gradient(Vector2(15,0))
	dock._canvas._refresh_gradient_preview()
	var layer_preview: Image = dock._canvas._gradient_texture.get_image()
	check(near(layer_preview.get_pixel(0,0), Color.GREEN), "new layer preview uses its own opacity above original layer")
	dock._canvas.commit_gradient()
	await settle()
	check(target.get_selected_layer().is_gradient_layer() and dock._texture_3d_layer_coordinator.is_dirty(), "editable gradient dirties 3D session")
	check(near(target.composite().get_pixel(0,0), Color.GREEN), "3D gradient cached composite matches preview")
	if DisplayServer.get_name() != "headless":
		check(near(dock._paint_3d_texture.get_image().get_pixel(0,0), Color.GREEN), "editable gradient updates actual 3D texture")
	dock.free()
	source.free()
func dock_checks():
	var dock := Dock.new()
	root.add_child(dock)
	dock.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await settle()
	dock._select_tool(Canvas.ToolMode.GRADIENT)
	check(dock._gradient_button.button_pressed and dock._gradient_options.visible and not dock._shape_options.visible, "tool selection and options")
	check(dock._gradient_button.get_index() == dock._fill_button.get_index()+1 and dock._shape_button.get_index() == dock._gradient_button.get_index()+1, "gradient toolbar placement")
	check(dock._color_set.get_parent() == dock._gradient_options, "shared color controls move into gradient options")
	var tools_tab := dock._settings_panel.find_child("Tools", true, false)
	check(tools_tab != null and tools_tab.is_ancestor_of(dock._gradient_output_mode) and tools_tab.is_ancestor_of(dock._brush_mode_selector), "Tools preferences groups brush and gradient controls")
	check(not dock._gradient_options.is_ancestor_of(dock._gradient_output_mode), "output preference is absent from toolbar")
	var panel = dock._gradient_panel
	check(not panel.rows[0].position.editable and not panel.rows[-1].position.editable, "endpoint position fields are read-only")
	check(panel.delete_button.disabled, "endpoint deletion remains disabled")
	check(panel.add_button.text.is_empty() and panel.add_button.icon != null and panel.duplicate_button.icon != null and panel.delete_button.icon != null, "bottom actions use shared icons")
	var rail_button: Button = dock._panel_host.panels.gradient.button
	check(rail_button.get_theme_constant("icon_max_width") == dock._gradient_button.get_theme_constant("icon_max_width") and rail_button.custom_minimum_size == dock._gradient_button.custom_minimum_size, "gradient rail icon uses toolbar sizing")
	panel.add_button.pressed.emit()
	var middle: Dictionary = panel.rows[1]
	check(middle.position.editable and not panel.delete_button.disabled, "intermediate row position and deletion enabled")
	middle.position.text = "35%"
	middle.position.text_submitted.emit("35%")
	check(is_equal_approx(dock._canvas.get_gradient_stops()[1].position, 0.35), "row position field accepts percentage input")
	middle.picker.color_changed.emit(Color(0.2,0.4,0.6,0.3))
	check(near(dock._canvas.get_gradient_stops()[1].color, Color(0.2,0.4,0.6,0.3)) and panel.rows[1].picker == middle.picker, "row color picker edits RGBA without rebuilding controls")
	edit_stop_alpha(panel, "invalid")
	check(middle.alpha.text == "30%", "invalid opacity input restores current value with its unit")
	edit_stop_alpha(panel, "150")
	check(dock._canvas.get_gradient_stops()[1].color.a == 1 and middle.alpha.text == "100%", "opacity input clamps and displays accepted value with its unit")
	middle.position.grab_focus()
	middle.position.text = "42"
	dock._canvas.gradient_stops_changed.emit()
	check(middle.position.text == "42" and middle.position.has_focus(), "preview refresh preserves in-progress text and keyboard focus")
	middle.position.text_submitted.emit("42")
	panel.delete_button.pressed.emit()
	check(panel.rows.size() == 2, "delete icon removes intermediate row")
	dock._canvas.reset_gradient_stops()
	var dropdowns := 0
	var opacity_fields := 0
	for child in dock._gradient_options.get_children():
		if child is OptionButton: dropdowns += 1
		if child is SpinBox: opacity_fields += 1
	check(dropdowns == 1 and opacity_fields == 0, "gradient toolbar has only shape dropdown and no overall opacity field")
	check(dock.find_child("Commit Gradient", true, false) == null and dock.find_child("Cancel Gradient", true, false) == null, "gradient commit/cancel toolbar buttons removed")
	var event := InputEventKey.new()
	event.keycode = KEY_G
	event.pressed = true
	check(Shortcuts.new().get_action(event) == Shortcuts.ACTION_GRADIENT, "G shortcut")
	event.ctrl_pressed = true
	check(Shortcuts.new().get_layer_tree_action(event) == Shortcuts.ACTION_NEW_GROUP, "Ctrl+G still creates layer group")
	dock._canvas.begin_gradient(Vector2.ZERO)
	dock._canvas.update_gradient(Vector2(30,30))
	dock._canvas._refresh_gradient_preview()
	var pixels: PackedByteArray = dock._canvas._gradient_preview.get_data()
	var previous_count: int = dock._history._undo_stack.size()
	dock._canvas.commit_gradient()
	check(dock._history._undo_stack.size() == previous_count+1, "dock receives exactly one history entry")
	dock._undo()
	check(dock._history._undo_stack.size() == previous_count and dock._canvas.get_image_copy().get_data() != pixels, "undo restores previous layer")
	dock._redo()
	check(dock._canvas.get_image_copy().get_data() == pixels, "redo restores gradient")
	dock._canvas.begin_gradient(Vector2.ZERO)
	dock._canvas.update_gradient(Vector2(10,0))
	dock._canvas.cancel_gradient()
	check(dock._canvas._gradient_base == null and dock._canvas.get_image_copy().get_data() == pixels and dock._history._undo_stack.size() == previous_count + 1, "Cancel button preserves pixels and history")
	dock._canvas.begin_gradient(Vector2.ZERO)
	dock._canvas.update_gradient(Vector2(15,0))
	dock._canvas.grab_focus()
	event.ctrl_pressed = false
	event.keycode = KEY_ENTER
	dock._input(event)
	check(dock._canvas._gradient_base != null and dock._history._undo_stack.size() == previous_count + 2, "committed layer retains editable handles")
	check(not dock._begin_3d_paint_hit({}), "direct 3D gradient painting is explicitly unavailable")
	if "--screenshot" in OS.get_cmdline_user_args():
		dock._canvas.begin_gradient(Vector2(10,10))
		dock._canvas.update_gradient(Vector2(100,85))
		dock._canvas.add_gradient_stop()
		dock._canvas.edit_gradient_stop(1, Color(0.2,0.55,1,0.7), 0.5)
		dock._canvas._refresh_gradient_preview()
		await settle()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://gradient_review.png")
		dock._panel_host.activate_panel("layers")
		await settle()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://gradient_layers_review.png")
		dock._open_preferences()
		await settle()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://gradient_preferences_review.png")
	dock.free()
