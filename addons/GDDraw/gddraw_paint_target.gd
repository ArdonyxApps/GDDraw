@tool
class_name GDDrawPaintTarget
extends RefCounted

const LayerNode := preload("res://addons/GDDraw/gddraw_layer_node.gd")
const MAX_LAYER_DIMENSION := 16384

var target_id := ""
var owner_group_id := ""
var label := "Paint Target"
var channel_id := "rgba"
var size := Vector2i.ONE
var binding: Dictionary = {}
var nodes: Array = []
var selected_layer_id := ""

var _next_node_serial := 1
var _saved_composite: Image
var _content_revision := 0


func initialize(
	initial_size: Vector2i,
	initial_image: Image = null,
	initial_label := "Paint Target",
	initial_channel := "rgba",
	mark_initial_saved := true
) -> bool:
	if initial_size.x <= 0 or initial_size.y <= 0:
		return false
	size = initial_size
	label = initial_label.strip_edges() if not initial_label.strip_edges().is_empty() else "Paint Target"
	channel_id = initial_channel.strip_edges() if not initial_channel.strip_edges().is_empty() else "rgba"
	nodes.clear()
	_next_node_serial = 1
	_content_revision = 0
	var source := _normalize_image(initial_image)
	if not source:
		source = _make_transparent_image()
	var base_layer := LayerNode.new()
	base_layer.id = _allocate_node_id("layer")
	base_layer.kind = LayerNode.Kind.PAINT
	base_layer.name = "Base"
	base_layer.origin = Vector2i.ZERO
	base_layer.image = source
	base_layer.eraser_source = source.duplicate()
	nodes.push_back(base_layer)
	selected_layer_id = base_layer.id
	_saved_composite = composite() if mark_initial_saved else null
	return true


func add_paint_layer(
	layer_name := "",
	source_image: Image = null,
	parent_group_id := "",
	index := 0,
	layer_origin := Vector2i.ZERO
) -> String:
	var container: Array = _get_child_container(parent_group_id)
	if container == null:
		return ""
	if not parent_group_id.is_empty() and is_node_effectively_locked(parent_group_id):
		return ""
	var normalized := _normalize_layer_image(source_image)
	if source_image and not normalized:
		return ""
	if not normalized:
		normalized = _make_transparent_image()
	if not _layer_workspace_is_safe(normalized, layer_origin, size):
		return ""
	var layer := LayerNode.new()
	layer.id = _allocate_node_id("layer")
	layer.kind = LayerNode.Kind.PAINT
	layer.name = layer_name.strip_edges()
	layer.origin = layer_origin
	if layer.name.is_empty():
		layer.name = "Paint Layer %d" % (_next_node_serial - 1)
	layer.image = normalized
	layer.eraser_source = normalized.duplicate()
	container.insert(clampi(index, 0, container.size()), layer)
	selected_layer_id = layer.id
	return layer.id


func add_group(group_name := "", parent_group_id := "", index := 0) -> String:
	var container: Array = _get_child_container(parent_group_id)
	if container == null:
		return ""
	if not parent_group_id.is_empty() and is_node_effectively_locked(parent_group_id):
		return ""
	var group := LayerNode.new()
	group.id = _allocate_node_id("group")
	group.kind = LayerNode.Kind.GROUP
	group.name = group_name.strip_edges()
	if group.name.is_empty():
		group.name = "Group %d" % (_next_node_serial - 1)
	container.insert(clampi(index, 0, container.size()), group)
	return group.id


func duplicate_node(node_id: String) -> String:
	var context := _find_context(node_id)
	if context.is_empty() or bool(context.get("locked_by_ancestor", false)):
		return ""
	var source = context.get("node")
	if not source or _node_or_descendants_locked(source):
		return ""
	var duplicate = _duplicate_node_with_new_ids(source, true)
	if not duplicate:
		return ""
	var container: Array = context.get("container", [])
	var index := int(context.get("index", 0))
	container.insert(clampi(index, 0, container.size()), duplicate)
	if duplicate.is_paint_layer():
		selected_layer_id = duplicate.id
	return duplicate.id


func capture_node_state(node_id: String) -> Dictionary:
	var node = find_node(node_id)
	return node.capture_state() if node else {}


func can_insert_node_state(node_state: Dictionary, parent_group_id := "") -> bool:
	var container: Array = _get_child_container(parent_group_id)
	if container == null:
		return false
	if not parent_group_id.is_empty() and is_node_effectively_locked(parent_group_id):
		return false
	return _node_state_is_valid_for_target(node_state)


func insert_node_state(
	node_state: Dictionary,
	parent_group_id := "",
	index := 0,
	rename_root := true
) -> String:
	if not can_insert_node_state(node_state, parent_group_id):
		return ""
	var source = _make_valid_node_from_state(node_state)
	if not source:
		return ""
	_assign_new_node_ids(source, rename_root)
	var container: Array = _get_child_container(parent_group_id)
	container.insert(clampi(index, 0, container.size()), source)
	if source.is_paint_layer():
		selected_layer_id = source.id
	return source.id


func show_only_node(node_id: String) -> bool:
	if not find_node(node_id):
		return false
	var changed := _show_only_node_in(nodes, node_id)
	return changed


func show_all_nodes() -> bool:
	return _set_nodes_visible_recursive(nodes, true)


func can_merge_node_down(node_id: String) -> bool:
	var context := _find_context(node_id)
	if context.is_empty() or bool(context.get("locked_by_ancestor", false)):
		return false
	var node = context.get("node")
	var container: Array = context.get("container", [])
	var index := int(context.get("index", -1))
	if not node or not node.is_paint_layer() or node.locked or index < 0 or index + 1 >= container.size():
		return false
	var below = container[index + 1]
	return below != null and below.is_paint_layer() and not below.locked


func merge_node_down(node_id: String) -> String:
	if not can_merge_node_down(node_id):
		return ""
	var context := _find_context(node_id)
	var container: Array = context.get("container", [])
	var index := int(context.get("index", -1))
	var upper = container[index]
	var lower = container[index + 1]
	var bounds := Rect2i(upper.origin, upper.image.get_size()).merge(Rect2i(lower.origin, lower.image.get_size()))
	if bounds.size.x <= 0 or bounds.size.y <= 0 or bounds.size.x > MAX_LAYER_DIMENSION or bounds.size.y > MAX_LAYER_DIMENSION:
		return ""
	var merged := _make_transparent_layer_image(bounds.size)
	_composite_nodes(merged, [upper, lower], "", null, Vector2i.ZERO, bounds.position)
	lower.image = merged
	lower.eraser_source = merged.duplicate()
	lower.origin = bounds.position
	lower.visible = true
	lower.opacity = 1.0
	container.remove_at(index)
	selected_layer_id = lower.id
	return lower.id


func can_merge_visible_nodes() -> bool:
	return _count_visible_paint_nodes(nodes, true) > 1 and not _has_effectively_locked_visible_node(nodes, false)


func merge_visible_nodes() -> String:
	if not can_merge_visible_nodes():
		return ""
	var bounds := _get_visible_nodes_bounds(nodes, true)
	if not bounds.has_area() or bounds.size.x > MAX_LAYER_DIMENSION or bounds.size.y > MAX_LAYER_DIMENSION:
		return ""
	var merged_image := _make_transparent_layer_image(bounds.size)
	_composite_nodes(merged_image, nodes, "", null, Vector2i.ZERO, bounds.position)
	for node in nodes:
		node.visible = false
	var merged_id := add_paint_layer("Merged Visible", merged_image, "", 0, bounds.position)
	return merged_id


func remove_node(node_id: String) -> bool:
	var context := _find_context(node_id)
	if context.is_empty() or bool(context.get("locked_by_ancestor", false)):
		return false
	var node = context.get("node")
	if not node or _node_or_descendants_locked(node):
		return false
	if _count_paint_layers_in(node) >= get_paint_layer_count():
		return false
	var container: Array = context.get("container", [])
	container.remove_at(int(context.get("index", -1)))
	if not find_node(selected_layer_id):
		var first_layer = get_first_paint_layer()
		selected_layer_id = first_layer.id if first_layer else ""
	return ensure_invariants()


func move_node(node_id: String, parent_group_id := "", index := 0) -> bool:
	var context := _find_context(node_id)
	if context.is_empty() or bool(context.get("locked_by_ancestor", false)):
		return false
	var node = context.get("node")
	if not node or _node_or_descendants_locked(node):
		return false
	if node.id == parent_group_id or (node.is_group() and _node_contains_id(node, parent_group_id)):
		return false
	var destination: Array = _get_child_container(parent_group_id)
	if destination == null:
		return false
	if not parent_group_id.is_empty() and is_node_effectively_locked(parent_group_id):
		return false
	var source: Array = context.get("container", [])
	var source_index := int(context.get("index", -1))
	var destination_index := clampi(index, 0, destination.size() - (1 if source == destination else 0))
	if source == destination:
		if source_index == destination_index:
			return false
	source.remove_at(source_index)
	destination.insert(clampi(destination_index, 0, destination.size()), node)
	return ensure_invariants()


func select_layer(layer_id: String) -> bool:
	var layer = find_node(layer_id)
	if not layer or not layer.is_paint_layer():
		return false
	selected_layer_id = layer.id
	return true


func get_selected_layer():
	var layer = find_node(selected_layer_id)
	return layer if layer and layer.is_paint_layer() else null


func get_selected_layer_image() -> Image:
	var layer = get_selected_layer()
	return layer.image.duplicate() if layer and layer.image else null


func get_selected_layer_image_reference() -> Image:
	var layer = get_selected_layer()
	return layer.image if layer and layer.image else null


func get_selected_eraser_source() -> Image:
	var layer = get_selected_layer()
	return layer.eraser_source.duplicate() if layer and layer.eraser_source else null


func get_selected_eraser_source_reference() -> Image:
	var layer = get_selected_layer()
	return layer.eraser_source if layer and layer.eraser_source else null


func set_selected_layer_image(next_image: Image) -> bool:
	var layer = get_selected_layer()
	var normalized := _normalize_layer_image(next_image)
	if not layer or not normalized or not _layer_workspace_is_safe(normalized, layer.origin, size) or is_node_effectively_locked(layer.id):
		return false
	layer.eraser_source = _remap_layer_image(layer.eraser_source, layer.origin, layer.origin, normalized.get_size())
	layer.image = normalized
	_content_revision += 1
	return true


func adopt_selected_layer_image(next_image: Image) -> bool:
	var layer = get_selected_layer()
	if (
		not layer
		or not next_image
		or next_image.is_empty()
		or next_image.has_mipmaps()
		or next_image.get_format() != Image.FORMAT_RGBA8
		or not _layer_workspace_is_safe(next_image, layer.origin, size)
		or is_node_effectively_locked(layer.id)
	):
		return false
	# The canvas emits a newly duplicated image for this handoff. Adopting that
	# owned value avoids immediately copying another 64 MiB for a 4096² layer.
	layer.eraser_source = _remap_layer_image(layer.eraser_source, layer.origin, layer.origin, next_image.get_size())
	layer.image = next_image
	_content_revision += 1
	return true


func get_selected_layer_origin() -> Vector2i:
	var layer = get_selected_layer()
	return layer.origin if layer else Vector2i.ZERO


func set_selected_layer_origin(next_origin: Vector2i) -> bool:
	var layer = get_selected_layer()
	if not layer or not _layer_workspace_is_safe(layer.image, next_origin, size) or is_node_effectively_locked(layer.id):
		return false
	layer.origin = next_origin
	_content_revision += 1
	return true


func adopt_selected_layer_workspace(next_image: Image, next_origin: Vector2i) -> bool:
	var layer = get_selected_layer()
	if not layer or not _layer_workspace_is_safe(next_image, next_origin, size) or is_node_effectively_locked(layer.id):
		return false
	if next_image.has_mipmaps() or next_image.get_format() != Image.FORMAT_RGBA8:
		return false
	var previous_origin: Vector2i = layer.origin
	var previous_size: Vector2i = layer.image.get_size() if layer.image else Vector2i.ZERO
	if previous_origin != next_origin or previous_size != next_image.get_size():
		layer.eraser_source = _remap_layer_image(layer.eraser_source, previous_origin, next_origin, next_image.get_size())
	layer.image = next_image
	layer.origin = next_origin
	_content_revision += 1
	return true


func get_content_revision() -> int:
	return _content_revision


func rename_node(node_id: String, next_name: String) -> bool:
	var node = find_node(node_id)
	var cleaned := next_name.strip_edges()
	if not node or cleaned.is_empty() or is_node_effectively_locked(node_id):
		return false
	if node.name == cleaned:
		return false
	node.name = cleaned
	return true


func set_node_visible(node_id: String, next_visible: bool) -> bool:
	var node = find_node(node_id)
	if not node:
		return false
	node.visible = next_visible
	return true


func set_node_opacity(node_id: String, next_opacity: float) -> bool:
	var node = find_node(node_id)
	if not node or not is_finite(next_opacity) or is_node_effectively_locked(node_id):
		return false
	var cleaned := clampf(next_opacity, 0.0, 1.0)
	if is_equal_approx(node.opacity, cleaned):
		return false
	node.opacity = cleaned
	return true


func set_node_locked(node_id: String, next_locked: bool) -> bool:
	var context := _find_context(node_id)
	if context.is_empty() or bool(context.get("locked_by_ancestor", false)):
		return false
	context.get("node").locked = next_locked
	return true


func find_node(node_id: String):
	return _find_node_in(nodes, node_id)


func get_first_paint_layer():
	return _find_first_paint_layer(nodes)


func get_paint_layer_count() -> int:
	var count := 0
	for node in nodes:
		count += _count_paint_layers_in(node)
	return count


func is_node_effectively_locked(node_id: String) -> bool:
	var context := _find_context(node_id)
	if context.is_empty():
		return false
	var node = context.get("node")
	return bool(context.get("locked_by_ancestor", false)) or (node and node.locked)


func is_node_locked_by_ancestor(node_id: String) -> bool:
	var context := _find_context(node_id)
	return not context.is_empty() and bool(context.get("locked_by_ancestor", false))


func get_node_location(node_id: String) -> Dictionary:
	var context := _find_context(node_id)
	if context.is_empty():
		return {}
	return {
		"parent_group_id": str(context.get("parent_group_id", "")),
		"index": int(context.get("index", -1)),
		"sibling_count": (context.get("container", []) as Array).size(),
	}


func move_node_relative(node_id: String, offset: int) -> bool:
	if not can_move_node_relative(node_id, offset):
		return false
	var context := _find_context(node_id)
	var node = context.get("node")
	var container: Array = context.get("container", [])
	var from_index := int(context.get("index", -1))
	var to_index := from_index + offset
	var sibling = container[to_index]
	container[to_index] = node
	container[from_index] = sibling
	return true


func can_move_node_relative(node_id: String, offset: int) -> bool:
	if offset == 0:
		return false
	var context := _find_context(node_id)
	if context.is_empty() or bool(context.get("locked_by_ancestor", false)):
		return false
	var node = context.get("node")
	if not node or _node_or_descendants_locked(node):
		return false
	var container: Array = context.get("container", [])
	var from_index := int(context.get("index", -1))
	var to_index := from_index + offset
	return from_index >= 0 and to_index >= 0 and to_index < container.size()


func can_remove_node(node_id: String) -> bool:
	var context := _find_context(node_id)
	if context.is_empty() or bool(context.get("locked_by_ancestor", false)):
		return false
	var node = context.get("node")
	return (
		node != null
		and not _node_or_descendants_locked(node)
		and _count_paint_layers_in(node) < get_paint_layer_count()
	)


func can_move_node(node_id: String, parent_group_id := "", index := 0) -> bool:
	var context := _find_context(node_id)
	if context.is_empty() or bool(context.get("locked_by_ancestor", false)):
		return false
	var node = context.get("node")
	if not node or _node_or_descendants_locked(node):
		return false
	if node.id == parent_group_id or (node.is_group() and _node_contains_id(node, parent_group_id)):
		return false
	var destination: Array = _get_child_container(parent_group_id)
	if destination == null or (not parent_group_id.is_empty() and is_node_effectively_locked(parent_group_id)):
		return false
	var source: Array = context.get("container", [])
	var source_index := int(context.get("index", -1))
	var destination_index := clampi(index, 0, destination.size() - (1 if source == destination else 0))
	if source == destination:
		return source_index != destination_index
	return true


func move_node_out_of_group(node_id: String) -> bool:
	var destination := get_move_out_destination(node_id)
	if destination.is_empty():
		return false
	return move_node(
		node_id,
		str(destination.get("parent_group_id", "")),
		int(destination.get("index", 0))
	)


func get_move_out_destination(node_id: String) -> Dictionary:
	var context := _find_context(node_id)
	var parent_group_id := str(context.get("parent_group_id", ""))
	if context.is_empty() or parent_group_id.is_empty():
		return {}
	var parent_context := _find_context(parent_group_id)
	if parent_context.is_empty():
		return {}
	var destination_parent_id := str(parent_context.get("parent_group_id", ""))
	var destination_index := int(parent_context.get("index", -1)) + 1
	if not can_move_node(node_id, destination_parent_id, destination_index):
		return {}
	return {"parent_group_id": destination_parent_id, "index": destination_index}


func get_move_into_neighbor_destination(node_id: String) -> Dictionary:
	var context := _find_context(node_id)
	if context.is_empty():
		return {}
	var siblings: Array = context.get("container", [])
	var source_index := int(context.get("index", -1))
	for neighbor_index in [source_index - 1, source_index + 1]:
		if neighbor_index < 0 or neighbor_index >= siblings.size():
			continue
		var neighbor = siblings[neighbor_index]
		if not neighbor or not neighbor.is_group() or is_node_effectively_locked(neighbor.id):
			continue
		var destination_index: int = neighbor.children.size() if neighbor_index < source_index else 0
		if can_move_node(node_id, neighbor.id, destination_index):
			return {"parent_group_id": neighbor.id, "index": destination_index}
	return {}


func move_node_into_neighbor_group(node_id: String) -> bool:
	var destination := get_move_into_neighbor_destination(node_id)
	if destination.is_empty():
		return false
	return move_node(
		node_id,
		str(destination.get("parent_group_id", "")),
		int(destination.get("index", 0))
	)


func resize_layers(new_size: Vector2i, keep_pixels: bool) -> bool:
	if new_size.x <= 0 or new_size.y <= 0 or new_size == size:
		return false
	if keep_pixels and not _all_layer_workspaces_are_safe(nodes, new_size):
		return false
	if not keep_pixels:
		for node in nodes:
			_resize_node_images(node, new_size, false)
	size = new_size
	return ensure_invariants()


func match_size_to_node(node_id: String) -> bool:
	var node = find_node(node_id)
	if not node or not node.is_paint_layer() or is_node_effectively_locked(node_id):
		return false
	for root_node in nodes:
		if _node_or_descendants_locked(root_node):
			return false
	var next_size: Vector2i = node.image.get_size() if node.image else Vector2i.ZERO
	var origin_shift: Vector2i = -Vector2i(node.origin)
	if next_size.x <= 0 or next_size.y <= 0 or (next_size == size and origin_shift == Vector2i.ZERO):
		return false
	var previous_size := size
	for root_node in nodes:
		_offset_node_origins(root_node, origin_shift)
	size = next_size
	if not _all_layer_workspaces_are_safe(nodes, size):
		for root_node in nodes:
			_offset_node_origins(root_node, -origin_shift)
		size = previous_size
		return false
	return ensure_invariants()


func crop_layers(pixel_rect: Rect2i) -> bool:
	var crop_rect := Rect2i(Vector2i.ZERO, size).intersection(pixel_rect)
	if crop_rect.size.x <= 0 or crop_rect.size.y <= 0 or crop_rect == Rect2i(Vector2i.ZERO, size):
		return false
	for node in nodes:
		_offset_node_origins(node, -crop_rect.position)
	size = crop_rect.size
	return ensure_invariants()


func scale_layers(new_size: Vector2i, interpolation: int) -> bool:
	if new_size.x <= 0 or new_size.y <= 0 or new_size == size or interpolation < 0 or interpolation > 1:
		return false
	for root_node in nodes:
		if _node_or_descendants_locked(root_node):
			return false
	if not _can_scale_nodes(nodes, new_size):
		return false
	for node in nodes:
		_scale_node_images(node, new_size, interpolation)
	size = new_size
	return ensure_invariants()


func composite() -> Image:
	var output := _make_transparent_image()
	_composite_nodes(output, nodes, "", null, Vector2i.ZERO, Vector2i.ZERO)
	return output


func composite_node(node_id: String) -> Image:
	var node = find_node(node_id)
	if not node:
		return null
	var output := _make_transparent_image()
	# Render the node through the same visibility, opacity, group-flattening,
	# and blend path as the document composite. This is used by compact row
	# previews, so a group thumbnail represents what that group contributes.
	_composite_nodes(output, [node], "", null, Vector2i.ZERO, Vector2i.ZERO)
	return output


func render_node_thumbnail(node_id: String, preview_size: int) -> Image:
	if preview_size <= 0:
		return null
	var node = find_node(node_id)
	if not node:
		return null
	var output := _make_transparent_layer_image(Vector2i(preview_size, preview_size))
	# A row preview describes the node's contents, not whether that node currently
	# contributes to the canvas. Ignore only the requested node's visibility so a
	# hidden layer/group stays identifiable while hidden descendants of a group
	# remain excluded from its flattened preview.
	var content_bounds := _get_node_visible_pixel_bounds(node, true, true)
	if not content_bounds.has_area():
		return output
	var scale := minf(
		float(preview_size) / float(content_bounds.size.x),
		float(preview_size) / float(content_bounds.size.y)
	)
	var destination_size := Vector2i(
		maxi(1, roundi(float(content_bounds.size.x) * scale)),
		maxi(1, roundi(float(content_bounds.size.y) * scale))
	)
	var destination_origin := Vector2i(
		(preview_size - destination_size.x) / 2,
		(preview_size - destination_size.y) / 2
	)
	for y in range(destination_size.y):
		var source_y := content_bounds.position.y + mini(
			content_bounds.size.y - 1,
			int(float(y) * float(content_bounds.size.y) / float(destination_size.y))
		)
		for x in range(destination_size.x):
			var source_x := content_bounds.position.x + mini(
				content_bounds.size.x - 1,
				int(float(x) * float(content_bounds.size.x) / float(destination_size.x))
			)
			output.set_pixel(
				destination_origin.x + x,
				destination_origin.y + y,
				_sample_composite_color([node], Vector2i(source_x, source_y), true)
			)
	return output


func composite_with_selected_layer(layer_image: Image, layer_origin = null) -> Image:
	var selected = get_selected_layer()
	var resolved_origin: Vector2i = selected.origin if selected else Vector2i.ZERO
	if layer_origin != null:
		resolved_origin = layer_origin
	if (
		can_display_selected_layer_directly()
		and layer_image
		and not layer_image.is_empty()
		and layer_image.get_size() == size
		and resolved_origin == Vector2i.ZERO
		and layer_image.get_format() == Image.FORMAT_RGBA8
		and not layer_image.has_mipmaps()
	):
		return layer_image
	var normalized := _normalize_layer_image(layer_image)
	if not normalized:
		return composite()
	var output := _make_transparent_image()
	_composite_nodes(output, nodes, selected_layer_id, normalized, resolved_origin, Vector2i.ZERO)
	return output


func composite_workspace(
	workspace_size: Vector2i,
	workspace_origin: Vector2i,
	selected_workspace_image: Image
) -> Image:
	if workspace_size.x <= 0 or workspace_size.y <= 0:
		return null
	if (
		can_display_selected_layer_directly()
		and selected_workspace_image
		and selected_workspace_image.get_size() == workspace_size
		and selected_workspace_image.get_format() == Image.FORMAT_RGBA8
		and not selected_workspace_image.has_mipmaps()
	):
		return selected_workspace_image
	var output := _make_transparent_layer_image(workspace_size)
	_composite_nodes(
		output,
		nodes,
		selected_layer_id,
		selected_workspace_image,
		workspace_origin,
		workspace_origin
	)
	return output


func composite_workspace_region(
	region: Rect2i,
	workspace_size: Vector2i,
	workspace_origin: Vector2i,
	selected_workspace_image: Image
) -> Image:
	var clipped := region.intersection(Rect2i(Vector2i.ZERO, workspace_size))
	if not clipped.has_area() or not selected_workspace_image:
		return null
	if can_display_selected_layer_directly():
		return selected_workspace_image.get_region(clipped)
	var output := _make_transparent_layer_image(clipped.size)
	_composite_nodes(
		output,
		nodes,
		selected_layer_id,
		selected_workspace_image,
		workspace_origin,
		workspace_origin + clipped.position
	)
	return output


func can_display_selected_layer_directly() -> bool:
	var state := {
		"visible_paint_count": 0,
		"selected_is_direct": false,
	}
	_collect_direct_display_state(nodes, true, state)
	return int(state.visible_paint_count) == 1 and bool(state.selected_is_direct)


func _collect_direct_display_state(layer_nodes: Array, ancestors_are_direct: bool, state: Dictionary) -> void:
	for node in layer_nodes:
		if not node.visible or node.opacity <= 0.0:
			continue
		var node_is_direct: bool = ancestors_are_direct and node.opacity >= 0.999999
		if node.is_group():
			_collect_direct_display_state(node.children, node_is_direct, state)
			continue
		state.visible_paint_count = int(state.visible_paint_count) + 1
		if node.id == selected_layer_id and node_is_direct:
			state.selected_is_direct = true


func mark_saved() -> void:
	_saved_composite = composite()


func is_dirty() -> bool:
	if not _saved_composite:
		return true
	return not _images_equal(composite(), _saved_composite)


func capture_state() -> Dictionary:
	var node_states: Array[Dictionary] = []
	for node in nodes:
		node_states.push_back(node.capture_state())
	return {
		"target_id": target_id,
		"owner_group_id": owner_group_id,
		"label": label,
		"channel_id": channel_id,
		"size": size,
		"binding": binding.duplicate(true),
		"nodes": node_states,
		"selected_layer_id": selected_layer_id,
		"next_node_serial": _next_node_serial,
		"saved_composite": _saved_composite.duplicate() if _saved_composite else null,
	}


func capture_state_with_selected_layer_image(layer_image: Image, layer_origin = null) -> Dictionary:
	var normalized := _normalize_layer_image(layer_image)
	if not normalized:
		return {}
	var state := capture_state()
	var selected = get_selected_layer()
	var resolved_origin: Vector2i = selected.origin if selected else Vector2i.ZERO
	if layer_origin != null:
		resolved_origin = layer_origin
	if not _replace_node_state_image(state.get("nodes", []), selected_layer_id, normalized, resolved_origin):
		return {}
	return state


func capture_history_state() -> Dictionary:
	return _capture_history_state_with_override("", null, null, null)


func capture_history_state_with_selected_layer_image(layer_image: Image, layer_origin = null) -> Dictionary:
	if (
		not layer_image
		or layer_image.is_empty()
		or layer_image.has_mipmaps()
		or layer_image.get_format() != Image.FORMAT_RGBA8
	):
		return {}
	var selected = get_selected_layer()
	if not selected:
		return {}
	var resolved_origin: Vector2i = selected.origin
	if layer_origin != null:
		resolved_origin = layer_origin
	if not _layer_workspace_is_safe_size(layer_image.get_size(), resolved_origin, size):
		return {}
	var history_eraser: Image = selected.eraser_source
	if selected.origin != resolved_origin or selected.image.get_size() != layer_image.get_size():
		history_eraser = _remap_layer_image(
			selected.eraser_source,
			selected.origin,
			resolved_origin,
			layer_image.get_size()
		)
	return _capture_history_state_with_override(
		selected_layer_id,
		layer_image,
		resolved_origin,
		history_eraser
	)


func _capture_history_state_with_override(
	override_id: String,
	override_image: Image,
	override_origin,
	override_eraser: Image
) -> Dictionary:
	var node_states: Array[Dictionary] = []
	for node in nodes:
		node_states.push_back(node.capture_history_state(
			override_id,
			override_image,
			override_origin,
			override_eraser
		))
	return {
		"target_id": target_id,
		"owner_group_id": owner_group_id,
		"label": label,
		"channel_id": channel_id,
		"size": size,
		"binding": binding.duplicate(true),
		"nodes": node_states,
		"selected_layer_id": selected_layer_id,
		"next_node_serial": _next_node_serial,
		# The saved baseline is immutable until mark_saved() replaces it.
		"saved_composite": _saved_composite,
	}


func restore_state(state: Dictionary) -> bool:
	var restored_size: Vector2i = state.get("size", Vector2i.ZERO)
	if restored_size.x <= 0 or restored_size.y <= 0:
		return false
	target_id = str(state.get("target_id", ""))
	owner_group_id = str(state.get("owner_group_id", ""))
	label = str(state.get("label", "Paint Target"))
	channel_id = str(state.get("channel_id", "rgba"))
	size = restored_size
	binding = state.get("binding", {}).duplicate(true)
	nodes.clear()
	for node_state in state.get("nodes", []):
		if not node_state is Dictionary:
			continue
		var node := LayerNode.new()
		node.restore_state(node_state)
		if not _validate_node_images(node):
			nodes.clear()
			return false
		nodes.push_back(node)
	selected_layer_id = str(state.get("selected_layer_id", ""))
	_next_node_serial = maxi(1, int(state.get("next_node_serial", 1)))
	_content_revision += 1
	var baseline: Image = state.get("saved_composite", null)
	_saved_composite = _normalize_image(baseline) if baseline else null
	return ensure_invariants()


func ensure_invariants() -> bool:
	if get_paint_layer_count() <= 0:
		return false
	var selected = find_node(selected_layer_id)
	if not selected or not selected.is_paint_layer():
		var first_layer = get_first_paint_layer()
		selected_layer_id = first_layer.id if first_layer else ""
	return not selected_layer_id.is_empty()


func _allocate_node_id(prefix: String) -> String:
	var next_id := "%s_%d" % [prefix, _next_node_serial]
	_next_node_serial += 1
	while find_node(next_id):
		next_id = "%s_%d" % [prefix, _next_node_serial]
		_next_node_serial += 1
	return next_id


func _get_child_container(parent_group_id: String):
	if parent_group_id.is_empty():
		return nodes
	var parent = find_node(parent_group_id)
	return parent.children if parent and parent.is_group() else null


func _find_node_in(search_nodes: Array, node_id: String):
	for node in search_nodes:
		if node.id == node_id:
			return node
		if node.is_group():
			var found = _find_node_in(node.children, node_id)
			if found:
				return found
	return null


func _find_context(node_id: String) -> Dictionary:
	return _find_context_in(nodes, node_id, false, "")


func _find_context_in(search_nodes: Array, node_id: String, ancestor_locked: bool, parent_group_id: String) -> Dictionary:
	for index in range(search_nodes.size()):
		var node = search_nodes[index]
		if node.id == node_id:
			return {
				"node": node,
				"container": search_nodes,
				"index": index,
				"locked_by_ancestor": ancestor_locked,
				"parent_group_id": parent_group_id,
			}
		if node.is_group():
			var found := _find_context_in(node.children, node_id, ancestor_locked or node.locked, node.id)
			if not found.is_empty():
				return found
	return {}


func _find_first_paint_layer(search_nodes: Array):
	for node in search_nodes:
		if node.is_paint_layer():
			return node
		var child = _find_first_paint_layer(node.children)
		if child:
			return child
	return null


func _count_paint_layers_in(node) -> int:
	if node.is_paint_layer():
		return 1
	var count := 0
	for child in node.children:
		count += _count_paint_layers_in(child)
	return count


func _node_contains_id(node, searched_id: String) -> bool:
	if searched_id.is_empty() or not node.is_group():
		return false
	for child in node.children:
		if child.id == searched_id or _node_contains_id(child, searched_id):
			return true
	return false


func _node_or_descendants_locked(node) -> bool:
	if not node:
		return false
	if node.locked:
		return true
	for child in node.children:
		if _node_or_descendants_locked(child):
			return true
	return false


func _duplicate_node_with_new_ids(source, rename_root := false):
	if not source:
		return null
	var duplicate := LayerNode.new()
	duplicate.id = _allocate_node_id("layer" if source.is_paint_layer() else "group")
	duplicate.kind = source.kind
	duplicate.name = source.name + (" copy" if rename_root else "")
	duplicate.visible = source.visible
	duplicate.opacity = source.opacity
	duplicate.locked = source.locked
	duplicate.origin = source.origin
	duplicate.image = source.image.duplicate() if source.image else null
	duplicate.eraser_source = source.eraser_source.duplicate() if source.eraser_source else null
	if source.is_group():
		for child in source.children:
			var child_duplicate = _duplicate_node_with_new_ids(child, false)
			if child_duplicate:
				duplicate.children.push_back(child_duplicate)
	return duplicate


func _make_valid_node_from_state(node_state: Dictionary):
	if not _node_state_is_valid_for_target(node_state):
		return null
	var node := LayerNode.new()
	node.restore_state(node_state)
	return node if _normalize_restored_node_images(node) else null


func _node_state_is_valid_for_target(node_state: Dictionary) -> bool:
	if node_state.is_empty():
		return false
	var kind := int(node_state.get("kind", -1))
	if kind == LayerNode.Kind.PAINT:
		var layer_image: Image = node_state.get("image", null)
		var layer_origin: Vector2i = node_state.get("origin", Vector2i.ZERO)
		return layer_image != null and _layer_workspace_is_safe_size(layer_image.get_size(), layer_origin, size)
	if kind != LayerNode.Kind.GROUP:
		return false
	for child_state in node_state.get("children", []):
		if not child_state is Dictionary or not _node_state_is_valid_for_target(child_state):
			return false
	return true


func _normalize_restored_node_images(node) -> bool:
	if node.is_paint_layer():
		if not node.image:
			return false
		if node.image.has_mipmaps():
			node.image.clear_mipmaps()
		if node.image.get_format() != Image.FORMAT_RGBA8:
			node.image.convert(Image.FORMAT_RGBA8)
		if not _layer_workspace_is_safe(node.image, node.origin, size):
			return false
		if node.eraser_source:
			if node.eraser_source.has_mipmaps():
				node.eraser_source.clear_mipmaps()
			if node.eraser_source.get_format() != Image.FORMAT_RGBA8:
				node.eraser_source.convert(Image.FORMAT_RGBA8)
		if not node.eraser_source or node.eraser_source.get_size() != node.image.get_size():
			node.eraser_source = _make_transparent_layer_image(node.image.get_size())
		return true
	for child in node.children:
		if not _normalize_restored_node_images(child):
			return false
	return true


func _assign_new_node_ids(node, rename_root := false) -> void:
	node.id = _allocate_node_id("layer" if node.is_paint_layer() else "group")
	if rename_root:
		node.name += " copy"
	for child in node.children:
		_assign_new_node_ids(child, false)


func _show_only_node_in(layer_nodes: Array, node_id: String) -> bool:
	var changed := false
	for node in layer_nodes:
		var contains_target: bool = node.id == node_id or _node_contains_id(node, node_id)
		if node.visible != contains_target:
			node.visible = contains_target
			changed = true
		if node.is_group() and contains_target and node.id != node_id:
			changed = _show_only_node_in(node.children, node_id) or changed
	return changed


func _set_nodes_visible_recursive(layer_nodes: Array, next_visible: bool) -> bool:
	var changed := false
	for node in layer_nodes:
		if node.visible != next_visible:
			node.visible = next_visible
			changed = true
		if node.is_group():
			changed = _set_nodes_visible_recursive(node.children, next_visible) or changed
	return changed


func _count_visible_paint_nodes(layer_nodes: Array, ancestors_visible: bool) -> int:
	var count := 0
	for node in layer_nodes:
		var node_visible: bool = ancestors_visible and bool(node.visible) and float(node.opacity) > 0.0
		if node.is_group():
			count += _count_visible_paint_nodes(node.children, node_visible)
		elif node_visible:
			count += 1
	return count


func _has_effectively_locked_visible_node(layer_nodes: Array, ancestor_locked: bool) -> bool:
	for node in layer_nodes:
		if not node.visible or node.opacity <= 0.0:
			continue
		var effectively_locked: bool = ancestor_locked or bool(node.locked)
		if effectively_locked:
			return true
		if node.is_group() and _has_effectively_locked_visible_node(node.children, effectively_locked):
			return true
	return false


func _get_visible_nodes_bounds(layer_nodes: Array, ancestors_visible: bool) -> Rect2i:
	var bounds := Rect2i()
	var has_bounds := false
	for node in layer_nodes:
		var node_visible: bool = ancestors_visible and bool(node.visible) and float(node.opacity) > 0.0
		if not node_visible:
			continue
		var node_bounds := Rect2i()
		if node.is_group():
			node_bounds = _get_visible_nodes_bounds(node.children, true)
		elif node.image:
			node_bounds = Rect2i(node.origin, node.image.get_size())
		if not node_bounds.has_area():
			continue
		bounds = bounds.merge(node_bounds) if has_bounds else node_bounds
		has_bounds = true
	return bounds if has_bounds else Rect2i()


func _get_node_visible_pixel_bounds(
	node,
	ancestors_visible: bool,
	ignore_node_visibility := false
) -> Rect2i:
	if (
		not node
		or not ancestors_visible
		or (not ignore_node_visibility and not node.visible)
		or node.opacity <= 0.0
	):
		return Rect2i()
	if node.is_paint_layer():
		if not node.image:
			return Rect2i()
		var used: Rect2i = node.image.get_used_rect()
		return Rect2i(node.origin + used.position, used.size) if used.has_area() else Rect2i()
	var bounds := Rect2i()
	var has_bounds := false
	for child in node.children:
		var child_bounds := _get_node_visible_pixel_bounds(child, true)
		if not child_bounds.has_area():
			continue
		bounds = bounds.merge(child_bounds) if has_bounds else child_bounds
		has_bounds = true
	return bounds if has_bounds else Rect2i()


func _sample_composite_color(
	layer_nodes: Array,
	document_pixel: Vector2i,
	ignore_top_level_visibility := false
) -> Color:
	var destination := Color.TRANSPARENT
	for index in range(layer_nodes.size() - 1, -1, -1):
		var node = layer_nodes[index]
		if (not ignore_top_level_visibility and not node.visible) or node.opacity <= 0.0:
			continue
		var source := Color.TRANSPARENT
		if node.is_group():
			source = _sample_composite_color(node.children, document_pixel, false)
		else:
			var local_pixel: Vector2i = document_pixel - node.origin
			if (
				node.image
				and local_pixel.x >= 0
				and local_pixel.y >= 0
				and local_pixel.x < node.image.get_width()
				and local_pixel.y < node.image.get_height()
			):
				source = node.image.get_pixelv(local_pixel)
		source.a *= node.opacity
		destination = destination.blend(source)
	return destination


func _resize_node_images(node, new_size: Vector2i, keep_pixels: bool) -> void:
	if node.is_group():
		for child in node.children:
			_resize_node_images(child, new_size, keep_pixels)
		return
	node.image = _resize_layer_image(node.image, new_size, keep_pixels)
	node.eraser_source = _resize_layer_image(node.eraser_source, new_size, keep_pixels)
	node.origin = Vector2i.ZERO


func _offset_node_origins(node, offset: Vector2i) -> void:
	if node.is_group():
		for child in node.children:
			_offset_node_origins(child, offset)
		return
	node.origin += offset


func _scale_node_images(node, new_size: Vector2i, interpolation: int) -> void:
	if node.is_group():
		for child in node.children:
			_scale_node_images(child, new_size, interpolation)
		return
	var old_target_size := size
	var scale := Vector2(float(new_size.x) / float(old_target_size.x), float(new_size.y) / float(old_target_size.y))
	var next_layer_size := Vector2i(
		maxi(1, roundi(float(node.image.get_width()) * scale.x)),
		maxi(1, roundi(float(node.image.get_height()) * scale.y))
	)
	node.image = _resample_layer_image(node.image, next_layer_size, interpolation)
	node.eraser_source = _resample_layer_image(node.eraser_source, next_layer_size, interpolation)
	node.origin = Vector2i(roundi(float(node.origin.x) * scale.x), roundi(float(node.origin.y) * scale.y))


func _can_scale_nodes(layer_nodes: Array, new_size: Vector2i) -> bool:
	var scale := Vector2(float(new_size.x) / float(size.x), float(new_size.y) / float(size.y))
	for node in layer_nodes:
		if node.is_group():
			if not _can_scale_nodes(node.children, new_size):
				return false
			continue
		var next_size := Vector2i(
			maxi(1, roundi(float(node.image.get_width()) * scale.x)),
			maxi(1, roundi(float(node.image.get_height()) * scale.y))
		)
		var next_origin := Vector2i(roundi(float(node.origin.x) * scale.x), roundi(float(node.origin.y) * scale.y))
		if not _layer_workspace_is_safe_size(next_size, next_origin, new_size):
			return false
	return true


func _all_layer_workspaces_are_safe(layer_nodes: Array, document_size: Vector2i) -> bool:
	for node in layer_nodes:
		if node.is_group():
			if not _all_layer_workspaces_are_safe(node.children, document_size):
				return false
		elif not _layer_workspace_is_safe(node.image, node.origin, document_size):
			return false
	return true


func _resize_layer_image(source: Image, new_size: Vector2i, keep_pixels: bool) -> Image:
	var result := Image.create_empty(new_size.x, new_size.y, false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	if keep_pixels:
		var copy_size := Vector2i(
			mini(source.get_width(), new_size.x),
			mini(source.get_height(), new_size.y)
		)
		result.blit_rect(source, Rect2i(Vector2i.ZERO, copy_size), Vector2i.ZERO)
	return result


func _resample_layer_image(source: Image, new_size: Vector2i, interpolation: int) -> Image:
	var result := Image.create_empty(new_size.x, new_size.y, false, Image.FORMAT_RGBA8)
	var source_size := source.get_size()
	for target_y in range(new_size.y):
		var source_y := (float(target_y) + 0.5) * float(source_size.y) / float(new_size.y) - 0.5
		for target_x in range(new_size.x):
			var source_x := (float(target_x) + 0.5) * float(source_size.x) / float(new_size.x) - 0.5
			var color: Color
			if interpolation == 0:
				color = source.get_pixel(
					clampi(roundi(source_x), 0, source_size.x - 1),
					clampi(roundi(source_y), 0, source_size.y - 1)
				)
			else:
				color = _sample_layer_bilinear(source, source_x, source_y)
			result.set_pixel(target_x, target_y, color)
	return result


func _sample_layer_bilinear(source: Image, source_x: float, source_y: float) -> Color:
	var left := floori(source_x)
	var top := floori(source_y)
	var right := left + 1
	var bottom := top + 1
	var weight_x := source_x - float(left)
	var weight_y := source_y - float(top)
	left = clampi(left, 0, source.get_width() - 1)
	right = clampi(right, 0, source.get_width() - 1)
	top = clampi(top, 0, source.get_height() - 1)
	bottom = clampi(bottom, 0, source.get_height() - 1)
	var top_color := _lerp_layer_premultiplied(
		_premultiply_layer_color(source.get_pixel(left, top)),
		_premultiply_layer_color(source.get_pixel(right, top)),
		weight_x
	)
	var bottom_color := _lerp_layer_premultiplied(
		_premultiply_layer_color(source.get_pixel(left, bottom)),
		_premultiply_layer_color(source.get_pixel(right, bottom)),
		weight_x
	)
	var premultiplied := _lerp_layer_premultiplied(top_color, bottom_color, weight_y)
	if premultiplied.a <= 0.0:
		return Color.TRANSPARENT
	return Color(
		premultiplied.r / premultiplied.a,
		premultiplied.g / premultiplied.a,
		premultiplied.b / premultiplied.a,
		premultiplied.a
	)


func _premultiply_layer_color(color: Color) -> Color:
	return Color(color.r * color.a, color.g * color.a, color.b * color.a, color.a)


func _lerp_layer_premultiplied(from_color: Color, to_color: Color, weight: float) -> Color:
	return Color(
		lerpf(from_color.r, to_color.r, weight),
		lerpf(from_color.g, to_color.g, weight),
		lerpf(from_color.b, to_color.b, weight),
		lerpf(from_color.a, to_color.a, weight)
	)


func _composite_nodes(
	destination: Image,
	layer_nodes: Array,
	override_layer_id: String,
	override_image: Image,
	override_origin: Vector2i,
	destination_origin: Vector2i
) -> void:
	for index in range(layer_nodes.size() - 1, -1, -1):
		var node = layer_nodes[index]
		if not node.visible or node.opacity <= 0.0:
			continue
		if node.is_group():
			var group_image := _make_transparent_layer_image(destination.get_size())
			_composite_nodes(group_image, node.children, override_layer_id, override_image, override_origin, destination_origin)
			_blend_with_opacity(destination, group_image, node.opacity, destination_origin, destination_origin)
		else:
			var source: Image = override_image if node.id == override_layer_id and override_image else node.image
			if source:
				var source_origin: Vector2i = override_origin if node.id == override_layer_id and override_image else node.origin
				_blend_with_opacity(destination, source, node.opacity, source_origin, destination_origin)


func _blend_with_opacity(
	destination: Image,
	source: Image,
	blend_opacity: float,
	source_origin: Vector2i,
	destination_origin: Vector2i
) -> void:
	var destination_bounds := Rect2i(destination_origin, destination.get_size())
	var source_bounds := Rect2i(source_origin, source.get_size())
	var visible_bounds := source_bounds.intersection(destination_bounds)
	if not visible_bounds.has_area():
		return
	var source_rect := Rect2i(visible_bounds.position - source_origin, visible_bounds.size)
	var destination_position := visible_bounds.position - destination_origin
	if blend_opacity >= 0.999999:
		destination.blend_rect(source, source_rect, destination_position)
		return
	# Layers are normalized to RGBA8. Modulating only every fourth byte avoids
	# millions of get_pixel()/set_pixel() calls while retaining exact source-over
	# semantics for partial layer and group opacity.
	var modulated := source.get_region(source_rect)
	var modulated_data := modulated.get_data()
	for alpha_index in range(3, modulated_data.size(), 4):
		modulated_data[alpha_index] = roundi(float(modulated_data[alpha_index]) * blend_opacity)
	modulated = Image.create_from_data(visible_bounds.size.x, visible_bounds.size.y, false, Image.FORMAT_RGBA8, modulated_data)
	destination.blend_rect(modulated, Rect2i(Vector2i.ZERO, visible_bounds.size), destination_position)


func _make_transparent_image() -> Image:
	return _make_transparent_layer_image(size)


func _make_transparent_layer_image(image_size: Vector2i) -> Image:
	var result := Image.create_empty(image_size.x, image_size.y, false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	return result


func _remap_layer_image(
	source: Image,
	source_origin: Vector2i,
	destination_origin: Vector2i,
	destination_size: Vector2i
) -> Image:
	var result := _make_transparent_layer_image(destination_size)
	if not source or source.is_empty():
		return result
	var source_bounds := Rect2i(source_origin, source.get_size())
	var destination_bounds := Rect2i(destination_origin, destination_size)
	var shared_bounds := source_bounds.intersection(destination_bounds)
	if shared_bounds.has_area():
		result.blit_rect(
			source,
			Rect2i(shared_bounds.position - source_origin, shared_bounds.size),
			shared_bounds.position - destination_origin
		)
	return result


func _normalize_image(source: Image) -> Image:
	if not source or source.is_empty() or source.get_size() != size:
		return null
	return _normalize_layer_image(source)


func _normalize_layer_image(source: Image) -> Image:
	if (
		not source
		or source.is_empty()
		or source.get_width() > MAX_LAYER_DIMENSION
		or source.get_height() > MAX_LAYER_DIMENSION
	):
		return null
	var normalized := source.duplicate()
	if normalized.has_mipmaps():
		normalized.clear_mipmaps()
	if normalized.get_format() != Image.FORMAT_RGBA8:
		normalized.convert(Image.FORMAT_RGBA8)
	return normalized


func _validate_node_images(node) -> bool:
	if node.is_paint_layer():
		var normalized := _normalize_layer_image(node.image)
		if not normalized:
			return false
		node.image = normalized
		if not _layer_workspace_is_safe(node.image, node.origin, size):
			return false
		var normalized_eraser := _normalize_layer_image(node.eraser_source)
		node.eraser_source = normalized_eraser if normalized_eraser and normalized_eraser.get_size() == normalized.get_size() else _make_transparent_layer_image(normalized.get_size())
		return true
	for child in node.children:
		if not _validate_node_images(child):
			return false
	return true


func _layer_workspace_is_safe(layer_image: Image, layer_origin: Vector2i, document_size: Vector2i) -> bool:
	return layer_image != null and _layer_workspace_is_safe_size(layer_image.get_size(), layer_origin, document_size)


func _layer_workspace_is_safe_size(layer_size: Vector2i, layer_origin: Vector2i, document_size: Vector2i) -> bool:
	if layer_size.x <= 0 or layer_size.y <= 0 or layer_size.x > MAX_LAYER_DIMENSION or layer_size.y > MAX_LAYER_DIMENSION:
		return false
	var workspace := Rect2i(layer_origin, layer_size).merge(Rect2i(Vector2i.ZERO, document_size))
	return workspace.size.x <= MAX_LAYER_DIMENSION and workspace.size.y <= MAX_LAYER_DIMENSION


func _replace_node_state_image(node_states: Array, node_id: String, replacement: Image, replacement_origin: Vector2i) -> bool:
	for node_state in node_states:
		if not node_state is Dictionary:
			continue
		if str(node_state.get("id", "")) == node_id:
			var current_origin: Vector2i = node_state.get("origin", Vector2i.ZERO)
			var current_eraser: Image = node_state.get("eraser_source", null)
			node_state["image"] = replacement.duplicate()
			node_state["eraser_source"] = _remap_layer_image(
				current_eraser,
				current_origin,
				replacement_origin,
				replacement.get_size()
			)
			node_state["origin"] = replacement_origin
			return true
		if _replace_node_state_image(node_state.get("children", []), node_id, replacement, replacement_origin):
			return true
	return false


func _images_equal(left: Image, right: Image) -> bool:
	if not left or not right or left.get_size() != right.get_size():
		return false
	var normalized_left := _normalize_image(left)
	var normalized_right := _normalize_image(right)
	return normalized_left != null and normalized_right != null and normalized_left.get_data() == normalized_right.get_data()
