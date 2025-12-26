extends EventCommand
class_name SetFlagCommand

## Comando para establecer flags globales en el GameStateService
## Los flags se guardan en global_flags y persisten durante la sesión
@export var flag_name: String = "test_flag"
@export var flag_value: bool = true

@export_group("Defer Options")
## Si es true, el cambio se aplicará en el próximo warp en lugar de inmediatamente
@export var defer_until_warp: bool = false

func execute(_context: Node) -> void:
	# Si debe diferirse hasta el próximo warp
	if defer_until_warp:
		GameStateService.defer_change("flag", {
			"name": flag_name,
			"value": flag_value
		})
		return

	# Establecer flag global en el GameStateService inmediatamente
	GameStateService.set_event_flag(flag_name, flag_value)

	# No llamar continue_execution() - el EventController lo maneja automáticamente para comandos síncronos

func is_async() -> bool:
	return false

func is_safe_for_parallel() -> bool:
	return true
