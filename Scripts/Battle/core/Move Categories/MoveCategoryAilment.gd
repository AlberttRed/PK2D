class_name MoveCategoryAilment
extends MoveCategoryLogic

func execute() -> Array[ImmediateBattleEffect]:
	var effects: Array[ImmediateBattleEffect] = []

	if move.get_ailment() and randf() < move.get_ailment_chance():
		effects.append(ApplyAilmentEffect.new(target, move.get_ailment(), {"min_turns": move.get_min_turns(), "max_turns": move.get_max_turns()}))

	return effects
