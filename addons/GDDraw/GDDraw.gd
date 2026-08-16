@tool
extends EditorPlugin

const DOCK_SCENE_PATH := "res://addons/GDDraw/gddraw_dock.tscn"
const PLUGIN_VERSION := "0.2.0"
const DOCK_META_KEY := "gddraw_bottom_panel_dock"
const ADDON_PATH_PREFIX := "res://addons/GDDraw/"
const MINIMUM_BOTTOM_PANEL_HEIGHT := 360.0

var _dock: Control
var _bottom_panel_button: Button


func _enter_tree() -> void:
	_cleanup_orphaned_docks()
	_dock = _make_dock()
	if not _dock:
		_dock = _make_dock_load_error("Could not instantiate GDDraw dock.")
	_dock.name = "GDDraw"
	_dock.custom_minimum_size.y = MINIMUM_BOTTOM_PANEL_HEIGHT
	_dock.set_meta(DOCK_META_KEY, true)
	_dock.set_meta("gddraw_plugin", self)
	if _dock.has_method("setup"):
		_dock.call("setup", self)
	_bottom_panel_button = add_control_to_bottom_panel(_dock, "GDDraw")
	make_bottom_panel_item_visible(_dock)
	call_deferred("_initialize_dock")


func _exit_tree() -> void:
	if _dock:
		remove_control_from_bottom_panel(_dock)
		_dock.queue_free()
		_dock = null
	_bottom_panel_button = null


func _make_dock_load_error(message: String) -> Control:
	var container := VBoxContainer.new()
	container.name = "GDDraw"
	var label := _make_error_label(message)
	container.add_child(label)
	return container


func _make_dock() -> Control:
	var dock_scene := ResourceLoader.load(DOCK_SCENE_PATH, "PackedScene", ResourceLoader.CACHE_MODE_REPLACE)
	if not dock_scene or not dock_scene is PackedScene:
		return null
	return (dock_scene as PackedScene).instantiate() as Control


func _initialize_dock() -> void:
	if not _dock:
		return
	if _dock.has_method("setup"):
		_dock.call("setup", self)
	if _dock.has_method("initialize"):
		_dock.call("initialize")


func _cleanup_orphaned_docks() -> void:
	var base_control := get_editor_interface().get_base_control()
	if not base_control:
		return
	for control in base_control.find_children("GDDraw", "Control", true, false):
		if control is Control and _is_gddraw_dock_control(control):
			if control == _dock:
				continue
			var parent := control.get_parent()
			if parent:
				parent.remove_child(control)
			control.queue_free()


func _is_gddraw_dock_control(control: Control) -> bool:
	if control.has_meta(DOCK_META_KEY):
		return true
	if control.name != "GDDraw":
		return false
	var script := control.get_script()
	if script and script is Script:
		var script_path := (script as Script).resource_path
		if script_path.begins_with(ADDON_PATH_PREFIX):
			return true
	return _contains_old_gddraw_error(control)


func _contains_old_gddraw_error(root: Control) -> bool:
	for child in root.find_children("*", "Label", true, false):
		if child is Label and (child as Label).text.begins_with("GDDraw dock script did not initialize"):
			return true
	return false


func _make_error_label(message: String) -> Label:
	var label := Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return label
