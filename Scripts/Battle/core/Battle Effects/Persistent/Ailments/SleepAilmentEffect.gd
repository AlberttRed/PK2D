class_name SleepAilmentEffect
extends PersistentBattleEffect

func apply_phase(pokemon, phase: Phases) -> void: 
	if phase != BattleEffect.Phases.ON_BEFORE_MOVE:
		return
	
	next_turn()
	
	if has_finished():
		pokemon.set_status(null)
	else:
		pokemon.can_act_this_turn = false 

func visualize_phase(pokemon: BattlePokemon, ui: BattleUI, phase: BattleEffect.Phases):
	if phase != BattleEffect.Phases.ON_BEFORE_MOVE:
		return
	if has_finished():
		await ui.show_end_ailment_message(pokemon, source)
		pokemon.status_changed.emit()
	else:
		await ui.show_ailment_effect_message(pokemon, source)

func get_priority() -> int:
	return 10
