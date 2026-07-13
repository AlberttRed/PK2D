class_name DamageCalculator_Gen5
extends RefCounted

static func calculate(move: BattleMove, user: BattlePokemon, target: BattlePokemon) -> DamageEffect:
	user = user.get_active_battle_pokemon() if user != null else null
	target = target.get_active_battle_pokemon() if target != null else null
	var atk_stat = StatsEnum.Values.SP_ATTACK if move.is_special_category() else StatsEnum.Values.ATTACK
	var def_stat = StatsEnum.Values.SP_DEFENSE if move.is_special_category() else StatsEnum.Values.DEFENSE

	var atk = user.get_modified_stat(atk_stat)
	var def = target.get_modified_stat(def_stat)
	var level = user.get_level()
	var power = move.get_power()
	var is_struggle := move.get_id() == MovesEnum.Values.STRUGGLE

	# Aplicar modificadores de potencia (atacante, globales)
	var power_data = ModifierEngine.apply_power(move, user, target, power)
	power = power_data.power

	# Paso 1: Daño base
	var base = (((2 * level / 5.0 + 2) * power * atk / def) / 50.0) + 2

	# Paso 2: STAB (Forcejeo es typeless en Gen 5)
	var stab := 1.0
	if not is_struggle:
		stab = 1.5 if move.get_type() == user.get_type1() or move.get_type() == user.get_type2() else 1.0

	# Paso 3: Crítico
	var is_crit = is_critical_hit(move.get_critical_rate())
	var crit = 2.0 if is_crit else 1.0

	# Paso 4: Efectividad (Forcejeo siempre ×1)
	var effectiveness := 1.0
	if not is_struggle:
		effectiveness = TypeEffectivenessUtils.get_multiplier(
			move.get_type(), target.get_type1(), target.get_type2()
		)

	# Paso 5: Variación aleatoria
	var random_value = randi_range(217, 255)
	var random_factor = float(random_value) / 255.0

	# Paso 6: Daño final
	var total = floor(base * stab * crit * effectiveness * random_factor)

	# Paso 7: Crear DamageEffect y aplicar daño mínimo 1 antes de modificadores finales
	var effect := DamageEffect.new(user, target, move, int(total))
	effect.effectiveness = effectiveness
	effect.is_critical = is_crit && !effect.is_ineffective()
	effect.is_stab = (stab > 1.0)
	effect.validate()

	# Paso 8: Modificadores de daño final (defensor, globales); pueden reducir a 0
	var final_mods = ModifierEngine.apply_final_damage_with_log(effect)
	log_damage_calculation(effect, final_mods)
	return effect

static func get_crit_chance(stage: int) -> float:
	match clamp(stage, 0, 3):
		0: return 1.0 / 16.0  # Gen 5: 1/16 por defecto
		1: return 1.0 / 8.0
		2: return 1.0 / 2.0
		_: return 1.0

static func is_critical_hit(stage: int) -> bool:
	return randf() < get_crit_chance(stage)


static func log_damage_calculation(effect: DamageEffect, final_mods: Array = []) -> void:
	var user = effect.user
	var target = effect.target
	var move = effect.move
	var total = effect.amount

	var atk_stat = StatsEnum.Values.SP_ATTACK if move.is_special_category() else StatsEnum.Values.ATTACK
	var def_stat = StatsEnum.Values.SP_DEFENSE if move.is_special_category() else StatsEnum.Values.DEFENSE

	var atk_final = user.get_final_stat(atk_stat)
	var atk_mod = user.get_modified_stat(atk_stat)
	var def_final = target.get_final_stat(def_stat)
	var def_mod = target.get_modified_stat(def_stat)
	var user_level = user.get_level()
	var target_level = target.get_level()
	var base_power = move.get_power()
	var power_data = apply_power_modifiers(move, user, target, base_power)
	var power = power_data.power
	var modifiers = power_data.modifiers

	# (Opcional) Calcular y mostrar modificadores de precisión si tu flujo los usa antes del cálculo de impacto
	# var acc_data = ModifierEngine.apply_accuracy(move, user, target, move.get_accuracy())
	# var acc_mods = acc_data.modifiers

	var stab = 1.5 if move.get_type() == user.get_type1() or move.get_type() == user.get_type2() else 1.0
	var crit = 2.0 if effect.is_critical else 1.0
	var effectiveness = effect.effectiveness

	var base = (((2 * user_level / 5.0 + 2) * power * atk_mod / def_mod) / 50.0) + 2

	print("===== DAMAGE LOG =====")
	var power_display = str(base_power)
	if base_power != power:
		# Mostrar qué efectos modificaron la potencia
		var modifier_names = []
		for mod in modifiers:
			var sign_str = "+" if mod.multiplier > 1.0 else ""
			var percent_change = (mod.multiplier - 1.0) * 100.0
			modifier_names.append("%s (%s%.0f%%)" % [mod.name, sign_str, percent_change])
		power_display = "%d → %d (%s)" % [base_power, power, ", ".join(modifier_names)]

	print("Movimiento: %s | Potencia: %s | Clase de daño: %s" %
		[move.get_name(), power_display, get_damage_class_string(move.get_damage_class())])
	print("Atacante: %s (Nivel %d)" % [user.get_display_name(), user_level])
	print("  - Stat base: %d → modificado (stages): %.2f" % [atk_final, atk_mod])

	if user.nature:
		var nature = user.nature
		var mult = nature.get_stat_multiplier(atk_stat)
		var icon = "↑" if mult > 1.0 else "↓" if mult < 1.0 else "–"
		var stat_name = StatsEnum.get_display_name(atk_stat).capitalize()
		print("  - Naturaleza: %s | %s %s (%.1fx)" % [nature.display_name, icon, stat_name, mult])

	print("Defensor: %s (Nivel %d)" % [target.get_display_name(), target_level])
	print("  - Stat base: %d → modificado (stages): %.2f" % [def_final, def_mod])

	if target.nature:
		var nature = target.nature
		var mult = nature.get_stat_multiplier(def_stat)
		var icon = "↑" if mult > 1.0 else "↓" if mult < 1.0 else "–"
		var stat_name = StatsEnum.get_display_name(def_stat).capitalize()
		print("  - Naturaleza: %s | %s %s (%.1fx)" % [nature.display_name, icon, stat_name, mult])

	print("STAB: %.1f | Crítico: %s | Efectividad: %.1f" %
		[stab, str(effect.is_critical), effectiveness])
	print("Daño final calculado: %d" % total)
	if final_mods and not final_mods.is_empty():
		var mods_strings := []
		for m in final_mods:
			var sign_str = "+" if m.multiplier > 1.0 else ""
			var percent_change = (m.multiplier - 1.0) * 100.0
			mods_strings.append("%s (%s%.0f%%)" % [m.name, sign_str, percent_change])
		print("Modificadores de daño final: %s" % ", ".join(mods_strings))

	# Mostrar los 39 posibles daños con su frecuencia
	var damage_counts := {}
	for i in range(217, 256):
		var factor := float(i) / 255.0
		var dmg := int(floor(base * stab * crit * effectiveness * factor))
		damage_counts[dmg] = damage_counts.get(dmg, 0) + 1

	var sorted_keys := damage_counts.keys()
	sorted_keys.sort()
	var damage_strings := []
	for dmg in sorted_keys:
		var count = damage_counts[dmg]
		damage_strings.append("%d (x%d)" % [dmg, count])

	print("Possible damage amounts: %s" % ", ".join(damage_strings))
	print("========================")


# Aplica modificadores de efectos activos al poder del movimiento
# Retorna un Dictionary con {power: int, modifiers: Array[Dictionary]}
static func apply_power_modifiers(move: BattleMove, user: BattlePokemon, target: BattlePokemon, base_power: int) -> Dictionary:
	# Retrocompat: delega al motor nuevo
	return ModifierEngine.apply_power(move, user, target, base_power)

# Convierte nombres de efectos de CamelCase a formato legible
static func _format_effect_name(name: String) -> String:
	# Casos especiales primero
	if name == "RainWeatherEffect":
		return "Lluvia"
	if name == "SunWeatherEffect":
		return "Sol"
	if name == "SandstormWeather":
		return "Tormenta de Arena"
	if name == "HailWeatherEffect":
		return "Granizo"

	# Para otros casos, intentar convertir de CamelCase
	var result = ""
	for i in range(name.length()):
		var c = name[i]
		if c == c.to_upper() and i > 0:
			result += " "
		result += c
	return result


static func get_damage_class_string(cls: BattleMove.DamageClass) -> String:
	match cls:
		BattleMove.DamageClass.PHYSIC: return "Físico"
		BattleMove.DamageClass.SPECIAL: return "Especial"
		BattleMove.DamageClass.STATUS: return "Estado"
		_: return "Desconocido"
