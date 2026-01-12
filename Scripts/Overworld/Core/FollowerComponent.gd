extends Node
class_name FollowerComponent

## Componente reutilizable para que un actor siga automáticamente a otro
## Reproduce los movimientos del actor líder al mismo tiempo, ignorando initial_step.

## Referencia al actor líder
var leader: Node2D = null

## Estado de seguimiento activo
var is_following: bool = false

## Distancia en tiles que debe mantener el follower
@export var distance_tiles: int = 1

## Si debe copiar la dirección del líder
@export var copy_facing: bool = true

## Si debe copiar el estado de correr del líder
@export var copy_run_state: bool = true

## Política de recuperación cuando queda bloqueado
@export var catchup_policy: CatchupPolicy.Type = CatchupPolicy.Type.SNAP

## Referencias a componentes
var follower_motion: GridMotion = null
var follower_actor: Node2D = null
var leader_motion: GridMotion = null
var context: OverworldContext = null

## Estado de movimiento
var is_executing_step: bool = false
var pending_movement: bool = false
var pending_target_tile: Vector2i = Vector2i.ZERO
var follower_start_tile: Vector2i = Vector2i.ZERO

## Valores originales del follower (para restaurar al detener seguimiento)
var original_is_running: bool = false
var original_base_speed: float = 1.0

## Historial de tiles del leader
var step_history: Array[Vector2i] = []
var max_history_size: int = 16
var leader_previous_tile: Vector2i = Vector2i.ZERO

func _ready() -> void:
	follower_actor = get_parent() as Node2D
	if not follower_actor:
		push_error("FollowerComponent: Debe ser hijo de un Node2D")
		return

	follower_motion = follower_actor.get_node_or_null("GridMotion")
	if not follower_motion:
		push_error("FollowerComponent: El actor debe tener un componente GridMotion")

## Inicia el seguimiento de un líder
func start_follow(p_leader: Node2D, config: Dictionary = {}) -> void:
	if not p_leader:
		push_error("FollowerComponent: Leader no puede ser nulo")
		return

	# Aplicar configuración
	if config.has("distance_tiles"): distance_tiles = config["distance_tiles"]
	if config.has("copy_facing"): copy_facing = config["copy_facing"]
	if config.has("copy_run_state"): copy_run_state = config["copy_run_state"]
	if config.has("catchup_policy"): catchup_policy = config["catchup_policy"]

	leader = p_leader
	leader_motion = leader.get_node_or_null("GridMotion")
	if not leader_motion:
		push_error("FollowerComponent: El líder debe tener un componente GridMotion")
		return

	# Guardar valores originales del follower antes de modificarlos
	if follower_motion:
		original_is_running = follower_motion.is_running
		original_base_speed = follower_motion.base_speed

	# Desconectar señales primero si ya estaban conectadas (para evitar duplicados)
	if leader_motion.step_started.is_connected(_on_leader_step_started):
		leader_motion.step_started.disconnect(_on_leader_step_started)
	if leader_motion.step_finished.is_connected(_on_leader_step_finished):
		leader_motion.step_finished.disconnect(_on_leader_step_finished)

	# Conectar las señales
	leader_motion.step_started.connect(_on_leader_step_started)
	leader_motion.step_finished.connect(_on_leader_step_finished)

	if leader.is_in_group("Player") and context:
		if context.warp_finished.is_connected(_on_leader_warped):
			context.warp_finished.disconnect(_on_leader_warped)
		context.warp_finished.connect(_on_leader_warped)

	# Inicializar historial
	step_history.clear()
	leader_previous_tile = leader_motion.current_tile()
	step_history.append(leader_previous_tile)

	is_following = true

	# Debug: verificar que las señales se conectaron correctamente
	print("FollowerComponent: Seguimiento iniciado - follower: %s, leader: %s, step_started conectada: %s, step_finished conectada: %s, leader.is_command_controlled: %s" % [
		follower_actor.name,
		leader.name,
		leader_motion.step_started.is_connected(_on_leader_step_started),
		leader_motion.step_finished.is_connected(_on_leader_step_finished),
		leader_motion.is_command_controlled
	])

## Detiene el seguimiento
func stop_follow() -> void:
	if not is_following:
		return

	# Desconectar señales
	if leader_motion:
		if leader_motion.step_started.is_connected(_on_leader_step_started):
			leader_motion.step_started.disconnect(_on_leader_step_started)
		if leader_motion.step_finished.is_connected(_on_leader_step_finished):
			leader_motion.step_finished.disconnect(_on_leader_step_finished)

	if leader.is_in_group("Player") and context:
		if context.warp_finished.is_connected(_on_leader_warped):
			context.warp_finished.disconnect(_on_leader_warped)

	# Limpiar estado
	step_history.clear()
	leader_previous_tile = Vector2i.ZERO
	pending_movement = false
	pending_target_tile = Vector2i.ZERO
	follower_start_tile = Vector2i.ZERO
	leader = null
	leader_motion = null
	is_following = false
	is_executing_step = false

	if follower_motion:
		follower_motion.is_command_controlled = false
		# Restaurar valores originales del follower
		follower_motion.is_running = original_is_running
		follower_motion.base_speed = original_base_speed

## Verifica si el componente está activo
func is_active() -> bool:
	return is_following and leader != null and is_instance_valid(leader)

## Se ejecuta cuando el líder EMPIEZA un paso (movimiento simultáneo)
func _on_leader_step_started() -> void:
	if not is_following or not leader_motion or not follower_motion:
		return

	if is_executing_step or follower_motion.moving:
		return

	if leader_motion.initial_step or leader_motion.dir == Vector2.ZERO:
		return

	# Verificar si el leader puede moverse antes de mover al follower
	var leader_current = leader_motion.current_tile()
	var leader_target = leader_current + Vector2i(leader_motion.dir)
	if not leader_motion.grid.can_step_to(leader, leader_current, leader_target):
		return

	# Calcular tile destino del follower
	var follower_target: Vector2i
	var follower_dir: Vector2
	var follower_current = follower_motion.current_tile()

	if step_history.size() >= distance_tiles:
		follower_target = step_history[step_history.size() - distance_tiles]
		var diff = follower_target - follower_current
		follower_dir = _normalize_direction(diff, leader_motion.dir)
	else:
		follower_target = leader_previous_tile
		follower_dir = leader_motion.dir

	if follower_target == follower_current:
		return

	# Verificar si es adyacente
	var target_diff = follower_target - follower_current
	if abs(target_diff.x) + abs(target_diff.y) != 1:
		_execute_follower_jump_to_tile(follower_target, follower_dir)
		return

	# Guardar estado y ejecutar movimiento
	pending_movement = true
	pending_target_tile = follower_target
	follower_start_tile = follower_current
	_execute_follower_step_immediate(follower_target, follower_dir)

## Se ejecuta cuando el líder TERMINA un paso
func _on_leader_step_finished(tile: Vector2i) -> void:
	if not is_following or not leader_motion or leader_motion.initial_step:
		return

	# Verificar si el leader realmente se movió
	if tile == leader_previous_tile:
		if pending_movement:
			_cancel_follower_movement()
		return

	# Confirmar movimiento y actualizar historial
	pending_movement = false
	step_history.append(tile)
	if step_history.size() > max_history_size:
		step_history = step_history.slice(-max_history_size)
	leader_previous_tile = tile

## Normaliza una diferencia de tiles a dirección cardinal
func _normalize_direction(diff: Vector2i, fallback: Vector2) -> Vector2:
	if abs(diff.x) > abs(diff.y):
		return Vector2(sign(diff.x), 0)
	elif abs(diff.y) > abs(diff.x):
		return Vector2(0, sign(diff.y))
	return fallback

## Ejecuta un paso del follower
func _execute_follower_step_immediate(target_tile: Vector2i, direction: Vector2) -> void:
	if not follower_motion or not is_following or is_executing_step or follower_motion.moving:
		return

	is_executing_step = true
	follower_motion.is_command_controlled = true

	if copy_run_state:
		follower_motion.is_running = leader_motion.is_running

	# Siempre copiar la velocidad base del leader
	follower_motion.base_speed = leader_motion.base_speed

	follower_motion.face(direction)

	if follower_actor.has_node("ActorAnimator"):
		follower_actor.get_node("ActorAnimator").idle(direction)

	var follower_current = follower_motion.current_tile()
	var move_dir = _normalize_direction(target_tile - follower_current, direction)

	if not follower_motion.grid.can_step_to(follower_actor, follower_current, target_tile):
		is_executing_step = false
		return

	follower_motion.try_step(move_dir)
	_execute_follower_movement_async()

## Ejecuta un salto/teleport del follower
func _execute_follower_jump_to_tile(target_tile: Vector2i, direction: Vector2) -> void:
	if not follower_motion or not is_following or is_executing_step or follower_motion.moving:
		return

	is_executing_step = true
	follower_motion.is_command_controlled = true

	if copy_run_state:
		follower_motion.is_running = leader_motion.is_running

	# Siempre copiar la velocidad base del leader
	follower_motion.base_speed = leader_motion.base_speed

	follower_motion.face(direction)

	if follower_actor.has_node("ActorAnimator"):
		follower_actor.get_node("ActorAnimator").idle(direction)

	var occupancy = follower_actor.get_node_or_null("Occupancy")
	if occupancy:
		occupancy.teleport_to_tile(target_tile)
		is_executing_step = false
	else:
		follower_motion.jump_to_tile(target_tile, false, 0)
		await follower_motion.step_finished
		is_executing_step = false

## Cancela el movimiento del follower
func _cancel_follower_movement() -> void:
	if not follower_motion:
		return

	if follower_motion.moving:
		follower_motion.stop_movement()

	var occupancy = follower_actor.get_node_or_null("Occupancy")
	if occupancy:
		occupancy.teleport_to_tile(follower_start_tile)
	else:
		follower_motion.jump_to_tile(follower_start_tile, false, 0)

	pending_movement = false
	is_executing_step = false

## Ejecuta el movimiento del follower de forma asíncrona
func _execute_follower_movement_async() -> void:
	await follower_motion.step_finished
	is_executing_step = false

## Se ejecuta cuando el líder hace warp/teleport
func _on_leader_warped(_map_id: String, _tile_pos: Vector2i) -> void:
	if not is_following:
		return

	step_history.clear()
	await get_tree().process_frame

	match catchup_policy:
		CatchupPolicy.Type.SNAP:
			_snap_to_leader()
		CatchupPolicy.Type.TELEPORT_IF_FAR:
			if _calculate_tile_distance() > distance_tiles * 2:
				_snap_to_leader()
		_:  # WAIT o cualquier otro
			pass

	# Reinicializar historial
	if leader_motion:
		leader_previous_tile = leader_motion.current_tile()
		step_history.append(leader_previous_tile)

## Calcula la distancia en tiles entre follower y leader
func _calculate_tile_distance() -> int:
	if not leader_motion or not follower_motion:
		return 999

	var diff = leader_motion.current_tile() - follower_motion.current_tile()
	return max(abs(diff.x), abs(diff.y))

## Teletransporta el follower cerca del líder
func _snap_to_leader() -> void:
	if not leader_motion or not follower_motion:
		return

	var leader_tile = leader_motion.current_tile()
	var behind_tile = leader_tile - Vector2i(leader_motion.dir) * distance_tiles

	if follower_motion.grid.can_step_to(follower_actor, follower_motion.current_tile(), behind_tile):
		follower_actor.global_position = follower_motion.grid.tile_to_world_center(behind_tile)
		return

	# Intentar tiles laterales
	var side_tiles = [
		behind_tile + Vector2i(1, 0), behind_tile + Vector2i(-1, 0),
		behind_tile + Vector2i(0, 1), behind_tile + Vector2i(0, -1)
	]

	for side_tile in side_tiles:
		if follower_motion.grid.can_step_to(follower_actor, follower_motion.current_tile(), side_tile):
			follower_actor.global_position = follower_motion.grid.tile_to_world_center(side_tile)
			return

## Establece el contexto del Overworld
func set_context(overworld_context: OverworldContext) -> void:
	context = overworld_context
	if is_following and leader and leader.is_in_group("Player"):
		if context and not context.warp_finished.is_connected(_on_leader_warped):
			context.warp_finished.connect(_on_leader_warped)

## Limpia el estado cuando el actor se desactiva (chunk)
func pause_follow() -> void:
	if not is_following:
		return

	if leader_motion and leader_motion.step_started.is_connected(_on_leader_step_started):
		leader_motion.step_started.disconnect(_on_leader_step_started)

	if leader and leader.is_in_group("Player") and context:
		if context.warp_finished.is_connected(_on_leader_warped):
			context.warp_finished.disconnect(_on_leader_warped)

## Reanuda el seguimiento cuando el actor se reactiva (chunk)
func resume_follow() -> void:
	if not is_following or not leader:
		return

	if leader_motion:
		if not leader_motion.step_started.is_connected(_on_leader_step_started):
			leader_motion.step_started.connect(_on_leader_step_started)
		if not leader_motion.step_finished.is_connected(_on_leader_step_finished):
			leader_motion.step_finished.connect(_on_leader_step_finished)

	if leader.is_in_group("Player") and context:
		if context and not context.warp_finished.is_connected(_on_leader_warped):
			context.warp_finished.connect(_on_leader_warped)

	step_history.clear()
	if leader_motion:
		leader_previous_tile = leader_motion.current_tile()
		step_history.append(leader_previous_tile)
