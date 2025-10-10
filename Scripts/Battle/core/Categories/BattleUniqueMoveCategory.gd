extends BattleMoveCategory

class_name BattleUniqueMoveCategory

func _create_handler(move: BattleMove, user: BattlePokemon, target: BattleTarget) -> BattleHandler:
	# Los movimientos únicos pueden tener diferentes comportamientos según el target
	# Por ahora asumimos que requieren un Pokémon, pero esto puede variar
	return BattleUniqueMoveHandler.new(move, user, target)
