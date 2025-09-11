extends Resource
class_name MoveCategoryLogic

# Base para lógica de ejecución por categoría de movimiento

var move: BattleMove
var user: BattlePokemon
var target: BattlePokemon
var num_hits: int = 1

func execute() -> Array[ImmediateBattleEffect]:
	return []
