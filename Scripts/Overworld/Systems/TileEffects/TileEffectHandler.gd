extends RefCounted
class_name TileEffectHandler

## Clase base abstracta para handlers de efectos de terreno
## Cada tipo de terreno (hierba, agua, arena, etc.) implementa su propio handler
##
## Los handlers se registran en TileEffectSystem y se llaman automáticamente
## cuando un actor interactúa con tiles de su tipo de terreno.

## Nombre del tipo de terreno que maneja este handler
## Debe coincidir con el valor de custom_data["encounter_type"] o custom_data["terrain"]
var terrain_type: String

## Referencia al sistema padre (para acceso a recursos compartidos)
var effect_system: Node  # TileEffectSystem (usamos Node para evitar referencia circular)


func _init(p_terrain_type: String, p_effect_system: Node) -> void:
	terrain_type = p_terrain_type
	effect_system = p_effect_system


## Se llama cuando un actor EMPIEZA a moverse hacia un tile de este terreno
## @param grid: OverworldGrid del mapa
## @param destination_tile: Tile de destino (Vector2i)
## @param actor: Actor que se está moviendo (Node2D)
func on_step_started_to_tile(_grid: OverworldGrid, _destination_tile: Vector2i, _actor: Node2D) -> void:
	pass  # Implementar en subclases


## Se llama cuando un actor TERMINA un paso en un tile de este terreno
## @param grid: OverworldGrid del mapa
## @param tile: Tile donde terminó el paso (Vector2i)
## @param actor: Actor que terminó el paso (Node2D)
## @param had_collision: true si hubo colisión (no se movió)
func on_step_finished_on_tile(_grid: OverworldGrid, _tile: Vector2i, _actor: Node2D, _had_collision: bool) -> void:
	pass  # Implementar en subclases


## Se llama cuando un actor SALE de un tile de este terreno
## @param grid: OverworldGrid del mapa
## @param tile: Tile del que sale (Vector2i)
## @param actor: Actor que sale (Node2D)
func on_step_exited_tile(_grid: OverworldGrid, _tile: Vector2i, _actor: Node2D) -> void:
	pass  # Implementar en subclases


## Retorna true si este handler puede manejar el tipo de terreno especificado
func can_handle(terrain_type_to_check: String) -> bool:
	return terrain_type == terrain_type_to_check

func clear_state():
	pass

## Se llama cuando un actor se desactiva (sale de un chunk, se desconecta, etc.)
## Permite a cada handler limpiar su estado específico para ese actor
## @param actor: Actor que se está desactivando (Node2D)
func deactivate_actor(_actor: Node2D) -> void:
	pass  # Implementar en subclases si es necesario
