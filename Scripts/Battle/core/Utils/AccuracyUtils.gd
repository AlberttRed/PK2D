class_name AccuracyUtils

static func check_hit(move: BattleMove, user: BattlePokemon, target: BattlePokemon) -> bool:
	var base_accuracy = move.get_accuracy()
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
