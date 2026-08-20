class_name FieldBattleEffect
extends PersistentBattleEffect

## Base común para efectos persistentes aplicados a un lado del campo (Player/Enemy)
## y registrados vía BattleEffectController.add_side_effect(...).
##
## Jerarquía:
##   FieldBattleEffect
##     ├── ScreenFieldEffect   — pantallas y barreras temporales (Reflect, Light Screen, …)
##     └── HazardFieldEffect   — trampas de entrada (Spikes, Stealth Rock, …)
##
## Las implementaciones concretas deben heredar de ScreenFieldEffect o HazardFieldEffect,
## no directamente de FieldBattleEffect, salvo casos excepcionales documentados.

## Lado protegido o afectado (PLAYER / ENEMY).
var side_type: BattleSide.Types = BattleSide.Types.NONE


func _init(
	_source = null,
	_duration: int = 5,
	_side_type: BattleSide.Types = BattleSide.Types.NONE
) -> void:
	super._init(_source)
	turns_left = _duration
	side_type = _side_type


func get_effect_id() -> int:
	if source != null and source.has_method("get_id"):
		return source.get_id()
	return 0


func applies_to_side(lookup_side_type: BattleSide.Types) -> bool:
	return lookup_side_type != BattleSide.Types.NONE and lookup_side_type == side_type


## Multiplicador de velocidad efectiva para Pokémon del lado (p. ej. Tailwind → 2.0).
func get_speed_multiplier(_pokemon: BattlePokemon) -> float:
	return 1.0


func apply_phase(pokemon: BattlePokemon, phase: Phases, ctx: BattlePhaseContext = null) -> void:
	if phase == Phases.ON_END_BATTLE_TURN:
		next_turn()
	_apply_field_effect_for_phase(pokemon, phase, ctx)


func visualize_phase(
	pokemon: BattlePokemon,
	ui: BattleUI,
	phase: Phases,
	ctx: BattlePhaseContext = null
) -> void:
	await _show_field_messages_for_phase(pokemon, ui, phase, ctx)


## Hook principal: lógica mecánica por fase (daño, switch-in, etc.).
## ScreenFieldEffect y HazardFieldEffect deben delegar aquí desde sus subclases concretas.
func _apply_field_effect_for_phase(
	_pokemon: BattlePokemon,
	_phase: Phases,
	_ctx: BattlePhaseContext = null
) -> void:
	pass


## Mensajes de inicio/expiración vía MessageFamily.Values.FIELD_EFFECT.
## El movimiento que crea el efecto suele mostrar el mensaje de inicio en su MoveEffect.visualize();
## esta ruta cubre efectos pre-sembrados (p. ej. debug) en ON_BATTLE_START.
func _show_field_messages_for_phase(
	_pokemon: BattlePokemon,
	ui: BattleUI,
	phase: Phases,
	_ctx: BattlePhaseContext = null
) -> void:
	var effect_id := get_effect_id()
	if effect_id == 0:
		return
	var message_pokemon := _get_message_pokemon()
	if message_pokemon == null:
		return
	if phase == Phases.ON_BATTLE_START:
		await ui.show_start_effect_message(
			MessageFamily.Values.FIELD_EFFECT,
			message_pokemon,
			effect_id
		)
	elif phase == Phases.ON_END_BATTLE_TURN and has_finished():
		await ui.show_end_effect_message(
			MessageFamily.Values.FIELD_EFFECT,
			message_pokemon,
			effect_id
		)


func _get_message_pokemon() -> BattlePokemon:
	if source is BattleMove:
		return source.pokemon
	return null


func get_priority() -> int:
	return 5
