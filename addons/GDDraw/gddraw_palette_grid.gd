@tool
extends Control
## One focusable, virtual swatch grid. Color-marker changes only redraw.
signal color_requested(color: Color, background: bool)
signal add_requested
signal edit_requested(index: int)
signal remove_requested(index: int)
signal undo_requested
signal redo_requested

const CELL := 32
var cell := CELL
var rows := false
var editable := false
var swatches: Array = []
var columns := 1
var focused_index := 0
var foreground := Color.BLACK
var background := Color.WHITE
var _add_icon: Texture2D

func _init() -> void:
	# Read the same SVG used by New Palette without requiring an import-cache entry.
	var plus_image := Image.new()
	if plus_image.load_svg_from_string(FileAccess.get_file_as_string("res://addons/GDDraw/icons/plus/plus_0.svg")) == OK:
		_add_icon = ImageTexture.create_from_image(plus_image)
	focus_mode = FOCUS_ALL
	mouse_filter = MOUSE_FILTER_STOP
	size_flags_horizontal = SIZE_EXPAND_FILL
	custom_minimum_size.x = CELL
	resized.connect(_reflow)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)

func set_swatches(values: Array, index := 0) -> void:
	swatches = values
	focused_index = clampi(index, 0, maxi(0, swatches.size() - 1 + int(editable)))
	_reflow()

func set_colors(fg: Color, bg: Color) -> void:
	foreground = fg
	background = bg
	queue_redraw()

func _reflow() -> void:
	columns = 1 if rows else maxi(1, floori(size.x / cell))
	custom_minimum_size.y = ceili(float(swatches.size() + int(editable)) / columns) * cell
	queue_redraw()

func swatch_rect(index: int) -> Rect2:
	return Rect2(Vector2(index % columns, index / columns) * cell, Vector2(size.x if rows else cell, cell))

func set_view(mode: int) -> void:
	rows = mode == 3
	cell = [24, 32, 48, 36][clampi(mode, 0, 3)]
	_reflow()

func _draw() -> void:
	var focus_color := get_theme_color("accent_color", "Editor") if has_theme_color("accent_color", "Editor") else Color("57a0ff")
	var scroll := get_parent() as ScrollContainer
	var first_row := maxi(0, scroll.scroll_vertical / cell) if scroll else 0
	var last_row := ceili(float(scroll.scroll_vertical + scroll.size.y) / cell) if scroll else ceili(size.y / cell)
	for index in range(first_row * columns, mini(swatches.size() + int(editable), (last_row + 1) * columns)):
		var rect := swatch_rect(index).grow(-2)
		if index == swatches.size():
			draw_rect(rect, Color("383838"))
			if _add_icon:
				var icon_size := Vector2.ONE * (18 if rows else cell / 2)
				draw_texture_rect(_add_icon, Rect2(rect.get_center() - icon_size / 2, icon_size), false)
			if has_focus() and focused_index == index: draw_rect(rect, focus_color, false, 1)
			continue
		var color := Color(swatches[index].color)
		for y in range(4):
			for x in range(4):
				draw_rect(Rect2(rect.position + Vector2(x, y) * rect.size / 4, rect.size / 4), Color(0.7, 0.7, 0.7) if (x + y) % 2 else Color(0.35, 0.35, 0.35))
		draw_rect(rect, color)
		draw_rect(rect, Color.BLACK, false, 1)
		if rows:
			# Names remain in the tooltip; keep the badge compact so the color dominates.
			var label := "#" + color.to_html(color.a < 1).to_upper()
			var font := ThemeDB.fallback_font
			var label_width := minf(font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x, maxf(0, rect.size.x - 16))
			var badge_size := Vector2(label_width + 10, 18)
			var badge := Rect2(rect.get_center() - badge_size / 2, badge_size)
			draw_rect(badge, Color(0, 0, 0, 0.75))
			var baseline := badge.position + Vector2(5, (badge.size.y - font.get_height(11)) / 2 + font.get_ascent(11))
			draw_string(font, baseline, label, HORIZONTAL_ALIGNMENT_CENTER, label_width, 11, Color.WHITE)
		if color.is_equal_approx(foreground): _badge(rect.position, "F")
		if color.is_equal_approx(background): _badge(rect.end - Vector2(12, 13), "B")
		if has_focus() and index == focused_index:
			draw_rect(swatch_rect(index).grow(-1), Color.BLACK, false, 3)
			draw_rect(swatch_rect(index).grow(-1), focus_color, false, 1)

func _badge(position: Vector2, label: String) -> void:
	draw_rect(Rect2(position, Vector2(12, 13)), Color.BLACK)
	draw_string(ThemeDB.fallback_font, position + Vector2(2, 11), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)

func _index_at(position: Vector2) -> int:
	if position.x < 0 or position.y < 0 or position.x >= (size.x if rows else columns * cell): return -1
	var index := floori(position.y / cell) * columns + (0 if rows else floori(position.x / cell))
	return index if index < swatches.size() + int(editable) else -1

func _get_tooltip(at_position: Vector2) -> String:
	var index := _index_at(at_position)
	if index < 0: return ""
	if index == swatches.size(): return "Add Color"
	var swatch: Dictionary = swatches[index]
	var color := Color(swatch.color)
	return (swatch.name + "\n" if not swatch.name.is_empty() else "") + "#" + color.to_html(color.a < 1).to_upper() + ("\nAlpha: %.1f%%" % (color.a * 100) if color.a < 1 else "") + "\nLeft click / Enter / Space: foreground\nRight click / Shift+Enter: background\nArrows: move focus; Home / End: first / last"

func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and has_focus() and editable and not event.alt_pressed:
		if (event.ctrl_pressed or event.meta_pressed) and event.keycode in [KEY_Z, KEY_Y]:
			if not event.echo:
				if event.keycode == KEY_Y or event.shift_pressed: redo_requested.emit()
				else: undo_requested.emit()
			accept_event()
			return
		if event.keycode == KEY_DELETE and not event.ctrl_pressed and not event.meta_pressed:
			if not event.echo and focused_index < swatches.size(): remove_requested.emit(focused_index)
			accept_event()
			return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		var index := _index_at(event.position)
		if index >= 0:
			focused_index = index
			grab_focus()
			if editable and event.shift_pressed and event.button_index == MOUSE_BUTTON_RIGHT and index < swatches.size(): edit_requested.emit(index)
			else: _assign(event.button_index == MOUSE_BUTTON_RIGHT)
		accept_event()
	elif event is InputEventKey and event.pressed and not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed:
		var next := focused_index
		match event.keycode:
			KEY_LEFT: next -= 1
			KEY_RIGHT: next += 1
			KEY_UP: next -= columns
			KEY_DOWN: next += columns
			KEY_HOME: next = 0
			KEY_END: next = swatches.size() - 1 + int(editable)
			KEY_F10:
				if editable and event.shift_pressed and focused_index < swatches.size(): edit_requested.emit(focused_index)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				if not event.echo: _assign(event.shift_pressed and event.keycode != KEY_SPACE)
			_: return
		focused_index = clampi(next, 0, maxi(0, swatches.size() - 1 + int(editable)))
		reveal_focus()
		queue_redraw()
		accept_event()

func _assign(to_background: bool) -> void:
	if editable and focused_index == swatches.size():
		add_requested.emit()
		return
	if not swatches.is_empty(): color_requested.emit(Color(swatches[focused_index].color), to_background)
	queue_redraw()

func reveal_focus() -> void:
	var scroll := get_parent() as ScrollContainer
	if not scroll: return
	var rect := swatch_rect(focused_index)
	if rect.position.y < scroll.scroll_vertical: scroll.scroll_vertical = int(rect.position.y)
	elif rect.end.y > scroll.scroll_vertical + scroll.size.y: scroll.scroll_vertical = ceili(rect.end.y - scroll.size.y)
