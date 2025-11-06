extends EventCommand
class_name UnblockPlayerCommand

## Comando para desbloquear el control del jugador
## Utiliza OverworldContext para acceso directo al Player

func execute(context: Node) -> void:
	print("UnblockPlayer: Desbloqueando control del jugador")

	# Obtener el jugador del contexto
	var overworld_context = _get_overworld_context(context)
	if not overworld_context:
		push_error("UnblockPlayerCommand: OverworldContext no disponible")
		return

	var player: Node = overworld_context.get_player()
	if not player:
		push_error("UnblockPlayerCommand: Player no disponible en el contexto")
		return

	# Desbloquear controles directamente
	player.unblock_controls()

	# No llamar continue_execution() - el EventController lo maneja automáticamente para comandos síncronos

## Obtiene el OverworldContext desde el EventController
func _get_overworld_context(context: Node) -> OverworldContext:
	if context is EventController:
		var event_system = context.get_parent() as EventSystem
		if event_system and event_system.context:
			return event_system.context
	return null

func is_async() -> bool:
	return false

func is_safe_for_parallel() -> bool:
	return true
