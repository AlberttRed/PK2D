extends BattleMoveCategory

class_name BattleHealMoveCategory

func _create_handler(move: BattleMove, user: BattlePokemon, target: BattleTarget) -> BattleHandler:
	var target_pokemon := require_pokemon_target(target)
	if not target_pokemon:
		return null
	
	return BattleHealMoveHandler.new(move, user, target_pokemon)
