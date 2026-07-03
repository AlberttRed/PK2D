extends PersistentBattleEffect
class_name IntimidateAbilityEffect

func _is_entry_phase(phase: Phases) -> bool:
	return phase == Phases.ON_BATTLE_START or phase == Phases.ON_SWITCH_IN

func apply_phase(pokemon: BattlePokemon, phase: Phases, _ctx: BattlePhaseContext = null) -> void:
	if not _is_entry_phase(phase):
		return
	var enemies := pokemon.side.opponent_side.get_active_pokemons()
	for target: BattlePokemon in enemies:
		target.stat_stages.decrease(StatsEnum.Values.ATTACK, 1)

func visualize_phase(pokemon: BattlePokemon, ui: BattleUI, phase: Phases, _ctx: BattlePhaseContext = null) -> void:
	if not _is_entry_phase(phase):
		return
	var enemies := pokemon.side.opponent_side.get_active_pokemons()
	var ability_id: int = source.id if source is AbilityData else int(source)
	for target: BattlePokemon in enemies:
		await ui.show_ability_effect_message(pokemon, target, ability_id)

func get_priority() -> int:
	return 10
