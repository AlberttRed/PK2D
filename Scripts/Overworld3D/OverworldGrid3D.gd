extends Node3D
class_name OverworldGrid3D
## Equivalente 3D de OverworldGrid (2D): dueño de los datos del mapa 3D.
##  - Referencias a los GridMap (Floor / Objects) y conversión celda ↔ mundo.
##  - Bake (una sola vez por mapa) de bloqueos, escaleras y alturas de suelo desde el MeshLibrary.
##  - Registro de eventos por celda (register_event / unregister_event / event_at) y su ocupación.
##  - can_enter(): única fuente de verdad de "¿se puede pisar esta celda?".
## GridMotion3D solo mueve; consulta este grid. Clave de celda: XZ lógica (Vector2i).
##
## Colocar como nodo hermano de Floor/Objects. Los Event3D cuelgan de OverworldGrid3D/Events
## (mismo esquema que 2D: OverworldGrid → Events → Event). El nombre del padre es el id del mapa.

const GROUP := "OverworldGrid3D"

## Stairs (MeshLibrary item 7): huella 2×1 (X×Z) vía BoxShape; subir/bajar en 2 pasos.
const STAIRS_ITEM_ID := 7
## Dirección de subida con orientación identidad (hacia -Z / "arriba" en mapa).
const STAIRS_BASE_CLIMB := Vector2i(0, -1)

@export var floor_grid_path: NodePath = NodePath("../Floor")
@export var objects_grid_path: NodePath = NodePath("../Objects")
@export var stair_step_height: float = 2.0

var floor_grid: GridMap
var objects_grid: GridMap

## Celdas XZ ocupadas solo a partir de shapes del MeshLibrary (p.ej. BoxShape).
## Sin shape → no bloquea en GRID (da igual el item_id de la celda).
var _blocked_cells: Dictionary = {} ## Vector2i -> true
## Huella Stairs desde shapes (no bloquea): Vector2i -> climb Vector2i.
var _stairs_cells: Dictionary = {}
## Alturas de suelo walkable por XZ (capa GridMap Y → world Y = y * cell_size.y).
var _floor_heights: Dictionary = {} ## Vector2i -> Array[float]
var _baked: bool = false

## Vector2i -> WeakRef(Event3D)
var _events: Dictionary = {}


func _enter_tree() -> void:
	add_to_group(GROUP)
	_resolve_grids()


func _resolve_grids() -> void:
	if floor_grid == null or not is_instance_valid(floor_grid):
		floor_grid = get_node_or_null(floor_grid_path) as GridMap
	if objects_grid == null or not is_instance_valid(objects_grid):
		objects_grid = get_node_or_null(objects_grid_path) as GridMap


## ID del mapa (equivalente al nombre del MapScene en 2D): nodo padre del grid.
func get_map_id() -> String:
	var parent := get_parent()
	return parent.name if parent != null else ""


func cell_size() -> Vector3:
	_resolve_grids()
	return floor_grid.cell_size if floor_grid != null else Vector3(2, 2, 2)


# --- Conversión celda ↔ mundo ---

func world_to_cell(world: Vector3) -> Vector2i:
	_resolve_grids()
	if floor_grid == null:
		var cs := 2.0
		return Vector2i(floori(world.x / cs), floori(world.z / cs))
	var local := floor_grid.to_local(world)
	var map := floor_grid.local_to_map(local)
	return Vector2i(map.x, map.z)


func cell_to_world_center(cell: Vector2i, y: float) -> Vector3:
	_resolve_grids()
	if floor_grid == null:
		var cs := 2.0
		return Vector3(cell.x * cs + cs * 0.5, y, cell.y * cs + cs * 0.5)
	# map_to_local con cell_center=false → esquina; sumamos medio cell para el centro.
	var corner := floor_grid.map_to_local(Vector3i(cell.x, 0, cell.y))
	var cs3 := floor_grid.cell_size
	var local_center := corner + Vector3(cs3.x * 0.5, 0.0, cs3.z * 0.5)
	var global := floor_grid.to_global(local_center)
	global.y = y
	return global


# --- Consulta de celdas ---

## at_y: altura de destino. Debe coincidir con un suelo en esa XZ.
func can_enter(cell: Vector2i, at_y: float) -> bool:
	_resolve_grids()
	if floor_grid == null:
		return true
	# Celdas ocupadas por Event3D no-through bloquean el paso (como la ocupación 2D).
	if is_cell_blocked(cell):
		return false
	_ensure_baked()
	# Stairs: transitables sin exigir suelo a esa altura.
	if _stairs_cells.has(cell):
		return not _blocked_cells.has(cell)
	if _blocked_cells.has(cell):
		return false
	return _has_floor_at_height(cell, at_y)


func is_stairs_cell(cell: Vector2i) -> bool:
	_ensure_baked()
	return _stairs_cells.has(cell)


func climb_dir_at(cell: Vector2i) -> Vector2i:
	_ensure_baked()
	var climb: Variant = _stairs_cells.get(cell, STAIRS_BASE_CLIMB)
	return climb as Vector2i


## Devuelve { is_stair, blocked, y } si el paso implica escalera ({} si no).
## Climb/-climb: ± half Y. Lateral sobre la huella: misma Y.
## Al salir a suelo, can_enter usa la Y de destino (no la mid de la escalera).
func resolve_stair_step(from: Vector2i, to: Vector2i, d: Vector2i, actor_y: float) -> Dictionary:
	var from_stairs := is_stairs_cell(from)
	var to_stairs := is_stairs_cell(to)
	if not from_stairs and not to_stairs:
		return {}

	var half := stair_step_height * 0.5
	var climb: Vector2i
	if to_stairs:
		climb = climb_dir_at(to)
	else:
		climb = climb_dir_at(from)

	var end_y := actor_y
	if from_stairs and to_stairs and d != climb and d != -climb:
		end_y = actor_y
	elif d == climb:
		end_y = actor_y + half
	elif d == -climb:
		end_y = actor_y - half
	else:
		return {"is_stair": true, "blocked": true}

	if not can_enter(to, end_y):
		return {"is_stair": true, "blocked": true}

	return {"is_stair": true, "blocked": false, "y": end_y}


func _has_floor_at_height(cell: Vector2i, y: float) -> bool:
	var heights: Variant = _floor_heights.get(cell)
	if heights == null:
		return false
	for h in heights as Array:
		if absf(y - float(h)) <= 0.05:
			return true
	return false


# --- Eventos (misma API que OverworldGrid 2D) ---

func register_event(cell: Vector2i, event: Node3D) -> void:
	# No sobrescribir un evento válido distinto en la misma celda.
	if _events.has(cell):
		var existing: Object = (_events[cell] as WeakRef).get_ref()
		if existing != null and existing != event and is_instance_valid(existing):
			return
	_events[cell] = weakref(event)


func unregister_event(cell: Vector2i, event: Node3D) -> void:
	if _events.has(cell) and (_events[cell] as WeakRef).get_ref() == event:
		_events.erase(cell)


func event_at(cell: Vector2i) -> Node3D:
	if _events.has(cell):
		return (_events[cell] as WeakRef).get_ref() as Node3D
	return null


## Celda donde está registrado un evento (o Vector2i.MAX si no lo está).
func cell_of(event: Node3D) -> Vector2i:
	for cell in _events.keys():
		if (_events[cell] as WeakRef).get_ref() == event:
			return cell
	return Vector2i.MAX


## true si la celda tiene un evento que bloquea el paso (página no through; sin página = bloquea, como en 2D).
func is_cell_blocked(cell: Vector2i) -> bool:
	var ev := event_at(cell)
	if ev == null or not is_instance_valid(ev):
		return false
	if ev.has_method("blocks_movement"):
		return ev.blocks_movement()
	return true


# --- Bake del MeshLibrary ---

func _ensure_baked() -> void:
	if not _baked:
		rebuild()


## Recalcula bloqueos / escaleras / alturas. Llamar si cambian los GridMap en runtime.
func rebuild() -> void:
	_resolve_grids()
	_blocked_cells.clear()
	_stairs_cells.clear()
	_floor_heights.clear()
	_bake_floor_heights(floor_grid)
	_bake_grid_blockers(objects_grid)
	_bake_grid_blockers(floor_grid)
	_bake_grid_stairs(objects_grid)
	_bake_grid_stairs(floor_grid)
	_baked = true


func _bake_floor_heights(grid: GridMap) -> void:
	if grid == null:
		return
	var sy: float = grid.cell_size.y
	for cell in grid.get_used_cells():
		var xz := Vector2i(cell.x, cell.z)
		var h: float = float(cell.y) * sy
		var heights: Array = _floor_heights.get(xz, [])
		if not heights.has(h):
			heights.append(h)
		_floor_heights[xz] = heights


func _bake_grid_blockers(grid: GridMap) -> void:
	if grid == null:
		return
	var lib: MeshLibrary = grid.mesh_library
	if lib == null:
		return
	for cell in grid.get_used_cells():
		var item_id: int = grid.get_cell_item(cell)
		if item_id == GridMap.INVALID_CELL_ITEM:
			continue
		# Stairs: walkable; su shape alimenta _stairs_cells, no blockers.
		if item_id == STAIRS_ITEM_ID:
			continue
		var shapes: Array = lib.get_item_shapes(item_id)
		if shapes.is_empty():
			continue
		var cell_basis: Basis = grid.get_cell_item_basis(cell)
		var cell_origin: Vector3 = grid.map_to_local(cell)
		var cell_xf := Transform3D(cell_basis, cell_origin)
		for i in range(0, shapes.size(), 2):
			var shape: Shape3D = shapes[i]
			var shape_xf: Transform3D = shapes[i + 1]
			var aabb := _shape_local_aabb(shape)
			if aabb.size == Vector3.ZERO:
				continue
			_mark_aabb_cells(grid, (cell_xf * shape_xf) * aabb, _blocked_cells, true)


func _bake_grid_stairs(grid: GridMap) -> void:
	if grid == null:
		return
	var lib: MeshLibrary = grid.mesh_library
	if lib == null:
		return
	for cell in grid.get_used_cells():
		var item_id: int = grid.get_cell_item(cell)
		if item_id != STAIRS_ITEM_ID:
			continue
		var climb := _climb_dir_from_basis(grid.get_cell_item_basis(cell))
		var shapes: Array = lib.get_item_shapes(item_id)
		if shapes.is_empty():
			# Sin shape: solo la celda pintada (fallback).
			_stairs_cells[Vector2i(cell.x, cell.z)] = climb
			continue
		var cell_basis: Basis = grid.get_cell_item_basis(cell)
		var cell_origin: Vector3 = grid.map_to_local(cell)
		var cell_xf := Transform3D(cell_basis, cell_origin)
		for i in range(0, shapes.size(), 2):
			var shape: Shape3D = shapes[i]
			var shape_xf: Transform3D = shapes[i + 1]
			var aabb := _shape_local_aabb(shape)
			if aabb.size == Vector3.ZERO:
				continue
			_mark_aabb_cells(grid, (cell_xf * shape_xf) * aabb, _stairs_cells, climb)


func _climb_dir_from_basis(basis: Basis) -> Vector2i:
	var v: Vector3 = basis * Vector3(float(STAIRS_BASE_CLIMB.x), 0.0, float(STAIRS_BASE_CLIMB.y))
	if absf(v.x) >= absf(v.z):
		return Vector2i(int(signf(v.x)), 0)
	return Vector2i(0, int(signf(v.z)))


func _shape_local_aabb(shape: Shape3D) -> AABB:
	if shape is BoxShape3D:
		var s: Vector3 = (shape as BoxShape3D).size
		return AABB(-s * 0.5, s)
	if shape is SphereShape3D:
		var r: float = (shape as SphereShape3D).radius
		return AABB(Vector3(-r, -r, -r), Vector3(r, r, r) * 2.0)
	if shape is CapsuleShape3D:
		var cap := shape as CapsuleShape3D
		var r2: float = cap.radius
		var h: float = cap.height
		return AABB(Vector3(-r2, -h * 0.5, -r2), Vector3(r2 * 2.0, h, r2 * 2.0))
	if shape is CylinderShape3D:
		var cyl := shape as CylinderShape3D
		var cr: float = cyl.radius
		var ch: float = cyl.height
		return AABB(Vector3(-cr, -ch * 0.5, -cr), Vector3(cr * 2.0, ch, cr * 2.0))
	return AABB()


func _mark_aabb_cells(grid: GridMap, aabb: AABB, target: Dictionary, value: Variant) -> void:
	## Muestrear a mitad de altura para no mezclar capas Y del GridMap.
	var eps := 1e-3
	var mid_y := aabb.position.y + aabb.size.y * 0.5
	var p0 := Vector3(aabb.position.x + eps, mid_y, aabb.position.z + eps)
	var p1 := Vector3(aabb.position.x + aabb.size.x - eps, mid_y, aabb.position.z + aabb.size.z - eps)
	var c0 := grid.local_to_map(p0)
	var c1 := grid.local_to_map(p1)
	var x0 := mini(c0.x, c1.x)
	var x1 := maxi(c0.x, c1.x)
	var z0 := mini(c0.z, c1.z)
	var z1 := maxi(c0.z, c1.z)
	for x in range(x0, x1 + 1):
		for z in range(z0, z1 + 1):
			target[Vector2i(x, z)] = value
