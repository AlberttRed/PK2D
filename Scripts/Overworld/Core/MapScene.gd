extends Node2D
class_name MapScene

## Script base para todos los mapas del overworld
## Permite configurar la posición mundial y proporciona funcionalidad común
##
## USO:
## 1. Asignar este script a la raíz de cada escena de mapa
## 2. Configurar world_position desde el inspector
## 3. El mapa se posicionará automáticamente al inicializarse

@export_group("World Configuration")
## Posición del mapa en el mundo global (coordenadas en píxeles)
## Ejemplo: Ruta1 arriba de PuebloPaleta → Vector2(0, -480)
@export var world_position: Vector2 = Vector2.ZERO
## Si true, este mapa se considera interior (casa/cueva/edificio).
## Se usa para sincronizar flags globales de estado (p.ej. `indoor`).
@export var is_indoor: bool = false

## ID del mapa (se auto-detecta del nombre si está vacío)
@export var map_id: String = ""

## IDs de mapas vecinos (para carga seamless)
## Los vecinos se precargan y son visibles desde este mapa
## Ejemplo: ["Ruta1", "Ruta21"] para un pueblo con dos rutas
@export var neighbors: Array[String] = []

@export_group("Overlay Settings")
## Nivel de oscuridad global al entrar en este mapa (0 = sin oscuridad, 1 = negro)
@export_range(0.0, 1.0, 0.01) var overlay_darkness: float = 0.0
## Clima visual inicial
@export_enum("none", "rain", "snow", "fog", "storm") var overlay_weather: String = "none"
## Indica si este mapa requiere iluminación tipo destello
@export var overlay_flashlight_required: bool = false

## Referencia al grid de este mapa
@onready var grid: OverworldGrid = $OverworldGrid

## Indica si este mapa está actualmente activo (jugador aquí)
var is_active: bool = false

## Límites del mapa en tiles (cacheado para verificación rápida)
var tile_bounds: Rect2i = Rect2i()

## Offset de tiles del mapa en coordenadas mundiales
var tile_offset: Vector2i = Vector2i.ZERO


func _ready() -> void:
	# Auto-detectar map_id del nombre de la escena si no está configurado
	if map_id.is_empty():
		map_id = name

	# Aplicar posición mundial
	global_position = world_position

	# Calcular límites del mapa y offset de tiles
	_calculate_tile_bounds()

	# El mapa inicia visible pero con procesamiento deshabilitado
	# (se habilitará cuando sea el mapa activo)
	visible = true
	_disable_processing()


## Calcula los límites del mapa en tiles (llamado en _ready)
func _calculate_tile_bounds() -> void:
	if not grid:
		push_warning("MapScene '%s': No tiene OverworldGrid" % map_id)
		return

	var terrain = grid.reference_layer()
	if not terrain:
		push_warning("MapScene '%s': No tiene capa de terreno" % map_id)
		return

	# Obtener el rectángulo de tiles usados
	tile_bounds = terrain.get_used_rect()

	# Calcular offset de tiles en coordenadas mundiales
	var tile_size = terrain.tile_set.tile_size.x if terrain.tile_set else 16
	tile_offset = Vector2i(
		int(world_position.x / tile_size),
		int(world_position.y / tile_size)
	)


## Verifica si un tile (en coordenadas mundiales) está en este mapa
## OPTIMIZADO: Usa Rect2i.has_point() que es O(1) muy rápido
func contains_world_tile(world_tile: Vector2i) -> bool:
	# Convertir tile mundial a tile local del mapa
	var local_tile = world_tile - tile_offset

	# Verificación ultra-rápida con Rect2i
	return tile_bounds.has_point(local_tile)


## Verifica si una posición global está dentro de este mapa
## (Menos eficiente, solo usar si no tienes el tile)
func contains_world_position(world_pos: Vector2) -> bool:
	if not grid:
		return false

	# Convertir posición a tile
	var local_pos = to_local(world_pos)
	var local_tile = grid.world_to_tile(local_pos)

	# Usar verificación rápida por tile
	return tile_bounds.has_point(local_tile)


## Activa este mapa (jugador está aquí)
## NOTA: NO activa grid ni eventos - el sistema de chunks controla su activación
func activate() -> void:
	is_active = true
	# NO llamar a _enable_processing() - el sistema de chunks (WorldChunkController)
	# controla qué eventos/grids están activos basándose en chunks activos, no en el mapa activo


## Desactiva este mapa (jugador en otro mapa)
## NOTA: NO desactiva grid ni eventos - el sistema de chunks controla su activación
func deactivate() -> void:
	is_active = false
	# NO llamar a _disable_processing() - el sistema de chunks (WorldChunkController)
	# controla qué eventos/grids están activos basándose en chunks activos, no en el mapa activo
	# Si desactivamos aquí, rompemos el sistema de chunks


## Habilita el procesamiento de este mapa
func _enable_processing() -> void:
	# Habilitar el grid para colisiones y eventos
	if grid:
		grid.process_mode = Node.PROCESS_MODE_INHERIT

	# Habilitar eventos del mapa
	var events_node = find_child("Events")
	if events_node:
		events_node.process_mode = Node.PROCESS_MODE_INHERIT


## Deshabilita el procesamiento de este mapa (optimización)
func _disable_processing() -> void:
	# Deshabilitar el grid (no procesa colisiones ni eventos)
	if grid:
		grid.process_mode = Node.PROCESS_MODE_DISABLED

	# Deshabilitar eventos del mapa
	var events_node = find_child("Events")
	if events_node:
		events_node.process_mode = Node.PROCESS_MODE_DISABLED


## Obtiene el OverworldGrid de este mapa
func get_grid() -> OverworldGrid:
	return grid


## Información de debug
func print_info() -> void:
	print("=== MapScene Info: %s ===" % map_id)
	print("  Posición mundial: %s" % world_position)
	print("  Posición actual: %s" % global_position)
	print("  Activo: %s" % is_active)
	print("  Visible: %s" % visible)
	print("  Grid válido: %s" % (grid != null))


## Devuelve la configuración de overlay asociada a este mapa
func get_overlay_settings() -> Dictionary:
	return {
		"darkness": clampf(overlay_darkness, 0.0, 1.0),
		"weather": overlay_weather,
		"flashlight_required": overlay_flashlight_required,
	}
