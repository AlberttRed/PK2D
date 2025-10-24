extends BattleMoveHandler

class_name BattleAilmentMoveHandler

var _is_valid: bool = false
var ailment: AilmentData = null

func _init(_move, _user, _target, _category = null):
	super._init(_move, _user, _target, _category)
	ailment = _move.get_ailment()

func _apply() -> void:
	if ailment == null or target.get_pokemon() == null:
		return
	if randf() >= move.get_ailment_chance():
		return
	
	_is_valid = _check_is_valid()

	if not _is_valid:
		return
	
	var effect_instance = ailment.get_effect(move.get_min_turns(), move.get_max_turns())
	if effect_instance != null:
		BattleEffectController.add_pokemon_effect(target.get_pokemon(), effect_instance)

	if ailment.is_persistent:
		target.get_pokemon().set_status(ailment)

func _visualize(ui) -> void:
	if ailment == null or target.get_pokemon() == null:
		return
	if not _is_valid:
		await ui.show_already_effect_message(MessageFamily.Values.AILMENT, target.get_pokemon(), ailment.id, ailment.is_persistent and target.get_pokemon().status != ailment)
		return
	await ui.show_start_effect_message(MessageFamily.Values.AILMENT, target.get_pokemon(), ailment.id)
	
	# Asegurar actualización de icono de estado en la barra de HP
	target.get_pokemon().status_changed.emit()

func _check_is_valid() -> bool:
	var effect_proto = ailment.get_effect() if ailment.effect != null else null
	var was_repeated := BattleEffectController.has_effect_for(target.get_pokemon(), effect_proto)
	var persistent_blocked: bool = ailment.is_persistent and target.get_pokemon().status != null and target.get_pokemon().status != ailment
	return not was_repeated and not persistent_blocked
