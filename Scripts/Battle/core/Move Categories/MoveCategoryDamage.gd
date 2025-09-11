class_name MoveCategoryDamage
extends MoveCategoryLogic

func execute() -> Array[ImmediateBattleEffect]:
	return [ApplyDamageEffect.new(user, target, move)]
	#return [move.calculate_damage(target)]
