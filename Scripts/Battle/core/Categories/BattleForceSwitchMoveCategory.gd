extends BattleMoveCategory

class_name BattleForceSwitchMoveCategory

func _create_handler(move: BattleMove, user: BattlePokemon, target: BattleTarget) -> BattleHandler:
	var target_pokemon := require_pokemon_target(target)
	if not target_pokemon:
		return null
	
	return BattleForceSwitchMoveHandler.new(move, user, target_pokemon)
