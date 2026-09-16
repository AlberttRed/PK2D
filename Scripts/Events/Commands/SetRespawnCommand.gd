extends EventCommand
class_name SetRespawnCommand
## Fija el último punto de blanqueo (Centro Pokémon, etc.); persiste vía `save_game`.
## Síncrono: NO llamar continue_execution (lo hace EventController).

@export var map_id: String = ""
@export var target_tile: Vector2i = Vector2i.ZERO
## Etiqueta libre (p. ej. "verde", "plateada") para discriminar mostradores / contexto.
## Se guarda en respawn_point y se copia a la variable global RESPAWN_TAG.
@export var tag: String = ""

enum FacingDirection {
	ARRIBA,
	ABAJO,
	IZQUIERDA,
	DERECHA
}

@export var facing_direction: FacingDirection = FacingDirection.ABAJO


func execute(_context: Node) -> void:
	if map_id.is_empty():
		push_warning("SetRespawnCommand: map_id vacío; se ignora")
		return
	var facing := get_facing_vector()
	GameStateService.set_respawn_point_data({
		"map_id": map_id,
		"position": target_tile,
		"facing": facing,
		"tag": tag,
	})
	print("SetRespawnCommand: respawn fijado en %s tile=%s dir=%s tag='%s'" % [map_id, target_tile, facing, tag])


func get_facing_vector() -> Vector2:
	match facing_direction:
		FacingDirection.ARRIBA:
			return Vector2.UP
		FacingDirection.ABAJO:
			return Vector2.DOWN
		FacingDirection.IZQUIERDA:
			return Vector2.LEFT
		FacingDirection.DERECHA:
			return Vector2.RIGHT
		_:
			return Vector2.DOWN


func is_async() -> bool:
	return false


func is_safe_for_parallel() -> bool:
	return true
