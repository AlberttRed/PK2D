class_name BurnAilmentEffect
extends PersistentBattleEffect


func can_apply() -> int:
	var base := super.can_apply()
	if not ApplyFailReason.is_success(base):
		return base
	if target == null:
		return ApplyFailReason.Values.GENERIC_FAIL
	if _has_type(target, TypesEnum.Values.FIRE):
		return ApplyFailReason.Values.GENERIC_FAIL
	return ApplyFailReason.Values.OK


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


static func _has_type(pokemon: BattlePokemon, type_id: int) -> bool:
	var type1 := pokemon.get_type1()
	if type1 != null and type1.id == type_id:
		return true
	var type2 := pokemon.get_type2()
	return type2 != null and type2.id == type_id
