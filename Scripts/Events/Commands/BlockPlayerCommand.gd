extends EventCommand
class_name BlockPlayerCommand

## Comando para bloquear el control del jugador

func execute(context: Node) -> void:
	print("BlockPlayer: Bloqueando control del jugador")
	
	# Obtener referencia temporal al jugador
	var player = context.get_tree().get_first_node_in_group("Player")
	
	# Si el jugador está moviéndose, esperar a que termine
	if player and player.motion and player.motion.moving:
		await player.motion.step_finished
	
	context.block_player_control()
	context.continue_execution()

func is_async() -> bool:
	return true
