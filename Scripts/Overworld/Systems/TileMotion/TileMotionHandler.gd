extends RefCounted
class_name TileMotionHandler

## Clase base abstracta para handlers de movimiento especial basado en tiles
## Cada tipo de movimiento especial (ledges, stairs, etc.) implementa su propio handler
##
## Los handlers se registran en TileMotionSystem y se llaman automáticamente
## cuando un actor intenta moverse hacia un tile que requiere movimiento especial.

## Nombre del tipo de movimiento que maneja este handler
## Debe coincidir con el valor de custom_data del tile (ej: "ledge", "stair")
var motion_type: String

## Referencia al sistema padre (para acceso a recursos compartidos)
var motion_system: Node  # TileMotionSystem (usamos Node para evitar referencia circular)


func _init(p_motion_type: String, p_motion_system: Node) -> void:
	motion_type = p_motion_type
	motion_system = p_motion_system


## Verifica si este handler puede manejar el movimiento hacia el tile especificado
## @param tile_info: Dictionary con la información del tile (custom_data, etc.)
## @param actor: Actor que intenta moverse (Node2D)
## @param direction: Dirección del movimiento (Vector2)
## @param from_tile: Tile de origen (Vector2i)
## @param to_tile: Tile de destino (Vector2i)
## @return: true si este handler puede manejar este movimiento
func can_handle(
	_tile_info: Dictionary,
	_actor: Node2D,
	_direction: Vector2,
	_from_tile: Vector2i,
	_to_tile: Vector2i
) -> bool:
	return false  # Implementar en subclases


## Se llama cuando un actor EMPIEZA a moverse hacia un tile que requiere movimiento especial
## Este método debe:
## - Verificar si el movimiento es válido
## - Si es válido, consumir el movimiento (retornar true) y ejecutar la animación
## - Si no es válido o no aplica, retornar false para permitir movimiento normal
##
## NOTA: Este método puede ser async (usar await) si necesita esperar animaciones
##
## @param grid: OverworldGrid del mapa
## @param from_tile: Tile de origen (Vector2i)
## @param to_tile: Tile de destino (Vector2i)
## @param actor: Actor que se está moviendo (Node2D)
## @param direction: Dirección del movimiento (Vector2)
## @return: true si el movimiento fue consumido (no ejecutar movimiento normal), false si se permite movimiento normal
func on_step_started_to_tile(
	_grid: OverworldGrid,
	_from_tile: Vector2i,
	_to_tile: Vector2i,
	_actor: Node2D,
	_direction: Vector2
) -> bool:
	return false  # Implementar en subclases


## Se llama cuando un actor TERMINA un paso en un tile (opcional)
## Útil para limpiar estados o ejecutar efectos post-movimiento
##
## @param grid: OverworldGrid del mapa
## @param tile: Tile donde terminó el paso (Vector2i)
## @param actor: Actor que terminó el paso (Node2D)
func on_step_finished_on_tile(_grid: OverworldGrid, _tile: Vector2i, _actor: Node2D) -> void:
	pass  # Implementar en subclases si es necesario


## Se llama cuando un actor se desactiva (sale de un chunk, se desconecta, etc.)
## Permite a cada handler limpiar su estado específico para ese actor
##
## @param actor: Actor que se está desactivando (Node2D)
func deactivate_actor(_actor: Node2D) -> void:
	pass  # Implementar en subclases si es necesario
