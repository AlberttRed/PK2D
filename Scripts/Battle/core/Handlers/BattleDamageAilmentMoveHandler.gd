extends BattleMoveHandler

class_name BattleDamageAilmentMoveHandler

var damage: DamageEffect = null
var _ailment_applied: bool = false
var ailment: Ailment = null

func _init(_move, _user, _target, _category = null):
	super._init(_move, _user, _target, _category)
	ailment = _move.get_ailment()
	
func apply() -> void:
	# 1) Daño
	damage = move.calculate_damage(target)
	show_effectiveness = (damage.effectiveness != 1.0)
	damage.apply()
	
	# Si el daño fue inefectivo, el objetivo se debilitó, no hay estado asociado o no supera la probabilidad,
	# salimos temprano y no intentamos aplicar el ailment.
	if damage == null or damage.is_ineffective() or target.is_fainted() or ailment == null or randf() >= move.get_ailment_chance():
		return
	# 2) Estado
	if _check_is_valid():
		var effect_instance = ailment.get_effect(move.get_min_turns(), move.get_max_turns())
		if effect_instance != null:
			BattleEffectController.add_pokemon_effect(target, effect_instance)
		if ailment.is_persistent:
			target.set_status(ailment)
		_ailment_applied = true

func visualize(ui) -> void:
	# Visualizar daño
	if damage != null:
		await damage.visualize(ui)
		if damage.is_critical:
			await ui.show_critical_hit_message()
		if show_effectiveness:
			await ui.show_effectiveness_message(damage)

	# Visualizar estado
	if _ailment_applied:
		await ui.show_start_effect_message(MessageFamily.Values.AILMENT, target, ailment.id)
		# Emitir después de visualizar para refrescar icono sincronizado con la UI
		if target != null:
			target.status_changed.emit()

func _check_is_valid() -> bool:
	var effect_proto = ailment.get_effect() if ailment.effect != null else null
	var repeated := BattleEffectController.has_effect_for(target, effect_proto)
	var blocked: bool = ailment.is_persistent and target.status != null and target.status != ailment
	return not repeated and not blocked
