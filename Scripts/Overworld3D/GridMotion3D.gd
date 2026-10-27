extends Node
class_name GridMotion3D
## Movimiento a pasos en grid 3D para el spike Overworld3D.
## Solo mueve: las reglas de celda (bloqueos, escaleras, suelo, eventos) viven en OverworldGrid3D.

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
## true tras disparar COLLISION contra un evento, hasta soltar/cambiar la dirección.
var _collision_latched: bool = false

## Celda lógica autoritativa (no se recalcula a ciegas desde floats).
var _cell: Vector2i = Vector2i.ZERO
## Altura Y autoritativa (0 suelo bajo; step_height/2 en escalera; step_height arriba).
var actor_y: float = 0.0

var actor: Node3D
var grid: OverworldGrid3D

var _tween: Tween
var _end_cell: Vector2i = Vector2i.ZERO
var _end_y: float = 0.0


func setup(p_actor: Node3D, p_grid: OverworldGrid3D) -> void:
	actor = p_actor
	grid = p_grid
	if actor != null:
		actor_y = actor.global_position.y


func get_step_duration() -> float:
	return step_duration / maxf(speed_multiplier, 0.01)


func world_to_cell(world: Vector3) -> Vector2i:
	if grid == null:
		return Vector2i(floori(world.x / 2.0), floori(world.z / 2.0))
	return grid.world_to_cell(world)


func cell_to_world_center(cell: Vector2i, y: float) -> Vector3:
	if grid == null:
		return Vector3(cell.x * 2.0 + 1.0, y, cell.y * 2.0 + 1.0)
	return grid.cell_to_world_center(cell, y)


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
	if grid == null:
		return true
	return grid.can_enter(cell, actor_y if is_nan(at_y) else at_y)


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

	var stair_move: Dictionary = grid.resolve_stair_step(from, to, d, actor_y) if grid != null else {}
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
		# Igual que 2D: si choca contra un evento cuyo trigger COLLISION se activa, no hay bump.
		if _try_event_collision(to):
			is_colliding = true
			moving = false
			return
		_start_bump(from)
		return

	is_colliding = false
	speed_multiplier = 2.0 if is_running else 1.0
	_end_cell = to
	_end_y = actor_y
	step_started.emit()
	_start_move_to(cell_to_world_center(to, actor_y))


## Evento en la celda `offset` pasos por delante (1 = la de delante). Equivalente a event_at_offset 2D.
func event_at_offset(offset: int = 1) -> Node3D:
	if grid == null:
		return null
	return grid.event_at(_cell + dir * offset)


func event_in_front() -> Node3D:
	return event_at_offset(1)


## Equivalente a GridMotion._check_player_collision (2D): solo para el Player (grupo "Player").
## Retorna true si el evento de la celda destino activó su trigger COLLISION.
## Latch: tras disparar, no se vuelve a disparar mientras se mantenga la misma dirección
## (hasta release_collision_latch()), para no repetir el evento cada frame con la tecla pulsada.
func _try_event_collision(target_cell: Vector2i) -> bool:
	if actor == null or grid == null or not actor.is_in_group("Player"):
		return false
	var ev := grid.event_at(target_cell)
	if ev == null or not ev.has_method("try_fire"):
		return false
	if _collision_latched:
		return true
	if ev.try_fire(EventTriggerSignal.SignalType.COLLISION, actor):
		_collision_latched = true
		return true
	return false


## Llamar cuando se suelta la dirección o cambia (Player3D).
func release_collision_latch() -> void:
	_collision_latched = false


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
