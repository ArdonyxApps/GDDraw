@tool
class_name GDDrawHistoryStack
extends RefCounted

const MAX_HISTORY := 32
const STATE_ENTRY_KIND := "gddraw_layer_session"
const ENTRY_KIND_KEY := "history_kind"
const ENTRY_STATE_KEY := "state"

var _undo_stack: Array = []
var _redo_stack: Array = []


func push_undo(image: Image) -> void:
	_push_bounded(_undo_stack, image.duplicate() if image else null)


func push_redo(image: Image) -> void:
	_redo_stack.push_back(image.duplicate() if image else null)


func push_undo_state(state: Dictionary) -> void:
	_push_bounded(_undo_stack, _make_state_entry(state))


func push_undo_state_owned(state: Dictionary) -> void:
	_push_bounded(_undo_stack, _make_owned_state_entry(state))


func push_redo_state(state: Dictionary) -> void:
	_redo_stack.push_back(_make_state_entry(state))


func pop_undo() -> Variant:
	return _undo_stack.pop_back()


func pop_redo() -> Variant:
	return _redo_stack.pop_back()


func is_state_entry(entry: Variant) -> bool:
	return (
		entry is Dictionary
		and str(entry.get(ENTRY_KIND_KEY, "")) == STATE_ENTRY_KIND
		and entry.get(ENTRY_STATE_KEY, null) is Dictionary
	)


func get_entry_state(entry: Variant) -> Dictionary:
	if not is_state_entry(entry):
		return {}
	return _duplicate_variant(entry.get(ENTRY_STATE_KEY, {}))


func clear_redo() -> void:
	_redo_stack.clear()


func clear() -> void:
	_undo_stack.clear()
	_redo_stack.clear()


func capture_state() -> Dictionary:
	return {
		"undo": _duplicate_entries(_undo_stack),
		"redo": _duplicate_entries(_redo_stack),
	}


func restore_state(state: Dictionary) -> void:
	_undo_stack = _duplicate_entries(state.get("undo", []))
	_redo_stack = _duplicate_entries(state.get("redo", []))


func can_undo() -> bool:
	return not _undo_stack.is_empty()


func can_redo() -> bool:
	return not _redo_stack.is_empty()


func _push_bounded(stack: Array, entry: Variant) -> void:
	if entry == null:
		return
	stack.push_back(entry)
	if stack.size() > MAX_HISTORY:
		stack.pop_front()


func _make_state_entry(state: Dictionary) -> Dictionary:
	return {
		ENTRY_KIND_KEY: STATE_ENTRY_KIND,
		ENTRY_STATE_KEY: _duplicate_variant(state),
	}


func _make_owned_state_entry(state: Dictionary) -> Dictionary:
	return {
		ENTRY_KIND_KEY: STATE_ENTRY_KIND,
		ENTRY_STATE_KEY: state,
	}


func _duplicate_entries(entries: Array) -> Array:
	var copies: Array = []
	for entry in entries:
		if entry is Image or is_state_entry(entry):
			copies.push_back(_duplicate_variant(entry))
	return copies


func _duplicate_variant(value: Variant) -> Variant:
	if value is Image:
		return value.duplicate()
	if value is Dictionary:
		var dictionary_copy := {}
		for key in value:
			dictionary_copy[_duplicate_variant(key)] = _duplicate_variant(value[key])
		return dictionary_copy
	if value is Array:
		var array_copy: Array = []
		for item in value:
			array_copy.push_back(_duplicate_variant(item))
		return array_copy
	if value is PackedByteArray:
		return value.duplicate()
	if value is PackedInt32Array:
		return value.duplicate()
	if value is PackedInt64Array:
		return value.duplicate()
	if value is PackedFloat32Array:
		return value.duplicate()
	if value is PackedFloat64Array:
		return value.duplicate()
	if value is PackedStringArray:
		return value.duplicate()
	if value is PackedVector2Array:
		return value.duplicate()
	if value is PackedVector3Array:
		return value.duplicate()
	if value is PackedColorArray:
		return value.duplicate()
	return value
