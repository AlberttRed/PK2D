extends Node
class_name GridMotion

signal step_started()
signal step_finished(tile: Vector2i)

## Duración base de un paso (en segundos)
@export var step_duration := 0.266
@export var initial_delay := 0.12  # tiempo que hay que mantener pulsado antes de moverse
@export var turn_duration := 0.133  # duración del giro en sitio (cuando no hay desplazamiento)

## Multiplicador de velocidad base (configurable por NPCs, Player usa 1.0)
@export var base_speed := 1.0

## Multiplicador de velocidad (1 = normal, 2 = correr, 0.5 = ralentizado…)
var speed_multiplier := 1.0

## Flag para indicar si el actor está corriendo (controlado externamente por Player o NPCs)
var is_running := false

var hold_time:float
var moving := false
var dir := Vector2.DOWN
var previous_dir := dir
var initial_step := false
var stride_is_left := true

@onready var actor := get_parent() as Node2D
var grid: OverworldGrid
var active_tween: Tween = null  # Referencia al tween activo

## Referencia a MapSystem (inicializada en _ready, crítica para seamless world)
var map_system: MapSystem = null

func _ready() -> void:
	# Inicializar MapSystem (crítico para seamless world)
	map_system = get_tree().get_first_node_in_group("MapSystem") as MapSystem
	if not map_system:
		push_error("GridMotion: MapSystem no encontrado - el sistema seamless no funcionará")
	
	# Suscribirse a cambios de grid activo publicados por MapSystem
	if SignalManager:
		SignalManager.active_grid_changed.connect(func(g): grid = g)
		# Inicializar con el grid activo si ya existe (usar MapSystem ya cargado)
		if map_system:
			grid = map_system.get_active_grid()

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

## Refresca la referencia al grid actual (con cache para evitar búsquedas repetidas)
## Nota: Se usa get_first_node_in_group en lugar de señales porque current_tile()
## es consultado frecuentemente (hot path) y necesita respuesta síncrona
func _refresh_grid() -> void:
	grid = get_tree().get_first_node_in_group("OverworldGrid") as OverworldGrid

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
	
	# PRIMERO: Intentar movimiento normal en el grid actual (99% de los casos)
	var can_step := grid.can_step_to(actor, from, to)
	
	# SOLO si no se puede mover, verificar si es porque el tile está en otro mapa (seamless)
	if not can_step:
		var seamless_result = _try_seamless_crossing(from, to)
		if seamless_result["success"]:
			can_step = true
			from = seamless_result["from"]
			to = seamless_result["to"]
	
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
		active_tween = actor.create_tween()
		active_tween.tween_property(actor, "global_position", target, get_step_duration())
		grid.vacate(from, actor)
		await active_tween.finished
		active_tween = null

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
