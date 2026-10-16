extends SceneTree
## Rebake Cliff / Cliff Corner desde GLB para GridMap:
## - recentra el mesh a la celda [0..2]
## - snap de bordes + solape leve (oculta microgrietas Godot)
## - material nearest, sin alpha scissor
## Uso: godot --headless --path . -s res://Scripts/Overworld3D/tools/rebuild_cliff_meshes.gd

const OVERLAP := 0.015


func _initialize() -> void:
	var lib_path := "res://Resources/Overworld3D/MeshLibraries/3DTiles.tres"
	var lib: MeshLibrary = load(lib_path)
	if lib == null:
		push_error("No se pudo cargar MeshLibrary")
		quit(1)
		return

	# Cliff: tras recentrar el export queda en z[0..2]; el GridMap antiguo usaba z[-2..0].
	if not _rebuild_item(lib, 2, "Cliff", "res://Resources/Overworld3D/Models/Cliff.glb", Vector3(0, 0, -2)):
		quit(1)
		return
	if not _rebuild_item(lib, 3, "Cliff Corner", "res://Resources/Overworld3D/Models/Cliff_Corner.glb", Vector3.ZERO):
		quit(1)
		return

	var err := ResourceSaver.save(lib, lib_path)
	if err != OK:
		push_error("Error guardando MeshLibrary: %s" % err)
		quit(1)
		return
	print("Cliff meshes rebuilt in ", lib_path)
	quit(0)


func _rebuild_item(
	lib: MeshLibrary,
	item_id: int,
	item_name: String,
	glb_path: String,
	extra_offset: Vector3 = Vector3.ZERO
) -> bool:
	var packed: PackedScene = load(glb_path)
	if packed == null:
		push_error("No se pudo cargar %s" % glb_path)
		return false
	var root := packed.instantiate()
	var mi := _find_mesh_instance(root)
	if mi == null or mi.mesh == null:
		push_error("Sin MeshInstance3D en %s" % glb_path)
		root.free()
		return false

	var src: Mesh = mi.mesh
	var src_mat: Material = null
	if src.get_surface_count() > 0:
		src_mat = src.surface_get_material(0)
	if src_mat == null:
		src_mat = mi.get_active_material(0)

	var mat := _make_cliff_material(src_mat)
	var aabb := src.get_aabb()
	# Origen de celda: min XZ a (0,0), min Y a 0 (suelo).
	var origin := Vector3(aabb.position.x, aabb.position.y, aabb.position.z)

	var new_mesh := ArrayMesh.new()
	for s in src.get_surface_count():
		var arrays: Array = src.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			indices = PackedInt32Array()
			for i in verts.size():
				indices.append(i)

		var out_v := PackedVector3Array()
		var out_n := PackedVector3Array()
		var out_uv := PackedVector2Array()
		var out_i := PackedInt32Array()
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var kept := 0

		for t in range(0, indices.size(), 3):
			var i0 := indices[t]
			var i1 := indices[t + 1]
			var i2 := indices[t + 2]
			var a := verts[i0] - origin + extra_offset
			var b := verts[i1] - origin + extra_offset
			var c := verts[i2] - origin + extra_offset
			if _tri_area(a, b, c) < 1e-7:
				continue
			var base_idx := out_v.size()
			for src_i in [i0, i1, i2]:
				var v := _overlap_edges(_snap_edges(verts[src_i] - origin + extra_offset))
				out_v.append(v)
				if normals.size() > src_i:
					out_n.append(normals[src_i])
				else:
					out_n.append(Vector3.UP)
				if uvs.size() > src_i:
					out_uv.append(uvs[src_i])
				else:
					out_uv.append(Vector2.ZERO)
			out_i.append(base_idx)
			out_i.append(base_idx + 1)
			out_i.append(base_idx + 2)
			kept += 1

		var out_arrays: Array = []
		out_arrays.resize(Mesh.ARRAY_MAX)
		out_arrays[Mesh.ARRAY_VERTEX] = out_v
		out_arrays[Mesh.ARRAY_NORMAL] = out_n
		out_arrays[Mesh.ARRAY_TEX_UV] = out_uv
		out_arrays[Mesh.ARRAY_INDEX] = out_i
		new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out_arrays)
		new_mesh.surface_set_material(new_mesh.get_surface_count() - 1, mat)
		print("  ", item_name, " surface ", s, ": kept ", kept, " tris, origin=", origin, " aabb=", new_mesh.get_aabb())

	root.free()
	lib.set_item_name(item_id, item_name)
	lib.set_item_mesh(item_id, new_mesh)
	lib.set_item_mesh_transform(item_id, Transform3D.IDENTITY)
	lib.set_item_mesh_cast_shadow(item_id, RenderingServer.SHADOW_CASTING_SETTING_ON)
	print("Updated item ", item_id, " (", item_name, ") from ", glb_path)
	return true


func _make_cliff_material(src_mat: Material) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	if src_mat is StandardMaterial3D:
		var sm := src_mat as StandardMaterial3D
		mat.albedo_texture = sm.albedo_texture
		mat.albedo_color = sm.albedo_color
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.texture_repeat = false
	mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.roughness = 1.0
	return mat


func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _find_mesh_instance(child)
		if found != null:
			return found
	return null


func _tri_area(a: Vector3, b: Vector3, c: Vector3) -> float:
	return 0.5 * (b - a).cross(c - a).length()


func _snap_edges(v: Vector3) -> Vector3:
	for axis in 3:
		if absf(v[axis]) < 0.002:
			v[axis] = 0.0
		elif absf(v[axis] - 2.0) < 0.002:
			v[axis] = 2.0
		elif absf(v[axis] + 2.0) < 0.002:
			v[axis] = -2.0
	return v


func _overlap_edges(v: Vector3) -> Vector3:
	if absf(v.x) < 0.0001:
		v.x = -OVERLAP
	elif absf(v.x - 2.0) < 0.0001:
		v.x = 2.0 + OVERLAP
	if absf(v.z) < 0.0001:
		v.z = -OVERLAP
	elif absf(v.z - 2.0) < 0.0001:
		v.z = 2.0 + OVERLAP
	elif absf(v.z + 2.0) < 0.0001:
		v.z = -2.0 - OVERLAP
	return v
