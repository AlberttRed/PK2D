extends Node2D
class_name SpawnPoint

## SpawnPoint - Punto de aparición para el jugador en los mapas
## Se puede usar para definir dónde debe aparecer el jugador al hacer warp

@export var spawn_id: String = ""
@export var facing_direction: Vector2

func _ready() -> void:
	# Añadir al grupo de SpawnPoints para facilitar la búsqueda
	if not is_in_group("SpawnPoints"):
		add_to_group("SpawnPoints")
	
	# Si no se especificó un ID, usar el nombre del nodo
	if spawn_id.is_empty():
		spawn_id = name
	
	print("SpawnPoint: Inicializado con ID: ", spawn_id, " y dirección: ", facing_direction)

## Retorna el ID del spawn point
func get_spawn_id() -> String:
	return spawn_id

## Retorna la posición en tiles del spawn point
func get_tile_position() -> Vector2i:
	# Buscar el OverworldGrid del mapa actual
	var map_system: MapSystem = get_tree().get_first_node_in_group("MapSystem")
	if not map_system:
		push_warning("SpawnPoint: No se encontró el MapSystem")
		return Vector2i.ZERO
	
	var grid: OverworldGrid = map_system.get_active_grid()
	if not grid:
		push_warning("SpawnPoint: No se encontró el OverworldGrid")
		return Vector2i.ZERO
	
	# Convertir posición mundial a tiles
	return grid.world_to_tile(global_position)

## Retorna la dirección a la que debe mirar el jugador
func get_facing_direction() -> Vector2:
	return facing_direction

## Establece el ID del spawn point
func set_spawn_id(new_id: String) -> void:
	spawn_id = new_id

## Establece la dirección de mirada
func set_facing_direction(direction: Vector2) -> void:
	facing_direction = direction
