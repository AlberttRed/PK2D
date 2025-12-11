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

## Referencia a WorldSystem (obtenida del contexto)
var world_system: WorldSystem = null

func _ready() -> void:
	# Configurar para que los Tweens continúen aunque el árbol esté pausado
	# Esto permite que las animaciones de movimiento continúen durante pausas de MO
	process_mode = Node.PROCESS_MODE_ALWAYS
	# El contexto se inyectará desde el Player/NPC padre después de _ready()
	# NO intentar obtener WorldSystem aquí - se hará cuando se reciba el contexto

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
## Nota: Para eventos (NPCs), usa su home_grid. Para Player, usa el grid activo.
func _refresh_grid() -> void:
	# Para eventos (NPCs), usar su home_grid en lugar del grid activo
	if actor is Event:
		var occupancy = actor.get_node_or_null("Occupancy")
		if occupancy and occupancy.home_grid:
			grid = occupancy.home_grid
			return

	# Para Player, obtener el grid activo del WorldSystem
	_update_world_system_reference()
	if world_system:
		grid = world_system.get_active_grid()
	# Si no hay WorldSystem todavía, simplemente no hacer nada
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

	# Consultar movimiento en mapas vecinos (WorldSystem ya validado en _ready)
	var movement_result = world_system.check_world_movement(actor, from_world_pos, to_world_pos)
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
	if context:
		context.emit_seamless_map_crossed(from_map_id, to_map_id)

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

	# Calcular si es un initial step ANTES de verificar lógica especial (surf, seamless crossing)
	# Esto evita ejecutar animaciones cuando solo se está girando sin moverse
	self.initial_step = requires_initial_step(d)

	# Si es un initial step (solo giro sin movimiento), no ejecutar lógica especial
	if self.initial_step:
		# Giro simple sin movimiento, no verificar surf ni seamless crossing
		speed_multiplier = get_speed_multiplier(d, false, self.initial_step)
		step_started.emit()
		to = from
		moving = true
		grid.reserve(from, to, actor)
		await get_tree().create_timer(turn_duration).timeout
		grid.commit(from, to, actor)
		moving = false
		self.initial_step = false
		step_finished.emit(to)
		return true

	# SEGUNDO: Intentar movimiento normal en el grid actual (99% de los casos)
	var can_step := grid.can_step_to(actor, from, to)

	# VALIDACIÓN ADICIONAL: Si el jugador está en modo surfing, verificar si puede ir al tile
	# Solo se ejecuta si realmente va a moverse (no es initial_step)
	if can_step and actor.is_in_group("Player") and actor.has_method("can_surf_to_tile"):
		if not actor.can_surf_to_tile(to):
			# Si retorna false, puede ser porque necesita ejecutar end_surf() primero
			# Verificar si tiene el método para ejecutarlo
			if actor.has_method("_execute_end_surf_before_move"):
				await actor._execute_end_surf_before_move(to)
				# Después de end_surf(), el movimiento ya se ejecutó, así que retornar
				return true
			can_step = false

	# SOLO si no se puede mover, verificar si es porque el tile está en otro mapa (seamless)
	# Solo se ejecuta si realmente va a moverse (no es initial_step)
	if not can_step:
		var seamless_result = _try_seamless_crossing(from, to)
		if seamless_result["success"]:
			can_step = true
			from = seamless_result["from"]
			to = seamless_result["to"]
		else:
			# El Player no puede moverse: verificar si colisiona con un evento PLAYER_TOUCH
			_check_player_collision(to)

	speed_multiplier = get_speed_multiplier(d, can_step, self.initial_step)
	step_started.emit()

	#If cannot move to next tile, stay in same position
	if !can_step:
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
	# Usamos WorldSystem que tiene acceso a todos los mapas renderizados
	if not world_system:
		_update_world_system_reference()

	if world_system:
		# Iterar por todos los hijos de WorldSystem (mapas renderizados)
		for child in world_system.get_children():
			if child.is_in_group("Player"):
				continue

			var grid_node = child.get_node_or_null("OverworldGrid") as OverworldGrid
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

## Ejecuta un salto genérico hacia el tile indicado con la animación de arco usada en los ledges.
func jump_to_tile(target_tile: Vector2i, show_shadow: bool = true, final_y_offset: int = 0) -> bool:
	if not grid or not is_instance_valid(grid):
		_refresh_grid()
		if not grid or not is_instance_valid(grid):
			return false

	var from_tile := current_tile()
	if from_tile == target_tile:
		return true

	return await _perform_arc_jump(from_tile, target_tile, show_shadow, final_y_offset)

## Ejecuta un salto sobre un ledge (método interno legado)
func _execute_ledge_jump(from: Vector2i, to: Vector2i) -> bool:
	context.block_player_control()
	is_jumping_ledge = true
	ledge_jump_started.emit()
	var succeeded:bool = await _perform_arc_jump(from, to, true)
	is_jumping_ledge = false
	ledge_jump_finished.emit()
	context.unblock_player_control()
	step_finished.emit(to)
	return succeeded

func _perform_arc_jump(
	from: Vector2i,
	to: Vector2i,
	show_shadow: bool,
	final_y_offset: int = -8,
	duration: float = ledge_jump_duration,
	height: float = ledge_jump_height
) -> bool:
	moving = true
	grid.reserve(from, to, actor)

	var target := grid.tile_to_world_center(to)
	grid.vacate(from, actor)

	if actor is Event:
		_update_event_registration(from, to)

	var sprite_node: AnimatedSprite2D = null
	if actor.has_node("AnimatedSprite2D"):
		sprite_node = actor.get_node("AnimatedSprite2D") as AnimatedSprite2D

	var original_y_offset := 0.0
	if sprite_node:
		original_y_offset = sprite_node.offset.y

	if show_shadow and actor.has_node("Shadow"):
		actor.get_node("Shadow").visible = true

	if is_jumping_ledge:
		step_started.emit()
		stride_is_left = not stride_is_left

	active_tween = actor.create_tween()
	active_tween.set_parallel(true)
	active_tween.tween_property(actor, "global_position", target, duration)\
		.set_ease(Tween.EASE_IN_OUT)\
		.set_trans(Tween.TRANS_QUAD)

	if sprite_node:
		var half_duration := duration / 2.0
		active_tween.tween_property(sprite_node, "offset:y", original_y_offset - height, half_duration)\
			.set_ease(Tween.EASE_OUT)\
			.set_trans(Tween.TRANS_QUAD)

		active_tween.tween_property(sprite_node, "offset:y", final_y_offset, half_duration)\
			.set_delay(half_duration)\
			.set_ease(Tween.EASE_IN)\
			.set_trans(Tween.TRANS_QUAD)

	var wait_time: float = max(duration / 2.0, 0.01)
	await get_tree().create_timer(wait_time).timeout

	if is_jumping_ledge:
		step_started.emit()
		stride_is_left = not stride_is_left

	await active_tween.finished
	active_tween = null

	if sprite_node:
		sprite_node.offset.y = final_y_offset

	if actor.has_node("Shadow"):
		actor.get_node("Shadow").visible = false

	grid.commit(from, to, actor)
	moving = false

	grid.on_enter_tile(actor, to)

	return true

## ============================================================================
## CONTEXT MANAGEMENT
## ============================================================================

## Actualiza la referencia a WorldSystem desde el contexto
func _update_world_system_reference() -> void:
	# Si ya tenemos WorldSystem, no hacer nada
	if world_system:
		return

	# Obtener del contexto si está disponible
	if not context:
		# No es un error - simplemente el contexto aún no se ha inyectado
		return

	world_system = context.get_world_system()
	if not world_system:
		push_error("GridMotion: WorldSystem no disponible en el contexto")

## Establece el contexto del Overworld (llamado desde el actor padre)
func set_context(overworld_context: OverworldContext) -> void:
	context = overworld_context
	_update_world_system_reference()

	# Solo conectar a active_grid_changed si es el Player
	# Los eventos (NPCs) no deben cambiar su grid cuando cambia el mapa activo
	if not actor is Event:
		if context and not context.active_grid_changed.is_connected(_on_active_grid_changed):
			context.active_grid_changed.connect(_on_active_grid_changed)

	_refresh_grid()

func _on_active_grid_changed(new_grid: OverworldGrid) -> void:
	# Los eventos (NPCs) no deben cambiar su grid cuando cambia el mapa activo
	# Solo el Player debe usar el grid activo
	if actor is Event:
		return  # Mantener su home_grid

	# Solo el Player actualiza su grid al grid activo
	grid = new_grid
