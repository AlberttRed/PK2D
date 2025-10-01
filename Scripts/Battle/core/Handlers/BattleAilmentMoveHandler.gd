extends BattleMoveHandler

class_name BattleAilmentMoveHandler

var _is_valid: bool = false

func _init(_move, _user, _target, _category = null):
	super._init(_move, _user, _target, _category)

func apply() -> void:
	var ailment: Ailment = move.get_ailment()
	if ailment == null:
		return
	if randf() >= move.get_ailment_chance():
		return

	_is_valid =_check_is_valid(ailment)

	if not _is_valid:
		return

	var effect_instance = ailment.get_effect(move.get_min_turns(), move.get_max_turns())
	if effect_instance != null:
		BattleEffectController.add_pokemon_effect(target, effect_instance)
	if ailment.is_persistent:
		target.set_status(ailment)

func visualize(ui) -> void:
	if not _is_valid:
		var ail: Ailment = move.get_ailment()
		if ail != null:
			await ui.show_already_ailment_message(target, ail, ail.is_persistent and target.status != ail)
		return
	await ui.show_start_ailment_message(target, move.get_ailment())
	# Asegurar actualización de icono de estado en la barra de HP
	if target != null:
		target.status_changed.emit()

func _check_is_valid(ailment: Ailment) -> bool:
	var effect_proto = ailment.get_effect() if ailment.effect != null else null
	var was_repeated := BattleEffectController.has_effect_for(target, effect_proto)
	var persistent_blocked: bool = ailment.is_persistent and target.status != null and target.status != ailment
	return not was_repeated and not persistent_blocked
