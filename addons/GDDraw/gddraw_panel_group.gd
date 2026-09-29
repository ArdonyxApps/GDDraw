@tool
extends PanelContainer
## Placement chrome only. Content and its signals belong to the registered client.

var host: Control
var group_id := ""
var tab_ids: Array = []
var strip: PanelContainer
var tabs: TabBar
var tab_view: ScrollContainer
var previous: Button
var next: Button
var menu: MenuButton
var body: MarginContainer
var drop_overlay: Control
var _updating := false
var _drop_zone := ""
var _drop_index := -1
var _drop_marker_x := 0.0
var _menu_actions: Array = []


func initialize(owner_host: Control, id: String) -> void:
	host = owner_host
	group_id = id
	size_flags_horizontal = SIZE_EXPAND_FILL
	size_flags_vertical = SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = host.surface_color
	style.border_color = host.outline_color
	style.set_border_width_all(3)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(side, 3)
	add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	add_child(column)
	strip = PanelContainer.new()
	var strip_style := StyleBoxFlat.new()
	strip_style.bg_color = host.outline_color
	strip.add_theme_stylebox_override("panel", strip_style)
	column.add_child(strip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	strip.add_child(row)
	previous = _arrow("Previous tab (Left Arrow / Home)", -1)
	tab_view = ScrollContainer.new()
	tab_view.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	tab_view.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tab_view.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(tab_view)
	tabs = TabBar.new()
	tabs.clip_tabs = false
	tabs.custom_minimum_size.y = 28
	tabs.tab_alignment = TabBar.ALIGNMENT_LEFT
	tabs.tab_changed.connect(_tab_changed)
	tabs.gui_input.connect(_tab_input)
	tabs.set_drag_forwarding(_drag_tab, _can_drop_tab.bind(tabs), _drop_tab)
	tab_view.add_child(tabs)
	row.add_child(previous)
	next = _arrow("Next tab (Right Arrow / End)", 1)
	row.add_child(next)
	menu = MenuButton.new()
	menu.custom_minimum_size = Vector2(28, 28)
	menu.tooltip_text = "Panel layout: move tab, split, collapse, or reset"
	menu.focus_mode = FOCUS_ALL
	menu.about_to_popup.connect(_build_menu)
	menu.get_popup().id_pressed.connect(_menu_selected)
	row.add_child(menu)
	body = MarginContainer.new()
	body.size_flags_vertical = SIZE_EXPAND_FILL
	column.add_child(body)
	set_drag_forwarding(Callable(), _can_drop_tab.bind(self), _drop_tab)
	strip.set_drag_forwarding(Callable(), _can_drop_tab.bind(strip), _drop_tab)
	# Client controls (notably Tree) stop drop propagation. A temporary overlay
	# receives panel drags without altering the client's own layer/asset drag API.
	drop_overlay = Control.new()
	drop_overlay.mouse_filter = MOUSE_FILTER_STOP
	drop_overlay.set_drag_forwarding(Callable(), _can_drop_tab.bind(drop_overlay), _drop_tab)
	drop_overlay.draw.connect(_draw_drop_feedback)
	drop_overlay.mouse_exited.connect(func(): _drop_zone = ""; drop_overlay.queue_redraw())
	add_child(drop_overlay)
	drop_overlay.hide()
	tab_view.resized.connect(_update_overflow)
	resized.connect(_update_overflow)


func _arrow(tip: String, direction: int) -> Button:
	var button := Button.new()
	var icon_path := "res://addons/GDDraw/icons/godot/GuiScrollArrow" + ("Left" if direction < 0 else "Right")
	button.set_meta("normal_icon", load(icon_path + "Hl.svg"))
	button.set_meta("highlight_icon", load(icon_path + ".svg"))
	button.icon = button.get_meta("normal_icon")
	button.flat = true
	button.add_theme_color_override("icon_normal_color", Color.WHITE)
	button.add_theme_color_override("icon_hover_color", Color.WHITE)
	button.add_theme_color_override("icon_pressed_color", Color.WHITE)
	button.add_theme_color_override("icon_disabled_color", Color(1, 1, 1, 0.35))
	button.mouse_entered.connect(func(): _update_arrow_icon(button, true))
	button.mouse_exited.connect(func(): _update_arrow_icon(button, false))
	button.tooltip_text = tip
	button.custom_minimum_size = Vector2(20, 28)
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_constant_override("icon_max_width", 16)
	button.add_theme_constant_override("h_separation", 0)
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var style := button.get_theme_stylebox(state).duplicate() as StyleBox
		style.set_content_margin(SIDE_LEFT, 2)
		style.set_content_margin(SIDE_RIGHT, 2)
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(navigate.bind(direction))
	button.gui_input.connect(_tab_input)
	return button


func _update_arrow_icon(button: Button, hovered: bool) -> void:
	button.icon = button.get_meta("highlight_icon" if hovered and not button.disabled else "normal_icon")


func configure(data: Dictionary) -> void:
	_updating = true
	# Use the requested header-button shade, retaining shared hover styling.
	var idle_style := menu.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	if idle_style:
		idle_style.bg_color = Color("#191919")
		menu.add_theme_stylebox_override("normal", idle_style)
		menu.add_theme_stylebox_override("disabled", idle_style)
	var next_ids: Array = host.open_tabs(data)
	var rebuild_tabs := next_ids != tab_ids
	tab_ids = next_ids
	if rebuild_tabs: tabs.clear_tabs()
	var minimum := Vector2(140, 100)
	for id in tab_ids:
		var panel: Dictionary = host.panels[id]
		if rebuild_tabs:
			tabs.add_tab(panel.title)
			tabs.set_tab_tooltip(tabs.tab_count - 1, panel.title + " — drag to reorder or move to another group; use ⋮ for keyboard placement")
		minimum = minimum.max(panel.minimum + Vector2(6, 37))
		var content: Control = panel.content
		if content.get_parent() != body:
			content.reparent(body) if content.get_parent() else body.add_child(content)
		content.visible = data.visible and id == data.active
	custom_minimum_size = minimum
	tabs.current_tab = tab_ids.find(data.active)
	visible = data.visible
	_updating = false
	call_deferred("_update_overflow")


func navigate(direction: int) -> void:
	if tab_ids.is_empty():
		return
	host.activate_panel(tab_ids[clampi(tabs.current_tab + direction, 0, tab_ids.size() - 1)])


func _tab_changed(index: int) -> void:
	if not _updating and index >= 0 and index < tab_ids.size():
		host.activate_panel(tab_ids[index])


func _tab_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_LEFT: navigate(-1)
			KEY_RIGHT: navigate(1)
			KEY_HOME: host.activate_panel(tab_ids[0])
			KEY_END: host.activate_panel(tab_ids[-1])
			_: return
		get_viewport().set_input_as_handled()


func _update_overflow() -> void:
	if not is_instance_valid(tabs) or tab_ids.is_empty():
		return
	# The native TabBar lives in a clipped viewport. No native tiny scroll arrows
	# are needed: the explicit buttons select adjacent tabs and reveal the active one.
	var available := maxf(1, strip.size.x - menu.size.x)
	var arrow_width := previous.get_combined_minimum_size().x + next.get_combined_minimum_size().x
	tabs.max_tab_width = int(maxf(32, minf(180, available - arrow_width)))
	var total := tabs.get_combined_minimum_size().x
	var overflow := total > available + 1
	previous.visible = overflow
	next.visible = overflow
	previous.disabled = tabs.current_tab <= 0
	next.disabled = tabs.current_tab >= tab_ids.size() - 1
	_update_arrow_icon(previous, previous.is_hovered())
	_update_arrow_icon(next, next.is_hovered())
	if tabs.current_tab >= 0:
		var rect := tabs.get_tab_rect(tabs.current_tab)
		var width := maxf(1, available - (arrow_width if overflow else 0))
		var offset := float(tab_view.scroll_horizontal)
		if rect.position.x < offset:
			offset = rect.position.x
		elif rect.end.x > offset + width:
			offset = rect.end.x - width
		tab_view.scroll_horizontal = maxi(0, ceili(offset)) if overflow else 0


func _drag_tab(position: Vector2) -> Variant:
	var index := tabs.get_tab_idx_at_point(position)
	if index < 0:
		return null
	var preview := Label.new()
	preview.text = "Move " + str(host.panels[tab_ids[index]].title)
	tabs.set_drag_preview(preview)
	return {"gddraw_panel_host": host.get_instance_id(), "panel_id": tab_ids[index]}


func _can_drop_tab(position: Vector2, data: Variant, receiver: Control) -> bool:
	if not host.accepts_drag(data):
		return false
	var point := get_global_transform().affine_inverse() * (receiver.get_global_transform() * position)
	_drop_zone = "tab"
	_drop_index = -1
	if point.y <= strip.size.y + 6 and not tab_ids.is_empty():
		var tab_point := tabs.get_global_transform().affine_inverse() * (receiver.get_global_transform() * position)
		var slot := tab_ids.size()
		for i in range(tab_ids.size()):
			if tab_point.x < tabs.get_tab_rect(i).get_center().x:
				slot = i
				break
		var group: Dictionary = host.group_for_panel(tab_ids[0])
		_drop_index = group.tabs.find(tab_ids[slot]) if slot < tab_ids.size() else group.tabs.size()
		var marker := tabs.get_tab_rect(slot).position.x if slot < tab_ids.size() else tabs.get_tab_rect(slot - 1).end.x
		_drop_marker_x = (drop_overlay.get_global_transform().affine_inverse() * (tabs.get_global_transform() * Vector2(marker, 0))).x
	if point.y > strip.size.y + 6:
		if point.x < size.x * 0.25: _drop_zone = "left"
		elif point.x > size.x * 0.75: _drop_zone = "right"
		elif point.y < size.y * 0.4: _drop_zone = "top"
		elif point.y > size.y * 0.6: _drop_zone = "bottom"
	drop_overlay.queue_redraw()
	return true


func _drop_tab(_position: Vector2, data: Variant) -> void:
	if host.accepts_drag(data):
		host.move_panel.call_deferred(data.panel_id, group_id, _drop_zone if not _drop_zone.is_empty() else "tab", _drop_index)
	_drop_zone = ""
	drop_overlay.queue_redraw()


func _notification(what: int) -> void:
	if not is_instance_valid(drop_overlay): return
	if what == NOTIFICATION_DRAG_BEGIN:
		drop_overlay.visible = host.accepts_drag(get_viewport().gui_get_drag_data())
	elif what == NOTIFICATION_DRAG_END:
		_drop_zone = ""
		drop_overlay.hide()
		drop_overlay.queue_redraw()


func _draw_drop_feedback() -> void:
	if _drop_zone.is_empty():
		return
	if _drop_zone == "tab" and _drop_index >= 0:
		var x := clampf(_drop_marker_x, 3, drop_overlay.size.x - 3)
		drop_overlay.draw_line(Vector2(x, 4), Vector2(x, strip.size.y + 2), Color(0.34, 0.63, 1), 3)
		return
	var rect := Rect2(Vector2.ZERO, drop_overlay.size)
	match _drop_zone:
		"left": rect.size.x *= 0.5
		"right": rect.position.x = drop_overlay.size.x * 0.5; rect.size.x *= 0.5
		"top": rect.size.y *= 0.5
		"bottom": rect.position.y = drop_overlay.size.y * 0.5; rect.size.y *= 0.5
	drop_overlay.draw_rect(rect, Color(0.34, 0.63, 1, 0.15))
	drop_overlay.draw_rect(rect, Color(0.34, 0.63, 1, 0.8), false, 4)


func _build_menu() -> void:
	var popup := menu.get_popup()
	popup.clear()
	_menu_actions.clear()
	for zone in ["left", "right", "top", "bottom"]:
		_add_action("Split active tab " + zone, ["move", group_id, zone])
		popup.set_item_disabled(popup.item_count - 1, tab_ids.size() < 2)
	for group in host.get_panel_groups():
		if group.id != group_id:
			_add_action("Move active tab to " + host.group_title(group), ["move", group.id, "tab"])
	popup.add_separator()
	_add_action("Collapse group", ["collapse"])
	_add_action("Reset panel layout", ["reset"])


func _add_action(title: String, action: Array) -> void:
	menu.get_popup().add_item(title, _menu_actions.size())
	_menu_actions.append(action)


func _menu_selected(index: int) -> void:
	var action: Array = _menu_actions[index]
	match action[0]:
		"move": host.move_panel.call_deferred(tab_ids[tabs.current_tab], action[1], action[2])
		"collapse": host.collapse_group.call_deferred(group_id)
		"reset": host.reset_layout.call_deferred()
