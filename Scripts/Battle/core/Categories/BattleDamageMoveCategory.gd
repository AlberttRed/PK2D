extends BattleMoveCategory
class_name BattleDamageMoveCategory

func _create_handler(move: BattleMove, user: BattlePokemon, target: BattleTarget) -> BattleHandler:
	# Pasar el BattleTarget crudo; el handler resolverá el Pokémon
	return BattleDamageMoveHandler.new(move, user, target)
