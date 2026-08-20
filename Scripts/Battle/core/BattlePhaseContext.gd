class_name BattlePhaseContext
extends RefCounted

## Pokémon sobre el que se ejecuta la fase (actor en selección o turno).
var pokemon: BattlePokemon = null
## Resultado de validaciones (bloqueos, mensajes, efecto bloqueante).
var validation: PhaseValidationContext = null
## Golpe entrante (fases ON_INCOMING_DAMAGE_*).
var damage: PhaseDamageContext = null
## Estado candidato (fase ON_VALIDATE_AILMENT).
var ailment: PhaseAilmentContext = null
## Cambio de stage candidato (fase ON_VALIDATE_STAT).
var stat_change: PhaseStatChangeContext = null
## Acción/movimiento candidato (validación en UI / ON_VALIDATE_MOVE).
var choice: PhaseChoiceContext = null


static func _ensure_validation(ctx: BattlePhaseContext) -> PhaseValidationContext:
	if ctx.validation == null:
		ctx.validation = PhaseValidationContext.new()
	return ctx.validation


static func for_choice(actor: BattlePokemon, action: BattleChoice) -> BattlePhaseContext:
	var ctx := BattlePhaseContext.new()
	ctx.pokemon = actor
	ctx.choice = PhaseChoiceContext.new()
	ctx.choice.battle_choice = action
	_ensure_validation(ctx)
	return ctx


static func for_move(actor: BattlePokemon, move_choice: BattleMoveChoice) -> BattlePhaseContext:
	var ctx := BattlePhaseContext.new()
	ctx.pokemon = actor
	ctx.choice = PhaseChoiceContext.new()
	ctx.choice.battle_choice = move_choice
	ctx.choice.move = move_choice.get_move() if move_choice != null else null
	_ensure_validation(ctx)
	return ctx


static func for_incoming_damage(
	defender: BattlePokemon,
	damage_effect: DamageEffect
) -> BattlePhaseContext:
	var ctx := BattlePhaseContext.new()
	ctx.pokemon = defender
	ctx.damage = PhaseDamageContext.new()
	ctx.damage.damage = damage_effect
	return ctx


static func for_ailment(defender: BattlePokemon, ailment_data: AilmentData) -> BattlePhaseContext:
	var ctx := BattlePhaseContext.new()
	ctx.pokemon = defender
	ctx.ailment = PhaseAilmentContext.new()
	ctx.ailment.ailment = ailment_data
	_ensure_validation(ctx)
	return ctx


static func for_stat_change(
	defender: BattlePokemon,
	source: BattlePokemon,
	stat: StatsEnum.Values,
	delta: int
) -> BattlePhaseContext:
	var ctx := BattlePhaseContext.new()
	ctx.pokemon = defender
	ctx.stat_change = PhaseStatChangeContext.new()
	ctx.stat_change.source = source
	ctx.stat_change.stat = stat
	ctx.stat_change.delta = delta
	_ensure_validation(ctx)
	return ctx
