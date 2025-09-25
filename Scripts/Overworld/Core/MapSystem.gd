extends Node
class_name MapSystem

## Sistema de gestión de mapas para el overworld
## Se encarga de controlar el mapa activo y mantener al jugador como entidad persistente

var active_map: Node = null
var player: Node = null
var previous_map: Node = null

func _enter_tree() -> void:
	# Verificar si ya hay un mapa configurado
	var map_scene = get_node_or_null("MapScene")
	if map_scene:
		set_active_map(map_scene)
		print("MapSystem: Mapa predefinido encontrado y configurado")
	else:
		print("MapSystem: No hay mapa predefinido - se cargará dinámicamente")

func _ready() -> void:
	# Buscar el jugador en la escena
	player = get_tree().get_first_node_in_group("Player")
	if not player:
		print("MapSystem: No se encontró el jugador en la escena - se cargará dinámicamente")
	else:
		print("MapSystem: Jugador predefinido encontrado")
	
	print("MapSystem: Inicialización completada")

## Configura el jugador según el estado del GameStateManager
func configure_player_from_gamestate() -> void:
	# Obtener datos del GameStateManager
	var map_id = GameStateManager.get_current_map_id()
	var position = GameStateManager.get_current_position()
	var facing_dir = GameStateManager.get_facing_direction()
	
	print("MapSystem: Configurando jugador desde GameState - Mapa: %s, Posición: %s, Dirección: %s" % [map_id, position, facing_dir])
	
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
	grid.position_player_at_tile(position)
	
	# Establecer la dirección del jugador usando el grid
	grid.set_player_facing_direction(facing_dir)
	
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

## Carga un mapa por su ID
func load_map(map_id: String) -> Node:
	print("MapSystem: Cargando mapa: ", map_id)

	# Buscar la ruta del mapa (permitiendo subcarpetas bajo Scenes/Overworld/Maps)
	var map_path = _find_map_path(map_id)
	if map_path == "":
		push_error("MapSystem: No se encontró el mapa '" + map_id + "' en 'res://Scenes/Overworld/Maps' ni sus subcarpetas")
		return null
	
	# Cargar la escena del mapa
	var map_scene = load(map_path) as PackedScene
	if not map_scene:
		push_error("MapSystem: No se pudo cargar la escena del mapa: " + map_path)
		return null
	
	# Instanciar el mapa
	var map_instance = map_scene.instantiate()
	if not map_instance:
		push_error("MapSystem: No se pudo instanciar el mapa: " + map_id)
		return null
	
	print("MapSystem: Mapa cargado exitosamente: ", map_id)
	return map_instance

## Cambia al mapa especificado
func change_to_map(map_id: String, preserve_previous: bool = false) -> bool:
	print("MapSystem: Cambiando a mapa: ", map_id)
	
	# Si ya estamos en el mapa correcto, no hacer nada
	if active_map and active_map.name == map_id:
		print("MapSystem: Ya estamos en el mapa: ", map_id)
		return true
	
	# Limpiar el mapa anterior si existe
	if active_map:
		if preserve_previous:
			# Preservar el mapa anterior de forma temporal para permitir terminar eventos en curso
			previous_map = active_map
			# Ocultar de forma robusta todo el subárbol visual
			_set_subtree_visibility(previous_map, false)
			previous_map.process_mode = Node.PROCESS_MODE_DISABLED
		else:
			_cleanup_previous_map()
			active_map.queue_free()
			active_map = null
	
	# Cargar el nuevo mapa
	var new_map = load_map(map_id)
	if not new_map:
		return false
	
	# Configurar el nuevo mapa
	new_map.name = map_id
	
	# Asegurar que el mapa nuevo esté visible
	_set_subtree_visibility(new_map, true)
	new_map.process_mode = Node.PROCESS_MODE_INHERIT
	
	# Establecer como activo ANTES de añadirlo como child
	# para que los sistemas puedan acceder a active_map en su _ready()
	active_map = new_map
	
	# Añadir como child (esto disparará _ready() en todos los nodos del mapa)
	add_child(new_map)

	# Emitir grid activo tras activar el mapa
	var grid := get_active_grid()
	if SignalManager and grid:
		SignalManager.active_grid_changed.emit(grid)
	
	# Configurar el mapa activo (esto ya no es necesario pero lo mantenemos por compatibilidad)
	set_active_map(new_map)
	
	print("MapSystem: Cambio de mapa completado: ", map_id)
	return true

## Busca recursivamente un mapa por nombre dentro de Scenes/Overworld/Maps
func _find_map_path(map_id: String) -> String:
	var base_path = "res://Scenes/Overworld/Maps"
	var target_file = "%s.tscn" % map_id
	return _find_file_recursive(base_path, target_file)

## Búsqueda recursiva de archivo por nombre exacto
func _find_file_recursive(dir_path: String, target_file: String) -> String:
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return ""
	
	dir.list_dir_begin()
	while true:
		var item = dir.get_next()
		if item == "":
			break
		if item.begins_with("."):
			continue
		var item_path = dir_path + "/" + item
		if dir.current_is_dir():
			var found = _find_file_recursive(item_path, target_file)
			if found != "":
				dir.list_dir_end()
				return found
		else:
			if item == target_file:
				dir.list_dir_end()
				return item_path
	
	dir.list_dir_end()
	return ""

## Libera el mapa preservado (si existe). Se puede conectar directamente a señales que pasen un parámetro
func release_previous_map(_event: Event = null) -> void:
	if previous_map and is_instance_valid(previous_map):
		print("MapSystem: Liberando mapa preservado: ", previous_map.name)
		previous_map.queue_free()
	previous_map = null

## Oculta/muestra todo el subárbol de un nodo CanvasItem (y descendientes)
func _set_subtree_visibility(node: Node, visible: bool) -> void:
	if node is CanvasItem:
		(node as CanvasItem).visible = visible
	for child in node.get_children():
		_set_subtree_visibility(child, visible)



## Limpia la configuración del mapa anterior
func _cleanup_previous_map() -> void:
	if not active_map:
		return
	
	# Aquí se pueden añadir limpiezas específicas si es necesario
	# Por ejemplo, desconectar señales, limpiar referencias, etc.
	pass
