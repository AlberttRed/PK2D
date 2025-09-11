class_name PoisonAilmentEffect
extends PersistentBattleEffect


func apply_phase(pokemon, phase: Phases) -> void: 
	if phase != BattleEffect.Phases.ON_END_POKEMON_TURN:
		return
	var dmg:int = ceil(pokemon.total_hp / 8.0)
	var effect := DamageEffect.new(null, pokemon, null, dmg)
	effect.show_effectiveness = false
	pokemon.take_damage(effect)


func visualize_phase(pokemon: BattlePokemon, ui: BattleUI, phase: BattleEffect.Phases):
	if phase != BattleEffect.Phases.ON_END_POKEMON_TURN:
		return

	await ui.show_ailment_effect_message(pokemon, source)
	await pokemon.battle_spot.apply_damage()

func get_priority() -> int:
	return 10
