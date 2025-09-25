extends Node2D
class_name SpawnPoint

## SpawnPoint - Punto de aparición para el jugador en los mapas
## Se puede usar para definir dónde debe aparecer el jugador al hacer warp

@export var facing_direction: Vector2

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	# Añadir al grupo de SpawnPoints para facilitar la búsqueda
	if not is_in_group("SpawnPoints"):
		add_to_group("SpawnPoints")
	
	# Ocultar sprite por defecto si es necesario
	hide_default_sprite_if_needed()
	
	print("SpawnPoint: Inicializado con ID: ", name, " y dirección: ", facing_direction)

## Retorna el ID del spawn point
func get_spawn_id() -> String:
	return name

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

## Establece la dirección de mirada
func set_facing_direction(direction: Vector2) -> void:
	facing_direction = direction

## Oculta el sprite si está usando la imagen por defecto (solo visible en editor)
func hide_default_sprite_if_needed() -> void:
	if not sprite or not sprite.sprite_frames:
		return
	
	# Verificar si está usando el sprite por defecto
	var is_using_default_sprite = is_using_default_spawn_sprite()
	
	if is_using_default_sprite:
		# Ocultar el sprite durante la ejecución del juego
		sprite.visible = false
		print("SpawnPoint '%s': Sprite por defecto ocultado en ejecución" % name)

## Verifica si el spawn point está usando el sprite por defecto
func is_using_default_spawn_sprite() -> bool:
	if not sprite or not sprite.sprite_frames:
		return false
	
	# Obtener la ruta del sprite actual
	var current_sprite_path = sprite.sprite_frames.resource_path
	
	# Verificar si coincide con el sprite por defecto
	var default_sprite_path = "res://Sprites/Eventos/DefaultSpawnPointSprite.png"
	
	# También verificar por el nombre del recurso
	if current_sprite_path.find("DefaultSpawnPointSprite") != -1:
		return true
	
	# Verificar si la primera animación usa la textura por defecto
	if sprite.sprite_frames.has_animation("default"):
		var frame_count = sprite.sprite_frames.get_frame_count("default")
		if frame_count > 0:
			var frame_texture = sprite.sprite_frames.get_frame_texture("default", 0)
			if frame_texture and frame_texture.resource_path == default_sprite_path:
				return true
	
	return false

## Permite mostrar temporalmente el sprite del spawn point
func show_sprite() -> void:
	if sprite:
		sprite.visible = true

## Permite ocultar el sprite del spawn point
func hide_sprite() -> void:
	if sprite:
		sprite.visible = false

## Restablece la visibilidad del sprite según si es por defecto o no
func reset_sprite_visibility() -> void:
	if is_using_default_spawn_sprite():
		sprite.visible = false
	else:
		sprite.visible = true
