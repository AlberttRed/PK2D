extends EventCommand
class_name UnblockPlayerCommand

## Comando para desbloquear el control del jugador

func execute(context: Node) -> void:
	print("UnblockPlayer: Desbloqueando control del jugador")
	context.unblock_player_control()
	# No llamar continue_execution() - el EventController lo maneja automáticamente para comandos síncronos

func is_async() -> bool:
	return false

func is_safe_for_parallel() -> bool:
	return true
