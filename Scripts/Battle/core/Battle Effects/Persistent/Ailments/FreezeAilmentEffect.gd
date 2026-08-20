class_name FreezeAilmentEffect
extends PersistentBattleEffect

func can_apply() -> int:
	var base := super.can_apply()
	if not ApplyFailReason.is_success(base):
		return base
	if target == null:
		return ApplyFailReason.Values.GENERIC_FAIL
	if _has_type(target, TypesEnum.Values.ICE):
		return ApplyFailReason.Values.GENERIC_FAIL
	return ApplyFailReason.Values.OK

func check_effect_success():
	effect_success = randf() < 0.2
	
func apply_phase(pokemon, phase: Phases, _ctx: BattlePhaseContext = null) -> void:
	if phase != BattleEffect.Phases.ON_BEFORE_MOVE:
		return
	if not pokemon.can_act_this_turn:
		return

	check_effect_success()

	pokemon.can_act_this_turn = effect_success

func visualize_phase(pokemon: BattlePokemon, ui: BattleUI, phase: BattleEffect.Phases, _ctx: BattlePhaseContext = null):
	if phase != BattleEffect.Phases.ON_BEFORE_MOVE:
		return

	if effect_success:
		await ui.show_end_effect_message(MessageFamily.Values.AILMENT, pokemon, source.id)
		pokemon.set_status(null)
		pokemon.status_changed.emit()
	else:
		await ui.show_effect_message(MessageFamily.Values.AILMENT, pokemon, source.id)

func get_priority() -> int:
	return BattleEffectPriority.PRE_MOVE_FREEZE

func has_finished():
	return effect_success


static func _has_type(pokemon: BattlePokemon, type_id: int) -> bool:
	var type1 := pokemon.get_type1()
	if type1 != null and type1.id == type_id:
		return true
	var type2 := pokemon.get_type2()
	return type2 != null and type2.id == type_id
