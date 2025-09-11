class_name DamageCalculator_Gen5
extends RefCounted

static func calculate(move: BattleMove, user: BattlePokemon, target: BattlePokemon) -> DamageEffect:
	var atk_stat = StatTypes.Stat.SP_ATTACK if move.is_special_category() else StatTypes.Stat.ATTACK
	var def_stat = StatTypes.Stat.SP_DEFENSE if move.is_special_category() else StatTypes.Stat.DEFENSE

	var atk = user.get_modified_stat(atk_stat)
	var def = target.get_modified_stat(def_stat)
	var level = user.get_level()
	var power = move.get_power()

	# Paso 1: Daño base
	var base = (((2 * level / 5 + 2) * power * atk / def) / 50) + 2

	# Paso 2: STAB
	var stab = 1.5 if move.get_type() == user.get_type1() or move.get_type() == user.get_type2() else 1.0

	# Paso 3: Crítico
	var is_crit = is_critical_hit(move.get_critical_rate())
	var crit = 1.5 if is_crit else 1.0

	# Paso 4: Efectividad
	var effectiveness = TypeEffectivenessUtils.get_multiplier(
		move.get_type(), target.get_type1(), target.get_type2()
	)

	# Paso 5: Variación aleatoria
	var random_value = randi_range(217, 255)
	var random_factor = float(random_value) / 255.0
	
	# Paso 6: Daño final
	var total = floor(base * stab * crit * effectiveness * random_factor)

	# Paso 7: Crear DamageEffect
	var effect := DamageEffect.new(user, target, move, int(total))
	effect.effectiveness = effectiveness
	effect.is_critical = is_crit && !effect.is_ineffective()
	log_damage_calculation(effect)
	return effect

static func get_crit_chance(stage: int) -> float:
	match clamp(stage, 0, 3):
		0: return 1.0 / 24.0
		1: return 1.0 / 8.0
		2: return 1.0 / 2.0
		_: return 1.0

static func is_critical_hit(stage: int) -> bool:
	return randf() < get_crit_chance(stage)


static func log_damage_calculation(effect: DamageEffect) -> void:
	var user = effect.user
	var target = effect.target
	var move = effect.move
	var total = effect.amount

	var atk_stat = StatTypes.Stat.SP_ATTACK if move.is_special_category() else StatTypes.Stat.ATTACK
	var def_stat = StatTypes.Stat.SP_DEFENSE if move.is_special_category() else StatTypes.Stat.DEFENSE

	var atk_final = user.get_final_stat(atk_stat)
	var atk_mod = user.get_modified_stat(atk_stat)
	var def_final = target.get_final_stat(def_stat)
	var def_mod = target.get_modified_stat(def_stat)
	var user_level = user.get_level()
	var target_level = target.get_level()
	var power = move.get_power()

	var stab = 1.5 if move.get_type() == user.get_type1() or move.get_type() == user.get_type2() else 1.0
	var crit = 1.5 if effect.is_critical else 1.0
	var effectiveness = effect.effectiveness

	var base = (((2 * user_level / 5 + 2) * power * atk_mod / def_mod) / 50) + 2

	print("===== DAMAGE LOG =====")
	print("Movimiento: %s | Potencia: %d | Clase de daño: %s" %
		[move.get_name(), power, get_damage_class_string(move.get_damage_class())])
	print("Atacante: %s (Nivel %d)" % [user.get_display_name(), user_level])
	print("  - Stat base: %d → modificado (stages): %.2f" % [atk_final, atk_mod])

	if user.nature:
		var nature = user.nature
		var mult = nature.get_stat_multiplier(atk_stat)
		var icon = "↑" if mult > 1.0 else "↓" if mult < 1.0 else "–"
		var stat_name = StatTypes.stat_to_string(atk_stat).capitalize()
		print("  - Naturaleza: %s | %s %s (%.1fx)" % [nature.display_name, icon, stat_name, mult])

	print("Defensor: %s (Nivel %d)" % [target.get_display_name(), target_level])
	print("  - Stat base: %d → modificado (stages): %.2f" % [def_final, def_mod])

	if target.nature:
		var nature = target.nature
		var mult = nature.get_stat_multiplier(def_stat)
		var icon = "↑" if mult > 1.0 else "↓" if mult < 1.0 else "–"
		var stat_name = StatTypes.stat_to_string(def_stat).capitalize()
		print("  - Naturaleza: %s | %s %s (%.1fx)" % [nature.display_name, icon, stat_name, mult])

	print("STAB: %.1f | Crítico: %s | Efectividad: %.1f" %
		[stab, str(effect.is_critical), effectiveness])
	print("Daño final calculado: %d" % total)

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



static func get_damage_class_string(cls: BattleMove.DamageClass) -> String:
	match cls:
		BattleMove.DamageClass.PHYSIC: return "Físico"
		BattleMove.DamageClass.SPECIAL: return "Especial"
		BattleMove.DamageClass.STATUS: return "Estado"
		_: return "Desconocido"
