extends BattleMoveCategory

class_name BattleOhkoMoveCategory

func _create_handler(move: BattleMove, user: BattlePokemon, target: BattleTarget) -> BattleHandler:
	return BattleOhkoMoveHandler.new(move, user, target)
