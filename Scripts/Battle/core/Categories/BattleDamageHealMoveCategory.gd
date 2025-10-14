extends BattleMoveCategory

class_name BattleDamageHealMoveCategory

func _create_handler(move: BattleMove, user: BattlePokemon, target: BattleTarget) -> BattleHandler:
	# Pasar BattleTarget para que el handler resuelva Pokémon y cantidades
	return BattleDamageHealMoveHandler.new(move, user, target)
