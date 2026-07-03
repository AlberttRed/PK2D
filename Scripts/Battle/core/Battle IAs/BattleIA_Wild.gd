extends BattleIA

class_name BattleIA_Wild

## IA para Pokémon salvajes.
##
## Comportamiento: Ataca con un movimiento aleatorio sin ninguna estrategia.
## Los Pokémon salvajes siempre atacan eligiendo aleatoriamente entre sus movimientos disponibles.
##
## Nota: Para Pokémon especiales (como los "Roaming" que intentan escapar),
## se crearán subclases específicas en el futuro.

func _init():
	difficulty_name = "Wild"
	use_items = false
	can_switch_strategically = false

## Decide la acción del Pokémon salvaje.
## Siempre elige un movimiento aleatorio de los disponibles.
func decide_action(pokemon: BattlePokemon) -> BattleChoice:
	var moves = pokemon.get_available_moves()

	if moves.is_empty():
		return BattlePassChoice.new()

	var legal_indices := get_selectable_move_indices(pokemon)
	if legal_indices.is_empty():
		return BattlePassChoice.new()

	var index: int = legal_indices[randi() % legal_indices.size()]
	var move = moves[index]
	
	# Crear la elección de movimiento
	var choice = BattleMoveChoice.new()
	choice.move_index = index
	choice.pokemon = pokemon

	# Generar targets automáticamente (sin UI) usando la lógica de targeting
	var selector := BattleTargetSelector.new()
	choice.targets = selector.resolve_targets(move, pokemon, null)
	
	return choice
