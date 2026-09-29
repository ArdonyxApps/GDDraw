@tool
class_name GDDraw3DBatchSaveDialog
extends ConfirmationDialog

signal show_unchanged_changed(enabled: bool)
signal save_all_requested
signal discard_requested
signal plan_changed

const ACTION_SAVE := 0
const ACTION_SAVE_AS := 1
const COLUMN_INCLUDE := 0
const COLUMN_TEXTURE := 1
const COLUMN_ACTION := 2
const COLUMN_DESTINATION := 3
const COLUMN_STATUS := 4

var texture_tree: Tree
var show_unchanged: CheckBox
var summary_label: Label
var preview: TextureRect
var preview_label: Label
var compare_mode: OptionButton
var pixel_scale: CheckButton
var layered_section: VBoxContainer
var save_layered: CheckBox
var layered_path: LineEdit
var progress: ProgressBar
var status_label: Label
var save_all_button: Button
var discard_button: Button

var _rows: Array[Dictionary] = []
var _item_by_target_id: Dictionary = {}
var _preview_image: Image
var _built := false
var _rebuilding_tree := false


func setup() -> void:
	if _built:
		return
	_built = true
	title = "Save 3D Textures"
	ok_button_text = "Save Changed"
	cancel_button_text = "Cancel"
	dialog_hide_on_ok = false
	min_size = Vector2i(820, 590)
	max_size = Vector2i(1180, 860)

	var content := VBoxContainer.new()
	content.name = "3D Batch Save Content"
	content.add_theme_constant_override("separation", 8)
	add_child(content)

	var header := HBoxContainer.new()
	summary_label = Label.new()
	summary_label.name = "3D Batch Save Summary"
	summary_label.text = "Review the texture files that will be written and reassigned."
	summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(summary_label)
	show_unchanged = CheckBox.new()
	show_unchanged.name = "Show Unchanged Textures"
	show_unchanged.text = "Show unchanged"
	show_unchanged.toggled.connect(func(enabled: bool): show_unchanged_changed.emit(enabled))
	header.add_child(show_unchanged)
	content.add_child(header)

	texture_tree = Tree.new()
	texture_tree.name = "3D Texture Save Plan"
	texture_tree.hide_root = true
	texture_tree.scroll_horizontal_enabled = true
	texture_tree.columns = 5
	texture_tree.column_titles_visible = true
	texture_tree.set_column_title(COLUMN_INCLUDE, "Save")
	texture_tree.set_column_title(COLUMN_TEXTURE, "Texture / Object")
	texture_tree.set_column_title(COLUMN_ACTION, "Action")
	texture_tree.set_column_title(COLUMN_DESTINATION, "Destination")
	texture_tree.set_column_title(COLUMN_STATUS, "Status")
	texture_tree.set_column_expand(COLUMN_INCLUDE, false)
	texture_tree.set_column_custom_minimum_width(COLUMN_INCLUDE, 48)
	texture_tree.set_column_custom_minimum_width(COLUMN_TEXTURE, 205)
	texture_tree.set_column_custom_minimum_width(COLUMN_ACTION, 150)
	texture_tree.set_column_custom_minimum_width(COLUMN_DESTINATION, 260)
	texture_tree.set_column_custom_minimum_width(COLUMN_STATUS, 100)
	texture_tree.custom_minimum_size = Vector2(790, 190)
	texture_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	texture_tree.item_selected.connect(_on_item_selected)
	texture_tree.item_edited.connect(_on_item_edited)
	content.add_child(texture_tree)

	var preview_header := HBoxContainer.new()
	preview_label = Label.new()
	preview_label.name = "3D Texture Comparison Label"
	preview_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	preview_header.add_child(preview_label)
	compare_mode = OptionButton.new()
	compare_mode.name = "3D Texture Comparison Mode"
	compare_mode.add_item("Original", 0)
	compare_mode.add_item("Edited", 1)
	compare_mode.add_item("Split", 2)
	compare_mode.select(1)
	compare_mode.item_selected.connect(func(_index: int): _refresh_preview())
	preview_header.add_child(compare_mode)
	pixel_scale = CheckButton.new()
	pixel_scale.name = "3D Texture Preview Pixel Scale"
	pixel_scale.text = "1:1"
	pixel_scale.tooltip_text = "Show the selected texture at full pixel scale; disable to fit it in the preview."
	pixel_scale.toggled.connect(func(_enabled: bool): _apply_preview_scale())
	preview_header.add_child(pixel_scale)
	content.add_child(preview_header)

	var preview_panel := PanelContainer.new()
	preview_panel.name = "3D Texture Comparison Panel"
	preview_panel.custom_minimum_size = Vector2(790, 220)
	preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var preview_scroll := ScrollContainer.new()
	preview_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	preview_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	preview_panel.add_child(preview_scroll)
	preview = TextureRect.new()
	preview.name = "3D Texture Comparison Preview"
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.custom_minimum_size = Vector2(760, 200)
	preview_scroll.add_child(preview)
	content.add_child(preview_panel)

	layered_section = VBoxContainer.new()
	layered_section.name = "Layer Document Save Section"
	var layered_row := HBoxContainer.new()
	save_layered = CheckBox.new()
	save_layered.name = "Save Layer Document"
	save_layered.text = "Save hierarchy layer document"
	save_layered.toggled.connect(_on_save_layered_toggled)
	layered_row.add_child(save_layered)
	layered_path = LineEdit.new()
	layered_path.name = "Layer Document Destination"
	layered_path.placeholder_text = "res://path/hierarchy.gddraw"
	layered_path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layered_path.text_changed.connect(func(_text: String): plan_changed.emit())
	layered_row.add_child(layered_path)
	layered_section.add_child(layered_row)
	content.add_child(layered_section)

	progress = ProgressBar.new()
	progress.name = "3D Batch Save Progress"
	progress.min_value = 0
	progress.max_value = 1
	progress.value = 0
	progress.show_percentage = false
	progress.visible = false
	content.add_child(progress)
	status_label = Label.new()
	status_label.name = "3D Batch Save Status"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(status_label)

	save_all_button = add_button("Save All", true, "save_all")
	discard_button = add_button("Discard and Continue", false, "discard")
	custom_action.connect(_on_custom_action)


func set_plan(
	rows: Array[Dictionary],
	show_unchanged_value: bool,
	layered_visible: bool,
	layered_checked: bool,
	layered_destination: String,
	transition_mode: bool
) -> void:
	setup()
	_rows = rows
	show_unchanged.set_pressed_no_signal(show_unchanged_value)
	layered_section.visible = layered_visible
	save_layered.set_pressed_no_signal(layered_checked)
	layered_path.text = layered_destination
	_on_save_layered_toggled(layered_checked)
	discard_button.visible = transition_mode
	summary_label.text = _make_summary_text()
	status_label.text = ""
	_rebuild_tree()
	set_busy(false)


func get_plan() -> Array[Dictionary]:
	return _rows


func get_save_layered_enabled() -> bool:
	return layered_section.visible and save_layered.button_pressed


func get_layered_destination() -> String:
	return layered_path.text.strip_edges()


func focus_layered_destination() -> void:
	if not layered_path or not layered_section.visible:
		return
	layered_path.grab_focus()
	layered_path.select_all()


func select_all_rows() -> void:
	for row in _rows:
		row["included"] = true
		var item: TreeItem = _item_by_target_id.get(str(row.get("target_id", "")))
		if item:
			item.set_checked(COLUMN_INCLUDE, true)
	plan_changed.emit()


func set_row_status(target_id: String, text: String, is_error := false) -> void:
	for row in _rows:
		if str(row.get("target_id", "")) == target_id:
			row["status"] = text
			row["status_error"] = is_error
			break
	var item: TreeItem = _item_by_target_id.get(target_id)
	if item:
		item.set_text(COLUMN_STATUS, text)
		item.set_custom_color(COLUMN_STATUS, Color(1.0, 0.42, 0.38) if is_error else Color(0.56, 0.82, 0.58))


func set_busy(busy: bool, message := "", completed := 0, total := 1) -> void:
	texture_tree.mouse_filter = Control.MOUSE_FILTER_IGNORE if busy else Control.MOUSE_FILTER_STOP
	show_unchanged.disabled = busy
	compare_mode.disabled = busy
	pixel_scale.disabled = busy
	save_layered.disabled = busy
	layered_path.editable = not busy and save_layered.button_pressed
	get_ok_button().disabled = busy
	get_cancel_button().disabled = busy
	save_all_button.disabled = busy
	discard_button.disabled = busy
	progress.visible = busy
	progress.max_value = maxi(total, 1)
	progress.value = clampi(completed, 0, maxi(total, 1))
	if not message.is_empty():
		status_label.text = message


func set_status(message: String) -> void:
	status_label.text = message


func _rebuild_tree() -> void:
	_rebuilding_tree = true
	texture_tree.set_block_signals(true)
	texture_tree.clear()
	_item_by_target_id.clear()
	var root := texture_tree.create_item()
	var first_item: TreeItem
	for row_index in range(_rows.size()):
		var row: Dictionary = _rows[row_index]
		var item := texture_tree.create_item(root)
		item.set_metadata(COLUMN_INCLUDE, row_index)
		item.set_cell_mode(COLUMN_INCLUDE, TreeItem.CELL_MODE_CHECK)
		item.set_editable(COLUMN_INCLUDE, true)
		item.set_checked(COLUMN_INCLUDE, bool(row.get("included", false)))
		item.set_text(COLUMN_TEXTURE, str(row.get("label", "Texture")))
		item.set_tooltip_text(COLUMN_TEXTURE, str(row.get("source_path", row.get("label", ""))))
		var thumbnail: Texture2D = row.get("thumbnail")
		if thumbnail:
			item.set_icon(COLUMN_TEXTURE, thumbnail)
			item.set_icon_max_width(COLUMN_TEXTURE, 28)
		item.set_cell_mode(COLUMN_ACTION, TreeItem.CELL_MODE_RANGE)
		item.set_text(COLUMN_ACTION, "Save,Save As & Reassign")
		item.set_range_config(COLUMN_ACTION, ACTION_SAVE, ACTION_SAVE_AS, 1)
		item.set_range(COLUMN_ACTION, int(row.get("action", ACTION_SAVE)))
		item.set_metadata(COLUMN_ACTION, int(row.get("action", ACTION_SAVE)))
		item.set_editable(COLUMN_ACTION, true)
		item.set_text(COLUMN_DESTINATION, str(row.get("destination", "")))
		item.set_editable(COLUMN_DESTINATION, int(row.get("action", ACTION_SAVE)) == ACTION_SAVE_AS)
		item.set_tooltip_text(COLUMN_DESTINATION, str(row.get("destination", "")))
		item.set_text(COLUMN_STATUS, str(row.get("status", "Changed" if bool(row.get("dirty", false)) else "Unchanged")))
		if bool(row.get("status_error", false)):
			item.set_custom_color(COLUMN_STATUS, Color(1.0, 0.42, 0.38))
		_item_by_target_id[str(row.get("target_id", ""))] = item
		if not first_item:
			first_item = item
	if first_item:
		first_item.select(COLUMN_TEXTURE)
		_refresh_preview()
	else:
		preview.texture = null
		preview_label.text = "No texture output is currently changed."
	texture_tree.set_block_signals(false)
	_rebuilding_tree = false


func _on_item_selected() -> void:
	_refresh_preview()


func _on_item_edited() -> void:
	if _rebuilding_tree:
		return
	var item := texture_tree.get_edited()
	if not item:
		return
	var row_index := int(item.get_metadata(COLUMN_INCLUDE))
	if row_index < 0 or row_index >= _rows.size():
		return
	var row: Dictionary = _rows[row_index]
	match texture_tree.get_edited_column():
		COLUMN_INCLUDE:
			row["included"] = item.is_checked(COLUMN_INCLUDE)
		COLUMN_ACTION:
			var previous_action := int(row.get("action", ACTION_SAVE))
			row["action"] = int(item.get_range(COLUMN_ACTION))
			item.set_metadata(COLUMN_ACTION, int(row["action"]))
			item.set_editable(COLUMN_DESTINATION, int(row["action"]) == ACTION_SAVE_AS)
			if int(row["action"]) == ACTION_SAVE:
				if previous_action == ACTION_SAVE_AS:
					row["save_as_destination"] = item.get_text(COLUMN_DESTINATION).strip_edges()
				row["destination"] = str(row.get("original_path", ""))
			else:
				var suggested := str(row.get("save_as_destination", "")).strip_edges()
				if suggested.is_empty():
					suggested = str(row.get("destination", ""))
				row["destination"] = suggested
			item.set_text(COLUMN_DESTINATION, str(row["destination"]))
			item.set_tooltip_text(COLUMN_DESTINATION, str(row["destination"]))
		COLUMN_DESTINATION:
			row["destination"] = item.get_text(COLUMN_DESTINATION).strip_edges()
			if int(row.get("action", ACTION_SAVE)) == ACTION_SAVE_AS:
				row["save_as_destination"] = row["destination"]
			item.set_tooltip_text(COLUMN_DESTINATION, str(row["destination"]))
	plan_changed.emit()


func _refresh_preview() -> void:
	var item := texture_tree.get_selected()
	if not item:
		return
	var row_index := int(item.get_metadata(COLUMN_INCLUDE))
	if row_index < 0 or row_index >= _rows.size():
		return
	var row: Dictionary = _rows[row_index]
	var target = row.get("target")
	var texture_session = row.get("session")
	var edited: Image = target.composite() if target and target.has_method("composite") else null
	var original: Image = texture_session.baseline_image if texture_session else null
	var mode := compare_mode.get_selected_id()
	if mode == 0:
		_preview_image = original.duplicate() if original else null
	elif mode == 2:
		_preview_image = _make_split_image(original, edited)
	else:
		_preview_image = edited
	preview.texture = ImageTexture.create_from_image(_preview_image) if _preview_image and not _preview_image.is_empty() else null
	var size := edited.get_size() if edited else Vector2i.ZERO
	preview_label.text = "%s  ·  %d × %d px" % [str(row.get("source_path", row.get("label", "Texture"))), size.x, size.y]
	_apply_preview_scale()


func _make_split_image(original: Image, edited: Image) -> Image:
	if not edited:
		return original.duplicate() if original else null
	var result := edited.duplicate()
	if not original:
		return result
	var before := original.duplicate()
	if before.get_size() != result.get_size():
		before.resize(result.get_width(), result.get_height(), Image.INTERPOLATE_NEAREST)
	var split_x: int = result.get_width() / 2
	result.blit_rect(before, Rect2i(0, 0, split_x, result.get_height()), Vector2i.ZERO)
	return result


func _apply_preview_scale() -> void:
	if not preview:
		return
	if pixel_scale.button_pressed and _preview_image:
		preview.custom_minimum_size = Vector2(_preview_image.get_size())
		preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		preview.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	else:
		preview.custom_minimum_size = Vector2(760, 200)
		preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED


func _on_save_layered_toggled(enabled: bool) -> void:
	layered_path.editable = enabled
	plan_changed.emit()


func _on_custom_action(action: StringName) -> void:
	match action:
		&"save_all":
			save_all_requested.emit()
		&"discard":
			discard_requested.emit()


func _make_summary_text() -> String:
	var dirty_count := 0
	for row in _rows:
		if bool(row.get("dirty", false)):
			dirty_count += 1
	if _rows.is_empty():
		return "No changed texture outputs. You can still save the hierarchy layer document below."
	return "%d changed texture%s · %d unique texture destination%s" % [
		dirty_count,
		"" if dirty_count == 1 else "s",
		_rows.size(),
		"" if _rows.size() == 1 else "s",
	]


func _make_thumbnail(image: Image) -> Texture2D:
	if not image or image.is_empty():
		return null
	var thumbnail := image.duplicate()
	var size: Vector2i = thumbnail.get_size()
	var scale := minf(28.0 / maxf(float(size.x), 1.0), 28.0 / maxf(float(size.y), 1.0))
	thumbnail.resize(maxi(1, roundi(size.x * scale)), maxi(1, roundi(size.y * scale)), Image.INTERPOLATE_BILINEAR)
	return ImageTexture.create_from_image(thumbnail)
