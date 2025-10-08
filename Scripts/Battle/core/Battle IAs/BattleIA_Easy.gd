extends BattleIA

class_name BattleIA_Easy

## IA básica para entrenadores de nivel fácil.
##
## Comportamiento: Considera la efectividad de tipos al elegir movimientos.
## - Calcula la efectividad de cada movimiento contra los enemigos activos
## - Elige el movimiento con mejor efectividad promedio
## - Si hay empate, elige aleatoriamente entre los mejores
## - No considera otros factores como stats, estado, clima, etc.

func _init():
	difficulty_name = "Easy"
	use_items = false
	can_switch_strategically = false

## Decide la acción del entrenador fácil.
## Elige el movimiento más efectivo contra los enemigos activos.
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
	
	# Calcular el mejor movimiento basado en efectividad
	var best_move_index = _find_best_move_by_effectiveness(moves, enemies)
	
	# Crear la elección de movimiento
	var choice = BattleMoveChoice.new()
	choice.move_index = best_move_index
	choice.pokemon = pokemon
	
	# Configurar los objetivos del movimiento
	var move = moves[best_move_index]
	var target_handler = BattleTarget.new(move)
	await target_handler.select_targets()
	choice.target_handler = target_handler
	
	return choice

## Encuentra el índice del mejor movimiento basado en efectividad de tipos.
## Si hay empate, elige aleatoriamente entre los mejores.
func _find_best_move_by_effectiveness(moves: Array[BattleMove], enemies: Array[BattlePokemon]) -> int:
	var effectiveness_scores: Array[float] = []
	
	# Calcular efectividad promedio de cada movimiento contra todos los enemigos
	for move: BattleMove in moves:
		var total_effectiveness := 0.0
		
		for enemy in enemies:
			total_effectiveness += move.get_effectiveness_against_pokemon(enemy)
		
		# Promedio de efectividad contra todos los enemigos
		var avg_effectiveness = total_effectiveness / float(enemies.size())
		effectiveness_scores.append(avg_effectiveness)
	
	# Encontrar la mejor efectividad
	var best_effectiveness: float = effectiveness_scores.max()
	
	# Si todos los movimientos tienen efectividad 0 (inmunes), elegir aleatorio
	if best_effectiveness <= 0.0:
		return randi() % moves.size()
	
	# Recopilar todos los índices con la mejor efectividad
	var best_indices: Array[int] = []
	for i in range(effectiveness_scores.size()):
		if is_equal_approx(effectiveness_scores[i], best_effectiveness):
			best_indices.append(i)
	
	# Si hay empate, elegir aleatoriamente entre los mejores
	if best_indices.size() > 1:
		return best_indices[randi() % best_indices.size()]
	
	return best_indices[0]

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

