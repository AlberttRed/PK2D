class_name BattlePhaseContext
extends RefCounted

## Pokémon sobre el que se ejecuta la fase (actor en selección o turno).
var pokemon: BattlePokemon = null
## Acción candidata durante validación en UI.
var choice: BattleChoice = null
## Movimiento candidato (atajo para ON_VALIDATE_MOVE).
var move: BattleMove = null
## Golpe entrante (atajo para fases ON_INCOMING_DAMAGE_*).
var damage: DamageEffect = null
## Estado mayor/volátil candidato (atajo para ON_VALIDATE_AILMENT).
var ailment: AilmentData = null
## Marcado por efectos que rechazan la selección en UI.
var rejected: bool = false
## Efecto que provocó el rechazo (prioridad más alta en la fase).
var blocking_effect: PersistentBattleEffect = null
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


static func for_incoming_damage(defender: BattlePokemon, damage_effect: DamageEffect) -> BattlePhaseContext:
	var ctx := BattlePhaseContext.new()
	ctx.pokemon = defender
	ctx.damage = damage_effect
	return ctx


static func for_ailment(defender: BattlePokemon, ailment_data: AilmentData) -> BattlePhaseContext:
	var ctx := BattlePhaseContext.new()
	ctx.pokemon = defender
	ctx.ailment = ailment_data
	return ctx
