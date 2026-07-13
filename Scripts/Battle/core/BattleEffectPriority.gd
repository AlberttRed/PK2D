class_name BattleEffectPriority
extends RefCounted

## ON_BEFORE_MOVE — mayor valor = se evalúa antes (Gen 4).
const PRE_MOVE_SLEEP := 40
const PRE_MOVE_FREEZE := 39
const PRE_MOVE_PARALYSIS := 38
const PRE_MOVE_FLINCH := 37
const PRE_MOVE_CONFUSION := 36
const PRE_MOVE_INFATUATION := 35

## ON_VALIDATE_MOVE — mayor valor = gana el rechazo y el mensaje.
const VALIDATE_ENCORE := 11
const VALIDATE_TAUNT := 10
const VALIDATE_DISABLE := 9
const VALIDATE_TORMENT := 8

## ON_VALIDATE_SWITCH / ON_VALIDATE_RUN
const VALIDATE_TRAP := 10

## ON_END_BATTLE_TURN — residuales y ticks.
const END_POISON := 25
const END_BURN := 24
const END_WEATHER_RESIDUAL := 20
const END_TRAP := 15
const END_PERISH_SONG := 14
const END_YAWN := 13
const END_VOLATILE_TICK := 5

## Daño entrante / validación de estados (Substitute).
const INCOMING_SUBSTITUTE := 6


## Prioridad de un efecto en una fase concreta. 0 = sin preferencia (orden estable al final).
static func get_for(effect: PersistentBattleEffect, phase: BattleEffect.Phases) -> int:
	if effect == null:
		return 0
	var effect_class: String = _effect_class_name(effect)
	match phase:
		BattleEffect.Phases.ON_BEFORE_MOVE:
			return _pre_move_priority(effect_class)
		BattleEffect.Phases.ON_VALIDATE_MOVE:
			return _validate_move_priority(effect_class)
		BattleEffect.Phases.ON_VALIDATE_SWITCH, BattleEffect.Phases.ON_VALIDATE_RUN:
			return _validate_trap_priority(effect_class)
		BattleEffect.Phases.ON_END_BATTLE_TURN:
			return _end_turn_priority(effect_class)
		BattleEffect.Phases.ON_INCOMING_DAMAGE_PRE, \
		BattleEffect.Phases.ON_INCOMING_DAMAGE_CALCULATE, \
		BattleEffect.Phases.ON_INCOMING_DAMAGE_FINALIZE, \
		BattleEffect.Phases.ON_INCOMING_DAMAGE_POST:
			if effect_class == "SubstituteAilmentEffect":
				return INCOMING_SUBSTITUTE
		_:
			pass
	return 0


static func _effect_class_name(effect: PersistentBattleEffect) -> String:
	var script: Script = effect.get_script()
	if script == null:
		return ""
	return script.get_global_name()


static func _pre_move_priority(effect_class: String) -> int:
	match effect_class:
		"SleepAilmentEffect":
			return PRE_MOVE_SLEEP
		"FreezeAilmentEffect":
			return PRE_MOVE_FREEZE
		"ParalysisAilmentEffect":
			return PRE_MOVE_PARALYSIS
		"FlinchAilmentEffect":
			return PRE_MOVE_FLINCH
		"ConfusionAilmentEffect":
			return PRE_MOVE_CONFUSION
		"InfatuationAilmentEffect":
			return PRE_MOVE_INFATUATION
		"TauntAilmentEffect":
			return VALIDATE_TAUNT
		"EncoreAilmentEffect":
			return VALIDATE_ENCORE
		"DisableAilmentEffect":
			return VALIDATE_DISABLE
		"TormentAilmentEffect":
			return VALIDATE_TORMENT
	return 0


static func _validate_move_priority(effect_class: String) -> int:
	match effect_class:
		"EncoreAilmentEffect":
			return VALIDATE_ENCORE
		"TauntAilmentEffect":
			return VALIDATE_TAUNT
		"DisableAilmentEffect":
			return VALIDATE_DISABLE
		"TormentAilmentEffect":
			return VALIDATE_TORMENT
	return 0


static func _validate_trap_priority(effect_class: String) -> int:
	if effect_class == "TrapAilmentEffect":
		return VALIDATE_TRAP
	return 0


static func _end_turn_priority(effect_class: String) -> int:
	match effect_class:
		"PoisonAilmentEffect":
			return END_POISON
		"BurnAilmentEffect":
			return END_BURN
		"HailWeatherEffect", "SandstormWeatherEffect":
			return END_WEATHER_RESIDUAL
		"TrapAilmentEffect":
			return END_TRAP
		"PerishSongAilmentEffect":
			return END_PERISH_SONG
		"YawnAilmentEffect":
			return END_YAWN
		"EncoreAilmentEffect", "TauntAilmentEffect", \
		"DisableAilmentEffect", "TormentAilmentEffect":
			return END_VOLATILE_TICK
	return 0
