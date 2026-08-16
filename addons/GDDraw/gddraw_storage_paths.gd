@tool
class_name GDDrawStoragePaths
extends RefCounted

const PROJECT_ASSET_ROOT := "res://gddraw"
const DEFAULT_IMAGE_DIR := PROJECT_ASSET_ROOT + "/images"
const DEFAULT_BRUSH_DIR := PROJECT_ASSET_ROOT + "/brushes"
const DEFAULT_FONT_DIR := PROJECT_ASSET_ROOT + "/fonts"
const UPDATE_STAGING_DIR := "user://gddraw/updates"
const PLUGIN_PACKAGE_ROOT := "res://addons/GDDraw"
const SETTINGS_SECTION := "GDDraw"
const DEFAULT_FONT_DIRECTORY_KEY := "default_font_directory"
const CUSTOM_BRUSH_PRESETS_KEY := "custom_brush_presets"


static func normalize_path(path: String) -> String:
	var normalized_path := path.strip_edges().replace("\\", "/")
	if normalized_path.is_empty():
		return ""
	normalized_path = normalized_path.simplify_path()
	if normalized_path in ["res://", "user://"]:
		return normalized_path
	return normalized_path.trim_suffix("/")


static func is_plugin_package_path(path: String) -> bool:
	var normalized_path := normalize_path(path).to_lower()
	var plugin_root := PLUGIN_PACKAGE_ROOT.to_lower()
	return normalized_path == plugin_root or normalized_path.begins_with(plugin_root + "/")


static func is_writable_project_path(path: String) -> bool:
	var normalized_path := normalize_path(path)
	return normalized_path.begins_with("res://") and not is_plugin_package_path(normalized_path)


static func get_default_font_dir(editor_settings: Object) -> String:
	if editor_settings:
		return str(editor_settings.get_project_metadata(SETTINGS_SECTION, DEFAULT_FONT_DIRECTORY_KEY, DEFAULT_FONT_DIR))
	return DEFAULT_FONT_DIR


static func set_default_font_dir(editor_settings: Object, path: String) -> void:
	if editor_settings:
		editor_settings.set_project_metadata(SETTINGS_SECTION, DEFAULT_FONT_DIRECTORY_KEY, path)


static func get_custom_brush_presets(editor_settings: Object) -> Variant:
	if editor_settings:
		return editor_settings.get_project_metadata(SETTINGS_SECTION, CUSTOM_BRUSH_PRESETS_KEY, [])
	return []


static func set_custom_brush_presets(editor_settings: Object, presets: Array[Dictionary]) -> void:
	if editor_settings:
		editor_settings.set_project_metadata(SETTINGS_SECTION, CUSTOM_BRUSH_PRESETS_KEY, presets)
