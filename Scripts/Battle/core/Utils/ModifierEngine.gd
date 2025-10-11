class_name ModifierEngine
extends RefCounted

static func apply_power(move: BattleMove, user: BattlePokemon, target: BattlePokemon, base_power: int) -> Dictionary:
	var modified_power := float(base_power)
	var modifiers_applied := []

	var effects_sets = [
		BattleEffectController.get_all_effects_for(user), # atacante
		BattleEffectController.get_field_effects() # globales
	]
	for effects in effects_sets:
		for effect in effects:
			if effect.has_method("on_power"):
				var old_power = modified_power
				modified_power = effect.on_power(move, user, target, modified_power)
				if modified_power != old_power:
					modifiers_applied.append(_mod_name(effect, modified_power / old_power))

	return { "power": int(modified_power), "modifiers": modifiers_applied }

static func apply_final_damage(effect: DamageEffect) -> void:
	var effects_sets = [
		BattleEffectController.get_all_effects_for(effect.target), # defensor
		BattleEffectController.get_field_effects() # globales
	]
	for effects in effects_sets:
		for e in effects:
			if e.has_method("on_damage"):
				e.on_damage(effect)

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


