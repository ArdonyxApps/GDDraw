extends SceneTree

const Dock := preload("res://addons/GDDraw/gddraw_dock.gd")
const Discovery := preload("res://addons/GDDraw/gddraw_3d_layer_discovery.gd")
const Canvas := preload("res://addons/GDDraw/gddraw_canvas.gd")

class InputDock:
	extends Dock
	var scripted_hits: Array[Dictionary] = []
	func _pick_3d_paint_uv(position: Vector2) -> Dictionary:
		if not scripted_hits.is_empty():
			return scripted_hits.pop_front()
		return super._pick_3d_paint_uv(position)

var failures: Array[String] = []
var assertions := 0

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, label: String) -> void:
	assertions += 1
	if not value:
		failures.push_back(label)
		push_error(label)

func _run() -> void:
	if "--benchmark" in OS.get_cmdline_user_args():
		await exercise(false, 2048)
		await exercise(false, 4096)
	else:
		await exercise(false)
		await exercise(true)
		await exercise(false, 32, true)
	print("Cross-object gestures: %d assertions, %d failures" % [assertions, failures.size()])
	quit(0 if failures.is_empty() else 1)

func mesh(tex: Texture2D, slots := 1) -> ArrayMesh:
	var result := ArrayMesh.new()
	for slot in range(slots):
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		var offset := Vector3(slot * 2, 0, 0)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([offset, offset + Vector3.RIGHT, offset + Vector3.UP])
		arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN])
		arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2])
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var material := StandardMaterial3D.new()
		material.albedo_texture = tex
		result.surface_set_material(slot, material)
	return result

func texture(side: int) -> ImageTexture:
	var image := Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
	image.fill(Color.BLACK)
	return ImageTexture.create_from_image(image)

func hit(dock, binding: Dictionary, uv: Vector2) -> Dictionary:
	var preview: MeshInstance3D = dock._paint_3d_mesh
	var cache = dock._paint_3d_mesh_cache
	var material: StandardMaterial3D = dock._paint_3d_material
	if str(preview.get_meta("gddraw_binding_key", "")) != str(binding.binding_key):
		for candidate in dock._paint_3d_context_meshes:
			if str(candidate.get_meta("gddraw_binding_key", "")) == str(binding.binding_key):
				preview = candidate
				var preview_id := str(candidate.get_meta("gddraw_preview_id"))
				cache = dock._paint_3d_context_caches[preview_id]
				material = dock._paint_3d_context_material_by_target[preview_id]
	var origin: Vector3 = preview.global_transform * Vector3(uv.x + binding.session.material_slot * 2, uv.y, 1)
	return dock._query_3d_preview_mesh_hit(preview, cache, origin, Vector3.FORWARD, binding.target_id, material)

func pixel(dock, target_id: String, uv: Vector2) -> Color:
	var image: Image = dock._layer_session.get_target(target_id).get_selected_layer_image_reference()
	return image.get_pixel(int(uv.x * image.get_width()), int(uv.y * image.get_height()))

func exercise(shared: bool, side := 32, separate_slots := false) -> void:
	var source := Node3D.new()
	root.add_child(source)
	var first := MeshInstance3D.new()
	first.name = "First"
	var atlas := texture(side)
	first.mesh = mesh(atlas, 2 if shared or separate_slots else 1)
	if separate_slots:
		first.mesh.surface_get_material(1).albedo_texture = texture(64)
	source.add_child(first)
	var second := MeshInstance3D.new()
	second.name = "Second"
	second.position.x = 5
	second.mesh = mesh(atlas if shared else texture(side * 2 if side == 32 else side))
	source.add_child(second)
	var dock = InputDock.new()
	root.add_child(dock)
	await process_frame
	var discovery := Discovery.new().discover([source], Discovery.Scope.SELECTED_HIERARCHY)
	dock._begin_3d_layer_session(discovery, false, false)
	dock._on_view_mode_selected(1)
	await process_frame
	var entries: Array = dock._texture_3d_layer_coordinator.get_preview_entries()
	var a: Dictionary = entries[0]
	var b: Dictionary = entries[entries.size() - 1]
	var uv_a := Vector2(0.125, 0.125)
	var uv_b := Vector2(0.625, 0.125)
	var uv_return := Vector2(0.125, 0.625)
	dock._canvas.brush_size = 1
	dock._canvas.brush_touch_pixels = true
	dock._canvas.pixel_perfect = true
	dock._canvas.stroke_overlap_enabled = "--no-overlap" not in OS.get_cmdline_user_args()
	dock._canvas.active_tool = Canvas.ToolMode.BRUSH
	dock._canvas.brush_color = Color.WHITE
	dock._history.clear()
	var tree_root: TreeItem = dock._layers_tree.get_root()
	var selection: Dictionary = dock._get_selected_layers_context().duplicate(true)
	var original_dirty: bool = dock._texture_3d_layer_coordinator.is_dirty()
	var started := Time.get_ticks_usec()
	check(dock._on_3d_paint_uv_started(hit(dock, a, uv_a)), "brush starts")
	var began := Time.get_ticks_usec()
	check(dock._canvas._stroke_start_image == dock._get_3d_gesture_original_image(a.target_id), "raster baseline reuses immutable gesture image")
	dock._on_3d_paint_uv_dragged(hit(dock, b, uv_b))
	var crossed := Time.get_ticks_usec()
	check(pixel(dock, b.target_id, uv_b) == Color.WHITE, "destination painted at its own resolution")
	check(not dock._history.can_undo(), "target crossing has no partial history entry")
	check(tree_root == dock._layers_tree.get_root(), "tree remains the same during crossing")
	check(selection == dock._get_selected_layers_context(), "visible selection remains unchanged during crossing")
	dock._on_3d_paint_uv_dragged(hit(dock, a, uv_return))
	var returned := Time.get_ticks_usec()
	var b_display: Image = dock._paint_3d_target_display_cache[b.target_id]
	check(b_display.get_pixel(int(uv_b.x * b_display.get_width()), int(uv_b.y * b_display.get_height())) == Color.WHITE, "departed target preview contains live pixels")
	check(pixel(dock, a.target_id, uv_a) == Color.WHITE, "return preserves first segment")
	check(pixel(dock, a.target_id, uv_return) == Color.WHITE, "return paints next segment")
	check(pixel(dock, a.target_id, Vector2(0.375, 0.375)) == Color.BLACK, "no diagonal bridge between objects")
	dock._on_3d_paint_uv_finished()
	var finished := Time.get_ticks_usec()
	check(dock._history._undo_stack.size() == 1, "one gesture has exactly one undo entry")
	dock._undo()
	var undone := Time.get_ticks_usec()
	check(pixel(dock, a.target_id, uv_a) == Color.BLACK and pixel(dock, b.target_id, uv_b) == Color.BLACK, "undo restores every affected target")
	check(dock._texture_3d_layer_coordinator.is_dirty() == original_dirty, "undo restores original dirty state")
	b_display = dock._paint_3d_target_display_cache[b.target_id]
	check(b_display.get_pixel(int(uv_b.x * b_display.get_width()), int(uv_b.y * b_display.get_height())) == Color.BLACK, "undo refreshes inactive preview")
	dock._redo()
	var redone := Time.get_ticks_usec()
	check(pixel(dock, a.target_id, uv_a) == Color.WHITE and pixel(dock, b.target_id, uv_b) == Color.WHITE, "redo restores every affected target")
	check(dock._texture_3d_layer_coordinator.is_dirty(), "redo restores dirty state")
	b_display = dock._paint_3d_target_display_cache[b.target_id]
	check(b_display.get_pixel(int(uv_b.x * b_display.get_width()), int(uv_b.y * b_display.get_height())) == Color.WHITE, "redo refreshes inactive preview")
	if side > 32:
		print("Gesture %dx%d two targets ms: start=%.1f cross=%.1f return=%.1f release=%.1f undo=%.1f redo=%.1f; editable history=%d MiB" % [side, side, (began-started)/1000.0, (crossed-began)/1000.0, (returned-crossed)/1000.0, (finished-returned)/1000.0, (undone-finished)/1000.0, (redone-undone)/1000.0, side*side*4*2/1048576])
		dock.free()
		source.free()
		await process_frame
		return
	var before: Dictionary = dock._layer_session.capture_state()
	var previous_binding: String = dock._active_3d_binding_key
	dock._canvas.brush_color = Color.RED
	dock._on_3d_paint_uv_started(hit(dock, a, uv_a))
	dock._on_3d_paint_uv_dragged(hit(dock, b, uv_b))
	dock._cancel_selection_or_preview()
	check(pixel(dock, a.target_id, uv_a) == Color.WHITE and pixel(dock, b.target_id, uv_b) == Color.WHITE, "cancel restores all pixels")
	check(dock._layer_session.active_target_id == before.active_target_id and dock._active_3d_binding_key == previous_binding, "cancel restores routing")
	check(dock._history._undo_stack.size() == 1, "cancel adds no history")
	dock._canvas.brush_color = Color.WHITE
	dock._on_3d_paint_uv_started(hit(dock, a, uv_a))
	dock._on_3d_paint_uv_finished()
	check(dock._history._undo_stack.size() == 1, "no-op creates no entry")
	dock._canvas.brush_color = Color.RED
	dock._on_3d_paint_uv_started(hit(dock, a, uv_a))
	dock._on_3d_paint_uv_dragged({})
	dock._on_3d_paint_uv_dragged(hit(dock, a, uv_return))
	check(pixel(dock, a.target_id, Vector2(0.125, 0.375)) == Color.BLACK, "miss prevents interpolation")
	dock._resolve_3d_brush_gesture(true)
	dock._canvas.active_tool = Canvas.ToolMode.ERASER
	dock._on_3d_paint_uv_started(hit(dock, a, uv_a))
	dock._on_3d_paint_uv_dragged(hit(dock, b, uv_b))
	dock._on_3d_paint_uv_finished()
	check(pixel(dock, a.target_id, uv_a) == Color.BLACK and pixel(dock, b.target_id, uv_b) == Color.BLACK, "eraser restores each target base")
	dock._undo()
	check(pixel(dock, a.target_id, uv_a) == Color.WHITE and pixel(dock, b.target_id, uv_b) == Color.WHITE, "eraser undo restores both targets")
	dock._canvas.active_tool = Canvas.ToolMode.BRUSH
	dock._canvas.brush_color = Color.WHITE
	dock._on_3d_paint_uv_started(hit(dock, a, uv_a))
	dock._on_3d_paint_uv_finished()
	check(dock._history.can_redo(), "no-op preserves existing redo history")
	dock._canvas.brush_color = Color.RED
	dock._canvas.active_tool = Canvas.ToolMode.BRUSH
	dock._on_3d_paint_uv_started(hit(dock, a, uv_a))
	dock._on_3d_paint_uv_dragged(hit(dock, b, uv_b))
	dock._notification(Control.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(dock._paint_3d_gesture_before.is_empty(), "focus loss resolves gesture")
	check(pixel(dock, a.target_id, uv_a) == Color.WHITE and pixel(dock, b.target_id, uv_b) == Color.WHITE, "focus loss restores both targets")
	# Target Lock permits different bindings of a shared atlas only.
	dock._route_3d_hit_to_paint_target(hit(dock, a, uv_a))
	dock._layer_session.set_target_lock_enabled(true)
	dock._on_3d_paint_uv_started(hit(dock, a, uv_a))
	dock._on_3d_paint_uv_dragged(hit(dock, b, uv_b))
	check(pixel(dock, b.target_id, uv_b) == (Color.RED if shared else Color.WHITE), "Target Lock accepts only shared-target bindings")
	dock._resolve_3d_brush_gesture(true)
	dock._layer_session.set_target_lock_enabled(false)
	if not shared:
		var target = dock._layer_session.get_target(b.target_id)
		for ancestor in [false, true]:
			var lock_id: String = target.selected_layer_id
			if ancestor:
				lock_id = target.add_group("Locked ancestor")
				target.move_node(target.selected_layer_id, lock_id)
			target.set_node_locked(lock_id, true)
			dock._on_3d_paint_uv_started(hit(dock, a, uv_a))
			dock._on_3d_paint_uv_dragged(hit(dock, b, uv_b))
			check(pixel(dock, b.target_id, uv_b) == Color.WHITE, "locked layer or ancestor rejects destination")
			check(dock._layer_session.active_target_id == a.target_id, "locked destination cannot alter routing")
			dock._on_3d_paint_uv_dragged(hit(dock, a, uv_return))
			check(pixel(dock, a.target_id, Vector2(0.125, 0.375)) == Color.BLACK, "locked hit breaks interpolation")
			dock._resolve_3d_brush_gesture(true)
			target = dock._layer_session.get_target(b.target_id)
			target.set_node_locked(lock_id, false)
		# Each destination uses its remembered layer, including a partial-opacity stack.
		var original_layer: String = target.selected_layer_id
		var overlay: String = target.add_paint_layer("Overlay")
		target.set_node_opacity(overlay, 0.5)
		dock._on_3d_paint_uv_started(hit(dock, a, uv_a))
		dock._on_3d_paint_uv_dragged(hit(dock, b, uv_b))
		dock._on_3d_paint_uv_finished()
		check(target.selected_layer_id == overlay and pixel(dock, b.target_id, uv_b) == Color.RED, "remembered selected layer receives paint")
		check(target.capture_node_state(original_layer).image.get_pixel(40, 8) == Color.WHITE, "other destination layers stay untouched")
		dock._undo()
	else:
		# Cross both material slots on the same mesh while Target Lock is enabled.
		dock._layer_session.set_target_lock_enabled(true)
		dock._on_3d_paint_uv_started(hit(dock, a, uv_a))
		dock._on_3d_paint_uv_dragged(hit(dock, entries[1], uv_b))
		check(dock._active_3d_binding_key == str(entries[1].binding_key), "same-mesh material slot receives gesture")
		check(pixel(dock, a.target_id, uv_b) == Color.RED, "same-mesh slot paints shared target")
		dock._sync_3d_paint_texture()
		for material in dock._paint_3d_context_materials:
			check(material.albedo_texture == dock._paint_3d_material.albedo_texture, "all shared bindings use one live preview texture")
		dock._resolve_3d_brush_gesture(true)
		dock._layer_session.set_target_lock_enabled(false)
	# No-overlap coverage survives a visit to another target or binding.
	dock._canvas.stroke_overlap_enabled = false
	dock._canvas.brush_color = Color(0, 0, 1, 0.5)
	for touch_pixels in [true, false]:
		dock._canvas.brush_touch_pixels = touch_pixels
		dock._on_3d_paint_uv_started(hit(dock, a, uv_a))
		var once := pixel(dock, a.target_id, uv_a)
		dock._on_3d_paint_uv_dragged(hit(dock, b, uv_b))
		dock._on_3d_paint_uv_dragged(hit(dock, a, uv_a))
		check(pixel(dock, a.target_id, uv_a) == once, "pixel-perfect and soft one-pass opacity persist across return")
		dock._resolve_3d_brush_gesture(true)
	dock._canvas.brush_touch_pixels = true
	dock._canvas.stroke_overlap_enabled = true
	if separate_slots:
		dock._canvas.brush_color = Color.RED
		dock._on_3d_paint_uv_started(hit(dock, a, uv_a))
		dock._on_3d_paint_uv_dragged(hit(dock, entries[1], uv_b))
		check(pixel(dock, entries[1].target_id, uv_b) == Color.RED, "independent same-mesh material target receives paint")
		check(dock._active_3d_binding_key == str(entries[1].binding_key), "independent material binding becomes active")
		dock._on_3d_paint_uv_finished()
		dock._undo()
		check(pixel(dock, entries[1].target_id, uv_b) == Color.BLACK, "same-mesh independent target undoes with gesture")
	# A small UV seam must break interpolation even below the distance threshold.
	var left := hit(dock, a, uv_a)
	var right := left.duplicate(true)
	right.triangle_index = int(left.triangle_index) + 1
	right.texture_uv = uv_a + Vector2(0.01, 0.01)
	check(dock._should_connect_3d_stroke_hits(left, right), "continuous shared edge remains interpolatable")
	var seam_uvs: PackedVector2Array = right.texture_triangle_uvs.duplicate()
	for index in range(seam_uvs.size()):
		seam_uvs[index] += Vector2(0.01, 0)
	right.texture_triangle_uvs = seam_uvs
	check(not dock._should_connect_3d_stroke_hits(left, right), "small UV discontinuity breaks interpolation")
	right = left.duplicate(true)
	right.binding_key = "unrelated_binding"
	check(not dock._should_connect_3d_stroke_hits(left, right), "identical triangle indices on different bindings never connect")
	# Exercise event ordering: a miss followed by a hit in the same frame must
	# not be coalesced away, and release must accept its own final target.
	dock._canvas.brush_color = Color.RED
	dock.scripted_hits.assign([hit(dock, a, uv_a), {}, hit(dock, a, uv_return), hit(dock, b, uv_b)])
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(-100, -100)
	dock._on_3d_paint_view_gui_input(press)
	var motion := InputEventMouseMotion.new()
	motion.position = press.position
	dock._on_3d_paint_view_gui_input(motion)
	dock._on_3d_paint_view_gui_input(motion)
	check(pixel(dock, a.target_id, Vector2(0.125, 0.375)) == Color.BLACK, "same-frame miss is not coalesced into a bridge")
	press.pressed = false
	dock._on_3d_paint_view_gui_input(press)
	check(dock._paint_3d_gesture_before.is_empty() and not dock._paint_3d_drawing, "release closes input and history lifecycles")
	check(dock._active_3d_binding_key == str(b.binding_key), "release synchronizes final accepted binding")
	check(pixel(dock, b.target_id, uv_b) == Color.RED, "release position is painted before commit")
	dock._undo()
	# Stop Editing/document guards resolve edits before computing dirty state.
	for transition in [dock.SessionTransition.STOP_SESSION, dock.SessionTransition.NEW_DOCUMENT]:
		dock._on_3d_paint_uv_started(hit(dock, a, uv_a))
		dock._on_3d_paint_uv_dragged(hit(dock, b, uv_b))
		var count_before: int = dock._history._undo_stack.size()
		dock._request_session_transition(transition)
		check(dock._paint_3d_gesture_before.is_empty(), "document guard resolves gesture")
		check(dock._history._undo_stack.size() == count_before + 1, "document guard commits exactly once")
		dock._cancel_pending_session_transition()
		dock._undo()
	# Source removal cancels before retained private-preview painting resumes.
	dock._on_3d_paint_uv_started(hit(dock, a, uv_a))
	dock._on_3d_paint_uv_dragged(hit(dock, b, uv_b))
	source.remove_child(second)
	dock._validate_3d_gesture_sources()
	check(dock._paint_3d_gesture_before.is_empty(), "source removal resolves all targets")
	check(pixel(dock, a.target_id, uv_a) == Color.WHITE, "source removal restores earlier target")
	source.add_child(second)
	# Single-click tools do not start a held gesture.
	dock._select_tool(Canvas.ToolMode.FILL)
	dock._canvas.brush_color = Color.GREEN
	var history_count: int = dock._history._undo_stack.size()
	check(not dock._on_3d_paint_uv_started(hit(dock, a, uv_a)), "fill is single click")
	check(dock._history._undo_stack.size() == history_count + 1, "fill retains one ordinary history action")
	dock._select_tool(Canvas.ToolMode.EYEDROPPER)
	history_count = dock._history._undo_stack.size()
	check(not dock._on_3d_paint_uv_started(hit(dock, a, uv_a)), "eyedropper is single click")
	check(dock._history._undo_stack.size() == history_count, "eyedropper creates no history")
	# History must retain native layer bounds, not the expanded canvas workspace.
	dock._route_3d_hit_to_paint_target(hit(dock, a, uv_a))
	var native_target = dock._layer_session.get_target(a.target_id)
	var tiny := Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
	var tiny_id: String = native_target.add_paint_layer("Offset", tiny, "", 0, Vector2i(4, 4))
	dock._sync_canvas_to_active_layer()
	dock._select_tool(Canvas.ToolMode.BRUSH)
	dock._canvas.brush_color = Color.WHITE
	dock._on_3d_paint_uv_started(hit(dock, a, uv_a))
	dock._on_3d_paint_uv_dragged(hit(dock, b, uv_b))
	dock._on_3d_paint_uv_finished()
	dock._undo()
	native_target = dock._layer_session.get_target(a.target_id)
	check(native_target.selected_layer_id == tiny_id, "undo restores remembered native layer selection")
	check(native_target.get_selected_layer_image_reference().get_size() == Vector2i(8, 8), "undo preserves native layer dimensions")
	check(native_target.get_selected_layer_origin() == Vector2i(4, 4), "undo preserves native layer origin")
	dock._canvas.brush_color = Color.TRANSPARENT
	history_count = dock._history._undo_stack.size()
	dock._on_3d_paint_uv_started(hit(dock, a, uv_a))
	dock._on_3d_paint_uv_finished()
	native_target = dock._layer_session.get_target(a.target_id)
	check(native_target.get_selected_layer_image_reference().get_size() == Vector2i(8, 8), "no-op cannot expand native layer bounds")
	check(dock._history._undo_stack.size() == history_count and dock._history.can_redo(), "native-layer no-op preserves history")
	await exercise_editable_destinations(dock, a, b, uv_a, uv_b)
	var retained_session = dock._layer_session
	dock._canvas.brush_color = Color.WHITE
	dock._on_3d_paint_uv_started(hit(dock, a, uv_a))
	dock.free()
	check(retained_session.get_target(a.target_id).get_selected_layer_image_reference().get_size() == Vector2i(8, 8), "dock teardown restores an interrupted gesture")
	source.free()
	await process_frame

func exercise_editable_destinations(dock, a: Dictionary, b: Dictionary, uv_a: Vector2, uv_b: Vector2) -> void:
	var original: Dictionary = dock._layer_session.capture_state()
	var counts := {}
	for binding in [a, b]:
		if counts.has(binding.target_id): continue
		dock._route_3d_hit_to_paint_target(hit(dock, binding, uv_a))
		dock._select_tool(Canvas.ToolMode.GRADIENT)
		dock._canvas.begin_gradient(Vector2.ZERO)
		dock._canvas.update_gradient(Vector2(24, 0))
		dock._canvas.commit_gradient()
		var target = dock._layer_session.get_target(binding.target_id)
		counts[binding.target_id] = target.get_paint_layer_count()
		check(target.get_selected_layer().is_gradient_layer(), "3D fixture selects editable Gradient")
	for mode in ["cancel", "transparent", "commit"]:
		dock._select_tool(Canvas.ToolMode.BRUSH)
		dock._canvas.brush_color = Color.TRANSPARENT if mode == "transparent" else Color.RED
		var history_count: int = dock._history._undo_stack.size()
		dock._on_3d_paint_uv_started(hit(dock, a, uv_a))
		dock._on_3d_paint_uv_dragged(hit(dock, b, uv_b))
		check(dock._canvas.active_tool == Canvas.ToolMode.BRUSH, "cross-target routing preserves explicit Brush")
		dock._resolve_3d_brush_gesture(mode == "cancel")
		check(dock._canvas.active_tool == Canvas.ToolMode.BRUSH, "resolving automatic layers preserves Brush")
		for target_id in counts:
			var target = dock._layer_session.get_target(target_id)
			check(target.get_paint_layer_count() == counts[target_id] + (1 if mode == "commit" else 0), "3D %s keeps only effective automatic layers" % mode)
		check(dock._history._undo_stack.size() == history_count + (1 if mode == "commit" else 0), "3D automatic layers share gesture history")
		if mode == "commit":
			dock._undo()
			for target_id in counts:
				check(dock._layer_session.get_target(target_id).get_paint_layer_count() == counts[target_id], "3D undo removes automatic paint layers across targets")
	dock._restore_layer_session(original)
	dock._sync_canvas_to_active_layer()
	dock._select_tool(Canvas.ToolMode.BRUSH)
	await process_frame
