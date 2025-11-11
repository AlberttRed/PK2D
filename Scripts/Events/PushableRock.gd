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

	# Obtener el grid de la jerarquía local (Event → Events → OverworldGrid)
	var grid = _get_local_grid()
	if not grid:
		push_error("PushableRock: No se encontró el OverworldGrid")
		return false

	# Calcular posición actual y siguiente
	var current_tile = grid.world_to_tile(global_position)
	var next_tile = current_tile + Vector2i(direction)

	# Verificar restricciones direccionales: ¿se puede "entrar" al tile de la roca desde donde viene el empuje?
	# can_enter_tile espera la dirección del movimiento (hacia donde va el jugador)
	# Si push es DOWN, el jugador se mueve hacia DOWN, y la función calcula entrada desde UP
	if not grid.can_enter_tile(current_tile, direction):
		# El tile de la roca no permite entrar desde esa dirección
		return false

	# Verificar si el tile destino es válido
	if not _can_move_to_tile(current_tile, next_tile, grid):
		return false

	# Empujar la roca (mover suavemente)
	is_moving = true
	await _move_to_tile(next_tile, grid)
	is_moving = false

	return true

## Verifica si la roca puede moverse al tile destino
func _can_move_to_tile(from: Vector2i, to: Vector2i, grid: OverworldGrid) -> bool:
	# Verificar si el tile destino es un ledge - las rocas NO pueden ser empujadas a ledges
	var ledge_info = grid.get_ledge_info(to)
	if ledge_info["is_ledge"]:
		return false  # Bloqueado: no se puede empujar una roca a un ledge

	# Usar can_step_to que incluye validación de direcciones (ledges, etc.)
	if not grid.can_step_to(self, from, to):
		return false

	# Verificar si hay otro evento en ese tile que bloquee el paso
	var event_in_tile = grid.event_at(to)
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
	# Obtener MOSystem del contexto
	var overworld_context = _get_context()
	var mo_system: MOSystem = overworld_context.get_mo_system() if overworld_context else null

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
	# Obtener el jugador del contexto
	var overworld_context = _get_context()
	var player: Node = overworld_context.get_player() if overworld_context else null
	if not player:
		push_error("PushableRock: Player no disponible para auto-push")
		return

	# Obtener el grid de la jerarquía local
	var grid = _get_local_grid()
	if not grid:
		push_error("PushableRock: Grid no disponible para auto-push")
		return

	# Calcular dirección del empuje (jugador → roca)
	var push_direction = _calculate_push_direction_from_player(player)

	# Verificar restricciones direccionales del tile de la roca
	var rock_tile = grid.world_to_tile(global_position)

	# can_enter_tile espera la dirección del movimiento del jugador
	# Si push_direction es DOWN, el jugador se mueve hacia DOWN (hacia la roca)
	if not grid.can_enter_tile(rock_tile, push_direction):
		# El tile de la roca no permite entrar desde esa dirección
		# (por ejemplo, un ledge que bloquea subir)
		return

	# Bloquear el control del jugador durante el empuje
	if overworld_context:
		overworld_context.block_player_control()
	else:
		push_warning("PushableRock: OverworldContext no disponible para bloquear el control del jugador")

	# Empujar la roca
	await push(push_direction)

	# Desbloquear el control del jugador
	if overworld_context:
		overworld_context.unblock_player_control()
	else:
		push_warning("PushableRock: OverworldContext no disponible para desbloquear el control del jugador")

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

## ============================================================================
## CONTEXT HELPERS
## ============================================================================

## Establece el contexto del Overworld (llamado desde OverworldGrid)
func set_overworld_context(context: OverworldContext) -> void:
	overworld_context = context

## Helper para obtener el OverworldContext
func _get_context() -> OverworldContext:
	return overworld_context

## Obtiene el OverworldGrid de la jerarquía local del evento
func _get_local_grid() -> OverworldGrid:
	var events_container = get_parent()
	if events_container and events_container.name == "Events":
		var overgrid = events_container.get_parent()
		if overgrid is OverworldGrid:
			return overgrid
	return null
