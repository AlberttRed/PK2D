extends BattleMoveCategory
class_name BattleDamageMoveCategory

func _create_handler(move, user, target) -> BattleHandler:
	return BattleDamageMoveHandler.new(move, user, target)
