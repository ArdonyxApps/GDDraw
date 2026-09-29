extends SceneTree

const Host := preload("res://addons/GDDraw/gddraw_panel_host.gd")
const Dock := preload("res://addons/GDDraw/gddraw_dock.gd")
const Discovery := preload("res://addons/GDDraw/gddraw_3d_layer_discovery.gd")

class Settings:
	extends RefCounted
	var values := {}
	var writes := 0
	func get_project_metadata(section: String, key: String, fallback: Variant = null) -> Variant:
		return values.get(section + "/" + key, fallback)
	func set_project_metadata(section: String, key: String, value: Variant) -> void:
		values[section + "/" + key] = value.duplicate(true) if value is Dictionary else value
		writes += 1

var assertions := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures.append(message)
		push_error(message)

func settle() -> void:
	for i in range(5): await process_frame

func tree_scroll(tree: Tree) -> VScrollBar:
	for child in tree.get_children(true):
		if child is VScrollBar: return child
	return null

func make_host(count := 5):
	var host := Host.new()
	root.add_child(host)
	host.size = Vector2(480, 360)
	for i in range(count):
		var tree := Tree.new()
		tree.hide_root = true
		tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var parent := tree.create_item()
		for row in range(80):
			var item := tree.create_item(parent)
			item.set_text(0, "Panel %d row %d" % [i, row])
		check(host.register_panel("test_%d" % i, "Temporary Panel %d" % i, null, tree, Vector2(180, 130)), "register temporary panel %d" % i)
	host.restore_layout()
	return host

func _run() -> void:
	root.size = Vector2i(1200, 720)
	if "--demo" in OS.get_cmdline_user_args() or "--screenshot" in OS.get_cmdline_user_args():
		await _demo()
		return
	await _layout_and_lifetime()
	await _independent_toggles()
	await _temporary_panel()
	await _overflow()
	await _drag_input()
	await _reorder_tabs()
	await _validation()
	await _dock_integration()
	await _active_3d_session()
	print("Panel host: %d assertions, %d failures" % [assertions, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _temporary_panel() -> void:
	var host = make_host(2)
	var settings := Settings.new()
	host.restore_layout(settings)
	host.activate_panel("test_0")
	host.activate_panel("test_1")
	host.move_panel("test_1", host.group_for_panel("test_0").id, "right")
	var saved: Dictionary = host.describe_layout()
	var writes := settings.writes
	var content := VBoxContainer.new()
	host.open_temporary_panel("gradient", "Gradient", null, content)
	check(host.is_panel_active("gradient"), "temporary panel becomes active")
	await settle()
	host._capture_scroll_states()
	check(host._scroll_states.has("gradient"), "visible temporary panel has captured scroll state")
	host.set_dock_width(450)
	check(settings.writes == writes, "temporary layout operations never persist")
	host.close_temporary_panel()
	check(not host._scroll_states.has("gradient"), "closing temporary panel clears its captured scroll state")
	await settle()
	# Deferred callbacks must also tolerate stale state from a removed client.
	host._scroll_states["removed_panel"] = []
	host._restore_scroll_states(host._generation)
	host._scroll_states.erase("removed_panel")
	check(host.describe_layout() == saved and settings.writes == writes, "temporary panel restores split layout and active tabs without writes")
	check(is_instance_valid(content) and not content.visible, "temporary content stays alive while parked")
	host.open_temporary_panel("gradient", "Gradient", null, content)
	await settle()
	host._capture_scroll_states()
	host.close_temporary_panel()
	await settle()
	check(host.describe_layout() == saved, "temporary panel can reopen without duplicate registration")
	host.open_temporary_panel("gradient", "Gradient", null, content)
	var gradient_group: String = host.group_for_panel("gradient").id
	host.move_panel("gradient", gradient_group, "bottom")
	check(host.retain_temporary_panel("gradient"), "temporary panel can become persistent")
	var retained: Dictionary = host.describe_layout()
	host.close_temporary_panel()
	check(host.describe_layout() == retained and host.is_panel_open("gradient"), "retaining preserves panel placement and open state")
	var fresh = make_host(2)
	var fresh_content := VBoxContainer.new()
	fresh.register_panel("gradient", "Gradient", null, fresh_content, Vector2(240,200))
	fresh.restore_layout(settings)
	check(fresh.describe_layout() == retained, "retained panel layout survives recreation")
	fresh.unregister_panel("gradient")
	check(not fresh.panels.has("gradient") and fresh.get_panel_groups().size() == 2 and is_instance_valid(fresh_content), "unregister prunes panel-only split and parks client")
	fresh.free()
	host.free()
	await settle()

func _demo() -> void:
	# Temporary clients exist only in this standalone review fixture, never in
	# the production plugin. Use the real dock's View selector for all four modes.
	root.size = Vector2i(1200, 720)
	var dock := Dock.new()
	root.add_child(dock)
	dock.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var host = dock._panel_host
	for i in range(6):
		var content := VBoxContainer.new()
		var field := LineEdit.new()
		field.text = "Temporary panel %d: retained text" % i
		content.add_child(field)
		var list := ItemList.new()
		list.size_flags_vertical = Control.SIZE_EXPAND_FILL
		for row in range(60): list.add_item("Stateful row %d" % row)
		content.add_child(list)
		host.register_panel("temporary_%d" % i, "Test Panel %d" % i, null, content, Vector2(180, 130))
	host.reset_layout()
	host.move_panel("temporary_4", "main", "right")
	host.move_panel("temporary_5", host.group_for_panel("temporary_4").id, "bottom")
	host.set_dock_width(620)
	dock._on_panel_layout_changed()
	await settle()
	print("Panel review fixture: use rail icons, tab arrows, drag tabs, ⋮ placement menus, split handles, and View > Reset Panel Layout.")
	if "--screenshot" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://panel_review.png")
		quit()

func _layout_and_lifetime() -> void:
	var host = make_host()
	var settings := Settings.new()
	host.restore_layout(settings, 410.0, false)
	check(settings.writes == 0, "migration load is read-only")
	check(host.dock_width == 410 and not host.has_visible_groups(), "legacy width and collapsed preference migrate")
	check(host.rail.is_visible_in_tree(), "last collapsed group leaves rail accessible")
	var tree: Tree = host.panels.test_0.content
	var content_id := tree.get_instance_id()
	var item := tree.get_root().get_child(25)
	item.select(0)
	host.toggle_panel("test_0")
	await settle()
	tree_scroll(tree).value = 180
	var scroll: float = tree_scroll(tree).value
	check(scroll > 0, "state fixture has a nonzero Tree scroll")
	var connections := tree.item_selected.get_connections().size()
	for i in range(3):
		host.toggle_panel("test_0")
		await settle()
		check(not host.has_visible_groups(), "active rail click collapses group")
		host.toggle_panel("test_0")
		await settle()
		check(tree.get_selected() == item and tree.get_instance_id() == content_id, "collapse/reopen retains exact control and selected TreeItem")
		check(is_equal_approx(tree_scroll(tree).value, scroll), "collapse/reopen retains scroll")
	host.activate_panel("test_1")
	check(host.panels.test_0.button.button_pressed and host.panels.test_1.button.button_pressed, "rail marks every open tab")
	host.toggle_panel("test_0")
	check(host.has_visible_groups() and host.is_panel_active("test_1") and not host.is_panel_open("test_0"), "inactive open rail click closes only its panel")
	host.toggle_panel("test_0")
	await settle()
	check(tree_scroll(tree).value == scroll, "tab switching retains scroll")
	check(host.move_panel("test_0", "main", "right"), "split active tab horizontally")
	await settle()
	check(host.layout.type == "split" and host.layout.axis == "horizontal", "horizontal split placement")
	check(host._graph is HSplitContainer, "horizontal placement uses native container")
	check(host._graph.get_theme_constant("autohide") == 0 and host._graph.get_theme_constant("minimum_grab_thickness") >= 10, "split handle stays visible and has usable drag target")
	check(tree.get_selected() == item and tree.get_instance_id() == content_id, "split move preserves selection and lifetime")
	check(tree_scroll(tree).value == scroll, "split move retains scroll")
	check(tree.item_selected.get_connections().size() == connections, "moving does not reconnect content signals")
	check(host.move_panel("test_1", "main", "bottom"), "split another tab vertically")
	await settle()
	check(host.layout.first.type == "split" and host.layout.first.axis == "vertical", "nested vertical placement")
	var split: SplitContainer = host._graph
	host.size = Vector2(1000, 600)
	await settle()
	split.split_offset = 90
	split.dragged.emit(90)
	var ratio: float = host.layout.ratio
	check(ratio > 0.5 and ratio < 0.9, "drag persists a normalized split ratio")
	var snapshot: Dictionary = host.describe_layout()
	var fresh = make_host()
	check(fresh.restore_layout(settings), "new host restores project metadata")
	fresh.size = Vector2(1000, 600)
	await settle()
	check(fresh.describe_layout() == snapshot, "restoration retains placement, active tabs, visibility, ratios and width")
	var restored_split: SplitContainer = fresh._graph
	var usable := restored_split.size.x - restored_split.get_theme_constant("separation")
	check(absf(restored_split.get_child(0).size.x / usable - ratio) < 0.01, "restoration applies the saved ratio to actual split geometry")
	check(not fresh.restore_layout(Settings.new()), "other project has independent layout defaults")
	check(not fresh.has_visible_groups(), "project metadata cannot leak across projects")
	fresh.free()
	var own_group: Dictionary = host.group_for_panel("test_0")
	host.collapse_group(own_group.id)
	await settle()
	check(host.layout.ratio == ratio, "collapse retains saved split ratio")
	host.activate_panel("test_0")
	await settle()
	check(host.layout.ratio == ratio, "reopen retains split ratio")
	check(host.move_panel("test_0", "main"), "move tab to another group")
	await settle()
	check(host.get_panel_groups().size() == 2, "empty source group prunes its split")
	check(tree.get_instance_id() == content_id and tree.get_selected() == item, "merge preserves content state")
	host.size = Vector2(280, 360)
	check(host.move_panel("test_2", "main", "right"), "narrow host supports side-by-side panels")
	await settle()
	check(host.viewport.get_h_scroll_bar().max_value > host.viewport.size.x, "narrow dock can scroll to both split panels without shrinking their controls")
	host.size = Vector2(280, 90)
	await settle()
	check(host.viewport.get_v_scroll_bar().max_value > host.viewport.size.y, "short dock can scroll to minimum-height controls")
	for view in host.group_views.values():
		check(view.size.x >= view.custom_minimum_size.x and view.size.y >= view.custom_minimum_size.y, "groups respect both registered minimum dimensions")
	check(host.rail.is_visible_in_tree(), "short dock keeps rail visible")
	host.reset_layout()
	await settle()
	check(host.get_panel_groups().size() == 1 and host.has_visible_groups(), "reset recovers one open tab group")
	check(host.dock_width == Host.DEFAULT_WIDTH, "reset restores default width")
	check(tree.get_instance_id() == content_id and tree.get_selected() == item, "reset does not recreate content")
	check(settings.values["GDDraw/" + Host.METADATA_KEY] == host.describe_layout(), "reset is persisted")
	check(not host.accepts_drag({"gddraw_panel_host": -1, "panel_id": "test_0"}), "foreign host drag rejected")
	check(not host.accepts_drag({"gddraw_panel_host": host.get_instance_id(), "panel_id": "unknown"}), "unknown panel drag rejected")
	check(not host.move_panel("test_0", "missing"), "unknown destination cannot lose a panel")
	host.free()

func _overflow() -> void:
	var host = make_host(8)
	host.reset_layout()
	host.size = Vector2(280, 280)
	host.activate_panel("test_0")
	await settle()
	var group = host.group_views.main
	check(group.previous.visible and group.next.visible, "narrow tabs display both compact arrows")
	check(group.previous.disabled and not group.next.disabled, "first tab disables left arrow only")
	check(group.previous.size.x == 20 and group.next.position.x - group.previous.position.x == 20, "arrow layout uses adjacent 20-pixel buttons with 2-pixel side padding")
	check(not group.previous.tooltip_text.is_empty() and group.previous.focus_mode == Control.FOCUS_ALL, "arrows expose tooltip and keyboard focus")
	for i in range(1, 8):
		group.next.pressed.emit()
		await settle()
		check(host.is_panel_active("test_%d" % i), "overflow navigation reaches tab %d" % i)
		var rect: Rect2 = group.tabs.get_tab_rect(i)
		var offset: int = group.tab_view.scroll_horizontal
		check(rect.position.x >= offset - 1 and rect.end.x <= offset + group.tab_view.size.x + 1, "active overflowing tab %d is fully visible" % i)
	check(group.next.disabled and not group.previous.disabled, "last tab disables right arrow only")
	for i in range(6, -1, -1):
		group.previous.pressed.emit()
		await settle()
		check(host.is_panel_active("test_%d" % i), "reverse navigation reaches tab %d" % i)
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_END
	group._tab_input(key)
	await settle()
	check(host.is_panel_active("test_7"), "End key reaches final tab")
	key.keycode = KEY_HOME
	group._tab_input(key)
	await settle()
	check(host.is_panel_active("test_0"), "Home key reaches first tab")
	group.tabs.grab_focus()
	key.keycode = KEY_RIGHT
	root.push_input(key)
	await settle()
	check(host.is_panel_active("test_1"), "native GUI Right Arrow dispatch advances exactly one tab")
	key.keycode = KEY_LEFT
	root.push_input(key)
	await settle()
	check(host.is_panel_active("test_0"), "native GUI Left Arrow dispatch returns exactly one tab")
	host.size.x = 2000
	await settle()
	check(not group.previous.visible and not group.next.visible, "arrows disappear when all tabs fit")
	check(group.tab_view.scroll_horizontal == 0, "wide tabs reset scroll offset")
	host.size.x = 280
	await settle()
	check(group.next.visible and group.previous.disabled, "narrowing recomputes overflow boundaries")
	group._build_menu()
	check(group.menu.get_popup().item_count >= 6, "keyboard placement menu exposes splits, collapse and reset")
	group._menu_selected(1)
	await settle()
	check(host.layout.type == "split", "placement menu moves active tab into a split")
	host.free()

func _validation() -> void:
	var host = make_host(2)
	host.reset_layout()
	var valid: Dictionary = host.describe_layout()
	var bad_values: Array = [null, [], "layout", {"version": 999}, {"version": 1, "root": null}]
	for field in ["visible", "tabs", "id", "closed"]:
		var bad := valid.duplicate(true)
		bad.root[field] = 12
		bad_values.append(bad)
	var duplicate := valid.duplicate(true)
	duplicate.root.tabs.append("test_0")
	bad_values.append(duplicate)
	var unknown_only := valid.duplicate(true)
	unknown_only.root.tabs = ["missing"]
	bad_values.append(unknown_only)
	var deep := valid.duplicate(true)
	for i in range(20):
		deep.root = {"type": "split", "axis": "horizontal", "ratio": 0.5, "first": deep.root, "second": valid.root}
	bad_values.append(deep)
	for width in [NAN, INF, "wide", {}]:
		var bad := valid.duplicate(true)
		bad.width = width
		bad_values.append(bad)
	for ratio in [NAN, INF, -1, 0, 1, "half"]:
		var bad := valid.duplicate(true)
		bad.root = {"type": "split", "axis": "horizontal", "ratio": ratio, "first": valid.root, "second": valid.root}
		bad_values.append(bad)
	for bad in bad_values:
		check(not host.restore_description(bad, "bad legacy width", []), "malformed description falls back safely")
		check(host.get_panel_groups().size() == 1 and host.group_for_panel("test_0").tabs.size() == 2, "fallback places every registered panel once")
	var unknown := valid.duplicate(true)
	unknown.root.tabs.append("uninstalled")
	unknown.root.active = "uninstalled"
	check(host.restore_description(unknown), "known tabs survive unknown ID and active tab")
	check(host.group_for_panel("test_0").active == "test_0", "unknown active tab selects first known panel")
	var missing := valid.duplicate(true)
	missing.root.tabs = ["test_0"]
	check(host.restore_description(missing) and not host.group_for_panel("test_1").is_empty(), "newly registered panel is reachable after restore")
	check(not host.register_panel("test_0", "Duplicate", null, host.panels.test_0.content, Vector2.ZERO), "duplicate registration rejected")
	check(not host.register_panel("alias", "Alias", null, host.panels.test_0.content, Vector2.ZERO), "one content control cannot own two panel IDs")
	host.free()

func _drag_input() -> void:
	var host = make_host(3)
	host.reset_layout()
	host.size = Vector2(700, 360)
	host.activate_panel("test_0")
	host.move_panel("test_1", "main", "right")
	await settle()
	var origin = host.group_views.main
	var destination_id: String = host.group_for_panel("test_1").id
	var destination = host.group_views[destination_id]
	var start: Vector2 = origin.tabs.global_position + origin.tabs.get_tab_rect(0).get_center()
	var finish: Vector2 = destination.tabs.global_position + Vector2(30, 12)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = start
	press.global_position = press.position
	root.push_input(press)
	var motion := InputEventMouseMotion.new()
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion.position = start + Vector2(25, 0)
	motion.relative = Vector2(25, 0)
	motion.global_position = motion.position
	root.push_input(motion)
	await process_frame
	check(root.gui_is_dragging(), "native tab gesture starts a drag with registered panel data")
	motion.position = finish
	motion.relative = finish - start
	motion.global_position = motion.position
	root.push_input(motion)
	await process_frame
	check(not destination._drop_zone.is_empty(), "native drag supplies visible drop feedback")
	press.pressed = false
	press.position = finish
	press.global_position = press.position
	root.push_input(press)
	await settle()
	if "--forwarded-drag" in OS.get_cmdline_user_args():
		# Some sandboxed DisplayServers return invalid system mouse coordinates
		# during native dragging. Validate the forwarding contract explicitly.
		destination._can_drop_tab(Vector2(30, 12), data_for_panel(host, "test_0"), destination.tabs)
		destination._drop_tab(Vector2(30, 12), data_for_panel(host, "test_0"))
		await settle()
	check(host.group_for_panel("test_0").id == destination_id, "native tab drop moves the panel between groups")
	check(host.group_for_panel("test_0").tabs == ["test_0", "test_1"], "cross-group header drop inserts before the pointed tab")
	check(not root.gui_is_dragging(), "native tab drop ends drag state")
	check(not destination.drop_overlay.visible, "drop overlay releases content input after dragging")
	destination = host.group_views.main
	var data := {"gddraw_panel_host": host.get_instance_id(), "panel_id": "test_0"}
	# Headless DisplayServer does not update the system pointer used by native
	# drag hover coordinates. Exercise the forwarded edge position explicitly.
	check(destination._can_drop_tab(Vector2(6, 90), data, destination), "registered panel edge accepts a forwarded drag")
	check(destination._drop_zone == "left", "forwarded content-edge drag exposes left split feedback")
	destination._drop_tab(Vector2(6, 90), data)
	await settle()
	check(host.get_panel_groups().size() == 3, "content-edge drop callback creates a new split group")
	host.free()

func data_for_panel(host, id: String) -> Dictionary:
	return {"gddraw_panel_host": host.get_instance_id(), "panel_id": id}

func _reorder_tabs() -> void:
	var host = make_host(3)
	var settings := Settings.new()
	host.restore_layout(settings)
	host.reset_layout()
	host.size = Vector2(900, 360)
	await settle()
	var view = host.group_views.main
	var content = host.panels.test_2.content
	var start: Vector2 = view.tabs.global_position + view.tabs.get_tab_rect(2).get_center()
	var finish: Vector2 = view.tabs.global_position + Vector2(4, 12)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = start
	press.global_position = start
	root.push_input(press)
	var motion := InputEventMouseMotion.new()
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion.position = start + Vector2(25, 0)
	motion.relative = Vector2(25, 0)
	motion.global_position = motion.position
	root.push_input(motion)
	await process_frame
	check(root.gui_is_dragging(), "same-group tab gesture starts native drag")
	motion.position = finish
	motion.global_position = finish
	motion.relative = finish - start
	root.push_input(motion)
	await process_frame
	if "--forwarded-drag" in OS.get_cmdline_user_args():
		view._can_drop_tab(Vector2(4, 12), data_for_panel(host, "test_2"), view.tabs)
	check(view._drop_index == 0, "tab header exposes first insertion slot")
	press.pressed = false
	press.position = finish
	press.global_position = finish
	root.push_input(press)
	await settle()
	if "--forwarded-drag" in OS.get_cmdline_user_args():
		view._can_drop_tab(Vector2(4, 12), data_for_panel(host, "test_2"), view.tabs)
		view._drop_tab(Vector2(4, 12), data_for_panel(host, "test_2"))
		await settle()
	check(host.group_for_panel("test_2").tabs == ["test_2", "test_0", "test_1"], "native drag reorders within a tab group")
	check(host.is_panel_active("test_2") and host.panels.test_2.content == content, "reorder retains active panel and content identity")
	check(not root.gui_is_dragging() and not view.drop_overlay.visible, "reorder releases overlay input")
	host.close_panel("test_0")
	check(host.move_panel("test_2", "main", "tab", 3), "tab moves to final insertion slot")
	check(host.group_for_panel("test_2").tabs == ["test_0", "test_1", "test_2"], "moving right adjusts index after removal")
	check(not host.is_panel_open("test_0"), "reordering leaves closed panels closed")
	var writes: int = settings.writes
	check(not host.move_panel("test_2", "main", "tab", 3) and settings.writes == writes, "dropping into own slot does not rewrite layout")
	await settle()
	view = host.group_views.main
	var data := {"gddraw_panel_host": host.get_instance_id(), "panel_id": "test_2"}
	var position: Vector2 = view.tabs.get_tab_rect(0).position + Vector2(4, 12)
	check(view._can_drop_tab(position, data, view.tabs) and view._drop_index == 1, "visible insertion slot accounts for a preceding closed panel")
	view._drop_tab(position, data)
	await settle()
	var fresh = make_host(3)
	fresh.restore_layout(settings)
	check(fresh.group_for_panel("test_2").tabs == ["test_0", "test_2", "test_1"] and not fresh.is_panel_open("test_0"), "reordered tabs and closed state survive restart")
	fresh.activate_panel("test_0")
	check(fresh.group_views.main.tab_ids == ["test_0", "test_2", "test_1"], "reopening restores remembered order")
	fresh.free()
	host.free()

func _dock_integration() -> void:
	var dock := Dock.new()
	dock.custom_minimum_size = Vector2(1000, 560)
	root.add_child(dock)
	await settle()
	var host = dock._panel_host
	var tree: Tree = dock._layers_tree
	host.activate_panel("layers")
	host.set_dock_width(420)
	dock._on_panel_layout_changed()
	await settle()
	check(absf(host.size.x - 420) <= 1, "restored dock width is applied to actual workspace split geometry")
	host.toggle_panel("layers")
	await settle()
	check(absf(host.size.x - Host.RAIL_WIDTH) <= 1, "collapse returns all space except the rail after a resized dock")
	host.toggle_panel("layers")
	await settle()
	check(absf(host.size.x - 420) <= 1, "reopening restores the resized dock width")
	var selected := tree.get_selected()
	var session = dock._layer_session
	var canvas = dock._canvas
	var pixels: PackedByteArray = canvas.get_image_copy().get_data()
	dock._history.push_undo(canvas.get_image_copy())
	dock._history.push_redo(canvas.get_image_copy())
	var undo: Array = dock._history._undo_stack.duplicate()
	var redo: Array = dock._history._redo_stack.duplicate()
	var baseline: Image = dock._document_baseline_image
	var dirty: bool = dock._is_2d_document_dirty()
	var signals_before := tree.item_selected.get_connections().size()
	for i in range(3):
		var temporary := LineEdit.new()
		temporary.text = "State %d" % i
		temporary.caret_column = 5
		temporary.select(1, 4)
		host.register_panel("temporary_%d" % i, "Temporary %d" % i, null, temporary, Vector2(180, 130))
	host.restore_description(host.describe_layout())
	for mode in range(4):
		dock._on_view_mode_selected(mode)
		host.activate_panel("layers")
		host.move_panel("layers", host.group_for_panel("layers").id, "right")
		host.move_panel("temporary_0", host.group_for_panel("temporary_0").id, "bottom")
		host.toggle_panel("layers")
		host.toggle_panel("layers")
		await settle()
		check(host.get_parent() == dock._workspace_layers_split, "panel placement stays outside canvas layout %d" % mode)
		check(tree == dock._layers_tree and tree.get_selected() == selected, "Layers selection survives layout %d" % mode)
		check(session == dock._layer_session and canvas == dock._canvas, "model/canvas lifetime survives layout %d" % mode)
		check(canvas.get_image_copy().get_data() == pixels, "layout %d preserves artwork" % mode)
		dock._on_menu_command(dock.MenuCommand.VIEW_RESET_PANEL_LAYOUT)
		await settle()
		check(host.get_panel_groups().size() == 1, "View reset action recovers layout %d" % mode)
	check(dock._history._undo_stack == undo and dock._history._redo_stack == redo, "all panel operations preserve both history stacks")
	check(tree.item_selected.get_connections().size() == signals_before, "Layers signals connected once across all operations")
	check(dock._document_baseline_image == baseline and dock._is_2d_document_dirty() == dirty, "layout preserves dirty state and baseline identity")
	for i in range(3):
		var field: LineEdit = host.panels["temporary_%d" % i].content
		check(field.text == "State %d" % i and field.caret_column == 5, "temporary client text and caret survive placement")
		check(field.get_selection_from_column() == 1 and field.get_selection_to_column() == 4, "temporary client text selection survives placement")
	dock.free()

func _active_3d_session() -> void:
	var source := MeshInstance3D.new()
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	var image := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color.BLACK)
	material.albedo_texture = ImageTexture.create_from_image(image)
	mesh.surface_set_material(0, material)
	source.mesh = mesh
	root.add_child(source)
	var dock := Dock.new()
	root.add_child(dock)
	await settle()
	dock._begin_3d_layer_session(Discovery.new().discover([source], Discovery.Scope.SELECTED_HIERARCHY), false, false)
	await settle()
	check(dock._texture_3d_layer_coordinator != null, "fixture owns an active 3D texture session")
	var host = dock._panel_host
	host.register_panel("temporary", "Temporary", null, LineEdit.new(), Vector2(180, 130))
	host.restore_description(host.describe_layout())
	var target = dock._layer_session.get_active_target()
	var layer = target.get_selected_layer()
	# Start with dirty artwork and populated undo/redo, not only an empty canvas.
	layer.image.set_pixel(0, 0, Color.RED)
	target.set_selected_layer_image(layer.image)
	var pixels: PackedByteArray = layer.image.get_data()
	var selected: String = target.selected_layer_id
	var dirty: bool = dock._texture_3d_layer_coordinator.is_dirty()
	dock._history.push_undo(image)
	dock._history.push_redo(image)
	var undo: Array = dock._history._undo_stack.duplicate()
	var redo: Array = dock._history._redo_stack.duplicate()
	var tree_root: TreeItem = dock._layers_tree.get_root()
	for mode in range(4):
		dock._on_view_mode_selected(mode)
		await settle()
		# Existing workspace view changes may rebuild render nodes. Capture after
		# that boundary so this assertion isolates panel-placement operations.
		var preview: MeshInstance3D = dock._paint_3d_mesh
		host.activate_panel("layers")
		host.move_panel("layers", host.group_for_panel("layers").id, "bottom")
		host.toggle_panel("layers")
		host.toggle_panel("layers")
		host.reset_layout()
		await settle()
		check(dock._layer_session.get_active_target() == target and target.selected_layer_id == selected, "panel operations preserve active 3D target and selected paint layer in view %d" % mode)
		check(dock._paint_3d_mesh == preview, "panel operations preserve prepared 3D preview in view %d" % mode)
		check(layer.image.get_data() == pixels and dock._texture_3d_layer_coordinator.is_dirty() == dirty, "panel operations preserve dirty 3D pixels in view %d" % mode)
		check(dock._history._undo_stack == undo and dock._history._redo_stack == redo, "panel operations preserve populated session history in view %d" % mode)
		check(dock._layers_tree.get_root() == tree_root, "panel operations do not rebuild Layers in view %d" % mode)
	dock.free()
	source.free()

func _independent_toggles() -> void:
	var host = make_host(2)
	var settings := Settings.new()
	host.restore_layout(settings)
	host.panels.test_0.button.button_pressed = true
	await settle()
	check(host.group_views.main.tab_ids == ["test_0"], "opening first panel shows only its tab")
	host.panels.test_1.button.button_pressed = true
	await settle()
	check(host.group_views.main.tab_ids == ["test_0", "test_1"], "opening second adds adjacent tab")
	check(host.panels.test_0.button.button_pressed and host.panels.test_1.button.button_pressed, "both rail buttons stay highlighted")
	host.activate_panel("test_0")
	check(host.is_panel_open("test_1") and host.panels.test_1.button.button_pressed, "tab selection does not close or unhighlight other panels")
	host.panels.test_0.button.button_pressed = false
	await settle()
	check(host.group_views.main.tab_ids == ["test_1"] and host.is_panel_active("test_1"), "closing active tab selects remaining open tab")
	host.toggle_panel("test_0")
	check(host.group_views.main.tab_ids == ["test_0", "test_1"], "reopening retains original tab order")
	host.move_panel("test_1", "main", "bottom")
	await settle()
	host.layout.ratio = 0.37
	var group_id: String = host.group_for_panel("test_1").id
	host.close_panel("test_1")
	await settle()
	var saved: Dictionary = host.describe_layout()
	check(host.layout.type == "split" and host.layout.ratio == 0.37 and host.is_panel_open("test_0"), "closing split retains placement and other open panel")
	var fresh = make_host(2)
	check(fresh.restore_layout(settings), "per-panel state restores from project storage")
	check(not fresh.is_panel_open("test_1") and fresh.is_panel_open("test_0"), "restoration retains independent open state")
	fresh.toggle_panel("test_1")
	await settle()
	check(fresh.group_for_panel("test_1").id == group_id and fresh.layout.axis == "vertical" and fresh.layout.ratio == 0.37, "reopening after restart restores split orientation and ratio")
	check(fresh.panels.test_0.button.button_pressed and fresh.panels.test_1.button.button_pressed, "restored open panels both highlighted")
	host.close_panel("test_0")
	check(not host.has_visible_groups() and host.rail.is_visible_in_tree(), "closing final panel leaves only rail")
	check(host.layout.type == saved.root.type, "closing final panel retains split tree")
	var legacy := {"version": 1, "width": 380, "root": {"type": "group", "id": "legacy", "tabs": ["test_0"], "active": "test_0", "visible": true}}
	check(fresh.restore_description(legacy) and fresh.is_panel_open("test_0") and not fresh.is_panel_open("test_1"), "old Layers-only layout does not auto-open new panels")
	host.free()
	fresh.free()
