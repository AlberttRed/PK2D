class_name FreezeAilmentEffect
extends PersistentBattleEffect

func check_effect_success():
	effect_success = randf() < 0.2
	
func apply_phase(pokemon, phase: Phases) -> void: 
	if phase != BattleEffect.Phases.ON_BEFORE_MOVE:
		return
	
	check_effect_success()

	pokemon.can_act_this_turn = effect_success

func visualize_phase(pokemon: BattlePokemon, ui: BattleUI, phase: BattleEffect.Phases):
	if phase != BattleEffect.Phases.ON_BEFORE_MOVE:
		return

	if effect_success:
		await ui.show_end_effect_message(MessageFamily.Values.AILMENT, pokemon, source.id)
		pokemon.set_status(null)
		pokemon.status_changed.emit()
	else:
		await ui.show_effect_message(MessageFamily.Values.AILMENT, pokemon, source.id)

func get_priority() -> int:
	return 10

func has_finished():
	return effect_success
