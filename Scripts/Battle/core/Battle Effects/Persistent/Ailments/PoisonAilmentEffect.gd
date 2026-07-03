class_name PoisonAilmentEffect
extends PersistentBattleEffect


func apply_phase(pokemon, phase: Phases, _ctx: BattlePhaseContext = null) -> void:
	if phase != BattleEffect.Phases.ON_END_BATTLE_TURN:
		return
	var dmg:int = ceil(pokemon.total_hp / 8.0)
	var effect := DamageEffect.new(null, pokemon, null, dmg)
	pokemon.take_damage(effect)


func visualize_phase(pokemon: BattlePokemon, ui: BattleUI, phase: BattleEffect.Phases, _ctx: BattlePhaseContext = null):
	if phase != BattleEffect.Phases.ON_END_BATTLE_TURN:
		return

	await ui.show_effect_message(MessageFamily.Values.AILMENT, pokemon, source.id)
	await pokemon.battle_spot.apply_damage()

func get_priority() -> int:
	return 10
