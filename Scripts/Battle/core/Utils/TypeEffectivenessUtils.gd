class_name TypeEffectivenessUtils

static func get_multiplier(attack_type: Type, def_type1: Type, def_type2: Type = null) -> float:
	var mult1 = _get_vs(attack_type, def_type1)
	var mult2 = _get_vs(attack_type, def_type2) if def_type2 != null else 1.0
	return mult1 * mult2

static func _get_vs(attack_type: Type, defense_type: Type) -> float:
	return attack_type.get_effectiveness_against(defense_type)
	#if defense_type in attack_type.no_effect_to:
		#return 0.0
	#if defense_type in attack_type.super_effective:
		#return 2.0
	#if defense_type in attack_type.resistance:
		#return 0.5
	#return 1.0
