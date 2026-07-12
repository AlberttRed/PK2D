class_name BurnAilmentEffect
extends PersistentBattleEffect


func apply_phase(pokemon: BattlePokemon, phase: Phases, _ctx: BattlePhaseContext = null) -> void:
	if phase != BattleEffect.Phases.ON_END_BATTLE_TURN:
		return

	var dmg:int = ceil(pokemon.total_hp / 16.0)

	var burn_effect := DamageEffect.new(null, pokemon, null, dmg)
	burn_effect.is_critical = false
	burn_effect.effectiveness = 1.0

	pokemon.take_damage(burn_effect)

func visualize_phase(pokemon: BattlePokemon, ui: BattleUI, phase: Phases, _ctx: BattlePhaseContext = null) -> void:
	if phase != BattleEffect.Phases.ON_END_BATTLE_TURN:
		return

	await ui.show_effect_message(MessageFamily.Values.AILMENT, pokemon, source.id)
	await pokemon.battle_spot.apply_damage()

func get_priority() -> int:
	return BattleEffectPriority.END_BURN
