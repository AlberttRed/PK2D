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
## Si es "" (string vacío), se verifica si la variable no existe, es null o es ""
## Para otros valores, se compara normalmente
## Puede ser cualquier tipo: int, bool, String, float, etc.
## NOTA: Para verificar si una variable no existe o está vacía, deja este campo como "" (string vacío)
@export var compare_value: Variant = ""

## Campo auxiliar para serialización de valores numéricos
## Godot tiene problemas serializando Variant int/float en Resources, así que guardamos el valor como String aquí
## Se usa automáticamente cuando compare_value es numérico
@export var compare_value_serialized: String = ""

## Evalúa la comparación de la variable según el operador
func evaluate(context: EventConditionContext) -> bool:
	if variable_name.is_empty():
		# Si no hay nombre de variable, la condición siempre es falsa
		return false

	# Restaurar compare_value desde compare_value_serialized si es necesario
	# (para evitar problemas de serialización con números en Resources)
	var actual_compare_value = compare_value
	if _is_value_empty(actual_compare_value) and not compare_value_serialized.is_empty():
		# Intentar parsear el valor serializado
		var parsed = _parse_serialized_value(compare_value_serialized)
		if not _is_value_empty(parsed):
			actual_compare_value = parsed
			compare_value = parsed  # Restaurar también en compare_value para futuras evaluaciones

	# Obtener el valor de la variable (puede ser cualquier tipo)
	var var_value = context.game_state.get_variable(variable_name)

	# Verificar si compare_value está "vacío" (null o string vacío)
	var is_compare_empty = _is_value_empty(actual_compare_value)

	# Si compare_value está vacío, verificar si la variable no existe, es null o es ""
	if is_compare_empty:
		var variable_exists = context.game_state.has_variable(variable_name)
		if not variable_exists:
			# Variable no existe → cumple la condición (está "vacía")
			return operator == Operator.EQUAL

		# Variable existe, verificar si también está vacía
		var is_var_empty = _is_value_empty(var_value)

		# Si la variable también está vacía, son iguales
		if is_var_empty:
			return operator == Operator.EQUAL
		else:
			# Variable tiene valor pero compare_value está vacío → no son iguales
			return operator == Operator.NOT_EQUAL

	# Realizar la comparación según el operador
	match operator:
		Operator.EQUAL:
			return var_value == actual_compare_value
		Operator.NOT_EQUAL:
			return var_value != actual_compare_value
		Operator.GREATER:
			# Solo para tipos numéricos
			if typeof(var_value) in [TYPE_INT, TYPE_FLOAT] and typeof(actual_compare_value) in [TYPE_INT, TYPE_FLOAT]:
				return var_value > actual_compare_value
			push_warning("VariableCondition: Operador GREATER solo válido para tipos numéricos (variable: %s, compare: %s)" % [typeof(var_value), typeof(actual_compare_value)])
			return false
		Operator.GREATER_EQUAL:
			if typeof(var_value) in [TYPE_INT, TYPE_FLOAT] and typeof(actual_compare_value) in [TYPE_INT, TYPE_FLOAT]:
				return var_value >= actual_compare_value
			push_warning("VariableCondition: Operador GREATER_EQUAL solo válido para tipos numéricos (variable: %s, compare: %s)" % [typeof(var_value), typeof(actual_compare_value)])
			return false
		Operator.LESS:
			if typeof(var_value) in [TYPE_INT, TYPE_FLOAT] and typeof(actual_compare_value) in [TYPE_INT, TYPE_FLOAT]:
				return var_value < actual_compare_value
			push_warning("VariableCondition: Operador LESS solo válido para tipos numéricos (variable: %s, compare: %s)" % [typeof(var_value), typeof(actual_compare_value)])
			return false
		Operator.LESS_EQUAL:
			if typeof(var_value) in [TYPE_INT, TYPE_FLOAT] and typeof(actual_compare_value) in [TYPE_INT, TYPE_FLOAT]:
				return var_value <= actual_compare_value
			push_warning("VariableCondition: Operador LESS_EQUAL solo válido para tipos numéricos (variable: %s, compare: %s)" % [typeof(var_value), typeof(actual_compare_value)])
			return false
		_:
			return false

## Verifica si un valor está "vacío" (null o string vacío)
## Se usa para detectar cuando compare_value está vacío y se debe verificar si la variable no existe
func _is_value_empty(value: Variant) -> bool:
	# Si es null, está vacío
	if value == null:
		return true

	# Si es string vacío, está vacío
	if typeof(value) == TYPE_STRING:
		return value == ""

	# Para otros tipos, no está vacío (0, false, etc. son valores válidos)
	return false

## Verifica si esta condición depende de una variable global específica
func depends_on_variable(var_name: String) -> bool:
	return var_name == variable_name

## Parsea un valor desde compare_value_serialized
func _parse_serialized_value(text: String) -> Variant:
	var trimmed = text.strip_edges()
	if trimmed.is_empty():
		return ""

	# Intentar como bool
	if trimmed.to_lower() == "true":
		return true
	if trimmed.to_lower() == "false":
		return false

	# Intentar como int
	if trimmed.is_valid_int():
		return trimmed.to_int()

	# Intentar como float
	if trimmed.is_valid_float():
		return trimmed.to_float()

	# Si no se puede parsear, devolver como String
	return trimmed

