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

## Celda lógica autoritativa (no se recalcula a ciegas desde floats).
var _cell: Vector2i = Vector2i.ZERO

var actor: Node3D
var floor_grid: GridMap
var objects_grid: GridMap

var _tween: Tween
var _end_cell: Vector2i = Vector2i.ZERO

## Celdas XZ ocupadas solo a partir de shapes del MeshLibrary (p.ej. BoxShape).
## Sin shape → no bloquea en GRID (da igual el item_id de la celda).
var _blocked_cells: Dictionary = {} ## Vector2i -> true


func setup(p_actor: Node3D, p_floor: GridMap, p_objects: GridMap = null) -> void:
	actor = p_actor
	floor_grid = p_floor
	objects_grid = p_objects
	# Player._ready corre antes que los GridMap hermanos; diferir el bake.
	call_deferred("rebuild_blocked_cells")


func rebuild_blocked_cells() -> void:
	_blocked_cells.clear()
	_bake_grid_blockers(objects_grid)
	_bake_grid_blockers(floor_grid)


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
			_mark_aabb_cells(grid, (cell_xf * shape_xf) * aabb)


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


func _mark_aabb_cells(grid: GridMap, aabb: AABB) -> void:
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
			_blocked_cells[Vector2i(x, z)] = true


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
	actor.global_position = cell_to_world_center(_cell, actor.global_position.y)


func face(d: Vector2i) -> void:
	if d == Vector2i.ZERO:
		return
	previous_dir = dir
	dir = d
	if previous_dir != d:
		direction_changed.emit(d)


func requires_initial_step(d: Vector2i) -> bool:
	return d != dir and hold_time < initial_delay


func can_enter(cell: Vector2i) -> bool:
	if floor_grid == null:
		return true
	var floor_item: int = floor_grid.get_cell_item(Vector3i(cell.x, 0, cell.y))
	if floor_item == GridMap.INVALID_CELL_ITEM:
		return false
	if _blocked_cells.is_empty():
		rebuild_blocked_cells()
	if _blocked_cells.has(cell):
		return false
	return true


func try_step(d: Vector2i) -> void:
	if actor == null or moving or d == Vector2i.ZERO:
		return

	initial_step = requires_initial_step(d)
	face(d)

	var from := _cell
	var to := from + d
	moving = true
	_end_cell = from

	if initial_step:
		speed_multiplier = 1.0
		step_started.emit()
		_start_wait(turn_duration, from)
		return

	if not can_enter(to):
		speed_multiplier = 0.5
		step_started.emit()
		_start_wait(turn_duration, from)
		return

	speed_multiplier = 2.0 if is_running else 1.0
	_end_cell = to
	step_started.emit()

	var target := cell_to_world_center(to, actor.global_position.y)
	if _tween != null and is_instance_valid(_tween):
		_tween.kill()
	_tween = create_tween()
	_tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	_tween.set_trans(Tween.TRANS_LINEAR)
	_tween.set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(actor, "global_position", target, get_step_duration())
	_tween.finished.connect(_on_step_tween_finished, CONNECT_ONE_SHOT)


func _start_wait(duration: float, end_cell: Vector2i) -> void:
	_end_cell = end_cell
	if _tween != null and is_instance_valid(_tween):
		_tween.kill()
	_tween = create_tween()
	_tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	_tween.tween_interval(duration)
	_tween.finished.connect(_on_step_tween_finished, CONNECT_ONE_SHOT)


func _on_step_tween_finished() -> void:
	_tween = null
	_cell = _end_cell
	if actor != null:
		actor.global_position = cell_to_world_center(_cell, actor.global_position.y)
	initial_step = false
	moving = false
	step_finished.emit(_cell)


func cancel_movement() -> void:
	if _tween != null and is_instance_valid(_tween):
		_tween.kill()
		_tween = null
	moving = false
	initial_step = false
	hold_time = 0.0
	snap_to_cell_center()
