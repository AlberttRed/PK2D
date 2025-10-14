extends BattleMoveCategory

class_name BattleHealMoveCategory

func _create_handler(move: BattleMove, user: BattlePokemon, target: BattleTarget) -> BattleHandler:
	# Pasar el BattleTarget crudo; el handler decidirá a quién curar según el movimiento
	return BattleHealMoveHandler.new(move, user, target)
