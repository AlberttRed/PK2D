extends BattleAnimation
class_name PokeballThrowBattleAnimation

## Lanzamiento de Poké Ball hacia un BattleSpot (player o enemy).
## Rival: VisualRoot en BallGround (suelo/sombra), no en Feet del bbox.

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


func _prepare_instance(
	instance: Node,
	user_spot: BattleSpot,
	target_spots: Array[BattleSpot]
) -> void:
	super._prepare_instance(instance, user_spot, target_spots)
	var landing := _first_target(target_spots)
	if landing == null:
		landing = user_spot
	if landing == null or landing.side == null or landing.side.type != BattleSide.Types.ENEMY:
		return
	var visual := instance.get_node_or_null("VisualRoot") as Node2D
	if visual == null:
		return
	visual.global_position = landing.get_anchor_global_position(BattleSpot.ANCHOR_BALL_GROUND)


func _resolve_throw_clip(landing: BattleSpot) -> String:
	if landing != null and landing.side != null and landing.side.type == BattleSide.Types.ENEMY:
		return "throw_enemy"
	return "throw_player"
