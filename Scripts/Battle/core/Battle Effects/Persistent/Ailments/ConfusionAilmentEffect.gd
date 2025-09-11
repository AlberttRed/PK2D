class_name ConfusionAilmentEffect
extends PersistentBattleEffect

func check_effect_success():
	effect_success = randf() < 0.5
	
func apply_phase(pokemon:BattlePokemon, phase: Phases) -> void: 
	if phase != Phases.ON_BEFORE_MOVE or !pokemon.can_act_this_turn:
		return
	
	next_turn()

	if has_finished():
		return

	check_effect_success()

	if effect_success:
		return  # Puede actuar normalmente
	else:
		var damage:int = ceil(pokemon.total_hp / 8.0)
		var effect := DamageEffect.new(pokemon, pokemon, null, damage)
		effect.show_effectiveness = false
		pokemon.take_damage(effect)
		pokemon.can_act_this_turn = false

func visualize_phase(pokemon: BattlePokemon, ui: BattleUI, phase: Phases):
	if phase != Phases.ON_BEFORE_MOVE or !pokemon.can_act_this_turn:
		return

	if has_finished():
		await ui.show_end_ailment_message(pokemon, source)
		return

	await ui.show_ailment_previous_effect_message(pokemon, source)

	if effect_success:
		return  # Puede actuar normalmente
	else:
		await ui.show_ailment_effect_message(pokemon, source)
		await pokemon.battle_spot.apply_damage()
