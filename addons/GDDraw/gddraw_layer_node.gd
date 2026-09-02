@tool
class_name GDDrawLayerNode
extends RefCounted

enum Kind {
	PAINT,
	GROUP,
}

var id := ""
var kind := Kind.PAINT
var name := "Layer"
var visible := true
var opacity := 1.0
var locked := false
## Document-space position of the paint image's top-left pixel. Paint layers
## may extend beyond their paint target's fixed canvas/export bounds.
var origin := Vector2i.ZERO
var image: Image
var eraser_source: Image
var children: Array = []


func is_paint_layer() -> bool:
	return kind == Kind.PAINT


func is_group() -> bool:
	return kind == Kind.GROUP


func capture_state() -> Dictionary:
	var child_states: Array[Dictionary] = []
	for child in children:
		if child and child.has_method("capture_state"):
			child_states.push_back(child.capture_state())
	return {
		"id": id,
		"kind": kind,
		"name": name,
		"visible": visible,
		"opacity": opacity,
		"locked": locked,
		"origin": origin,
		"image": image.duplicate() if image else null,
		"eraser_source": eraser_source.duplicate() if eraser_source else null,
		"children": child_states,
	}


func capture_history_state(
	image_override_id := "",
	image_override: Image = null,
	origin_override = null,
	eraser_override: Image = null
) -> Dictionary:
	var child_states: Array[Dictionary] = []
	for child in children:
		if child and child.has_method("capture_history_state"):
			child_states.push_back(child.capture_history_state(
				image_override_id,
				image_override,
				origin_override,
				eraser_override
			))
	var uses_override := is_paint_layer() and id == image_override_id and image_override != null
	return {
		"id": id,
		"kind": kind,
		"name": name,
		"visible": visible,
		"opacity": opacity,
		"locked": locked,
		"origin": origin_override if uses_override and origin_override != null else origin,
		# The stroke-start image is already an owned copy. Other editable images
		# need one snapshot because later layer edits mutate them in place.
		"image": image_override if uses_override else (image.duplicate() if image else null),
		# Eraser sources are immutable after creation; resize/move operations replace
		# the Image object instead of modifying it, so history can safely share them.
		"eraser_source": eraser_override if uses_override and eraser_override else eraser_source,
		"children": child_states,
	}


func restore_state(state: Dictionary) -> void:
	id = str(state.get("id", ""))
	kind = int(state.get("kind", Kind.PAINT))
	name = str(state.get("name", "Layer"))
	visible = bool(state.get("visible", true))
	opacity = clampf(float(state.get("opacity", 1.0)), 0.0, 1.0)
	locked = bool(state.get("locked", false))
	origin = state.get("origin", Vector2i.ZERO)
	var state_image: Image = state.get("image", null)
	image = state_image.duplicate() if state_image else null
	var state_eraser_source: Image = state.get("eraser_source", null)
	eraser_source = state_eraser_source.duplicate() if state_eraser_source else null
	children.clear()
	if kind != Kind.GROUP:
		return
	for child_state in state.get("children", []):
		if not child_state is Dictionary:
			continue
		var child := GDDrawLayerNode.new()
		child.restore_state(child_state)
		children.push_back(child)
