class_name FlinchAilmentEffect
extends PersistentBattleEffect


func can_apply() -> int:
	if target != null and BattleEffectController.has_effect_for(target, self):
		return ApplyFailReason.Values.SKIPPED
	return ApplyFailReason.Values.OK


func apply_phase(pokemon: BattlePokemon, phase: Phases, _ctx: BattlePhaseContext = null) -> void:
	if phase == BattleEffect.Phases.ON_BEFORE_MOVE:
		applied = true
		if pokemon.can_act_this_turn:
			pokemon.can_act_this_turn = false
			effect_success = true
	elif phase == BattleEffect.Phases.ON_END_BATTLE_TURN:
		applied = true


func visualize_phase(pokemon: BattlePokemon, ui: BattleUI, phase: Phases, _ctx: BattlePhaseContext = null) -> void:
	if phase != BattleEffect.Phases.ON_BEFORE_MOVE or not applied:
		return
	if effect_success:
		await ui.show_effect_message(MessageFamily.Values.AILMENT, pokemon, source.id)


func has_finished() -> bool:
	return applied


func get_priority() -> int:
	return BattleEffectPriority.PRE_MOVE_FLINCH
