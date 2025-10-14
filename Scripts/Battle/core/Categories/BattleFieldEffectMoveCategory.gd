extends BattleMoveCategory

class_name BattleFieldEffectMoveCategory

func _create_handler(move: BattleMove, user: BattlePokemon, target: BattleTarget) -> BattleHandler:
	# Los efectos de lado (Reflejo, Pantalla de Luz, Púas, etc.) pasan BattleTarget
	# El handler resolverá el SIDE internamente si lo necesita
	return BattleFieldEffectMoveHandler.new(move, user, target)
