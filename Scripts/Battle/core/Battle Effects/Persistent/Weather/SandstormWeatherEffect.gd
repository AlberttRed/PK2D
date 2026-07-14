class_name SandstormWeatherEffect
extends WeatherBattleEffect

const MAGIC_GUARD_ABILITY_ID := 98
const OVERCOAT_ABILITY_ID := 142

var _residual_targets: Array[BattlePokemon] = []


func _on_weather_tick(_pokemon: BattlePokemon, phase: Phases, _ctx: BattlePhaseContext = null) -> void:
	if phase != Phases.ON_END_BATTLE_TURN or has_finished():
		return
	_residual_targets.clear()
	for bp in _get_active_pokemon():
		if bp.is_fainted() or _is_immune_to_sandstorm(bp):
			continue
		var dmg := ceili(bp.total_hp / 16.0)
		var effect := DamageEffect.new(null, bp, null, dmg)
		bp.take_damage(effect)
		_residual_targets.append(bp)


func visualize_phase(
	pokemon: BattlePokemon,
	ui: BattleUI,
	phase: Phases,
	ctx: BattlePhaseContext = null
) -> void:
	await super.visualize_phase(pokemon, ui, phase, ctx)
	if phase != Phases.ON_END_BATTLE_TURN or has_finished():
		_residual_targets.clear()
		return
	for bp in _residual_targets:
		if bp == null or bp.is_fainted():
			continue
		var msg := ui.message_controller.get_weather_residual_damage_message(get_weather_id(), bp)
		if not msg.is_empty():
			await ui.show_message_from_dict(msg)
		if bp.battle_spot != null:
			await bp.battle_spot.apply_damage()
	_residual_targets.clear()


func get_priority() -> int:
	return BattleEffectPriority.END_WEATHER_RESIDUAL


func _get_active_pokemon() -> Array[BattlePokemon]:
	var controller := BattleEffectController.get_instance()
	if controller == null or controller.ui == null or controller.ui.battle_controller == null:
		return []
	return controller.ui.battle_controller.get_all_active_pokemon()


func _is_immune_to_sandstorm(pokemon: BattlePokemon) -> bool:
	if (
		_has_type(pokemon, TypesEnum.Values.ROCK)
		or _has_type(pokemon, TypesEnum.Values.GROUND)
		or _has_type(pokemon, TypesEnum.Values.STEEL)
	):
		return true
	if pokemon.ability == null:
		return false
	var ability_id := int(pokemon.ability.id)
	return ability_id == MAGIC_GUARD_ABILITY_ID or ability_id == OVERCOAT_ABILITY_ID


func _has_type(pokemon: BattlePokemon, type_id: int) -> bool:
	var type1 := pokemon.get_type1()
	if type1 != null and type1.id == type_id:
		return true
	var type2 := pokemon.get_type2()
	return type2 != null and type2.id == type_id
