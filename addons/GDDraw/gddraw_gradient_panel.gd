@tool
extends VBoxContainer
const Raster := preload("res://addons/GDDraw/gddraw_gradient.gd")
const PERCENT_WIDTH := 64
signal edit_layer_requested
var canvas: Control
var strip: Control
var rows: Array = []
var rows_box: VBoxContainer
var add_button: Button
var duplicate_button: Button
var delete_button: Button
var empty_hint: Label
var _updating := false
var _strip_drag := false

func _init() -> void:
	name = "Gradient Controls"
	add_theme_constant_override("separation", 8)
	empty_hint = Label.new()
	empty_hint.text = "Select the Gradient tool or a Gradient layer to edit color stops."
	empty_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	empty_hint.hide()
	add_child(empty_hint)
	var hint := Label.new()
	hint.text = "Color stops"
	add_child(hint)
	strip = Control.new()
	strip.custom_minimum_size = Vector2(220, 52)
	strip.size_flags_horizontal = SIZE_EXPAND_FILL
	strip.tooltip_text = "Select or drag a color stop"
	strip.draw.connect(_draw_strip)
	strip.gui_input.connect(_strip_input)
	add_child(strip)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 100
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	add_child(scroll)
	rows_box = VBoxContainer.new()
	rows_box.size_flags_horizontal = SIZE_EXPAND_FILL
	rows_box.add_theme_constant_override("separation", 3)
	scroll.add_child(rows_box)
	var heading_margin := MarginContainer.new()
	heading_margin.add_theme_constant_override("margin_left", 3)
	heading_margin.add_theme_constant_override("margin_right", 3)
	rows_box.add_child(heading_margin)
	var headings := HBoxContainer.new()
	headings.add_theme_constant_override("separation", 4)
	heading_margin.add_child(headings)
	var spacer := Control.new()
	spacer.custom_minimum_size.x = 68
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	headings.add_child(spacer)
	for title in ["Position", "Opacity"]:
		var label := Label.new()
		label.text = title
		label.add_theme_font_size_override("font_size", 12)
		label.custom_minimum_size.x = PERCENT_WIDTH
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		headings.add_child(label)
	var footer := MarginContainer.new()
	footer.add_theme_constant_override("margin_bottom", 8)
	footer.add_theme_constant_override("margin_top", 4)
	add_child(footer)
	var actions := HBoxContainer.new()
	footer.add_child(actions)
	for i in range(3):
		var cell := CenterContainer.new()
		cell.size_flags_horizontal = SIZE_EXPAND_FILL
		actions.add_child(cell)
		var button := Button.new()
		cell.add_child(button)
		match i:
			0:
				add_button = button
				button.pressed.connect(func(): _ensure_gradient_edit(); canvas.add_gradient_stop())
			1:
				duplicate_button = button
				button.pressed.connect(func(): _ensure_gradient_edit(); canvas.add_gradient_stop(true))
			2:
				delete_button = button
				button.pressed.connect(func(): _ensure_gradient_edit(); canvas.delete_gradient_stop())

func set_context_available(available: bool) -> void:
	for child in get_children():
		if child is Control: child.visible = available if child != empty_hint else not available


func bind_canvas(value: Control) -> void:
	canvas = value
	canvas.gradient_stops_changed.connect(refresh)
	canvas.gradient_draft_changed.connect(refresh)
	refresh()

func _percent_field(parent: HBoxContainer, index: int, key: String) -> LineEdit:
	var field := LineEdit.new()
	field.custom_minimum_size.x = PERCENT_WIDTH
	field.size_flags_vertical = SIZE_SHRINK_CENTER
	field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	field.add_theme_font_size_override("font_size", 13)
	field.tooltip_text = ("Position" if key == "position" else "Opacity") + " (%)"
	field.set_meta("live_row", true)
	parent.add_child(field)
	field.focus_entered.connect(func():
		if not _updating and field.get_meta("live_row", false): _select(index))
	field.text_submitted.connect(func(_text: String): _commit_field(index, key, field))
	field.focus_exited.connect(func(): _commit_field(index, key, field))
	return field

func _make_row(index: int) -> Dictionary:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.focus_mode = Control.FOCUS_ALL
	rows_box.add_child(panel)
	panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed: _select(index)
		elif event is InputEventKey and event.pressed:
			if event.keycode in [KEY_UP, KEY_DOWN]:
				_select(clampi(index + (-1 if event.keycode == KEY_UP else 1), 0, rows.size() - 1))
				rows[canvas.gradient_selected_stop].panel.grab_focus()
				panel.accept_event())
	panel.focus_entered.connect(func():
		if not _updating: _select(index))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	panel.add_child(row)
	var picker := ColorPickerButton.new()
	picker.custom_minimum_size = Vector2(28, 28)
	picker.size_flags_vertical = SIZE_SHRINK_CENTER
	# Equal padding keeps the visible color square inside the button.
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var swatch_style := StyleBoxFlat.new()
		swatch_style.bg_color = Color("383838") if state in ["hover", "pressed"] else Color("232323")
		swatch_style.set_content_margin_all(4)
		picker.add_theme_stylebox_override(state, swatch_style)
	picker.edit_alpha = true
	picker.tooltip_text = "Stop color and transparency"
	row.add_child(picker)
	picker.pressed.connect(func(): _select(index))
	picker.color_changed.connect(func(color: Color):
		if not _updating:
			_select(index)
			canvas.edit_gradient_stop(index, color, canvas.get_gradient_stops()[index].position))
	var label := Label.new()
	label.custom_minimum_size.x = 36
	label.size_flags_horizontal = SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 13)
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(label)
	var position := _percent_field(row, index, "position")
	var alpha := _percent_field(row, index, "alpha")
	return {"panel": panel, "picker": picker, "label": label, "position": position, "alpha": alpha}

func refresh() -> void:
	if not canvas: return
	_updating = true
	var stops: Array = canvas.get_gradient_stops()
	if rows.size() != stops.size():
		for row in rows:
			row.position.set_meta("live_row", false)
			row.alpha.set_meta("live_row", false)
			rows_box.remove_child(row.panel)
			row.panel.queue_free()
		rows.clear()
		for i in range(stops.size()): rows.append(_make_row(i))
	var accent := get_theme_color("accent_color", "Editor") if has_theme_color("accent_color", "Editor") else Color("57a0ff")
	for i in range(stops.size()):
		var row: Dictionary = rows[i]
		var style := StyleBoxFlat.new()
		style.bg_color = Color(accent, 0.22) if i == canvas.gradient_selected_stop else Color("232323")
		style.set_content_margin_all(3)
		row.panel.add_theme_stylebox_override("panel", style)
		row.picker.color = stops[i].color
		row.label.text = "Start" if i == 0 else ("End" if i == stops.size() - 1 else str(i))
		row.position.editable = i > 0 and i < stops.size() - 1
		if not row.position.has_focus(): row.position.text = _format_percent(stops[i].position * 100) + "%"
		if not row.alpha.has_focus(): row.alpha.text = _format_percent(stops[i].color.a * 100) + "%"
		row.panel.tooltip_text = "Stop %d: position %s%%, opacity %s%%" % [i, _format_percent(stops[i].position * 100), _format_percent(stops[i].color.a * 100)]
	delete_button.disabled = canvas.gradient_selected_stop <= 0 or canvas.gradient_selected_stop >= stops.size() - 1
	strip.queue_redraw()
	_updating = false

func _format_percent(value: float) -> String:
	return ("%.2f" % value).trim_suffix("0").trim_suffix("0").trim_suffix(".")

func _commit_field(index: int, key: String, field: LineEdit) -> void:
	if _updating or not field.get_meta("live_row", false) or not field.editable: return
	var text := field.text.strip_edges().trim_suffix("%").strip_edges().replace(",", ".")
	var stops: Array = canvas.get_gradient_stops()
	if index >= stops.size(): return
	if text.is_valid_float() and is_finite(text.to_float()):
		_select(index)
		stops = canvas.get_gradient_stops()
		var color: Color = stops[index].color
		var position: float = stops[index].position
		if key == "alpha": color.a = clampf(text.to_float() / 100.0, 0, 1)
		else: position = clampf(text.to_float() / 100.0, 0, 1)
		canvas.edit_gradient_stop(index, color, position)
	stops = canvas.get_gradient_stops()
	field.text = _format_percent((stops[index].color.a if key == "alpha" else stops[index].position) * 100) + "%"

func _ensure_gradient_edit() -> void:
	if canvas and canvas.gradient_editing_enabled and not canvas._gradient_base:
		var selected: int = canvas.gradient_selected_stop
		edit_layer_requested.emit()
		canvas.select_gradient_stop(selected)

func _select(index: int) -> void:
	if _updating: return
	_ensure_gradient_edit()
	canvas.select_gradient_stop(index)

func _edit(color: Color, offset: float) -> void:
	_ensure_gradient_edit()
	canvas.edit_gradient_stop(canvas.gradient_selected_stop, color, offset)

func _draw_strip() -> void:
	if not canvas: return
	var width := maxf(1, strip.size.x - 20)
	var settings: Dictionary = canvas.get_gradient_settings()
	var ramp: Gradient = Raster.make_ramp(settings)
	for x in range(int(width)):
		for y in range(0, 32, 8):
			strip.draw_rect(Rect2(10 + x, y, 1, 8), Color(0.3,0.3,0.3) if (x / 8 + y / 8) % 2 == 0 else Color(0.55,0.55,0.55))
		strip.draw_line(Vector2(10 + x, 0), Vector2(10 + x, 32), ramp.sample(float(x) / width))
	var stops: Array = canvas.get_gradient_stops()
	for i in range(stops.size()):
		var offset: float = 1 - stops[i].position if canvas.gradient_reverse else stops[i].position
		var point := Vector2(10 + width * offset, 39)
		strip.draw_circle(point, 7, Color("57a0ff") if i == canvas.gradient_selected_stop else Color.BLACK)
		strip.draw_circle(point, 4, stops[i].color)

func _strip_input(event: InputEvent) -> void:
	if not canvas: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_strip_drag = event.pressed
		if event.pressed:
			var stops: Array = canvas.get_gradient_stops()
			var nearest := 0
			var distance := INF
			for i in range(stops.size()):
				var offset: float = 1 - stops[i].position if canvas.gradient_reverse else stops[i].position
				var current: float = absf(event.position.x - (10 + (strip.size.x - 20) * offset))
				if current < distance:
					distance = current
					nearest = i
			canvas.select_gradient_stop(nearest)
		strip.accept_event()
	elif event is InputEventMouseMotion and _strip_drag:
		if not event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_strip_drag = false
			return
		var offset: float = clampf((event.position.x - 10) / maxf(1, strip.size.x - 20), 0, 1)
		_edit(canvas.get_gradient_stops()[canvas.gradient_selected_stop].color, 1 - offset if canvas.gradient_reverse else offset)
		strip.accept_event()
