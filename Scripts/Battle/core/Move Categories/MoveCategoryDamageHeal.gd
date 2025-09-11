extends MoveCategoryLogic
class_name MoveCategoryDamageHeal

func execute() -> Array[ImmediateBattleEffect]:
	# 1. Calcular daño
	var damage_result := move.calculate_damage(target)
	# 2. Calcular curación en base al daño infligido
	var heal_result := move.calculate_healing(target, damage_result.amount)

	#Devolvemos el impacto del daño, y luego el impacto de la curación
	return []
