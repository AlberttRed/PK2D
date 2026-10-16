extends SceneTree
## Rebake Tree desde GLB para GridMap.
## - conserva el footprint del export; solo +2 en Z (una celda "abajo") para alinear con la celda colocada
## - BoxShape 2×1 celdas (X×Z): size (4, 4, 2) centrada en (2, 2, 1) → cubre [0..4]×[0..2]
## - material nearest + alpha scissor (billboard con transparencia)
## Uso: godot --headless --path . -s res://Scripts/Overworld3D/tools/rebuild_tree_meshes.gd


const CELL_Z_ALIGN := Vector3(0, 0, 2)
## Huella lógica: 2 celdas en X, 1 en Z (cell_size 2).
const FOOTPRINT_SIZE := Vector3(4, 4, 2)
const FOOTPRINT_CENTER := Vector3(2, 2, 1)


func _initialize() -> void:
	var lib_path := "res://Resources/Overworld3D/MeshLibraries/3DTiles.tres"
	var lib: MeshLibrary = load(lib_path)
	if lib == null:
		push_error("No se pudo cargar MeshLibrary")
		quit(1)
		return

	if not _rebuild_item(lib, 1, "Tree", "res://Resources/Overworld3D/Models/Tree.glb"):
		quit(1)
		return

	var err := ResourceSaver.save(lib, lib_path)
	if err != OK:
		push_error("Error guardando MeshLibrary: %s" % err)
		quit(1)
		return
	print("Tree mesh rebuilt in ", lib_path)
	quit(0)


func _rebuild_item(lib: MeshLibrary, item_id: int, item_name: String, glb_path: String) -> bool:
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

	var mat := _make_tree_material(src_mat)
	# Mismo footprint del GLB + una celda en +Z (sin recentrar/centrar).
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
			var a := verts[i0] + CELL_Z_ALIGN
			var b := verts[i1] + CELL_Z_ALIGN
			var c := verts[i2] + CELL_Z_ALIGN
			if _tri_area(a, b, c) < 1e-7:
				continue
			var base_idx := out_v.size()
			for src_i in [i0, i1, i2]:
				out_v.append(verts[src_i] + CELL_Z_ALIGN)
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
		print("  ", item_name, " surface ", s, ": kept ", kept, " tris, aabb=", new_mesh.get_aabb())

	root.free()
	lib.set_item_name(item_id, item_name)
	lib.set_item_mesh(item_id, new_mesh)
	lib.set_item_mesh_transform(item_id, Transform3D.IDENTITY)
	lib.set_item_mesh_cast_shadow(item_id, RenderingServer.SHADOW_CASTING_SETTING_ON)
	var box := BoxShape3D.new()
	box.size = FOOTPRINT_SIZE
	var shape_xf := Transform3D(Basis.IDENTITY, FOOTPRINT_CENTER)
	lib.set_item_shapes(item_id, [box, shape_xf])
	print("Updated item ", item_id, " (", item_name, ") from ", glb_path,
		" + BoxShape ", FOOTPRINT_SIZE, " @ ", FOOTPRINT_CENTER)
	return true


func _make_tree_material(src_mat: Material) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	if src_mat is StandardMaterial3D:
		var sm := src_mat as StandardMaterial3D
		mat.albedo_texture = sm.albedo_texture
		mat.albedo_color = sm.albedo_color
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.texture_repeat = false
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.01
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
