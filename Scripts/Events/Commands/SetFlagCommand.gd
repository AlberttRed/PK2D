extends EventCommand
class_name SetFlagCommand

## Comando para establecer flags globales en el GameStateService
## Los flags se guardan en global_flags y persisten durante la sesión
@export var flag_name: String = "test_flag"
@export var flag_value: bool = true

func execute(_context: Node) -> void:
	print("SetFlag: Estableciendo flag global '%s' a %s" % [flag_name, flag_value])

	# Establecer flag global en el GameStateService (usa global_flags internamente)
	GameStateService.set_event_flag(flag_name, flag_value)

	# No llamar continue_execution() - el EventController lo maneja automáticamente para comandos síncronos

func is_async() -> bool:
	return false

func is_safe_for_parallel() -> bool:
	return true
