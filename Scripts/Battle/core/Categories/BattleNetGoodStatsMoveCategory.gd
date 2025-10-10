extends BattleMoveCategory

class_name BattleNetGoodStatsMoveCategory

func _create_handler(move: BattleMove, user: BattlePokemon, target: BattleTarget) -> BattleHandler:
	var target_pokemon := require_pokemon_target(target)
	if not target_pokemon:
		return null
	
	return BattleNetGoodStatsMoveHandler.new(move, user, target_pokemon)
