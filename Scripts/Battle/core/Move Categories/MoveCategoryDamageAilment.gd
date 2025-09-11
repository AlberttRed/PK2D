class_name MoveCategoryDamageAilment
extends MoveCategoryLogic

func execute() -> Array[ImmediateBattleEffect]:
	var effects: Array[ImmediateBattleEffect] = []

	# Efecto de daño
	#var damage_effect := move.calculate_damage(target)
	effects.append(ApplyDamageEffect.new(user, target, move))
	
	# Efecto de estado (si hay posibilidad de aplicar un ailment)
	if !move.get_effectiveness_against_pokemon(target) == 0.0 and move.get_ailment() and 0 < move.get_ailment_chance():
		var ailment_effect := ApplyAilmentEffect.new(target, move.get_ailment(), {"min_turns": move.get_min_turns(), "max_turns": move.get_max_turns()}, false)
		if ailment_effect.is_valid:
			effects.append(ailment_effect)

	return effects
