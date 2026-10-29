extends SceneTree
## Rebake Tree desde GLB para GridMap.
## - +2 en Z para alinear con la celda colocada
## - BoxShape 2×2 celdas (X×Z): size (4, 4, 4) @ (2, 2, 2)
## - material nearest + alpha scissor + sin cull (el quad mira hacia -Z; la cámara típica mira -Z)
## Uso: godot --headless --path . -s res://Scripts/Overworld3D/tools/rebuild_tree_meshes.gd


const CELL_Z_ALIGN := Vector3(0, 0, 2)
## Huella lógica: 2 celdas en X, 2 en Z (cell_size 2).
const FOOTPRINT_SIZE := Vector3(4, 4, 4)
const FOOTPRINT_CENTER := Vector3(2, 2, 2)


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
	var new_mesh := ArrayMesh.new()
	for s in src.get_surface_count():
		var arrays: Array = src.surface_get_arrays(s).duplicate()
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX].duplicate()
		for i in verts.size():
			verts[i] = verts[i] + CELL_Z_ALIGN
		arrays[Mesh.ARRAY_VERTEX] = verts
		new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		new_mesh.surface_set_material(s, mat)
		print("  ", item_name, " surface ", s, ": verts=", verts.size(), " aabb=", new_mesh.get_aabb())

	root.free()
	if not item_id in lib.get_item_list():
		lib.create_item(item_id)
	lib.set_item_name(item_id, item_name)
	lib.set_item_mesh(item_id, new_mesh)
	lib.set_item_mesh_transform(item_id, Transform3D.IDENTITY)
	lib.set_item_mesh_cast_shadow(item_id, RenderingServer.SHADOW_CASTING_SETTING_ON)
	var box := BoxShape3D.new()
	box.size = FOOTPRINT_SIZE
	lib.set_item_shapes(item_id, [box, Transform3D(Basis.IDENTITY, FOOTPRINT_CENTER)])
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
	# El quad del árbol mira hacia -Z; la cámara del overworld también mira -Z → sin cull.
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.roughness = 1.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat


func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _find_mesh_instance(child)
		if found != null:
			return found
	return null
