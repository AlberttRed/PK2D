extends BattleMoveCategory

class_name BattleDamageRaiseMoveCategory

func _create_handler(move, user, target) -> BattleHandler:
	return BattleDamageRaiseMoveHandler.new(move, user, target)
