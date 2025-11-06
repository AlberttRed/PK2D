extends EventCommand
class_name WarpCommand

## Comando para teletransportar al jugador
@export var target_scene: String = ""
@export var target_spawn: String = ""

enum FacingDirection {
	ARRIBA,
	ABAJO,
	IZQUIERDA,
	DERECHA
}

@export var facing_direction: FacingDirection = FacingDirection.ABAJO

func execute(_context: Node) -> void:
	print("Warp: Solicitando teletransporte a escena '%s' en spawn '%s'" % [target_scene, target_spawn])

	# Verificar que se especificó la escena de destino
	if target_scene.is_empty():
		push_error("WarpCommand: No se especificó escena de destino")
		return

	# Verificar que el SignalManager esté disponible
	if not SignalManager:
		push_error("WarpCommand: SignalManager no está disponible")
		return

	# Emitir señal para solicitar warp
	SignalManager.warp_requested.emit(target_scene, target_spawn)
	print("WarpCommand: Señal warp_requested emitida correctamente")

	# Esperar a que termine el warp realmente
	await SignalManager.warp_finished

	# Aplicar la dirección con el nuevo mapa ya activo
	_apply_facing_direction(_context)

	# Continuar ejecución del EventController al terminar este comando asíncrono
	_context.continue_execution()

## Aplica la dirección configurada en el inspector
func _apply_facing_direction(context: Node) -> void:
	var direction = get_facing_vector()
	print("WarpCommand: Aplicando dirección: ", direction)

	# Obtener el jugador del contexto
	var overworld_context = _get_overworld_context(context)
	if not overworld_context:
		push_error("WarpCommand: OverworldContext no disponible")
		return

	var player: Node = overworld_context.get_player()
	if not player:
		push_error("WarpCommand: Player no disponible en el contexto")
		return

	# Aplicar la dirección al jugador
	player.set_facing_direction(direction)
	GameStateService.set_facing_direction(direction)
	print("WarpCommand: Dirección aplicada correctamente")

## Obtiene el OverworldContext desde el EventController
func _get_overworld_context(context: Node) -> OverworldContext:
	if context is EventController:
		var event_system = context.get_parent() as EventSystem
		if event_system and event_system.context:
			return event_system.context
	return null

## Convierte el enum a Vector2
func get_facing_vector() -> Vector2:
	match facing_direction:
		FacingDirection.ARRIBA:
			return Vector2.UP
		FacingDirection.ABAJO:
			return Vector2.DOWN
		FacingDirection.IZQUIERDA:
			return Vector2.LEFT
		FacingDirection.DERECHA:
			return Vector2.RIGHT
		_:
			return Vector2.DOWN

func is_async() -> bool:
	return true

func is_safe_for_parallel() -> bool:
	return false
