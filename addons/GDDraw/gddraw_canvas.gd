@tool
class_name GDDrawCanvasControl
extends Control

signal stroke_committed(previous_image: Image)
signal canvas_size_changed(size: Vector2i)
signal view_changed(zoom_percent: int)
signal color_picked(color: Color, pixel: Vector2i)
signal selection_committed(selection_rect: Rect2i)
signal selection_cleared()
signal image_drop_requested(data: Variant)
signal image_changed(image: Image)
signal hover_uv_changed(uv: Vector2, has_hover: bool)

enum ToolMode {
	BRUSH,
	ERASER,
	FILL,
	LINE,
	RECTANGLE,
	ELLIPSE,
	EYEDROPPER,
	SELECT,
	LASSO_SELECT,
	PAN,
}

const DEFAULT_IMAGE_SIZE := Vector2i(128, 128)
const CHECKER_SIZE := 16
const MIN_IMAGE_SIZE := 1
const MAX_IMAGE_SIZE := 4096
const MIN_ZOOM := 0.1
const MAX_PIXEL_VIEWPORT_FRACTION := 0.5
const MAX_ZOOM_SAFETY_CEILING := 10000.0
const ZOOM_STEP := 1.25
const SELECTION_HANDLE_SIZE := 8.0
const SELECTION_ROTATE_OFFSET := 22.0
const CANVAS_AREA_BACKGROUND_COLOR := Color(0.30, 0.30, 0.30, 1.0)

enum SelectionTransformMode {
	NONE,
	MOVE,
	SCALE,
	ROTATE,
}

enum BrushHead {
	SQUARE,
	CIRCLE,
}

enum FillMode {
	CONTIGUOUS,
	GLOBAL,
	REPLACE_COLOR,
}

enum MirrorMode {
	OFF,
	HORIZONTAL,
	VERTICAL,
	BOTH,
}

enum ScaleInterpolation {
	NEAREST,
	BILINEAR,
}


# Public tool/view state configured by the dock.
var brush_color := Color.BLACK
var brush_size := 12
var alpha_lock := false:
	set(value):
		alpha_lock = value
		_refresh_shape_preview_image()
		queue_redraw()
var fill_tolerance := 0:
	set(value):
		fill_tolerance = clampi(value, 0, 255)
var fill_mode := FillMode.CONTIGUOUS
var mirror_mode := MirrorMode.OFF:
	set(value):
		mirror_mode = clampi(value, MirrorMode.OFF, MirrorMode.BOTH)
		_refresh_shape_preview_image()
		queue_redraw()
var stroke_overlap_enabled := true
var brush_head := BrushHead.SQUARE:
	set(value):
		brush_head = value
		queue_redraw()
var brush_touch_pixels := true:
	set(value):
		brush_touch_pixels = value
		queue_redraw()
var brush_hardness := 0.75:
	set(value):
		brush_hardness = clampf(value, 0.0, 1.0)
		queue_redraw()
var shape_fill_enabled := false:
	set(value):
		shape_fill_enabled = value
		_refresh_shape_preview_image()
		queue_redraw()
var shape_from_center := false:
	set(value):
		shape_from_center = value
		_refresh_shape_preview_image()
		queue_redraw()
var active_tool := ToolMode.BRUSH:
	set(value):
		active_tool = value
		if active_tool != ToolMode.BRUSH and active_tool != ToolMode.ERASER:
			_is_drawing = false
			_stroke_start_image = null
			_stroke_coverage = PackedFloat32Array()
		if not _is_shape_tool():
			_is_shape_previewing = false
			_clear_shape_preview_image()
			_set_canvas_mouse_hidden(false)
		if active_tool != ToolMode.SELECT and active_tool != ToolMode.LASSO_SELECT:
			_is_selecting = false
			_is_lasso_selecting = false
			if _has_floating_selection:
				_commit_floating_selection(false)
			_clear_selection()
			selection_cleared.emit()
		if active_tool != ToolMode.PAN:
			_is_panning = false
		_has_preview = false
		_set_canvas_mouse_hidden(false)
		mouse_default_cursor_shape = _get_base_cursor_shape()
		queue_redraw()
var eraser_enabled := false:
	set(value):
		eraser_enabled = value
		if value:
			active_tool = ToolMode.ERASER
		elif active_tool == ToolMode.ERASER:
			active_tool = ToolMode.BRUSH
var pan_tool_enabled := false:
	set(value):
		pan_tool_enabled = value
		if value:
			active_tool = ToolMode.PAN
		elif active_tool == ToolMode.PAN:
			active_tool = ToolMode.BRUSH
var pixel_perfect := true:
	set(value):
		pixel_perfect = value
		queue_redraw()
var show_grid := false:
	set(value):
		show_grid = value
		queue_redraw()
var snap_to_grid := false:
	set(value):
		snap_to_grid = value
		_refresh_shape_preview_image()
		queue_redraw()
var grid_size := 1:
	set(value):
		grid_size = maxi(1, value)
		_refresh_shape_preview_image()
		queue_redraw()
var grid_min_cell_size := 6:
	set(value):
		grid_min_cell_size = maxi(1, value)
		queue_redraw()
var grid_color := Color(0.1, 0.45, 0.9, 0.55):
	set(value):
		grid_color = value
		queue_redraw()
var checker_color_light := Color(0.68, 0.68, 0.68, 1.0):
	set(value):
		checker_color_light = Color(value.r, value.g, value.b, 1.0)
		queue_redraw()
var checker_color_dark := Color(0.48, 0.48, 0.48, 1.0):
	set(value):
		checker_color_dark = Color(value.r, value.g, value.b, 1.0)
		queue_redraw()
var tile_preview_enabled := false:
	set(value):
		tile_preview_enabled = value
		queue_redraw()
var uv_overlay_visible := false:
	set(value):
		uv_overlay_visible = value
		queue_redraw()
var zoom_multiplier := 1.0:
	set(value):
		if not is_finite(value):
			value = zoom_multiplier
		zoom_multiplier = clampf(value, MIN_ZOOM, get_max_zoom())
		_clamp_pan_offset()
		queue_redraw()
		view_changed.emit(get_zoom_percent())


# Internal canvas, stroke, selection, preview, and overlay state.
var _image := Image.create_empty(DEFAULT_IMAGE_SIZE.x, DEFAULT_IMAGE_SIZE.y, false, Image.FORMAT_RGBA8)
var _texture := ImageTexture.create_from_image(_image)
var _image_rect := Rect2()
var _is_drawing := false
var _is_panning := false
var _last_pixel := Vector2i.ZERO
var _last_pan_position := Vector2.ZERO
var _pan_offset := Vector2.ZERO
var _stroke_start_image: Image
var _stroke_coverage := PackedFloat32Array()
var _has_preview := false
var _preview_position := Vector2.ZERO
var _is_shape_previewing := false
var _shape_start_pixel := Vector2i.ZERO
var _shape_pointer_pixel := Vector2i.ZERO
var _shape_end_pixel := Vector2i.ZERO
var _shape_preview_image: Image
var _shape_preview_texture: ImageTexture
var _shape_preview_rect := Rect2i()
var _is_shape_preview_rasterizing := false
var _shape_preview_original_pixels := {}
var _is_selecting := false
var _selection_start_pixel := Vector2i.ZERO
var _selection_end_pixel := Vector2i.ZERO
var _has_selection := false
var _selection_rect := Rect2i()
var _selection_mask: Image
var _crop_preview_rect := Rect2i()
var _has_crop_preview := false
var _is_lasso_selecting := false
var _lasso_points: Array[Vector2i] = []
var _clipboard_image: Image
var _is_transforming_selection := false
var _selection_transform_mode := SelectionTransformMode.NONE
var _selection_scale_handle := -1
var _selection_transform_start_pixel := Vector2i.ZERO
var _selection_transform_start_rect := Rect2i()
var _selection_transform_previous_image: Image
var _selection_preview_image: Image
var _selection_preview_texture: ImageTexture
var _selection_preview_rect := Rect2i()
var _selection_preview_angle := 0.0
var _selection_transform_start_angle := 0.0
var _selection_transform_start_mouse_angle := 0.0
var _selection_transform_flip_h := false
var _selection_transform_flip_v := false
var _selection_transform_started_floating := false
var _has_floating_selection := false
var _floating_image: Image
var _floating_texture: ImageTexture
var _floating_rect := Rect2i()
var _floating_angle := 0.0
var _floating_mask: Image
var _floating_cancel_image: Image
var _floating_history_recorded := false
var _shift_constrain := false
var _mouse_hidden_by_canvas := false
var _previous_mouse_mode := Input.MOUSE_MODE_VISIBLE
var _eraser_restore_image: Image
var _external_hover_visible := false
var _external_hover_uv := Vector2.ZERO
var _external_hover_triangle := PackedVector2Array()
var _external_hover_triangles: Array[PackedVector2Array] = []
var _uv_overlay_edges: Array = []
var _uv_overlay_vertices := PackedVector2Array()
var _uv_overlay_cached_canvas_rect := Rect2()
var _uv_overlay_cached_visible_rect := Rect2()
var _uv_overlay_cached_line_points := PackedVector2Array()
var _uv_overlay_cached_vertex_points := PackedVector2Array()
var _uv_overlay_cached_detail_level := -1
var _uv_overlay_geometry_dirty := true
var _mirror_raster_scope_depth := 0
var _mirror_generated_pixels := {}
var _selection_nudge_previous_image: Image
var _last_viewport_size := Vector2.ZERO


# Lifecycle and public image/session API.
func _init() -> void:
	custom_minimum_size = Vector2(360, 220)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true
	mouse_entered.connect(_emit_hover_at_mouse)
	mouse_exited.connect(_clear_preview)
	_clear_image(Color(0, 0, 0, 0))


func _enter_tree() -> void:
	var canvas_host := get_parent() as Control
	if canvas_host and not canvas_host.resized.is_connected(_on_drawable_viewport_resized):
		canvas_host.resized.connect(_on_drawable_viewport_resized)
	call_deferred("_on_drawable_viewport_resized")


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_on_drawable_viewport_resized()
	elif what == NOTIFICATION_EXIT_TREE:
		_set_canvas_mouse_hidden(false)


func get_image_copy() -> Image:
	var copied_image := _image.duplicate()
	if _has_floating_selection:
		_blit_image_alpha_to_image(copied_image, _get_rotated_floating_image(), _floating_rect.position)
	return copied_image


func get_canvas_size() -> Vector2i:
	return Vector2i(_image.get_width(), _image.get_height())


func capture_workspace_state() -> Dictionary:
	return {
		"image": _image.duplicate(),
		"zoom": zoom_multiplier,
		"pan": _pan_offset,
		"active_tool": active_tool,
		"eraser_enabled": eraser_enabled,
		"pan_tool_enabled": pan_tool_enabled,
		"mirror_mode": mirror_mode,
		"show_grid": show_grid,
		"tile_preview_enabled": tile_preview_enabled,
		"has_selection": _has_selection,
		"selection_rect": _selection_rect,
		"selection_mask": _selection_mask.duplicate() if _selection_mask else null,
		"has_floating_selection": _has_floating_selection,
		"floating_image": _floating_image.duplicate() if _floating_image else null,
		"floating_rect": _floating_rect,
		"floating_angle": _floating_angle,
		"floating_mask": _floating_mask.duplicate() if _floating_mask else null,
		"floating_cancel_image": _floating_cancel_image.duplicate() if _floating_cancel_image else null,
		"floating_history_recorded": _floating_history_recorded,
	}


func restore_workspace_state(state: Dictionary) -> void:
	var image: Image = state.get("image", null)
	if not image or image.is_empty():
		image = Image.create_empty(DEFAULT_IMAGE_SIZE.x, DEFAULT_IMAGE_SIZE.y, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
	set_image(image)
	zoom_multiplier = float(state.get("zoom", 1.0))
	_pan_offset = state.get("pan", Vector2.ZERO)
	mirror_mode = int(state.get("mirror_mode", MirrorMode.OFF))
	show_grid = bool(state.get("show_grid", false))
	tile_preview_enabled = bool(state.get("tile_preview_enabled", false))
	active_tool = int(state.get("active_tool", ToolMode.BRUSH))
	eraser_enabled = bool(state.get("eraser_enabled", false))
	pan_tool_enabled = bool(state.get("pan_tool_enabled", false))
	_has_selection = bool(state.get("has_selection", false))
	_selection_rect = state.get("selection_rect", Rect2i())
	var selection_mask: Image = state.get("selection_mask", null)
	_selection_mask = selection_mask.duplicate() if selection_mask else null
	_has_floating_selection = bool(state.get("has_floating_selection", false))
	var floating_image: Image = state.get("floating_image", null)
	_floating_image = floating_image.duplicate() if floating_image else null
	_floating_texture = ImageTexture.create_from_image(_floating_image) if _floating_image else null
	_floating_rect = state.get("floating_rect", Rect2i())
	_floating_angle = float(state.get("floating_angle", 0.0))
	var floating_mask: Image = state.get("floating_mask", null)
	_floating_mask = floating_mask.duplicate() if floating_mask else null
	var floating_cancel_image: Image = state.get("floating_cancel_image", null)
	_floating_cancel_image = floating_cancel_image.duplicate() if floating_cancel_image else null
	_floating_history_recorded = bool(state.get("floating_history_recorded", false))
	_clamp_pan_offset()
	canvas_size_changed.emit(get_canvas_size())
	image_changed.emit(get_image_copy())
	if has_active_selection():
		selection_committed.emit(_floating_rect if _has_floating_selection else _selection_rect)
	else:
		selection_cleared.emit()
	queue_redraw()


func has_visible_pixels() -> bool:
	var image := get_image_copy()
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.0:
				return true
	return false


func set_image(image: Image) -> void:
	_image = image.duplicate()
	if _image.has_mipmaps():
		_image.clear_mipmaps()
	if _image.get_format() != Image.FORMAT_RGBA8:
		_image.convert(Image.FORMAT_RGBA8)
	_texture = ImageTexture.create_from_image(_image)
	_has_crop_preview = false
	_crop_preview_rect = Rect2i()
	_clear_selection()
	_clear_floating_selection()
	_clamp_pan_offset()
	canvas_size_changed.emit(get_canvas_size())
	image_changed.emit(get_image_copy())
	queue_redraw()


func set_eraser_restore_image(image: Image) -> void:
	if image and not image.is_empty():
		_eraser_restore_image = image.duplicate()
		if _eraser_restore_image.get_format() != Image.FORMAT_RGBA8:
			_eraser_restore_image.convert(Image.FORMAT_RGBA8)
	else:
		_eraser_restore_image = null


func clear_eraser_restore_image() -> void:
	_eraser_restore_image = null


func set_external_hover_uv(uv: Vector2, visible := true) -> void:
	_external_hover_uv = uv
	_external_hover_visible = visible
	queue_redraw()


func clear_external_hover_uv() -> void:
	if not _external_hover_visible:
		return
	_external_hover_visible = false
	queue_redraw()


func set_external_hover_triangle(triangle_uvs: PackedVector2Array) -> void:
	_external_hover_triangle = triangle_uvs.duplicate()
	_external_hover_triangles = [triangle_uvs.duplicate()]
	queue_redraw()


func set_external_hover_triangles(triangles: Array) -> void:
	_external_hover_triangles.clear()
	for triangle in triangles:
		if triangle is PackedVector2Array and triangle.size() >= 3:
			_external_hover_triangles.push_back(triangle.duplicate())
	_external_hover_triangle = _external_hover_triangles[0].duplicate() if not _external_hover_triangles.is_empty() else PackedVector2Array()
	queue_redraw()


func clear_external_hover_triangle() -> void:
	if _external_hover_triangle.is_empty():
		return
	_external_hover_triangle = PackedVector2Array()
	_external_hover_triangles.clear()
	queue_redraw()


func set_uv_overlay_data(edges: Array, vertices: PackedVector2Array) -> void:
	_uv_overlay_edges = edges.duplicate()
	_uv_overlay_vertices = vertices.duplicate()
	_uv_overlay_geometry_dirty = true
	queue_redraw()


func clear_uv_overlay_data() -> void:
	_uv_overlay_edges.clear()
	_uv_overlay_vertices = PackedVector2Array()
	_uv_overlay_cached_line_points = PackedVector2Array()
	_uv_overlay_cached_vertex_points = PackedVector2Array()
	_uv_overlay_geometry_dirty = true
	queue_redraw()


func begin_uv_stroke(uv: Vector2) -> void:
	var pixel := _uv_to_image_pixel(uv)
	if active_tool == ToolMode.FILL:
		var previous_image := get_image_copy()
		if _flood_fill(pixel, brush_color, false):
			_refresh_texture()
			stroke_committed.emit(previous_image)
		return
	if active_tool == ToolMode.EYEDROPPER:
		color_picked.emit(_image.get_pixel(pixel.x, pixel.y), pixel)
		return
	if not _is_stroke_tool():
		return
	_is_drawing = true
	_stroke_start_image = get_image_copy()
	_begin_stroke_coverage()
	_last_pixel = pixel
	_stamp_unmirrored(_last_pixel)
	_refresh_texture()


func continue_uv_stroke(uv: Vector2) -> void:
	if not _is_drawing:
		return
	var pixel := _uv_to_image_pixel(uv)
	_draw_line_unmirrored(_last_pixel, pixel)
	_last_pixel = pixel
	_refresh_texture()


func end_uv_stroke() -> void:
	_end_stroke()


func begin_uv_triangle_stroke(uv: Vector2, triangle_uvs: PackedVector2Array) -> void:
	var pixel := _uv_to_image_pixel(uv)
	if active_tool == ToolMode.FILL:
		var previous_image := get_image_copy()
		if _flood_fill(pixel, brush_color, false):
			_refresh_texture()
			stroke_committed.emit(previous_image)
		return
	if active_tool == ToolMode.EYEDROPPER:
		color_picked.emit(_image.get_pixel(pixel.x, pixel.y), pixel)
		return
	if not _is_stroke_tool():
		return
	_is_drawing = true
	_stroke_start_image = get_image_copy()
	_begin_stroke_coverage()
	_last_pixel = pixel
	_stamp_uv_3d(_last_pixel, triangle_uvs)
	_refresh_texture()


func continue_uv_triangle_stroke(uv: Vector2, triangle_uvs: PackedVector2Array, connect_from_previous := true) -> void:
	if not _is_drawing:
		return
	var pixel := _uv_to_image_pixel(uv)
	if connect_from_previous:
		_draw_uv_3d_line(_last_pixel, pixel, triangle_uvs)
	else:
		_stamp_uv_3d(pixel, triangle_uvs)
	_last_pixel = pixel
	_refresh_texture()


func end_uv_triangle_stroke() -> void:
	_end_stroke()


func resize_canvas(new_size: Vector2i, keep_pixels: bool) -> Image:
	new_size = Vector2i(
		clampi(new_size.x, MIN_IMAGE_SIZE, MAX_IMAGE_SIZE),
		clampi(new_size.y, MIN_IMAGE_SIZE, MAX_IMAGE_SIZE)
	)
	var previous_image := get_image_copy()
	var resized_image := Image.create_empty(new_size.x, new_size.y, false, Image.FORMAT_RGBA8)
	resized_image.fill(Color(0, 0, 0, 0))
	if keep_pixels:
		var copy_size := Vector2i(
			mini(previous_image.get_width(), new_size.x),
			mini(previous_image.get_height(), new_size.y)
		)
		resized_image.blit_rect(previous_image, Rect2i(Vector2i.ZERO, copy_size), Vector2i.ZERO)
	_image = resized_image
	_texture = ImageTexture.create_from_image(_image)
	_has_crop_preview = false
	_crop_preview_rect = Rect2i()
	_clear_selection()
	_clear_floating_selection(false)
	_clamp_pan_offset()
	canvas_size_changed.emit(get_canvas_size())
	queue_redraw()
	return previous_image


func scale_image(new_size: Vector2i, interpolation := ScaleInterpolation.NEAREST) -> bool:
	if (
		new_size.x < MIN_IMAGE_SIZE
		or new_size.y < MIN_IMAGE_SIZE
		or new_size.x > MAX_IMAGE_SIZE
		or new_size.y > MAX_IMAGE_SIZE
		or new_size == get_canvas_size()
		or interpolation < ScaleInterpolation.NEAREST
		or interpolation > ScaleInterpolation.BILINEAR
	):
		return false
	var previous_image := get_image_copy()
	var scaled_image := _resample_image(previous_image, new_size, interpolation)
	if not scaled_image or scaled_image.is_empty():
		return false
	if scaled_image.get_format() != Image.FORMAT_RGBA8:
		scaled_image.convert(Image.FORMAT_RGBA8)
	_image = scaled_image
	_texture = ImageTexture.create_from_image(_image)
	_has_crop_preview = false
	_crop_preview_rect = Rect2i()
	_clear_selection()
	_clear_floating_selection(false)
	_clamp_pan_offset()
	canvas_size_changed.emit(get_canvas_size())
	image_changed.emit(get_image_copy())
	selection_cleared.emit()
	stroke_committed.emit(previous_image)
	queue_redraw()
	return true


func _resample_image(source: Image, new_size: Vector2i, interpolation: int) -> Image:
	var result := Image.create_empty(new_size.x, new_size.y, false, Image.FORMAT_RGBA8)
	var source_size := Vector2i(source.get_width(), source.get_height())
	for target_y in range(new_size.y):
		var source_y := (float(target_y) + 0.5) * float(source_size.y) / float(new_size.y) - 0.5
		for target_x in range(new_size.x):
			var source_x := (float(target_x) + 0.5) * float(source_size.x) / float(new_size.x) - 0.5
			var color: Color
			if interpolation == ScaleInterpolation.NEAREST:
				color = source.get_pixel(
					clampi(roundi(source_x), 0, source_size.x - 1),
					clampi(roundi(source_y), 0, source_size.y - 1)
				)
			else:
				color = _sample_bilinear_premultiplied(source, source_x, source_y)
			result.set_pixel(target_x, target_y, color)
	return result


func _sample_bilinear_premultiplied(source: Image, source_x: float, source_y: float) -> Color:
	var left := floori(source_x)
	var top := floori(source_y)
	var right := left + 1
	var bottom := top + 1
	var weight_x := source_x - float(left)
	var weight_y := source_y - float(top)
	left = clampi(left, 0, source.get_width() - 1)
	right = clampi(right, 0, source.get_width() - 1)
	top = clampi(top, 0, source.get_height() - 1)
	bottom = clampi(bottom, 0, source.get_height() - 1)
	var top_color := _lerp_premultiplied(
		_premultiply_color(source.get_pixel(left, top)),
		_premultiply_color(source.get_pixel(right, top)),
		weight_x
	)
	var bottom_color := _lerp_premultiplied(
		_premultiply_color(source.get_pixel(left, bottom)),
		_premultiply_color(source.get_pixel(right, bottom)),
		weight_x
	)
	var premultiplied := _lerp_premultiplied(top_color, bottom_color, weight_y)
	if premultiplied.a <= 0.0:
		return Color(0, 0, 0, 0)
	return Color(
		premultiplied.r / premultiplied.a,
		premultiplied.g / premultiplied.a,
		premultiplied.b / premultiplied.a,
		premultiplied.a
	)


func _premultiply_color(color: Color) -> Color:
	return Color(color.r * color.a, color.g * color.a, color.b * color.a, color.a)


func _lerp_premultiplied(from: Color, to: Color, weight: float) -> Color:
	return Color(
		lerpf(from.r, to.r, weight),
		lerpf(from.g, to.g, weight),
		lerpf(from.b, to.b, weight),
		lerpf(from.a, to.a, weight)
	)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return _drop_data_might_contain_image(data) or _drop_data_might_contain_3d_mesh(data)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	image_drop_requested.emit(data)


func _drop_data_might_contain_image(data: Variant) -> bool:
	if data is String:
		return _is_supported_drop_image_path(data)
	if data is Texture2D:
		return true
	if data is Resource:
		return _is_supported_drop_image_path(data.resource_path)
	if data is Dictionary:
		if data.has("files") or data.has("paths") or data.has("path") or data.has("resource") or data.has("nodes"):
			return true
	if data is Array:
		for item in data:
			if _drop_data_might_contain_image(item):
				return true
	return false


func _drop_data_might_contain_3d_mesh(data: Variant) -> bool:
	if data is Mesh or data is MeshInstance3D:
		return true
	if data is String:
		return data.strip_edges().begins_with("res://")
	if data is Dictionary:
		for key in ["nodes", "resource", "resource_path", "mesh"]:
			if data.has(key):
				return true
	if data is Array:
		for item in data:
			if _drop_data_might_contain_3d_mesh(item):
				return true
	return false


func _is_supported_drop_image_path(path: String) -> bool:
	var normalized_path := path.strip_edges()
	if normalized_path.is_empty():
		return false
	if normalized_path.begins_with("res://"):
		return normalized_path.get_extension().to_lower() in ["png", "jpg", "jpeg", "webp", "bmp", "tga", "svg"]
	normalized_path = normalized_path.replace("\\", "/")
	if normalized_path.begins_with("file:///"):
		normalized_path = normalized_path.substr(8)
		if OS.get_name() == "Windows" and normalized_path.length() > 2 and normalized_path[0] == "/" and normalized_path[2] == ":":
			normalized_path = normalized_path.substr(1)
	if not FileAccess.file_exists(normalized_path):
		return false
	return normalized_path.get_extension().to_lower() in ["png", "jpg", "jpeg", "webp", "bmp", "tga", "svg"]


# Public document, crop, selection, and view commands used by the dock.
func clear_canvas() -> Image:
	var previous_image := get_image_copy()
	_clear_selection()
	_clear_floating_selection(false)
	_clear_image(Color(0, 0, 0, 0))
	return previous_image


func has_active_selection() -> bool:
	return _has_selection or _has_floating_selection


func has_floating_selection() -> bool:
	return _has_floating_selection or _is_transforming_selection


func get_selection_crop_rect() -> Rect2i:
	if _has_floating_selection:
		return _clip_pixel_rect(_floating_rect)
	if not _has_selection:
		return Rect2i()
	var clipped_rect := _clip_pixel_rect(_selection_rect)
	if clipped_rect.size.x <= 0 or clipped_rect.size.y <= 0 or not _selection_mask:
		return clipped_rect
	var occupied := _get_mask_occupied_rect(_selection_mask)
	if occupied.size.x <= 0 or occupied.size.y <= 0:
		return Rect2i()
	return _clip_pixel_rect(Rect2i(_selection_rect.position + occupied.position, occupied.size))


func get_transparent_bounds() -> Rect2i:
	var image := get_image_copy()
	var left := image.get_width()
	var top := image.get_height()
	var right := -1
	var bottom := -1
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a8 > 0:
				left = mini(left, x)
				top = mini(top, y)
				right = maxi(right, x)
				bottom = maxi(bottom, y)
	if right < left or bottom < top:
		return Rect2i()
	return Rect2i(Vector2i(left, top), Vector2i(right - left + 1, bottom - top + 1))


func begin_crop_preview(pixel_rect: Rect2i) -> Rect2i:
	return update_crop_preview(pixel_rect)


func update_crop_preview(pixel_rect: Rect2i) -> Rect2i:
	_crop_preview_rect = _clip_pixel_rect(pixel_rect)
	_has_crop_preview = _crop_preview_rect.size.x > 0 and _crop_preview_rect.size.y > 0
	queue_redraw()
	return _crop_preview_rect


func cancel_crop_preview() -> bool:
	if not _has_crop_preview:
		return false
	_has_crop_preview = false
	_crop_preview_rect = Rect2i()
	queue_redraw()
	return true


func has_crop_preview() -> bool:
	return _has_crop_preview


func get_crop_preview_rect() -> Rect2i:
	return _crop_preview_rect if _has_crop_preview else Rect2i()


func get_crop_preview_image() -> Image:
	if not _has_crop_preview:
		return Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)
	return get_image_copy().get_region(_crop_preview_rect)


func crop_to_selection() -> bool:
	return crop_to_rect(get_selection_crop_rect())


func trim_transparent_bounds() -> bool:
	return crop_to_rect(get_transparent_bounds())


func apply_crop_preview() -> bool:
	if not _has_crop_preview:
		return false
	return crop_to_rect(_crop_preview_rect)


func crop_to_rect(pixel_rect: Rect2i) -> bool:
	var crop_rect := _clip_pixel_rect(pixel_rect)
	var full_rect := Rect2i(Vector2i.ZERO, get_canvas_size())
	if crop_rect.size.x <= 0 or crop_rect.size.y <= 0 or crop_rect == full_rect:
		return false
	var previous_image := get_image_copy()
	var cropped_image := previous_image.get_region(crop_rect)
	if cropped_image.is_empty():
		return false
	if cropped_image.get_format() != Image.FORMAT_RGBA8:
		cropped_image.convert(Image.FORMAT_RGBA8)
	_image = cropped_image
	_texture = ImageTexture.create_from_image(_image)
	_has_crop_preview = false
	_crop_preview_rect = Rect2i()
	_clear_selection()
	_clear_floating_selection(false)
	_clamp_pan_offset()
	canvas_size_changed.emit(get_canvas_size())
	image_changed.emit(get_image_copy())
	selection_cleared.emit()
	stroke_committed.emit(previous_image)
	queue_redraw()
	return true


func has_clipboard_image() -> bool:
	return _clipboard_image != null and not _clipboard_image.is_empty()


func set_clipboard_image(image: Image) -> bool:
	if not image or image.is_empty():
		return false
	_clipboard_image = image.duplicate()
	if _clipboard_image.get_format() != Image.FORMAT_RGBA8:
		_clipboard_image.convert(Image.FORMAT_RGBA8)
	return true


func select_all() -> bool:
	if _has_floating_selection:
		_commit_floating_selection()
	_selection_rect = Rect2i(Vector2i.ZERO, get_canvas_size())
	_selection_mask = null
	_has_selection = true
	selection_committed.emit(_selection_rect)
	queue_redraw()
	return true


func copy_selection() -> bool:
	if _has_floating_selection:
		_clipboard_image = _get_rotated_floating_image()
		return true
	if not _has_selection:
		return false

	var clipped_rect := _clip_pixel_rect(_selection_rect)
	if clipped_rect.size.x <= 0 or clipped_rect.size.y <= 0:
		return false

	_clipboard_image = _copy_selected_image()
	return true


func cut_selection() -> bool:
	if _has_floating_selection:
		var previous_image := get_image_copy()
		_clipboard_image = _get_rotated_floating_image()
		_clear_floating_selection()
		_clear_selection()
		stroke_committed.emit(previous_image)
		queue_redraw()
		return true
	if not _has_selection:
		return false
	if not copy_selection():
		return false

	var previous_image := get_image_copy()
	_clear_selected_pixels()
	_refresh_texture()
	stroke_committed.emit(previous_image)
	return true


func paste_selection() -> bool:
	if not has_clipboard_image():
		return false

	var previous_image := get_image_copy()
	var paste_size := Vector2i(_clipboard_image.get_width(), _clipboard_image.get_height())
	var paste_position := _selection_rect.position if _has_selection else _get_centered_paste_position(paste_size)
	paste_position = _clamp_rect_position(paste_position, paste_size)
	_set_floating_selection(_clipboard_image.duplicate(), Rect2i(paste_position, paste_size))
	_selection_rect = Rect2i(paste_position, paste_size)
	_has_selection = true
	selection_committed.emit(_selection_rect)
	stroke_committed.emit(previous_image)
	_floating_history_recorded = true
	queue_redraw()
	return true


func duplicate_selection() -> bool:
	if not has_active_selection():
		return false
	if _has_floating_selection:
		_commit_floating_selection()
	var selected_image := _copy_selected_image()
	var selected_mask := _selection_mask.duplicate() if _selection_mask else null
	if not selected_image or selected_image.is_empty():
		return false
	var previous_image := get_image_copy()
	_set_floating_selection(selected_image, _clip_pixel_rect(_selection_rect), selected_mask, previous_image)
	stroke_committed.emit(previous_image)
	_floating_history_recorded = true
	selection_committed.emit(_selection_rect)
	queue_redraw()
	return true


func rotate_selection_clockwise() -> bool:
	return _rotate_selection_quarter_turn(true)


func rotate_selection_counterclockwise() -> bool:
	return _rotate_selection_quarter_turn(false)


func rotate_selection_degrees(degrees: float) -> bool:
	if not has_active_selection():
		return false
	var normalized := fposmod(degrees, 360.0)
	if is_zero_approx(normalized) or is_equal_approx(normalized, 360.0):
		return false
	if is_equal_approx(normalized, 90.0):
		return _rotate_selection_quarter_turn(true)
	if is_equal_approx(normalized, 270.0):
		return _rotate_selection_quarter_turn(false)
	var previous_image := get_image_copy()
	var source_rect := _floating_rect if _has_floating_selection else _clip_pixel_rect(_selection_rect)
	var source_image := _get_rotated_floating_image() if _has_floating_selection else _copy_selected_image()
	var source_mask := _floating_mask.duplicate() if _floating_mask != null else (_selection_mask.duplicate() if _selection_mask != null else null)
	if _has_floating_selection and source_mask != null and not is_zero_approx(_floating_angle):
		source_mask = _rotate_image_nearest(source_mask, _floating_angle)
	if source_image == null or source_image.is_empty() or source_rect.size.x <= 0 or source_rect.size.y <= 0:
		return false
	if not _has_floating_selection:
		_clear_selected_pixels()
	var rotated_image := _rotate_image_nearest(source_image, deg_to_rad(normalized))
	var rotated_mask := _rotate_image_nearest(source_mask, deg_to_rad(normalized)) if source_mask != null else null
	var center_twice := source_rect.position * 2 + source_rect.size
	var rotated_size := Vector2i(rotated_image.get_width(), rotated_image.get_height())
	var rotated_position := Vector2i(
		floori(float(center_twice.x - rotated_size.x) * 0.5),
		floori(float(center_twice.y - rotated_size.y) * 0.5)
	)
	rotated_position = _clamp_rect_position_partial(rotated_position, rotated_size)
	_set_floating_selection(rotated_image, Rect2i(rotated_position, rotated_size), rotated_mask, previous_image)
	stroke_committed.emit(previous_image)
	_floating_history_recorded = true
	selection_committed.emit(_selection_rect)
	_refresh_texture()
	return true


func nudge_selection(delta: Vector2i, begin_sequence := true, end_sequence := true) -> bool:
	if not has_active_selection() or delta == Vector2i.ZERO:
		return false
	if begin_sequence or not _selection_nudge_previous_image:
		_selection_nudge_previous_image = get_image_copy()
	if not _has_floating_selection:
		var selected_image := _copy_selected_image()
		var selected_mask := _selection_mask.duplicate() if _selection_mask else null
		_clear_selected_pixels()
		_set_floating_selection(selected_image, _clip_pixel_rect(_selection_rect), selected_mask, _selection_nudge_previous_image)
	var next_position := _floating_rect.position + delta
	if _can_snap_to_grid():
		next_position = _snap_image_pixel(next_position)
	next_position = _clamp_rect_position_partial(next_position, _floating_rect.size)
	if next_position == _floating_rect.position:
		if end_sequence:
			_selection_nudge_previous_image = null
		return false
	_floating_rect.position = next_position
	_selection_rect = _floating_rect
	selection_committed.emit(_selection_rect)
	queue_redraw()
	if end_sequence:
		stroke_committed.emit(_selection_nudge_previous_image)
		_floating_history_recorded = true
		_selection_nudge_previous_image = null
	return true


func finish_selection_nudge_sequence() -> void:
	if _selection_nudge_previous_image:
		stroke_committed.emit(_selection_nudge_previous_image)
		_floating_history_recorded = true
		_selection_nudge_previous_image = null


func commit_active_selection_transform() -> bool:
	if _is_transforming_selection:
		_commit_selection_transform()
		return true
	if _has_floating_selection:
		_commit_floating_selection()
		return true
	return false


func get_tile_preview_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var center := _get_image_rect()
	for tile_y in range(-1, 2):
		for tile_x in range(-1, 2):
			rects.push_back(Rect2(
				center.position + Vector2(tile_x * center.size.x, tile_y * center.size.y),
				center.size
			))
	return rects


func flip_selection_horizontal() -> bool:
	return _flip_selection(true)


func flip_selection_vertical() -> bool:
	return _flip_selection(false)


func delete_active_selection() -> bool:
	if _has_floating_selection:
		var restore_image := _floating_cancel_image
		_clear_floating_selection()
		if restore_image:
			_image = restore_image.duplicate()
			_texture = ImageTexture.create_from_image(_image)
			_clear_selection()
			selection_cleared.emit()
			image_changed.emit(get_image_copy())
			queue_redraw()
		return true
	if not _has_selection:
		return false

	var previous_image := get_image_copy()
	_clear_selected_pixels()
	_refresh_texture()
	stroke_committed.emit(previous_image)
	return true


func cancel_active_selection_or_preview() -> bool:
	if _is_shape_previewing:
		_is_shape_previewing = false
		_set_canvas_mouse_hidden(false)
		queue_redraw()
		return true
	if _is_selecting or _is_lasso_selecting:
		_clear_selection()
		selection_cleared.emit()
		queue_redraw()
		return true
	if _is_transforming_selection:
		_cancel_selection_transform()
		return true
	if _is_drawing:
		_cancel_stroke()
		return true
	if _has_floating_selection:
		var restore_image := _floating_cancel_image
		_clear_floating_selection()
		if restore_image:
			_image = restore_image.duplicate()
			_texture = ImageTexture.create_from_image(_image)
			_clear_selection()
			selection_cleared.emit()
			image_changed.emit(get_image_copy())
			queue_redraw()
		return true
	if _has_selection:
		_clear_selection()
		selection_cleared.emit()
		queue_redraw()
		return true
	if _has_preview:
		_has_preview = false
		queue_redraw()
		return true
	return false


func zoom_in() -> void:
	set_zoom(zoom_multiplier * ZOOM_STEP)


func zoom_out() -> void:
	set_zoom(zoom_multiplier / ZOOM_STEP)


func reset_view() -> void:
	zoom_multiplier = 1.0
	_pan_offset = Vector2.ZERO
	queue_redraw()


func set_zoom(value: float) -> void:
	_zoom_at_position(value, _get_drawable_viewport_size() * 0.5)


func get_zoom_percent() -> int:
	var fit_scale := _get_fit_scale_for_viewport(_get_drawable_viewport_size())
	if fit_scale <= 0.0:
		return roundi(zoom_multiplier * 100.0)
	return roundi(fit_scale * zoom_multiplier * 100.0)


func get_max_zoom() -> float:
	var viewport_size := _get_drawable_viewport_size()
	var fit_scale := _get_fit_scale_for_viewport(viewport_size)
	if fit_scale <= 0.0:
		return MAX_ZOOM_SAFETY_CEILING
	return clampf(
		_get_max_pixel_scale(viewport_size) / fit_scale,
		MIN_ZOOM,
		MAX_ZOOM_SAFETY_CEILING
	)


func get_max_zoom_percent() -> int:
	var viewport_size := _get_drawable_viewport_size()
	var fit_scale := _get_fit_scale_for_viewport(viewport_size)
	if fit_scale <= 0.0:
		return roundi(MAX_ZOOM_SAFETY_CEILING * 100.0)
	return roundi(fit_scale * get_max_zoom() * 100.0)


func can_zoom_in() -> bool:
	var maximum_zoom := get_max_zoom()
	return zoom_multiplier < maximum_zoom and not is_equal_approx(zoom_multiplier, maximum_zoom)


func can_zoom_out() -> bool:
	return zoom_multiplier > MIN_ZOOM and not is_equal_approx(zoom_multiplier, MIN_ZOOM)


# Rendering entry points and canvas overlays.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), CANVAS_AREA_BACKGROUND_COLOR, true)
	_image_rect = _get_image_rect()
	_draw_tile_preview()
	_draw_checkerboard(_image_rect)
	_draw_image_texture(_image_rect)
	_draw_shape_preview_image()
	if show_grid:
		_draw_pixel_grid(_image_rect)
	if uv_overlay_visible:
		_draw_uv_overlay(_image_rect)
	_draw_canvas_outline(_image_rect)
	_draw_floating_selection()
	_draw_selection_transform_preview()
	_draw_selection()
	_draw_crop_preview()
	_draw_stroke_preview()
	_draw_external_hover_preview()


func _draw_checkerboard(canvas_rect: Rect2, clip_rect := Rect2()) -> void:
	var visible_rect := canvas_rect.intersection(Rect2(Vector2.ZERO, size))
	if clip_rect.has_area():
		visible_rect = visible_rect.intersection(clip_rect)
	if visible_rect.size.x <= 0.0 or visible_rect.size.y <= 0.0:
		return

	var start_x := floori((visible_rect.position.x - canvas_rect.position.x) / float(CHECKER_SIZE))
	var start_y := floori((visible_rect.position.y - canvas_rect.position.y) / float(CHECKER_SIZE))
	var end_x := ceili((visible_rect.end.x - canvas_rect.position.x) / float(CHECKER_SIZE))
	var end_y := ceili((visible_rect.end.y - canvas_rect.position.y) / float(CHECKER_SIZE))
	for y in range(start_y, end_y):
		for x in range(start_x, end_x):
			var color := checker_color_light if (x + y) % 2 == 0 else checker_color_dark
			var tile_rect := Rect2(
				canvas_rect.position + Vector2(x * CHECKER_SIZE, y * CHECKER_SIZE),
				Vector2(CHECKER_SIZE, CHECKER_SIZE)
			)
			draw_rect(tile_rect.intersection(visible_rect), color, true)


func _draw_tile_preview() -> void:
	if not tile_preview_enabled or _image_rect.size.x <= 0.0 or _image_rect.size.y <= 0.0:
		return
	for tile_y in range(-1, 2):
		for tile_x in range(-1, 2):
			if tile_x == 0 and tile_y == 0:
				continue
			var tile_rect := Rect2(
				_image_rect.position + Vector2(tile_x * _image_rect.size.x, tile_y * _image_rect.size.y),
				_image_rect.size
			)
			var clipped := tile_rect.intersection(_get_work_rect())
			if not clipped.has_area():
				continue
			_draw_checkerboard(tile_rect, _get_work_rect())
			var source_position := Vector2(
				(clipped.position.x - tile_rect.position.x) / tile_rect.size.x * float(_image.get_width()),
				(clipped.position.y - tile_rect.position.y) / tile_rect.size.y * float(_image.get_height())
			)
			var source_size := Vector2(
				clipped.size.x / tile_rect.size.x * float(_image.get_width()),
				clipped.size.y / tile_rect.size.y * float(_image.get_height())
			)
			draw_texture_rect_region(_texture, clipped, Rect2(source_position, source_size), Color(1, 1, 1, 0.72))
			draw_rect(tile_rect, Color(0.08, 0.08, 0.08, 0.8), false, 1.0)


func _draw_image_texture(canvas_rect: Rect2) -> void:
	var visible_rect := canvas_rect.intersection(_get_work_rect())
	if visible_rect.size.x <= 0.0 or visible_rect.size.y <= 0.0:
		return

	var src_position := Vector2(
		(visible_rect.position.x - canvas_rect.position.x) / canvas_rect.size.x * float(_image.get_width()),
		(visible_rect.position.y - canvas_rect.position.y) / canvas_rect.size.y * float(_image.get_height())
	)
	var src_size := Vector2(
		visible_rect.size.x / canvas_rect.size.x * float(_image.get_width()),
		visible_rect.size.y / canvas_rect.size.y * float(_image.get_height())
	)
	draw_texture_rect_region(_texture, visible_rect, Rect2(src_position, src_size))


func _draw_uv_overlay(canvas_rect: Rect2) -> void:
	var visible_rect := canvas_rect.intersection(_get_work_rect())
	if visible_rect.size.x <= 0.0 or visible_rect.size.y <= 0.0:
		return
	var detail_level := 0
	if _uv_overlay_edges.size() > 5000:
		detail_level = 1
	if _uv_overlay_edges.size() > 25000:
		detail_level = 2
	if (
		_uv_overlay_geometry_dirty
		or canvas_rect != _uv_overlay_cached_canvas_rect
		or visible_rect != _uv_overlay_cached_visible_rect
		or detail_level != _uv_overlay_cached_detail_level
	):
		_rebuild_uv_overlay_draw_cache(canvas_rect, visible_rect, detail_level)
	var edge_color := Color(1.0, 0.95, 0.15, 0.92)
	var edge_shadow := Color(0.0, 0.0, 0.0, 0.75)
	if not _uv_overlay_cached_line_points.is_empty():
		if detail_level < 2:
			draw_multiline(_uv_overlay_cached_line_points, edge_shadow, 3.0, false)
		draw_multiline(_uv_overlay_cached_line_points, edge_color, 1.25 if detail_level == 0 else 1.0, false)
	if not _uv_overlay_cached_vertex_points.is_empty():
		draw_multiline(_uv_overlay_cached_vertex_points, Color(0.0, 0.0, 0.0, 0.75), 4.0, false)
		draw_multiline(_uv_overlay_cached_vertex_points, Color(0.25, 0.85, 1.0, 0.96), 2.0, false)


func _rebuild_uv_overlay_draw_cache(canvas_rect: Rect2, visible_rect: Rect2, detail_level: int) -> void:
	_uv_overlay_cached_canvas_rect = canvas_rect
	_uv_overlay_cached_visible_rect = visible_rect
	_uv_overlay_cached_detail_level = detail_level
	_uv_overlay_geometry_dirty = false
	_uv_overlay_cached_line_points = PackedVector2Array()
	_uv_overlay_cached_vertex_points = PackedVector2Array()
	if canvas_rect.size.x <= 0.0 or canvas_rect.size.y <= 0.0:
		return
	var visible_uv := Rect2(
		Vector2(
			(visible_rect.position.x - canvas_rect.position.x) / canvas_rect.size.x,
			(visible_rect.position.y - canvas_rect.position.y) / canvas_rect.size.y
		),
		Vector2(
			visible_rect.size.x / canvas_rect.size.x,
			visible_rect.size.y / canvas_rect.size.y
		)
	).grow(2.0 / maxf(1.0, minf(canvas_rect.size.x, canvas_rect.size.y)))
	for edge in _uv_overlay_edges:
		if not (edge is PackedVector2Array) or edge.size() < 2:
			continue
		var from_uv: Vector2 = edge[0]
		var to_uv: Vector2 = edge[1]
		var edge_bounds := Rect2(from_uv.min(to_uv), (to_uv - from_uv).abs())
		if not edge_bounds.grow(0.000001).intersects(visible_uv, true):
			continue
		_uv_overlay_cached_line_points.push_back(_uv_to_local(from_uv, canvas_rect))
		_uv_overlay_cached_line_points.push_back(_uv_to_local(to_uv, canvas_rect))
	if detail_level > 0:
		return
	for uv in _uv_overlay_vertices:
		if not visible_uv.has_point(uv):
			continue
		var point := _uv_to_local(uv, canvas_rect)
		_uv_overlay_cached_vertex_points.push_back(point - Vector2(2.0, 0.0))
		_uv_overlay_cached_vertex_points.push_back(point + Vector2(2.0, 0.0))
		_uv_overlay_cached_vertex_points.push_back(point - Vector2(0.0, 2.0))
		_uv_overlay_cached_vertex_points.push_back(point + Vector2(0.0, 2.0))


func _uv_to_local(uv: Vector2, canvas_rect: Rect2) -> Vector2:
	return canvas_rect.position + Vector2(uv.x * canvas_rect.size.x, uv.y * canvas_rect.size.y)


func _uv_to_image_pixel(uv: Vector2) -> Vector2i:
	return Vector2i(
		clampi(floori(clampf(uv.x, 0.0, 1.0) * float(_image.get_width())), 0, _image.get_width() - 1),
		clampi(floori(clampf(uv.y, 0.0, 1.0) * float(_image.get_height())), 0, _image.get_height() - 1)
	)


func _draw_stroke_preview() -> void:
	if not _has_preview or _is_drawing or _is_shape_previewing:
		return

	var display_scale := _get_display_scale()
	if display_scale <= 0.0:
		return

	var preview_pixel := _local_to_snapped_brush_pixel(_preview_position) if _is_stroke_tool() else _local_to_snapped_image_pixel(_preview_position)
	var preview_color := Color.WHITE if _is_eraser_tool() else brush_color
	if _is_eraser_tool():
		preview_color.a = brush_color.a
	if active_tool == ToolMode.FILL:
		var fill_color := preview_color
		fill_color.a *= 0.28
		var fill_preview_pixels: Array = []
		if fill_mode == FillMode.REPLACE_COLOR:
			fill_preview_pixels.push_back(preview_pixel)
		else:
			fill_preview_pixels = _get_mirrored_pixels(preview_pixel)
		for mirror_pixel: Vector2i in fill_preview_pixels:
			var fill_rect := _image_pixels_to_local_rect(Rect2i(mirror_pixel, Vector2i.ONE))
			draw_rect(fill_rect, fill_color, true)
			draw_rect(fill_rect, Color.WHITE, false, 1.5)
		return

	if active_tool == ToolMode.EYEDROPPER:
		var sample_rect := _image_pixels_to_local_rect(Rect2i(preview_pixel, Vector2i.ONE))
		var sample_color := _image.get_pixel(preview_pixel.x, preview_pixel.y)
		sample_color.a = maxf(0.35, sample_color.a)
		draw_rect(sample_rect, sample_color, true)
		draw_rect(sample_rect, Color.WHITE, false, 1.5)
		return

	if not _uses_brush_hover_preview():
		return

	var fill_color := preview_color
	fill_color.a *= 0.22
	for mirror_pixel in _get_mirrored_pixels(preview_pixel):
		_draw_brush_coverage_preview(mirror_pixel, fill_color)


func _draw_external_hover_preview() -> void:
	if not _external_hover_visible or _is_drawing or _is_shape_previewing:
		return
	var display_scale := _get_display_scale()
	if display_scale <= 0.0:
		return
	_draw_external_hover_island_outline(display_scale)
	var preview_pixel := _uv_to_image_pixel(_external_hover_uv)
	var preview_color := Color.WHITE if _is_eraser_tool() else brush_color
	if _is_eraser_tool():
		preview_color.a = brush_color.a
	preview_color.a *= 0.18
	_draw_brush_coverage_preview(preview_pixel, preview_color)


func _draw_external_hover_island_outline(display_scale: float) -> void:
	var edges := {}
	for triangle in _external_hover_triangles:
		if triangle.size() < 3:
			continue
		_add_external_hover_edge(edges, triangle[0], triangle[1])
		_add_external_hover_edge(edges, triangle[1], triangle[2])
		_add_external_hover_edge(edges, triangle[2], triangle[0])
	for edge_value in edges.values():
		var edge: Array = edge_value
		if int(edge[2]) != 1:
			continue
		var from_uv: Vector2 = edge[0]
		var to_uv: Vector2 = edge[1]
		var from_point := _image_rect.position + Vector2(from_uv.x * _image_rect.size.x, from_uv.y * _image_rect.size.y)
		var to_point := _image_rect.position + Vector2(to_uv.x * _image_rect.size.x, to_uv.y * _image_rect.size.y)
		draw_line(from_point, to_point, Color(1.0, 0.72, 0.18, 0.95), maxf(1.0, display_scale * 0.08), true)


func _add_external_hover_edge(edges: Dictionary, from_uv: Vector2, to_uv: Vector2) -> void:
	var from_key := _external_hover_uv_key(from_uv)
	var to_key := _external_hover_uv_key(to_uv)
	var edge_key := from_key + ">" + to_key if from_key < to_key else to_key + ">" + from_key
	if edges.has(edge_key):
		var edge: Array = edges[edge_key]
		edge[2] = int(edge[2]) + 1
	else:
		edges[edge_key] = [from_uv, to_uv, 1]


func _external_hover_uv_key(uv: Vector2) -> String:
	return "%d,%d" % [roundi(uv.x * 1000000.0), roundi(uv.y * 1000000.0)]


func _draw_brush_coverage_preview(center: Vector2i, color: Color) -> void:
	var radius := maxf(0.5, float(brush_size) * 0.5)
	var pixel_radius := int(ceil(radius + 1.0))
	for y in range(center.y - pixel_radius, center.y + pixel_radius + 1):
		for x in range(center.x - pixel_radius, center.x + pixel_radius + 1):
			var pixel := Vector2i(x, y)
			if not _can_paint_pixel(pixel):
				continue
			var coverage := _get_brush_pixel_coverage(center, pixel, radius)
			if coverage <= 0.0:
				continue
			var pixel_color := color
			pixel_color.a *= coverage
			draw_rect(_image_pixels_to_local_rect(Rect2i(pixel, Vector2i.ONE)), pixel_color, true)
	var outline := _image_pixels_to_local_rect(_get_brush_rect(center)).intersection(_image_rect)
	if not outline.has_area():
		return
	var outline_color := Color(1, 1, 1, 0.9)
	if brush_head == BrushHead.CIRCLE:
		var local_center := _image_pixel_center_to_local(center)
		var local_radius := maxf(1.0, float(brush_size) * _get_display_scale() * 0.5)
		draw_arc(local_center, local_radius, 0.0, TAU, 48, outline_color, 1.25, true)
	else:
		draw_rect(outline, outline_color, false, 1.25)


# Input routing and high-level tool dispatch.
func _gui_input(event: InputEvent) -> void:
	var previous_shift_constrain := _shift_constrain
	if event is InputEventKey and event.keycode == KEY_SHIFT:
		_shift_constrain = event.pressed
	elif event is InputEventWithModifiers:
		_shift_constrain = event.shift_pressed
	if previous_shift_constrain != _shift_constrain and _is_shape_previewing:
		_shape_end_pixel = _get_constrained_shape_end_pixel(_shape_pointer_pixel)
		_refresh_shape_preview_image()
		queue_redraw()
	if event is InputEventKey and event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
		if has_active_selection():
			if event.pressed:
				var direction := Vector2i.ZERO
				match event.keycode:
					KEY_LEFT:
						direction = Vector2i.LEFT
					KEY_RIGHT:
						direction = Vector2i.RIGHT
					KEY_UP:
						direction = Vector2i.UP
					KEY_DOWN:
						direction = Vector2i.DOWN
				var nudge_step := grid_size if _can_snap_to_grid() else 1
				nudge_selection(direction * nudge_step * (10 if event.shift_pressed else 1), not event.echo, false)
			else:
				finish_selection_nudge_sequence()
			accept_event()
			return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_at_position(zoom_multiplier * ZOOM_STEP, event.position)
			accept_event()
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_at_position(zoom_multiplier / ZOOM_STEP, event.position)
			accept_event()
			return
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			_is_panning = event.pressed
			_last_pan_position = event.position
			_has_preview = false
			mouse_default_cursor_shape = Control.CURSOR_DRAG if _is_panning or active_tool == ToolMode.PAN else _get_base_cursor_shape()
			accept_event()
			return
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		if not event.pressed:
			if _is_panning:
				_is_panning = false
				accept_event()
				return
			if _is_shape_previewing:
				_commit_shape_preview(event.position)
				accept_event()
				return
			if _is_selecting:
				_commit_selection_preview(event.position)
				accept_event()
				return
			if _is_lasso_selecting:
				_commit_lasso_selection(event.position)
				accept_event()
				return
			if _is_transforming_selection:
				_commit_selection_transform()
				accept_event()
				return
			_end_stroke()
			accept_event()
			return
		if active_tool == ToolMode.PAN:
			_is_panning = true
			_last_pan_position = event.position
			_has_preview = false
			accept_event()
			return
		if _is_selection_tool() and _has_selection:
			if _rotate_handle_has_point(event.position):
				_begin_selection_transform(event.position, SelectionTransformMode.ROTATE)
				accept_event()
				return
			var scale_handle := _get_scale_handle_at_position(event.position)
			if scale_handle != -1:
				_begin_selection_transform(event.position, SelectionTransformMode.SCALE, scale_handle)
				accept_event()
				return
			if _image_pixels_to_local_rect(_clip_pixel_rect(_selection_rect)).has_point(event.position):
				_begin_selection_transform(event.position, SelectionTransformMode.MOVE)
				accept_event()
				return
		if _image_rect.has_point(event.position):
			if active_tool == ToolMode.FILL:
				_fill_at_position(event.position)
			elif active_tool == ToolMode.EYEDROPPER:
				_pick_color_at_position(event.position)
			elif active_tool == ToolMode.SELECT:
				_begin_selection_preview(event.position)
			elif active_tool == ToolMode.LASSO_SELECT:
				_begin_lasso_selection(event.position)
			elif _is_shape_tool():
				_begin_shape_preview(event.position)
			elif _is_stroke_tool():
				_begin_stroke(event.position)
			accept_event()
	elif event is InputEventMagnifyGesture:
		_zoom_at_position(zoom_multiplier * event.factor, event.position)
		accept_event()
	elif event is InputEventMouseMotion:
		if _is_panning:
			_pan_offset += event.position - _last_pan_position
			_last_pan_position = event.position
			_clamp_pan_offset()
			queue_redraw()
			accept_event()
			return
		_update_preview(event.position)
		_emit_hover_uv(event.position)
		if _is_shape_previewing:
			_update_shape_preview(event.position)
		if _is_selecting:
			_update_selection_preview(event.position)
		if _is_lasso_selecting:
			_update_lasso_selection(event.position)
		if _is_transforming_selection:
			_update_selection_transform(event.position)
		if _is_drawing:
			_continue_stroke(event.position)
		accept_event()


func _emit_hover_uv(local_position: Vector2) -> void:
	if _image_rect.has_point(local_position):
		var normalized := Vector2(
			clampf((local_position.x - _image_rect.position.x) / _image_rect.size.x, 0.0, 1.0),
			clampf((local_position.y - _image_rect.position.y) / _image_rect.size.y, 0.0, 1.0)
		)
		hover_uv_changed.emit(normalized, true)
	else:
		hover_uv_changed.emit(Vector2.ZERO, false)


func _emit_hover_at_mouse() -> void:
	_emit_hover_uv(get_local_mouse_position())


func _begin_stroke(local_position: Vector2) -> void:
	_is_drawing = true
	_stroke_start_image = get_image_copy()
	_begin_stroke_coverage()
	_last_pixel = _local_to_snapped_brush_pixel(local_position)
	_stamp(_last_pixel)
	_refresh_texture()


func _continue_stroke(local_position: Vector2) -> void:
	if not _image_rect.has_point(local_position):
		_end_stroke()
		return
	var pixel := _local_to_snapped_brush_pixel(local_position)
	_draw_line(_last_pixel, pixel)
	_last_pixel = pixel
	_refresh_texture()


func _end_stroke() -> void:
	if not _is_drawing:
		return
	_is_drawing = false
	if _stroke_start_image:
		if not _images_equal(_stroke_start_image, _image):
			stroke_committed.emit(_stroke_start_image)
		_stroke_start_image = null
	_stroke_coverage = PackedFloat32Array()
	queue_redraw()


func _cancel_stroke() -> void:
	if not _is_drawing:
		return
	_is_drawing = false
	if _stroke_start_image:
		_image = _stroke_start_image.duplicate()
		_texture = ImageTexture.create_from_image(_image)
		_stroke_start_image = null
		_stroke_coverage = PackedFloat32Array()
		image_changed.emit(get_image_copy())
	queue_redraw()


func _begin_shape_preview(local_position: Vector2) -> void:
	_is_shape_previewing = true
	_shape_start_pixel = _local_to_snapped_image_pixel(local_position)
	_shape_pointer_pixel = _shape_start_pixel
	_shape_end_pixel = _shape_start_pixel
	_has_preview = false
	_set_canvas_mouse_hidden(true)
	_refresh_shape_preview_image()
	queue_redraw()


func _update_shape_preview(local_position: Vector2) -> void:
	_shape_pointer_pixel = _local_to_snapped_image_pixel(local_position)
	_shape_end_pixel = _get_constrained_shape_end_pixel(_shape_pointer_pixel)
	_refresh_shape_preview_image()
	queue_redraw()


func _commit_shape_preview(local_position: Vector2) -> void:
	if not _is_shape_previewing:
		return

	_shape_pointer_pixel = _local_to_snapped_image_pixel(local_position)
	_shape_end_pixel = _get_constrained_shape_end_pixel(_shape_pointer_pixel)
	_commit_current_shape()


func _commit_current_shape() -> void:
	_is_shape_previewing = false
	_clear_shape_preview_image()
	_set_canvas_mouse_hidden(false)
	var previous_image: Image = get_image_copy()
	_is_drawing = true
	_stroke_start_image = previous_image
	_begin_stroke_coverage()
	if not _raster_active_shape():
		_is_drawing = false
		_stroke_start_image = null
		_stroke_coverage = PackedFloat32Array()
		queue_redraw()
		return

	_is_drawing = false
	_stroke_start_image = null
	_stroke_coverage = PackedFloat32Array()
	if not _images_equal(previous_image, _image):
		_refresh_texture()
		stroke_committed.emit(previous_image)
	else:
		queue_redraw()


func _raster_active_shape() -> bool:
	var endpoints := _get_active_shape_endpoints()
	var from_pixel: Vector2i = endpoints[0]
	var to_pixel: Vector2i = endpoints[1]
	_begin_mirror_raster_scope()
	if active_tool == ToolMode.LINE:
		_draw_line(from_pixel, to_pixel)
		_end_mirror_raster_scope()
		return true
	if active_tool == ToolMode.RECTANGLE:
		if shape_fill_enabled:
			_draw_filled_rectangle(from_pixel, to_pixel)
		else:
			_draw_rectangle_outline(from_pixel, to_pixel)
		_end_mirror_raster_scope()
		return true
	if active_tool == ToolMode.ELLIPSE:
		if shape_fill_enabled:
			_draw_filled_ellipse(from_pixel, to_pixel)
		else:
			_draw_ellipse_outline(from_pixel, to_pixel)
		_end_mirror_raster_scope()
		return true
	_end_mirror_raster_scope()
	return false


func _refresh_shape_preview_image() -> void:
	if not _is_shape_previewing or _is_shape_preview_rasterizing:
		return

	_clear_shape_preview_image()
	var previous_is_drawing := _is_drawing
	var previous_stroke_start_image := _stroke_start_image
	var previous_stroke_coverage := _stroke_coverage
	_is_shape_preview_rasterizing = true
	_shape_preview_original_pixels.clear()
	_is_drawing = true
	_stroke_start_image = null
	_begin_stroke_coverage()
	var valid_shape := _raster_active_shape()
	_is_drawing = previous_is_drawing
	_stroke_start_image = previous_stroke_start_image
	_stroke_coverage = previous_stroke_coverage
	_is_shape_preview_rasterizing = false

	if valid_shape and not _shape_preview_original_pixels.is_empty():
		var width := _image.get_width()
		var left := width
		var top := _image.get_height()
		var right := -1
		var bottom := -1
		for key in _shape_preview_original_pixels:
			var index := int(key)
			var x := index % width
			var y := index / width
			left = mini(left, x)
			top = mini(top, y)
			right = maxi(right, x)
			bottom = maxi(bottom, y)
		_shape_preview_rect = Rect2i(Vector2i(left, top), Vector2i(right - left + 1, bottom - top + 1))
		_shape_preview_image = _image.get_region(_shape_preview_rect)

	for key in _shape_preview_original_pixels:
		var index := int(key)
		_image.set_pixel(index % _image.get_width(), index / _image.get_width(), _shape_preview_original_pixels[key])
	_shape_preview_original_pixels.clear()

	if _shape_preview_image and not _shape_preview_image.is_empty():
		_shape_preview_texture = ImageTexture.create_from_image(_shape_preview_image)


func _clear_shape_preview_image() -> void:
	_shape_preview_image = null
	_shape_preview_texture = null
	_shape_preview_rect = Rect2i()


func _draw_shape_preview_image() -> void:
	if not _is_shape_previewing or not _shape_preview_texture or not _shape_preview_rect.has_area():
		return
	var local_rect := _image_pixels_to_local_rect(_shape_preview_rect)
	var visible_rect := local_rect.intersection(_get_work_rect())
	if not visible_rect.has_area():
		return
	_draw_checkerboard(_image_rect, visible_rect)
	var source_position := Vector2(
		(visible_rect.position.x - local_rect.position.x) / local_rect.size.x * float(_shape_preview_rect.size.x),
		(visible_rect.position.y - local_rect.position.y) / local_rect.size.y * float(_shape_preview_rect.size.y)
	)
	var source_size := Vector2(
		visible_rect.size.x / local_rect.size.x * float(_shape_preview_rect.size.x),
		visible_rect.size.y / local_rect.size.y * float(_shape_preview_rect.size.y)
	)
	draw_texture_rect_region(_shape_preview_texture, visible_rect, Rect2(source_position, source_size))


func _fill_at_position(local_position: Vector2) -> void:
	if not _image_rect.has_point(local_position):
		return

	var fill_pixel := _local_to_image_pixel(local_position)
	var previous_image := get_image_copy()
	if _flood_fill(fill_pixel, brush_color):
		_refresh_texture()
		stroke_committed.emit(previous_image)


func _pick_color_at_position(local_position: Vector2) -> void:
	if not _image_rect.has_point(local_position):
		return

	var sample_pixel := _local_to_image_pixel(local_position)
	color_picked.emit(_image.get_pixel(sample_pixel.x, sample_pixel.y), sample_pixel)


# Selection creation, transforms, floating selections, and clipboard image edits.
func _begin_selection_preview(local_position: Vector2) -> void:
	if _has_floating_selection:
		_commit_floating_selection()
	_is_selecting = true
	_selection_start_pixel = _local_to_snapped_image_pixel(local_position)
	_selection_end_pixel = _selection_start_pixel
	_has_selection = false
	_selection_mask = null
	_has_preview = false
	queue_redraw()


func _update_selection_preview(local_position: Vector2) -> void:
	_selection_end_pixel = _get_constrained_selection_end_pixel(_local_to_snapped_image_pixel(local_position))
	queue_redraw()


func _commit_selection_preview(_local_position: Vector2) -> void:
	if not _is_selecting:
		return

	_selection_rect = _get_pixel_rect(_selection_start_pixel, _selection_end_pixel)
	_has_selection = true
	_selection_mask = null
	_is_selecting = false
	selection_committed.emit(_selection_rect)
	queue_redraw()


func _begin_lasso_selection(local_position: Vector2) -> void:
	if _has_floating_selection:
		_commit_floating_selection()
	_is_lasso_selecting = true
	_lasso_points.clear()
	var start_pixel := _local_to_snapped_image_pixel(local_position)
	_lasso_points.push_back(start_pixel)
	_has_selection = false
	_selection_mask = null
	_has_preview = false
	queue_redraw()


func _update_lasso_selection(local_position: Vector2) -> void:
	var pixel := _local_to_snapped_image_pixel(local_position)
	if _lasso_points.is_empty() or _lasso_points.back() != pixel:
		_lasso_points.push_back(pixel)
	queue_redraw()


func _commit_lasso_selection(local_position: Vector2) -> void:
	if not _is_lasso_selecting:
		return

	_update_lasso_selection(local_position)
	_is_lasso_selecting = false
	if _lasso_points.size() < 3:
		_clear_selection()
		selection_cleared.emit()
		queue_redraw()
		return

	_selection_rect = _get_lasso_bounds(_lasso_points)
	_selection_mask = _create_lasso_mask(_lasso_points, _selection_rect)
	_has_selection = _selection_mask != null and not _selection_mask.is_empty()
	if _has_selection:
		selection_committed.emit(_selection_rect)
	else:
		selection_cleared.emit()
	queue_redraw()


func _begin_selection_transform(local_position: Vector2, mode: int, scale_handle := -1) -> void:
	if not _has_selection:
		return

	var clipped_rect := _floating_rect if _has_floating_selection else _clip_pixel_rect(_selection_rect)
	if clipped_rect.size.x <= 0 or clipped_rect.size.y <= 0:
		return

	_is_transforming_selection = true
	_selection_transform_mode = mode
	_selection_scale_handle = scale_handle
	_selection_transform_start_pixel = _local_to_image_pixel(local_position)
	_selection_transform_start_rect = _selection_rect
	_selection_transform_previous_image = get_image_copy()
	_selection_preview_image = _get_rotated_floating_image() if _has_floating_selection else _copy_selected_image()
	_selection_preview_texture = ImageTexture.create_from_image(_selection_preview_image)
	_selection_preview_rect = clipped_rect
	_selection_preview_angle = 0.0
	_selection_transform_start_angle = _floating_angle if _has_floating_selection else 0.0
	_selection_transform_start_mouse_angle = _get_angle_from_selection_center(local_position)
	_selection_transform_flip_h = false
	_selection_transform_flip_v = false
	_selection_transform_started_floating = _has_floating_selection
	if not _selection_transform_started_floating:
		_clear_selected_pixels()
	else:
		_clear_floating_selection(false)
	_has_selection = false
	_selection_mask = null
	_has_preview = false
	_refresh_texture()


func _update_selection_transform(local_position: Vector2) -> void:
	if not _is_transforming_selection:
		return

	var pixel := _local_to_image_pixel(local_position)
	if _selection_transform_mode == SelectionTransformMode.MOVE:
		var delta := pixel - _selection_transform_start_pixel
		var next_position := _selection_transform_start_rect.position + delta
		if _can_snap_to_grid():
			next_position = _snap_image_pixel(next_position)
		_selection_preview_rect.position = _clamp_rect_position_partial(
			next_position,
			_selection_preview_rect.size
		)
	elif _selection_transform_mode == SelectionTransformMode.SCALE:
		if _can_snap_to_grid():
			pixel = _snap_image_pixel(pixel)
		_selection_preview_rect = _get_scaled_selection_rect(pixel, _shift_constrain)
		_selection_preview_texture = ImageTexture.create_from_image(_get_transformed_preview_image())
	elif _selection_transform_mode == SelectionTransformMode.ROTATE:
		_selection_preview_angle = _selection_transform_start_angle + _get_angle_from_selection_center(local_position) - _selection_transform_start_mouse_angle
	queue_redraw()


func _commit_selection_transform() -> void:
	if not _is_transforming_selection:
		return

	if _selection_preview_image and _selection_preview_rect.size.x > 0 and _selection_preview_rect.size.y > 0:
		var transformed_image := _get_transformed_preview_image()
		if _selection_transform_mode == SelectionTransformMode.ROTATE:
			var rotated_size := Vector2i(transformed_image.get_width(), transformed_image.get_height())
			var original_center := Vector2(_selection_preview_rect.position) + Vector2(_selection_preview_rect.size) * 0.5
			var rotated_position := Vector2i(roundi(original_center.x - float(rotated_size.x) * 0.5), roundi(original_center.y - float(rotated_size.y) * 0.5))
			_selection_preview_rect = Rect2i(_clamp_rect_position(rotated_position, rotated_size), rotated_size)
		if _selection_transform_started_floating:
			_set_floating_selection(transformed_image, _selection_preview_rect, _floating_mask, _selection_transform_previous_image)
			_selection_rect = _floating_rect
			_has_selection = true
		else:
			_set_floating_selection(transformed_image, _selection_preview_rect, _selection_mask, _selection_transform_previous_image)
			_selection_rect = _floating_rect
			_has_selection = true

	_is_transforming_selection = false
	_selection_transform_mode = SelectionTransformMode.NONE
	_selection_scale_handle = -1
	_selection_preview_image = null
	_selection_preview_texture = null
	_selection_transform_started_floating = false
	_refresh_texture()
	if _selection_transform_previous_image:
		stroke_committed.emit(_selection_transform_previous_image)
		_selection_transform_previous_image = null
	if _has_selection:
		selection_committed.emit(_selection_rect)


func _cancel_selection_transform() -> void:
	if not _is_transforming_selection:
		return

	if _selection_transform_started_floating and _selection_preview_image:
		_set_floating_selection(_selection_preview_image, _selection_transform_start_rect)
		_selection_rect = _floating_rect
		_has_selection = true
	else:
		if _selection_transform_previous_image:
			_image = _selection_transform_previous_image.duplicate()
			_texture = ImageTexture.create_from_image(_image)
			_selection_rect = _selection_transform_start_rect
			_has_selection = true
			image_changed.emit(get_image_copy())

	_is_transforming_selection = false
	_selection_transform_mode = SelectionTransformMode.NONE
	_selection_scale_handle = -1
	_selection_preview_image = null
	_selection_preview_texture = null
	_selection_preview_rect = Rect2i()
	_selection_preview_angle = 0.0
	_selection_transform_previous_image = null
	_selection_transform_started_floating = false
	selection_committed.emit(_selection_rect)
	queue_redraw()


func _rotate_selection_clockwise() -> void:
	_rotate_selection_quarter_turn(true)


func _rotate_selection_quarter_turn(clockwise: bool) -> bool:
	if not has_active_selection():
		return false
	var previous_image := get_image_copy()
	var source_rect := _floating_rect if _has_floating_selection else _clip_pixel_rect(_selection_rect)
	var source_image := _floating_image.duplicate() if _has_floating_selection else _copy_selected_image()
	var source_mask := _floating_mask.duplicate() if _floating_mask else (_selection_mask.duplicate() if _selection_mask else null)
	if not source_image or source_image.is_empty() or source_rect.size.x <= 0 or source_rect.size.y <= 0:
		return false
	if not _has_floating_selection:
		_clear_selected_pixels()
	var rotated_image := _rotate_image_quarter_turn(source_image, clockwise)
	var rotated_mask := _rotate_image_quarter_turn(source_mask, clockwise) if source_mask else null
	var center_twice := source_rect.position * 2 + source_rect.size
	var rotated_size := Vector2i(rotated_image.get_width(), rotated_image.get_height())
	var rotated_position := Vector2i(
		floori(float(center_twice.x - rotated_size.x) * 0.5),
		floori(float(center_twice.y - rotated_size.y) * 0.5)
	)
	rotated_position = _clamp_rect_position_partial(rotated_position, rotated_size)
	_set_floating_selection(rotated_image, Rect2i(rotated_position, rotated_size), rotated_mask, previous_image)
	stroke_committed.emit(previous_image)
	_floating_history_recorded = true
	selection_committed.emit(_selection_rect)
	_refresh_texture()
	return true


func _rotate_image_quarter_turn(source_image: Image, clockwise: bool) -> Image:
	var result := Image.create_empty(source_image.get_height(), source_image.get_width(), false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	for y in range(source_image.get_height()):
		for x in range(source_image.get_width()):
			if clockwise:
				result.set_pixel(source_image.get_height() - 1 - y, x, source_image.get_pixel(x, y))
			else:
				result.set_pixel(y, source_image.get_width() - 1 - x, source_image.get_pixel(x, y))
	return result


# Fill, line, shape, and preview rasterization.
func _flood_fill(start: Vector2i, color: Color, apply_mirror := true) -> bool:
	var width: int = _image.get_width()
	var height: int = _image.get_height()
	if start.x < 0 or start.y < 0 or start.x >= width or start.y >= height:
		return false

	var target_color: Color = _image.get_pixel(start.x, start.y)
	if fill_mode == FillMode.GLOBAL or fill_mode == FillMode.REPLACE_COLOR:
		return _global_fill(target_color, color)

	var seeds: Array[Vector2i] = _get_mirrored_pixels(start)
	if not apply_mirror:
		seeds = []
		seeds.push_back(start)
	var source_image := _image.duplicate()
	var changed := false
	var visited := PackedByteArray()
	visited.resize(width * height)
	for seed in seeds:
		if _fill_pixel_visited(visited, width, seed.x, seed.y):
			continue
		var seed_target: Color = source_image.get_pixel(seed.x, seed.y)
		var stack: Array[Vector2i] = [seed]
		while not stack.is_empty():
			var pixel: Vector2i = stack.pop_back()
			if pixel.x < 0 or pixel.y < 0 or pixel.x >= width or pixel.y >= height:
				continue
			if _fill_pixel_visited(visited, width, pixel.x, pixel.y):
				continue
			if not _colors_match_with_tolerance(source_image.get_pixel(pixel.x, pixel.y), seed_target):
				continue

			var left: int = pixel.x
			while (
				left >= 0
				and not _fill_pixel_visited(visited, width, left, pixel.y)
				and _colors_match_with_tolerance(source_image.get_pixel(left, pixel.y), seed_target)
			):
				left -= 1
			left += 1

			var right: int = pixel.x
			while (
				right < width
				and not _fill_pixel_visited(visited, width, right, pixel.y)
				and _colors_match_with_tolerance(source_image.get_pixel(right, pixel.y), seed_target)
			):
				right += 1
			right -= 1

			var above_open: bool = false
			var below_open: bool = false
			for x in range(left, right + 1):
				_mark_fill_pixel_visited(visited, width, x, pixel.y)
				if _can_paint_pixel(Vector2i(x, pixel.y)):
					changed = _paint_pixel(x, pixel.y, color, 1.0) or changed
				if pixel.y > 0:
					var above_matches: bool = (
						not _fill_pixel_visited(visited, width, x, pixel.y - 1)
						and _colors_match_with_tolerance(source_image.get_pixel(x, pixel.y - 1), seed_target)
					)
					if above_matches and not above_open:
						stack.push_back(Vector2i(x, pixel.y - 1))
						above_open = true
					elif not above_matches:
						above_open = false
				if pixel.y < height - 1:
					var below_matches: bool = (
						not _fill_pixel_visited(visited, width, x, pixel.y + 1)
						and _colors_match_with_tolerance(source_image.get_pixel(x, pixel.y + 1), seed_target)
					)
					if below_matches and not below_open:
						stack.push_back(Vector2i(x, pixel.y + 1))
						below_open = true
					elif not below_matches:
						below_open = false

	return changed


func _global_fill(target_color: Color, color: Color) -> bool:
	var changed := false
	for y in range(_image.get_height()):
		for x in range(_image.get_width()):
			if _pixel_matches_fill_target(x, y, target_color) and _can_paint_pixel(Vector2i(x, y)):
				changed = _paint_pixel(x, y, color, 1.0) or changed
	return changed


func _draw_line(from_pixel: Vector2i, to_pixel: Vector2i) -> void:
	_draw_line_internal(from_pixel, to_pixel, true)


func _draw_line_unmirrored(from_pixel: Vector2i, to_pixel: Vector2i) -> void:
	_draw_line_internal(from_pixel, to_pixel, false)


func _draw_line_internal(from_pixel: Vector2i, to_pixel: Vector2i, apply_mirror: bool) -> void:
	var distance := from_pixel.distance_to(to_pixel)
	var steps := max(1, int(ceil(distance / max(1.0, float(brush_size) * 0.16))))
	for index in range(steps + 1):
		var weight := float(index) / float(steps)
		var pixel := Vector2(from_pixel).lerp(Vector2(to_pixel), weight)
		var stamp_pixel := Vector2i(roundi(pixel.x), roundi(pixel.y))
		if apply_mirror:
			_stamp(stamp_pixel)
		else:
			_stamp_unmirrored(stamp_pixel)


func _draw_uv_triangle_line(from_pixel: Vector2i, to_pixel: Vector2i, triangle_uvs: PackedVector2Array) -> void:
	var distance := from_pixel.distance_to(to_pixel)
	var steps := max(1, int(ceil(distance / max(1.0, float(brush_size) * 0.16))))
	for index in range(steps + 1):
		var weight := float(index) / float(steps)
		var pixel := Vector2(from_pixel).lerp(Vector2(to_pixel), weight)
		_stamp_uv_triangle(Vector2i(roundi(pixel.x), roundi(pixel.y)), triangle_uvs)


func _draw_uv_3d_line(from_pixel: Vector2i, to_pixel: Vector2i, triangle_uvs: PackedVector2Array) -> void:
	var distance := from_pixel.distance_to(to_pixel)
	var steps := max(1, int(ceil(distance / max(1.0, float(brush_size) * 0.16))))
	for index in range(steps + 1):
		var weight := float(index) / float(steps)
		var pixel := Vector2(from_pixel).lerp(Vector2(to_pixel), weight)
		_stamp_uv_3d(Vector2i(roundi(pixel.x), roundi(pixel.y)), triangle_uvs)


func _draw_rectangle_outline(from_pixel: Vector2i, to_pixel: Vector2i) -> void:
	var rect: Rect2i = _get_pixel_rect(from_pixel, to_pixel)
	var left: int = rect.position.x
	var top: int = rect.position.y
	var right: int = rect.position.x + rect.size.x - 1
	var bottom: int = rect.position.y + rect.size.y - 1
	_draw_line(Vector2i(left, top), Vector2i(right, top))
	_draw_line(Vector2i(right, top), Vector2i(right, bottom))
	_draw_line(Vector2i(right, bottom), Vector2i(left, bottom))
	_draw_line(Vector2i(left, bottom), Vector2i(left, top))


func _draw_filled_rectangle(from_pixel: Vector2i, to_pixel: Vector2i) -> void:
	var rect: Rect2i = _get_pixel_rect(from_pixel, to_pixel)
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			_paint_mirrored_pixel(x, y, brush_color, 1.0)


func _draw_ellipse_outline(from_pixel: Vector2i, to_pixel: Vector2i) -> void:
	var rect: Rect2i = _get_pixel_rect(from_pixel, to_pixel)
	if rect.size.x <= 1 or rect.size.y <= 1:
		_draw_line(from_pixel, to_pixel)
		return

	var center := Vector2(rect.position) + (Vector2(rect.size) - Vector2.ONE) * 0.5
	var radius := (Vector2(rect.size) - Vector2.ONE) * 0.5
	var steps: int = max(16, int(ceil(TAU * maxf(radius.x, radius.y) * 1.5)))
	for index in range(steps):
		var angle := TAU * float(index) / float(steps)
		var pixel := center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y)
		_stamp(Vector2i(roundi(pixel.x), roundi(pixel.y)))


func _draw_filled_ellipse(from_pixel: Vector2i, to_pixel: Vector2i) -> void:
	var rect: Rect2i = _get_pixel_rect(from_pixel, to_pixel)
	var center := Vector2(rect.position) + (Vector2(rect.size) - Vector2.ONE) * 0.5
	var radius := Vector2(rect.size) * 0.5
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			var normalized := Vector2(
				(float(x) - center.x) / radius.x,
				(float(y) - center.y) / radius.y
			)
			if normalized.length_squared() <= 1.0:
				_paint_mirrored_pixel(x, y, brush_color, 1.0)


func _draw_shape_preview() -> void:
	if not _is_shape_previewing:
		return
	var endpoints := _get_active_shape_endpoints()
	var from_pixel: Vector2i = endpoints[0]
	var to_pixel: Vector2i = endpoints[1]
	if active_tool == ToolMode.LINE:
		_draw_line_preview(from_pixel, to_pixel)
	elif active_tool == ToolMode.RECTANGLE:
		if shape_fill_enabled:
			_draw_filled_rectangle_preview(from_pixel, to_pixel)
		else:
			_draw_rectangle_outline_preview(from_pixel, to_pixel)
	elif active_tool == ToolMode.ELLIPSE:
		if shape_fill_enabled:
			_draw_filled_ellipse_preview(from_pixel, to_pixel)
		else:
			_draw_ellipse_outline_preview(from_pixel, to_pixel)
	_draw_shape_start_outline(_shape_start_pixel)


func _draw_line_preview(from_pixel: Vector2i, to_pixel: Vector2i) -> void:
	var display_scale: float = _get_display_scale()
	if display_scale <= 0.0:
		return

	var distance: float = from_pixel.distance_to(to_pixel)
	var steps: int = max(1, int(ceil(distance / max(1.0, float(brush_size) * 0.16))))
	var preview_color: Color = brush_color
	preview_color.a *= 0.45
	for index in range(steps + 1):
		var weight: float = float(index) / float(steps)
		var pixel: Vector2 = Vector2(from_pixel).lerp(Vector2(to_pixel), weight)
		var stamp_pixel: Vector2i = Vector2i(roundi(pixel.x), roundi(pixel.y))
		_draw_brush_preview_stamp(stamp_pixel, preview_color, false)


func _draw_brush_preview_stamp(stamp_pixel: Vector2i, preview_color: Color, draw_border: bool) -> void:
	var display_scale: float = _get_display_scale()
	if display_scale <= 0.0:
		return

	if pixel_perfect:
		var brush_rect := _image_pixels_to_local_rect(_get_brush_rect(stamp_pixel))
		if brush_head == BrushHead.CIRCLE:
			var center := brush_rect.position + brush_rect.size * 0.5
			var radius := maxf(1.0, minf(brush_rect.size.x, brush_rect.size.y) * 0.5)
			draw_circle(center, radius, preview_color)
			if draw_border:
				draw_arc(center, radius, 0.0, TAU, 32, Color.WHITE, 1.5, true)
		else:
			draw_rect(brush_rect, preview_color, true)
			if draw_border:
				draw_rect(brush_rect, Color.WHITE, false, 1.5)
		return

	var local_position: Vector2 = _image_pixel_center_to_local(stamp_pixel)
	var radius: float = maxf(1.0, float(brush_size) * display_scale * 0.5)
	if brush_head == BrushHead.CIRCLE:
		draw_circle(local_position, radius, preview_color)
		if draw_border:
			draw_arc(local_position, radius, 0.0, TAU, 48, Color.WHITE, 1.5, true)
	else:
		var local_rect := Rect2(local_position - Vector2(radius, radius), Vector2(radius * 2.0, radius * 2.0))
		draw_rect(local_rect, preview_color, true)
		if draw_border:
			draw_rect(local_rect, Color.WHITE, false, 1.5)


func _draw_shape_start_outline(pixel: Vector2i) -> void:
	var preview_color: Color = brush_color
	preview_color.a *= 0.4
	_draw_brush_preview_stamp(pixel, preview_color, true)


func _draw_rectangle_outline_preview(from_pixel: Vector2i, to_pixel: Vector2i) -> void:
	var rect: Rect2i = _get_pixel_rect(from_pixel, to_pixel)
	var left: int = rect.position.x
	var top: int = rect.position.y
	var right: int = rect.position.x + rect.size.x - 1
	var bottom: int = rect.position.y + rect.size.y - 1
	_draw_line_preview(Vector2i(left, top), Vector2i(right, top))
	_draw_line_preview(Vector2i(right, top), Vector2i(right, bottom))
	_draw_line_preview(Vector2i(right, bottom), Vector2i(left, bottom))
	_draw_line_preview(Vector2i(left, bottom), Vector2i(left, top))


func _draw_filled_rectangle_preview(from_pixel: Vector2i, to_pixel: Vector2i) -> void:
	var rect: Rect2i = _get_pixel_rect(from_pixel, to_pixel)
	var preview_color: Color = brush_color
	preview_color.a *= 0.45
	draw_rect(_image_pixels_to_local_rect(rect), preview_color, true)


func _draw_ellipse_outline_preview(from_pixel: Vector2i, to_pixel: Vector2i) -> void:
	var rect: Rect2i = _get_pixel_rect(from_pixel, to_pixel)
	if rect.size.x <= 1 or rect.size.y <= 1:
		_draw_line_preview(from_pixel, to_pixel)
		return

	var center := Vector2(rect.position) + (Vector2(rect.size) - Vector2.ONE) * 0.5
	var radius := (Vector2(rect.size) - Vector2.ONE) * 0.5
	var steps: int = max(16, int(ceil(TAU * maxf(radius.x, radius.y) * 1.5)))
	var preview_color: Color = brush_color
	preview_color.a *= 0.45
	for index in range(steps):
		var angle := TAU * float(index) / float(steps)
		var pixel := center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y)
		var stamp_pixel := Vector2i(roundi(pixel.x), roundi(pixel.y))
		_draw_brush_preview_stamp(stamp_pixel, preview_color, false)


func _draw_filled_ellipse_preview(from_pixel: Vector2i, to_pixel: Vector2i) -> void:
	var rect: Rect2i = _get_pixel_rect(from_pixel, to_pixel)
	var local_rect := _image_pixels_to_local_rect(rect)
	var center := local_rect.position + local_rect.size * 0.5
	var radius := local_rect.size * 0.5
	var preview_color: Color = brush_color
	preview_color.a *= 0.45
	var points := PackedVector2Array()
	var steps: int = max(24, int(ceil(TAU * maxf(radius.x, radius.y) / 8.0)))
	for index in range(steps):
		var angle := TAU * float(index) / float(steps)
		points.push_back(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, preview_color)


func _draw_selection() -> void:
	if _is_selecting:
		_draw_selection_rect(_get_pixel_rect(_selection_start_pixel, _selection_end_pixel), true)
	elif _is_lasso_selecting:
		_draw_lasso_path(_lasso_points, true)
	elif _has_selection:
		if _selection_mask:
			_draw_lasso_mask_selection(_selection_rect, _selection_mask)
			if _is_selection_tool():
				_draw_selection_bounds_controls(_selection_rect, false, true)
		else:
			_draw_selection_rect(_selection_rect, false, true)


func _draw_crop_preview() -> void:
	if not _has_crop_preview:
		return
	var clipped_rect := _clip_pixel_rect(_crop_preview_rect)
	if clipped_rect.size.x <= 0 or clipped_rect.size.y <= 0:
		return
	var local_rect := _image_pixels_to_local_rect(clipped_rect)
	var work_rect := _image_pixels_to_local_rect(Rect2i(Vector2i.ZERO, get_canvas_size()))
	var shade := Color(0.0, 0.0, 0.0, 0.48)
	if local_rect.position.y > work_rect.position.y:
		draw_rect(Rect2(work_rect.position, Vector2(work_rect.size.x, local_rect.position.y - work_rect.position.y)), shade, true)
	if local_rect.end.y < work_rect.end.y:
		draw_rect(Rect2(Vector2(work_rect.position.x, local_rect.end.y), Vector2(work_rect.size.x, work_rect.end.y - local_rect.end.y)), shade, true)
	if local_rect.position.x > work_rect.position.x:
		draw_rect(Rect2(Vector2(work_rect.position.x, local_rect.position.y), Vector2(local_rect.position.x - work_rect.position.x, local_rect.size.y)), shade, true)
	if local_rect.end.x < work_rect.end.x:
		draw_rect(Rect2(Vector2(local_rect.end.x, local_rect.position.y), Vector2(work_rect.end.x - local_rect.end.x, local_rect.size.y)), shade, true)
	_draw_dashed_rect(local_rect, Color(1.0, 0.85, 0.2, 1.0), 2.0, 8.0)


func _draw_floating_selection() -> void:
	if not _has_floating_selection or _is_transforming_selection or not _floating_texture:
		return
	_draw_texture_in_pixel_rect(_floating_texture, _floating_rect, _floating_angle)


func _draw_selection_transform_preview() -> void:
	if not _is_transforming_selection or not _selection_preview_texture:
		return

	_draw_texture_in_pixel_rect(_selection_preview_texture, _selection_preview_rect, _selection_preview_angle)
	if _selection_mask:
		_draw_lasso_mask_selection(_selection_preview_rect, _selection_mask)
		_draw_selection_bounds_controls(_selection_preview_rect, true, true)
	else:
		_draw_selection_rect(_selection_preview_rect, true, true)


func _draw_texture_in_pixel_rect(texture: Texture2D, pixel_rect: Rect2i, angle: float) -> void:
	var local_rect := _image_pixels_to_local_rect(pixel_rect)
	if is_zero_approx(angle):
		var clipped_pixel_rect := _clip_pixel_rect(pixel_rect)
		if clipped_pixel_rect.size.x <= 0 or clipped_pixel_rect.size.y <= 0:
			return
		var clipped_local_rect := _image_pixels_to_local_rect(clipped_pixel_rect)
		var texture_size := Vector2(texture.get_width(), texture.get_height())
		var source_rect := Rect2(
			Vector2(clipped_pixel_rect.position - pixel_rect.position) / Vector2(pixel_rect.size) * texture_size,
			Vector2(clipped_pixel_rect.size) / Vector2(pixel_rect.size) * texture_size
		)
		draw_texture_rect_region(texture, clipped_local_rect, source_rect)
		return

	var center := local_rect.position + local_rect.size * 0.5
	draw_set_transform(center, angle, Vector2.ONE)
	draw_texture_rect(texture, Rect2(-local_rect.size * 0.5, local_rect.size), false)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_selection_rect(pixel_rect: Rect2i, preview: bool, controls := false) -> void:
	var clipped_pixel_rect := _clip_pixel_rect(pixel_rect)
	if clipped_pixel_rect.size.x <= 0 or clipped_pixel_rect.size.y <= 0:
		return
	var local_rect := _image_pixels_to_local_rect(clipped_pixel_rect)
	var fill_color := Color(0.2, 0.55, 1.0, 0.16 if preview else 0.07)
	var border_color := Color(0.95, 0.98, 1.0, 0.95)
	draw_rect(local_rect, fill_color, true)
	_draw_dashed_rect(local_rect, border_color, 2.0, 8.0)
	if controls:
		_draw_selection_controls(local_rect)


func _draw_selection_bounds_controls(pixel_rect: Rect2i, preview: bool, controls := false) -> void:
	var clipped_pixel_rect := _clip_pixel_rect(pixel_rect)
	if clipped_pixel_rect.size.x <= 0 or clipped_pixel_rect.size.y <= 0:
		return
	var local_rect := _image_pixels_to_local_rect(clipped_pixel_rect)
	var border_color := Color(0.95, 0.98, 1.0, 0.95 if not preview else 0.8)
	_draw_dashed_rect(local_rect, border_color, 2.0, 8.0)
	if controls:
		_draw_selection_controls(local_rect)


func _draw_selection_controls(local_rect: Rect2) -> void:
	var handle_color := Color(0.95, 0.98, 1.0)
	var handle_border := Color(0.05, 0.12, 0.2)
	for handle_rect in _get_scale_handle_rects(local_rect):
		draw_rect(handle_rect, handle_color, true)
		draw_rect(handle_rect, handle_border, false, 1.0)

	var rotate_center := _get_rotate_handle_center(local_rect)
	draw_line(Vector2(local_rect.position.x + local_rect.size.x * 0.5, local_rect.position.y), rotate_center, handle_color, 1.0)
	draw_circle(rotate_center, SELECTION_HANDLE_SIZE * 0.55, handle_color)
	draw_arc(rotate_center, SELECTION_HANDLE_SIZE * 0.55, 0.0, TAU, 20, handle_border, 1.0)


func _draw_dashed_rect(rect: Rect2, color: Color, width: float, dash_length: float) -> void:
	_draw_dashed_line(rect.position, Vector2(rect.end.x, rect.position.y), color, width, dash_length)
	_draw_dashed_line(Vector2(rect.end.x, rect.position.y), rect.end, color, width, dash_length)
	_draw_dashed_line(rect.end, Vector2(rect.position.x, rect.end.y), color, width, dash_length)
	_draw_dashed_line(Vector2(rect.position.x, rect.end.y), rect.position, color, width, dash_length)


func _draw_dashed_line(from_point: Vector2, to_point: Vector2, color: Color, width: float, dash_length: float) -> void:
	var distance := from_point.distance_to(to_point)
	if distance <= 0.0:
		draw_circle(from_point, width, color)
		return

	var direction := (to_point - from_point) / distance
	var cursor := 0.0
	while cursor < distance:
		var segment_end := minf(cursor + dash_length, distance)
		draw_line(from_point + direction * cursor, from_point + direction * segment_end, color, width)
		cursor += dash_length * 2.0


func _draw_lasso_path(points: Array[Vector2i], preview: bool) -> void:
	if points.is_empty():
		return
	var local_points := PackedVector2Array()
	for point in points:
		local_points.push_back(_image_pixel_center_to_local(point))
	var path_color := Color(0.2, 0.55, 1.0, 0.35 if preview else 0.2)
	var border_color := Color(0.95, 0.98, 1.0, 0.95)
	for index in range(local_points.size() - 1):
		draw_line(local_points[index], local_points[index + 1], path_color, 5.0)
		_draw_dashed_line(local_points[index], local_points[index + 1], border_color, 2.0, 8.0)
	if not preview and local_points.size() > 2:
		draw_line(local_points[local_points.size() - 1], local_points[0], path_color, 5.0)
		_draw_dashed_line(local_points[local_points.size() - 1], local_points[0], border_color, 2.0, 8.0)


func _draw_lasso_mask_selection(pixel_rect: Rect2i, mask: Image, controls := false) -> void:
	var clipped_rect := _clip_pixel_rect(pixel_rect)
	if clipped_rect.size.x <= 0 or clipped_rect.size.y <= 0:
		return
	var fill_color := Color(0.2, 0.55, 1.0, 0.07)
	var border_color := Color(0.95, 0.98, 1.0, 0.95)
	for y in range(clipped_rect.position.y, clipped_rect.position.y + clipped_rect.size.y):
		for x in range(clipped_rect.position.x, clipped_rect.position.x + clipped_rect.size.x):
			var mask_position := Vector2i(x, y) - pixel_rect.position
			if not _mask_has_pixel(mask, mask_position):
				continue
			var pixel_local_rect := _image_pixels_to_local_rect(Rect2i(Vector2i(x, y), Vector2i.ONE))
			draw_rect(pixel_local_rect, fill_color, true)
			_draw_mask_edge_if_needed(mask, pixel_rect, Vector2i(x, y), Vector2i.LEFT, border_color)
			_draw_mask_edge_if_needed(mask, pixel_rect, Vector2i(x, y), Vector2i.RIGHT, border_color)
			_draw_mask_edge_if_needed(mask, pixel_rect, Vector2i(x, y), Vector2i.UP, border_color)
			_draw_mask_edge_if_needed(mask, pixel_rect, Vector2i(x, y), Vector2i.DOWN, border_color)
	if controls:
		_draw_selection_controls(_image_pixels_to_local_rect(clipped_rect))


func _draw_mask_edge_if_needed(mask: Image, pixel_rect: Rect2i, pixel: Vector2i, direction: Vector2i, color: Color) -> void:
	var neighbor := pixel + direction
	if _mask_has_pixel(mask, neighbor - pixel_rect.position):
		return
	var local_rect := _image_pixels_to_local_rect(Rect2i(pixel, Vector2i.ONE))
	if direction == Vector2i.LEFT:
		draw_line(local_rect.position, Vector2(local_rect.position.x, local_rect.end.y), color, 1.5)
	elif direction == Vector2i.RIGHT:
		draw_line(Vector2(local_rect.end.x, local_rect.position.y), local_rect.end, color, 1.5)
	elif direction == Vector2i.UP:
		draw_line(local_rect.position, Vector2(local_rect.end.x, local_rect.position.y), color, 1.5)
	elif direction == Vector2i.DOWN:
		draw_line(Vector2(local_rect.position.x, local_rect.end.y), local_rect.end, color, 1.5)


# Brush stamping, UV painting, coverage, and low-level pixel writes.
func _stamp(center: Vector2i) -> void:
	_begin_mirror_raster_scope()
	_stamp_pixels(center, true)
	_end_mirror_raster_scope()


func _stamp_unmirrored(center: Vector2i) -> void:
	_stamp_pixels(center, false)


func _stamp_pixels(center: Vector2i, apply_mirror: bool) -> void:
	if not pixel_perfect:
		_stamp_antialiased(center, apply_mirror)
		return

	var brush_rect := _get_brush_rect(center)
	for y in range(brush_rect.position.y, brush_rect.position.y + brush_rect.size.y):
		if y < 0 or y >= _image.get_height():
			continue
		for x in range(brush_rect.position.x, brush_rect.position.x + brush_rect.size.x):
			if x < 0 or x >= _image.get_width():
				continue
			if brush_head == BrushHead.CIRCLE and not _brush_circle_contains_pixel(center, Vector2i(x, y)):
				continue
			if apply_mirror:
				_paint_mirrored_pixel(x, y, brush_color, 1.0, _is_eraser_tool())
			elif _can_paint_pixel(Vector2i(x, y)):
				_paint_pixel(x, y, brush_color, 1.0, _is_eraser_tool())


func _stamp_antialiased(center: Vector2i, apply_mirror := true) -> void:
	var radius := maxf(0.5, float(brush_size) * 0.5)
	var pixel_radius := int(ceil(radius + 1.0))
	for y in range(center.y - pixel_radius, center.y + pixel_radius + 1):
		if y < 0 or y >= _image.get_height():
			continue
		for x in range(center.x - pixel_radius, center.x + pixel_radius + 1):
			if x < 0 or x >= _image.get_width():
				continue
			var coverage := _get_brush_pixel_coverage(center, Vector2i(x, y), radius)
			if coverage > 0.0:
				if apply_mirror:
					_paint_mirrored_pixel(x, y, brush_color, coverage, _is_eraser_tool())
				elif _can_paint_pixel(Vector2i(x, y)):
					_paint_pixel(x, y, brush_color, coverage, _is_eraser_tool())


func _stamp_uv_triangle(center: Vector2i, triangle_uvs: PackedVector2Array) -> void:
	if triangle_uvs.size() < 3:
		_stamp_unmirrored(center)
		return

	var triangle := _uv_triangle_to_image_points(triangle_uvs)
	var radius := maxf(0.5, float(brush_size) * 0.5)
	var pixel_radius := int(ceil(radius + (1.0 if not pixel_perfect else 0.0)))
	var brush_rect := Rect2i(
		Vector2i(center.x - pixel_radius, center.y - pixel_radius),
		Vector2i(pixel_radius * 2 + 1, pixel_radius * 2 + 1)
	)

	for y in range(brush_rect.position.y, brush_rect.position.y + brush_rect.size.y):
		if y < 0 or y >= _image.get_height():
			continue
		for x in range(brush_rect.position.x, brush_rect.position.x + brush_rect.size.x):
			if x < 0 or x >= _image.get_width():
				continue
			if not _pixel_touches_triangle_2d(Vector2i(x, y), triangle[0], triangle[1], triangle[2]):
				continue
			var coverage := _get_brush_pixel_coverage(center, Vector2i(x, y), radius)
			if coverage <= 0.0:
				continue
			if _can_paint_pixel(Vector2i(x, y)):
				_paint_pixel(x, y, brush_color, coverage, _is_eraser_tool())


func _stamp_uv_3d(center: Vector2i, triangle_uvs: PackedVector2Array) -> void:
	if brush_touch_pixels:
		_stamp_unmirrored(center)
	else:
		_stamp_uv_triangle(center, triangle_uvs)


func _get_brush_pixel_coverage(center: Vector2i, pixel: Vector2i, radius: float) -> float:
	if pixel_perfect:
		if brush_head == BrushHead.CIRCLE and not _brush_circle_contains_pixel(center, pixel):
			return 0.0
		if brush_head == BrushHead.SQUARE:
			var rect := _get_brush_rect(center)
			return 1.0 if rect.has_point(pixel) else 0.0
		return 1.0

	var distance: float
	if brush_head == BrushHead.CIRCLE:
		distance = _distance_to_pixel_rect(Vector2(center) + Vector2(0.5, 0.5), pixel) if brush_touch_pixels else Vector2(pixel.x - center.x, pixel.y - center.y).length()
	else:
		var distance_x := abs(float(pixel.x - center.x))
		var distance_y := abs(float(pixel.y - center.y))
		distance = maxf(distance_x, distance_y)
	var outer_radius := radius + 0.75
	if distance >= outer_radius:
		return 0.0
	if brush_hardness >= 0.999:
		return 1.0
	var inner_radius := radius * brush_hardness
	if distance <= inner_radius:
		return 1.0
	var falloff_width := maxf(0.0001, outer_radius - inner_radius)
	var weight := clampf((outer_radius - distance) / falloff_width, 0.0, 1.0)
	return weight * weight * (3.0 - 2.0 * weight)


func _uv_triangle_to_image_points(triangle_uvs: PackedVector2Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(3):
		var uv := triangle_uvs[index]
		points.push_back(Vector2(
			clampf(uv.x, 0.0, 1.0) * float(_image.get_width()),
			clampf(uv.y, 0.0, 1.0) * float(_image.get_height())
		))
	return points


func _point_in_triangle_2d(point: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var v0 := c - a
	var v1 := b - a
	var v2 := point - a
	var dot00 := v0.dot(v0)
	var dot01 := v0.dot(v1)
	var dot02 := v0.dot(v2)
	var dot11 := v1.dot(v1)
	var dot12 := v1.dot(v2)
	var denominator := dot00 * dot11 - dot01 * dot01
	if absf(denominator) <= 0.000001:
		return false
	var inverse_denominator := 1.0 / denominator
	var u := (dot11 * dot02 - dot01 * dot12) * inverse_denominator
	var v := (dot00 * dot12 - dot01 * dot02) * inverse_denominator
	return u >= -0.001 and v >= -0.001 and u + v <= 1.001


func _pixel_touches_triangle_2d(pixel: Vector2i, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var top_left := Vector2(pixel)
	var top_right := top_left + Vector2.RIGHT
	var bottom_left := top_left + Vector2.DOWN
	var bottom_right := top_left + Vector2.ONE
	var pixel_rect := Rect2(top_left, Vector2.ONE)
	var center := top_left + Vector2(0.5, 0.5)
	if _point_in_triangle_2d(center, a, b, c):
		return true
	for corner in [top_left, top_right, bottom_right, bottom_left]:
		if _point_in_triangle_2d(corner, a, b, c):
			return true
	for vertex in [a, b, c]:
		if pixel_rect.has_point(vertex):
			return true
	var pixel_edges := [
		PackedVector2Array([top_left, top_right]),
		PackedVector2Array([top_right, bottom_right]),
		PackedVector2Array([bottom_right, bottom_left]),
		PackedVector2Array([bottom_left, top_left]),
	]
	var triangle_edges := [
		PackedVector2Array([a, b]),
		PackedVector2Array([b, c]),
		PackedVector2Array([c, a]),
	]
	for triangle_edge in triangle_edges:
		for pixel_edge in pixel_edges:
			if _segments_intersect_2d(triangle_edge[0], triangle_edge[1], pixel_edge[0], pixel_edge[1]):
				return true
	return false


func _segments_intersect_2d(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	var direction_a := _orientation_2d(a, b, c)
	var direction_b := _orientation_2d(a, b, d)
	var direction_c := _orientation_2d(c, d, a)
	var direction_d := _orientation_2d(c, d, b)
	if is_zero_approx(direction_a) and _point_on_segment_2d(c, a, b):
		return true
	if is_zero_approx(direction_b) and _point_on_segment_2d(d, a, b):
		return true
	if is_zero_approx(direction_c) and _point_on_segment_2d(a, c, d):
		return true
	if is_zero_approx(direction_d) and _point_on_segment_2d(b, c, d):
		return true
	return (direction_a > 0.0) != (direction_b > 0.0) and (direction_c > 0.0) != (direction_d > 0.0)


func _orientation_2d(a: Vector2, b: Vector2, c: Vector2) -> float:
	var value := (b - a).cross(c - a)
	return 0.0 if absf(value) <= 0.000001 else value


func _point_on_segment_2d(point: Vector2, a: Vector2, b: Vector2) -> bool:
	return (
		point.x >= minf(a.x, b.x) - 0.000001
		and point.x <= maxf(a.x, b.x) + 0.000001
		and point.y >= minf(a.y, b.y) - 0.000001
		and point.y <= maxf(a.y, b.y) + 0.000001
	)


func _distance_to_pixel_rect(point: Vector2, pixel: Vector2i) -> float:
	var left := float(pixel.x)
	var top := float(pixel.y)
	var right := left + 1.0
	var bottom := top + 1.0
	var closest := Vector2(clampf(point.x, left, right), clampf(point.y, top, bottom))
	return point.distance_to(closest)


func _local_to_image_pixel(local_position: Vector2) -> Vector2i:
	if _image_rect.size.x <= 0.0 or _image_rect.size.y <= 0.0:
		return Vector2i.ZERO
	var normalized := Vector2(
		clampf((local_position.x - _image_rect.position.x) / _image_rect.size.x, 0.0, 1.0),
		clampf((local_position.y - _image_rect.position.y) / _image_rect.size.y, 0.0, 1.0)
	)
	return Vector2i(
		clampi(floori(normalized.x * float(_image.get_width())), 0, _image.get_width() - 1),
		clampi(floori(normalized.y * float(_image.get_height())), 0, _image.get_height() - 1)
	)


func _local_to_snapped_image_pixel(local_position: Vector2) -> Vector2i:
	var pixel := _local_to_image_pixel(local_position)
	return _snap_image_pixel(pixel) if _can_snap_to_grid() else pixel


func _local_to_snapped_brush_pixel(local_position: Vector2) -> Vector2i:
	var pixel := _local_to_image_pixel(local_position)
	return _snap_brush_pixel(pixel) if _can_snap_to_grid() else pixel


func _can_snap_to_grid() -> bool:
	return snap_to_grid and grid_size > 0 and _image != null and not _image.is_empty()


func _snap_image_pixel(pixel: Vector2i) -> Vector2i:
	if not _can_snap_to_grid():
		return pixel
	var step := maxi(1, grid_size)
	return Vector2i(
		clampi(roundi(float(pixel.x) / float(step)) * step, 0, _image.get_width() - 1),
		clampi(roundi(float(pixel.y) / float(step)) * step, 0, _image.get_height() - 1)
	)


func _snap_brush_pixel(pixel: Vector2i) -> Vector2i:
	if not _can_snap_to_grid():
		return pixel
	var step := maxi(1, grid_size)
	var brush_offset := floori(float(maxi(1, brush_size)) * 0.5)
	var cell_origin := Vector2i(
		floori(float(pixel.x) / float(step)) * step,
		floori(float(pixel.y) / float(step)) * step
	)
	return Vector2i(
		clampi(cell_origin.x + brush_offset, 0, _image.get_width() - 1),
		clampi(cell_origin.y + brush_offset, 0, _image.get_height() - 1)
	)


func _update_preview(local_position: Vector2) -> void:
	_has_preview = _image_rect.has_point(local_position)
	_preview_position = local_position
	_update_canvas_mouse_visibility()
	mouse_default_cursor_shape = _get_cursor_shape_at_position(local_position)
	queue_redraw()


func _clear_preview() -> void:
	_has_preview = false
	hover_uv_changed.emit(Vector2.ZERO, false)
	if _is_shape_previewing:
		_is_shape_previewing = false
		_clear_shape_preview_image()
	_update_canvas_mouse_visibility()
	queue_redraw()


func _get_mirrored_pixels(pixel: Vector2i) -> Array[Vector2i]:
	var pixels: Array[Vector2i] = [pixel]
	var mirror_horizontal := mirror_mode == MirrorMode.HORIZONTAL or mirror_mode == MirrorMode.BOTH
	var mirror_vertical := mirror_mode == MirrorMode.VERTICAL or mirror_mode == MirrorMode.BOTH
	if mirror_vertical:
		_append_unique_pixel(pixels, Vector2i(_image.get_width() - 1 - pixel.x, pixel.y))
	if mirror_horizontal:
		_append_unique_pixel(pixels, Vector2i(pixel.x, _image.get_height() - 1 - pixel.y))
	if mirror_horizontal and mirror_vertical:
		_append_unique_pixel(
			pixels,
			Vector2i(_image.get_width() - 1 - pixel.x, _image.get_height() - 1 - pixel.y)
		)
	return pixels


func _append_unique_pixel(pixels: Array[Vector2i], pixel: Vector2i) -> void:
	if not pixels.has(pixel):
		pixels.push_back(pixel)


func _begin_mirror_raster_scope() -> void:
	if _mirror_raster_scope_depth == 0:
		_mirror_generated_pixels.clear()
	_mirror_raster_scope_depth += 1


func _end_mirror_raster_scope() -> void:
	_mirror_raster_scope_depth = maxi(0, _mirror_raster_scope_depth - 1)
	if _mirror_raster_scope_depth == 0:
		_mirror_generated_pixels.clear()


func _paint_mirrored_pixel(x: int, y: int, color: Color, coverage: float, erase := false) -> bool:
	var source := Vector2i(x, y)
	var owns_scope := _mirror_raster_scope_depth == 0
	if owns_scope:
		_begin_mirror_raster_scope()
	var source_index := y * _image.get_width() + x
	if _mirror_generated_pixels.has(source_index):
		if owns_scope:
			_end_mirror_raster_scope()
		return false

	var changed := false
	var destinations := _get_mirrored_pixels(source)
	for destination in destinations:
		if not _can_paint_pixel(destination):
			continue
		changed = _paint_pixel(destination.x, destination.y, color, coverage, erase) or changed
		if destination != source:
			_mirror_generated_pixels[destination.y * _image.get_width() + destination.x] = true
	if owns_scope:
		_end_mirror_raster_scope()
	return changed


func _can_paint_pixel(pixel: Vector2i) -> bool:
	if pixel.x < 0 or pixel.y < 0 or pixel.x >= _image.get_width() or pixel.y >= _image.get_height():
		return false
	if not _has_selection:
		return true
	if not _selection_rect.has_point(pixel):
		return false
	if not _selection_mask:
		return true
	return _mask_has_pixel(_selection_mask, pixel - _selection_rect.position)


func _paint_pixel(x: int, y: int, color: Color, coverage: float, erase := false) -> bool:
	var current: Color = _image.get_pixel(x, y)
	var coverage_index := y * _image.get_width() + x
	if _is_shape_preview_rasterizing and not _shape_preview_original_pixels.has(coverage_index):
		_shape_preview_original_pixels[coverage_index] = current
	var base := current
	var effective_coverage := clampf(coverage, 0.0, 1.0)
	if _is_drawing and not stroke_overlap_enabled and (_stroke_start_image or _is_shape_preview_rasterizing):
		if coverage_index >= 0 and coverage_index < _stroke_coverage.size():
			if effective_coverage <= _stroke_coverage[coverage_index]:
				return false
			_stroke_coverage[coverage_index] = effective_coverage
			if _is_shape_preview_rasterizing:
				base = _shape_preview_original_pixels[coverage_index]
			else:
				base = _stroke_start_image.get_pixel(x, y)
	if effective_coverage <= 0.0:
		return false

	var result := base
	if erase:
		var erase_amount := clampf(effective_coverage * color.a, 0.0, 1.0)
		if erase_amount <= 0.0:
			return false
		if alpha_lock and base.a <= 0.0:
			return false
		if _has_eraser_restore_image():
			result = base.lerp(_get_eraser_color(x, y), erase_amount)
			if alpha_lock:
				result.a = base.a
		elif not alpha_lock:
			result.a = base.a * (1.0 - erase_amount)
	else:
		var source_alpha := clampf(color.a * effective_coverage, 0.0, 1.0)
		if source_alpha <= 0.0:
			return false
		if alpha_lock:
			if base.a <= 0.0:
				return false
			result.r = lerpf(base.r, color.r, source_alpha)
			result.g = lerpf(base.g, color.g, source_alpha)
			result.b = lerpf(base.b, color.b, source_alpha)
			result.a = base.a
		else:
			var out_alpha := source_alpha + base.a * (1.0 - source_alpha)
			if out_alpha <= 0.0:
				result = Color(0, 0, 0, 0)
			else:
				result.r = (color.r * source_alpha + base.r * base.a * (1.0 - source_alpha)) / out_alpha
				result.g = (color.g * source_alpha + base.g * base.a * (1.0 - source_alpha)) / out_alpha
				result.b = (color.b * source_alpha + base.b * base.a * (1.0 - source_alpha)) / out_alpha
				result.a = out_alpha

	if result.to_rgba32() == current.to_rgba32():
		return false
	_image.set_pixel(x, y, result)
	return true


func _begin_stroke_coverage() -> void:
	_stroke_coverage = PackedFloat32Array()
	if stroke_overlap_enabled:
		return
	_stroke_coverage.resize(_image.get_width() * _image.get_height())


func _pixel_matches_fill_target(x: int, y: int, target_color: Color) -> bool:
	return _colors_match_with_tolerance(_image.get_pixel(x, y), target_color)


# Fill tolerance is the maximum absolute difference between any RGBA8 channel.
func _colors_match_with_tolerance(left: Color, right: Color) -> bool:
	var tolerance := fill_tolerance
	return (
		absi(roundi(clampf(left.r, 0.0, 1.0) * 255.0) - roundi(clampf(right.r, 0.0, 1.0) * 255.0)) <= tolerance
		and absi(roundi(clampf(left.g, 0.0, 1.0) * 255.0) - roundi(clampf(right.g, 0.0, 1.0) * 255.0)) <= tolerance
		and absi(roundi(clampf(left.b, 0.0, 1.0) * 255.0) - roundi(clampf(right.b, 0.0, 1.0) * 255.0)) <= tolerance
		and absi(roundi(clampf(left.a, 0.0, 1.0) * 255.0) - roundi(clampf(right.a, 0.0, 1.0) * 255.0)) <= tolerance
	)


func _fill_pixel_visited(visited: PackedByteArray, width: int, x: int, y: int) -> bool:
	return visited[y * width + x] != 0


func _mark_fill_pixel_visited(visited: PackedByteArray, width: int, x: int, y: int) -> void:
	visited[y * width + x] = 1


func _images_equal(left: Image, right: Image) -> bool:
	return (
		left != null
		and right != null
		and left.get_width() == right.get_width()
		and left.get_height() == right.get_height()
		and left.get_format() == right.get_format()
		and left.get_data() == right.get_data()
	)


# Tool predicates, geometry helpers, selection masks, and canvas coordinate utilities.
func _is_stroke_tool() -> bool:
	return active_tool == ToolMode.BRUSH or active_tool == ToolMode.ERASER


func _uses_brush_hover_preview() -> bool:
	return _is_stroke_tool() or _is_shape_tool()


func _is_shape_tool() -> bool:
	return (
		active_tool == ToolMode.LINE
		or active_tool == ToolMode.RECTANGLE
		or active_tool == ToolMode.ELLIPSE
	)


func _is_selection_tool() -> bool:
	return active_tool == ToolMode.SELECT or active_tool == ToolMode.LASSO_SELECT


func _is_eraser_tool() -> bool:
	return active_tool == ToolMode.ERASER


func _has_eraser_restore_image() -> bool:
	return (
		_eraser_restore_image != null
		and not _eraser_restore_image.is_empty()
		and _eraser_restore_image.get_width() == _image.get_width()
		and _eraser_restore_image.get_height() == _image.get_height()
	)


func _get_eraser_color(x: int, y: int) -> Color:
	if _has_eraser_restore_image():
		return _eraser_restore_image.get_pixel(x, y)
	return Color(0, 0, 0, 0)


func _get_pixel_rect(from_pixel: Vector2i, to_pixel: Vector2i) -> Rect2i:
	var left: int = mini(from_pixel.x, to_pixel.x)
	var top: int = mini(from_pixel.y, to_pixel.y)
	var right: int = maxi(from_pixel.x, to_pixel.x)
	var bottom: int = maxi(from_pixel.y, to_pixel.y)
	return Rect2i(Vector2i(left, top), Vector2i(right - left + 1, bottom - top + 1))


func _get_constrained_shape_end_pixel(pixel: Vector2i) -> Vector2i:
	if not _shift_constrain:
		return pixel
	if active_tool == ToolMode.LINE:
		return _get_constrained_line_end_pixel(_shape_start_pixel, pixel)
	if active_tool == ToolMode.RECTANGLE or active_tool == ToolMode.ELLIPSE:
		return _get_square_end_pixel(_shape_start_pixel, pixel)
	return pixel


func _get_active_shape_endpoints() -> Array[Vector2i]:
	if not shape_from_center:
		return [_shape_start_pixel, _shape_end_pixel]
	var delta := _shape_end_pixel - _shape_start_pixel
	return [_shape_start_pixel - delta, _shape_start_pixel + delta]


func _get_constrained_selection_end_pixel(pixel: Vector2i) -> Vector2i:
	if not _shift_constrain or active_tool != ToolMode.SELECT:
		return pixel
	return _get_square_end_pixel(_selection_start_pixel, pixel)


func _get_constrained_line_end_pixel(from_pixel: Vector2i, to_pixel: Vector2i) -> Vector2i:
	var delta := to_pixel - from_pixel
	if delta == Vector2i.ZERO:
		return to_pixel
	var angle := Vector2(delta).angle()
	var snapped_angle := roundf(angle / (PI * 0.25)) * PI * 0.25
	var length := maxi(abs(delta.x), abs(delta.y))
	return _clamp_pixel(Vector2i(
		from_pixel.x + roundi(cos(snapped_angle) * float(length)),
		from_pixel.y + roundi(sin(snapped_angle) * float(length))
	))


func _get_square_end_pixel(from_pixel: Vector2i, to_pixel: Vector2i) -> Vector2i:
	var delta := to_pixel - from_pixel
	var side := maxi(abs(delta.x), abs(delta.y))
	return _clamp_pixel(Vector2i(
		from_pixel.x + _sign_int(delta.x) * side,
		from_pixel.y + _sign_int(delta.y) * side
	))


func _clamp_pixel(pixel: Vector2i) -> Vector2i:
	return Vector2i(
		clampi(pixel.x, 0, _image.get_width() - 1),
		clampi(pixel.y, 0, _image.get_height() - 1)
	)


func _sign_int(value: int) -> int:
	if value < 0:
		return -1
	if value > 0:
		return 1
	return 0


func _clip_pixel_rect(pixel_rect: Rect2i) -> Rect2i:
	return pixel_rect.intersection(Rect2i(Vector2i.ZERO, get_canvas_size()))


func _copy_image_rect(pixel_rect: Rect2i) -> Image:
	var clipped_rect := _clip_pixel_rect(pixel_rect)
	var copied_image := Image.create_empty(clipped_rect.size.x, clipped_rect.size.y, false, Image.FORMAT_RGBA8)
	copied_image.fill(Color(0, 0, 0, 0))
	if clipped_rect.size.x > 0 and clipped_rect.size.y > 0:
		copied_image.blit_rect(_image, clipped_rect, Vector2i.ZERO)
	return copied_image


func _copy_selected_image() -> Image:
	var clipped_rect := _clip_pixel_rect(_selection_rect)
	if clipped_rect.size.x <= 0 or clipped_rect.size.y <= 0:
		return Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)
	if not _selection_mask:
		return _copy_image_rect(clipped_rect)

	var copied_image := Image.create_empty(clipped_rect.size.x, clipped_rect.size.y, false, Image.FORMAT_RGBA8)
	copied_image.fill(Color(0, 0, 0, 0))
	for y in range(clipped_rect.size.y):
		for x in range(clipped_rect.size.x):
			var source_pixel := clipped_rect.position + Vector2i(x, y)
			var mask_position := source_pixel - _selection_rect.position
			if _mask_has_pixel(_selection_mask, mask_position):
				copied_image.set_pixel(x, y, _image.get_pixel(source_pixel.x, source_pixel.y))
	return copied_image


func _get_mask_occupied_rect(mask: Image) -> Rect2i:
	var left := mask.get_width()
	var top := mask.get_height()
	var right := -1
	var bottom := -1
	for y in range(mask.get_height()):
		for x in range(mask.get_width()):
			if mask.get_pixel(x, y).a8 > 0:
				left = mini(left, x)
				top = mini(top, y)
				right = maxi(right, x)
				bottom = maxi(bottom, y)
	if right < left or bottom < top:
		return Rect2i()
	return Rect2i(Vector2i(left, top), Vector2i(right - left + 1, bottom - top + 1))


func _clear_pixels(pixel_rect: Rect2i) -> void:
	var clipped_rect := _clip_pixel_rect(pixel_rect)
	for y in range(clipped_rect.position.y, clipped_rect.position.y + clipped_rect.size.y):
		for x in range(clipped_rect.position.x, clipped_rect.position.x + clipped_rect.size.x):
			_image.set_pixel(x, y, Color(0, 0, 0, 0))


func _clear_selected_pixels() -> void:
	var clipped_rect := _clip_pixel_rect(_selection_rect)
	if clipped_rect.size.x <= 0 or clipped_rect.size.y <= 0:
		return
	if not _selection_mask:
		_clear_pixels(clipped_rect)
		return
	for y in range(clipped_rect.position.y, clipped_rect.position.y + clipped_rect.size.y):
		for x in range(clipped_rect.position.x, clipped_rect.position.x + clipped_rect.size.x):
			if _mask_has_pixel(_selection_mask, Vector2i(x, y) - _selection_rect.position):
				_image.set_pixel(x, y, Color(0, 0, 0, 0))


func _blit_image_alpha(source_image: Image, target_position: Vector2i) -> void:
	_blit_image_alpha_to_image(_image, source_image, target_position)


func _blit_image_alpha_to_image(target_image: Image, source_image: Image, target_position: Vector2i) -> void:
	for y in range(source_image.get_height()):
		var target_y := target_position.y + y
		if target_y < 0 or target_y >= target_image.get_height():
			continue
		for x in range(source_image.get_width()):
			var target_x := target_position.x + x
			if target_x < 0 or target_x >= target_image.get_width():
				continue
			var source_color := source_image.get_pixel(x, y)
			if source_color.a <= 0.0:
				continue
			var base_color := target_image.get_pixel(target_x, target_y)
			target_image.set_pixel(target_x, target_y, _alpha_blend(source_color, base_color))


func _alpha_blend(source: Color, base: Color) -> Color:
	var out_alpha := source.a + base.a * (1.0 - source.a)
	if out_alpha <= 0.0:
		return Color(0, 0, 0, 0)
	return Color(
		(source.r * source.a + base.r * base.a * (1.0 - source.a)) / out_alpha,
		(source.g * source.a + base.g * base.a * (1.0 - source.a)) / out_alpha,
		(source.b * source.a + base.b * base.a * (1.0 - source.a)) / out_alpha,
		out_alpha
	)


func _get_centered_paste_position(paste_size: Vector2i) -> Vector2i:
	return Vector2i(
		floori(float(_image.get_width() - paste_size.x) * 0.5),
		floori(float(_image.get_height() - paste_size.y) * 0.5)
	)


func _clamp_rect_position(position: Vector2i, rect_size: Vector2i) -> Vector2i:
	return Vector2i(
		clampi(position.x, 0, maxi(0, _image.get_width() - rect_size.x)),
		clampi(position.y, 0, maxi(0, _image.get_height() - rect_size.y))
	)


func _clamp_rect_position_partial(position: Vector2i, rect_size: Vector2i) -> Vector2i:
	return Vector2i(
		clampi(position.x, mini(0, 1 - rect_size.x), _image.get_width() - 1),
		clampi(position.y, mini(0, 1 - rect_size.y), _image.get_height() - 1)
	)


func _get_scaled_selection_rect(pixel: Vector2i, preserve_aspect := false) -> Rect2i:
	if preserve_aspect and _selection_scale_handle in [0, 2, 4, 6]:
		pixel = _get_aspect_locked_scale_pixel(pixel)

	var left := _selection_transform_start_rect.position.x
	var top := _selection_transform_start_rect.position.y
	var right := _selection_transform_start_rect.position.x + _selection_transform_start_rect.size.x - 1
	var bottom := _selection_transform_start_rect.position.y + _selection_transform_start_rect.size.y - 1
	match _selection_scale_handle:
		0:
			left = pixel.x
			top = pixel.y
		1:
			top = pixel.y
		2:
			right = pixel.x
			top = pixel.y
		3:
			right = pixel.x
		4:
			right = pixel.x
			bottom = pixel.y
		5:
			bottom = pixel.y
		6:
			left = pixel.x
			bottom = pixel.y
		7:
			left = pixel.x

	_selection_transform_flip_h = left > right
	_selection_transform_flip_v = top > bottom
	var scaled_rect := _get_pixel_rect(Vector2i(left, top), Vector2i(right, bottom))
	scaled_rect.size.x = maxi(1, scaled_rect.size.x)
	scaled_rect.size.y = maxi(1, scaled_rect.size.y)
	return _clip_pixel_rect(scaled_rect)


func _get_aspect_locked_scale_pixel(pixel: Vector2i) -> Vector2i:
	var start_rect := _selection_transform_start_rect
	if start_rect.size.x <= 0 or start_rect.size.y <= 0:
		return pixel

	var left := start_rect.position.x
	var top := start_rect.position.y
	var right := start_rect.position.x + start_rect.size.x - 1
	var bottom := start_rect.position.y + start_rect.size.y - 1
	var anchor := Vector2i.ZERO
	match _selection_scale_handle:
		0:
			anchor = Vector2i(right, bottom)
		2:
			anchor = Vector2i(left, bottom)
		4:
			anchor = Vector2i(left, top)
		6:
			anchor = Vector2i(right, top)
		_:
			return pixel

	var direction_x := _sign_int(pixel.x - anchor.x)
	var direction_y := _sign_int(pixel.y - anchor.y)
	if direction_x == 0:
		direction_x = -1 if _selection_scale_handle in [0, 6] else 1
	if direction_y == 0:
		direction_y = -1 if _selection_scale_handle in [0, 2] else 1

	var width := maxi(1, abs(pixel.x - anchor.x) + 1)
	var height := maxi(1, abs(pixel.y - anchor.y) + 1)
	var aspect := float(start_rect.size.x) / float(start_rect.size.y)
	var target_width := width
	var target_height := height
	if float(width) / float(height) > aspect:
		target_height = maxi(1, roundi(float(width) / aspect))
	else:
		target_width = maxi(1, roundi(float(height) * aspect))

	return _clamp_pixel(Vector2i(
		anchor.x + direction_x * (target_width - 1),
		anchor.y + direction_y * (target_height - 1)
	))


func _get_lasso_bounds(points: Array[Vector2i]) -> Rect2i:
	var min_pixel := points[0]
	var max_pixel := points[0]
	for point in points:
		min_pixel.x = mini(min_pixel.x, point.x)
		min_pixel.y = mini(min_pixel.y, point.y)
		max_pixel.x = maxi(max_pixel.x, point.x)
		max_pixel.y = maxi(max_pixel.y, point.y)
	return _clip_pixel_rect(Rect2i(min_pixel, max_pixel - min_pixel + Vector2i.ONE))


func _create_lasso_mask(points: Array[Vector2i], bounds: Rect2i) -> Image:
	var mask := Image.create_empty(bounds.size.x, bounds.size.y, false, Image.FORMAT_RGBA8)
	mask.fill(Color(0, 0, 0, 0))
	if bounds.size.x <= 0 or bounds.size.y <= 0:
		return mask
	var polygon: Array[Vector2] = []
	for point in points:
		polygon.push_back(Vector2(point) + Vector2(0.5, 0.5))
	for y in range(bounds.size.y):
		for x in range(bounds.size.x):
			var image_point := Vector2(bounds.position + Vector2i(x, y)) + Vector2(0.5, 0.5)
			if _point_in_polygon(image_point, polygon):
				mask.set_pixel(x, y, Color(1, 1, 1, 1))
	return mask


func _create_alpha_mask(source_image: Image, clipped_rect: Rect2i, source_position: Vector2i) -> Image:
	var mask := Image.create_empty(clipped_rect.size.x, clipped_rect.size.y, false, Image.FORMAT_RGBA8)
	mask.fill(Color(0, 0, 0, 0))
	for y in range(clipped_rect.size.y):
		for x in range(clipped_rect.size.x):
			var source_pixel := clipped_rect.position - source_position + Vector2i(x, y)
			if source_pixel.x < 0 or source_pixel.y < 0 or source_pixel.x >= source_image.get_width() or source_pixel.y >= source_image.get_height():
				continue
			if source_image.get_pixel(source_pixel.x, source_pixel.y).a > 0.0:
				mask.set_pixel(x, y, Color(1, 1, 1, 1))
	return mask


func _mask_has_pixel(mask: Image, position: Vector2i) -> bool:
	if not mask:
		return false
	if position.x < 0 or position.y < 0 or position.x >= mask.get_width() or position.y >= mask.get_height():
		return false
	return mask.get_pixel(position.x, position.y).a > 0.0


func _point_in_polygon(point: Vector2, polygon: Array[Vector2]) -> bool:
	var inside := false
	var count := polygon.size()
	var previous := count - 1
	for current in range(count):
		var current_point := polygon[current]
		var previous_point := polygon[previous]
		var intersects := (
			(current_point.y > point.y) != (previous_point.y > point.y)
			and point.x < (previous_point.x - current_point.x) * (point.y - current_point.y) / (previous_point.y - current_point.y) + current_point.x
		)
		if intersects:
			inside = not inside
		previous = current
	return inside


func _get_scale_handle_rects(local_rect: Rect2) -> Array[Rect2]:
	var half_size := SELECTION_HANDLE_SIZE * 0.5
	var points: Array[Vector2] = [
		local_rect.position,
		Vector2(local_rect.position.x + local_rect.size.x * 0.5, local_rect.position.y),
		Vector2(local_rect.end.x, local_rect.position.y),
		Vector2(local_rect.end.x, local_rect.position.y + local_rect.size.y * 0.5),
		local_rect.end,
		Vector2(local_rect.position.x + local_rect.size.x * 0.5, local_rect.end.y),
		Vector2(local_rect.position.x, local_rect.end.y),
		Vector2(local_rect.position.x, local_rect.position.y + local_rect.size.y * 0.5),
	]
	var handle_rects: Array[Rect2] = []
	for point in points:
		handle_rects.push_back(Rect2(point - Vector2(half_size, half_size), Vector2(SELECTION_HANDLE_SIZE, SELECTION_HANDLE_SIZE)))
	return handle_rects


func _get_scale_handle_at_position(local_position: Vector2) -> int:
	var local_rect := _image_pixels_to_local_rect(_clip_pixel_rect(_selection_rect))
	var handle_rects := _get_scale_handle_rects(local_rect)
	for index in range(handle_rects.size()):
		if handle_rects[index].has_point(local_position):
			return index
	return -1


func _get_rotate_handle_center(local_rect: Rect2) -> Vector2:
	return Vector2(local_rect.position.x + local_rect.size.x * 0.5, local_rect.position.y - SELECTION_ROTATE_OFFSET)


func _rotate_handle_has_point(local_position: Vector2) -> bool:
	var local_rect := _image_pixels_to_local_rect(_clip_pixel_rect(_selection_rect))
	return local_position.distance_to(_get_rotate_handle_center(local_rect)) <= SELECTION_HANDLE_SIZE


func _get_base_cursor_shape() -> int:
	if active_tool == ToolMode.PAN:
		return Control.CURSOR_DRAG
	return Control.CURSOR_CROSS


func _get_cursor_shape_at_position(local_position: Vector2) -> int:
	if _is_panning or active_tool == ToolMode.PAN:
		return Control.CURSOR_DRAG
	if _is_transforming_selection:
		if _selection_transform_mode == SelectionTransformMode.MOVE:
			return Control.CURSOR_MOVE
		if _selection_transform_mode == SelectionTransformMode.ROTATE:
			return Control.CURSOR_POINTING_HAND
		if _selection_transform_mode == SelectionTransformMode.SCALE:
			return _get_scale_cursor_shape(_selection_scale_handle)
	if _is_selection_tool() and _has_selection:
		if _rotate_handle_has_point(local_position):
			return Control.CURSOR_POINTING_HAND
		var scale_handle := _get_scale_handle_at_position(local_position)
		if scale_handle != -1:
			return _get_scale_cursor_shape(scale_handle)
		if _image_pixels_to_local_rect(_clip_pixel_rect(_selection_rect)).has_point(local_position):
			return Control.CURSOR_MOVE
	return _get_base_cursor_shape()


func _get_scale_cursor_shape(handle_index: int) -> int:
	match handle_index:
		0, 4:
			return Control.CURSOR_FDIAGSIZE
		1, 5:
			return Control.CURSOR_VSIZE
		2, 6:
			return Control.CURSOR_BDIAGSIZE
		3, 7:
			return Control.CURSOR_HSIZE
	return _get_base_cursor_shape()


func _get_angle_from_selection_center(local_position: Vector2) -> float:
	var local_rect := _image_pixels_to_local_rect(_selection_transform_start_rect)
	var center := local_rect.position + local_rect.size * 0.5
	return (local_position - center).angle()


func _get_transformed_preview_image() -> Image:
	var transformed_image := _selection_preview_image.duplicate()
	if _selection_transform_mode == SelectionTransformMode.SCALE:
		if _selection_transform_flip_h:
			transformed_image.flip_x()
		if _selection_transform_flip_v:
			transformed_image.flip_y()
		if transformed_image.get_width() != _selection_preview_rect.size.x or transformed_image.get_height() != _selection_preview_rect.size.y:
			transformed_image.resize(_selection_preview_rect.size.x, _selection_preview_rect.size.y, Image.INTERPOLATE_NEAREST)
	elif _selection_transform_mode == SelectionTransformMode.ROTATE:
		transformed_image = _rotate_image_nearest(transformed_image, _selection_preview_angle)
	return transformed_image


func _rotate_image_nearest(source_image: Image, angle: float) -> Image:
	if is_zero_approx(angle):
		return source_image.duplicate()

	var source_size := Vector2(source_image.get_width(), source_image.get_height())
	var source_center := (source_size - Vector2.ONE) * 0.5
	var corners: Array[Vector2] = [
		Vector2.ZERO - source_center,
		Vector2(source_size.x - 1.0, 0.0) - source_center,
		Vector2(source_size.x - 1.0, source_size.y - 1.0) - source_center,
		Vector2(0.0, source_size.y - 1.0) - source_center,
	]
	var min_point := Vector2(INF, INF)
	var max_point := Vector2(-INF, -INF)
	for corner in corners:
		var rotated := corner.rotated(angle)
		min_point = min_point.min(rotated)
		max_point = max_point.max(rotated)

	var target_size := Vector2i(
		maxi(1, ceili(max_point.x - min_point.x + 1.0)),
		maxi(1, ceili(max_point.y - min_point.y + 1.0))
	)
	var target_image := Image.create_empty(target_size.x, target_size.y, false, Image.FORMAT_RGBA8)
	target_image.fill(Color(0, 0, 0, 0))
	var target_center := (Vector2(target_size) - Vector2.ONE) * 0.5
	for y in range(target_size.y):
		for x in range(target_size.x):
			var target_offset := Vector2(x, y) - target_center
			var source_point := target_offset.rotated(-angle) + source_center
			var source_x := roundi(source_point.x)
			var source_y := roundi(source_point.y)
			if source_x >= 0 and source_y >= 0 and source_x < source_image.get_width() and source_y < source_image.get_height():
				target_image.set_pixel(x, y, source_image.get_pixel(source_x, source_y))
	return target_image


func _set_floating_selection(image: Image, pixel_rect: Rect2i, mask: Image = null, cancel_image: Image = null) -> void:
	_floating_image = image.duplicate()
	_floating_texture = ImageTexture.create_from_image(_floating_image)
	_floating_rect = Rect2i(
		_clamp_rect_position_partial(pixel_rect.position, Vector2i(_floating_image.get_width(), _floating_image.get_height())),
		Vector2i(_floating_image.get_width(), _floating_image.get_height())
	)
	_floating_angle = 0.0
	_floating_mask = mask.duplicate() if mask else null
	_floating_cancel_image = cancel_image.duplicate() if cancel_image else null
	_floating_history_recorded = false
	_has_floating_selection = true
	_selection_rect = _floating_rect
	_selection_mask = _floating_mask
	_has_selection = true


func _clear_floating_selection(redraw := true) -> void:
	_has_floating_selection = false
	_floating_image = null
	_floating_texture = null
	_floating_rect = Rect2i()
	_floating_angle = 0.0
	_floating_mask = null
	_floating_cancel_image = null
	_floating_history_recorded = false
	if redraw:
		queue_redraw()


func _commit_floating_selection(keep_selection := true) -> void:
	if not _has_floating_selection:
		return
	var previous_image := _image.duplicate()
	var committed_mask := _floating_mask.duplicate() if _floating_mask else null
	var history_recorded := _floating_history_recorded
	_blit_image_alpha(_get_rotated_floating_image(), _floating_rect.position)
	_selection_rect = _floating_rect
	_has_selection = keep_selection
	_clear_floating_selection(false)
	_selection_mask = committed_mask
	_refresh_texture()
	if not history_recorded and not _images_equal(previous_image, _image):
		stroke_committed.emit(previous_image)
	if keep_selection:
		selection_committed.emit(_selection_rect)


func _get_rotated_floating_image() -> Image:
	if not _has_floating_selection:
		return Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)
	return _rotate_image_nearest(_floating_image, _floating_angle)


func _flip_selection(horizontal: bool) -> bool:
	if _has_floating_selection:
		var previous_image := get_image_copy()
		var flipped_image := _floating_image.duplicate()
		if horizontal:
			flipped_image.flip_x()
		else:
			flipped_image.flip_y()
		_set_floating_selection(flipped_image, _floating_rect)
		stroke_committed.emit(previous_image)
		selection_committed.emit(_selection_rect)
		queue_redraw()
		return true

	if not _has_selection:
		return false
	var clipped_rect := _clip_pixel_rect(_selection_rect)
	if clipped_rect.size.x <= 0 or clipped_rect.size.y <= 0:
		return false

	var previous_image := get_image_copy()
	var flipped_selection := _copy_image_rect(clipped_rect)
	if horizontal:
		flipped_selection.flip_x()
	else:
		flipped_selection.flip_y()
	_clear_pixels(clipped_rect)
	_blit_image_alpha(flipped_selection, clipped_rect.position)
	_refresh_texture()
	_selection_mask = null
	stroke_committed.emit(previous_image)
	selection_committed.emit(_selection_rect)
	return true


func _get_brush_rect(center: Vector2i) -> Rect2i:
	var size_pixels: int = maxi(1, brush_size)
	var offset: int = floori(float(size_pixels) * 0.5)
	return Rect2i(
		Vector2i(center.x - offset, center.y - offset),
		Vector2i(size_pixels, size_pixels)
	)


func _brush_circle_contains_pixel(center: Vector2i, pixel: Vector2i) -> bool:
	if brush_size <= 1:
		return pixel == center
	if brush_touch_pixels:
		return _brush_circle_touches_pixel(center, pixel)
	var radius := maxf(0.5, float(maxi(1, brush_size)) * 0.5)
	var pixel_center := Vector2(pixel) + Vector2(0.5, 0.5)
	var brush_center := Vector2(center) + Vector2(0.5, 0.5)
	return pixel_center.distance_to(brush_center) <= radius


func _brush_circle_touches_pixel(center: Vector2i, pixel: Vector2i) -> bool:
	var radius := maxf(0.5, float(maxi(1, brush_size)) * 0.5)
	var brush_center := Vector2(center) + Vector2(0.5, 0.5)
	return _distance_to_pixel_rect(brush_center, pixel) < radius


func _image_pixels_to_local_rect(pixel_rect: Rect2i) -> Rect2:
	var display_scale := _get_display_scale()
	return Rect2(
		_image_rect.position + Vector2(pixel_rect.position) * display_scale,
		Vector2(pixel_rect.size) * display_scale
	)


func _image_pixel_center_to_local(pixel: Vector2i) -> Vector2:
	var display_scale: float = _get_display_scale()
	return _image_rect.position + (Vector2(pixel) + Vector2(0.5, 0.5)) * display_scale


func _draw_pixel_grid(canvas_rect: Rect2) -> void:
	var display_scale := _get_display_scale()
	if display_scale <= 0.0:
		return

	var base_step := float(grid_size) * display_scale
	if base_step <= 0.0:
		return

	var skip := maxi(1, ceili(float(grid_min_cell_size) / base_step))
	var image_step := grid_size * skip
	var step := float(image_step) * display_scale
	if step < 1.0:
		return

	var line_color := grid_color
	var major_line_color := grid_color.lightened(0.35)
	major_line_color.a = minf(1.0, grid_color.a * 1.2)
	var width := 1.0
	var columns := int(ceil(float(_image.get_width()) / float(image_step)))
	var rows := int(ceil(float(_image.get_height()) / float(image_step)))
	var visible_rect := canvas_rect.intersection(_get_work_rect())
	if visible_rect.size.x <= 0.0 or visible_rect.size.y <= 0.0:
		return

	for x in range(columns + 1):
		var pixel_x := mini(x * image_step, _image.get_width())
		var local_x := canvas_rect.position.x + float(pixel_x) * display_scale
		if local_x < visible_rect.position.x or local_x > visible_rect.end.x:
			continue
		var color := major_line_color if pixel_x % 8 == 0 else line_color
		draw_line(Vector2(local_x, visible_rect.position.y), Vector2(local_x, visible_rect.end.y), color, width)
	for y in range(rows + 1):
		var pixel_y := mini(y * image_step, _image.get_height())
		var local_y := canvas_rect.position.y + float(pixel_y) * display_scale
		if local_y < visible_rect.position.y or local_y > visible_rect.end.y:
			continue
		var color := major_line_color if pixel_y % 8 == 0 else line_color
		draw_line(Vector2(visible_rect.position.x, local_y), Vector2(visible_rect.end.x, local_y), color, width)


func _draw_canvas_outline(canvas_rect: Rect2) -> void:
	var visible_rect := canvas_rect.intersection(_get_work_rect())
	if visible_rect.size.x <= 0.0 or visible_rect.size.y <= 0.0:
		return

	var color := Color(0.78, 0.78, 0.78)
	if canvas_rect.position.x >= 0.0 and canvas_rect.position.x <= size.x:
		draw_line(Vector2(canvas_rect.position.x, visible_rect.position.y), Vector2(canvas_rect.position.x, visible_rect.end.y), color, 2.0)
	if canvas_rect.end.x >= 0.0 and canvas_rect.end.x <= size.x:
		draw_line(Vector2(canvas_rect.end.x, visible_rect.position.y), Vector2(canvas_rect.end.x, visible_rect.end.y), color, 2.0)
	if canvas_rect.position.y >= 0.0 and canvas_rect.position.y <= size.y:
		draw_line(Vector2(visible_rect.position.x, canvas_rect.position.y), Vector2(visible_rect.end.x, canvas_rect.position.y), color, 2.0)
	if canvas_rect.end.y >= 0.0 and canvas_rect.end.y <= size.y:
		draw_line(Vector2(visible_rect.position.x, canvas_rect.end.y), Vector2(visible_rect.end.x, canvas_rect.end.y), color, 2.0)


func _get_image_rect() -> Rect2:
	return _get_image_rect_for_viewport(_get_drawable_viewport_size(), zoom_multiplier)


func _get_work_rect() -> Rect2:
	return Rect2(Vector2.ZERO, _get_drawable_viewport_size())


func _get_display_scale() -> float:
	if _image.get_width() <= 0:
		return 0.0
	return _image_rect.size.x / float(_image.get_width())


func _clear_image(color: Color) -> void:
	_image.fill(color)
	_refresh_texture()


func _clear_selection() -> void:
	_is_selecting = false
	_is_lasso_selecting = false
	_has_selection = false
	_selection_rect = Rect2i()
	_selection_mask = null
	_lasso_points.clear()


func _refresh_texture() -> void:
	_texture.update(_image)
	image_changed.emit(get_image_copy())
	queue_redraw()


func _set_canvas_mouse_hidden(hidden: bool) -> void:
	if hidden:
		if _mouse_hidden_by_canvas:
			return
		_previous_mouse_mode = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
		_mouse_hidden_by_canvas = true
		return

	if not _mouse_hidden_by_canvas:
		return
	Input.mouse_mode = _previous_mouse_mode
	_mouse_hidden_by_canvas = false


func _update_canvas_mouse_visibility() -> void:
	_set_canvas_mouse_hidden(_has_preview and (_uses_brush_hover_preview() or _is_shape_previewing))


func _zoom_at_position(new_zoom: float, local_position: Vector2) -> void:
	var old_rect := _get_image_rect()
	var previous_zoom := zoom_multiplier
	zoom_multiplier = new_zoom
	if is_equal_approx(previous_zoom, zoom_multiplier):
		return

	var image_anchor := Vector2(0.5, 0.5)
	if old_rect.size.x > 0.0 and old_rect.size.y > 0.0:
		image_anchor = Vector2(
			(local_position.x - old_rect.position.x) / old_rect.size.x,
			(local_position.y - old_rect.position.y) / old_rect.size.y
		)
		image_anchor = image_anchor.clamp(Vector2.ZERO, Vector2.ONE)

	var image_size := Vector2(_image.get_width(), _image.get_height())
	var viewport_size := _get_drawable_viewport_size()
	var available := viewport_size - Vector2(16, 16)
	if image_size.x <= 0.0 or image_size.y <= 0.0 or available.x <= 0.0 or available.y <= 0.0:
		queue_redraw()
		return

	var fit_scale := minf(available.x / image_size.x, available.y / image_size.y)
	var display_size := (image_size * fit_scale * zoom_multiplier).floor()
	var centered_position := ((viewport_size - display_size) * 0.5).floor()
	_pan_offset = local_position - centered_position - image_anchor * display_size
	_clamp_pan_offset()
	queue_redraw()


func _on_drawable_viewport_resized() -> void:
	var viewport_size := _get_drawable_viewport_size()
	if viewport_size.is_equal_approx(_last_viewport_size):
		return
	var previous_viewport_size := _last_viewport_size
	_last_viewport_size = viewport_size
	_clamp_zoom_after_viewport_resize(previous_viewport_size, viewport_size)


func _clamp_zoom_after_viewport_resize(
	previous_viewport_size: Vector2,
	viewport_size: Vector2
) -> void:
	var previous_zoom := zoom_multiplier
	var target_zoom := previous_zoom
	var image_anchor := Vector2(0.5, 0.5)
	if previous_viewport_size.x > 0.0 and previous_viewport_size.y > 0.0:
		var old_rect := _get_image_rect_for_viewport(previous_viewport_size, previous_zoom)
		if old_rect.size.x > 0.0 and old_rect.size.y > 0.0:
			image_anchor = Vector2(
				(previous_viewport_size.x * 0.5 - old_rect.position.x) / old_rect.size.x,
				(previous_viewport_size.y * 0.5 - old_rect.position.y) / old_rect.size.y
			).clamp(Vector2.ZERO, Vector2.ONE)
		var previous_fit_scale := _get_fit_scale_for_viewport(previous_viewport_size)
		var new_fit_scale := _get_fit_scale_for_viewport(viewport_size)
		if previous_fit_scale > 0.0 and new_fit_scale > 0.0:
			target_zoom = previous_fit_scale * previous_zoom / new_fit_scale

	zoom_multiplier = target_zoom
	var zoom_changed := not is_equal_approx(previous_zoom, zoom_multiplier)
	if zoom_changed:
		var new_rect := _get_image_rect_for_viewport(viewport_size, zoom_multiplier, Vector2.ZERO)
		_pan_offset = viewport_size * 0.5 - new_rect.position - image_anchor * new_rect.size
	_clamp_pan_offset()
	queue_redraw()
	# The maximum changes even when the current zoom does not, so refresh
	# readouts and zoom-in availability after every drawable viewport resize.
	if not zoom_changed:
		view_changed.emit(get_zoom_percent())


func _get_image_rect_for_viewport(
	viewport_size: Vector2,
	zoom: float,
	pan := _pan_offset
) -> Rect2:
	var image_size := Vector2(_image.get_width(), _image.get_height())
	var available := viewport_size - Vector2(16, 16)
	if image_size.x <= 0.0 or image_size.y <= 0.0 or available.x <= 0.0 or available.y <= 0.0:
		return Rect2()
	var scale := minf(available.x / image_size.x, available.y / image_size.y) * zoom
	var display_size := (image_size * scale).floor()
	var position := ((viewport_size - display_size) * 0.5 + pan).floor()
	return Rect2(position, display_size)


func _get_fit_scale_for_viewport(viewport_size: Vector2) -> float:
	var image_size := Vector2(_image.get_width(), _image.get_height())
	var available := viewport_size - Vector2(16, 16)
	if image_size.x <= 0.0 or image_size.y <= 0.0 or available.x <= 0.0 or available.y <= 0.0:
		return 0.0
	return minf(available.x / image_size.x, available.y / image_size.y)


func _get_max_pixel_scale(viewport_size: Vector2) -> float:
	return maxf(0.0, minf(viewport_size.x, viewport_size.y) * MAX_PIXEL_VIEWPORT_FRACTION)


func _get_drawable_viewport_size() -> Vector2:
	var viewport_size := size
	var canvas_host := get_parent() as Control
	if canvas_host:
		viewport_size = viewport_size.min(canvas_host.size)
	return viewport_size.max(Vector2.ZERO)


func _clamp_pan_offset() -> void:
	var image_size := Vector2(_image.get_width(), _image.get_height())
	var viewport_size := _get_drawable_viewport_size()
	var available := viewport_size - Vector2(16, 16)
	if image_size.x <= 0.0 or image_size.y <= 0.0 or available.x <= 0.0 or available.y <= 0.0:
		_pan_offset = Vector2.ZERO
		return

	var fit_scale := minf(available.x / image_size.x, available.y / image_size.y)
	var display_size := (image_size * fit_scale * zoom_multiplier).floor()
	var overflow := ((display_size - viewport_size) * 0.5).max(Vector2.ZERO)
	_pan_offset.x = clampf(_pan_offset.x, -overflow.x, overflow.x)
	_pan_offset.y = clampf(_pan_offset.y, -overflow.y, overflow.y)
