extends BattleAnimation
class_name PokeballThrowBattleAnimation

## Lanzamiento de Poké Ball hacia un BattleSpot (player o enemy).
## Elige clip throw_player / throw_enemy según el lado del spot de aterrizaje.

func play(
	animation_layer: Node2D,
	user_spot: BattleSpot,
	target_spots: Array[BattleSpot]
) -> void:
	var landing := _first_target(target_spots)
	if landing == null:
		landing = user_spot
	animation_name = _resolve_throw_clip(landing)
	await super.play(animation_layer, user_spot, target_spots)


func _resolve_throw_clip(landing: BattleSpot) -> String:
	if landing != null and landing.side != null and landing.side.type == BattleSide.Types.ENEMY:
		return "throw_enemy"
	return "throw_player"
