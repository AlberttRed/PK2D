extends BattleMoveCategory

class_name BattleDamageLowerMoveCategory

func _create_handler(move: BattleMove, user: BattlePokemon, target: BattleTarget) -> BattleHandler:
	var target_pokemon := require_pokemon_target(target)
	if not target_pokemon:
		return null
	
	return BattleDamageLowerMoveHandler.new(move, user, target_pokemon)
