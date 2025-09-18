extends Resource
## Clase base de la que heredarán todos los comandos
class_name EventCommand

## Aquí irían los parámetros comunes, si los hubiera
# Por ejemplo, se puede poner un diccionario de argumentos:
# @export var args: Dictionary = {}

## Obtiene el nombre de la clase del comando
func get_command_name() -> String:
	var script = get_script()
	if script and script.get_global_name() != "":
		return script.get_global_name()
	else:
		# Fallback: usar el nombre del archivo
		var script_path = script.get_path()
		return script_path.get_file().get_basename().replace("Command", "")

## Método que luego ejecutará el EventController
func execute(_context: Node) -> void:
	push_warning("Ejecutando comando base, debería ser sobrescrito.")
