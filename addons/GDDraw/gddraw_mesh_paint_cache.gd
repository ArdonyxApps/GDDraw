@tool
class_name GDDrawMeshPaintCache
extends RefCounted

const BVH_LEAF_SIZE := 8
const GEOMETRY_RELATIVE_EPSILON := 1.0e-12
const RAY_RELATIVE_EPSILON := 1.0e-7
const UV_RELATIVE_EPSILON := 1.0e-12
const BARYCENTRIC_TOLERANCE := 1.0e-5

var geometry_signature := ""
var material_slots := PackedInt32Array()
var triangle_count := 0
var invalid_triangle_count := 0
var surface_array_reads := 0
var build_time_usec := 0
var extraction_time_usec := 0
var bvh_time_usec := 0
var uv_bvh_time_usec := 0
var island_time_usec := 0

var _mesh: Mesh
var _triangles: Array[Dictionary] = []
var _triangle_by_source: Dictionary = {}
var _bvh_nodes: Array[Dictionary] = []
var _bvh_root := -1
var _uv_bvh_nodes: Array[Dictionary] = []
var _uv_bvh_root := -1
var _island_members: Dictionary = {}


func build(mesh: Mesh, slots := PackedInt32Array(), signature := "") -> Dictionary:
	var started := Time.get_ticks_usec()
	clear()
	_mesh = mesh
	geometry_signature = signature
	if not mesh:
		return get_build_stats()
	material_slots = _normalize_slots(mesh, slots)
	var edge_members: Dictionary = {}
	var phase_started := Time.get_ticks_usec()
	for surface_index in material_slots:
		_extract_surface(mesh, surface_index, edge_members)
	extraction_time_usec = Time.get_ticks_usec() - phase_started
	triangle_count = _triangles.size()
	if triangle_count > 0:
		var triangle_ids: Array[int] = []
		triangle_ids.resize(triangle_count)
		for triangle_id in range(triangle_count):
			triangle_ids[triangle_id] = triangle_id
		phase_started = Time.get_ticks_usec()
		_bvh_root = _build_bvh_node(triangle_ids, false)
		bvh_time_usec = Time.get_ticks_usec() - phase_started
		phase_started = Time.get_ticks_usec()
		_uv_bvh_root = _build_bvh_node(triangle_ids, true)
		uv_bvh_time_usec = Time.get_ticks_usec() - phase_started
		phase_started = Time.get_ticks_usec()
		_build_uv_islands(edge_members)
		island_time_usec = Time.get_ticks_usec() - phase_started
	build_time_usec = Time.get_ticks_usec() - started
	return get_build_stats()


func clear() -> void:
	_mesh = null
	geometry_signature = ""
	material_slots = PackedInt32Array()
	triangle_count = 0
	invalid_triangle_count = 0
	surface_array_reads = 0
	build_time_usec = 0
	extraction_time_usec = 0
	bvh_time_usec = 0
	uv_bvh_time_usec = 0
	island_time_usec = 0
	_triangles.clear()
	_triangle_by_source.clear()
	_bvh_nodes.clear()
	_bvh_root = -1
	_uv_bvh_nodes.clear()
	_uv_bvh_root = -1
	_island_members.clear()


func is_valid() -> bool:
	return _mesh != null and triangle_count > 0 and _bvh_root >= 0 and _uv_bvh_root >= 0


func matches(mesh: Mesh, slots: PackedInt32Array, signature: String) -> bool:
	return mesh == _mesh and material_slots == _normalize_slots(mesh, slots) and geometry_signature == signature


func get_build_stats() -> Dictionary:
	return {
		"triangle_count": triangle_count,
		"invalid_triangle_count": invalid_triangle_count,
		"surface_array_reads": surface_array_reads,
		"bvh_node_count": _bvh_nodes.size(),
		"uv_bvh_node_count": _uv_bvh_nodes.size(),
		"build_time_usec": build_time_usec,
		"extraction_time_usec": extraction_time_usec,
		"bvh_time_usec": bvh_time_usec,
		"uv_bvh_time_usec": uv_bvh_time_usec,
		"island_time_usec": island_time_usec,
	}


func get_triangle(triangle_id: int) -> Dictionary:
	if triangle_id < 0 or triangle_id >= _triangles.size():
		return {}
	return _triangles[triangle_id]


func get_island_triangles(surface_index: int, source_triangle_index: int) -> Array:
	var source_key := Vector2i(surface_index, source_triangle_index)
	var triangle_id := int(_triangle_by_source.get(source_key, -1))
	if triangle_id < 0:
		return []
	var ids: PackedInt32Array = _island_members.get(triangle_id, PackedInt32Array([triangle_id]))
	var result: Array = []
	for member_id in ids:
		result.push_back(_triangle_to_hit(member_id))
	return result


func validate_surface_shape_endpoints(start_hit: Dictionary, end_hit: Dictionary, overlap_distance_epsilon: float) -> Dictionary:
	if start_hit.is_empty() or end_hit.is_empty():
		return _shape_validation(false, "The shape endpoint is not on the active surface.")
	var start_surface := int(start_hit.get("surface_index", -1))
	var end_surface := int(end_hit.get("surface_index", -1))
	if start_surface < 0 or end_surface < 0 or start_surface != end_surface:
		return _shape_validation(false, "The shape cannot cross material surfaces.")
	var start_id := _hit_triangle_id(start_hit)
	var end_id := _hit_triangle_id(end_hit)
	if start_id < 0 or end_id < 0:
		return _shape_validation(false, "The shape endpoint no longer belongs to the active mesh.")
	if _hit_has_ambiguous_uv_mapping(start_hit, overlap_distance_epsilon) or _hit_has_ambiguous_uv_mapping(end_hit, overlap_distance_epsilon):
		return _shape_validation(false, "The shape crosses an ambiguous mirrored or overlapping UV mapping.")
	if start_id != end_id:
		var island: PackedInt32Array = _island_members.get(start_id, PackedInt32Array([start_id]))
		if not island.has(end_id):
			return _shape_validation(false, "The shape endpoints are separated by a UV seam or disconnected geometry.")
	return _shape_validation(true, "")


func _hit_triangle_id(hit: Dictionary) -> int:
	var triangle_id := int(hit.get("cache_triangle_id", -1))
	if triangle_id >= 0 and triangle_id < _triangles.size():
		return triangle_id
	return int(_triangle_by_source.get(
		Vector2i(int(hit.get("surface_index", -1)), int(hit.get("triangle_index", -1))),
		-1
	))


func _hit_has_ambiguous_uv_mapping(hit: Dictionary, distance_epsilon: float) -> bool:
	var hit_id := _hit_triangle_id(hit)
	if hit_id < 0:
		return true
	var uv: Vector2 = hit.get("uv", Vector2.ZERO)
	var hit_position: Vector3 = hit.get("position", Vector3.ZERO)
	var query := query_uv_candidates(uv)
	for other_id in query.get("triangle_ids", PackedInt32Array()):
		if other_id == hit_id:
			continue
		var other_hit := make_uv_hit(other_id, uv)
		if other_hit.is_empty():
			continue
		var other_position: Vector3 = other_hit.get("position", Vector3.ZERO)
		if hit_position.distance_to(other_position) > distance_epsilon:
			# The 3D ray has selected a spatially distinct destination. Mirrored
			# body parts and CSG faces may share these texture pixels, so retain
			# the shared-UV warning but do not make surface-shape tools inactive.
			continue
		# Continuous neighboring triangles legitimately meet at the same 3D/UV
		# boundary. Coincident interior mappings remain unsafe because the ray
		# cannot establish which duplicate surface owns the destination.
		if (
			_uv_hit_is_on_triangle_boundary(hit_id, uv)
			and _uv_hit_is_on_triangle_boundary(other_id, uv)
		):
			continue
		return true
	return false


func _uv_hit_is_on_triangle_boundary(triangle_id: int, uv: Vector2) -> bool:
	if triangle_id < 0 or triangle_id >= _triangles.size():
		return false
	var triangle: Dictionary = _triangles[triangle_id]
	var bary := uv_barycentric(uv, triangle["uv_a"], triangle["uv_b"], triangle["uv_c"])
	return minf(bary.x, minf(bary.y, bary.z)) <= BARYCENTRIC_TOLERANCE


func _shape_validation(valid: bool, reason: String) -> Dictionary:
	return {"valid": valid, "reason": reason}


func query_ray(ray_origin: Vector3, ray_direction: Vector3, ray_length: float) -> Dictionary:
	var result := {
		"hit": {},
		"candidate_count": 0,
		"nodes_examined": 0,
		"triangles_examined": 0,
	}
	if not is_valid() or ray_length <= 0.0 or ray_direction.length_squared() <= 0.0:
		return result
	var candidates := PackedInt32Array()
	var stack: Array[int] = [_bvh_root]
	while not stack.is_empty():
		var node_index := stack.pop_back()
		result["nodes_examined"] = int(result["nodes_examined"]) + 1
		var node: Dictionary = _bvh_nodes[node_index]
		if not _ray_intersects_bounds(
			ray_origin,
			ray_direction,
			ray_length,
			node["minimum"],
			node["maximum"]
		):
			continue
		var left := int(node["left"])
		if left < 0:
			var node_ids: PackedInt32Array = node["triangles"]
			candidates.append_array(node_ids)
		else:
			stack.push_back(left)
			stack.push_back(int(node["right"]))
	result["candidate_count"] = candidates.size()
	var best_distance := INF
	var best_hit: Dictionary = {}
	for triangle_id in candidates:
		result["triangles_examined"] = int(result["triangles_examined"]) + 1
		var hit := _intersect_triangle(triangle_id, ray_origin, ray_direction, minf(ray_length, best_distance))
		if hit.is_empty():
			continue
		var distance := float(hit["distance"])
		if distance < best_distance:
			best_distance = distance
			best_hit = hit
	result["hit"] = best_hit
	return result


func query_uv_candidates(point: Vector2, margin := Vector2.ZERO) -> Dictionary:
	var result := {
		"triangle_ids": PackedInt32Array(),
		"candidate_count": 0,
		"nodes_examined": 0,
	}
	if not is_valid():
		return result
	margin = Vector2(maxf(0.0, margin.x), maxf(0.0, margin.y))
	var query_minimum := point - margin
	var query_maximum := point + margin
	var candidates := PackedInt32Array()
	var stack: Array[int] = [_uv_bvh_root]
	while not stack.is_empty():
		var node_index := stack.pop_back()
		result["nodes_examined"] = int(result["nodes_examined"]) + 1
		var node: Dictionary = _uv_bvh_nodes[node_index]
		var minimum: Vector2 = node["minimum"]
		var maximum: Vector2 = node["maximum"]
		if maximum.x < query_minimum.x or maximum.y < query_minimum.y:
			continue
		if minimum.x > query_maximum.x or minimum.y > query_maximum.y:
			continue
		var left := int(node["left"])
		if left < 0:
			var node_ids: PackedInt32Array = node["triangles"]
			candidates.append_array(node_ids)
		else:
			stack.push_back(left)
			stack.push_back(int(node["right"]))
	result["triangle_ids"] = candidates
	result["candidate_count"] = candidates.size()
	return result


func make_uv_hit(triangle_id: int, point: Vector2, barycentric_tolerance := BARYCENTRIC_TOLERANCE) -> Dictionary:
	if triangle_id < 0 or triangle_id >= _triangles.size():
		return {}
	var triangle: Dictionary = _triangles[triangle_id]
	var bary := uv_barycentric(
		point,
		triangle["uv_a"],
		triangle["uv_b"],
		triangle["uv_c"]
	)
	if bary.x < -barycentric_tolerance or bary.y < -barycentric_tolerance or bary.z < -barycentric_tolerance:
		return {}
	return _triangle_to_hit(triangle_id, point, bary)


func count_uv_overlaps(hit: Dictionary, distance_epsilon: float) -> Dictionary:
	var result := {
		"overlap_count": 0,
		"candidate_count": 0,
		"triangles_examined": 0,
	}
	if hit.is_empty():
		return result
	var uv: Vector2 = hit.get("uv", Vector2.ZERO)
	var query := query_uv_candidates(uv)
	var triangle_ids: PackedInt32Array = query["triangle_ids"]
	result["candidate_count"] = triangle_ids.size()
	var hit_position: Vector3 = hit.get("position", Vector3.ZERO)
	var hit_normal: Vector3 = hit.get("normal", Vector3.UP)
	var hit_surface := int(hit.get("surface_index", -1))
	var hit_triangle := int(hit.get("triangle_index", -1))
	for triangle_id in triangle_ids:
		var triangle: Dictionary = _triangles[triangle_id]
		if int(triangle["surface_index"]) == hit_surface and int(triangle["triangle_index"]) == hit_triangle:
			continue
		result["triangles_examined"] = int(result["triangles_examined"]) + 1
		var other_hit := make_uv_hit(triangle_id, uv)
		if other_hit.is_empty():
			continue
		var other_position: Vector3 = other_hit["position"]
		var other_normal: Vector3 = other_hit["normal"]
		var separated := other_position.distance_to(hit_position) > distance_epsilon
		var different_facing := other_normal.dot(hit_normal) < 0.85
		if separated or different_facing:
			result["overlap_count"] = int(result["overlap_count"]) + 1
	return result


static func uv_barycentric(point: Vector2, a: Vector2, b: Vector2, c: Vector2) -> Vector3:
	var edge_ab := b - a
	var edge_ac := c - a
	var point_offset := point - a
	var d00 := edge_ab.dot(edge_ab)
	var d01 := edge_ab.dot(edge_ac)
	var d11 := edge_ac.dot(edge_ac)
	var d20 := point_offset.dot(edge_ab)
	var d21 := point_offset.dot(edge_ac)
	var denominator := d00 * d11 - d01 * d01
	var scale := d00 * d11
	if scale <= 0.0 or absf(denominator) <= scale * UV_RELATIVE_EPSILON:
		return Vector3(-INF, -INF, -INF)
	var bary_c := (d00 * d21 - d01 * d20) / denominator
	var bary_b := (d11 * d20 - d01 * d21) / denominator
	return Vector3(1.0 - bary_b - bary_c, bary_b, bary_c)


func _normalize_slots(mesh: Mesh, slots: PackedInt32Array) -> PackedInt32Array:
	var normalized := PackedInt32Array()
	if not mesh:
		return normalized
	if slots.is_empty():
		for surface_index in range(mesh.get_surface_count()):
			normalized.push_back(surface_index)
		return normalized
	var seen: Dictionary = {}
	for surface_index in slots:
		if surface_index < 0 or surface_index >= mesh.get_surface_count() or seen.has(surface_index):
			continue
		seen[surface_index] = true
		normalized.push_back(surface_index)
	normalized.sort()
	return normalized


func _extract_surface(mesh: Mesh, surface_index: int, edge_members: Dictionary) -> void:
	if mesh.surface_get_primitive_type(surface_index) != Mesh.PRIMITIVE_TRIANGLES:
		return
	var arrays := mesh.surface_get_arrays(surface_index)
	surface_array_reads += 1
	if arrays.size() <= Mesh.ARRAY_TEX_UV:
		return
	if not (arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array):
		return
	if not (arrays[Mesh.ARRAY_TEX_UV] is PackedVector2Array):
		return
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	if vertices.size() < 3 or uvs.is_empty():
		return
	var indices := PackedInt32Array()
	if arrays.size() > Mesh.ARRAY_INDEX and arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
		indices = arrays[Mesh.ARRAY_INDEX]
	var source_triangle_count := indices.size() / 3 if not indices.is_empty() else mini(vertices.size(), uvs.size()) / 3
	for source_triangle_index in range(source_triangle_count):
		var offset := source_triangle_index * 3
		var a_index := indices[offset] if not indices.is_empty() else offset
		var b_index := indices[offset + 1] if not indices.is_empty() else offset + 1
		var c_index := indices[offset + 2] if not indices.is_empty() else offset + 2
		if not _indices_are_valid(vertices, uvs, a_index, b_index, c_index):
			invalid_triangle_count += 1
			continue
		var a := vertices[a_index]
		var b := vertices[b_index]
		var c := vertices[c_index]
		var edge_ab := b - a
		var edge_ac := c - a
		var normal_unnormalized := edge_ab.cross(edge_ac)
		var area_scale := edge_ab.length_squared() * edge_ac.length_squared()
		if area_scale <= 0.0 or normal_unnormalized.length_squared() <= area_scale * GEOMETRY_RELATIVE_EPSILON:
			invalid_triangle_count += 1
			continue
		var uv_a := uvs[a_index]
		var uv_b := uvs[b_index]
		var uv_c := uvs[c_index]
		var triangle_id := _triangles.size()
		var triangle := {
			"surface_index": surface_index,
			"triangle_index": source_triangle_index,
			"source_indices": Vector3i(a_index, b_index, c_index),
			"a": a,
			"b": b,
			"c": c,
			"uv_a": uv_a,
			"uv_b": uv_b,
			"uv_c": uv_c,
			"normal": normal_unnormalized.normalized(),
			"minimum": Vector3(
				minf(a.x, minf(b.x, c.x)),
				minf(a.y, minf(b.y, c.y)),
				minf(a.z, minf(b.z, c.z))
			),
			"maximum": Vector3(
				maxf(a.x, maxf(b.x, c.x)),
				maxf(a.y, maxf(b.y, c.y)),
				maxf(a.z, maxf(b.z, c.z))
			),
			"uv_minimum": Vector2(minf(uv_a.x, minf(uv_b.x, uv_c.x)), minf(uv_a.y, minf(uv_b.y, uv_c.y))),
			"uv_maximum": Vector2(maxf(uv_a.x, maxf(uv_b.x, uv_c.x)), maxf(uv_a.y, maxf(uv_b.y, uv_c.y))),
		}
		_triangles.push_back(triangle)
		_triangle_by_source[Vector2i(surface_index, source_triangle_index)] = triangle_id
		_add_uv_edge_member(edge_members, surface_index, a, b, uv_a, uv_b, triangle_id)
		_add_uv_edge_member(edge_members, surface_index, b, c, uv_b, uv_c, triangle_id)
		_add_uv_edge_member(edge_members, surface_index, c, a, uv_c, uv_a, triangle_id)


func _indices_are_valid(vertices: PackedVector3Array, uvs: PackedVector2Array, a: int, b: int, c: int) -> bool:
	if a < 0 or b < 0 or c < 0:
		return false
	if a >= vertices.size() or b >= vertices.size() or c >= vertices.size():
		return false
	return a < uvs.size() and b < uvs.size() and c < uvs.size()


func _build_bvh_node(triangle_ids: Array[int], uv_space: bool) -> int:
	var node_index := _uv_bvh_nodes.size() if uv_space else _bvh_nodes.size()
	var bounds := _calculate_bounds(triangle_ids, uv_space)
	var node := {
		"minimum": bounds["minimum"],
		"maximum": bounds["maximum"],
		"left": -1,
		"right": -1,
		"triangles": PackedInt32Array(),
	}
	if uv_space:
		_uv_bvh_nodes.push_back(node)
	else:
		_bvh_nodes.push_back(node)
	if triangle_ids.size() <= BVH_LEAF_SIZE:
		var packed_ids := PackedInt32Array()
		for triangle_id in triangle_ids:
			packed_ids.push_back(triangle_id)
		node["triangles"] = packed_ids
		if uv_space:
			_uv_bvh_nodes[node_index] = node
		else:
			_bvh_nodes[node_index] = node
		return node_index
	var extent = bounds["maximum"] - bounds["minimum"]
	var axis := 0
	if extent.y > extent.x:
		axis = 1
	if not uv_space and extent.z > extent[axis]:
		axis = 2
	var split_value: float = (float(bounds["minimum"][axis]) + float(bounds["maximum"][axis])) * 0.5
	var left_ids: Array[int] = []
	var right_ids: Array[int] = []
	for triangle_id in triangle_ids:
		if _triangle_center_axis(triangle_id, axis, uv_space) < split_value:
			left_ids.push_back(triangle_id)
		else:
			right_ids.push_back(triangle_id)
	# Coincident centers are common in stacked UV shells. An even fallback
	# guarantees bounded depth without paying for a full sort at every node.
	if left_ids.is_empty() or right_ids.is_empty():
		left_ids.clear()
		right_ids.clear()
		var middle := triangle_ids.size() / 2
		for index in range(triangle_ids.size()):
			if index < middle:
				left_ids.push_back(triangle_ids[index])
			else:
				right_ids.push_back(triangle_ids[index])
	node["left"] = _build_bvh_node(left_ids, uv_space)
	node["right"] = _build_bvh_node(right_ids, uv_space)
	if uv_space:
		_uv_bvh_nodes[node_index] = node
	else:
		_bvh_nodes[node_index] = node
	return node_index


func _calculate_bounds(triangle_ids: Array[int], uv_space: bool) -> Dictionary:
	if uv_space:
		var uv_minimum := Vector2(INF, INF)
		var uv_maximum := Vector2(-INF, -INF)
		for triangle_id in triangle_ids:
			var triangle: Dictionary = _triangles[triangle_id]
			uv_minimum = uv_minimum.min(triangle["uv_minimum"])
			uv_maximum = uv_maximum.max(triangle["uv_maximum"])
		return {"minimum": uv_minimum, "maximum": uv_maximum}
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	for triangle_id in triangle_ids:
		var triangle: Dictionary = _triangles[triangle_id]
		minimum = minimum.min(triangle["minimum"])
		maximum = maximum.max(triangle["maximum"])
	return {"minimum": minimum, "maximum": maximum}


func _triangle_center_axis(triangle_id: int, axis: int, uv_space: bool) -> float:
	var triangle: Dictionary = _triangles[triangle_id]
	if uv_space:
		var center: Vector2 = (triangle["uv_minimum"] + triangle["uv_maximum"]) * 0.5
		return center[axis]
	var center: Vector3 = (triangle["minimum"] + triangle["maximum"]) * 0.5
	return center[axis]


func _ray_intersects_bounds(origin: Vector3, direction: Vector3, ray_length: float, minimum: Vector3, maximum: Vector3) -> bool:
	var near := 0.0
	var far := ray_length
	for axis in range(3):
		var component := direction[axis]
		if is_zero_approx(component):
			if origin[axis] < minimum[axis] or origin[axis] > maximum[axis]:
				return false
			continue
		var inverse := 1.0 / component
		var axis_near := (minimum[axis] - origin[axis]) * inverse
		var axis_far := (maximum[axis] - origin[axis]) * inverse
		if axis_near > axis_far:
			var swap := axis_near
			axis_near = axis_far
			axis_far = swap
		near = maxf(near, axis_near)
		far = minf(far, axis_far)
		if near > far:
			return false
	return far >= 0.0 and near <= ray_length


func _intersect_triangle(triangle_id: int, ray_origin: Vector3, ray_direction: Vector3, ray_length: float) -> Dictionary:
	var triangle: Dictionary = _triangles[triangle_id]
	var a: Vector3 = triangle["a"]
	var edge_ab: Vector3 = triangle["b"] - a
	var edge_ac: Vector3 = triangle["c"] - a
	var pvec := ray_direction.cross(edge_ac)
	var determinant := edge_ab.dot(pvec)
	var determinant_scale := sqrt(edge_ab.length_squared() * edge_ac.length_squared()) * ray_direction.length()
	if determinant_scale <= 0.0 or absf(determinant) <= determinant_scale * RAY_RELATIVE_EPSILON:
		return {}
	var inverse_determinant := 1.0 / determinant
	var tvec := ray_origin - a
	var bary_b := tvec.dot(pvec) * inverse_determinant
	if bary_b < -BARYCENTRIC_TOLERANCE or bary_b > 1.0 + BARYCENTRIC_TOLERANCE:
		return {}
	var qvec := tvec.cross(edge_ab)
	var bary_c := ray_direction.dot(qvec) * inverse_determinant
	if bary_c < -BARYCENTRIC_TOLERANCE or bary_b + bary_c > 1.0 + BARYCENTRIC_TOLERANCE:
		return {}
	var distance := edge_ac.dot(qvec) * inverse_determinant
	if distance < 0.0 or distance > ray_length:
		return {}
	var bary := Vector3(1.0 - bary_b - bary_c, bary_b, bary_c)
	var uv: Vector2 = triangle["uv_a"] * bary.x + triangle["uv_b"] * bary.y + triangle["uv_c"] * bary.z
	return _triangle_to_hit(triangle_id, uv, bary, distance)


func _triangle_to_hit(triangle_id: int, uv := Vector2(INF, INF), bary := Vector3(INF, INF, INF), distance := 0.0) -> Dictionary:
	var triangle: Dictionary = _triangles[triangle_id]
	if is_inf(uv.x):
		uv = (triangle["uv_a"] + triangle["uv_b"] + triangle["uv_c"]) / 3.0
	if is_inf(bary.x):
		bary = uv_barycentric(uv, triangle["uv_a"], triangle["uv_b"], triangle["uv_c"])
	var a: Vector3 = triangle["a"]
	var b: Vector3 = triangle["b"]
	var c: Vector3 = triangle["c"]
	return {
		"cache_triangle_id": triangle_id,
		"surface_index": triangle["surface_index"],
		"triangle_index": triangle["triangle_index"],
		"source_indices": triangle["source_indices"],
		"uv": uv,
		"triangle_uvs": PackedVector2Array([triangle["uv_a"], triangle["uv_b"], triangle["uv_c"]]),
		"triangle_positions": PackedVector3Array([a, b, c]),
		"position": a * bary.x + b * bary.y + c * bary.z,
		"normal": triangle["normal"],
		"distance": distance,
	}


func _add_uv_edge_member(edge_members: Dictionary, surface_index: int, from_position: Vector3, to_position: Vector3, from_uv: Vector2, to_uv: Vector2, triangle_id: int) -> void:
	# A continuous island edge must be the same geometric edge and map to the
	# same UV edge. UV-only matching incorrectly joins disconnected or stacked
	# geometry; position-only matching incorrectly joins across texture seams.
	var from_key := _surface_edge_endpoint_key(from_position, from_uv)
	var to_key := _surface_edge_endpoint_key(to_position, to_uv)
	var edge_key := from_key + ">" + to_key if from_key <= to_key else to_key + ">" + from_key
	var surface_edges: Dictionary = edge_members.get(surface_index, {})
	var members: PackedInt32Array = surface_edges.get(edge_key, PackedInt32Array())
	members.push_back(triangle_id)
	surface_edges[edge_key] = members
	edge_members[surface_index] = surface_edges


func _surface_edge_endpoint_key(position: Vector3, uv: Vector2) -> String:
	return "%d,%d,%d@%d,%d" % [
		roundi(position.x * 1000000.0),
		roundi(position.y * 1000000.0),
		roundi(position.z * 1000000.0),
		roundi(uv.x * 1000000.0),
		roundi(uv.y * 1000000.0),
	]


func _build_uv_islands(edge_members: Dictionary) -> void:
	var adjacency: Array[PackedInt32Array] = []
	adjacency.resize(triangle_count)
	for triangle_id in range(triangle_count):
		adjacency[triangle_id] = PackedInt32Array()
	for surface_edges_value in edge_members.values():
		var surface_edges: Dictionary = surface_edges_value
		for members_value in surface_edges.values():
			var members: PackedInt32Array = members_value
			for left_index in range(members.size()):
				for right_index in range(left_index + 1, members.size()):
					var left := members[left_index]
					var right := members[right_index]
					adjacency[left].push_back(right)
					adjacency[right].push_back(left)
	var visited: Dictionary = {}
	for triangle_id in range(triangle_count):
		if visited.has(triangle_id):
			continue
		var component := PackedInt32Array()
		var pending: Array[int] = [triangle_id]
		visited[triangle_id] = true
		while not pending.is_empty():
			var current := pending.pop_back()
			component.push_back(current)
			for neighbor in adjacency[current]:
				if visited.has(neighbor):
					continue
				visited[neighbor] = true
				pending.push_back(neighbor)
		for member_id in component:
			_island_members[member_id] = component


func _quantized_uv(uv: Vector2) -> Vector2i:
	return Vector2i(roundi(uv.x * 1000000.0), roundi(uv.y * 1000000.0))
