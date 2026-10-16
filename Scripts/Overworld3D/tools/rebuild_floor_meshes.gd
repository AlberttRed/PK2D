extends SceneTree
## Regenera los meshes de suelo del MeshLibrary con PlaneMesh + textura 32x32.
## Uso: godot --headless --path . -s res://Scripts/Overworld3D/tools/rebuild_floor_meshes.gd

func _initialize() -> void:
	var lib_path := "res://Resources/Overworld3D/MeshLibraries/3DTiles.tres"
	var lib: MeshLibrary = load(lib_path)
	if lib == null:
		push_error("No se pudo cargar MeshLibrary")
		quit(1)
		return

	_set_floor_item(lib, 0, "Snow", "res://Resources/Overworld3D/Models/SnowTile_32.png")
	# Cliff floor: extraer tile si existe; si no, reutilizar snow temporalmente no.
	# Usamos textura atlas con material nearest + plane; UV 0-1 sobre crop dedicado si hay.
	var cliff_tile := "res://Resources/Overworld3D/Models/CliffFloorTile_32.png"
	if ResourceLoader.exists(cliff_tile):
		_set_floor_item(lib, 4, "Cliff Floor", cliff_tile)

	var err := ResourceSaver.save(lib, lib_path)
	if err != OK:
		push_error("Error guardando MeshLibrary: %s" % err)
		quit(1)
		return
	print("Floor meshes rebuilt in ", lib_path)
	quit(0)


func _set_floor_item(lib: MeshLibrary, item_id: int, item_name: String, tex_path: String) -> void:
	var tex: Texture2D = load(tex_path)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.texture_repeat = false
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL

	var plane := PlaneMesh.new()
	plane.size = Vector2(2.0, 2.0)
	plane.orientation = PlaneMesh.FACE_Y

	var am := ArrayMesh.new()
	var arrays: Array = plane.get_mesh_arrays()
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var inset := 0.5 / 32.0
	for i in uvs.size():
		uvs[i] = Vector2(
			clampf(uvs[i].x, inset, 1.0 - inset),
			clampf(uvs[i].y, inset, 1.0 - inset)
		)
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	am.surface_set_material(0, mat)

	lib.set_item_name(item_id, item_name)
	lib.set_item_mesh(item_id, am)
	# PlaneMesh FACE_Y centrado → desplazar a esquina como el tile Crocotile (0..2, -2..0).
	lib.set_item_mesh_transform(item_id, Transform3D(Basis.IDENTITY, Vector3(1, 0, -1)))
	lib.set_item_mesh_cast_shadow(item_id, RenderingServer.SHADOW_CASTING_SETTING_OFF)
	print("Updated item ", item_id, " (", item_name, ")")
