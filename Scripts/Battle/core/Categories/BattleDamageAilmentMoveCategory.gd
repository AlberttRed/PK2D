extends BattleMoveCategory

class_name BattleDamageAilmentMoveCategory

func _create_handler(move: BattleMove, user: BattlePokemon, target: BattleTarget) -> BattleHandler:
	return BattleDamageAilmentMoveHandler.new(move, user, target)
