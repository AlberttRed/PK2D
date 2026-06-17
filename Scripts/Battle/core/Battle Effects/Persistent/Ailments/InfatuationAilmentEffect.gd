class_name InfatuationAilmentEffect
extends PersistentBattleEffect

const BLOCK_CHANCE: float = 0.5

var _finished: bool = false


func check_effect_success() -> void:
	effect_success = randf() < BLOCK_CHANCE


func can_apply() -> int:
	if target != null and BattleEffectController.has_effect_for(target, self):
		return ApplyFailReason.Values.GENERIC_FAIL
	if not _are_opposite_genders(user, target):
		return ApplyFailReason.Values.GENERIC_FAIL
	return ApplyFailReason.Values.OK


static func _are_opposite_genders(a: BattlePokemon, b: BattlePokemon) -> bool:
	if a == null or b == null or a.base_data == null or b.base_data == null:
		return false
	var gender_a: int = a.base_data.gender
	var gender_b: int = b.base_data.gender
	if gender_a == CONST.GENEROS.SIN_GENERO or gender_b == CONST.GENEROS.SIN_GENERO:
		return false
	if gender_a == CONST.GENEROS.NON_SELECTED or gender_b == CONST.GENEROS.NON_SELECTED:
		return false
	return (gender_a == CONST.GENEROS.MACHO and gender_b == CONST.GENEROS.HEMBRA) \
		or (gender_a == CONST.GENEROS.HEMBRA and gender_b == CONST.GENEROS.MACHO)


func _should_end() -> bool:
	return user == null or not user.in_battle or user.is_fainted()


func apply_phase(pokemon: BattlePokemon, phase: Phases, _ctx: BattlePhaseContext = null) -> void:
	if phase != BattleEffect.Phases.ON_BEFORE_MOVE or not pokemon.can_act_this_turn:
		return

	applied = true

	if _should_end():
		_finished = true
		return

	check_effect_success()

	if effect_success:
		pokemon.can_act_this_turn = false


func visualize_phase(pokemon: BattlePokemon, ui: BattleUI, phase: BattleEffect.Phases, _ctx: BattlePhaseContext = null) -> void:
	if phase != BattleEffect.Phases.ON_BEFORE_MOVE or not applied:
		return

	if has_finished():
		await ui.show_end_effect_message(MessageFamily.Values.AILMENT, pokemon, source.id)
		return

	await ui.show_previous_effect_message(MessageFamily.Values.AILMENT, pokemon, source.id, user)

	if effect_success:
		await ui.show_effect_message(MessageFamily.Values.AILMENT, pokemon, source.id)


func has_finished() -> bool:
	return _finished


func get_priority() -> int:
	return 10
