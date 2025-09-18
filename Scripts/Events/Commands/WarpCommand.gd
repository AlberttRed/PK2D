extends EventCommand
class_name WarpCommand

## Comando para teletransportar al jugador
@export var target_scene: String = ""
@export var target_spawn: String = ""

func execute(context: Node) -> void:
	print("Warp: Solicitando teletransporte a escena '%s' en spawn '%s'" % [target_scene, target_spawn])
	
	# Verificar que se especificó la escena de destino
	if target_scene.is_empty():
		print("Warp: Error - No se especificó escena de destino")
		context.continue_execution()
		return
	
	# Emitir señal para solicitar warp
	SignalManager.warp_requested.emit(target_scene, target_spawn)
	
	# Continuar ejecución inmediatamente (el warp será manejado por WarpSystem)
	context.continue_execution()

func is_async() -> bool:
	# Será asíncrono cuando implementemos cambio de escena
	return false
