extends EventCommand
class_name SetFlagCommand

## Comando para establecer flags en el GameState
@export var flag_name: String = "test_flag"
@export var flag_value: bool = true

func execute(_context: Node) -> void:
	print("SetFlag: Estableciendo flag '%s' a %s" % [flag_name, flag_value])
	
	# Establecer flag en el GameStateManager
	GameStateManager.set_event_flag(flag_name, flag_value)
	
	# No llamar continue_execution() - el EventController lo maneja automáticamente para comandos síncronos

func is_async() -> bool:
	return false
