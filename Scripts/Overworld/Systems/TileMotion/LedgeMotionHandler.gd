extends TileMotionHandler
class_name LedgeMotionHandler

## Handler para movimientos de salto sobre ledges (acantilados)
## Migra la lógica de ledges desde GridMotion a este handler centralizado

func _init(p_motion_type: String, p_motion_system: Node) -> void:
	super._init(p_motion_type, p_motion_system)


## Verifica si este handler puede manejar el movimiento hacia el tile especificado
func can_handle(
	tile_info: Dictionary,
	actor: Node2D,
	direction: Vector2,
	_from_tile: Vector2i,
	_to_tile: Vector2i
) -> bool:

	# Verificar que el tile destino tiene ledge_direction en custom_data
	var ledge_dir = tile_info.get("ledge_direction", "")
	if not ledge_dir is String or ledge_dir.is_empty():
		return false

	# Convertir string de dirección a Vector2
	var ledge_direction = _string_to_direction(ledge_dir)
	if ledge_direction == Vector2.ZERO:
		return false

	# Verificar que la dirección del movimiento coincide con la dirección del ledge
	if ledge_direction != direction:
		return false

	return true


## Ejecuta el salto de ledge si es válido
func on_step_started_to_tile(
	grid: OverworldGrid,
	from_tile: Vector2i,
	_to_tile: Vector2i,
	actor: Node2D,
	direction: Vector2
) -> bool:
	# Verificar que el tile de aterrizaje está libre
	# Para ledges, el salto es de 2 tiles en total desde la posición actual
	# landing_tile = from + 2 tiles en la dirección
	var landing_tile = from_tile + Vector2i(direction) * 2

	# Verificar que el tile de aterrizaje existe y no está bloqueado ni ocupado
	if grid.is_blocked(actor, landing_tile) or grid.has_actor(landing_tile):
		return false  # No puede saltar, permitir movimiento normal

	# Obtener GridMotion del actor
	var grid_motion = actor.get_node_or_null("GridMotion")
	if not grid_motion:
		return false

	# Obtener contexto para bloquear controles
	var context: OverworldContext = null
	if grid_motion.context:
		context = grid_motion.context
	elif actor.has_method("get_context"):
		context = actor.context

	if not context:
		push_warning("LedgeMotionHandler: No se pudo obtener OverworldContext")
		return false

	# Ejecutar el salto directamente (este método es async, así que podemos usar await)
	await _execute_ledge_jump(grid_motion, context, landing_tile)

	# Retornar true para indicar que el movimiento fue consumido
	return true


## Ejecuta el salto de ledge de forma asíncrona
func _execute_ledge_jump(
	grid_motion: GridMotion,
	context: OverworldContext,
	landing_tile: Vector2i
) -> void:
	# Bloquear control del jugador
	context.block_player_control()

	# Marcar que está saltando (para que GridMotion lo sepa)
	grid_motion.is_jumping_ledge = true

	# Emitir señal de inicio de salto
	grid_motion.ledge_jump_started.emit()

	# Ejecutar el salto usando jump_to_tile de GridMotion (async)
	await grid_motion.jump_to_tile(landing_tile, true, -8)

	# Limpiar estado
	grid_motion.is_jumping_ledge = false
	grid_motion.ledge_jump_finished.emit()

	# Desbloquear control del jugador
	context.unblock_player_control()

	# NOTA: jump_to_tile NO emite step_finished automáticamente (solo _execute_ledge_jump lo hace)
	# Emitir step_finished manualmente
	grid_motion.step_finished.emit(landing_tile)


## Convierte un string de dirección a Vector2
func _string_to_direction(dir_string: String) -> Vector2:
	match dir_string.to_lower():
		"up":
			return Vector2.UP
		"down":
			return Vector2.DOWN
		"left":
			return Vector2.LEFT
		"right":
			return Vector2.RIGHT
		_:
			return Vector2.ZERO
