@tool
extends VBoxContainer
signal color_requested(color: Color, background: bool)
signal filesystem_refresh_requested

const Store := preload("res://addons/GDDraw/gddraw_palette_store.gd")
const Grid := preload("res://addons/GDDraw/gddraw_palette_grid.gd")
var model: RefCounted
var dropdown: OptionButton
var menu: MenuButton
var scroll: ScrollContainer
var grid: Control
var attribution_footer: RichTextLabel
var empty: VBoxContainer
var import_dialog: FileDialog
var export_dialog: FileDialog
var export_options: ConfirmationDialog
var export_format: OptionButton
var remove_dialog: ConfirmationDialog
var error_dialog: AcceptDialog
var _shown_id := ""
var _view_states := {}
var _remove_id := ""
var _restore_frames := 0
var _pending_scroll := 0
var new_button: Button
var save_button: Button
var settings: Object
var palette_folder := "res://gddraw/palettes"
var bundled_folder := Store.BUNDLED_FOLDER
var name_dialog: ConfirmationDialog
var name_edit: LineEdit
var save_dialog: ConfirmationDialog
var replace_dialog: ConfirmationDialog
var dirty_dialog: ConfirmationDialog
var color_dialog: ConfirmationDialog
var color_picker: ColorPicker
var color_name: LineEdit
var swatch_menu: PopupMenu
var _new_mode := false
var _save_as_new := false
var _save_path := ""
var _save_name := ""
var _color_index := -1
var _pending_action := Callable()
var _file_refresh_pending := false

func _init(store: RefCounted = null) -> void:
	name = "Palettes Panel Content"
	model = store if store else Store.new()
	add_theme_constant_override("separation", 3)
	var toolbar := HBoxContainer.new()
	add_child(toolbar)
	new_button = Button.new()
	new_button.text = "+"
	new_button.custom_minimum_size = Vector2(28, 28)
	new_button.tooltip_text = "New Palette"
	new_button.pressed.connect(func(): _guard(_show_new))
	toolbar.add_child(new_button)
	save_button = Button.new()
	save_button.text = "Save"
	save_button.custom_minimum_size = Vector2(28, 28)
	save_button.tooltip_text = "Save Palette"
	save_button.pressed.connect(_show_save)
	toolbar.add_child(save_button)
	dropdown = OptionButton.new()
	dropdown.size_flags_horizontal = SIZE_EXPAND_FILL
	dropdown.fit_to_longest_item = false
	dropdown.clip_text = true
	dropdown.custom_minimum_size.x = 64
	dropdown.tooltip_text = "Palette to view (does not change drawing colors)"
	dropdown.item_selected.connect(_select)
	toolbar.add_child(dropdown)
	menu = MenuButton.new()
	menu.custom_minimum_size = Vector2(28, 28)
	menu.tooltip_text = "Palette actions"
	menu.get_popup().add_item("Import Palette…", 0)
	menu.get_popup().add_item("Remove Palette…", 1)
	menu.get_popup().add_item("New Palette…", 2)
	menu.get_popup().add_item("Save Palette…", 3)
	menu.get_popup().add_item("Rescan Palette Folder", 4)
	menu.get_popup().add_item("Export HEX…", 5)
	menu.get_popup().add_item("Restore Bundled Palettes", 6)
	menu.get_popup().add_separator("Colors")
	menu.get_popup().add_item("Edit Selected Color…", 20)
	menu.get_popup().add_item("Remove Selected Color", 21)
	menu.get_popup().add_item("Undo Palette Edit", 22)
	menu.get_popup().add_item("Redo Palette Edit", 23)
	menu.get_popup().about_to_popup.connect(_refresh_color_actions)
	menu.get_popup().add_separator("View")
	for i in range(4): menu.get_popup().add_radio_check_item(["Small Tiles", "Medium Tiles", "Large Tiles", "Horizontal Rows"][i], 10 + i)
	menu.get_popup().id_pressed.connect(_menu_action)
	toolbar.add_child(menu)
	empty = VBoxContainer.new()
	add_child(empty)
	var label := Label.new()
	label.text = "No palettes yet."
	empty.add_child(label)
	var import_button := Button.new()
	import_button.text = "Import Palette…"
	import_button.pressed.connect(_show_import)
	empty.add_child(import_button)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Reserve the bar so wrapping never oscillates as the last row appears.
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	add_child(scroll)
	grid = Grid.new()
	grid.editable = true
	grid.add_requested.connect(func(): _show_color(-1))
	grid.edit_requested.connect(_show_swatch_menu)
	grid.remove_requested.connect(_remove_swatch)
	grid.undo_requested.connect(func(): _report(model.undo_swatches()))
	grid.redo_requested.connect(func(): _report(model.redo_swatches()))
	scroll.add_child(grid)
	scroll.get_v_scroll_bar().value_changed.connect(func(_value: float): grid.queue_redraw())
	grid.color_requested.connect(func(color: Color, background: bool): color_requested.emit(color, background))
	attribution_footer = RichTextLabel.new()
	attribution_footer.fit_content = true
	attribution_footer.scroll_active = false
	attribution_footer.bbcode_enabled = false
	attribution_footer.add_theme_font_size_override("normal_font_size", 12)
	attribution_footer.meta_clicked.connect(_open_attribution_link)
	add_child(attribution_footer)
	import_dialog = FileDialog.new()
	import_dialog.title = "Import Palette"
	import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	import_dialog.access = FileDialog.ACCESS_FILESYSTEM
	import_dialog.filters = PackedStringArray(["*.gddrawpalette ; GDDraw palette", "*.gpl ; GIMP palette", "*.hex,*.txt ; Hex colors"])
	import_dialog.file_selected.connect(import_palette)
	add_child(import_dialog)
	export_options = ConfirmationDialog.new()
	export_options.title = "Export HEX"
	export_options.ok_button_text = "Choose File"
	var export_box := VBoxContainer.new()
	var export_hint := Label.new()
	export_hint.text = "Export a copy. RGB omits transparency; RGBA preserves it."
	export_box.add_child(export_hint)
	export_format = OptionButton.new()
	export_format.add_item("RGBA — RRGGBBAA (preserve alpha)")
	export_format.add_item("RGB — RRGGBB (opaque colors)")
	export_box.add_child(export_format)
	export_options.add_child(export_box)
	export_options.confirmed.connect(func():
		export_dialog.current_dir = Store.canonical_source(palette_folder)
		export_dialog.current_file = Store.filename_for(str(model.get_palette(model.active_id).get("name", "palette"))).get_basename() + ("-rgba.hex" if export_format.selected == 0 else "-rgb.hex")
		export_dialog.popup_centered_ratio(0.7))
	add_child(export_options)
	export_dialog = FileDialog.new()
	export_dialog.title = "Export HEX Copy"
	export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	export_dialog.access = FileDialog.ACCESS_FILESYSTEM
	export_dialog.filters = PackedStringArray(["*.hex ; HEX palette"])
	export_dialog.file_selected.connect(_export_palette)
	add_child(export_dialog)
	remove_dialog = ConfirmationDialog.new()
	remove_dialog.title = "Remove Palette"
	remove_dialog.confirmed.connect(func(): _report(model.remove_palette(_remove_id)))
	add_child(remove_dialog)
	error_dialog = AcceptDialog.new()
	error_dialog.title = "Palettes"
	add_child(error_dialog)
	_build_authoring_dialogs()
	model.changed.connect(_refresh)
	_refresh()

func _ready() -> void:
	if not new_button.has_meta("inactive_icon_name") and has_theme_icon("Add", "EditorIcons"):
		new_button.icon = get_theme_icon("Add", "EditorIcons")
		new_button.text = ""
	if not save_button.has_meta("inactive_icon_name") and has_theme_icon("Save", "EditorIcons"):
		save_button.icon = get_theme_icon("Save", "EditorIcons")
		save_button.text = ""
	if not model.load_error.is_empty(): _show_error.call_deferred(model.load_error)
	elif not model.load_warning.is_empty(): _show_error.call_deferred(model.load_warning)

func owns_input_focus() -> bool:
	var focused := get_viewport().gui_get_focus_owner()
	for child in get_children():
		if child is Window and child.visible: return true
	return focused == self or (focused and is_ancestor_of(focused))

func _refresh() -> void:
	if not _shown_id.is_empty(): _view_states[_shown_id] = {"index": grid.focused_index, "scroll": scroll.scroll_vertical}
	for id in _view_states.keys():
		if model.get_palette(id).is_empty(): _view_states.erase(id)
	dropdown.clear()
	for palette in model.palettes:
		# Keep text shaping bounded even when an imported name fills the input file.
		dropdown.add_item(str(palette.name).left(160) + (" (Bundled)" if Store.is_bundled(palette) else "") + (" *" if palette.get("dirty", false) else ""))
		dropdown.set_item_metadata(dropdown.item_count - 1, palette.id)
		if palette.id == model.active_id: dropdown.select(dropdown.item_count - 1)
	dropdown.disabled = model.palettes.is_empty()
	save_button.disabled = model.palettes.is_empty()
	menu.get_popup().set_item_disabled(menu.get_popup().get_item_index(5), model.palettes.is_empty())
	menu.get_popup().set_item_disabled(menu.get_popup().get_item_index(3), model.palettes.is_empty())
	menu.get_popup().set_item_disabled(1, model.palettes.is_empty())
	empty.visible = model.palettes.is_empty()
	scroll.visible = not model.palettes.is_empty()
	_shown_id = model.active_id
	var palette: Dictionary = model.get_palette(_shown_id)
	_refresh_attribution(palette)
	menu.get_popup().set_item_text(menu.get_popup().get_item_index(1), "Hide Bundled Palette…" if Store.is_bundled(palette) else "Remove Palette…")
	menu.get_popup().set_item_disabled(menu.get_popup().get_item_index(6), model.hidden_bundled.is_empty())
	var state: Dictionary = _view_states.get(_shown_id, {"index": 0, "scroll": 0})
	grid.set_swatches(palette.get("swatches", []), state.index)
	_refresh_color_actions()
	_pending_scroll = state.scroll
	_restore_frames = 3
	set_process(true)

func _refresh_attribution(palette: Dictionary) -> void:
	attribution_footer.clear()
	var credit: Dictionary = palette.get("attribution", {})
	attribution_footer.visible = not credit.is_empty()
	attribution_footer.tooltip_text = str(credit.get("license", ""))
	if credit.is_empty(): return
	var derived: bool = palette.get("attribution_derived", false) or palette.get("dirty", false)
	attribution_footer.add_text("Based on a palette by " if derived else "Palette by ")
	var url: String = credit.get("url", "")
	var linked := Store.attribution_url_allowed(url)
	if linked: attribution_footer.push_meta(url)
	attribution_footer.add_text(credit.author)
	if linked: attribution_footer.pop()

func _open_attribution_link(meta: Variant) -> void:
	if meta is String and Store.attribution_url_allowed(meta): OS.shell_open(meta)

func _process(_delta: float) -> void:
	# Minimum height and scrollbar range settle separately. Node-owned processing
	# coalesces newer requests and stops automatically if the panel is freed.
	_restore_frames -= 1
	if _restore_frames <= 0:
		scroll.scroll_vertical = _pending_scroll
		set_process(false)

func _select(index: int) -> void:
	var id: String = dropdown.get_item_metadata(index)
	_refresh()
	if id != model.active_id: _guard(func(): _report(model.select_palette(id)))

func _refresh_color_actions() -> void:
	var valid: bool = grid.focused_index >= 0 and grid.focused_index < grid.swatches.size()
	for id in [20, 21]: menu.get_popup().set_item_disabled(menu.get_popup().get_item_index(id), not valid)
	menu.get_popup().set_item_disabled(menu.get_popup().get_item_index(22), not model.can_undo_swatches())
	menu.get_popup().set_item_disabled(menu.get_popup().get_item_index(23), not model.can_redo_swatches())

func _remove_swatch(index: int) -> void:
	_report(model.edit_swatch(index, Color.WHITE, "", true))

func _menu_action(id: int) -> void:
	if id == 20:
		if grid.focused_index < grid.swatches.size(): _show_color(grid.focused_index)
	elif id == 21:
		if grid.focused_index < grid.swatches.size(): _remove_swatch(grid.focused_index)
	elif id == 22: _report(model.undo_swatches())
	elif id == 23: _report(model.redo_swatches())
	elif id >= 10 and id <= 13:
		_set_view(id - 10)
	elif id == 0: _guard(_show_import)
	elif id == 2: _guard(_show_new)
	elif id == 3: _show_save()
	elif id == 4: rescan()
	elif id == 5: export_options.popup_centered()
	elif id == 6:
		var restored: Dictionary = model.restore_bundled()
		_report(restored)
		if restored.ok: rescan()
	elif id == 1:
		_guard(_show_remove.bind(model.active_id))

func _show_remove(id := "") -> void:
	_remove_id = model.active_id if id.is_empty() else id
	var palette: Dictionary = model.get_palette(_remove_id)
	if palette.is_empty(): return
	remove_dialog.dialog_text = "Remove “%s” from this project?\nThe original import file will be kept." % str(palette.name).left(160)
	var bundled := Store.is_bundled(palette)
	remove_dialog.title = "Hide Bundled Palette" if bundled else "Remove Palette"
	remove_dialog.ok_button_text = "Hide" if bundled else "Remove"
	if bundled:
		remove_dialog.dialog_text = "Hide “%s” in this project?\nThe packaged file is kept. Use Restore Bundled Palettes to show it again." % str(palette.name).left(160)
	remove_dialog.popup_centered(Vector2i(380, 140))

func _show_import() -> void:
	import_dialog.popup_centered_ratio(0.7)

func import_palette(path: String) -> void:
	var result: Dictionary = model.import_file(path)
	_report(result)
	if result.ok: _queue_file_refresh()

func _export_palette(path: String) -> void:
	var result: Dictionary = model.export_hex(path, export_format.selected == 0, true)
	_report(result)
	if result.ok: _queue_file_refresh()

func _queue_file_refresh() -> void:
	if _file_refresh_pending: return
	_file_refresh_pending = true
	_refresh_files.call_deferred()

func _refresh_files() -> void:
	_file_refresh_pending = false
	# Let file dialogs finish closing before scanning or refreshing their lists.
	rescan()
	_refresh()
	import_dialog.invalidate()
	export_dialog.invalidate()
	filesystem_refresh_requested.emit()

func _report(result: Dictionary) -> void:
	if not result.ok: _show_error(result.error)

func _show_error(message: String) -> void:
	error_dialog.dialog_text = message
	error_dialog.popup_centered(Vector2i(440, 140))

func set_colors(foreground: Color, background: Color) -> void:
	grid.set_colors(foreground, background)

func configure(editor_settings: Object, folder: String) -> void:
	settings = editor_settings
	palette_folder = folder
	_set_view(int(settings.get_project_metadata("GDDraw", "palette_view", 1)) if settings else 1)
	rescan.call_deferred()

func rescan() -> void:
	var selected: String = model.active_id
	var result: Dictionary = model.scan_folder(palette_folder)
	var bundled: Dictionary = model.scan_folder(bundled_folder, true)
	result.warnings.append_array(bundled.warnings)
	if not selected.is_empty() and model.active_id != selected: _report(model.select_palette(selected))
	if not result.warnings.is_empty(): _show_error("\n".join(result.warnings))

func _set_view(mode: int) -> void:
	mode = clampi(mode, 0, 3)
	grid.set_view(mode)
	for i in range(4): menu.get_popup().set_item_checked(menu.get_popup().get_item_index(10 + i), mode == i)
	if settings: settings.set_project_metadata("GDDraw", "palette_view", mode)

func _build_authoring_dialogs() -> void:
	name_dialog = ConfirmationDialog.new()
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Palette name"
	name_edit.max_length = 160
	name_edit.custom_minimum_size.x = 320
	name_dialog.add_child(name_edit)
	name_dialog.confirmed.connect(_name_confirmed)
	name_edit.text_submitted.connect(func(_text: String): name_dialog.hide(); _name_confirmed())
	name_dialog.canceled.connect(_cancel_action)
	add_child(name_dialog)
	save_dialog = ConfirmationDialog.new()
	save_dialog.title = "Save Palette"
	save_dialog.dialog_text = "Save changes to this palette or create a new palette file."
	save_dialog.ok_button_text = "Save Changes"
	save_dialog.add_button("Save as New Palette…", true, "new")
	save_dialog.confirmed.connect(_save_existing)
	save_dialog.custom_action.connect(func(_action: String): save_dialog.hide(); _show_save_name(true))
	save_dialog.canceled.connect(_cancel_action)
	add_child(save_dialog)
	replace_dialog = ConfirmationDialog.new()
	replace_dialog.title = "Replace Palette File"
	replace_dialog.confirmed.connect(func(): _perform_save(true))
	replace_dialog.canceled.connect(_cancel_action)
	add_child(replace_dialog)
	dirty_dialog = ConfirmationDialog.new()
	dirty_dialog.title = "Unsaved Palette Changes"
	dirty_dialog.dialog_text = "Save your palette changes before continuing?"
	dirty_dialog.ok_button_text = "Save"
	dirty_dialog.add_button("Discard", true, "discard")
	dirty_dialog.confirmed.connect(_show_save)
	dirty_dialog.custom_action.connect(func(_action: String):
		dirty_dialog.hide()
		var result: Dictionary = model.discard_changes()
		if result.ok: _finish_action()
		else: _report(result))
	dirty_dialog.canceled.connect(_cancel_action)
	add_child(dirty_dialog)
	color_dialog = ConfirmationDialog.new()
	var color_scroll := ScrollContainer.new()
	color_scroll.custom_minimum_size = Vector2(300, 250)
	color_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	color_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	color_dialog.add_child(color_scroll)
	var color_box := VBoxContainer.new()
	color_box.size_flags_horizontal = SIZE_EXPAND_FILL
	color_scroll.add_child(color_box)
	color_picker = ColorPicker.new()
	color_picker.edit_alpha = true
	color_picker.picker_shape = ColorPicker.SHAPE_HSV_WHEEL
	color_box.add_child(color_picker)
	color_name = LineEdit.new()
	color_name.placeholder_text = "Color name (optional)"
	color_name.max_length = 160
	color_box.add_child(color_name)
	color_dialog.confirmed.connect(func():
		var palette: Dictionary = model.get_palette(model.active_id)
		if not palette.is_empty(): _report(model.edit_swatch(palette.swatches.size() if _color_index < 0 else _color_index, color_picker.color, color_name.text)))
	add_child(color_dialog)
	swatch_menu = PopupMenu.new()
	swatch_menu.add_item("Edit Color…", 0)
	swatch_menu.add_item("Remove Color", 1)
	swatch_menu.id_pressed.connect(func(id: int):
		if id == 0: _show_color(_color_index)
		else: _report(model.edit_swatch(_color_index, Color.WHITE, "", true)))
	add_child(swatch_menu)

func _guard(action: Callable) -> void:
	if model.get_palette(model.active_id).get("dirty", false):
		_pending_action = action
		dirty_dialog.popup_centered()
	else: action.call()

func _cancel_action() -> void:
	_pending_action = Callable()

func _finish_action() -> void:
	var action := _pending_action
	_pending_action = Callable()
	if action.is_valid(): action.call()

func _show_new() -> void:
	_new_mode = true
	name_dialog.title = "New Palette"
	name_dialog.ok_button_text = "Create"
	name_edit.text = ""
	name_dialog.popup_centered()
	name_edit.grab_focus()

func _name_confirmed() -> void:
	if _new_mode:
		_report(model.new_palette(name_edit.text))
	else:
		_save_name = name_edit.text.strip_edges()
		_save_path = palette_folder.path_join(Store.filename_for(_save_name))
		_perform_save()

func _show_save() -> void:
	if model.get_palette(model.active_id).is_empty(): return
	if Store.is_bundled(model.get_palette(model.active_id)):
		_show_save_name(true)
		return
	save_dialog.popup_centered()

func _save_existing() -> void:
	var palette: Dictionary = model.get_palette(model.active_id)
	if Store.is_bundled(palette):
		_show_save_name(true)
		return
	var source: String = palette.get("source", "")
	if source.get_extension().to_lower() != "hex":
		_show_save_name(false)
		return
	_save_as_new = false
	_save_name = palette.name
	_save_path = source
	_perform_save()

func _show_save_name(as_new: bool) -> void:
	_new_mode = false
	_save_as_new = as_new
	name_dialog.title = "Save as New Palette" if as_new else "Save HEX Palette"
	if Store.is_bundled(model.get_palette(model.active_id)): name_dialog.title = "Save Bundled Palette as Copy"
	name_dialog.ok_button_text = "Save"
	name_edit.text = str(model.get_palette(model.active_id).get("name", "")) + (" Copy" if as_new else "")
	name_dialog.popup_centered()
	name_edit.grab_focus()
	name_edit.select_all()

func _perform_save(overwrite := false) -> void:
	var result: Dictionary = model.save_palette(_save_path, _save_name, _save_as_new, overwrite)
	if result.get("needs_confirmation", false):
		replace_dialog.dialog_text = "Replace %s?" % _save_path
		replace_dialog.popup_centered()
	elif result.ok:
		_queue_file_refresh()
		_finish_action()
	else:
		_cancel_action()
		_report(result)

func _show_color(index: int) -> void:
	var palette: Dictionary = model.get_palette(model.active_id)
	if palette.is_empty(): return
	_color_index = index
	color_dialog.title = "Add Color" if index < 0 else "Edit Color"
	color_dialog.ok_button_text = "Add" if index < 0 else "Apply"
	color_picker.color = Color.WHITE if index < 0 else Color(palette.swatches[index].color)
	color_name.text = "" if index < 0 else str(palette.swatches[index].name)
	color_dialog.popup_centered(Vector2i(340, mini(720, int(get_viewport_rect().size.y * 0.85))))

func _show_swatch_menu(index: int) -> void:
	_color_index = index
	swatch_menu.position = Vector2i(get_screen_position() + get_local_mouse_position())
	swatch_menu.popup()
