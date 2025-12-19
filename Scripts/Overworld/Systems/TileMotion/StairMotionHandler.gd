extends TileMotionHandler
class_name StairMotionHandler

## Handler para movimientos de escaleras (subir/bajar con animación diagonal)
## Aplica un offset diagonal al sprite durante el movimiento para simular subir/bajar escaleras

## Offset diagonal en píxeles para el movimiento de escaleras
const STAIR_OFFSET: float = 8.0

func _init(p_motion_type: String, p_motion_system: Node) -> void:
	super._init(p_motion_type, p_motion_system)


## Verifica si este handler puede manejar el movimiento hacia el tile especificado
func can_handle(
	tile_info: Dictionary,
	_actor: Node2D,
	direction: Vector2,
	_from_tile: Vector2i,
	_to_tile: Vector2i
) -> bool:
	# Verificar que el tile destino tiene stair_dir en custom_data
	var stair_dir = tile_info.get("stair_dir", "")
	if not stair_dir is String or stair_dir.is_empty():
		return false

	# stair_dir debe ser "right" o "left" (indica la dirección de la escalera)
	if stair_dir.to_lower() != "right" and stair_dir.to_lower() != "left":
		return false

	# Verificar que el movimiento es horizontal (izquierda o derecha)
	# El offset vertical se calculará según si la dirección coincide con stair_dir
	if direction != Vector2.LEFT and direction != Vector2.RIGHT:
		return false

	return true


## Ejecuta el movimiento de escalera si es válido
func on_step_started_to_tile(
	grid: OverworldGrid,
	from_tile: Vector2i,
	to_tile: Vector2i,
	actor: Node2D,
	direction: Vector2
) -> bool:
	var grid_motion = actor.get_node_or_null("GridMotion")
	# Verificar que el tile destino no está bloqueado ni ocupado
	if grid.is_blocked(actor, to_tile):
		return false  # No puede moverse, permitir movimiento normal

	if  grid.has_actor(to_tile):
		grid_motion._check_player_collision(to_tile)

	# Obtener contexto para bloquear controles (solo si es Player)
	var context: OverworldContext = null
	if grid_motion.context:
		context = grid_motion.context
	elif actor.has_method("get_context"):
		context = actor.context

	# Obtener stair_dir del tile para calcular el offset correcto
	var tile_info = grid.get_tile_info(to_tile)
	var stair_dir = tile_info.get("stair_dir", "")

	# Ejecutar el movimiento de escalera directamente (este método es async)
	await _execute_stair_movement(grid, grid_motion, context, from_tile, to_tile, direction, actor, stair_dir)

	# Retornar true para indicar que el movimiento fue consumido
	return true


## Ejecuta el movimiento de escalera de forma asíncrona
func _execute_stair_movement(
	grid: OverworldGrid,
	grid_motion: GridMotion,
	context: OverworldContext,
	from_tile: Vector2i,
	to_tile: Vector2i,
	direction: Vector2,
	actor: Node2D,
	stair_dir: String
) -> void:
	# Bloquear control del jugador si es Player
	if actor.is_in_group("Player") and context:
		context.block_player_control()

	# Marcar que está moviéndose
	grid_motion.moving = true

	# Reservar el tile destino
	grid.reserve(from_tile, to_tile, actor)

	# Obtener posición destino (centro del tile)
	var target_position = grid.tile_to_world_center(to_tile)

	# Calcular offset diagonal según stair_dir (vertical) y direction (horizontal)
	var diagonal_offset = _calculate_diagonal_offset(stair_dir, direction)

	# Obtener el sprite del actor para aplicar el offset
	var sprite_node: AnimatedSprite2D = null
	var original_offset: Vector2 = Vector2.ZERO
	if actor.has_node("AnimatedSprite2D"):
		sprite_node = actor.get_node("AnimatedSprite2D") as AnimatedSprite2D
		if sprite_node:
			original_offset = sprite_node.offset

	# Actualizar registro de eventos si es Event
	if actor is Event:
		grid_motion._update_event_registration(from_tile, to_tile)

	# Emitir step_started inicial y alternar zancada (primer paso)
	grid_motion.step_started.emit()
	grid_motion.stride_is_left = not grid_motion.stride_is_left

	# Crear tween para el movimiento
	var duration = grid_motion.get_step_duration() * 4
	var tween = actor.create_tween()
	tween.set_parallel(true)

	# Tween para la posición del actor (hacia el tile destino)
	tween.tween_property(actor, "global_position", target_position, duration)\
		.set_ease(Tween.EASE_IN_OUT)\
		.set_trans(Tween.TRANS_LINEAR)

	# Tween para el offset del sprite (movimiento diagonal)
	if sprite_node:
		var target_offset = original_offset + diagonal_offset
		# Aplicar offset durante el movimiento
		tween.tween_property(sprite_node, "offset", target_offset, duration)\
			.set_ease(Tween.EASE_IN_OUT)\
			.set_trans(Tween.TRANS_LINEAR)

	# Vaciar el tile origen
	grid.vacate(from_tile, actor)

	# Esperar un tercio de la duración y emitir step_started de nuevo (segundo paso)
	var step_duration = duration / 3.0
	await actor.get_tree().create_timer(step_duration).timeout
	grid_motion.step_started.emit()
	grid_motion.stride_is_left = not grid_motion.stride_is_left

	# Esperar otro tercio y emitir step_started de nuevo (tercer paso)
	await actor.get_tree().create_timer(step_duration).timeout
	grid_motion.step_started.emit()
	grid_motion.stride_is_left = not grid_motion.stride_is_left

	# Esperar a que termine el tween
	await tween.finished

	# Restaurar el offset del sprite al original
	if sprite_node:
		sprite_node.offset = original_offset

	# Confirmar el movimiento
	grid.commit(from_tile, to_tile, actor)
	grid_motion.moving = false

	# Desbloquear control del jugador si es Player
	if actor.is_in_group("Player") and context:
		context.unblock_player_control()

	# Emitir step_finished
	grid_motion.step_finished.emit(to_tile)

	# Llamar on_enter_tile
	grid.on_enter_tile(actor, to_tile)

	# NOTA: No alternar zancada aquí porque ya se alternó 3 veces durante el movimiento


## Calcula el offset diagonal según stair_dir y direction del actor
## @param stair_dir: Dirección de la escalera ("right" o "left")
## @param direction: Dirección del movimiento del actor (Vector2.LEFT o Vector2.RIGHT)
## Si la dirección coincide con stair_dir, sube (offset_y negativo)
## Si no coincide, baja (offset_y positivo)
func _calculate_diagonal_offset(stair_dir: String, direction: Vector2) -> Vector2:
	var offset_y: float = 0.0
	var offset_x: float = 0.0

	# Verificar que stair_dir es válido
	var stair_dir_lower = stair_dir.to_lower()
	if stair_dir_lower != "right" and stair_dir_lower != "left":
		return Vector2.ZERO

	# Verificar que la dirección es horizontal
	if direction != Vector2.LEFT and direction != Vector2.RIGHT:
		return Vector2.ZERO

	# Offset vertical: si la dirección coincide con stair_dir, sube; si no, baja
	var direction_matches: bool = false
	if stair_dir_lower == "right" and direction == Vector2.RIGHT:
		direction_matches = true
	elif stair_dir_lower == "left" and direction == Vector2.LEFT:
		direction_matches = true

	if direction_matches:
		offset_y = -STAIR_OFFSET  # Hacia arriba (sube)
	else:
		offset_y = STAIR_OFFSET   # Hacia abajo (baja)

	# Offset horizontal según la dirección del movimiento del actor
	if direction == Vector2.LEFT:
		offset_x = -STAIR_OFFSET  # Hacia la izquierda
	elif direction == Vector2.RIGHT:
		offset_x = STAIR_OFFSET   # Hacia la derecha

	return Vector2(offset_x, offset_y)
