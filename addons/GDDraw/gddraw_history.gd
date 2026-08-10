@tool
class_name GDDrawHistoryStack
extends RefCounted

const MAX_HISTORY := 32

var _undo_stack: Array[Image] = []
var _redo_stack: Array[Image] = []


func push_undo(image: Image) -> void:
	_undo_stack.push_back(image)
	if _undo_stack.size() > MAX_HISTORY:
		_undo_stack.pop_front()


func push_redo(image: Image) -> void:
	_redo_stack.push_back(image)


func pop_undo() -> Image:
	return _undo_stack.pop_back()


func pop_redo() -> Image:
	return _redo_stack.pop_back()


func clear_redo() -> void:
	_redo_stack.clear()


func clear() -> void:
	_undo_stack.clear()
	_redo_stack.clear()


func capture_state() -> Dictionary:
	return {
		"undo": _duplicate_images(_undo_stack),
		"redo": _duplicate_images(_redo_stack),
	}


func restore_state(state: Dictionary) -> void:
	_undo_stack = _duplicate_images(state.get("undo", []))
	_redo_stack = _duplicate_images(state.get("redo", []))


func can_undo() -> bool:
	return not _undo_stack.is_empty()


func can_redo() -> bool:
	return not _redo_stack.is_empty()


func _duplicate_images(images: Array) -> Array[Image]:
	var copies: Array[Image] = []
	for image in images:
		if image is Image:
			copies.push_back(image.duplicate())
	return copies
