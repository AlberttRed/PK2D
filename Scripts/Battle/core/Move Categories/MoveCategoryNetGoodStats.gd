extends MoveCategoryLogic
class_name MoveCategoryNetGoodStats

func execute() -> Array[ImmediateBattleEffect]:
	return [StatChangeEffect.new(target,move.get_stat_changes())]
