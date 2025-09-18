extends EventCommand
class_name UnblockPlayerCommand

## Comando para desbloquear el control del jugador

func execute(context: Node) -> void:
	print("UnblockPlayer: Desbloqueando control del jugador")
	context.unblock_player_control()
	context.continue_execution()

func is_async() -> bool:
	return false
