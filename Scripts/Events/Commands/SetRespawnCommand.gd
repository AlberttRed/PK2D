extends EventCommand
class_name SetRespawnCommand
## Fija el último punto de blanqueo (Centro Pokémon, etc.); persiste vía `save_game`.

@export var map_id: String = ""
@export var target_tile: Vector2i = Vector2i.ZERO

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
		_context.continue_execution()
		return
	var facing := get_facing_vector()
	GameStateService.set_respawn_point_data({
		"map_id": map_id,
		"position": target_tile,
		"facing": facing,
	})
	print("SetRespawnCommand: respawn fijado en %s tile=%s dir=%s" % [map_id, target_tile, facing])
	_context.continue_execution()


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
