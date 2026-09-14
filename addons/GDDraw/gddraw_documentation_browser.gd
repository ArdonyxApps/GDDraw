@tool
class_name GDDrawDocumentationBrowser
extends AcceptDialog

const DEFAULT_MANIFEST_PATH := "res://addons/GDDraw/docs/navigation.json"
const DOCUMENTATION_ROOT := "res://addons/GDDraw/docs/"
const ACCENT_COLOR := "#6EA7E8"
const MUTED_COLOR := "#A7ADB5"
const CODE_COLOR := "#D7BA7D"
const CALLOUT_COLOR := "#8FB9E8"

var _manifest_path := DEFAULT_MANIFEST_PATH
var _manifest: Dictionary = {}
var _pages: Dictionary = {}
var _page_order := PackedStringArray()
var _current_page := ""
var _history := PackedStringArray()
var _history_index := -1
var _rebuilding_navigation := false

var _navigation_tree: Tree
var _filter_field: LineEdit
var _back_button: Button
var _forward_button: Button
var _breadcrumb: Label
var _content: RichTextLabel
var _empty_message: Label


func _ready() -> void:
	title = "GDDraw Documentation"
	min_size = Vector2i(760, 500)
	dialog_text = ""
	get_ok_button().text = "Close"
	_build_interface()
	_load_manifest()


func configure(manifest_path := DEFAULT_MANIFEST_PATH) -> void:
	_manifest_path = manifest_path
	if is_node_ready():
		_load_manifest()


func open_documentation(page_path := "index.md") -> void:
	if _pages.is_empty():
		_load_manifest()
	var resolved := _normalize_page_path(page_path)
	if not _pages.has(resolved):
		resolved = _normalize_page_path(str(_manifest.get("home", "index.md")))
	if not _pages.has(resolved) and not _page_order.is_empty():
		resolved = _page_order[0]
	if not resolved.is_empty():
		_show_page(resolved, true)
	popup_centered_clamped(Vector2i(960, 660), 0.9)


func get_current_page_path() -> String:
	return _current_page


func get_page_count() -> int:
	return _pages.size()


func get_rendered_document_text() -> String:
	return _content.get_parsed_text() if _content else ""


func render_markdown_for_tests(markdown: String) -> String:
	return _markdown_to_bbcode(markdown)


func _build_interface() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var root := VBoxContainer.new()
	root.custom_minimum_size = Vector2(900, 570)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 4)
	root.add_child(toolbar)

	_back_button = Button.new()
	_back_button.text = "‹"
	_back_button.custom_minimum_size = Vector2(30, 28)
	_back_button.tooltip_text = "Previous documentation page"
	_back_button.disabled = true
	_back_button.pressed.connect(_navigate_history.bind(-1))
	toolbar.add_child(_back_button)

	_forward_button = Button.new()
	_forward_button.text = "›"
	_forward_button.custom_minimum_size = Vector2(30, 28)
	_forward_button.tooltip_text = "Next documentation page"
	_forward_button.disabled = true
	_forward_button.pressed.connect(_navigate_history.bind(1))
	toolbar.add_child(_forward_button)

	_breadcrumb = Label.new()
	_breadcrumb.text = "GDDraw Documentation"
	_breadcrumb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_breadcrumb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_breadcrumb.add_theme_color_override("font_color", Color("#C9CDD2"))
	toolbar.add_child(_breadcrumb)

	root.add_child(HSeparator.new())

	var split := HSplitContainer.new()
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 235
	root.add_child(split)

	var navigation_panel := PanelContainer.new()
	navigation_panel.custom_minimum_size.x = 210
	split.add_child(navigation_panel)
	var navigation_column := VBoxContainer.new()
	navigation_column.add_theme_constant_override("separation", 6)
	navigation_panel.add_child(navigation_column)

	_filter_field = LineEdit.new()
	_filter_field.placeholder_text = "Filter documentation"
	_filter_field.clear_button_enabled = true
	_filter_field.tooltip_text = "Filter documentation page titles"
	_filter_field.text_changed.connect(_on_filter_changed)
	navigation_column.add_child(_filter_field)

	_navigation_tree = Tree.new()
	_navigation_tree.name = "Documentation Navigation"
	_navigation_tree.hide_root = true
	_navigation_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_navigation_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_navigation_tree.item_selected.connect(_on_navigation_item_selected)
	navigation_column.add_child(_navigation_tree)

	var content_panel := PanelContainer.new()
	content_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(content_panel)

	var content_margin := MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", 18)
	content_margin.add_theme_constant_override("margin_top", 12)
	content_margin.add_theme_constant_override("margin_right", 18)
	content_margin.add_theme_constant_override("margin_bottom", 12)
	content_panel.add_child(content_margin)

	_content = RichTextLabel.new()
	_content.name = "Documentation Content"
	_content.bbcode_enabled = true
	_content.fit_content = false
	_content.scroll_active = true
	_content.selection_enabled = true
	_content.context_menu_enabled = true
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.meta_clicked.connect(_on_content_meta_clicked)
	content_margin.add_child(_content)

	_empty_message = Label.new()
	_empty_message.text = "Documentation could not be loaded. Reinstall GDDraw to restore the packaged documentation files."
	_empty_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_message.visible = false
	content_margin.add_child(_empty_message)


func _load_manifest() -> void:
	_manifest.clear()
	_pages.clear()
	_page_order = PackedStringArray()
	if not FileAccess.file_exists(_manifest_path):
		_show_load_error("Missing documentation manifest: %s" % _manifest_path)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_manifest_path))
	if not parsed is Dictionary:
		_show_load_error("The packaged documentation manifest is invalid.")
		return
	_manifest = parsed
	for section_value in _manifest.get("sections", []):
		if not section_value is Dictionary:
			continue
		var section: Dictionary = section_value
		for page_value in section.get("pages", []):
			if not page_value is Dictionary:
				continue
			var page: Dictionary = page_value
			var page_path := _normalize_page_path(str(page.get("path", "")))
			if page_path.is_empty():
				continue
			page["path"] = page_path
			page["section"] = str(section.get("title", "Documentation"))
			_pages[page_path] = page
			_page_order.push_back(page_path)
	_rebuild_navigation()
	_empty_message.visible = _pages.is_empty()
	_content.visible = not _pages.is_empty()


func _show_load_error(message: String) -> void:
	if _navigation_tree:
		_navigation_tree.clear()
	if _content:
		_content.clear()
		_content.visible = false
	if _empty_message:
		_empty_message.text = message
		_empty_message.visible = true


func _rebuild_navigation(filter_text := "") -> void:
	if not _navigation_tree:
		return
	_rebuilding_navigation = true
	_navigation_tree.clear()
	var root := _navigation_tree.create_item()
	var normalized_filter := filter_text.strip_edges().to_lower()
	for section_value in _manifest.get("sections", []):
		if not section_value is Dictionary:
			continue
		var section: Dictionary = section_value
		var matching_pages: Array[Dictionary] = []
		for page_value in section.get("pages", []):
			if not page_value is Dictionary:
				continue
			var page: Dictionary = page_value
			var page_path := _normalize_page_path(str(page.get("path", "")))
			var searchable := "%s %s %s" % [str(page.get("title", "")), page_path, str(section.get("title", ""))]
			if normalized_filter.is_empty() or searchable.to_lower().contains(normalized_filter):
				matching_pages.push_back(page)
		if matching_pages.is_empty():
			continue
		var section_item := _navigation_tree.create_item(root)
		section_item.set_text(0, str(section.get("title", "Documentation")))
		section_item.set_selectable(0, false)
		section_item.set_custom_color(0, Color("#B9C5D3"))
		for page in matching_pages:
			var page_path := _normalize_page_path(str(page.get("path", "")))
			var page_item := _navigation_tree.create_item(section_item)
			page_item.set_text(0, str(page.get("title", page_path.get_file().get_basename())))
			page_item.set_tooltip_text(0, str(page.get("description", page_item.get_text(0))))
			page_item.set_metadata(0, page_path)
			if page_path == _current_page:
				page_item.select(0)
		section_item.collapsed = false
	_rebuilding_navigation = false


func _on_filter_changed(filter_text: String) -> void:
	_rebuild_navigation(filter_text)


func _on_navigation_item_selected() -> void:
	if _rebuilding_navigation or not _navigation_tree:
		return
	var selected := _navigation_tree.get_selected()
	if not selected:
		return
	var page_path := str(selected.get_metadata(0))
	if not page_path.is_empty():
		_show_page(page_path, true)


func _show_page(page_path: String, add_to_history: bool) -> void:
	var normalized := _normalize_page_path(page_path)
	if not _pages.has(normalized):
		return
	var absolute_path := DOCUMENTATION_ROOT + normalized
	if not FileAccess.file_exists(absolute_path):
		_show_load_error("Missing documentation page: %s" % absolute_path)
		return
	_current_page = normalized
	var page: Dictionary = _pages[normalized]
	_breadcrumb.text = "%s  ›  %s" % [str(page.get("section", "Documentation")), str(page.get("title", normalized.get_file().get_basename()))]
	_content.visible = true
	_empty_message.visible = false
	_content.text = _markdown_to_bbcode(FileAccess.get_file_as_string(absolute_path))
	_content.scroll_to_line(0)
	if add_to_history:
		while _history.size() - 1 > _history_index:
			_history.remove_at(_history.size() - 1)
		if _history.is_empty() or _history[_history.size() - 1] != normalized:
			_history.push_back(normalized)
		_history_index = _history.size() - 1
	_update_history_buttons()
	_select_navigation_page(normalized)


func _select_navigation_page(page_path: String) -> void:
	if not _navigation_tree:
		return
	var item := _navigation_tree.get_root().get_first_child() if _navigation_tree.get_root() else null
	while item:
		var page_item := item.get_first_child()
		while page_item:
			if str(page_item.get_metadata(0)) == page_path:
				_rebuilding_navigation = true
				page_item.select(0)
				_navigation_tree.scroll_to_item(page_item)
				_rebuilding_navigation = false
				return
			page_item = page_item.get_next()
		item = item.get_next()


func _navigate_history(direction: int) -> void:
	var next_index := _history_index + direction
	if next_index < 0 or next_index >= _history.size():
		return
	_history_index = next_index
	_show_page(_history[_history_index], false)


func _update_history_buttons() -> void:
	if _back_button:
		_back_button.disabled = _history_index <= 0
	if _forward_button:
		_forward_button.disabled = _history_index < 0 or _history_index >= _history.size() - 1


func _on_content_meta_clicked(meta: Variant) -> void:
	var target := str(meta).strip_edges()
	if target.begins_with("http://") or target.begins_with("https://"):
		OS.shell_open(target)
		return
	var page_path := target.get_slice("#", 0)
	if page_path.begins_with("./"):
		page_path = page_path.trim_prefix("./")
	if _pages.has(_normalize_page_path(page_path)):
		_show_page(page_path, true)


func _normalize_page_path(page_path: String) -> String:
	var normalized := page_path.strip_edges().replace("\\", "/")
	while normalized.begins_with("./"):
		normalized = normalized.trim_prefix("./")
	if normalized.begins_with(DOCUMENTATION_ROOT):
		normalized = normalized.trim_prefix(DOCUMENTATION_ROOT)
	if normalized.contains("..") or normalized.begins_with("/"):
		return ""
	return normalized


func _markdown_to_bbcode(markdown: String) -> String:
	var output := PackedStringArray()
	var in_code_block := false
	var code_lines := PackedStringArray()
	for raw_line in markdown.replace("\r\n", "\n").split("\n"):
		var line := str(raw_line)
		if line.strip_edges().begins_with("```"):
			if in_code_block:
				output.push_back("[bgcolor=#202328][color=%s]%s[/color][/bgcolor]\n" % [CODE_COLOR, _escape_bbcode("\n".join(code_lines))])
				code_lines = PackedStringArray()
			in_code_block = not in_code_block
			continue
		if in_code_block:
			code_lines.push_back(line)
			continue
		var stripped := line.strip_edges()
		if stripped.is_empty():
			output.push_back("\n")
		elif stripped.begins_with("#### "):
			output.push_back("[font_size=16][b]%s[/b][/font_size]\n" % _inline_markdown_to_bbcode(stripped.trim_prefix("#### ")))
		elif stripped.begins_with("### "):
			output.push_back("[font_size=18][b][color=%s]%s[/color][/b][/font_size]\n" % [ACCENT_COLOR, _inline_markdown_to_bbcode(stripped.trim_prefix("### "))])
		elif stripped.begins_with("## "):
			output.push_back("\n[font_size=21][b]%s[/b][/font_size]\n[color=#50555C]────────────────────────────────────────[/color]\n" % _inline_markdown_to_bbcode(stripped.trim_prefix("## ")))
		elif stripped.begins_with("# "):
			output.push_back("[font_size=26][b]%s[/b][/font_size]\n[color=%s]%s[/color]\n" % [_inline_markdown_to_bbcode(stripped.trim_prefix("# ")), ACCENT_COLOR, "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"])
		elif stripped.begins_with("> "):
			output.push_back("[indent][color=%s]▌ %s[/color][/indent]\n" % [CALLOUT_COLOR, _inline_markdown_to_bbcode(stripped.trim_prefix("> "))])
		elif stripped.begins_with("- "):
			output.push_back("[indent]• %s[/indent]\n" % _inline_markdown_to_bbcode(stripped.trim_prefix("- ")))
		elif _is_numbered_list_line(stripped):
			var separator := stripped.find(". ")
			output.push_back("[indent]%s. %s[/indent]\n" % [stripped.left(separator), _inline_markdown_to_bbcode(stripped.substr(separator + 2))])
		elif stripped == "---":
			output.push_back("[color=#50555C]────────────────────────────────────────[/color]\n")
		else:
			output.push_back("%s\n" % _inline_markdown_to_bbcode(stripped))
	if in_code_block and not code_lines.is_empty():
		output.push_back("[bgcolor=#202328][color=%s]%s[/color][/bgcolor]\n" % [CODE_COLOR, _escape_bbcode("\n".join(code_lines))])
	return "".join(output)


func _is_numbered_list_line(line: String) -> bool:
	var separator := line.find(". ")
	if separator <= 0:
		return false
	return line.left(separator).is_valid_int()


func _inline_markdown_to_bbcode(text: String) -> String:
	var output := ""
	var index := 0
	while index < text.length():
		if text.substr(index, 2) == "![":
			var label_end := text.find("](", index + 2)
			var target_end := text.find(")", label_end + 2) if label_end >= 0 else -1
			if label_end >= 0 and target_end >= 0:
				var alt_text := text.substr(index + 2, label_end - index - 2)
				var image_target := text.substr(label_end + 2, target_end - label_end - 2)
				var image_path := _resolve_document_image_path(image_target)
				if not image_path.is_empty():
					output += "[img]%s[/img]\n[color=%s]%s[/color]" % [image_path, MUTED_COLOR, _escape_bbcode(alt_text)]
				else:
					output += "[color=%s]Image: %s[/color]" % [MUTED_COLOR, _escape_bbcode(alt_text)]
				index = target_end + 1
				continue
		if text.substr(index, 2) == "**":
			var close := text.find("**", index + 2)
			if close >= 0:
				output += "[b]%s[/b]" % _inline_markdown_to_bbcode(text.substr(index + 2, close - index - 2))
				index = close + 2
				continue
		if text[index] == "`":
			var close := text.find("`", index + 1)
			if close >= 0:
				output += "[bgcolor=#25282D][color=%s]%s[/color][/bgcolor]" % [CODE_COLOR, _escape_bbcode(text.substr(index + 1, close - index - 1))]
				index = close + 1
				continue
		if text[index] == "[":
			var label_end := text.find("](", index + 1)
			var target_end := text.find(")", label_end + 2) if label_end >= 0 else -1
			if label_end >= 0 and target_end >= 0:
				var label := text.substr(index + 1, label_end - index - 1)
				var target := text.substr(label_end + 2, target_end - label_end - 2)
				output += "[url=%s][color=%s]%s[/color][/url]" % [_escape_bbcode(target), ACCENT_COLOR, _escape_bbcode(label)]
				index = target_end + 1
				continue
		if text[index] == "*":
			var close := text.find("*", index + 1)
			if close >= 0:
				output += "[i]%s[/i]" % _inline_markdown_to_bbcode(text.substr(index + 1, close - index - 1))
				index = close + 1
				continue
		output += _escape_bbcode(text[index])
		index += 1
	return output


func _resolve_document_image_path(target: String) -> String:
	var normalized := target.strip_edges().replace("\\", "/")
	if normalized.contains("..") or normalized.begins_with("http://") or normalized.begins_with("https://"):
		return ""
	var resource_path := normalized if normalized.begins_with("res://") else DOCUMENTATION_ROOT + normalized.trim_prefix("./")
	if not resource_path.begins_with(DOCUMENTATION_ROOT) or not ResourceLoader.exists(resource_path):
		return ""
	return resource_path


func _escape_bbcode(text: String) -> String:
	return text.replace("[", "[lb]")
