extends BattleMoveCategory

class_name BattleWholeFieldEffectMoveCategory

func _create_handler(move: BattleMove, user: BattlePokemon, _target: BattleTarget) -> BattleHandler:
	# Los efectos de campo completo siempre afectan a FIELD
	# No necesitamos el target, se aplica globalmente
	return BattleWholeFieldEffectMoveHandler.new(move, user)
