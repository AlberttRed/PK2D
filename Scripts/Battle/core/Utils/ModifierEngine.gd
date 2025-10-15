class_name ModifierEngine
extends RefCounted

static func apply_power(move: BattleMove, user: BattlePokemon, target: BattlePokemon, base_power: int) -> Dictionary:
	var modified_power := float(base_power)
	var modifiers_applied := []

	# Usar una sola fuente: incluye efectos del atacante, side y campo
	var effects = BattleEffectController.get_all_effects_for(user)
	for effect in effects:
		if effect.has_method("on_power"):
			var old_power = modified_power
			modified_power = effect.on_power(move, user, target, modified_power)
			if modified_power != old_power:
				modifiers_applied.append(_mod_name(effect, modified_power / old_power))

	return { "power": int(modified_power), "modifiers": modifiers_applied }

static func apply_accuracy(move: BattleMove, user: BattlePokemon, target: BattlePokemon, base_accuracy: int) -> Dictionary:
	var modified_accuracy := float(base_accuracy)
	var modifiers_applied := []

	var effects = BattleEffectController.get_all_effects_for(user)
	for effect in effects:
		if effect.has_method("on_accuracy"):
			var old_acc = modified_accuracy
			modified_accuracy = effect.on_accuracy(move, user, target, modified_accuracy)
			if modified_accuracy != old_acc:
				modifiers_applied.append(_mod_name(effect, modified_accuracy / old_acc))

	return { "accuracy": int(modified_accuracy), "modifiers": modifiers_applied }

static func apply_final_damage(effect: DamageEffect) -> void:
	# Usar una sola fuente: incluye efectos del defensor, side y campo
	var effects = BattleEffectController.get_all_effects_for(effect.target)
	for e in effects:
		if e.has_method("on_damage"):
			e.on_damage(effect)

static func apply_final_damage_with_log(effect: DamageEffect) -> Array:
	var applied := []
	var effects = BattleEffectController.get_all_effects_for(effect.target)
	for e in effects:
		if e.has_method("on_damage"):
			var old := float(effect.amount)
			e.on_damage(effect)
			if float(effect.amount) != old:
				applied.append(_mod_name(e, float(effect.amount) / old))
	return applied

static func _mod_name(effect, multiplier: float) -> Dictionary:
	var effect_name = "Efecto desconocido"
	if effect.get_script() and effect.get_script().get_global_name():
		effect_name = effect.get_script().get_global_name()
	if effect_name.ends_with("Effect"):
		effect_name = effect_name.substr(0, effect_name.length() - 6)
	return { "name": _format_effect_name(effect_name), "multiplier": multiplier }

static func _format_effect_name(name: String) -> String:
	var result = ""
	for i in range(name.length()):
		var c = name[i]
		if c == c.to_upper() and i > 0:
			result += " "
		result += c
	return result
