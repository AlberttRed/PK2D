extends Node2D
class_name MapSystem

## Sistema de gestión de mapas para el overworld
## Se encarga de controlar el mapa activo y mantener al jugador como entidad persistente

var active_map: Node = null
var player: Node = null
var previous_map: Node = null

## Referencia al OverworldContext (inyectada desde OverworldCoordinator)
var context: OverworldContext = null

## Referencia al WorldSystem (inyectada desde OverworldCoordinator)
## DEPRECATED: Usar context.get_world_system() en su lugar
## Se mantiene temporalmente para compatibilidad
var world_system: WorldSystem = null

# NOTA: La gestión de escenas de mapa ahora es responsabilidad del WorldSystem
# El MapSystem se enfoca únicamente en el mapa activo y el jugador

func _enter_tree() -> void:
	# Verificar si ya hay un mapa configurado
	var map_scene = get_node_or_null("MapScene")
	if map_scene:
		set_active_map(map_scene)
		print("MapSystem: Mapa predefinido encontrado y configurado")
	else:
		print("MapSystem: No hay mapa predefinido - se cargará dinámicamente")

func _ready() -> void:
	# El Player se cargará dinámicamente desde load_player()
	# No buscar player aquí - se inyectará desde el contexto cuando esté disponible
	print("MapSystem: Inicialización completada")
	# NOTA: El contexto se inyecta desde OverworldCoordinator después de _ready()
	# y el Player se registrará en el contexto cuando se cargue dinámicamente

## DEPRECATED: Usar OverworldCoordinator.configure_from_gamestate() en su lugar
## Este método permanece por compatibilidad temporal pero será eliminado
##
## PROBLEMA: Este método hace orquestación de alto nivel (cambiar mapa, cargar jugador, posicionar)
## que debería estar en OverworldCoordinator, no en MapSystem.
##
## Flujo correcto:
## GameStart → OverworldCoordinator.configure_from_gamestate()
##   └→ Orquesta WorldSystem, MapSystem y OverworldGrid
func configure_player_from_gamestate() -> void:
	push_warning("MapSystem.configure_player_from_gamestate() está DEPRECATED. Usar OverworldCoordinator.configure_from_gamestate()")

	# Obtener datos del GameStateService
	var map_id = GameStateService.get_current_map_id()
	var player_position = GameStateService.get_current_position()
	var facing_dir = GameStateService.get_facing_direction()

	print("MapSystem: Configurando jugador desde GameState - Mapa: %s, Posición: %s, Dirección: %s" % [map_id, player_position, facing_dir])

	# Cargar el mapa si no existe o es diferente
	if !active_map or active_map.name != map_id:
		print("MapSystem: Cargando mapa según GameState...")
		var success = change_to_map(map_id)
		if not success:
			push_error("MapSystem: No se pudo cargar el mapa del GameState: " + map_id)
			return

	# Cargar el jugador si no existe
	if not player:
		print("MapSystem: Cargando jugador dinámicamente...")
		var success = load_player()
		if not success:
			push_error("MapSystem: No se pudo cargar el jugador")
			return

	# Delegar el posicionamiento al OverworldGrid del mapa activo
	var grid = get_active_grid()
	if not grid:
		push_error("MapSystem: No se pudo obtener el OverworldGrid del mapa activo")
		return

	# Posicionar al jugador usando el grid
	if not player:
		push_error("MapSystem: Player no disponible para posicionar")
		return

	grid.position_player_at_tile(player_position, player)

	# Establecer la dirección del jugador usando el grid
	grid.set_player_facing_direction(facing_dir, player)

	print("MapSystem: Jugador configurado según GameState")

## Carga el jugador dinámicamente
func load_player() -> bool:
	print("MapSystem: Cargando jugador dinámicamente...")

	# Cargar la escena del jugador
	var player_scene = preload("res://Scenes/Overworld/Actors/Player.tscn")
	if not player_scene:
		push_error("MapSystem: No se pudo cargar la escena del jugador")
		return false

	# Instanciar el jugador
	var player_instance = player_scene.instantiate()
	if not player_instance:
		push_error("MapSystem: No se pudo instanciar el jugador")
		return false

	# Añadir el jugador como hijo del MapSystem
	add_child(player_instance)
	player = player_instance

	# Registrar el jugador en el contexto si está disponible
	if context:
		context.register_system("Player", player_instance)
		print("MapSystem: Jugador registrado en el contexto")

	# Inyectar el contexto al jugador si tiene el método
	if player_instance.has_method("set_context"):
		player_instance.set_context(context)

	print("MapSystem: Jugador cargado dinámicamente")
	return true

## Asigna un mapa como activo
func set_active_map(map_scene: Node) -> void:
	if not map_scene:
		push_error("MapSystem: No se puede asignar un mapa nulo")
		return

	# Si ya hay un mapa activo, lo removemos
	if active_map and active_map != map_scene:
		# Desconectar el jugador del mapa anterior si es necesario
		_cleanup_previous_map()

	active_map = map_scene

	# Asegurar que el mapa esté en la escena
	if not is_instance_valid(active_map) or not is_ancestor_of(active_map):
		push_error("MapSystem: El mapa debe ser un nodo hijo de MapSystem")
		return

	# Inyectar contexto al grid del mapa
	if context:
		var grid = get_active_grid()
		if grid and grid.has_method("set_context"):
			grid.set_context(context)

	# Configurar el jugador para el nuevo mapa
	_setup_player_for_map()

## Obtiene el OverworldGrid del mapa activo
func get_active_grid() -> OverworldGrid:
	if not active_map:
		push_warning("MapSystem: No hay mapa activo")
		return null

	var grid = active_map.get_node("OverworldGrid")
	if not grid or not grid is OverworldGrid:
		push_warning("MapSystem: El mapa activo no tiene un OverworldGrid válido")
		return null

	return grid

## Obtiene el mapa activo actual
func get_active_map() -> Node:
	return active_map

## Obtiene el jugador
func get_player() -> Node:
	return player

## Configura el jugador para el mapa activo
func _setup_player_for_map() -> void:
	if not player or not active_map:
		return

	# Asegurar que el jugador esté en la jerarquía correcta
	if not is_ancestor_of(player):
		# Si el jugador no está bajo MapSystem, moverlo
		var parent = player.get_parent()
		if parent:
			parent.remove_child(player)
		add_child(player)

	# Configurar la cámara del jugador para el nuevo mapa
	var camera = player.get_node("Camera2D")
	if camera and camera.has_method("set_map_layer_path"):
		var grid = get_active_grid()
		if grid:
			var terrain_layer = grid.get_node("Terrain")
			if terrain_layer:
				camera.map_layer_path = terrain_layer.get_path()

## Carga un mapa por su ID - DELEGADO AL WORLDSYSTEM
func load_map(map_id: String) -> Node:
	print("MapSystem: Delegando carga de mapa a WorldSystem: ", map_id)

	# Obtener WorldSystem del contexto (método preferido)
	var ws: WorldSystem = null
	if context:
		ws = context.get_world_system()
	elif world_system:
		# Fallback temporal para compatibilidad
		ws = world_system

	if not ws:
		push_error("MapSystem: WorldSystem no disponible. Verificar inyección de contexto.")
		return null

	# Delegar la carga al WorldSystem
	return ws.load_map(map_id)

## Cambia al mapa especificado - DELEGADO AL WORLDSYSTEM
func change_to_map(map_id: String, _preserve_previous: bool = false) -> bool:
	print("MapSystem: Delegando cambio de mapa a WorldSystem: ", map_id)

	# Obtener WorldSystem del contexto (método preferido)
	var ws: WorldSystem = null
	if context:
		ws = context.get_world_system()
	elif world_system:
		# Fallback temporal para compatibilidad
		ws = world_system

	if not ws:
		push_error("MapSystem: WorldSystem no disponible. Verificar inyección de contexto.")
		return false

	# Delegar al WorldSystem
	return ws.change_to_map(map_id)

## Cambia al mapa usando una instancia ya proporcionada (por WorldSystem)
## NOTA: En sistema seamless, el mapa puede ya estar renderizado como vecino
func change_to_map_instance(map_instance: Node) -> bool:
	if not map_instance:
		push_error("MapSystem: Instancia de mapa inválida")
		return false

	var map_id := map_instance.name
	print("MapSystem: Cambiando a instancia de mapa: ", map_id)

	# Si ya estamos en este mapa, no hacer nada
	if active_map == map_instance:
		print("MapSystem: Ya estamos en el mapa: ", map_id)
		return true

	# Desactivar el mapa anterior (pero NO removerlo - sistema seamless)
	if active_map:
		_cleanup_previous_map()

		# En sistema seamless, los mapas pueden permanecer visibles
		# Solo desactivamos el procesamiento si tiene el método
		if active_map.has_method("deactivate"):
			active_map.deactivate()

		# NO remover el mapa del árbol (puede ser un vecino visible)
		# active_map sigue bajo MapSystem pero inactivo

	# Establecer como activo
	active_map = map_instance

	# Añadir como child si no está ya en la jerarquía (primera carga)
	if not is_ancestor_of(map_instance):
		# CRÍTICO: Remover del padre actual si tiene uno (puede estar en cache_container)
		var current_parent = map_instance.get_parent()
		if current_parent:
			current_parent.remove_child(map_instance)
			print("  → Removido de: %s" % current_parent.name)

		add_child(map_instance)
		print("  ✓ Mapa añadido a MapSystem")
	else:
		print("  ✓ Mapa ya estaba en MapSystem (seamless)")

	# Configurar visibilidad y procesamiento
	_set_subtree_visibility(map_instance, true)

	# Activar el procesamiento si tiene el método
	if map_instance.has_method("activate"):
		map_instance.activate()
	else:
		map_instance.process_mode = Node.PROCESS_MODE_INHERIT

	# Emitir grid activo tras activar el mapa
	var grid := get_active_grid()
	if context and grid:
		context.emit_active_grid_changed(grid)

	# Configurar el mapa activo
	set_active_map(map_instance)

	print("MapSystem: Cambio de mapa completado: ", map_id)
	return true

## MÉTODO ELIMINADO: _get_scene_for_map_id
## La resolución de escenas ahora es responsabilidad del WorldSystem

## Libera el mapa preservado (si existe). Se puede conectar directamente a señales que pasen un parámetro
func release_previous_map(_event: Event = null) -> void:
	if previous_map and is_instance_valid(previous_map):
		print("MapSystem: Liberando mapa preservado: ", previous_map.name)
		previous_map.queue_free()
	previous_map = null

## Configura la visibilidad del nodo raíz (NO recursivo)
## Los nodos hijos gestionan su propia visibilidad (respeta SpawnPoints, etc.)
func _set_subtree_visibility(node: Node, vis: bool) -> void:
	if node is CanvasItem:
		(node as CanvasItem).visible = vis
	# NO hacer recursivo - respeta la visibilidad configurada de los hijos
	# Ejemplo: SpawnPoints con sprite oculto, eventos con sprites personalizados, etc.



## Limpia la configuración del mapa anterior
func _cleanup_previous_map() -> void:
	if not active_map:
		return

	# Aquí se pueden añadir limpiezas específicas si es necesario
	# Por ejemplo, desconectar señales, limpiar referencias, etc.
	pass


## ============================================================================
## CONSULTAS DE MOVIMIENTO MUNDIAL (para seamless world)
## ============================================================================

## Encuentra el grid que contiene una posición global y retorna grid + tile convertido
## Optimizado: convierte una sola vez, evitando cálculos duplicados
## Retorna: {"grid": OverworldGrid, "tile": Vector2i}
func find_grid_and_tile_at_world_position(world_pos: Vector2) -> Dictionary:
	# Iterar por todos los hijos de MapSystem (mapas renderizados)
	for child in get_children():
		if child.is_in_group("Player"):
			continue

		var grid = child.get_grid() if child.has_method("get_grid") else null
		if not grid:
			continue

		# Convertir posición global a tile local de este grid
		var tile_local = grid.world_to_tile(world_pos)

		# Verificar si el grid tiene tile data en esa posición
		var tile_data = grid.get_tile_data(tile_local)
		if not tile_data.is_empty():
			return {"grid": grid, "tile": tile_local}  # Encontrado!

	return {"grid": null, "tile": Vector2i.ZERO}


## Verifica movimiento usando posiciones globales y retorna resultado + grid destino
## Optimizado: usa find_grid_and_tile_at_world_position para evitar conversiones duplicadas
## Retorna: {"can_move": bool, "target_grid": OverworldGrid, "from_tile": Vector2i, "to_tile": Vector2i}
func check_world_movement(actor: Node, from_world_pos: Vector2, to_world_pos: Vector2) -> Dictionary:
	# Encontrar el grid que contiene la posición destino (con tile ya convertido)
	var to_result = find_grid_and_tile_at_world_position(to_world_pos)
	var target_grid: OverworldGrid = to_result["grid"]
	var to_tile: Vector2i = to_result["tile"]

	if not target_grid:
		return {"can_move": false, "target_grid": null, "from_tile": Vector2i.ZERO, "to_tile": Vector2i.ZERO}

	# Convertir posición origen al sistema del grid destino
	var from_tile = target_grid.world_to_tile(from_world_pos)

	# Verificar si puede moverse usando la lógica del grid correspondiente
	var can_move = target_grid.can_step_to(actor, from_tile, to_tile)

	return {
		"can_move": can_move,
		"target_grid": target_grid,
		"from_tile": from_tile,
		"to_tile": to_tile
	}
