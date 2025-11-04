extends Event
class_name PushableRock

## Script para rocas empujables con la MO FUERZA (STRENGTH)
##
## Uso:
## 1. Crear un Event en el mapa
## 2. Asignarle este script
## 3. Añadir UseMOCommand con mo_type = STRENGTH
## 4. La roca se empujará automáticamente cuando el jugador use FUERZA

## Flag para evitar empujar mientras ya se está moviendo
var is_moving: bool = false

## Empuja la roca en una dirección
## @param direction: Vector2 (UP, DOWN, LEFT, RIGHT)
## @return: true si se pudo empujar, false si está bloqueado
func push(direction: Vector2) -> bool:
	if is_moving:
		return false

	# Obtener el grid activo del grupo
	var grid = get_tree().get_first_node_in_group("OverworldGrid") as OverworldGrid
	if not grid:
		push_error("PushableRock: No se encontró el OverworldGrid")
		return false

	# Calcular posición actual y siguiente
	var current_tile = grid.world_to_tile(global_position)
	var next_tile = current_tile + Vector2i(direction)

	# Verificar si el tile destino es válido
	if not _can_move_to_tile(next_tile, grid):
		return false

	# Empujar la roca (mover suavemente)
	is_moving = true
	await _move_to_tile(next_tile, grid)
	is_moving = false

	return true

## Verifica si la roca puede moverse al tile destino
func _can_move_to_tile(tile: Vector2i, grid: OverworldGrid) -> bool:
	# Verificar que el tile no está bloqueado (terreno, colisiones)
	if grid.is_blocked(self, tile):
		return false

	# Verificar si hay otro actor (jugador, NPC) en ese tile
	if grid.has_actor(tile):
		return false

	# Verificar si hay otro evento en ese tile que bloquee el paso
	var event_in_tile = grid.event_at(tile)
	if event_in_tile and event_in_tile != self:
		# Solo bloquear si el evento NO es "through"
		if event_in_tile.current_page and not event_in_tile.current_page.through:
			return false
		# Si es "through", se puede pasar por encima (no bloquear)

	return true

## Mueve la roca al tile destino con animación suave
func _move_to_tile(tile: Vector2i, grid: OverworldGrid) -> void:
	# Obtener posición mundial del tile destino
	var target_pos = grid.tile_to_world_center(tile)

	# Actualizar ocupación en el grid
	var current_tile = grid.world_to_tile(global_position)

	# Desregistrar evento del tile actual
	grid.unregister_event(current_tile, self)

	# Liberar tile actual (ocupación física)
	grid.vacate(current_tile, self)

	# Registrar evento en el tile destino
	grid.register_event(tile, self)

	# Ocupar tile destino (ocupación física)
	grid.occupy(tile, self)

	# Mover con tween lineal (velocidad constante)
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(self, "global_position", target_pos, 0.6)

	# Esperar a que termine el movimiento
	await tween.finished

	# TODO: Reproducir sonido de roca moviéndose
	# TODO: Verificar si la roca cayó en un agujero o presionó un switch

## Callback cuando el jugador colisiona con la roca
## Se llama automáticamente desde GridMotion cuando el jugador intenta entrar al tile de la roca
func on_player_collision() -> void:
	# Verificar si STRENGTH está activo
	var mo_system = get_tree().get_first_node_in_group("MOSystem")
	if not mo_system:
		# Si no hay MOSystem, ejecutar el comportamiento normal del evento (ACTION_BUTTON)
		super.on_player_collision()
		return

	var strength_active = mo_system.is_effect_active("STRENGTH_ENABLED")

	if not strength_active:
		# Si STRENGTH no está activo, ejecutar el comportamiento normal del evento
		super.on_player_collision()
		return

	# STRENGTH activo - empujar automáticamente
	_auto_push()

## Empuja la roca automáticamente cuando STRENGTH está activo
func _auto_push() -> void:
	# Obtener el jugador
	var player = get_tree().get_first_node_in_group("Player")
	if not player:
		return

	# Calcular dirección del empuje (jugador → roca)
	var push_direction = _calculate_push_direction_from_player(player)

	# Bloquear el control del jugador durante el empuje
	SignalManager.player_control_blocked.emit()

	# Empujar la roca
	await push(push_direction)

	# Desbloquear el control del jugador
	SignalManager.player_control_unblocked.emit()

## Calcula la dirección de empuje basándose en la posición del jugador
func _calculate_push_direction_from_player(player: Node) -> Vector2:
	var diff = global_position - player.global_position

	# Determinar la dirección principal basándose en la diferencia
	if abs(diff.x) > abs(diff.y):
		# Movimiento horizontal predominante
		return Vector2.RIGHT if diff.x > 0 else Vector2.LEFT
	else:
		# Movimiento vertical predominante
		return Vector2.DOWN if diff.y > 0 else Vector2.UP
