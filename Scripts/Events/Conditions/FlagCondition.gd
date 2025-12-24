extends EventCondition
class_name FlagCondition

## Condición que evalúa un flag (global o self-switch)
enum Scope { GLOBAL, SELF }

## Nombre del flag a evaluar
@export var flag_name: String = ""

## Alcance del flag: GLOBAL (global_flags) o SELF (event_self_flags)
@export var scope: Scope = Scope.GLOBAL

## Valor esperado del flag (true/false)
@export var expected_value: bool = true

## Evalúa si el flag tiene el valor esperado
func evaluate(context: EventConditionContext) -> bool:
	if flag_name.is_empty():
		# Si no hay nombre de flag, la condición siempre es verdadera
		return true

	var flag_value: bool = false

	match scope:
		Scope.GLOBAL:
			# Leer de global_flags
			flag_value = context.game_state.get_event_flag(flag_name)
		Scope.SELF:
			# Leer de event_self_flags usando el formato "event_uid:flag_name"
			# Para self-switches, el flag_name debe ser la letra (A, B, C, D)
			flag_value = context.game_state.get_self_switch(context.event_uid, flag_name)

	# Retornar true si el valor coincide con el esperado
	return flag_value == expected_value

