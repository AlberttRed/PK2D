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

@export_group("Defer Options")
## Si es true, el cambio se aplicará en el próximo warp en lugar de inmediatamente
@export var defer_until_warp: bool = false

func execute(_context: Node) -> void:
	if variable_name.is_empty():
		push_warning("SetVariableCommand: variable_name está vacío")
		return

	var resolved_value: Variant = _coerce_value(value, variable_type)
	# Validar que el tipo del valor coincida con el tipo seleccionado
	if not _validate_type(resolved_value, variable_type):
		push_error("SetVariableCommand: El valor '%s' (tipo: %s) no es compatible con el tipo seleccionado '%s'" % [value, _get_type_name_from_value(value), _get_type_name(variable_type)])
		return

	# Si debe diferirse hasta el próximo warp
	if defer_until_warp:
		GameStateService.defer_change("variable", {
			"name": variable_name,
			"value": resolved_value
		})
		return

	# Establecer variable en GameStateService inmediatamente
	GameStateService.set_variable(variable_name, resolved_value)


## Godot a menudo serializa bool ausente como int 0; aceptar 0/1 → false/true.
func _coerce_value(raw: Variant, expected_type: VariableType) -> Variant:
	if expected_type == VariableType.BOOL and typeof(raw) == TYPE_INT:
		return raw != 0
	return raw

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
