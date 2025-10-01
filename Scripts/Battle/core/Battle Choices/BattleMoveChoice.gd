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
		return target_handler.selected_targets
	return []
	
func get_priority() -> int:
	return get_move().get_priority() if get_move() != null else 0

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

func resolve() -> Array[BattleHandler]:
	var handlers: Array[BattleHandler] = []
	var targets = target_handler.selected_targets if target_handler else []

	if targets.is_empty():
		return handlers

	var move := get_move()

	for spot in targets:
		var target := spot.get_active_pokemon()

		if not AccuracyUtils.check_hit(move, pokemon, target):
			handlers.append(MissHandler.new(pokemon))
			continue

		var category: BattleMoveCategory = move.get_category() if move.has_method("get_category") else null
		if category != null:
			var handler := category.create_handler(move, pokemon, target)
			if handler != null:
				handlers.append(handler)
		else:
			print("No category found for move: " + move.get_name())

	return handlers
