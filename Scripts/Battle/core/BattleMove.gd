class_name BattleMove
extends RefCounted

enum DamageClass {
	STATUS = 1,
	PHYSIC = 2,
	SPECIAL = 3	
}

enum MoveCategory {
	DAMAGE,
	AILMENT,
	NET_GOOD_STATS,
	HEAL,
	DAMAGE_AILMENT,
	SWAGGER,
	DAMAGE_LOWER,
	DAMAGE_RAISE,
	DAMAGE_HEAL,
	OHKO,
	WHOLE_FIELD_EFFECT,
	FIELD_EFFECT,
	FORCE_SWITCH,
	UNIQUE
}

var base_data: MoveInstance
var pokemon: BattlePokemon

func _init(_base_data: MoveInstance, _pokemon: BattlePokemon):
	self.base_data = _base_data
	self.pokemon = _pokemon

func get_name() -> String:
	return base_data.Name

func get_type() -> Type:
	return base_data.type as Type

func get_type_name() -> String:
	return base_data.type.Name

func get_damage_class() -> DamageClass:
	return base_data.damage_class as DamageClass

func is_physic_category():
	return get_damage_class() == DamageClass.PHYSIC

func is_special_category():
	return get_damage_class() == DamageClass.SPECIAL
	
func is_status_category():
	return get_damage_class() == DamageClass.STATUS

func get_pp() -> int:
	return base_data.pp_actual

func get_total_pp() -> int:
	return base_data.pp

func get_power() -> int:
	return base_data.power

func get_accuracy() -> int:
	return base_data.accuracy

func is_depleted() -> bool:
	return base_data.pp_actual <= 0

func get_priority() -> int:
	return base_data.priority
	
func get_category() -> MoveCategory:
	return base_data.get_category_id()
	
func get_drain_percentage() -> int:
	return base_data.get_drain_percentage()

func get_heal_amount() -> int:
	return base_data.get_heal_amount()

func get_number_of_hits() -> int:
	var min_hits = get_min_hits()
	var max_hits = get_max_hits()

	if min_hits >= max_hits:
		return min_hits # por seguridad, o ataques normales

	# Para el caso específico de 2 a 5 golpes, usamos distribución oficial
	if min_hits == 2 and max_hits == 5:
		var roll = randi_range(1, 100)
		if roll <= 35:
			return 2
		elif roll <= 70:
			return 3
		elif roll <= 85:
			return 4
		else:
			return 5

	# En otros casos (ej: 2–3 golpes), elegimos al azar dentro del rango
	return randi_range(min_hits, max_hits)

func is_multi_hit() -> bool:
	return base_data.get_max_hits() > 1
	
func get_max_hits() -> int:
	return base_data.get_max_hits()

func get_min_hits() -> int:
	return base_data.get_min_hits()

func get_max_turns() -> int:
	return base_data.get_max_turns()

func get_min_turns() -> int:
	return base_data.get_min_turns()
	
func get_critical_rate() -> int:
	return base_data.get_critical_rate()
	
func get_category_logic() -> MoveCategoryLogic:
	match get_category():
		MoveCategory.DAMAGE:
			return MoveCategoryDamage.new()
		MoveCategory.AILMENT:
			return MoveCategoryAilment.new()
		MoveCategory.NET_GOOD_STATS:
			return MoveCategoryNetGoodStats.new()
		MoveCategory.HEAL:
			return MoveCategoryHeal.new()
		MoveCategory.DAMAGE_AILMENT:
			return MoveCategoryDamageAilment.new()
		MoveCategory.SWAGGER:
			return MoveCategorySwagger.new()
		MoveCategory.DAMAGE_LOWER:
			return MoveCategoryDamageLower.new()
		MoveCategory.DAMAGE_RAISE:
			return MoveCategoryDamageRaise.new()
		MoveCategory.DAMAGE_HEAL:
			return MoveCategoryDamageHeal.new()
		MoveCategory.OHKO:
			return MoveCategoryOhko.new()
		MoveCategory.WHOLE_FIELD_EFFECT:
			return MoveCategoryWholeFieldEffect.new()
		MoveCategory.FIELD_EFFECT:
			return MoveCategoryFieldEffect.new()
		MoveCategory.FORCE_SWITCH:
			return MoveCategoryForceSwitch.new()
		MoveCategory.UNIQUE:
			return MoveCategoryUnique.new()
		_:
			push_warning("Move category no implementada: %s" % str(get_category()))
			return MoveCategoryLogic.new()

func get_ailment() -> Ailment:
	return base_data.get_ailment()
	
func get_ailment_chance() -> float:
	return 100.0 if base_data.get_ailment_chance() == 0 else (float(base_data.get_ailment_chance()) / 100.0)

func get_stat_changes() -> Dictionary[StatTypes.Stat, int]:
	return base_data.get_stat_changes()

func get_stat_change_value(stat: StatTypes.Stat) -> int:
	return get_stat_changes()[stat]

func get_effectiveness_against_pokemon(target: BattlePokemon) -> float:
	return get_type().get_effectiveness_against_pokemon(target)


# Calcula el daño infligido a un objetivo según la generación activa
func calculate_damage(target: BattlePokemon) -> DamageEffect:
	assert(pokemon != null, "El movimiento no tiene asignado un 'pokemon' (usuario)")
	return DamageCalculator_Gen5.calculate(self, pokemon, target)


# Calcula la curación para este movimiento (puede ser auto-curación o por drenaje)
func calculate_healing(target: BattlePokemon, damage_taken: int = 0) -> MoveImpactResult.Heal:
	assert(pokemon != null, "El movimiento no tiene asignado un 'pokemon' (usuario)")
	return HealingCalculator.calculate(self, pokemon, target, damage_taken)


# Placeholder para más adelante
func apply(target: BattleSpot):
	pass
