extends BattleMoveCategory

class_name BattleSwaggerMoveCategory

func _create_handler(move: BattleMove, user: BattlePokemon, target: BattleTarget) -> BattleHandler:
	return BattleSwaggerMoveHandler.new(move, user, target)
