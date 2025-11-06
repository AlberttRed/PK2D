extends Node
class_name Occupancy

@onready var actor := get_parent() as Node2D
var grid: OverworldGrid
var previous_grid: OverworldGrid = null  # Para limpiar al cambiar de mapa

## Para EVENTOS: grid nativo donde pertenecen (no cambia con active_grid)
## Para PLAYER: null (usa siempre el grid activo)
var home_grid: OverworldGrid = null

## Referencia al OverworldContext (inyectada desde el actor padre)
var context: OverworldContext = null

func _ready() -> void:
	# EVENTOS: Obtener su grid nativo (del mapa donde están)
	if actor is Event:
		# Buscar el OverworldGrid en la jerarquía: Event → Events → OverworldGrid
		var events_container = actor.get_parent()
		if events_container and events_container.name == "Events":
			var overgrid = events_container.get_parent()
			if overgrid is OverworldGrid:
				grid = overgrid
				home_grid = overgrid  # Guardar como nativo

		# Registrar ocupación inicial para eventos
		if grid:
			var tile := grid.world_to_tile(actor.global_position)
			grid.register_event(tile, actor)
			# Para eventos, esperar a que se configure current_page
			call_deferred("register_event_occupancy", tile)
	# PLAYER: Se inicializará cuando reciba el contexto (en set_context)

	# Suscribirse a cambios de grid activo publicados por MapSystem
	SignalManager.active_grid_changed.connect(_on_grid_changed)

func current_tile() -> Vector2i:
	if not grid or not is_instance_valid(grid):
		push_error("Occupancy: grid inválido en current_tile()")
		assert(false)
		return Vector2i.ZERO
	return grid.world_to_tile(actor.global_position)

## Registra la ocupación del evento después de que se haya configurado current_page
func register_event_occupancy(tile: Vector2i) -> void:
	if actor is Event:
		# Registrar en occ solo si NO es through (bloquea el paso)
		if not actor.current_page or not actor.current_page.through:
			grid.occupy(tile, actor)

## Si en algún momento teletransportas:
## Maneja el cambio de grid activo (limpia ocupación del grid anterior)
func _on_grid_changed(new_grid: OverworldGrid) -> void:
	# EVENTOS: Solo responden si el nuevo grid es su grid nativo
	if actor is Event:
		if new_grid != home_grid:
			return  # Ignorar cambios de grids de otros mapas

	# SOLO limpiar si realmente cambió de grid (evita borrar eventos al inicializar)
	if grid and new_grid and grid != new_grid and is_instance_valid(grid):
		var old_tile = grid.world_to_tile(actor.global_position)

		if actor is Event:
			grid.unregister_event(old_tile, actor)
			if not actor.current_page or not actor.current_page.through:
				grid.vacate(old_tile, actor)
		else:
			grid.vacate(old_tile, actor)

	# Actualizar al nuevo grid
	previous_grid = grid
	grid = new_grid

	# Re-registrar en el nuevo grid
	if grid and is_instance_valid(grid):
		var tile_pos = grid.world_to_tile(actor.global_position)

		if actor is Event:
			# Re-registrar evento
			grid.register_event(tile_pos, actor)

			# Re-registrar ocupación si no es through
			if not actor.current_page or not actor.current_page.through:
				grid.occupy(tile_pos, actor)
		else:
			# Re-registrar actor normal (player se maneja vía GridMotion.commit)
			# No ocupamos aquí para evitar duplicados
			pass


func teleport_to_tile(t: Vector2i) -> void:
	if not grid or not is_instance_valid(grid):
		push_error("Occupancy: grid inválido en teleport_to_tile()")
		assert(false)
		return
	var cur := grid.world_to_tile(actor.global_position)
	# Limpiar registros previos del grid ACTUAL
	if actor is Event:
		grid.unregister_event(cur, actor)
		if not actor.current_page or not actor.current_page.through:
			grid.vacate(cur, actor)
	else:
		grid.vacate(cur, actor)

	# Reubicar
	actor.global_position = grid.tile_to_world_center(t)

	# Registrar de nuevo
	if actor is Event:
		grid.register_event(t, actor)
		if not actor.current_page or not actor.current_page.through:
			grid.occupy(t, actor)
	else:
		grid.occupy(t, actor)


## Actualiza el registro de ocupación en el grid según el estado actual del actor
## Se llama cuando cambia la página activa de un evento (y cambia su propiedad through)
func refresh_occupancy() -> void:
	if not actor is Event:
		return  # Solo eventos tienen páginas con through

	if not grid or not is_instance_valid(grid):
		return

	var tile = grid.world_to_tile(actor.global_position)
	var is_through = actor.current_page and actor.current_page.through
	var is_occupied = grid.has_actor(tile) and grid.occ[tile].get_ref() == actor

	# Si debe ser "through" pero está ocupando, liberar el tile
	if is_through and is_occupied:
		grid.vacate(tile, actor)
		print("Occupancy: Evento '%s' ahora es through (liberando tile %s)" % [actor.name, tile])

	# Si NO debe ser "through" pero no está ocupando, ocupar el tile
	elif not is_through and not is_occupied:
		grid.occupy(tile, actor)
		print("Occupancy: Evento '%s' ya no es through (ocupando tile %s)" % [actor.name, tile])

# Ya no necesitamos escuchar warp_finished; el grid se actualiza vía active_grid_changed

## ============================================================================
## CONTEXT MANAGEMENT
## ============================================================================

## Establece el contexto del Overworld (llamado desde el actor padre)
func set_context(overworld_context: OverworldContext) -> void:
	context = overworld_context

	# Inicializar grid para Player/NPCs cuando se recibe el contexto
	if not actor is Event and not grid:
		_initialize_player_grid()

## Inicializa el grid para Player/NPCs usando el contexto
func _initialize_player_grid() -> void:
	if not context:
		push_error("Occupancy: Contexto no disponible para inicializar grid")
		return

	var map_system: MapSystem = context.get_map_system()
	if not map_system:
		push_error("Occupancy: MapSystem no disponible en el contexto")
		return

	grid = map_system.get_active_grid()
	if not grid:
		push_error("Occupancy: No se pudo obtener el OverworldGrid del MapSystem")
		return

	previous_grid = grid  # Inicializar para evitar null en primer cruce

	# Registrar ocupación inicial
	var tile := grid.world_to_tile(actor.global_position)
	grid.occupy(tile, actor)

	print("Occupancy: Grid inicializado para %s en tile %s" % [actor.name, tile])
