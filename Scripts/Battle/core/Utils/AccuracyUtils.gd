class_name AccuracyUtils

## Tirada global de precisión: una sola vez por movimiento.
## Usa precisión base + modificadores globales del usuario (accuracy stage).
static func roll_global_accuracy(move: BattleMove, user: BattlePokemon) -> bool:
	if move.get_id() == MovesEnum.Values.STRUGGLE:
		return true
	var base_accuracy := move.get_accuracy()
	if base_accuracy <= 0:
		return true
	var acc_mod := get_stage_modifier(user.stat_stages.get_stat(StatsEnum.Values.ACCURACY))
	var final_accuracy := base_accuracy * acc_mod
	return randf() * 100.0 < final_accuracy


## Resolución individual por target sin repetir la tirada global.
static func check_target_hit(move: BattleMove, _user: BattlePokemon, target: BattleTarget) -> HitResult.Values:
	if not target.is_valid():
		return HitResult.Values.NO_TARGET

	if not target.is_pokemon():
		return HitResult.Values.HIT

	var target_pokemon := target.get_pokemon()
	if target_pokemon == null:
		return HitResult.Values.NO_TARGET

	if _is_target_immune(move, target_pokemon):
		return HitResult.Values.IMMUNE

	if move.get_accuracy() > 0 and _target_evades(target_pokemon):
		return HitResult.Values.EVADED

	return HitResult.Values.HIT


## Compatibilidad: combina tirada global y evaluación por target.
static func check_hit(move: BattleMove, user: BattlePokemon, target: BattlePokemon) -> bool:
	if not roll_global_accuracy(move, user):
		return false
	var battle_target := BattleTarget.new(target)
	return check_target_hit(move, user, battle_target) == HitResult.Values.HIT


static func get_stage_modifier(stage: int) -> float:
	stage = clamp(stage, -6, 6)
	if stage >= 0:
		return (3.0 + stage) / 3.0
	else:
		return 3.0 / (3.0 - stage)


static func _target_evades(target: BattlePokemon) -> bool:
	var eva_mod := get_stage_modifier(target.stat_stages.get_stat(StatsEnum.Values.EVASION))
	if eva_mod <= 1.0:
		return false
	return randf() >= (1.0 / eva_mod)


static func _is_target_immune(move: BattleMove, target: BattlePokemon) -> bool:
	if target == null or move.is_status_category():
		return false
	if move.get_id() == MovesEnum.Values.STRUGGLE:
		return false
	return TypeEffectivenessUtils.get_multiplier(
		move.get_type(), target.get_type1(), target.get_type2()
	) == 0.0
