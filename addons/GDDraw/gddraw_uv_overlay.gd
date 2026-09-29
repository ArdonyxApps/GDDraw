@tool
class_name GDDrawUVOverlayBuilder
extends RefCounted


func extract_from_mesh_instance(mesh_instance: MeshInstance3D) -> Dictionary:
	if not mesh_instance or not mesh_instance.mesh:
		return {"edges": [], "vertices": PackedVector2Array()}
	return extract_from_mesh(mesh_instance.mesh)


func extract_from_mesh(mesh: Mesh, surface_slots := PackedInt32Array()) -> Dictionary:
	var edges: Array = []
	var vertices := PackedVector2Array()
	var edge_keys := {}
	var vertex_keys := {}
	if not mesh:
		return {"edges": edges, "vertices": vertices}

	var slots := surface_slots
	if slots.is_empty():
		slots = PackedInt32Array()
		for surface_index in range(mesh.get_surface_count()):
			slots.push_back(surface_index)
	for surface_index in slots:
		if surface_index < 0 or surface_index >= mesh.get_surface_count():
			continue
		if mesh.surface_get_primitive_type(surface_index) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arrays := mesh.surface_get_arrays(surface_index)
		if arrays.size() <= Mesh.ARRAY_TEX_UV:
			continue
		if not (arrays[Mesh.ARRAY_TEX_UV] is PackedVector2Array):
			continue
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		if uvs.is_empty():
			continue
		for uv in uvs:
			var vertex_key := _uv_key(uv)
			if not vertex_keys.has(vertex_key):
				vertex_keys[vertex_key] = true
				vertices.push_back(uv)

		var indices := PackedInt32Array()
		if arrays.size() > Mesh.ARRAY_INDEX and arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
			indices = arrays[Mesh.ARRAY_INDEX]
		if indices.size() >= 3:
			for index in range(0, indices.size() - 2, 3):
				_add_triangle_edges(edges, edge_keys, uvs, indices[index], indices[index + 1], indices[index + 2])
		else:
			for index in range(0, uvs.size() - 2, 3):
				_add_triangle_edges(edges, edge_keys, uvs, index, index + 1, index + 2)

	return {"edges": edges, "vertices": vertices}


func _add_triangle_edges(edges: Array, edge_keys: Dictionary, uvs: PackedVector2Array, a: int, b: int, c: int) -> void:
	_add_edge(edges, edge_keys, uvs, a, b)
	_add_edge(edges, edge_keys, uvs, b, c)
	_add_edge(edges, edge_keys, uvs, c, a)


func _add_edge(edges: Array, edge_keys: Dictionary, uvs: PackedVector2Array, from_index: int, to_index: int) -> void:
	if from_index < 0 or to_index < 0 or from_index >= uvs.size() or to_index >= uvs.size():
		return
	var from_uv := uvs[from_index]
	var to_uv := uvs[to_index]
	var from_key := _uv_key(from_uv)
	var to_key := _uv_key(to_uv)
	var edge_key := Vector4i(from_key.x, from_key.y, to_key.x, to_key.y)
	if from_key.x > to_key.x or (from_key.x == to_key.x and from_key.y > to_key.y):
		edge_key = Vector4i(to_key.x, to_key.y, from_key.x, from_key.y)
	if edge_keys.has(edge_key):
		return
	edge_keys[edge_key] = true
	edges.push_back(PackedVector2Array([from_uv, to_uv]))


func _uv_key(uv: Vector2) -> Vector2i:
	return Vector2i(roundi(uv.x * 100000.0), roundi(uv.y * 100000.0))
