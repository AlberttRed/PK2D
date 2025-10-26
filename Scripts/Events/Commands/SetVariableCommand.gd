extends EventCommand
class_name SetVariableCommand

## Comando para establecer o modificar variables globales del juego
## Las variables se guardan en GameStateManager y persisten durante la sesión

@export_group("Variable")
## Nombre de la variable a modificar
@export var variable_name: String = ""

@export_group("Operation")
## Tipo de operación a realizar
@export_enum("Set", "Add", "Subtract", "Multiply", "Divide", "Modulo") var operation: int = 0

## Valor a usar en la operación
@export var value: int = 0

func execute(_context: Node) -> void:
	if variable_name.is_empty():
		push_warning("SetVariableCommand: variable_name está vacío")
		return
	
	var current_value = GameStateManager.get_variable(variable_name, 0)
	var new_value = current_value
	
	match operation:
		0:  # Set
			new_value = value
		1:  # Add
			new_value = current_value + value
		2:  # Subtract
			new_value = current_value - value
		3:  # Multiply
			new_value = current_value * value
		4:  # Divide
			if value != 0:
				new_value = int(current_value / value)
			else:
				push_warning("SetVariableCommand: División por cero, se mantiene el valor")
				new_value = current_value
		5:  # Modulo
			if value != 0:
				new_value = current_value % value
			else:
				push_warning("SetVariableCommand: Módulo por cero, se mantiene el valor")
				new_value = current_value
	
	print("SetVariableCommand: '%s' %s %d = %d" % [variable_name, _get_operation_name(), value, new_value])
	GameStateManager.set_variable(variable_name, new_value)

func _get_operation_name() -> String:
	match operation:
		0: return "="
		1: return "+="
		2: return "-="
		3: return "*="
		4: return "/="
		5: return "%="
		_: return "?"

func is_async() -> bool:
	return false

func is_safe_for_parallel() -> bool:
	return true

