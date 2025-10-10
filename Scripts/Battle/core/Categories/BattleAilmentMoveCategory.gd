extends BattleMoveCategory

class_name BattleAilmentMoveCategory

func _create_handler(move: BattleMove, user: BattlePokemon, target: BattleTarget) -> BattleHandler:
	var target_pokemon := require_pokemon_target(target)
	if not target_pokemon:
		return null
	
	return BattleAilmentMoveHandler.new(move, user, target_pokemon)
