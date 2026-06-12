extends BattleMoveHandler

class_name BattleDamageAilmentMoveHandler

var damage: DamageEffect = null
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
	# 1) Daño
	if target.get_pokemon() == null:
		return
	damage = move.calculate_damage(target.get_pokemon())
	show_effectiveness = (damage.effectiveness != 1.0)
	damage.apply()

	# Si el daño fue inefectivo, el objetivo se debilitó, no hay estado asociado o no supera la probabilidad,
	# salimos temprano y no intentamos aplicar el ailment.
	if damage == null or damage.is_ineffective() or target.get_pokemon().is_fainted() or ailment == null \
			or (not BattleDebugAilmentTest.force_ailment_apply and randf() >= move.get_ailment_chance()):
		return
	# 2) Estado
	_apply_result = _validate_ailment_apply(ailment, _effect_instance)
	if ApplyFailReason.is_success(_apply_result):
		if _effect_instance != null:
			BattleEffectController.add_pokemon_effect(target.get_pokemon(), _effect_instance)
		if ailment.is_persistent:
			target.get_pokemon().set_status(ailment)

func _visualize(ui) -> void:
	# Visualizar daño
	if damage != null:
		await damage.visualize(ui)
		if damage.is_critical:
			await ui.show_critical_hit_message()
		if show_effectiveness:
			await ui.show_effectiveness_message(damage)

	# Visualizar estado: solo si se aplicó (fallos de ailment en daño+estado no muestran mensaje).
	if not ApplyFailReason.is_success(_apply_result) or ailment == null or target.get_pokemon() == null:
		return
	await ui.show_start_effect_message(MessageFamily.Values.AILMENT, target.get_pokemon(), ailment.get_enum_value())
	target.get_pokemon().status_changed.emit()
