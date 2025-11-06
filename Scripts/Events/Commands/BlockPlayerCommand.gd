extends EventCommand
class_name BlockPlayerCommand

## Comando para bloquear el control del jugador
## Utiliza OverworldContext para acceso directo al Player

func execute(context: Node) -> void:
	print("BlockPlayer: Bloqueando control del jugador")

	# Obtener el jugador del contexto
	var overworld_context = _get_overworld_context(context)
	if not overworld_context:
		push_error("BlockPlayerCommand: OverworldContext no disponible")
		context.continue_execution()
		return

	var player: Node = overworld_context.get_player()
	if not player:
		push_error("BlockPlayerCommand: Player no disponible en el contexto")
		context.continue_execution()
		return

	# Si el jugador está moviéndose, esperar a que termine
	if player.motion and player.motion.moving:
		await player.motion.step_finished

	# Bloquear controles directamente
	player.block_controls()

	context.continue_execution()

## Obtiene el OverworldContext desde el EventController
func _get_overworld_context(context: Node) -> OverworldContext:
	if context is EventController:
		var event_system = context.get_parent() as EventSystem
		if event_system and event_system.context:
			return event_system.context
	return null

func is_async() -> bool:
	return true

func is_safe_for_parallel() -> bool:
	return true
