extends EventCommand
class_name WarpCommand

## Comando para teletransportar al jugador
@export var target_scene: String = ""
@export var target_spawn: String = ""

func execute(_context: Node) -> void:
	print("Warp: Solicitando teletransporte a escena '%s' en spawn '%s'" % [target_scene, target_spawn])
	
	# Verificar que se especificó la escena de destino
	if target_scene.is_empty():
		print("Warp: Error - No se especificó escena de destino")
		# No llamar continue_execution() - el EventController lo maneja automáticamente para comandos síncronos
		return
	
	# Emitir señal para solicitar warp
	SignalManager.warp_requested.emit(target_scene, target_spawn)
	
	# No llamar continue_execution() - el EventController lo maneja automáticamente para comandos síncronos

func is_async() -> bool:
	# Será asíncrono cuando implementemos cambio de escena
	return false
