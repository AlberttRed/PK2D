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
	
	# Si no hay movimientos disponibles, pasar turno
	if moves.is_empty():
		return BattlePassChoice.new()
	
	# Obtener enemigos activos
	var enemies = pokemon.get_opponent_side().get_active_pokemons()
	
	# Si no hay enemigos (situación extraña), usar movimiento aleatorio
	if enemies.is_empty():
		return await _select_random_move(pokemon, moves)
	
	# Usar el método común de la clase base para evaluar combinaciones
	var best_choice = evaluate_best_move_target_combination(moves, enemies)
	
	# Crear la elección de movimiento
	var choice = BattleMoveChoice.new()
	choice.move_index = best_choice.move_index
	choice.pokemon = pokemon
	
	# Configurar los objetivos del movimiento
	var move = moves[best_choice.move_index]
	var target_handler = BattleTarget.new(move)
	
	# Si el movimiento requiere selección manual de objetivo, pre-seleccionarlo
	if best_choice.has("target_spot") and best_choice.target_spot != null:
		target_handler.set_manual_target(best_choice.target_spot)
	else:
		# Para movimientos multi-objetivo o auto-target
		await target_handler.select_targets()
	
	choice.target_handler = target_handler
	
	return choice

## Selecciona un movimiento aleatorio como fallback.
func _select_random_move(pokemon: BattlePokemon, moves: Array[BattleMove]) -> BattleChoice:
	var index = randi() % moves.size()
	var move = moves[index]
	
	var choice = BattleMoveChoice.new()
	choice.move_index = index
	choice.pokemon = pokemon
	
	var target_handler = BattleTarget.new(move)
	await target_handler.select_targets()
	choice.target_handler = target_handler
	
	return choice

