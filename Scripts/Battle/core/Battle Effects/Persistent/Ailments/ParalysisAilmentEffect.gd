class_name ParalysisAilmentEffect
extends PersistentBattleEffect

func check_effect_success():
	effect_success = randf() < 0.25
	
func apply_phase(pokemon, phase: Phases) -> void: 
	if phase != BattleEffect.Phases.ON_BEFORE_MOVE:
		return
	check_effect_success()

	if effect_success:
		pokemon.can_act_this_turn = false
	

func visualize_phase(pokemon: BattlePokemon, ui: BattleUI, phase: BattleEffect.Phases):
	if phase != BattleEffect.Phases.ON_BEFORE_MOVE:
		return

	if effect_success:
		await ui.show_ailment_effect_message(pokemon, source)

func get_priority() -> int:
	return 10
