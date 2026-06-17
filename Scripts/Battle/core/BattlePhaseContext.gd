class_name BattlePhaseContext
extends RefCounted

## Pokémon sobre el que se ejecuta la fase (actor en selección o turno).
var pokemon: BattlePokemon = null
## Acción candidata durante validación en UI.
var choice: BattleChoice = null
## Movimiento candidato (atajo para ON_VALIDATE_MOVE).
var move: BattleMove = null
## Marcado por efectos que rechazan la selección en UI.
var rejected: bool = false
## Mensaje opcional; la UI puede mostrarlo con el overlay adecuado (p. ej. party).
var rejection_message: Dictionary = {}


static func for_choice(actor: BattlePokemon, action: BattleChoice) -> BattlePhaseContext:
	var ctx := BattlePhaseContext.new()
	ctx.pokemon = actor
	ctx.choice = action
	return ctx


static func for_move(actor: BattlePokemon, move_choice: BattleMoveChoice) -> BattlePhaseContext:
	var ctx := BattlePhaseContext.new()
	ctx.pokemon = actor
	ctx.choice = move_choice
	ctx.move = move_choice.get_move() if move_choice != null else null
	return ctx
