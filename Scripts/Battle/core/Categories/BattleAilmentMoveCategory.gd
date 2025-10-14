extends BattleMoveCategory

class_name BattleAilmentMoveCategory

func _create_handler(move: BattleMove, user: BattlePokemon, target: BattleTarget) -> BattleHandler:
	# Pasar el BattleTarget crudo; el handler resolverá el Pokémon
	return BattleAilmentMoveHandler.new(move, user, target)
