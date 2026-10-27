extends Node
class_name GridMotion3D
## Movimiento a pasos en grid 3D para el spike Overworld3D.
## Usa la API del GridMap (local_to_map / map_to_local) para no desfazar celdas.

signal step_started
signal step_finished(cell: Vector2i)
signal direction_changed(new_dir: Vector2i)

@export var step_duration: float = 0.266
@export var initial_delay: float = 0.12
@export var turn_duration: float = 0.133

var hold_time: float = 0.0
var moving: bool = false
var dir: Vector2i = Vector2i(0, 1) ## XZ: (1,0)=+X, (0,1)=+Z
var previous_dir: Vector2i = dir
var initial_step: bool = false
var is_running: bool = false
var speed_multiplier: float = 1.0
## Alterna left/right entre pasos (misma lógica que GridMotion 2D).
var stride_is_left: bool = true
## Igual que GridMotion 2D: true desde el primer bump hasta el siguiente paso real.
var is_colliding: bool = false
## Suena el "bump" al chocar (como el Player 2D). Desactivar en NPCs.
@export var play_bump_sound: bool = true
## true solo mientras dura la espera de un bump (no durante giros ni pasos).
var _bump_active: bool = false

## Celda lógica autoritativa (no se recalcula a ciegas desde floats).
var _cell: Vector2i = Vector2i.ZERO
## Altura Y autoritativa (0 suelo bajo; step_height/2 en escalera; step_height arriba).
var actor_y: float = 0.0

var actor: Node3D
var floor_grid: GridMap
var objects_grid: GridMap

var _tween: Tween
var _end_cell: Vector2i = Vector2i.ZERO
var _end_y: float = 0.0

## Celdas XZ ocupadas solo a partir de shapes del MeshLibrary (p.ej. BoxShape).
## Sin shape → no bloquea en GRID (da igual el item_id de la celda).
var _blocked_cells: Dictionary = {} ## Vector2i -> true
## Huella Stairs desde shapes (no bloquea): Vector2i -> climb Vector2i.
var _stairs_cells: Dictionary = {}
## Alturas de suelo walkable por XZ (capa GridMap Y → world Y = y * cell_size.y).
var _floor_heights: Dictionary = {} ## Vector2i -> Array[float]

## Stairs (MeshLibrary item 7): huella 2×1 (X×Z) vía BoxShape; subir/bajar en 2 pasos.
const STAIRS_ITEM_ID := 7
## Dirección de subida con orientación identidad (hacia -Z / "arriba" en mapa).
const STAIRS_BASE_CLIMB := Vector2i(0, -1)
@export var stair_step_height: float = 2.0


func setup(p_actor: Node3D, p_floor: GridMap, p_objects: GridMap = null) -> void:
	actor = p_actor
	floor_grid = p_floor
	objects_grid = p_objects
	if actor != null:
		actor_y = actor.global_position.y
	# Player._ready corre antes que los GridMap hermanos; diferir el bake.
	call_deferred("rebuild_blocked_cells")


func rebuild_blocked_cells() -> void:
	_blocked_cells.clear()
	_stairs_cells.clear()
	_floor_heights.clear()
	_bake_floor_heights(floor_grid)
	_bake_grid_blockers(objects_grid)
	_bake_grid_blockers(floor_grid)
	_bake_grid_stairs(objects_grid)
	_bake_grid_stairs(floor_grid)


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


func get_step_duration() -> float:
	return step_duration / maxf(speed_multiplier, 0.01)


func world_to_cell(world: Vector3) -> Vector2i:
	if floor_grid == null:
		var cs := 2.0
		return Vector2i(floori(world.x / cs), floori(world.z / cs))
	var local := floor_grid.to_local(world)
	var map := floor_grid.local_to_map(local)
	return Vector2i(map.x, map.z)


func cell_to_world_center(cell: Vector2i, y: float) -> Vector3:
	if floor_grid == null:
		var cs := 2.0
		return Vector3(cell.x * cs + cs * 0.5, y, cell.y * cs + cs * 0.5)
	# map_to_local con cell_center=false → esquina; sumamos medio cell para el centro.
	var corner := floor_grid.map_to_local(Vector3i(cell.x, 0, cell.y))
	var cs := floor_grid.cell_size
	var local_center := corner + Vector3(cs.x * 0.5, 0.0, cs.z * 0.5)
	var global := floor_grid.to_global(local_center)
	global.y = y
	return global


func current_cell() -> Vector2i:
	return _cell


func snap_to_cell_center() -> void:
	if actor == null:
		return
	_cell = world_to_cell(actor.global_position)
	actor_y = actor.global_position.y
	actor.global_position = cell_to_world_center(_cell, actor_y)


func face(d: Vector2i) -> void:
	if d == Vector2i.ZERO:
		return
	previous_dir = dir
	dir = d
	if previous_dir != d:
		direction_changed.emit(d)


func requires_initial_step(d: Vector2i) -> bool:
	return d != dir and hold_time < initial_delay


## at_y: altura de destino (por defecto la del actor). Debe coincidir con un suelo en esa XZ.
func can_enter(cell: Vector2i, at_y: float = NAN) -> bool:
	if floor_grid == null:
		return true
	if _floor_heights.is_empty() and _blocked_cells.is_empty() and _stairs_cells.is_empty():
		rebuild_blocked_cells()
	# Stairs: transitables sin exigir suelo a esa altura.
	if _is_stairs_cell(cell):
		return not _blocked_cells.has(cell)
	if _blocked_cells.has(cell):
		return false
	var y: float = actor_y if is_nan(at_y) else at_y
	return _has_floor_at_height(cell, y)


func _has_floor_at_height(cell: Vector2i, y: float) -> bool:
	var heights: Variant = _floor_heights.get(cell)
	if heights == null:
		return false
	for h in heights as Array:
		if absf(y - float(h)) <= 0.05:
			return true
	return false


func try_step(d: Vector2i) -> void:
	if actor == null or moving or d == Vector2i.ZERO:
		return

	initial_step = requires_initial_step(d)
	face(d)

	var from := _cell
	var to := from + d
	moving = true
	_end_cell = from
	_end_y = actor_y

	if initial_step:
		# 2D: get_speed_multiplier(d, false, true) → 0.5; la espera es turn_duration fija.
		speed_multiplier = 0.5
		step_started.emit()
		_start_wait(turn_duration, from, actor_y)
		return

	var stair_move := _resolve_stair_step(from, to, d)
	if stair_move.get("blocked", false):
		_start_bump(from)
		return
	if stair_move.get("is_stair", false):
		is_colliding = false
		speed_multiplier = 2.0 if is_running else 1.0
		_end_cell = to
		_end_y = float(stair_move["y"])
		step_started.emit()
		_start_move_to(cell_to_world_center(to, _end_y))
		return

	if not can_enter(to):
		_start_bump(from)
		return

	is_colliding = false
	speed_multiplier = 2.0 if is_running else 1.0
	_end_cell = to
	_end_y = actor_y
	step_started.emit()
	_start_move_to(cell_to_world_center(to, actor_y))


## Choque contra pared/obstáculo. Igual que GridMotion 2D: velocidad 0.5 y se queda
## en el sitio get_step_duration() (= step_duration / 0.5), no turn_duration.
## Si fuera más corto, la animación de caminar (loop 0) se reiniciaría a mitad de ciclo.
func _start_bump(from: Vector2i) -> void:
	is_colliding = true
	speed_multiplier = 0.5
	step_started.emit()
	if play_bump_sound:
		AudioManager.play_overworld_player_bump()
	_bump_active = true
	_start_wait(get_step_duration(), from, actor_y)


## Equivalente a `motion.cancel_movement()` del Player 2D cuando is_colliding y la
## dirección del input cambia (o se suelta): termina el bump al instante.
func cancel_bump() -> void:
	if not _bump_active or not moving:
		return
	if _tween != null and is_instance_valid(_tween):
		_tween.kill()
	_on_step_tween_finished()


func _start_move_to(target: Vector3) -> void:
	if _tween != null and is_instance_valid(_tween):
		_tween.kill()
	_tween = create_tween()
	_tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	_tween.set_trans(Tween.TRANS_LINEAR)
	_tween.set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(actor, "global_position", target, get_step_duration())
	_tween.finished.connect(_on_step_tween_finished, CONNECT_ONE_SHOT)


func _start_wait(duration: float, end_cell: Vector2i, end_y: float = -1.0) -> void:
	_end_cell = end_cell
	_end_y = actor_y if end_y < 0.0 else end_y
	if _tween != null and is_instance_valid(_tween):
		_tween.kill()
	_tween = create_tween()
	_tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	_tween.tween_interval(duration)
	_tween.finished.connect(_on_step_tween_finished, CONNECT_ONE_SHOT)


func _on_step_tween_finished() -> void:
	_tween = null
	_bump_active = false
	_cell = _end_cell
	actor_y = _end_y
	if actor != null:
		actor.global_position = cell_to_world_center(_cell, actor_y)
	initial_step = false
	moving = false
	step_finished.emit(_cell)
	stride_is_left = not stride_is_left


func cancel_movement() -> void:
	if _tween != null and is_instance_valid(_tween):
		_tween.kill()
		_tween = null
	_bump_active = false
	moving = false
	initial_step = false
	hold_time = 0.0
	snap_to_cell_center()


func _is_stairs_cell(cell: Vector2i) -> bool:
	if _stairs_cells.is_empty():
		rebuild_blocked_cells()
	return _stairs_cells.has(cell)


func _climb_dir_from_basis(basis: Basis) -> Vector2i:
	var v: Vector3 = basis * Vector3(float(STAIRS_BASE_CLIMB.x), 0.0, float(STAIRS_BASE_CLIMB.y))
	if absf(v.x) >= absf(v.z):
		return Vector2i(int(signf(v.x)), 0)
	return Vector2i(0, int(signf(v.z)))


func _climb_dir_at(cell: Vector2i) -> Vector2i:
	if _stairs_cells.is_empty():
		rebuild_blocked_cells()
	var climb: Variant = _stairs_cells.get(cell, STAIRS_BASE_CLIMB)
	return climb as Vector2i


## Devuelve { is_stair, blocked, y } si el paso implica escalera.
## Climb/-climb: ± half Y. Lateral sobre la huella: misma Y.
## Al salir a suelo, can_enter usa la Y de destino (no la mid de la escalera).
func _resolve_stair_step(from: Vector2i, to: Vector2i, d: Vector2i) -> Dictionary:
	var from_stairs := _is_stairs_cell(from)
	var to_stairs := _is_stairs_cell(to)
	if not from_stairs and not to_stairs:
		return {}

	var half := stair_step_height * 0.5
	var climb: Vector2i
	if to_stairs:
		climb = _climb_dir_at(to)
	else:
		climb = _climb_dir_at(from)

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
