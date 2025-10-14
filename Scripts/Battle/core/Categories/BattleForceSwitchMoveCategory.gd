extends BattleMoveCategory

class_name BattleForceSwitchMoveCategory

func _create_handler(move: BattleMove, user: BattlePokemon, target: BattleTarget) -> BattleHandler:
	return BattleForceSwitchMoveHandler.new(move, user, target)
