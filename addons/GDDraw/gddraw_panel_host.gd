@tool
extends PanelContainer
## Owns placement only; never receives a canvas, document, or drawing history.

signal layout_changed
signal menu_created(button: MenuButton)

const Group := preload("res://addons/GDDraw/gddraw_panel_group.gd")
const LAYOUT_VERSION := 2
const METADATA_KEY := "right_panel_layout"
const RAIL_WIDTH := 34.0
const DEFAULT_WIDTH := 280.0

var panels: Dictionary = {}
var group_views: Dictionary = {}
var surface_color := Color("#292929")
var outline_color := Color("#202020")
var dock_width := DEFAULT_WIDTH
var layout: Dictionary = {}
var rail: VBoxContainer
var viewport: ScrollContainer
var parking: Control
var _settings: Object
var _graph: Control
var _next_group := 0
var _generation := 0
var _scroll_states: Dictionary = {}
var _temporary_layout: Dictionary = {}
var _temporary_id := ""


func _init() -> void:
	name = "Right Panel Host"
	size_flags_horizontal = SIZE_EXPAND_FILL
	size_flags_vertical = SIZE_EXPAND_FILL
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	add_child(row)
	var rail_scroll := ScrollContainer.new()
	rail_scroll.custom_minimum_size.x = RAIL_WIDTH - 4
	rail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rail_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	row.add_child(rail_scroll)
	rail = VBoxContainer.new()
	rail.size_flags_horizontal = SIZE_EXPAND_FILL
	rail_scroll.add_child(rail)
	var top_divider := HSeparator.new()
	top_divider.name = "Panel Rail Top Divider"
	top_divider.custom_minimum_size.y = 6
	rail.add_child(top_divider)
	viewport = ScrollContainer.new()
	viewport.size_flags_horizontal = SIZE_EXPAND_FILL
	viewport.size_flags_vertical = SIZE_EXPAND_FILL
	viewport.follow_focus = true
	row.add_child(viewport)
	parking = Control.new()
	parking.hide()
	add_child(parking)


func register_panel(id: String, title: String, icon: Texture2D, content: Control, minimum: Vector2, rail_button: Button = null) -> bool:
	if id.is_empty() or panels.has(id) or not is_instance_valid(content):
		return false
	for entry in panels.values():
		if entry.content == content:
			return false
	if not minimum.is_finite() or minimum.x < 0 or minimum.y < 0:
		return false
	var button := rail_button if rail_button else Button.new()
	button.icon = icon
	if not icon and not rail_button: button.text = title.left(1)
	button.tooltip_text = "Show / hide " + title + " (highlighted while open)"
	button.custom_minimum_size = Vector2(28, 28)
	button.toggle_mode = true
	button.focus_mode = FOCUS_ALL
	button.toggled.connect(func(_pressed: bool): toggle_panel(id))
	rail.add_child(button)
	content.size_flags_horizontal = SIZE_EXPAND_FILL
	content.size_flags_vertical = SIZE_EXPAND_FILL
	content.custom_minimum_size = content.custom_minimum_size.max(minimum)
	if content.get_parent(): content.reparent(parking)
	else: parking.add_child(content)
	panels[id] = {"title": title, "icon": icon, "content": content, "minimum": minimum, "button": button}
	return true


func open_temporary_panel(id: String, title: String, icon: Texture2D, content: Control, rail_button: Button = null) -> void:
	if _temporary_id == id: return
	if not _temporary_id.is_empty(): close_temporary_panel()
	_temporary_layout = describe_layout()
	_temporary_id = id
	register_panel(id, title, icon, content, Vector2(240, 200), rail_button)
	var group: Dictionary = get_panel_groups()[0]
	group.tabs.append(id)
	activate_panel(id)

func close_temporary_panel() -> void:
	if _temporary_id.is_empty(): return
	var entry: Dictionary = panels[_temporary_id]
	entry.content.reparent(parking)
	entry.content.hide()
	entry.button.queue_free()
	_scroll_states.erase(_temporary_id)
	panels.erase(_temporary_id)
	var saved := _temporary_layout
	_temporary_layout = {}
	_temporary_id = ""
	restore_description(saved)
	layout_changed.emit()

func retain_temporary_panel(id: String) -> bool:
	if _temporary_id != id: return false
	_temporary_id = ""
	_temporary_layout = {}
	_save()
	return true


func unregister_panel(id: String) -> void:
	if not panels.has(id): return
	if _temporary_id == id:
		close_temporary_panel()
		return
	var entry: Dictionary = panels[id]
	entry.content.reparent(parking)
	entry.content.hide()
	entry.button.queue_free()
	panels.erase(id)
	_scroll_states.erase(id)
	for group in get_panel_groups():
		group.tabs.erase(id)
		group.closed.erase(id)
		_sync_group(group)
	layout = _prune(layout)
	_changed()


func restore_layout(settings: Object = null, legacy_width: Variant = DEFAULT_WIDTH, legacy_expanded: Variant = false) -> bool:
	_settings = settings
	if settings:
		legacy_width = settings.get_project_metadata("GDDraw", "layers_panel_width", legacy_width)
		legacy_expanded = settings.get_project_metadata("GDDraw", "layers_panel_expanded", legacy_expanded)
	# EditorSettings treats null as "no default" and logs an error for a missing key.
	var saved: Variant = settings.get_project_metadata("GDDraw", METADATA_KEY, {}) if settings else {}
	return restore_description(saved, legacy_width, legacy_expanded)


func restore_description(saved: Variant, legacy_width: Variant = DEFAULT_WIDTH, legacy_expanded: Variant = false) -> bool:
	_capture_scroll_states()
	var valid := false
	var normalized: Dictionary = {}
	if saved is Dictionary and saved.get("version") in [1, LAYOUT_VERSION]:
		var seen := {}
		var groups := {}
		normalized = _validate_node(saved.get("root"), seen, groups, 0, saved.version == 1)
		valid = not normalized.is_empty() and _valid_number(saved.get("width"))
		if valid:
			# Newly registered / previously missing clients remain reachable as tabs.
			var first := _groups_in(normalized)[0] as Dictionary
			for id in panels:
				if not seen.has(id):
					first.tabs.append(id)
					first.closed.append(id)
			dock_width = clampf(float(saved.width), DEFAULT_WIDTH, 1600)
	if valid:
		layout = normalized
	else:
		dock_width = clampf(float(legacy_width), DEFAULT_WIDTH, 520) if _valid_number(legacy_width) else DEFAULT_WIDTH
		layout = _default_layout(legacy_expanded if legacy_expanded is bool else false)
		if not layout.is_empty() and layout.visible:
			layout.closed = layout.tabs.slice(1)
	_render()
	# Loading is read-only. The first actual layout operation writes the migration.
	return valid


func _valid_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


func _validate_node(value: Variant, seen: Dictionary, groups: Dictionary, depth: int, legacy := false) -> Dictionary:
	if depth > 16 or not value is Dictionary:
		return {}
	if value.get("type") == "group":
		var id: Variant = value.get("id")
		if not id is String or id.is_empty() or id.length() > 128 or groups.has(id) or groups.size() >= 128: return {}
		if not value.get("tabs") is Array or value.tabs.size() > 128 or not value.get("visible") is bool: return {}
		groups[id] = true
		var ids: Array = []
		for panel_id in value.tabs:
			if not panel_id is String: return {}
			if not panels.has(panel_id): continue
			if seen.has(panel_id): return {}
			seen[panel_id] = true
			ids.append(panel_id)
		if ids.is_empty(): return {}
		var active: Variant = value.get("active")
		var closed: Array = []
		if legacy:
			if not value.visible: closed = ids.duplicate()
		else:
			if not value.get("closed") is Array or value.closed.size() > 128: return {}
			for panel_id in value.closed:
				if not panel_id is String or closed.has(panel_id): return {}
				if panel_id in ids: closed.append(panel_id)
		var result := {"type": "group", "id": id, "tabs": ids, "closed": closed, "active": active if active in ids else ids[0], "visible": value.visible}
		_sync_group(result)
		return result
	if value.get("type") == "split":
		if value.get("axis") not in ["horizontal", "vertical"] or not _valid_number(value.get("ratio")): return {}
		if float(value.ratio) <= 0 or float(value.ratio) >= 1: return {}
		var first := _validate_node(value.get("first"), seen, groups, depth + 1, legacy)
		var second := _validate_node(value.get("second"), seen, groups, depth + 1, legacy)
		if first.is_empty() or second.is_empty(): return {}
		return {"type": "split", "axis": value.axis, "ratio": clampf(value.ratio, 0.1, 0.9), "first": first, "second": second}
	return {}


func _default_layout(expanded: bool) -> Dictionary:
	if panels.is_empty(): return {}
	return {"type": "group", "id": "main", "tabs": panels.keys(), "closed": [] if expanded else panels.keys(), "active": panels.keys()[0], "visible": expanded}


func open_tabs(group: Dictionary) -> Array:
	# A live @tool host may still hold version-1 groups after script reload.
	if not group.has("closed"):
		group.closed = [] if group.visible else group.tabs.duplicate()
	var result: Array = []
	for id in group.tabs:
		if id not in group.closed: result.append(id)
	return result


func _sync_group(group: Dictionary) -> void:
	var opened := open_tabs(group)
	group.visible = not opened.is_empty()
	if group.visible and group.active not in opened: group.active = opened[0]


func is_panel_open(id: String) -> bool:
	var group := group_for_panel(id)
	return not group.is_empty() and id in open_tabs(group)


func describe_layout() -> Dictionary:
	return {"version": LAYOUT_VERSION, "width": dock_width, "root": layout.duplicate(true)}


func get_panel_groups() -> Array:
	return _groups_in(layout)


func _groups_in(node: Dictionary) -> Array:
	if node.is_empty(): return []
	if node.type == "group": return [node]
	return _groups_in(node.first) + _groups_in(node.second)


func group_for_panel(id: String) -> Dictionary:
	for group in get_panel_groups():
		if id in group.tabs: return group
	return {}


func group_title(group: Dictionary) -> String:
	var titles: PackedStringArray = []
	for id in group.tabs: titles.append(panels[id].title)
	return ", ".join(titles)


func is_panel_active(id: String) -> bool:
	var group := group_for_panel(id)
	return not group.is_empty() and group.visible and group.active == id


func has_visible_groups() -> bool:
	return _node_visible(layout)


func toggle_panel(id: String) -> void:
	if is_panel_open(id): close_panel(id)
	else: activate_panel(id)


func close_panel(id: String) -> void:
	var group := group_for_panel(id)
	if group.is_empty() or not is_panel_open(id): return
	_capture_scroll_states()
	group.closed.append(id)
	_sync_group(group)
	_changed()
	panels[id].button.grab_focus()


func activate_panel(id: String, take_focus := true) -> void:
	var group := group_for_panel(id)
	if group.is_empty(): return
	var already_open := id in open_tabs(group)
	_capture_scroll_states()
	group.closed.erase(id)
	group.active = id
	group.visible = true
	if already_open and group_views.has(group.id):
		# Keep the TabBar in the tree during its mouse press so an inactive
		# tab can become the source of a drag without losing native input state.
		group_views[group.id].configure(group)
		_sync_panel_buttons()
		_save()
		layout_changed.emit()
		call_deferred("_restore_scroll_states", _generation)
	else:
		_changed()
	var view: Control = group_views[group.id]
	if take_focus: view.tabs.grab_focus()
	viewport.ensure_control_visible(view)


func collapse_group(id: String) -> void:
	for group in get_panel_groups():
		if group.id == id:
			_capture_scroll_states()
			group.closed = group.tabs.duplicate()
			group.visible = false
			_changed()
			panels[group.active].button.grab_focus()
			return


func reset_layout() -> void:
	_capture_scroll_states()
	layout = _default_layout(true)
	dock_width = DEFAULT_WIDTH
	_changed()


func set_dock_width(width: float) -> void:
	if is_finite(width):
		dock_width = clampf(width, DEFAULT_WIDTH, 1600)
		_save()


func accepts_drag(data: Variant) -> bool:
	return data is Dictionary and data.get("gddraw_panel_host") == get_instance_id() and panels.has(data.get("panel_id"))


func move_panel(id: String, destination_id: String, zone := "tab", insertion_index := -1) -> bool:
	if zone not in ["tab", "left", "right", "top", "bottom"]: return false
	var source := group_for_panel(id)
	var destination: Dictionary = {}
	for group in get_panel_groups():
		if group.id == destination_id: destination = group
	if source.is_empty() or destination.is_empty(): return false
	open_tabs(source)
	open_tabs(destination)
	if source.id == destination.id:
		if zone == "tab":
			if insertion_index < 0: return false
			var old_index: int = source.tabs.find(id)
			var new_index := clampi(insertion_index, 0, source.tabs.size())
			if new_index > old_index: new_index -= 1
			if old_index == new_index: return false
			_capture_scroll_states()
			source.tabs.erase(id)
			source.tabs.insert(new_index, id)
			_changed()
			return true
		if source.tabs.size() == 1: return false
	_capture_scroll_states()
	source.tabs.erase(id)
	source.closed.erase(id)
	if source.active == id: source.active = source.tabs[0] if not source.tabs.is_empty() else ""
	_sync_group(source)
	if zone == "tab":
		destination.tabs.insert(destination.tabs.size() if insertion_index < 0 else clampi(insertion_index, 0, destination.tabs.size()), id)
		destination.closed.erase(id)
		destination.active = id
		destination.visible = true
	else:
		var new_id := _new_group_id()
		var new_group := {"type": "group", "id": new_id, "tabs": [id], "closed": [], "active": id, "visible": true}
		var old := destination.duplicate(true)
		destination.clear()
		destination.merge({"type": "split", "axis": "horizontal" if zone in ["left", "right"] else "vertical", "ratio": 0.5,
			"first": new_group if zone in ["left", "top"] else old,
			"second": old if zone in ["left", "top"] else new_group})
	layout = _prune(layout)
	_changed()
	return true


func _new_group_id() -> String:
	var ids: Array = []
	for group in get_panel_groups(): ids.append(group.id)
	while true:
		_next_group += 1
		var id := "group_%d" % _next_group
		if id not in ids: return id
	return ""


func _prune(node: Dictionary) -> Dictionary:
	if node.type == "group": return {} if node.tabs.is_empty() else node
	node.first = _prune(node.first)
	node.second = _prune(node.second)
	if node.first.is_empty(): return node.second
	if node.second.is_empty(): return node.first
	return node


func _node_visible(node: Dictionary) -> bool:
	if node.is_empty(): return false
	if node.type == "group": return node.visible
	return _node_visible(node.first) or _node_visible(node.second)


func _changed() -> void:
	_render()
	_save()
	layout_changed.emit()


func _save() -> void:
	if not _temporary_id.is_empty(): return
	if is_instance_valid(_settings):
		_settings.set_project_metadata("GDDraw", METADATA_KEY, describe_layout())


func _render() -> void:
	_generation += 1
	var client_focus: Control = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	var retain_focus := false
	if client_focus:
		for entry in panels.values():
			if entry.content == client_focus or entry.content.is_ancestor_of(client_focus):
				retain_focus = true
	# Park clients before freeing any obsolete placement nodes. Their complete
	# subtrees stay alive and connected exactly once, including TreeItem selection.
	for entry in panels.values():
		var content: Control = entry.content
		content.hide()
		if content.get_parent() != parking: content.reparent(parking)
	for view in group_views.values():
		if view.get_parent() != parking: view.reparent(parking)
	if is_instance_valid(_graph) and _graph not in group_views.values(): _graph.free()
	_graph = null
	var live_ids: Array = []
	for group in get_panel_groups():
		live_ids.append(group.id)
		if not group_views.has(group.id):
			var view := Group.new()
			parking.add_child(view)
			view.initialize(self, group.id)
			menu_created.emit(view.menu)
			group_views[group.id] = view
		group_views[group.id].configure(group)
	for id in group_views.keys():
		if id not in live_ids:
			group_views[id].free()
			group_views.erase(id)
	if not layout.is_empty():
		_graph = _build_node(layout)
		viewport.add_child(_graph)
	viewport.visible = has_visible_groups()
	custom_minimum_size = Vector2(DEFAULT_WIDTH if viewport.visible else RAIL_WIDTH, 32)
	_sync_panel_buttons()
	if retain_focus and is_instance_valid(client_focus) and client_focus.is_visible_in_tree():
		client_focus.grab_focus()
	call_deferred("_restore_scroll_states", _generation)


func _sync_panel_buttons() -> void:
	for id in panels:
		panels[id].button.set_pressed_no_signal(is_panel_open(id))


func _build_node(node: Dictionary) -> Control:
	if node.type == "group":
		var view: Control = group_views[node.id]
		view.get_parent().remove_child(view)
		return view
	var split: SplitContainer = HSplitContainer.new() if node.axis == "horizontal" else VSplitContainer.new()
	split.size_flags_horizontal = SIZE_EXPAND_FILL
	split.size_flags_vertical = SIZE_EXPAND_FILL
	split.add_theme_constant_override("autohide", 0)
	split.add_theme_constant_override("separation", 10)
	split.add_theme_constant_override("minimum_grab_thickness", 10)
	split.add_child(_build_node(node.first))
	split.add_child(_build_node(node.second))
	split.visible = _node_visible(node)
	split.resized.connect(_apply_ratio.bind(weakref(split), node), CONNECT_DEFERRED)
	split.dragged.connect(_split_dragged.bind(split, node))
	_apply_ratio.call_deferred(weakref(split), node)
	return split


func _apply_ratio(split_ref: WeakRef, node: Dictionary) -> void:
	var split := split_ref.get_ref() as SplitContainer
	if not is_instance_valid(split) or not split.is_inside_tree(): return
	if not _node_visible(node.first) or not _node_visible(node.second): return
	var extent := split.size.y if split.vertical else split.size.x
	var usable := maxf(0, extent - split.get_theme_constant("separation"))
	split.split_offset = roundi(usable * (float(node.ratio) - 0.5))


func _split_dragged(_offset: int, split: SplitContainer, node: Dictionary) -> void:
	var extent := split.size.y if split.vertical else split.size.x
	var usable := maxf(1, extent - split.get_theme_constant("separation"))
	node.ratio = clampf(0.5 + float(split.split_offset) / usable, 0.1, 0.9)
	_save()


func _capture_scroll_states() -> void:
	for id in panels:
		var content: Control = panels[id].content
		if content.is_visible_in_tree():
			var state: Array = []
			_capture_scroll(content, state)
			_scroll_states[id] = state


func _capture_scroll(node: Node, state: Array) -> void:
	if node is ScrollBar: state.append([weakref(node), node.value])
	for child in node.get_children(true): _capture_scroll(child, state)


func _restore_scroll_states(generation: int) -> void:
	if generation != _generation: return
	for id in _scroll_states:
		if not panels.has(id): continue
		if panels[id].content.is_visible_in_tree():
			for item in _scroll_states[id]:
				var bar: Object = item[0].get_ref()
				if bar: bar.value = item[1]


func owns_chrome_focus() -> bool:
	if not is_inside_tree(): return false
	var focused := get_viewport().gui_get_focus_owner()
	if not focused or not is_ancestor_of(focused): return false
	for panel in panels.values():
		if focused == panel.content or panel.content.is_ancestor_of(focused): return false
	return true
