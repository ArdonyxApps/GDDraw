extends SceneTree

const Parser := preload("res://addons/GDDraw/gddraw_palette_parser.gd")
const Store := preload("res://addons/GDDraw/gddraw_palette_store.gd")
const PalettePanel := preload("res://addons/GDDraw/gddraw_palette_panel.gd")
const Dock := preload("res://addons/GDDraw/gddraw_dock.gd")
const Discovery := preload("res://addons/GDDraw/gddraw_3d_layer_discovery.gd")

class FailedStore:
	extends Store
	var fail_write := false
	func _replace_file(temporary: String, destination: String) -> Error:
		return ERR_CANT_CREATE if fail_write else super._replace_file(temporary, destination)

var assertions := 0

class ExtensionSettings:
	extends RefCounted
	var value := "txt,md,json"
	var writes := 0
	func has_setting(_key: String) -> bool: return true
	func get_setting(_key: String) -> String: return value
	func set_setting(_key: String, updated: String) -> void:
		value = updated
		writes += 1

class PreferencesDock:
	extends Dock
	var test_settings: Object
	func _get_editor_settings() -> Object: return test_settings

var failures: Array[String] = []
var directory := "res://palette_test_" + str(Time.get_ticks_usec())

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	assertions += 1
	if not value:
		failures.append(message)
		push_error(message)

func settle() -> void:
	for i in range(6): await process_frame

func write(path: String, contents: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(contents)
	file.close()

func _run() -> void:
	root.size = Vector2i(1200, 720)
	_parser()
	_file_visibility()
	_storage()
	_authoring()
	await _bundled()
	await _attribution()
	await _swatch_history_checks()
	await _authoring_ui()
	await _file_refresh()
	await _panel()
	await _dock()
	await _preferences_ui()
	await _session()
	print("Palettes: %d assertions, %d failures" % [assertions, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _file_visibility() -> void:
	var settings := ExtensionSettings.new()
	check(Dock._missing_palette_file_extensions(settings) == PackedStringArray(["hex", "gpl"]) and settings.writes == 0, "checking visibility does not change editor settings")
	check(Dock._register_palette_file_extensions(settings) and settings.value == "txt,md,json,hex,gpl", "enable preserves existing extensions and appends palette types")
	Dock._register_palette_file_extensions(settings)
	check(settings.writes == 1, "repeated enable does not duplicate extensions or write again")
	settings.value = "txt, HEX ,gpl,custom"
	check(Dock._missing_palette_file_extensions(settings).is_empty(), "visibility detection accepts case and surrounding whitespace")
	settings.value = "txt,hex,"
	Dock._register_palette_file_extensions(settings)
	check(settings.value == "txt,hex,gpl", "partial registration adds only missing extension")
	check(not Dock._register_palette_file_extensions(null), "missing editor settings handled without writes")

func _preferences_ui() -> void:
	var dock := PreferencesDock.new()
	root.add_child(dock)
	await settle()
	var settings := ExtensionSettings.new()
	dock.test_settings = settings
	dock._refresh_palette_file_visibility()
	dock._palette_extensions_button.pressed.emit()
	check(dock._palette_extensions_dialog.visible and settings.writes == 0, "Enable opens confirmation without changing settings")
	dock._palette_extensions_dialog.get_cancel_button().pressed.emit()
	dock._palette_extensions_dialog.hide()
	check(settings.writes == 0, "Cancel preserves editor extensions")
	dock._palette_extensions_button.pressed.emit()
	dock._palette_extensions_dialog.confirmed.emit()
	dock._palette_extensions_dialog.hide()
	check(settings.writes == 1 and dock._palette_extensions_button.text == "Enabled" and dock._resource_filesystem_scan_pending, "Continue enables extensions and schedules filesystem refresh")
	dock.test_settings = null
	var tabs := TabContainer.new()
	tabs.size = Vector2(400, 150)
	root.add_child(tabs)
	for title in ["Tools", "View", "Files"]:
		var content := dock._add_preferences_tab(tabs, title)
		var tall := Control.new()
		tall.custom_minimum_size = Vector2(200, 600)
		content.add_child(tall)
	for index in range(3):
		tabs.current_tab = index
		await settle()
		var tab_scroll: ScrollContainer = tabs.get_tab_control(index)
		check(tab_scroll.get_v_scroll_bar().visible and tabs.size.y <= 150, "preference tab %d scrolls instead of expanding past available height" % index)
		tab_scroll.scroll_vertical = 10000
		check(tab_scroll.scroll_vertical > 0 and tab_scroll.follow_focus, "preference tab %d supports scrolling and keyboard focus following" % index)
	tabs.queue_free()
	dock.queue_free()
	await settle()

func _bundled() -> void:
	var folder := directory + "/bundled"
	var users := directory + "/users"
	write(folder + "/starter.hex", "112233\n44556677\n")
	write(folder + "/README.txt", "Not a palette")
	write(users + "/starter.hex", "abcdef\n")
	var model := FailedStore.new(directory + "/bundled_collection.json")
	model.scan_folder(users)
	check(model.scan_folder(folder, true).warnings.is_empty(), "bundled scan ignores documentation")
	check(model.palettes.size() == 2, "same-named user and bundled palettes coexist")
	var starter: Dictionary = model.palettes[1]
	var id: String = starter.id
	check(Store.is_bundled(starter), "bundled source is marked")
	model.scan_folder(folder, true)
	check(model.palettes.size() == 2 and model.palettes[1].id == id, "repeat bundled scan keeps identity")
	var moved := directory + "/moved_bundle"
	write(moved + "/starter.hex", "112233\n44556677\n")
	model.scan_folder(moved, true)
	check(model.palettes.size() == 2 and model.get_palette(id).source == Store.canonical_source(moved + "/starter.hex"), "bundle relocation preserves identity")
	model.select_palette(id)
	model.edit_swatch(0, Color.RED)
	write(moved + "/starter.hex", "ffffff\n")
	check(model.scan_folder(moved, true).warnings.size() == 1 and model.get_palette(id).swatches[0].color == "ff0000ff", "bundle update protects edited colors")
	var original := FileAccess.get_file_as_string(moved + "/starter.hex")
	check(model.save_palette(users + "/copy.hex", "Starter Copy", false).ok, "bundled save automatically creates a copy")
	check(model.active_id != id and not Store.is_bundled(model.get_palette(model.active_id)), "saved copy is independent user palette")
	check(FileAccess.get_file_as_string(users + "/copy.hex").begins_with("FF0000FF") and FileAccess.get_file_as_string(moved + "/starter.hex") == original, "copy retains edits and packaged bytes stay intact")
	check(not model.get_palette(id).dirty, "successful copy clears bundled draft")
	model.scan_folder(moved, true)
	check(model.get_palette(id).swatches[0].color == "ffffffff", "clean bundle accepts source updates")
	model.fail_write = true
	check(not model.remove_palette(id).ok and model.hidden_bundled.is_empty() and not model.get_palette(id).is_empty(), "failed hide preserves collection state")
	model.fail_write = false
	check(model.remove_palette(id).ok and model.hidden_bundled == ["starter.hex"], "hide records bundled filename")
	model = FailedStore.new(model.path)
	model.scan_folder(moved, true)
	check(model.palettes.size() == 2 and model.get_palette(id).is_empty(), "hidden bundle stays hidden after reload")
	check(FileAccess.get_file_as_string(moved + "/starter.hex") == original, "hide preserves bundled file")
	check(model.restore_bundled().ok, "restore clears hidden choices")
	model.scan_folder(moved, true)
	check(model.palettes.size() == 3, "restore rediscovers bundled palette")
	model.select_palette(model.palettes[2].id)
	var panel := PalettePanel.new(model)
	panel.palette_folder = users
	panel.bundled_folder = moved
	root.add_child(panel)
	await settle()
	check(panel.dropdown.get_item_text(panel.dropdown.selected).contains("(Bundled)"), "selector labels bundled palettes")
	check(panel.menu.get_popup().get_item_text(panel.menu.get_popup().get_item_index(1)) == "Hide Bundled Palette…", "bundled menu offers hide")
	panel._show_save()
	check(panel.name_dialog.visible and not panel.save_dialog.visible and panel._save_as_new, "bundled save asks for user copy")
	panel.name_dialog.hide()
	model.remove_palette(model.active_id)
	panel._menu_action(6)
	check(model.palettes.size() == 3 and model.hidden_bundled.is_empty(), "panel restore scans bundled source")
	write(users + "/another.hex", "010203\n")
	write(moved + "/extra.hex", "040506\n")
	panel.rescan()
	check(model.palettes.size() == 5, "panel refresh discovers both palette sources")
	panel.queue_free()
	await settle()

func _attribution() -> void:
	var folder := directory + "/credits"
	var source := folder + "/credited.hex"
	var metadata := folder + "/attribution.json"
	var credit := {"author": "Artist [b]Name[/b]", "url": "https://lospec.com/palette-list/example", "license": "Example permission"}
	write(source, "112233\n")
	write(metadata, JSON.stringify({"version": 1, "palettes": {"credited.hex": credit}}))
	var model := Store.new(directory + "/credits_collection.json")
	check(model.scan_folder(folder, true).warnings.is_empty(), "valid attribution loads with bundled colors")
	var id := model.active_id
	check(model.get_palette(id).get("attribution", {}) == credit, "attribution matches exact HEX filename")
	var panel := PalettePanel.new(model)
	root.add_child(panel)
	await settle()
	check(panel.attribution_footer.visible and panel.attribution_footer.get_parsed_text() == "Palette by Artist [b]Name[/b]", "footer renders author as literal text")
	check(panel.attribution_footer.tooltip_text == "Example permission", "license available in credit tooltip")
	model.edit_swatch(0, Color.RED)
	check(panel.attribution_footer.get_parsed_text().begins_with("Based on a palette by "), "edited bundle uses derivative credit")
	credit.author = "Corrected Artist"
	write(metadata, JSON.stringify({"version": 1, "palettes": {"credited.hex": credit}}))
	model.scan_folder(folder, true)
	check(model.get_palette(id).attribution.author == "Corrected Artist" and model.get_palette(id).swatches[0].color == "ff0000ff" and model.get_palette(id).dirty, "credit-only rescan updates dirty draft without changing colors")
	var copies := directory + "/credit_copies"
	check(model.save_palette(copies + "/copy.hex", "Credited Copy").ok, "credited bundle saves as copy")
	var copy_id := model.active_id
	check(model.get_palette(copy_id).attribution == credit and model.get_palette(copy_id).attribution_derived, "copy retains attribution and derivative status")
	model.scan_folder(copies)
	check(model.get_palette(copy_id).attribution == credit, "user folder rescan retains copy credit")
	var reloaded := Store.new(model.path)
	check(reloaded.get_palette(copy_id).attribution == credit and reloaded.get_palette(copy_id).attribution_derived, "credits survive collection reload")
	check(FileAccess.get_file_as_string(copies + "/copy.hex") == "FF0000FF\n", "HEX stays portable without embedded metadata")
	model.select_palette(id)
	check(panel.attribution_footer.get_parsed_text() == "Palette by Corrected Artist", "starter reverts to original credit after copy")
	write(metadata, "{broken")
	check(model.scan_folder(folder, true).warnings.size() == 1 and model.get_palette(id).attribution == credit, "malformed metadata preserves existing credits")
	write(folder + "/uncredited.hex", "abcdef\n")
	model.scan_folder(folder, true)
	check(model.palettes.size() == 3, "bad metadata does not block valid palette discovery")
	check(not Store.attribution_url_allowed("file:///tmp/a") and not Store.attribution_url_allowed("javascript:alert(1)") and not Store.attribution_url_allowed("https://"), "non-web or empty-host links are rejected")
	check(Store.attribution_url_allowed("https://lospec.com/example") and Store.attribution_url_allowed("http://example.org/artist"), "web attribution links accepted")
	credit.url = "file:///tmp/a"
	write(metadata, JSON.stringify({"version": 1, "palettes": {"credited.hex": credit}}))
	check(model.scan_folder(folder, true).warnings.size() == 1 and model.get_palette(id).attribution.url.begins_with("https://"), "invalid link metadata preserves previous credit")
	write(metadata, JSON.stringify({"version": 1, "palettes": {}}))
	model.scan_folder(folder, true)
	check(not model.get_palette(id).has("attribution") and not panel.attribution_footer.visible, "removing attribution hides footer on rescan")
	check(model.get_palette(copy_id).has("attribution"), "independent copy retains provenance after source metadata removed")
	panel.queue_free()
	await settle()

func _swatch_history_checks() -> void:
	var model := FailedStore.new(directory + "/history.json")
	model.import_candidate(Parser.parse_text("112233\n445566", "History.hex").palette)
	var first := model.active_id
	var original: Array = model.get_palette(first).swatches.duplicate(true)
	model.edit_swatch(2, Color.RED, "Red")
	check(model.can_undo_swatches() and model.get_palette(first).swatches.size() == 3, "adding color records undo")
	model.undo_swatches()
	check(model.get_palette(first).swatches == original and not model.get_palette(first).dirty and model.can_redo_swatches(), "undo add restores clean saved colors")
	model.redo_swatches()
	check(model.get_palette(first).swatches[2].name == "Red", "redo restores added color name")
	model.edit_swatch(0, Color("abcdef80"), "Alpha")
	model.undo_swatches()
	check(model.get_palette(first).swatches[0] == original[0], "undo restores edited color and name")
	model.redo_swatches()
	check(model.get_palette(first).swatches[0].color == "abcdef80", "redo restores edited alpha")
	model.edit_swatch(0, Color.WHITE, "", true)
	model.undo_swatches()
	check(model.get_palette(first).swatches[0].name == "Alpha", "undo removal restores order and metadata")
	model.edit_swatch(1, Color.GREEN)
	check(not model.can_redo_swatches(), "new swatch edit clears redo branch")
	var before: Array = model.get_palette(first).swatches.duplicate(true)
	model.fail_write = true
	check(not model.undo_swatches().ok and model.get_palette(first).swatches == before and model.can_undo_swatches(), "failed undo write preserves history and colors")
	check(not model.edit_swatch(0, Color.BLACK).ok and model.get_palette(first).swatches == before, "failed edit does not mutate palette")
	model.fail_write = false
	model.new_palette("Other")
	check(not model.can_undo_swatches(), "palette history isolated by ID")
	model.select_palette(first)
	check(model.can_undo_swatches(), "switching palettes preserves session undo")
	model.save_palette(directory + "/history.hex", "History")
	model.undo_swatches()
	check(model.get_palette(first).dirty, "undo after save becomes dirty against new baseline")
	model.redo_swatches()
	check(not model.get_palette(first).dirty, "redo to saved colors becomes clean")
	var panel := PalettePanel.new(model)
	root.add_child(panel)
	await settle()
	panel.grid.grab_focus()
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_DELETE
	panel.grid._gui_input(key)
	check(model.get_palette(first).swatches.size() == before.size() - 1, "Delete removes focused swatch")
	key.keycode = KEY_Z
	key.ctrl_pressed = true
	panel.grid._gui_input(key)
	check(model.get_palette(first).swatches == before, "Ctrl+Z reverses Delete within grid")
	key.shift_pressed = true
	panel.grid._gui_input(key)
	check(model.get_palette(first).swatches.size() == before.size() - 1, "Ctrl+Shift+Z redoes swatch removal")
	panel.grid.release_focus()
	var count: int = model.get_palette(first).swatches.size()
	key.shift_pressed = false
	panel.grid._gui_input(key)
	check(model.get_palette(first).swatches.size() == count, "history shortcut ignores unfocused grid")
	panel.grid.focused_index = panel.grid.swatches.size()
	panel._refresh_color_actions()
	check(panel.menu.get_popup().is_item_disabled(panel.menu.get_popup().get_item_index(21)), "Remove disabled for Add tile")
	panel.grid.focused_index = 0
	panel._refresh_color_actions()
	check(not panel.menu.get_popup().is_item_disabled(panel.menu.get_popup().get_item_index(20)), "Edit available for focused color")
	panel._menu_action(21)
	check(model.get_palette(first).swatches.size() == count - 1, "three-dot Remove acts on focused swatch")
	panel._menu_action(22)
	check(model.get_palette(first).swatches.size() == count, "three-dot Undo restores color")
	model.discard_changes()
	check(not model.can_undo_swatches() and not model.can_redo_swatches(), "discard clears palette history")
	model.edit_swatch(0, Color.BLACK)
	check(not Store.new(model.path).can_undo_swatches(), "undo history is session-only")
	model.reload()
	check(not model.can_undo_swatches(), "reload clears in-memory history")
	panel.queue_free()
	await settle()

func _authoring() -> void:
	var folder := directory + "/authoring"
	var model := Store.new(folder + "/collection.json")
	check(model.new_palette("Empty").ok, "create empty persistent draft")
	var draft_id: String = model.active_id
	check(Store.new(model.path).get_palette(draft_id).get("dirty", false), "draft survives reload")
	check(model.edit_swatch(0, Color("12345678"), "Alpha").ok, "append named alpha color")
	var destination := folder + "/empty.hex"
	check(model.save_palette(destination, "Empty").ok, "save RGBA HEX palette")
	var parsed := Parser.parse_file(destination)
	check(parsed.ok and parsed.palette.swatches == [{"color": "12345678", "name": ""}], "HEX roundtrip retains alpha")
	check(FileAccess.get_file_as_string(destination) == "12345678\n", "save writes plain eight-digit HEX")
	check(Store.new(model.path).get_palette(draft_id).swatches[0].name == "Alpha", "names persist internally")
	check(not model.get_palette(draft_id).dirty, "successful save clears dirty")
	check(model.edit_swatch(0, Color.RED, "Red").ok, "edit color")
	check(model.discard_changes().ok and model.get_palette(draft_id).swatches[0].color == "12345678", "discard restores saved snapshot")
	check(model.edit_swatch(0, Color.WHITE, "", true).ok, "remove last color")
	check(not model.save_palette(destination, "Empty").ok and model.get_palette(draft_id).dirty, "empty palette remains draft instead of writing unusable HEX")
	model.discard_changes()
	check(model.save_palette(destination, "Empty").ok and model.active_id == draft_id, "overwrite retains internal ID")
	check(model.save_palette(folder + "/copy.hex", "Copy", true).ok, "save as new creates collection entry")
	check(model.palettes.size() == 2 and model.active_id != draft_id, "copy has independent internal ID")
	var before_export := JSON.stringify(model.palettes)
	check(model.export_hex(directory + "/rgb.hex", false).ok and FileAccess.get_file_as_string(directory + "/rgb.hex") == "123456\n", "RGB export omits alpha")
	check(model.export_hex(directory + "/rgba.hex", true).ok and FileAccess.get_file_as_string(directory + "/rgba.hex") == "12345678\n", "RGBA export retains alpha")
	check(JSON.stringify(model.palettes) == before_export, "export leaves collection and draft state intact")
	check(not model.export_hex(destination, false, true).ok, "export cannot replace managed source")
	check(not model.export_hex(directory + "/rgb.hex", true).ok, "export collision needs replacement confirmation")
	check(not model.save_palette(folder + "/copy.hex", "Different Name", true).ok, "save-as-new cannot overwrite its original source")
	var selected: String = model.active_id
	write(folder + "/download.hex", "aabbcc\n11223344")
	write(folder + "/bad.hex", "not a color")
	var scanned := model.scan_folder(folder)
	check(scanned.warnings.size() == 1 and model.palettes.size() == 3, "scan continues after invalid input and ignores collection JSON")
	check(model.active_id == selected, "rescan preserves active palette")
	model.scan_folder(folder)
	check(model.palettes.size() == 3, "repeat scans do not duplicate sources")
	var imported_id := ""
	for palette in model.palettes:
		if palette.name == "download": imported_id = palette.id
	model.select_palette(imported_id)
	model.edit_swatch(0, Color.GREEN)
	write(folder + "/download.hex", "ff00ff")
	scanned = model.scan_folder(folder)
	check(scanned.warnings.size() == 2 and model.get_palette(imported_id).swatches[0].color == "00ff00ff", "scan protects dirty draft from source changes")
	model.discard_changes()
	model.scan_folder(folder)
	check(model.get_palette(imported_id).swatches[0].color == "ff00ffff", "clean known source updates in place")
	var source_bytes := FileAccess.get_file_as_bytes(folder + "/download.hex")
	check(model.save_palette(folder + "/download-saved.hex", "download").ok, "import saves as native")
	check(FileAccess.get_file_as_bytes(folder + "/download.hex") == source_bytes, "native save leaves import source intact")
	model.scan_folder(folder)
	check(model.palettes.size() == 3, "converted import and native source do not duplicate on scan")
	check(model.remove_palette(imported_id).ok and FileAccess.file_exists(folder + "/download-saved.hex"), "remove never deletes native source")
	var failed := FailedStore.new(folder + "/failed.json")
	failed.new_palette("Failed")
	failed.edit_swatch(0, Color.BLUE)
	failed.fail_write = true
	check(not failed.save_palette(folder + "/failed.hex", "Failed").ok and failed.get_palette(failed.active_id).dirty, "failed native replacement retains draft")
	check(not FileAccess.file_exists(folder + "/failed.hex"), "failed save leaves no destination")
	model.select_palette(draft_id)
	model.edit_swatch(0, Color.BLUE)
	write(destination, '{"version":1,"id":"external","name":"External","swatches":[]}')
	check(not model.save_palette(destination, "Empty").ok and model.get_palette(draft_id).dirty, "save refuses external native changes")
	var collision := folder + "/collision.hex"
	write(collision, "original bytes")
	check(model.save_palette(collision, "Replacement", true).get("needs_confirmation", false), "unmanaged file collision requires confirmation")
	check(FileAccess.get_file_as_string(collision) == "original bytes", "unconfirmed replacement preserves file")
	check(model.save_palette(collision, "Replacement", true, true).ok, "confirmed replacement saves")
	var legacy := folder + "/legacy.gddrawpalette"
	write(legacy, '{"version":1,"id":"legacy","name":"Legacy","swatches":[{"color":"#ABCDEF80","name":"Named"}]}')
	check(model.import_file(legacy).ok, "legacy native import remains supported")
	check(model.save_palette(folder + "/legacy.hex", "Legacy").ok, "legacy import saves as HEX")
	check(FileAccess.file_exists(legacy) and FileAccess.get_file_as_string(folder + "/legacy.hex") == "ABCDEF80\n", "legacy original preserved on conversion")
	check(not Parser.parse_text('{"version":2}', "bad.gddrawpalette").ok, "reject unsupported native version")
	check(not Parser.parse_text('{"version":1,"id":"a","name":"Bad","swatches":[{"color":"#123"}]}', "bad.gddrawpalette").ok, "reject malformed native color")

func _authoring_ui() -> void:
	var model := Store.new(directory + "/author-ui.json")
	model.new_palette("Draft")
	var panel := PalettePanel.new(model)
	root.add_child(panel)
	panel.size = Vector2(260, 240)
	await settle()
	var assignments: Array = []
	panel.color_requested.connect(func(color: Color, bg: bool): assignments.append([color, bg]))
	click(panel.grid, 0)
	check(panel.color_dialog.visible and panel.owns_input_focus(), "empty add tile opens modal picker and owns input")
	panel.color_picker.color = Color("ff112280")
	panel.color_dialog.hide()
	check(model.get_palette(model.active_id).swatches.is_empty() and assignments.is_empty(), "canceled picker adds nothing and never assigns drawing colors")
	panel._show_color(-1)
	panel.color_picker.color = Color("ff112280")
	panel.color_name.text = "Named"
	panel.color_dialog.confirmed.emit()
	panel.color_dialog.hide()
	check(model.get_palette(model.active_id).swatches.size() == 1 and assignments.is_empty(), "explicit Add appends exactly one color")
	check(panel.dropdown.get_item_text(0).ends_with(" *"), "dirty dropdown marker")
	panel._menu_action(5)
	check(panel.export_options.visible and panel.owns_input_focus() and panel.export_format.item_count == 2, "export offers RGB and RGBA in modal dialog")
	panel.export_options.hide()
	check(model.get_palette(model.active_id).dirty and assignments.is_empty(), "cancel export preserves dirty palette and drawing colors")
	for mode in range(4):
		panel._set_view(mode)
		await settle()
		check(panel.grid._index_at(panel.grid.swatch_rect(1).get_center()) == 1, "add tile hit target in view %d" % mode)
	check(panel.grid.columns == 1 and panel.grid.swatch_rect(0).size.x == panel.grid.size.x, "horizontal rows fill available width")
	panel._guard(panel._show_new)
	check(panel.dirty_dialog.visible, "replacing dirty draft prompts")
	panel.dirty_dialog.hide()
	panel._cancel_action()
	check(model.palettes.size() == 1 and model.get_palette(model.active_id).dirty, "cancel preserves draft")
	panel.free()

func _file_refresh() -> void:
	var folder := directory + "/refresh"
	var model := Store.new(folder + "/collection.json")
	var panel := PalettePanel.new(model)
	panel.palette_folder = folder
	root.add_child(panel)
	var requests: Array = []
	panel.filesystem_refresh_requested.connect(func(): requests.append(true))
	write(folder + "/first.hex", "12345678")
	write(folder + "/discovered.hex", "112233")
	panel.import_palette(folder + "/first.hex")
	var selected: String = model.active_id
	await settle()
	check(model.palettes.size() == 2 and model.active_id == selected, "import refresh discovers folder files and preserves selection")
	check(requests.size() == 1, "successful import requests editor filesystem refresh")
	model.edit_swatch(0, Color("abcdef80"), "Draft")
	panel.export_format.select(1)
	panel._export_palette(folder + "/exported.hex")
	await settle()
	check(model.palettes.size() == 3 and model.active_id == selected and model.get_palette(selected).dirty, "export refresh discovers copy without replacing dirty active palette")
	check(requests.size() == 2, "successful export requests editor filesystem refresh")
	write(folder + "/later.hex", "ffffff")
	panel._save_path = folder + "/first.hex"
	panel._save_name = "first"
	panel._perform_save()
	await settle()
	check(model.palettes.size() == 4 and model.active_id == selected and not model.get_palette(selected).dirty, "save refresh discovers new files and retains saved palette")
	check(requests.size() == 3, "successful save requests editor filesystem refresh")
	panel.import_palette(folder + "/missing.hex")
	panel.error_dialog.hide()
	await settle()
	check(requests.size() == 3, "failed import does not refresh")
	panel.free()

func _parser() -> void:
	var hex := Parser.parse_text(String.chr(0xfeff) + "  #aAbBcC \r\n; comment\n\n// comment\n#11223344\n#AABBCC", "Colors.hex")
	check(hex.ok, "BOM, whitespace and full-line comments")
	check(hex.palette.name == "Colors", "hex filename stem")
	check(hex.palette.swatches == [{"color": "aabbccff", "name": ""}, {"color": "11223344", "name": ""}, {"color": "aabbccff", "name": ""}], "alpha, order and duplicates")
	for extension in ["hex", "txt"]:
		var bare := Parser.parse_text(String.chr(0xfeff) + "  aAbBcC \r\n11223344\n#AABBCC\n000000\n", "Download." + extension)
		check(bare.ok and bare.palette.swatches == hex.palette.swatches + [{"color": "000000ff", "name": ""}], "optional hash preserves alpha, order and duplicates in " + extension)
	write(directory + "/download.hex", "000000\r\n222034\r\n45283c\r\n8a6f30\r\n")
	var download := Parser.parse_file(directory + "/download.hex")
	check(download.ok and download.palette.swatches.size() == 4 and download.palette.swatches[1].color == "222034ff", "downloaded bare-hex file imports without conversion")
	var gpl := Parser.parse_text("GIMP Palette\r\nName: Named colors\nColumns: 5\n # comment\n\t255 0 1  Red name \n0\t0\t0\n255 0 1 duplicate", "fallback.gpl")
	check(gpl.ok and gpl.palette.name == "Named colors", "GPL name and metadata")
	check(gpl.palette.swatches[0] == {"color": "ff0001ff", "name": "Red name"}, "GPL RGB and optional name")
	check(gpl.palette.swatches.size() == 3 and gpl.palette.swatches[1].name == "", "GPL names optional, order and duplicates")
	check(Parser.parse_text("GIMP Palette\n0 255 0", "old.gpl").palette.name == "old", "old GPL without metadata")
	check(Parser.parse_text("GIMP Palette\nColumns: 0\n0 255 0", "old.gpl").ok, "optional Columns without Name extension")
	check(Parser.parse_text("GIMP Palette\n000255 +0 000000001", "old.gpl").palette.swatches[0].color == "ff0001ff", "GPL decimal padding and explicit positive sign")
	write(directory + "/bom.hex", String.chr(0xfeff) + "#AABBCC\r\n#11223344")
	check(Parser.parse_file(directory + "/bom.hex").ok, "actual UTF-8 BOM file import")
	write(directory + "/bom.gpl", String.chr(0xfeff) + "GIMP Palette\r\nName: UTF-8 café\r\n255 0 0 Réd")
	check(Parser.parse_file(directory + "/bom.gpl").palette.swatches[0].name == "Réd", "actual GPL UTF-8 BOM and names")
	for text in ["", "\n; none", "#123", "#1234567", "#123456789", "12345", "1234567", "123456789", "0x123456", "12345g", "123456 comment", "##123456", "#12345g", "#123456 comment", "# comment", "#123456 #123456"]:
		check(not Parser.parse_text(text, "bad.txt").ok, "reject malformed hex: " + text)
	for text in ["wrong\n0 0 0", "GIMP Palette", "GIMP Palette\n256 0 0", "GIMP Palette\n-1 0 0", "GIMP Palette\n1.5 0 0", "GIMP Palette\n0 0", "GIMP Palette\nColumns: 256\n0 0 0", "GIMP Palette\nName: \n0 0 0", "GIMP Palette\n0 0 0\nName: Late", "GIMP Palette\nName: A\nName: B\n0 0 0"]:
		check(not Parser.parse_text(text, "bad.gpl").ok, "reject malformed GPL: " + text)
	check(Parser.parse_text("#000000\ninvalid", "bad.hex").error.begins_with("Line 2:"), "line-numbered error")
	check(not Parser.parse_text("#000000", "bad.ase").ok, "unsupported extension")
	check(Parser.parse_text("#123456\n".repeat(4096), "large.hex").ok, "4096 swatches accepted")
	check(not Parser.parse_text("#123456\n".repeat(4097), "large.hex").ok, "4097 rejected")
	var large := directory + "/large.hex"
	write(large, ";".repeat(Parser.MAX_FILE_BYTES + 1))
	check(not Parser.parse_file(large).ok, "file size bounded before parsing")
	var bad_utf := FileAccess.open(directory + "/utf.txt", FileAccess.WRITE)
	bad_utf.store_buffer(PackedByteArray([0xff, 0xfe, 0x23]))
	bad_utf.close()
	check(not Parser.parse_file(directory + "/utf.txt").ok, "invalid UTF-8 rejected")

func _storage() -> void:
	var path := directory + "/project_a/palettes.json"
	var model := FailedStore.new(path)
	check(not DirAccess.dir_exists_absolute(path.get_base_dir()), "loading is read-only; no directory")
	var source := directory + "/source.hex"
	write(source, "#123456\n#11223344")
	check(model.import_file(source).ok, "import commits")
	var first := model.active_id
	check(model.import_file(source).ok and model.active_id != first, "same-name stable distinct IDs")
	check(model.palettes[1].name == "source (2)", "deterministic display suffix")
	var second := model.active_id
	check(model.select_palette(first).ok, "persist active palette")
	var bytes := FileAccess.get_file_as_bytes(path)
	var state := model.palettes.duplicate(true)
	write(source, "bad")
	check(not model.import_file(source).ok and model.palettes == state and FileAccess.get_file_as_bytes(path) == bytes, "invalid import atomic")
	model.fail_write = true
	check(not model.remove_palette(first).ok, "failed replacement reported")
	check(model.palettes == state and model.active_id == first and FileAccess.get_file_as_bytes(path) == bytes, "failed replacement preserves memory and disk")
	check(not model.select_palette(second).ok and model.active_id == first, "failed active-palette write atomic")
	check(not model.import_candidate(Parser.parse_text("#ffffff", "new.hex").palette).ok and model.palettes == state and FileAccess.get_file_as_bytes(path) == bytes, "failed import write preserves collection")
	model.fail_write = false
	DirAccess.remove_absolute(source)
	var restored := Store.new(path)
	check(restored.load_error.is_empty() and restored.active_id == first and restored.palettes == state, "restore normalized data without source")
	var independent := Store.new(directory + "/project_b/palettes.json")
	check(independent.palettes.is_empty(), "independent project collection")
	check(model.remove_palette(first).ok and model.active_id == second, "removal selects next deterministically")
	check(not restored.remove_palette(first).ok, "stale model cannot overwrite newer collection")
	check(model.remove_palette(second).ok and model.active_id == "" and model.palettes.is_empty(), "last removal empty state")
	write(source, "#ffffff")
	check(model.import_file(source).ok and model.remove_palette(model.active_id).ok and FileAccess.file_exists(source), "removal never deletes external source")
	var valid := JSON.parse_string(bytes.get_string_from_utf8()) as Dictionary
	for kind in ["json", "version", "id", "duplicate", "color", "counter"]:
		var data := valid.duplicate(true)
		match kind:
			"version": data.version = 999
			"id": data.palettes[0].erase("id")
			"duplicate": data.palettes[1].id = data.palettes[0].id
			"color": data.palettes[0].swatches[0].color = "wrong"
			"counter": data.next_id = 1
		var corrupt_path: String = directory + "/" + kind + ".json"
		var content := "{broken" if kind == "json" else JSON.stringify(data)
		write(corrupt_path, content)
		var corrupt := Store.new(corrupt_path)
		check(not corrupt.load_error.is_empty(), "stored validation: " + kind)
		check(not corrupt.import_candidate(Parser.parse_text("#000000", "new.hex").palette).ok and FileAccess.get_file_as_string(corrupt_path) == content, "corrupt data preserved: " + kind)
	valid.active_id = "missing"
	write(directory + "/active.json", JSON.stringify(valid))
	var missing_active := Store.new(directory + "/active.json")
	check(missing_active.active_id == first and not missing_active.load_warning.is_empty(), "missing active ID fallback with warning")
	check(FileAccess.get_file_as_string(directory + "/active.json") == JSON.stringify(valid), "fallback restoration read-only")
	write(directory + "/blocked", "file blocks directory")
	var blocked := Store.new(directory + "/blocked/palettes.json")
	check(not blocked.import_candidate(Parser.parse_text("#000000", "new.hex").palette).ok and blocked.palettes.is_empty(), "directory write failure atomic")

func key(grid: Control, code: Key, shift := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	event.shift_pressed = shift
	grid._gui_input(event)

func click(grid: Control, index: int, background := false) -> void:
	var event := InputEventMouseButton.new()
	event.position = grid.swatch_rect(index).get_center()
	event.button_index = MOUSE_BUTTON_RIGHT if background else MOUSE_BUTTON_LEFT
	event.pressed = true
	grid._gui_input(event)

func _panel() -> void:
	var model := Store.new(directory + "/panel.json")
	var panel := PalettePanel.new(model)
	root.add_child(panel)
	panel.size = Vector2(180, 150)
	check(panel.empty.visible and panel.dropdown.disabled, "minimal empty state")
	var colors: Array = []
	panel.color_requested.connect(func(color: Color, background: bool): colors.append([color, background]))
	check(model.import_candidate(Parser.parse_text("#ffffff\n#000000\n#12345600\n".repeat(1000), "many.hex").palette).ok, "large panel import")
	await settle()
	var grid = panel.grid
	check(colors.is_empty(), "import does not assign first color")
	var first_id: String = model.active_id
	check(grid.get_child_count() == 0 and grid.swatches.size() == 3000, "virtual grid avoids thousands of controls")
	check(grid.columns >= 3 and grid.columns <= 6, "responsive columns at narrow width")
	grid.grab_focus()
	key(grid, KEY_END)
	await settle()
	check(grid.focused_index == 3000 and panel.scroll.scroll_vertical > 0, "End focuses add tile and reveals")
	check(colors.is_empty(), "focus movement does not assign")
	key(grid, KEY_HOME)
	key(grid, KEY_DOWN)
	check(grid.focused_index == grid.columns, "Down moves spatially")
	key(grid, KEY_RIGHT)
	key(grid, KEY_UP)
	check(grid.focused_index == 1, "Right/Up spatial movement")
	key(grid, KEY_LEFT)
	key(grid, KEY_ENTER)
	key(grid, KEY_ENTER, true)
	key(grid, KEY_SPACE)
	check(colors == [[Color.WHITE, false], [Color.WHITE, true], [Color.WHITE, false]], "Enter, Shift+Enter, Space assignment")
	click(grid, 2, true)
	check(colors.back() == [Color("12345600"), true], "right click preserves transparency")
	click(grid, 1)
	check(colors.back() == [Color.BLACK, false], "left click foreground")
	check("Alpha:" in grid._get_tooltip(grid.swatch_rect(2).get_center()), "transparent tooltip includes alpha")
	var before: Array = grid.swatches
	panel.set_colors(Color.WHITE, Color.BLACK)
	check(grid.swatches == before and grid.foreground == Color.WHITE and grid.background == Color.BLACK, "marker update without rebuilding data")
	key(grid, KEY_END)
	await settle()
	var remembered_scroll: int = panel.scroll.scroll_vertical
	model.import_candidate(Parser.parse_text("#e84941", "other.hex").palette)
	await settle()
	var assigned_count := colors.size()
	model.select_palette(first_id)
	await settle()
	check(grid.focused_index == 3000 and panel.scroll.scroll_vertical == remembered_scroll and colors.size() == assigned_count, "palette switching restores swatch and scroll without assignment")
	panel.size = Vector2(96, 90)
	await settle()
	check(grid.columns >= 1 and grid.CELL == 32 and panel.scroll.size.y > 0, "short narrow panel retains usable targets and scroll")
	var active: String = model.active_id
	panel.free()
	var recreated := PalettePanel.new(Store.new(directory + "/panel.json"))
	root.add_child(recreated)
	check(recreated.model.active_id == active and recreated.grid.swatches.size() == 3000, "model and panel recreation restores view")
	recreated.free()
	# Destruction during pending scroll restoration must not resume freed code.
	var transient := PalettePanel.new(Store.new(directory + "/panel.json"))
	var transient_ref: WeakRef = weakref(transient)
	root.add_child(transient)
	await process_frame
	transient.free()
	await settle()
	check(transient_ref.get_ref() == null, "panel teardown releases content during scroll restoration; inspect logs")

func _dock() -> void:
	var dock := Dock.new()
	root.add_child(dock)
	dock.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await settle()
	var panel = dock._palette_panel
	# Isolate managed data from any real project collection in this fixture.
	panel.model.path = directory + "/dock.json"
	panel.model.reload()
	var host = dock._panel_host
	check(host.panels.keys() == ["layers", "palettes"], "production registration and rail order")
	var old := {"version": 1, "width": 380, "root": {"type": "group", "id": "old", "tabs": ["layers"], "active": "layers", "visible": false}}
	check(host.restore_description(old), "old Layers-only layout accepted")
	check(host.layout.tabs == ["layers", "palettes"] and host.layout.active == "layers" and not host.layout.visible and host.dock_width == 380, "migration preserves old layout and visibility")
	var canvas = dock._canvas
	var pixels: PackedByteArray = canvas.get_image_copy().get_data()
	var dirty: bool = dock._is_2d_document_dirty()
	dock._history.push_undo(canvas.get_image_copy())
	dock._history.push_redo(canvas.get_image_copy())
	var undo: Array = dock._history._undo_stack.duplicate()
	var redo: Array = dock._history._redo_stack.duplicate()
	var fg: Color = canvas.brush_color
	var bg: Color = canvas.background_color
	check(panel.model.import_candidate(Parser.parse_text("#ff0000\n#0000ff80\n#ff0000\n".repeat(80), "Dock.hex").palette).ok, "dock import")
	check(canvas.brush_color == fg and canvas.background_color == bg, "import preserves both drawing colors")
	host.activate_panel("palettes")
	await settle()
	var grid = panel.grid
	click(grid, 0)
	check(canvas.brush_color == Color.RED and dock._foreground_color_picker.color == Color.RED and dock._recent_colors[0] == Color.RED, "foreground path and recents")
	click(grid, 1, true)
	check(canvas.background_color == Color("0000ff80") and dock._background_color_picker.color == Color("0000ff80"), "background path and picker")
	dock._foreground_color_picker.color = Color.GREEN
	dock._on_foreground_color_changed(Color.GREEN)
	check(grid.foreground == Color.GREEN, "main picker synchronization")
	dock._set_foreground_color(Color.RED)
	dock._on_color_picked(Color.YELLOW, Vector2i.ZERO)
	check(grid.foreground == Color.YELLOW and dock._foreground_color_picker.color == Color.YELLOW, "eyedropper synchronization")
	dock._set_foreground_color(Color.RED)
	dock._on_swap_colors_pressed()
	check(grid.foreground == canvas.brush_color and grid.background == canvas.background_color, "swap synchronization")
	key(grid, KEY_END)
	await settle()
	var connections: int = panel.color_requested.get_connections().size()
	var model_connections: int = panel.model.changed.get_connections().size()
	for mode in range(4):
		dock._on_view_mode_selected(mode)
		grid.grab_focus()
		check(host.move_panel("palettes", host.group_for_panel("layers").id, "right"), "move Palettes to horizontal split mode %d" % mode)
		await settle()
		check(grid.has_focus(), "moving visible panel retains keyboard focus mode %d" % mode)
		var scroll_value: int = panel.scroll.scroll_vertical
		host.toggle_panel("palettes")
		host.toggle_panel("palettes")
		await settle()
		check(panel.scroll.scroll_vertical == scroll_value, "scroll survives collapse/reopen mode %d" % mode)
		check(host.move_panel("palettes", host.group_for_panel("layers").id, "bottom"), "move Palettes to vertical split mode %d" % mode)
		await settle()
		check(host.move_panel("palettes", host.group_for_panel("layers").id, "tab"), "move Palettes back to tabs mode %d" % mode)
		host.reset_layout()
		host.activate_panel("palettes")
		await settle()
		check(panel == dock._palette_panel and grid == panel.grid and grid.focused_index == 240, "panel identity and focused swatch preserved mode %d" % mode)
	check(panel.color_requested.get_connections().size() == connections and panel.model.changed.get_connections().size() == model_connections, "signal ownership preserved")
	panel._menu_action(1)
	panel.remove_dialog.hide()
	check(panel.model.palettes.size() == 1, "cancel removal leaves collection intact")
	check(panel.model.remove_palette(panel.model.active_id).ok and panel.empty.visible, "managed removal to empty state")
	check(canvas.get_image_copy().get_data() == pixels and dock._is_2d_document_dirty() == dirty, "palette management and selection preserve artwork and dirty state")
	check(dock._history._undo_stack == undo and dock._history._redo_stack == redo, "palette and placement preserve populated undo/redo")
	# Compare draft semantics to the same existing setters, without introducing
	# a palette commit path. Browsing and placement leave the draft alive.
	canvas.active_tool = canvas.ToolMode.TEXT
	canvas.create_text_draft(Rect2i(0, 0, 64, 32), "Draft")
	await settle()
	check(canvas.has_text_draft(), "text draft fixture active")
	panel.model.import_candidate(Parser.parse_text("#43a986\n#4175c780", "draft.hex").palette)
	panel._show_import()
	panel.import_dialog.hide()
	panel._menu_action(1)
	panel.remove_dialog.hide()
	host.move_panel("palettes", host.group_for_panel("layers").id, "right")
	await settle()
	check(canvas.has_text_draft() and canvas.get_image_copy().get_data() == pixels, "import dialogs and panel placement preserve text draft and pixels")
	dock._set_foreground_color(Color("43a986"))
	var expected_preview: PackedByteArray = canvas._text_preview_image.get_data()
	dock._set_foreground_color(Color.RED)
	click(grid, 0)
	check(canvas.has_text_draft() and canvas._text_preview_image.get_data() == expected_preview, "palette foreground follows existing text preview setter semantics")
	# Exercise dispatch through _input as well as direct widget unit events.
	grid.grab_focus()
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	Input.parse_input_event(enter)
	await settle()
	check(canvas.has_text_draft() and dock._history._undo_stack == undo and dock._history._redo_stack == redo, "swatch Enter does not leak into draft commit shortcut")
	canvas.cancel_text_draft()
	canvas.active_tool = canvas.ToolMode.LINE
	check(canvas.begin_surface_shape_preview(Vector2i(0, 0), Vector2i(8, 8)), "surface draft active")
	var shape_settings: Dictionary = canvas._surface_shape_settings.duplicate(true)
	panel.model.select_palette(panel.model.palettes[0].id)
	host.toggle_panel("palettes")
	host.toggle_panel("palettes")
	click(grid, 1, true)
	check(canvas.is_surface_shape_previewing() and canvas._surface_shape_settings == shape_settings, "browsing and palette background preserve captured surface draft settings")
	check(canvas.get_image_copy().get_data() == pixels and dock._history._undo_stack == undo and dock._history._redo_stack == redo, "draft color use owns no pixel or history mutation")
	canvas.cancel_surface_shape_preview()
	grid.grab_focus()
	grid.focused_index = 0
	var swatch_count: int = grid.swatches.size()
	var delete := InputEventKey.new()
	delete.keycode = KEY_DELETE
	delete.pressed = true
	Input.parse_input_event(delete)
	await settle()
	check(grid.swatches.size() == swatch_count - 1, "routed Delete reaches palette grid")
	var undo_key := InputEventKey.new()
	undo_key.keycode = KEY_Z
	undo_key.ctrl_pressed = true
	undo_key.pressed = true
	Input.parse_input_event(undo_key)
	await settle()
	check(grid.swatches.size() == swatch_count, "routed Ctrl+Z restores swatch")
	check(canvas.get_image_copy().get_data() == pixels and dock._history._undo_stack == undo and dock._history._redo_stack == redo, "palette Delete and Undo leave artwork and its history untouched")
	if "--screenshot" in OS.get_cmdline_user_args():
		panel.model.import_candidate(Parser.parse_text("GIMP Palette\nName: Studio colors\n255 255 255 Snow\n0 0 0 Ink\n232 73 65 Coral\n244 185 65 Gold\n67 169 134 Mint\n65 117 199 Blue\n142 96 180 Violet\n", "studio.gpl").palette)
		panel.model.import_candidate(Parser.parse_text("#ffffff\n#000000\n#e84941\n#f4b941\n#43a986\n#4175c7\n#8e60b4\n#e8494180\n#4175c740\n#00000000\n", "Transparency.hex").palette)
		host.move_panel("palettes", host.group_for_panel("layers").id, "bottom")
		host.set_dock_width(300)
		dock._on_panel_layout_changed()
		grid.grab_focus()
		dock._set_foreground_color(Color.WHITE)
		dock._set_background_color(Color.BLACK)
		await settle()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://palette_review.png")
		panel._set_view(3)
		await settle()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://palette_rows_review.png")
		root.gui_embed_subwindows = true
		panel._show_color(-1)
		await settle()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://palette_color_review.png")
		panel.color_dialog.hide()
	dock.free()

func _session() -> void:
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
	var panel = dock._palette_panel
	panel.model.path = directory + "/session.json"
	panel.model.reload()
	var host = dock._panel_host
	var target = dock._layer_session.get_active_target()
	var layer = target.get_selected_layer()
	layer.image.set_pixel(0, 0, Color.RED)
	target.set_selected_layer_image(layer.image)
	var pixels: PackedByteArray = layer.image.get_data()
	var dirty: bool = dock._texture_3d_layer_coordinator.is_dirty()
	dock._history.push_undo(image)
	dock._history.push_redo(image)
	var undo: Array = dock._history._undo_stack.duplicate()
	var redo: Array = dock._history._redo_stack.duplicate()
	var tree_root: TreeItem = dock._layers_tree.get_root()
	for mode in range(4):
		dock._on_view_mode_selected(mode)
		await settle()
		var preview: MeshInstance3D = dock._paint_3d_mesh
		panel.model.import_candidate(Parser.parse_text("#112233\n#44556677", "session.hex").palette)
		host.activate_panel("palettes")
		host.move_panel("palettes", host.group_for_panel("layers").id, "bottom")
		await settle()
		click(panel.grid, 0)
		click(panel.grid, 1, true)
		host.toggle_panel("palettes")
		host.toggle_panel("palettes")
		panel.model.remove_palette(panel.model.active_id)
		host.reset_layout()
		await settle()
		check(dock._layer_session.get_active_target() == target and dock._paint_3d_mesh == preview, "palette operations preserve active 3D target and preview mode %d" % mode)
		check(layer.image.get_data() == pixels and dock._texture_3d_layer_coordinator.is_dirty() == dirty, "palette operations preserve dirty 3D artwork mode %d" % mode)
		check(dock._history._undo_stack == undo and dock._history._redo_stack == redo, "palette operations preserve populated 3D history mode %d" % mode)
		check(dock._layers_tree.get_root() == tree_root, "palette operations do not rebuild Layers mode %d" % mode)
	dock.free()
	source.free()
