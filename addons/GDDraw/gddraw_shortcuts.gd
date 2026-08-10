@tool
class_name GDDrawShortcutMap
extends RefCounted

const ACTION_NONE := ""
const ACTION_COPY := "copy"
const ACTION_CUT := "cut"
const ACTION_PASTE := "paste"
const ACTION_DELETE := "delete"
const ACTION_CANCEL := "cancel"
const ACTION_SELECT_ALL := "select_all"
const ACTION_DUPLICATE := "duplicate"
const ACTION_COMMIT := "commit"

const SHORTCUTS := [
	{"action": ACTION_COPY, "keycode": KEY_C, "ctrl": true},
	{"action": ACTION_CUT, "keycode": KEY_X, "ctrl": true},
	{"action": ACTION_PASTE, "keycode": KEY_V, "ctrl": true},
	{"action": ACTION_SELECT_ALL, "keycode": KEY_A, "ctrl": true},
	{"action": ACTION_DUPLICATE, "keycode": KEY_D, "ctrl": true},
	{"action": ACTION_COMMIT, "keycode": KEY_ENTER},
	{"action": ACTION_DELETE, "keycode": KEY_DELETE},
	{"action": ACTION_CANCEL, "keycode": KEY_ESCAPE},
]


func get_action(event: InputEvent) -> String:
	if not _is_shortcut_event(event):
		return ACTION_NONE

	for shortcut in SHORTCUTS:
		if _matches_shortcut(event, shortcut):
			return str(shortcut.get("action", ACTION_NONE))
	return ACTION_NONE


func _is_shortcut_event(event: InputEvent) -> bool:
	return event is InputEventKey and event.pressed and not event.echo


func _matches_shortcut(event: InputEventKey, shortcut: Dictionary) -> bool:
	if event.keycode != int(shortcut.get("keycode", KEY_NONE)):
		return false
	if event.ctrl_pressed != bool(shortcut.get("ctrl", false)):
		return false
	if event.alt_pressed != bool(shortcut.get("alt", false)):
		return false
	if event.shift_pressed != bool(shortcut.get("shift", false)):
		return false
	if event.meta_pressed != bool(shortcut.get("meta", false)):
		return false
	return true
