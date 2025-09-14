extends Resource
## Clase base de la que heredarán todos los comandos
class_name EventCommand

## Nombre del comando (ej. "ShowMessage", "Warp")
@export var command_name: String = "BaseCommand"

## Aquí irían los parámetros comunes, si los hubiera
# Por ejemplo, se puede poner un diccionario de argumentos:
# @export var args: Dictionary = {}

## Método que luego ejecutará el EventController
func execute(context: Node) -> void:
	push_warning("Ejecutando comando base '%s', debería ser sobrescrito." % command_name)
