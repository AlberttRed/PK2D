extends MoveCategoryLogic
class_name MoveCategoryHeal

func execute() -> Array[ImmediateBattleEffect]:
	return []#[move.calculate_healing(user)]
