extends BattleMoveCategory

class_name BattleNetGoodStatsMoveCategory

func _create_handler(move: BattleMove, user: BattlePokemon, target: BattleTarget) -> BattleHandler:
	return BattleNetGoodStatsMoveHandler.new(move, user, target)
