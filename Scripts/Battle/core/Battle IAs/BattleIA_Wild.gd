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
	
	# Si no hay movimientos disponibles, pasar turno
	if moves.is_empty():
		return BattlePassChoice.new()
	
	# Seleccionar un movimiento aleatorio
	var index = randi() % moves.size()
	var move = moves[index]
	
	# Crear la elección de movimiento
	var choice = BattleMoveChoice.new()
	choice.move_index = index
	choice.pokemon = pokemon

	# Generar targets automáticamente (sin UI) usando la lógica de targeting
	var selector := BattleTargetSelector.new()
	choice.targets = selector.resolve_targets(move, pokemon, null)
	
	return choice
