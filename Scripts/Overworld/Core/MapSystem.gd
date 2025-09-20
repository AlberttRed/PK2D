extends Node
class_name MapSystem

## Sistema de gestión de mapas para el overworld
## Se encarga de controlar el mapa activo y mantener al jugador como entidad persistente

var active_map: Node = null
var player: Node = null

func _enter_tree() -> void:
	# Configurar el mapa inicial ANTES que otros sistemas se inicialicen
	var map_scene = get_node("MapScene")
	if map_scene:
		set_active_map(map_scene)
		print("MapSystem: Mapa inicial configurado en _enter_tree()")
	else:
		push_warning("MapSystem: No se encontró el nodo MapScene")

func _ready() -> void:
	# Buscar el jugador en la escena
	player = get_tree().get_first_node_in_group("Player")
	if not player:
		push_error("MapSystem: No se encontró el jugador en la escena")
	
	print("MapSystem: Inicialización completada")

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
	
	# Construir la ruta del mapa
	var map_path = "res://Scenes/Overworld/Maps/%s/MapScene.tscn" % map_id
	
	# Verificar si el archivo existe
	if not ResourceLoader.exists(map_path):
		push_error("MapSystem: No se encontró el mapa en la ruta: " + map_path)
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
func change_to_map(map_id: String) -> bool:
	print("MapSystem: Cambiando a mapa: ", map_id)
	
	# Si ya estamos en el mapa correcto, no hacer nada
	if active_map and active_map.name == map_id:
		print("MapSystem: Ya estamos en el mapa: ", map_id)
		return true
	
	# Limpiar el mapa anterior si existe
	if active_map:
		_cleanup_previous_map()
		active_map.queue_free()
		active_map = null
	
	# Cargar el nuevo mapa
	var new_map = load_map(map_id)
	if not new_map:
		return false
	
	# Configurar el nuevo mapa
	new_map.name = map_id
	add_child(new_map)
	set_active_map(new_map)
	
	print("MapSystem: Cambio de mapa completado: ", map_id)
	return true

## Busca un SpawnPoint en el mapa activo por su ID
func find_spawn_point(spawn_id: String) -> Node2D:
	if not active_map:
		push_warning("MapSystem: No hay mapa activo para buscar spawn point")
		return null
	
	var grid = get_active_grid()
	if not grid:
		push_warning("MapSystem: No se encontró el OverworldGrid del mapa activo")
		return null
	
	# Buscar directamente en el grid del mapa activo
	return grid.get_spawn_point(spawn_id)

## Posiciona al jugador en un SpawnPoint específico
func position_player_at_spawn(spawn_id: String) -> bool:
	if not player:
		push_error("MapSystem: No hay jugador para posicionar")
		return false
	
	var spawn_point = find_spawn_point(spawn_id)
	if not spawn_point:
		push_warning("MapSystem: No se encontró el spawn point: " + spawn_id)
		# Usar posición por defecto del GameStateManager
		var default_pos = GameStateManager.get_spawn_position()
		player.teleport_to_tile(default_pos)
		return false
	
	# Obtener la posición del spawn point usando su método
	var spawn_position = spawn_point.get_tile_position()
	
	# Teletransportar al jugador
	player.teleport_to_tile(spawn_position)
	
	# Actualizar la dirección si el spawn point la especifica
	var direction = spawn_point.get_facing_direction()
	print("MapSystem: Dirección del SpawnPoint: ", direction)
	player.set_facing_direction(direction)
	GameStateManager.set_facing_direction(direction)
	
	print("MapSystem: Jugador posicionado en spawn: ", spawn_id, " en posición: ", spawn_position, " mirando: ", direction)
	return true

## Limpia la configuración del mapa anterior
func _cleanup_previous_map() -> void:
	if not active_map:
		return
	
	# Aquí se pueden añadir limpiezas específicas si es necesario
	# Por ejemplo, desconectar señales, limpiar referencias, etc.
	pass
