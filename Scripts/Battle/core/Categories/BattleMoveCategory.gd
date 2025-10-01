extends Resource

class_name BattleMoveCategory

func create_handler(move: BattleMove, user: BattlePokemon, target: BattlePokemon) -> BattleHandler:
	var base := _create_handler(move, user, target)
	var num_hits := move.get_number_of_hits()
	if num_hits > 1:
		return MultiHitHandler.new(self, move, user, target, num_hits)
	return base

func _create_handler(move: BattleMove, user: BattlePokemon, target: BattlePokemon) -> BattleHandler:
	return null
