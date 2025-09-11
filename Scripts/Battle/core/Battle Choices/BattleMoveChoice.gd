class_name BattleMoveChoice
extends BattleChoice

var move: BattleMove

var move_index: int = -1
var target_handler: BattleTarget = null

func get_move() -> BattleMove:
	if not pokemon or move_index == -1:
		return null
	return pokemon.get_available_moves()[move_index]

func get_targets() -> Array:
	if target_handler:
		return target_handler.selectedTargets
	return []
	
func get_priority() -> int:
	return get_move().get_priority() if get_move() != null else null

func get_main_target():
	if target_handler:
		return target_handler.get_actual_target()
	return null
#
#func resolve() -> Array[ImmediateBattleEffect]:
	#var all_effects: Array[ImmediateBattleEffect] = []
#
	#var targets = target_handler.selected_targets if target_handler else []
	#if targets.is_empty():
		#return all_effects  # Nada que hacer
#
	#var num_hits := get_move().get_number_of_hits()
	#print("Num. hits: " + str(num_hits))
#
	#for spot in targets:
		#var target := spot.get_active_pokemon()
#
		#if not AccuracyUtils.check_hit(get_move(), pokemon, target):
			#all_effects.append(MissEffect.new(pokemon, target))
			#continue
#
		#var logic: MoveCategoryLogic = get_move().get_category_logic()
		#logic.move = get_move()
		#logic.user = pokemon
		#logic.target = target
		#logic.num_hits = num_hits
#
		#for i in num_hits:
			#if target.is_fainted():
				#break
#
			#var effects: Array[ImmediateBattleEffect] = logic.execute()
			#all_effects.append_array(effects)
#
	#return all_effects

func resolve() -> BattleMoveResult:
	var all_effects: Array[ImmediateBattleEffect] = []
	var result := BattleMoveResult.new()
	var targets = target_handler.selected_targets if target_handler else []

	if targets.is_empty():
		return result

	for spot in targets:
		var target := spot.get_active_pokemon()

		if not AccuracyUtils.check_hit(get_move(), pokemon, target):
			all_effects.append(MissEffect.new(pokemon))
			continue

		var num_hits := get_move().get_number_of_hits()

		if num_hits > 1:
			var multi := MultiHitEffect.new(pokemon, target, get_move(), num_hits)
			all_effects.append(multi)
		else:
			var logic = get_move().get_category_logic()
			logic.move = get_move()
			logic.user = pokemon
			logic.target = target
			all_effects.append_array(logic.execute())
	result.effects = all_effects
	return result
