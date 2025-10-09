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

	# Si el movimiento afecta al campo o a un lado, ejecutamos un único handler
	var target_type := move.base_data.get_target_id() as BattleTarget.TYPE
	if _is_field_or_side_target(target_type):
		var category_field: BattleMoveCategory = move.get_category() if move.has_method("get_category") else null
		if category_field != null:
			# Pasamos un target cualquiera (o null) porque el handler de campo no depende del objetivo
			var any_target: BattlePokemon = null
			if not targets.is_empty() and targets[0] and targets[0].has_active_pokemon():
				any_target = targets[0].get_active_pokemon()
			var field_handler := category_field.create_handler(move, pokemon, any_target)
			if field_handler != null:
				handlers.append(field_handler)
		else:
			print("No category found for move: " + move.get_name())
		return handlers

	# Para el resto de movimientos, iterar por cada objetivo y aplicar precisión si corresponde
	for spot in targets:
		var target := spot.get_active_pokemon()

		# Movimientos con precisión <= 0 no hacen chequeo (auto-hit)
		if move.get_accuracy() > 0 and not AccuracyUtils.check_hit(move, pokemon, target):
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


# Devuelve true si el tipo de target representa efectos de campo o de lado
func _is_field_or_side_target(t: BattleTarget.TYPE) -> bool:
	return t == BattleTarget.TYPE.ALL_FIELD \
		or t == BattleTarget.TYPE.PLAYERS \
		or t == BattleTarget.TYPE.ENEMIES
