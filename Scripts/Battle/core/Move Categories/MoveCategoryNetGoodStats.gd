extends MoveCategoryLogic
class_name MoveCategoryNetGoodStats

func execute() -> Array[ImmediateBattleEffect]:
	var effect := StatChangeEffect.new(target, move.get_stat_changes())
	effect.user = user
	return [effect]
