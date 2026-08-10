@tool
class_name GDDrawPngIOHelper
extends RefCounted

const DEFAULT_SAVE_DIR := "res://gddraw"
const SETTINGS_SECTION := "GDDraw"
const DEFAULT_SAVE_DIR_KEY := "default_save_dir"


func make_default_png_name() -> String:
	var timestamp := Time.get_datetime_string_from_system().replace(":", "-")
	return "gddraw_%s.png" % timestamp


func normalize_png_path(path: String) -> String:
	var normalized_path := path.strip_edges()
	if normalized_path.is_empty() or not normalized_path.begins_with("res://"):
		return ""
	if normalized_path.get_extension().is_empty():
		normalized_path += ".png"
	elif normalized_path.get_extension().to_lower() != "png":
		normalized_path = "%s.png" % normalized_path.get_basename()
	return normalized_path


func ensure_resource_dir(path: String) -> int:
	var normalized_path := path.strip_edges()
	if normalized_path.is_empty() or not normalized_path.begins_with("res://"):
		return ERR_INVALID_PARAMETER
	return DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(normalized_path))


func get_default_save_dir(editor_settings: EditorSettings) -> String:
	if editor_settings:
		return str(editor_settings.get_project_metadata(SETTINGS_SECTION, DEFAULT_SAVE_DIR_KEY, DEFAULT_SAVE_DIR))
	return DEFAULT_SAVE_DIR


func set_default_save_dir(editor_settings: EditorSettings, path: String) -> bool:
	var normalized_path := path.strip_edges()
	if normalized_path.is_empty() or not normalized_path.begins_with("res://"):
		return false
	if editor_settings:
		editor_settings.set_project_metadata(SETTINGS_SECTION, DEFAULT_SAVE_DIR_KEY, normalized_path)
	return true
