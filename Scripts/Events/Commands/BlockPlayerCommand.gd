extends EventCommand
class_name BlockPlayerCommand

## Comando para bloquear el control del jugador

func execute(context: Node) -> void:
	print("BlockPlayer: Bloqueando control del jugador")
	context.block_player_control()
	context.continue_execution()

func is_async() -> bool:
	return false
