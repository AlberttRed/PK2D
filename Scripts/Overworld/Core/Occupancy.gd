extends Node
class_name Occupancy

@onready var actor := get_parent() as Node2D
var grid: OverworldGrid
var previous_grid: OverworldGrid = null  # Para limpiar al cambiar de mapa

## Para EVENTOS: grid nativo donde pertenecen (no cambia con active_grid)
## Para PLAYER: null (usa siempre el grid activo)
var home_grid: OverworldGrid = null

func _ready() -> void:
	# EVENTOS: Obtener su grid nativo (del mapa donde están)
	# PLAYER: Obtener grid activo
	if actor is Event:
		# Buscar el OverworldGrid en la jerarquía: Event → Events → OverworldGrid
		var events_container = actor.get_parent()
		if events_container and events_container.name == "Events":
			var overgrid = events_container.get_parent()
			if overgrid is OverworldGrid:
				grid = overgrid
				home_grid = overgrid  # Guardar como nativo
	else:
		# PLAYER u otros actores: Obtener grid activo del MapSystem
		var map_system: MapSystem = get_tree().get_first_node_in_group("MapSystem")
		if not map_system:
			push_error("Occupancy: No se encontró el MapSystem en la escena")
			return
		
		grid = map_system.get_active_grid()
		if not grid:
			push_error("Occupancy: No se pudo obtener el OverworldGrid del MapSystem")
			return
	

	# Suscribirse a cambios de grid activo publicados por MapSystem
	SignalManager.active_grid_changed.connect(_on_grid_changed)
	
	# SOLO PLAYER actualiza grid al activo
	# Eventos mantienen su grid nativo siempre
	if actor is Event:
		previous_grid = home_grid  # Para eventos, previous = home
	else:
		# Player: Inicializar con el grid activo si ya existe
		var ms: MapSystem = get_tree().get_first_node_in_group("MapSystem")
		if ms:
			var active_grid = ms.get_active_grid()
			if active_grid:
				grid = active_grid
			previous_grid = grid  # Inicializar para evitar null en primer cruce
	
	# Snap al centro de tile y registra ocupación inicial
	var tile := grid.world_to_tile(actor.global_position)
	#actor.global_position = grid.tile_to_world_center(tile)
	if actor is Event:
		# Registrar siempre en events
		grid.register_event(tile, actor)

		# Para eventos, esperar a que se configure current_page
		call_deferred("register_event_occupancy", tile)
	else:
		# Cualquier otro actor (Player, NPC, etc.)
		grid.occupy(tile, actor)

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

# Ya no necesitamos escuchar warp_finished; el grid se actualiza vía active_grid_changed
