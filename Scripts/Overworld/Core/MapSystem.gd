extends Node
class_name MapSystem

## Sistema de gestión de mapas para el overworld
## Se encarga de controlar el mapa activo y mantener al jugador como entidad persistente

var active_map: Node = null
var player: Node = null

func _ready() -> void:
	# Añadir este nodo al grupo para localizarlo fácilmente
	if not is_in_group("MapSystem"):
		add_to_group("MapSystem")
	
	# Buscar el jugador en la escena
	player = get_tree().get_first_node_in_group("Player")
	if not player:
		push_error("MapSystem: No se encontró el jugador en la escena")
	
	# Configurar el mapa inicial si existe
	var map_scene = get_node("MapScene")
	if map_scene:
		set_active_map(map_scene)

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

## Limpia la configuración del mapa anterior
func _cleanup_previous_map() -> void:
	if not active_map:
		return
	
	# Aquí se pueden añadir limpiezas específicas si es necesario
	# Por ejemplo, desconectar señales, limpiar referencias, etc.
	pass
