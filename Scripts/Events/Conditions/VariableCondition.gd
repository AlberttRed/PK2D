extends EventCondition
class_name VariableCondition

## Condición que evalúa una variable global con un operador de comparación
enum Operator {
	EQUAL,          # ==
	NOT_EQUAL,      # !=
	GREATER,        # >
	GREATER_EQUAL,  # >=
	LESS,           # <
	LESS_EQUAL      # <=
}

## Nombre de la variable global a evaluar
@export var variable_name: String = ""

## Operador de comparación a usar
@export var operator: Operator = Operator.EQUAL

## Valor con el que comparar la variable
@export var compare_value: Variant = 0

## Evalúa la comparación de la variable según el operador
func evaluate(context: EventConditionContext) -> bool:
	if variable_name.is_empty():
		# Si no hay nombre de variable, la condición siempre es falsa
		return false

	# Obtener el valor de la variable (default 0 si no existe)
	var var_value = context.game_state.get_variable(variable_name)

	# Realizar la comparación según el operador
	match operator:
		Operator.EQUAL:
			return var_value == compare_value
		Operator.NOT_EQUAL:
			return var_value != compare_value
		Operator.GREATER:
			return var_value > compare_value
		Operator.GREATER_EQUAL:
			return var_value >= compare_value
		Operator.LESS:
			return var_value < compare_value
		Operator.LESS_EQUAL:
			return var_value <= compare_value
		_:
			return false

