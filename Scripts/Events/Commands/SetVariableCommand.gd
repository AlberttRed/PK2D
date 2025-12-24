extends EventCommand
class_name SetVariableCommand

## Comando para establecer variables globales del juego
## Las variables se guardan en game_variables (GameStateService) y persisten durante la sesión
## Las variables pueden ser de diferentes tipos: int, bool, String, float

enum VariableType {
	INT,
	BOOL,
	STRING,
	FLOAT
}

@export_group("Variable")
## Nombre de la variable a modificar
@export var variable_name: String = ""

@export_group("Type and Value")
## Tipo de la variable
@export var variable_type: VariableType = VariableType.INT

## Valor a establecer (debe coincidir con el tipo seleccionado)
@export var value: Variant = 0

func execute(_context: Node) -> void:
	if variable_name.is_empty():
		push_warning("SetVariableCommand: variable_name está vacío")
		return

	# Validar que el tipo del valor coincida con el tipo seleccionado
	if not _validate_type(value, variable_type):
		push_error("SetVariableCommand: El valor '%s' (tipo: %s) no es compatible con el tipo seleccionado '%s'" % [value, _get_type_name_from_value(value), _get_type_name(variable_type)])
		return

	# Establecer variable en GameStateService
	GameStateService.set_variable(variable_name, value)
	print("SetVariableCommand: Variable '%s' establecida a: %s (tipo: %s)" % [variable_name, value, _get_type_name(variable_type)])

## Valida que el tipo del valor coincida con el tipo seleccionado
func _validate_type(value: Variant, expected_type: VariableType) -> bool:
	var value_type = typeof(value)

	match expected_type:
		VariableType.INT:
			return value_type == TYPE_INT
		VariableType.BOOL:
			return value_type == TYPE_BOOL
		VariableType.STRING:
			return value_type == TYPE_STRING
		VariableType.FLOAT:
			return value_type == TYPE_FLOAT
		_:
			return false

## Obtiene el nombre del tipo para mensajes de error
func _get_type_name(type: VariableType) -> String:
	match type:
		VariableType.INT:
			return "int"
		VariableType.BOOL:
			return "bool"
		VariableType.STRING:
			return "String"
		VariableType.FLOAT:
			return "float"
		_:
			return "unknown"

## Obtiene el nombre del tipo de un valor para mensajes de error
func _get_type_name_from_value(value: Variant) -> String:
	match typeof(value):
		TYPE_INT:
			return "int"
		TYPE_BOOL:
			return "bool"
		TYPE_STRING:
			return "String"
		TYPE_FLOAT:
			return "float"
		_:
			return "unknown"

func is_async() -> bool:
	return false

func is_safe_for_parallel() -> bool:
	return true

