extends BattleMoveCategory

class_name BattleDamageRaiseMoveCategory

func _create_handler(move: BattleMove, user: BattlePokemon, target: BattleTarget) -> BattleHandler:
	return BattleDamageRaiseMoveHandler.new(move, user, target)
