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
	_apply_ball_sprite_for_spot(instance, landing)
	if landing == null or landing.side == null or landing.side.type != BattleSide.Types.ENEMY:
		return
	var visual := instance.get_node_or_null("VisualRoot") as Node2D
	if visual == null:
		return
	visual.global_position = landing.get_anchor_global_position(BattleSpot.ANCHOR_BALL_GROUND)


static func _resolve_ball_sprite_id(spot: BattleSpot) -> String:
	if spot == null or spot.pokemon == null:
		return PokeballItemEffect.DEFAULT_BALL_SPRITE_ID
	var mon: Pokemon = spot.pokemon.base_data
	if mon == null:
		return PokeballItemEffect.DEFAULT_BALL_SPRITE_ID
	return PokeballItemEffect.normalize_ball_sprite_id(mon.captured_ball_id)


static func _apply_ball_sprite_for_spot(instance: Node, spot: BattleSpot) -> void:
	var ball := instance.get_node_or_null("VisualRoot/Ball") as Sprite2D
	if ball == null:
		return
	PokeballThrowSpriteFrames.setup_sprite_sheet_mode(ball, _resolve_ball_sprite_id(spot))


func _resolve_throw_clip(landing: BattleSpot) -> String:
	if landing != null and landing.side != null and landing.side.type == BattleSide.Types.ENEMY:
		return "throw_enemy"
	return "throw_player"
