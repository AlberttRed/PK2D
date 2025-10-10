extends BattleMoveCategory

class_name BattleFieldEffectMoveCategory

func _create_handler(move: BattleMove, user: BattlePokemon, target: BattleTarget) -> BattleHandler:
	# Los efectos de lado (Reflejo, Pantalla de Luz, Púas, etc.) requieren un SIDE como target
	var side := require_side_target(target)
	if not side:
		return null
	
	return BattleFieldEffectMoveHandler.new(move, user, side)
