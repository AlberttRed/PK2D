extends TrainerBattleIA

class_name BattleIA_TrainerEasy

## IA de entrenador de nivel fácil (única IA trainer de contenido en esta fase).
##
## Comportamiento (miopía de un turno, solo tipos):
## - Evalúa combinaciones (movimiento, objetivo) por efectividad de tipo
## - Si hay alguna combinación > 0, elige entre las de máxima efectividad (empate al azar)
## - Si todas son ≤ 0 (inmunidades/nulas), cae al helper random legal tipado
## - Sin items ni switch estratégico; forced switch = primer bench vivo

func _init() -> void:
	difficulty_name = "TrainerEasy"
	use_items = false
	can_switch_strategically = false


## Decide la acción del entrenador fácil.
## Prioriza el mejor par (movimiento, objetivo) por efectividad; evita elegir 0x si hay alternativa.
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
		return build_random_legal_move_choice(pokemon, moves, legal_indices)

	var best_choice := evaluate_best_move_target_combination(moves, enemies, legal_indices)
	var best_effectiveness: float = float(best_choice.get("effectiveness", 0.0))

	# Sin golpe tipado útil: no inventar estrategia entre inmunidades; random legal.
	if best_effectiveness <= 0.0:
		return build_random_legal_move_choice(pokemon, moves, legal_indices)

	var choice := BattleMoveChoice.new()
	choice.move_index = best_choice.move_index
	choice.pokemon = pokemon

	var move: BattleMove = moves[best_choice.move_index]
	var selector := BattleTargetSelector.new()
	var manual_spot: BattleSpot = best_choice.target_spot if best_choice.has("target_spot") else null
	choice.targets = selector.resolve_targets(move, pokemon, manual_spot)

	return choice


## Tras KO del activo: primer Pokémon vivo del party que no esté en campo.
func decide_forced_switch(side: BattleSide, spot: BattleSpot, fainted: BattlePokemon) -> BattleSwitchChoice:
	return build_first_available_forced_switch(side, spot, fainted)
