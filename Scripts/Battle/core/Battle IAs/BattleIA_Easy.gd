extends BattleIA

class_name BattleIA_Easy

## IA básica para entrenadores de nivel fácil.
##
## Comportamiento: Considera la efectividad de tipos al elegir movimientos y objetivos.
## - Evalúa todas las combinaciones de (movimiento, objetivo) posibles
## - Elige la combinación con mejor efectividad
## - Para movimientos multi-objetivo (ENEMIES, ALL_FIELD, etc.), usa efectividad promedio
## - Si hay empate, elige aleatoriamente entre los mejores
## - No considera otros factores como stats, estado, clima, etc.

func _init():
	difficulty_name = "Easy"
	use_items = false
	can_switch_strategically = false

## Decide la acción del entrenador fácil.
## Elige el mejor par (movimiento, objetivo) basado en efectividad de tipos.
func decide_action(pokemon: BattlePokemon) -> BattleChoice:
	var moves = pokemon.get_available_moves()

	if moves.is_empty():
		return BattlePassChoice.new()

	var struggle := BattleStruggleChoice.create_if_needed(pokemon)
	if struggle != null:
		return struggle

	var legal_indices := get_selectable_move_indices(pokemon)
	if legal_indices.is_empty():
		return BattlePassChoice.new()

	var enemies = pokemon.get_opponent_side().get_active_pokemons()

	if enemies.is_empty():
		return await _select_random_move(pokemon, moves, legal_indices)

	var best_choice = evaluate_best_move_target_combination(moves, enemies, legal_indices)
	
	# Crear la elección de movimiento
	var choice = BattleMoveChoice.new()
	choice.move_index = best_choice.move_index
	choice.pokemon = pokemon
	
	# Configurar los objetivos del movimiento (sin UI) con la lógica
	var move = moves[best_choice.move_index]
	var selector := BattleTargetSelector.new()
	var manual_spot: BattleSpot = best_choice.target_spot if best_choice.has("target_spot") else null
	choice.targets = selector.resolve_targets(move, pokemon, manual_spot)
	
	return choice

## Selecciona un movimiento aleatorio como fallback.
func _select_random_move(
	pokemon: BattlePokemon,
	moves: Array[BattleMove],
	legal_indices: Array[int] = []
) -> BattleChoice:
	var indices := legal_indices
	if indices.is_empty():
		indices = get_selectable_move_indices(pokemon)
	if indices.is_empty():
		var struggle := BattleStruggleChoice.create_if_needed(pokemon)
		if struggle != null:
			return struggle
		return BattlePassChoice.new()
	var index: int = indices[randi() % indices.size()]
	var move = moves[index]
	
	var choice = BattleMoveChoice.new()
	choice.move_index = index
	choice.pokemon = pokemon
	
	var target_handler = BattleTarget.new(move)
	await target_handler.select_targets()
	choice.target_handler = target_handler
	
	return choice

