extends Node
class_name GridMotion

signal step_started()
signal step_finished(tile: Vector2i)
signal direction_changed(new_direction: Vector2)
signal ledge_jump_started()
signal ledge_jump_finished()

## Duración base de un paso (en segundos)
@export var step_duration := 0.266
@export var initial_delay := 0.12  # tiempo que hay que mantener pulsado antes de moverse
@export var turn_duration := 0.133  # duración del giro en sitio (cuando no hay desplazamiento)
@export var ledge_jump_duration := 0.5  # duración del salto sobre un ledge (en segundos)
@export var ledge_jump_height := 12.0  # altura del arco del salto (en píxeles)

## Multiplicador de velocidad base (configurable por NPCs, Player usa 1.0)
@export var base_speed := 1.0

## Multiplicador de velocidad (1 = normal, 2 = correr, 0.5 = ralentizado…)
var speed_multiplier := 1.0

## Flag para indicar si el actor está corriendo (controlado externamente por Player o NPCs)
var is_running := false

## Flag para indicar que el movimiento está siendo controlado por un comando
## Cuando es true, el input del jugador no debe modificar is_running
var is_command_controlled := false

var hold_time:float
var moving := false
var dir := Vector2.DOWN
var previous_dir := dir
var initial_step := false
var stride_is_left := true
var is_jumping_ledge := false  # Flag para indicar que se está saltando un ledge

@onready var actor := get_parent() as Node2D
var grid: OverworldGrid
var active_tween: Tween = null  # Referencia al tween activo

## Referencia al OverworldContext (inyectada desde el actor padre)
var context: OverworldContext = null

## Referencia a MapSystem (obtenida del contexto)
var map_system: MapSystem = null

func _ready() -> void:
	# El contexto se inyectará desde el Player/NPC padre después de _ready()
	# NO intentar obtener MapSystem aquí - se hará cuando se reciba el contexto

	# Suscribirse a cambios de grid activo (la señal actualiza grid automáticamente)
	if SignalManager:
		SignalManager.active_grid_changed.connect(func(g): grid = g)
		print("GridMotion: Suscrito a active_grid_changed")

func get_step_duration() -> float:
	return step_duration / speed_multiplier

##Gets de speed scale that will be used to move and animate the actor when moving
func get_speed_multiplier(_d: Vector2, can_step: bool, is_initial_step: bool) -> float:
	var multiplier := base_speed

	# Aplicar boost de run si está activado (controlado externamente por Player/NPC)
	if (is_initial_step or is_running) and can_step and base_speed == 1.0:
		multiplier = 2.0

	if not can_step:
		multiplier = 0.5

	return multiplier


func current_tile() -> Vector2i:
	# Revalidar grid por si fue liberado tras un cambio de mapa
	if not grid or not is_instance_valid(grid):
		_refresh_grid()
		if not grid or not is_instance_valid(grid):
			push_error("GridMotion: OverworldGrid no disponible para calcular current_tile")
			assert(false)
			return Vector2i.ZERO
	return grid.world_to_tile(actor.global_position)

## Refresca la referencia al grid actual
## Nota: Obtiene el grid activo del MapSystem
func _refresh_grid() -> void:
	# Actualizar referencia a MapSystem si es necesario
	_update_map_system_reference()

	# Obtener grid del MapSystem
	if map_system:
		grid = map_system.get_active_grid()
	# Si no hay MapSystem todavía, simplemente no hacer nada
	# El grid se inicializará cuando se reciba el contexto

func _on_warp_finished(_map_id: String, _spawn_id: String) -> void:
	_refresh_grid()

## Intenta cruzar a un mapa vecino (seamless world)
## Retorna: {"success": bool, "from": Vector2i, "to": Vector2i}
func _try_seamless_crossing(from: Vector2i, to: Vector2i) -> Dictionary:
	# Verificar si el tile destino no existe en el grid actual
	var tile_data = grid.get_tile_data(to)
	if not tile_data.is_empty():
		return {"success": false, "from": from, "to": to}

	# El tile no existe en este grid, puede ser un mapa vecino
	var from_world_pos = actor.global_position
	var to_world_pos = grid.tile_to_world_center(to)

	# Consultar movimiento en mapas vecinos (MapSystem ya validado en _ready)
	var movement_result = map_system.check_world_movement(actor, from_world_pos, to_world_pos)
	if not movement_result["can_move"]:
		return {"success": false, "from": from, "to": to}

	var target_grid: OverworldGrid = movement_result["target_grid"]
	if not target_grid or target_grid == grid:
		return {"success": false, "from": from, "to": to}

	# Cruce exitoso: actualizar al nuevo grid
	var from_map_id = grid.get_parent().name
	var to_map_id = target_grid.get_parent().name

	# Emitir señal para que otros sistemas reaccionen (WorldSystem, Occupancy, etc.)
	# NOTA: WorldSystem emitirá active_grid_changed, que hará que Occupancy limpie
	# automáticamente la ocupación del grid anterior
	SignalManager.seamless_map_crossed.emit(from_map_id, to_map_id)

	# Actualizar al nuevo grid
	# IMPORTANTE: La limpieza de ocupación la hace Occupancy vía active_grid_changed
	grid = target_grid

	# Retornar coordenadas convertidas
	return {
		"success": true,
		"from": movement_result["from_tile"],
		"to": movement_result["to_tile"]
	}


## Detiene inmediatamente cualquier movimiento en curso (para warps)
func stop_movement() -> void:
	# Cancelar tween activo si existe
	if active_tween and active_tween.is_valid():
		active_tween.kill()
		active_tween = null
		print("GridMotion: Tween cancelado")

	# Resetear estado de movimiento
	moving = false
	hold_time = 0.0

	print("GridMotion: Movimiento detenido")

func face(d: Vector2) -> void:
	if d != Vector2.ZERO:
		self.previous_dir = dir
		self.dir = d
		# Emitir señal solo si realmente cambió la dirección
		if self.previous_dir != d:
			direction_changed.emit(d)

func try_step(d: Vector2) -> bool:
	# Revalidar grid antes de cualquier acceso (evita crash si se mantiene input durante warp)
	if not grid or not is_instance_valid(grid):
		_refresh_grid()
		if not grid or not is_instance_valid(grid):
			return false

	if moving or d == Vector2.ZERO:
		return false
	face(d)

	var from := current_tile()
	var to := from + Vector2i(d)

	# VERIFICAR PRIMERO: ¿El tile destino es un ledge? (Solo para jugadores)
	# El jugador está ENTRANDO al ledge, no está sobre él
	if actor.is_in_group("Player") and grid.can_jump_ledge(actor, to, d):
		# Para ledges, el salto es de 2 tiles en total desde la posición actual
		# landing_tile = from + 2 tiles
		var landing_tile := from + Vector2i(d) * 2
		# Ejecutar salto de ledge (desde from, pasando por to/ledge, hasta landing_tile)
		return await _execute_ledge_jump(from, landing_tile)

	# SEGUNDO: Intentar movimiento normal en el grid actual (99% de los casos)
	var can_step := grid.can_step_to(actor, from, to)

	# VALIDACIÓN ADICIONAL: Si el jugador está en modo surfing, verificar si puede ir al tile
	if can_step and actor.is_in_group("Player") and actor.has_method("can_surf_to_tile"):
		if not actor.can_surf_to_tile(to):
			can_step = false

	# SOLO si no se puede mover, verificar si es porque el tile está en otro mapa (seamless)
	if not can_step:
		var seamless_result = _try_seamless_crossing(from, to)
		if seamless_result["success"]:
			can_step = true
			from = seamless_result["from"]
			to = seamless_result["to"]
		else:
			# El Player no puede moverse: verificar si colisiona con un evento PLAYER_TOUCH
			_check_player_collision(to)

	self.initial_step = requires_initial_step(d)

	speed_multiplier = get_speed_multiplier(d, can_step, self.initial_step)
	step_started.emit()

	#If cannot move to next tile, or trying a first quick tap to another direction when idle, stay in same position
	if self.initial_step or !can_step:
		to = from

	moving = true
	grid.reserve(from, to, actor)

	var target := grid.tile_to_world_center(to)

	if to == from:
		await get_tree().create_timer(turn_duration if initial_step else get_step_duration()).timeout
	else:
		# if actor is Event:
		# 	# Desregistrar del tile anterior
		if actor is Event:
			# Registrar en el tile nuevo
			_update_event_registration(from, to)
		# 	grid.unregister_event(from, actor)
		active_tween = actor.create_tween()
		active_tween.tween_property(actor, "global_position", target, get_step_duration())
		grid.vacate(from, actor)
		await active_tween.finished
		active_tween = null
		# if actor is Event:
		# 	# Registrar en el tile nuevo
		# 	grid.register_event(to, actor)

	grid.commit(from, to, actor)
	moving = false
	self.initial_step = false

	step_finished.emit(to)

	# Solo llamar on_enter_tile si realmente nos movimos a un tile diferente
	if to != from:
		grid.on_enter_tile(actor, to)
		# Alternar la zancada únicamente cuando hubo desplazamiento real
	stride_is_left = not stride_is_left

	return true

func event_at_offset(offset: int = 1) -> Event:
	# offset = 1 → el tile de delante
	# offset = 2 → dos tiles más adelante
	# offset = -1 → el tile de detrás
	var target_tile = current_tile() + Vector2i(dir) * offset
	return grid.event_at(target_tile)

func event_in_front() -> Event:
	return event_at_offset(1)

##Checks if actor need to do the first step animation before moving
func requires_initial_step(direction: Vector2) -> bool:
	return (direction != previous_dir and self.hold_time < initial_delay)

## Actualiza el registro de eventos en el grid cuando se mueve un Event
func _update_event_registration(from_tile: Vector2i, to_tile: Vector2i) -> void:
	if not grid:
		return

	# Desregistrar del tile anterior
	grid.unregister_event(from_tile, actor)

	# Registrar en el tile nuevo
	grid.register_event(to_tile, actor)

	#print("GridMotion: Event movido de tile ", from_tile, " a ", to_tile)

## Verifica si el Player colisionó con un evento de tipo PLAYER_TOUCH
func _check_player_collision(target_tile: Vector2i) -> void:
	# Solo verificar para el Player
	if not actor.is_in_group("Player"):
		return

	# Obtener la posición mundial del tile destino
	var target_world_pos = grid.tile_to_world_center(target_tile)

	# Buscar evento en todos los grids (importante para seamless world)
	var event: Event = null
	# NOTA: Para seamless world necesitamos buscar en múltiples grids
	# Esto es una de las pocas excepciones donde get_nodes_in_group es necesario
	var grids = get_tree().get_nodes_in_group("OverworldGrid")

	for g in grids:
		var grid_node = g as OverworldGrid
		if not grid_node:
			continue

		# Convertir posición mundial a tile de este grid
		var tile_in_grid = grid_node.world_to_tile(target_world_pos)
		var event_in_grid = grid_node.event_at(tile_in_grid)

		if event_in_grid:
			event = event_in_grid
			break

	if not event:
		return

	if event.has_method("on_player_collision"):
		event.on_player_collision()

# --- Sistema de Saltos (Ledges) - PBI 455 ---
## Ejecuta un salto sobre un ledge (método interno)
## @param from: Tile de origen
## @param to: Tile de destino (2 tiles adelante)
## @return bool: siempre true (el salto se ejecuta)
func _execute_ledge_jump(from: Vector2i, to: Vector2i) -> bool:
	# Emitir señal de inicio de salto
	is_jumping_ledge = true
	ledge_jump_started.emit()

	# Bloquear el control del jugador durante el salto
	SignalManager.player_control_blocked.emit()

	moving = true
	grid.reserve(from, to, actor)

	# Calcular posición de destino
	var target := grid.tile_to_world_center(to)

	# Vaciar el tile de origen
	grid.vacate(from, actor)

	# Actualizar registro si es un evento (aunque los eventos no deberían llegar aquí)
	if actor is Event:
		_update_event_registration(from, to)

	# Obtener el sprite del actor para animar el arco
	var sprite_node: Node = null
	if actor.has_node("AnimatedSprite2D"):
		sprite_node = actor.get_node("AnimatedSprite2D")

	var original_y_offset = 0.0
	if sprite_node:
		original_y_offset = sprite_node.offset.y

	# Obtener la sombra del jugador (si existe)
	var shadow_node: Sprite2D = null
	if actor.has_node("Shadow"):
		shadow_node = actor.get_node("Shadow") as Sprite2D
		if shadow_node:
			shadow_node.visible = true  # Mostrar sombra durante el salto

	# PRIMER PASO: Emitir step_started para iniciar la animación
	step_started.emit()
	# Alternar la zancada para el siguiente paso
	stride_is_left = not stride_is_left

	# Crear el tween para el salto con animación suave
	active_tween = actor.create_tween()
	active_tween.set_parallel(true)

	# Movimiento horizontal/vertical principal
	active_tween.tween_property(actor, "global_position", target, ledge_jump_duration)\
		.set_ease(Tween.EASE_IN_OUT)\
		.set_trans(Tween.TRANS_QUAD)

	# Animación del arco del salto (usando offset del sprite)
	if sprite_node:
		# Subir primero (primera mitad del salto)
		active_tween.tween_property(sprite_node, "offset:y", original_y_offset-ledge_jump_height, ledge_jump_duration / 2.0)\
			.set_ease(Tween.EASE_OUT)\
			.set_trans(Tween.TRANS_QUAD)

		# Bajar después (segunda mitad del salto)
		active_tween.tween_property(sprite_node, "offset:y", original_y_offset, ledge_jump_duration / 2.0)\
			.set_delay(ledge_jump_duration / 2.0)\
			.set_ease(Tween.EASE_IN)\
			.set_trans(Tween.TRANS_QUAD)

	# Esperar a la mitad del salto para emitir el SEGUNDO PASO
	await get_tree().create_timer(ledge_jump_duration / 2.0).timeout
	step_started.emit()
	# Alternar la zancada de nuevo para el siguiente movimiento después del salto
	stride_is_left = not stride_is_left

	# Esperar a que termine el resto del tween
	await active_tween.finished
	active_tween = null

	# Asegurar que el offset vuelve al valor original (por si hubo algún problema)
	if sprite_node:
		sprite_node.offset.y = original_y_offset

	# Ocultar la sombra al finalizar el salto
	if shadow_node:
		shadow_node.visible = false

	# Confirmar el movimiento
	grid.commit(from, to, actor)
	moving = false
	is_jumping_ledge = false

	# Desbloquear el control del jugador
	SignalManager.player_control_unblocked.emit()

	# Emitir señales de finalización
	ledge_jump_finished.emit()
	step_finished.emit(to)

	# Llamar a on_enter_tile para triggers
	grid.on_enter_tile(actor, to)

	# NO alternar la zancada aquí porque ya se hizo durante el salto (2 veces)

	return true

## ============================================================================
## CONTEXT MANAGEMENT
## ============================================================================

## Actualiza la referencia a MapSystem desde el contexto
func _update_map_system_reference() -> void:
	# Si ya tenemos MapSystem, no hacer nada
	if map_system:
		return

	# Obtener del contexto si está disponible
	if not context:
		# No es un error - simplemente el contexto aún no se ha inyectado
		return

	map_system = context.get_map_system()
	if not map_system:
		push_error("GridMotion: MapSystem no disponible en el contexto")

## Establece el contexto del Overworld (llamado desde el actor padre)
func set_context(overworld_context: OverworldContext) -> void:
	context = overworld_context
	_update_map_system_reference()

	# Inicializar grid ahora que tenemos el contexto
	_refresh_grid()

	print("GridMotion: Contexto establecido, grid inicializado: %s" % ("OK" if grid else "FAIL"))
