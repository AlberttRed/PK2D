extends Node
class_name WarpSystem

## WarpSystem - Sistema global para gestionar cambios de mapa/posición
## Utiliza OverworldContext para acceder a otros sistemas sin acoplamiento

signal warp_started(map_id: String, tile_pos: Vector2i)
signal warp_finished(map_id: String, tile_pos: Vector2i)

# Referencia al OverworldContext (inyectada desde OverworldCoordinator)
var context: OverworldContext = null

# Referencias a otros sistemas (inyectadas desde OverworldCoordinator)
# DEPRECATED: Usar context.get_X_system() en su lugar
# Se mantienen temporalmente para compatibilidad
var world_system: WorldSystem = null

# Variables del estado actual
var is_warping: bool = false
var current_map_id: String = ""
var current_tile_pos: Vector2i = Vector2i.ZERO

func _ready() -> void:
	pass  # NOTA: El contexto se inyecta desde OverworldCoordinator después de _ready()
	# Se validará cuando se use, no aquí

## Actualiza las referencias a otros sistemas desde el contexto
## DEPRECATED: Este método solo sirve para obtener el contexto del coordinador como fallback inicial
func _update_references() -> void:
	# Intentar obtener el contexto del coordinador si no está disponible
	if not context:
		var coordinator = get_parent() as OverworldCoordinator
		if coordinator and coordinator.has_method("get_context"):
			context = coordinator.get_context()
			if context:
				print("WarpSystem: Contexto obtenido del coordinador")
		else:
			push_error("WarpSystem: Contexto no disponible y no se puede obtener del coordinador")

## Método público para solicitar un warp a coordenadas de tile específicas
func request_warp(map_id: String, tile_pos: Vector2i) -> void:
	print("WarpSystem: Solicitud de warp recibida - Mapa: ", map_id, ", Tile: ", tile_pos)

	if is_warping:
		push_warning("WarpSystem: Ya hay un warp en progreso, esperando a que finalice")
		await self.warp_finished
		return

	# Emitir señal de inicio local
	warp_started.emit(map_id, tile_pos)

	# Ejecutar el cambio de mapa/posición usando tile
	await _execute_warp(map_id, tile_pos)

	# Esperar a que la señal de finalización sea emitida
	if is_warping:
		await self.warp_finished


## Ejecuta el cambio de mapa/posición usando coordenadas de tile
func _execute_warp(map_id: String, tile_pos: Vector2i) -> void:
	print("WarpSystem: Ejecutando warp - Mapa: ", map_id, ", Tile: ", tile_pos)

	is_warping = true

	# 0. CRÍTICO: Detener completamente cualquier movimiento en curso
	if not context:
		push_error("WarpSystem: Contexto no disponible en _execute_warp")
		is_warping = false
		return

	var player: Node = context.get_player()

	if player and player.has_node("GridMotion"):
		var motion = player.get_node("GridMotion")
		if motion:
			# Si está en movimiento, esperar que termine
			if motion.moving:
				print("WarpSystem: Esperando a que termine el paso actual...")
				await motion.step_finished
				print("WarpSystem: Paso completado")

			# Detener completamente el movimiento (cancela tweens, resetea estado)
			if motion.has_method("stop_movement"):
				motion.stop_movement()

			print("WarpSystem: Movimiento detenido, continuando warp")

	# 1. Obtener referencias de sistemas del contexto
	var ws: WorldSystem = null

	if context:
		ws = context.get_world_system()
	else:
		# Fallback temporal: actualizar referencias
		_update_references()
		ws = world_system

	# Verificar que tenemos las referencias necesarias
	if not ws:
		push_error("WarpSystem: No se pudo obtener el WorldSystem")
		is_warping = false
		return

	# 2. Verificar si necesitamos cambiar de mapa
	var current_map = ws.get_active_map()
	var needs_map_change = not current_map or current_map.name != map_id

	if needs_map_change:
		print("WarpSystem: Cambiando de mapa a través de WorldSystem: ", map_id)

		# Usar warp_with_state_management
		if ws.has_method("warp_with_state_management"):
			var success = await ws.warp_with_state_management(map_id, tile_pos)
			if not success:
				push_error("WarpSystem: No se pudo cambiar al mapa con gestión de estado: " + map_id)
				is_warping = false
				return

			# Verificar eventos TOUCH en la nueva posición
			var active_grid = ws.get_active_grid()
			if active_grid:
				_check_touch_events_at_player_position(active_grid)

			# Si el warp con gestión de estado se completó, salir temprano
			_emit_warp_finished(map_id, tile_pos)
			return
		else:
			# Fallback al método tradicional
			var success = ws.change_to_map(map_id)
			if not success:
				push_error("WarpSystem: No se pudo cambiar al mapa: " + map_id)
				is_warping = false
				return

	# 3. Posicionar al jugador en la coordenada de tile
	print("WarpSystem: Posicionando jugador en tile: ", tile_pos)
	var grid = ws.get_active_grid()
	if not grid:
		push_error("WarpSystem: No se pudo obtener el OverworldGrid del mapa activo")
		is_warping = false
		return

	# Posicionar usando teleport_to_tile o fallback
	if player.has_method("teleport_to_tile"):
		player.teleport_to_tile(tile_pos)
	else:
		player.global_position = grid.tile_to_world_center(tile_pos)

	# Inicializar chunks activos con la nueva posición del jugador
	var chunk_controller = ws.chunk_controller if ws else null
	if chunk_controller:
		chunk_controller.initialize_active_chunks.call_deferred(player.global_position)

	# 4. Verificar si hay un evento TOUCH en la posición del jugador
	_check_touch_events_at_player_position(grid)

	# 5. Actualizar estado interno
	current_map_id = map_id
	current_tile_pos = tile_pos

	# Emitir warp_finished de forma diferida
	call_deferred("_emit_warp_finished", map_id, tile_pos)
	return


## Emisión diferida de warp_finished para evitar carreras con await en comandos
func _emit_warp_finished(map_id: String, tile_pos: Vector2i) -> void:
	# Marcar que ya no estamos warpeando justo antes de emitir
	is_warping = false
	warp_finished.emit(map_id, tile_pos)
	print("WarpSystem: Warp completado - Mapa: ", map_id, ", Tile: ", tile_pos)

## Obtiene información del estado actual
func get_current_warp_info() -> Dictionary:
	return {
		"map_id": current_map_id,
		"tile_pos": current_tile_pos,
		"is_warping": is_warping
	}

## Verifica si el sistema está listo para realizar warps
func is_ready() -> bool:
	# Si tenemos contexto, verificar con él
	if context:
		return not is_warping and context.get_world_system() != null

	# Fallback temporal: actualizar referencias
	_update_references()
	return not is_warping and world_system != null

## Verifica si hay eventos con trigger TOUCH en la posición del jugador tras un warp
func _check_touch_events_at_player_position(grid: Node) -> void:
	if not context:
		push_error("WarpSystem: Contexto no disponible en _check_touch_events")
		return

	var player: Node = context.get_player()
	if not player:
		push_error("WarpSystem: Player no disponible en el contexto")
		return

	# Obtener la tile del jugador
	var player_tile = grid.world_to_tile(player.global_position)

	# Usar el método event_at del grid para buscar el evento en esa tile
	var event = grid.event_at(player_tile)
	if event and event.has_method("on_player_touch"):
		# Llamar al evento con un frame de delay para que el warp termine primero
		call_deferred("_trigger_event_touch", event)

## Activa un evento TOUCH de forma diferida
func _trigger_event_touch(event: Event) -> void:
	if event and event.has_method("on_player_touch"):
		print("WarpSystem: Activando evento TOUCH '%s' en posición del jugador" % event.name)
		event.on_player_touch()

func set_context(overworld_context: OverworldContext) -> void:
	context = overworld_context
