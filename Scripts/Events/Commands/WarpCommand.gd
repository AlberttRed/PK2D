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
	
	# Esperar a que termine el warp y aplicar la dirección
	await _context.get_tree().process_frame
	_apply_facing_direction(_context)

## Aplica la dirección configurada en el inspector
func _apply_facing_direction(context: Node) -> void:
	var direction = get_facing_vector()
	print("WarpCommand: Aplicando dirección: ", direction)
	
	# Buscar el jugador
	var player = context.get_tree().get_first_node_in_group("Player")
	if not player:
		push_warning("WarpCommand: No se encontró el jugador para aplicar dirección")
		return
	
	# Aplicar la dirección al jugador
	player.set_facing_direction(direction)
	GameStateManager.set_facing_direction(direction)
	print("WarpCommand: Dirección aplicada correctamente")

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
	# Será asíncrono cuando implementemos cambio de escena
	return false
