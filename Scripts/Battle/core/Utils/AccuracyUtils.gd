class_name AccuracyUtils

static func check_hit(move: BattleMove, user: BattlePokemon, target: BattlePokemon) -> bool:
	if move.get_id() == MovesEnum.Values.STRUGGLE:
		return true
	var base_accuracy = move.get_accuracy()
	# Movimientos sin precisión (0) siempre impactan: usados para efectos de campo/side
	if base_accuracy <= 0 or !target:
		return true
	var acc_mod = get_stage_modifier(user.accuracy_stage)
	var eva_mod = get_stage_modifier(target.evasion_stage)

	var final_accuracy = base_accuracy * acc_mod / eva_mod

	return randf() * 100.0 < final_accuracy



static func get_stage_modifier(stage: int) -> float:
	stage = clamp(stage, -6, 6)
	if stage >= 0:
		return (3.0 + stage) / 3.0
	else:
		return 3.0 / (3.0 - stage)
