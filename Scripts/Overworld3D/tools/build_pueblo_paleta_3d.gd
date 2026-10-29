extends SceneTree
## Genera Pueblo_Paleta3D a partir del mapa 2D: suelo (Terrain) + árboles (Tree.glb).
## Añade al MeshLibrary los tiles de Outside/Sea que falten (PlaneMesh + UVs de atlas).
##
## Uso:
##   godot --headless --path . -s res://Scripts/Overworld3D/tools/build_pueblo_paleta_3d.gd

const MAP_2D := "res://Scenes/Overworld/Maps/Pueblo Paleta/Pueblo_Paleta.tscn"
const TEMPLATE_3D := "res://Scenes/Overworld3D/Maps/MapTemplate3D.tscn"
const OUT_3D := "res://Scenes/Overworld3D/Maps/Pueblo Paleta/Pueblo_Paleta3D.tscn"
const LIB_PATH := "res://Resources/Overworld3D/MeshLibraries/3DTiles.tres"
const OUTSIDE := "res://Sprites/Tilesets/Outside.png"
const SEA := "res://Sprites/Autotiles/Sea.png"
const TILE_PX := 32
const TREE_ITEM := 1
## Ítems de Outside.png: id = OUTSIDE_ID_BASE + ax + ay * 8
const OUTSIDE_ID_BASE := 100
## Ítems de Sea.png: id = SEA_ID_BASE + ax + ay * 32
const SEA_ID_BASE := 1000

## Atlas coords (Outside) de masa de dosel en Terrain (borde N/S/E/O del pueblo).
const TREE_ATLAS := {
	Vector2i(2, 52): true, Vector2i(3, 52): true,
	Vector2i(2, 53): true, Vector2i(3, 53): true,
	Vector2i(2, 54): true, Vector2i(3, 54): true,
	Vector2i(0, 54): true, Vector2i(1, 54): true,
}
## Bajo los árboles pintamos hierba.
const UNDER_TREE_ATLAS := Vector2i(1, 0)


func _initialize() -> void:
	var lib: MeshLibrary = load(LIB_PATH)
	if lib == null:
		push_error("No MeshLibrary")
		quit(1)
		return

	var map_2d: Node = load(MAP_2D).instantiate()
	var terrain: TileMapLayer = _find_layer(map_2d, "Terrain")
	var objects: TileMapLayer = _find_layer(map_2d, "Objects")
	if terrain == null:
		push_error("No Terrain layer")
		quit(1)
		return

	# 1) Recolectar tiles de suelo necesarios y celdas a pintar.
	var floor_cells: Dictionary = {} ## Vector2i cell -> Vector2i atlas (Outside) OR {"sea": Vector2i}
	var needed_outside: Dictionary = {} ## Vector2i atlas -> true
	var needed_sea: Dictionary = {}
	## Celdas de dosel 2D → luego se anclan Tree.glb en rejilla 2×2 (N/S/E/O).
	var tree_mass: Dictionary = {} ## Vector2i -> true

	for c in terrain.get_used_cells():
		var sid: int = terrain.get_cell_source_id(c)
		var ac: Vector2i = terrain.get_cell_atlas_coords(c)
		if sid == 3:
			if TREE_ATLAS.has(ac):
				tree_mass[c] = true
				needed_outside[UNDER_TREE_ATLAS] = true
				floor_cells[c] = UNDER_TREE_ATLAS
			else:
				needed_outside[ac] = true
				floor_cells[c] = ac
		elif sid == 4:
			# Mar: x negativo codifica atlas de Sea.png.
			needed_sea[ac] = true
			floor_cells[c] = Vector2i(-(ac.x + 1), ac.y)

	# Sea on Objects layer (pond). No tratar props (2,121 etc.) como árboles.
	if objects != null:
		for c in objects.get_used_cells():
			var sid: int = objects.get_cell_source_id(c)
			var ac: Vector2i = objects.get_cell_atlas_coords(c)
			if sid == 4:
				needed_sea[ac] = true
				floor_cells[c] = Vector2i(-(ac.x + 1), ac.y)

	# Anclas 2×2: una por bloque que tenga dosel. Cubren bordes N/S/E/O (no solo Above).
	var tree_anchors: Array[Vector2i] = _tree_anchors_2x2(tree_mass)

	needed_outside[UNDER_TREE_ATLAS] = true

	# 2) MeshLibrary: ítems de suelo.
	var outside_tex: Texture2D = load(OUTSIDE)
	var sea_tex: Texture2D = load(SEA)
	for ac in needed_outside.keys():
		_set_atlas_floor(lib, _outside_item_id(ac), "Outside_%d_%d" % [ac.x, ac.y], outside_tex, ac)
	for ac in needed_sea.keys():
		_set_atlas_floor(lib, _sea_item_id(ac), "Sea_%d_%d" % [ac.x, ac.y], sea_tex, ac)

	var err := ResourceSaver.save(lib, LIB_PATH)
	if err != OK:
		push_error("Save MeshLibrary failed: %s" % err)
		quit(1)
		return
	print("MeshLibrary updated. Outside tiles=", needed_outside.size(), " Sea tiles=", needed_sea.size())

	# 3) Escena 3D desde plantilla.
	var root: Node3D = load(TEMPLATE_3D).instantiate()
	root.name = "Pueblo_Paleta3D"
	if root.get("display_name") != null:
		root.set("display_name", "Pueblo Paleta")
	if root.get("map_id") != null:
		root.set("map_id", "Pueblo_Paleta3D")

	var floor_gm: GridMap = root.get_node("Floor")
	var objects_gm: GridMap = root.get_node("Objects")
	floor_gm.clear()
	objects_gm.clear()

	for cell in floor_cells.keys():
		var encoded: Vector2i = floor_cells[cell]
		var item_id: int
		if encoded.x < 0:
			var sea_ac := Vector2i(-encoded.x - 1, encoded.y)
			item_id = _sea_item_id(sea_ac)
		else:
			item_id = _outside_item_id(encoded)
		floor_gm.set_cell_item(Vector3i(cell.x, 0, cell.y), item_id)

	# 4) Árboles: Tree.glb con huella 2×2 sobre toda la masa de dosel (incl. laterales).
	for anchor in tree_anchors:
		objects_gm.set_cell_item(Vector3i(anchor.x, 0, anchor.y), TREE_ITEM)

	print("Floor cells=", floor_cells.size(), " Trees placed=", tree_anchors.size(),
		" mass=", tree_mass.size(), " sample=", tree_anchors.slice(0, mini(8, tree_anchors.size())))

	# 5) Guardar escena.
	DirAccess.make_dir_recursive_absolute("res://Scenes/Overworld3D/Maps/Pueblo Paleta")
	var packed := PackedScene.new()
	err = packed.pack(root)
	if err != OK:
		push_error("pack failed: %s" % err)
		quit(1)
		return
	err = ResourceSaver.save(packed, OUT_3D)
	print("Saved ", OUT_3D, " err=", err)
	quit(0 if err == OK else 1)


## Rejilla 2×2 sobre la masa de dosel. Ancla = esquina (x par, y par) de cada bloque.
func _tree_anchors_2x2(tree_mass: Dictionary) -> Array[Vector2i]:
	var occupied: Dictionary = {}
	var anchors: Array[Vector2i] = []
	var cells: Array = tree_mass.keys()
	cells.sort_custom(func(a, b): return a.y < b.y or (a.y == b.y and a.x < b.x))
	for cell in cells:
		var c: Vector2i = cell
		var ax: int = (c.x >> 1) << 1
		var ay: int = (c.y >> 1) << 1
		var anchor := Vector2i(ax, ay)
		if occupied.has(anchor):
			continue
		# Exigir al menos 2 celdas de dosel en el bloque 2×2 (evita props sueltos).
		var hits := 0
		for dz in range(2):
			for dx in range(2):
				if tree_mass.has(Vector2i(ax + dx, ay + dz)):
					hits += 1
		if hits < 2:
			continue
		occupied[anchor] = true
		anchors.append(anchor)
	return anchors


func _outside_item_id(ac: Vector2i) -> int:
	return OUTSIDE_ID_BASE + ac.x + ac.y * 8


func _sea_item_id(ac: Vector2i) -> int:
	return SEA_ID_BASE + ac.x + ac.y * 32


func _set_atlas_floor(lib: MeshLibrary, item_id: int, item_name: String, atlas: Texture2D, cell: Vector2i) -> void:
	var aw := float(atlas.get_width())
	var ah := float(atlas.get_height())
	var inset_u := 0.5 / aw
	var inset_v := 0.5 / ah
	var x0 := (float(cell.x) * float(TILE_PX)) / aw + inset_u
	var y0 := (float(cell.y) * float(TILE_PX)) / ah + inset_v
	var x1 := (float(cell.x + 1) * float(TILE_PX)) / aw - inset_u
	var y1 := (float(cell.y + 1) * float(TILE_PX)) / ah - inset_v
	var uv_rect := Rect2(x0, y0, x1 - x0, y1 - y0)

	var mat := StandardMaterial3D.new()
	mat.albedo_texture = atlas
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.texture_repeat = false
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	# Agua / tiles con transparencia.
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.1

	var plane := PlaneMesh.new()
	plane.size = Vector2(2.0, 2.0)
	plane.orientation = PlaneMesh.FACE_Y

	var am := ArrayMesh.new()
	var arrays: Array = plane.get_mesh_arrays()
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	for i in uvs.size():
		uvs[i] = Vector2(
			uv_rect.position.x + uvs[i].x * uv_rect.size.x,
			uv_rect.position.y + uvs[i].y * uv_rect.size.y
		)
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	am.surface_set_material(0, mat)

	if not item_id in lib.get_item_list():
		lib.create_item(item_id)
	lib.set_item_name(item_id, item_name)
	lib.set_item_mesh(item_id, am)
	lib.set_item_mesh_transform(item_id, Transform3D(Basis.IDENTITY, Vector3(1, 0, 1)))
	lib.set_item_mesh_cast_shadow(item_id, RenderingServer.SHADOW_CASTING_SETTING_OFF)


func _find_layer(root: Node, layer_name: String) -> TileMapLayer:
	for n in root.find_children(layer_name, "TileMapLayer", true, false):
		return n as TileMapLayer
	return null
