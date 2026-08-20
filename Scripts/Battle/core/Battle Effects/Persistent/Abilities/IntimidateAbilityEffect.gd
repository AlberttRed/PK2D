extends PersistentBattleEffect
class_name IntimidateAbilityEffect

var _stat_effects: Dictionary = {}


func _is_entry_phase(phase: Phases) -> bool:
	return phase == Phases.ON_BATTLE_START or phase == Phases.ON_SWITCH_IN


func apply_phase(pokemon: BattlePokemon, phase: Phases, _ctx: BattlePhaseContext = null) -> void:
	if not _is_entry_phase(phase):
		return
	_stat_effects.clear()
	var enemies := pokemon.side.opponent_side.get_active_pokemons()
	for enemy: BattlePokemon in enemies:
		var effect := StatChangeEffect.new(
			enemy, {StatsEnum.Values.ATTACK: -1}
		)
		effect.user = pokemon
		effect.apply()
		_stat_effects[enemy] = effect


func visualize_phase(pokemon: BattlePokemon, ui: BattleUI, phase: Phases, _ctx: BattlePhaseContext = null) -> void:
	if not _is_entry_phase(phase):
		return
	var enemies := pokemon.side.opponent_side.get_active_pokemons()
	var ability_id: int = source.id if source is AbilityData else int(source)
	for enemy: BattlePokemon in enemies:
		await ui.show_ability_effect_message(pokemon, enemy, ability_id)
		if _stat_effects.has(enemy):
			await _stat_effects[enemy].visualize(ui)


func get_priority() -> int:
	return 10
