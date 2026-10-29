extends SceneTree
## Regenera los meshes de suelo del MeshLibrary con PlaneMesh + textura 32x32.
## Uso: godot --headless --path . -s res://Scripts/Overworld3D/tools/rebuild_floor_meshes.gd
##
## Suelos planos: PNG suelto (`_set_floor_item`) o región del tileset 2D (`_set_floor_item_from_atlas`).
## Nota: en 3D `AtlasTexture` NO recorta bien el muestreo (se ve el atlas entero). Para tiles del
## atlas 2D usamos la textura completa + UVs remapeados a la celda.

const OUTSIDE_ATLAS := "res://Sprites/Tilesets/Outside.png"
const TILE_PX := 32


func _initialize() -> void:
	var lib_path := "res://Resources/Overworld3D/MeshLibraries/3DTiles.tres"
	var lib: MeshLibrary = load(lib_path)
	if lib == null:
		push_error("No se pudo cargar MeshLibrary")
		quit(1)
		return

	_set_floor_item(lib, 0, "Snow", "res://Resources/Overworld3D/Models/SnowTile_32.png")
	var cliff_tile := "res://Resources/Overworld3D/Models/CliffFloorTile_32.png"
	if ResourceLoader.exists(cliff_tile):
		_set_floor_item(lib, 4, "Cliff Floor", cliff_tile)

	# Ejemplo Pueblo Paleta: hierba = 2º tile de la 1ª fila de Outside.png (a la derecha del negro).
	_set_floor_item_from_atlas(lib, 10, "Grass", OUTSIDE_ATLAS, Vector2i(1, 0))

	var err := ResourceSaver.save(lib, lib_path)
	if err != OK:
		push_error("Error guardando MeshLibrary: %s" % err)
		quit(1)
		return
	print("Floor meshes rebuilt in ", lib_path)
	quit(0)


func _set_floor_item(lib: MeshLibrary, item_id: int, item_name: String, tex_path: String) -> void:
	var tex: Texture2D = load(tex_path)
	if tex == null:
		push_error("No se pudo cargar textura: %s" % tex_path)
		return
	# Textura = un solo tile: UVs 0..1 con inset de medio píxel.
	_apply_floor_item(lib, item_id, item_name, tex, Rect2(0, 0, 1, 1), float(TILE_PX))


## Ítem de suelo desde una celda del atlas 2D (`atlas_cell` en tiles de 32px, origen arriba-izquierda).
## El material usa el atlas completo; los UVs del plano apuntan solo a esa celda.
func _set_floor_item_from_atlas(lib: MeshLibrary, item_id: int, item_name: String,
		atlas_path: String, atlas_cell: Vector2i) -> void:
	var atlas: Texture2D = load(atlas_path)
	if atlas == null:
		push_error("No se pudo cargar atlas: %s" % atlas_path)
		return
	var aw := float(atlas.get_width())
	var ah := float(atlas.get_height())
	if aw <= 0.0 or ah <= 0.0:
		push_error("Atlas sin tamaño: %s" % atlas_path)
		return
	# Medio píxel de inset en espacio del atlas completo.
	var inset_u := 0.5 / aw
	var inset_v := 0.5 / ah
	var x0 := (float(atlas_cell.x) * float(TILE_PX)) / aw + inset_u
	var y0 := (float(atlas_cell.y) * float(TILE_PX)) / ah + inset_v
	var x1 := (float(atlas_cell.x + 1) * float(TILE_PX)) / aw - inset_u
	var y1 := (float(atlas_cell.y + 1) * float(TILE_PX)) / ah - inset_v
	var uv_rect := Rect2(x0, y0, x1 - x0, y1 - y0)
	_apply_floor_item(lib, item_id, item_name, atlas, uv_rect, aw)
	print("  atlas cell ", atlas_cell, " uv_rect=", uv_rect, " atlas=", aw, "x", ah)


func _apply_floor_item(lib: MeshLibrary, item_id: int, item_name: String, tex: Texture2D,
		uv_rect: Rect2, inset_ref_px: float) -> void:
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
	# Si uv_rect es 0..1 completo, aplicamos inset local; si no, uv_rect ya trae el inset del atlas.
	var use_local_inset := is_equal_approx(uv_rect.position.x, 0.0) and is_equal_approx(uv_rect.position.y, 0.0) \
			and is_equal_approx(uv_rect.size.x, 1.0) and is_equal_approx(uv_rect.size.y, 1.0)
	var inset := 0.5 / maxf(inset_ref_px, 1.0) if use_local_inset else 0.0
	for i in uvs.size():
		var u := clampf(uvs[i].x, inset, 1.0 - inset)
		var v := clampf(uvs[i].y, inset, 1.0 - inset)
		uvs[i] = Vector2(
			uv_rect.position.x + u * uv_rect.size.x,
			uv_rect.position.y + v * uv_rect.size.y
		)
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	am.surface_set_material(0, mat)

	if not item_id in lib.get_item_list():
		lib.create_item(item_id)
	lib.set_item_name(item_id, item_name)
	lib.set_item_mesh(item_id, am)
	# PlaneMesh FACE_Y centrado (-1..1): offset (1,0,1) → cobertor exacto de la celda [0..2]x[0..2].
	lib.set_item_mesh_transform(item_id, Transform3D(Basis.IDENTITY, Vector3(1, 0, 1)))
	lib.set_item_mesh_cast_shadow(item_id, RenderingServer.SHADOW_CASTING_SETTING_OFF)
	print("Updated item ", item_id, " (", item_name, ") tex=", tex.resource_path)
