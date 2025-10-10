class_name BattleMoveChoice
extends BattleChoice

var move: BattleMove
var move_index: int = -1

# Array de BattleTarget generados para este movimiento
var targets: Array[BattleTarget] = []
## Los targets serán asignados por BattleUI antes de resolver

func get_move() -> BattleMove:
	if not pokemon or move_index == -1:
		return null
	return pokemon.get_available_moves()[move_index]

func get_priority() -> int:
	return get_move().get_priority() if get_move() != null else 0

## Resuelve el movimiento y genera los handlers correspondientes
func resolve() -> Array[BattleHandler]:
	var handlers: Array[BattleHandler] = []
	
	var move_instance := get_move()
	if not move_instance:
		return handlers
	
	if targets.is_empty():
		return handlers
	
	var category: BattleMoveCategory = move_instance.get_category() if move_instance.has_method("get_category") else null
	if not category:
		print("No category found for move: " + move_instance.get_name())
		return handlers
	
	for target in targets:

		if move_instance.get_accuracy() > 0 and not AccuracyUtils.check_hit(move_instance, pokemon, target.get_pokemon()):
			handlers.append(MissHandler.new(pokemon))
			continue
		
		var handler := category.create_handler(move_instance, pokemon, target)
		if handler:
			handlers.append(handler)
	
	return handlers
