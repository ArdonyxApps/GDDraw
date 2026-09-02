@tool
class_name GDDraw3DLayerDiscovery
extends RefCounted

const SurfaceTarget := preload("res://addons/GDDraw/gddraw_3d_surface_target.gd")

const STATUS := "status"
const MESSAGE := "message"
const GROUPS := "groups"
const TARGETS := "targets"
const ISSUES := "issues"
const STATUS_OK := "ok"
const STATUS_ERROR := "error"

enum Scope {
	SELECTED_SURFACE,
	SELECTED_HIERARCHY,
	EXPLICIT_SELECTION,
}


func discover(selected_nodes: Array, scope: int) -> Dictionary:
	if scope < Scope.SELECTED_SURFACE or scope > Scope.EXPLICIT_SELECTION:
		return _result(STATUS_ERROR, "Unknown 3D import scope.")
	var roots := _sanitize_roots(selected_nodes)
	if roots.is_empty():
		return _result(STATUS_ERROR, "Select at least one scene object to inspect.")
	if scope == Scope.SELECTED_SURFACE:
		var first_surface := _find_first_surface(roots)
		if not first_surface:
			return _result(STATUS_ERROR, "The selection contains no editable MeshInstance3D or supported CSG surface.")
		roots = [first_surface]
	elif scope == Scope.SELECTED_HIERARCHY:
		roots = [roots[0]]

	var groups: Array[Dictionary] = []
	var targets: Array[Dictionary] = []
	var issues: Array[Dictionary] = []
	var group_keys := {}
	var surface_keys := {}
	for root in roots:
		var surfaces: Array[Node3D] = []
		_collect_surface_nodes(root, surfaces)
		for surface in surfaces:
			var surface_key := _node_key(surface)
			if surface_keys.has(surface_key):
				continue
			surface_keys[surface_key] = true
			_append_group_path(root, surface, groups, group_keys, scope == Scope.SELECTED_SURFACE)
			var group_key := _node_key(surface)
			_discover_surface_targets(surface, group_key, targets, issues)

	if targets.is_empty():
		var message := "No supported albedo paint targets were found in the selected scope."
		if not issues.is_empty():
			message = str(issues[0].get("reason", message))
		return {
			STATUS: STATUS_ERROR,
			MESSAGE: message,
			"scope": scope,
			GROUPS: groups,
			TARGETS: targets,
			ISSUES: issues,
		}
	return {
		STATUS: STATUS_OK,
		MESSAGE: "Found %d paint target(s) across %d object group(s)." % [targets.size(), groups.size()],
		"scope": scope,
		GROUPS: groups,
		TARGETS: targets,
		ISSUES: issues,
	}


func _sanitize_roots(selected_nodes: Array) -> Array[Node]:
	var roots: Array[Node] = []
	var seen := {}
	for candidate in selected_nodes:
		if not candidate is Node or not is_instance_valid(candidate):
			continue
		var node := candidate as Node
		var key := _node_key(node)
		if seen.has(key):
			continue
		seen[key] = true
		roots.push_back(node)
	return roots


func _find_first_surface(roots: Array[Node]) -> Node3D:
	for root in roots:
		var surfaces: Array[Node3D] = []
		_collect_surface_nodes(root, surfaces, 1)
		if not surfaces.is_empty():
			return surfaces[0]
	return null


func _collect_surface_nodes(node: Node, surfaces: Array[Node3D], limit := 0) -> void:
	if not node or (limit > 0 and surfaces.size() >= limit):
		return
	if _is_surface_node(node):
		var probe := SurfaceTarget.new()
		var inspection: Dictionary = probe.inspect(node)
		if str(inspection.get(STATUS, STATUS_ERROR)) == STATUS_OK:
			surfaces.push_back(node as Node3D)
			if limit > 0 and surfaces.size() >= limit:
				return
	for child in node.get_children():
		_collect_surface_nodes(child, surfaces, limit)
		if limit > 0 and surfaces.size() >= limit:
			return


func _is_surface_node(node: Node) -> bool:
	return (
		(node is MeshInstance3D and (node as MeshInstance3D).mesh != null)
		or (
			node is CSGShape3D
			and node.has_method("get_material")
			and node.has_method("set_material")
		)
	)


func _append_group_path(
	root: Node,
	surface: Node3D,
	groups: Array[Dictionary],
	group_keys: Dictionary,
	surface_only: bool
) -> void:
	var path: Array[Node] = []
	var cursor: Node = surface
	while cursor:
		if cursor is Node3D:
			path.push_front(cursor)
		if surface_only or cursor == root:
			break
		cursor = cursor.get_parent()
	if path.is_empty() or (not surface_only and cursor == null):
		path = [surface]
	var parent_key := ""
	for node in path:
		var key := _node_key(node)
		if not group_keys.has(key):
			groups.push_back({
				"key": key,
				"label": str(node.name),
				"class_name": node.get_class(),
				"parent_key": parent_key,
				"source_node": node,
			})
			group_keys[key] = true
		parent_key = key


func _discover_surface_targets(
	surface: Node3D,
	group_key: String,
	targets: Array[Dictionary],
	issues: Array[Dictionary]
) -> void:
	var probe := SurfaceTarget.new()
	var inspection: Dictionary = probe.inspect(surface)
	if str(inspection.get(STATUS, STATUS_ERROR)) != STATUS_OK:
		issues.push_back({
			"source_key": _node_key(surface),
			"source_node": surface,
			"reason": str(inspection.get(MESSAGE, "Could not inspect this 3D surface.")),
		})
		return
	for choice in probe.discover_material_slots():
		var slot := int(choice.get("slot", 0))
		var channel := str(choice.get("channel", "albedo"))
		var binding_key := "%s|slot:%d|channel:%s|uv:0" % [_node_key(surface), slot, channel]
		var descriptor := {
			"key": binding_key,
			"label": _make_paint_target_label(str(surface.name), choice),
			"group_key": group_key,
			"source_key": _node_key(surface),
			"source_node": surface,
			"source_class": surface.get_class(),
			"material_slot": slot,
			"channel": channel,
			"uv_set": 0,
			"texture_path": str(choice.get("texture_path", "")),
			"missing_texture": bool(choice.get("missing_texture", false)),
			"missing_material": bool(choice.get("missing_material", false)),
			"choice": choice.duplicate(true),
		}
		if bool(choice.get("supported", false)):
			targets.push_back(descriptor)
		else:
			descriptor["reason"] = str(choice.get("reason", "Unsupported material target."))
			issues.push_back(descriptor)


func _make_paint_target_label(surface_name: String, choice: Dictionary) -> String:
	var choice_label := str(choice.get("label", "Material · Albedo"))
	var albedo_marker := " · Albedo"
	var albedo_index := choice_label.find(albedo_marker)
	if albedo_index >= 0:
		choice_label = choice_label.substr(0, albedo_index + albedo_marker.length())
	else:
		var material_label := choice_label.split(" · ", false)[0] if not choice_label.is_empty() else "Material"
		choice_label = "%s · Albedo" % material_label
	return "%s · %s" % [surface_name, choice_label]


func _node_key(node: Node) -> String:
	if node and node.is_inside_tree():
		return str(node.get_path())
	return "%s#%d" % [str(node.name) if node else "Node", node.get_instance_id() if node else 0]


func _result(status: String, message: String) -> Dictionary:
	return {
		STATUS: status,
		MESSAGE: message,
		GROUPS: [],
		TARGETS: [],
		ISSUES: [],
	}
