class_name ScreenFieldEffect
extends FieldBattleEffect

## Subbase para pantallas y buffs de lado con duración por turnos.
## Ejemplos: Reflect, Light Screen, Safeguard, Mist, Tailwind.
##
## Ciclo común (heredado de FieldBattleEffect):
##   - ON_END_BATTLE_TURN: decrementa turns_left.
##   - ON_BATTLE_START: mensaje de inicio (efectos pre-sembrados).
##   - ON_END_BATTLE_TURN + has_finished(): mensaje de fin.
## El movimiento que crea la pantalla suele mostrar el inicio en su *MoveEffect.visualize().
##
## Migrar un efecto existente a esta subbase:
##   1. Cambiar herencia: extends ScreenFieldEffect.
##   2. Eliminar _init, apply_phase, visualize_phase y get_priority si solo repetían la base.
##   3. Implementar hooks según mecánica (p. ej. on_damage para Reflect).
##   4. Mantener el *MoveEffect y BattleEffectController.add_side_effect(...) sin cambios.


func _apply_field_effect_for_phase(
	pokemon: BattlePokemon,
	phase: Phases,
	ctx: BattlePhaseContext = null
) -> void:
	match phase:
		Phases.ON_INCOMING_DAMAGE_PRE:
			on_damage_pre(ctx)
		Phases.ON_INCOMING_DAMAGE_CALCULATE:
			on_damage(ctx)
		Phases.ON_INCOMING_DAMAGE_POST:
			on_damage_post(ctx)
		_:
			on_screen_phase(pokemon, phase, ctx)


func on_damage_pre(_ctx: BattlePhaseContext = null) -> void:
	pass


func on_damage(_ctx: BattlePhaseContext = null) -> void:
	pass


func on_damage_post(_ctx: BattlePhaseContext = null) -> void:
	pass


func on_stat_modify(
	_move: BattleMove,
	_user: BattlePokemon,
	_target: BattlePokemon,
	_stat_id: int,
	_value
):
	return _value


func on_status_restrict(
	_pokemon: BattlePokemon,
	_ailment: AilmentData,
	_ctx: BattlePhaseContext = null
) -> bool:
	return false


func on_screen_phase(
	_pokemon: BattlePokemon,
	_phase: Phases,
	_ctx: BattlePhaseContext = null
) -> void:
	pass
