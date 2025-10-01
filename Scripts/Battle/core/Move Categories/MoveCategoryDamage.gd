class_name MoveCategoryDamage
extends MoveCategoryLogic

func execute() -> Array[ImmediateBattleEffect]:
	# Deprecated: ahora los handlers gestionan el daño
	return []
	#return [move.calculate_damage(target)]
