extends BattleMoveHandler

class_name BattleAilmentMoveHandler

var _apply_result: int = ApplyFailReason.Values.SKIPPED
var _effect_instance: PersistentBattleEffect = null
var ailment: AilmentData = null

func _init(_move, _user, _target, _category = null):
	super._init(_move, _user, _target, _category)
	ailment = _move.get_ailment()
	if ailment != null and ailment.effect != null:
		_effect_instance = ailment.get_effect(move.get_min_turns(), move.get_max_turns())
		_bind_effect_context(_effect_instance)

func _apply() -> void:
	if ailment == null or target.get_pokemon() == null:
		return
	if not BattleDebugAilmentTest.force_ailment_apply and randf() >= move.get_ailment_chance():
		return

	_apply_result = _validate_ailment_apply(ailment, _effect_instance)
	if not ApplyFailReason.is_success(_apply_result):
		return

	if _effect_instance != null:
		BattleEffectController.add_pokemon_effect(target.get_pokemon(), _effect_instance)

	if ailment.is_persistent:
		target.get_pokemon().set_status(ailment)

func _visualize(ui) -> void:
	if ailment == null or target.get_pokemon() == null:
		return
	if _apply_result == ApplyFailReason.Values.SKIPPED:
		return
	if not ApplyFailReason.is_success(_apply_result):
		await ui.show_already_effect_message(
			MessageFamily.Values.AILMENT,
			target.get_pokemon(),
			ailment.get_enum_value(),
			ApplyFailReason.uses_generic_fail_message(_apply_result)
		)
		return
	await ui.show_start_effect_message(MessageFamily.Values.AILMENT, target.get_pokemon(), ailment.get_enum_value())

	target.get_pokemon().status_changed.emit()
