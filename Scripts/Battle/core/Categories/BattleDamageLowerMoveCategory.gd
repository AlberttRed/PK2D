extends BattleMoveCategory

class_name BattleDamageLowerMoveCategory

func _create_handler(move: BattleMove, user: BattlePokemon, target: BattleTarget) -> BattleHandler:
	return BattleDamageLowerMoveHandler.new(move, user, target)
