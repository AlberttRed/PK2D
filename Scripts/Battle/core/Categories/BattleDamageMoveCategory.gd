extends BattleMoveCategory
class_name BattleDamageMoveCategory

func _create_handler(move: BattleMove, user: BattlePokemon, target: BattlePokemon) -> BattleHandler:
	return BattleDamageMoveHandler.new(move, user, target)
