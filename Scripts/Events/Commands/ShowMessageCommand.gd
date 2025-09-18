extends EventCommand
class_name ShowMessageCommand

## Comando para mostrar un mensaje al jugador
@export var message: String = "¡Hola mundo!"
@export var wait_input: bool = true
@export var close_at_end: bool = true
@export var wait_time: float = 0.0

func execute(context: Node) -> void:
	print("ShowMessage: %s" % message)
	
	# Configurar parámetros del mensaje
	var config = {
		"waitInput": wait_input,
		"closeAtEnd": close_at_end,
		"waitTime": wait_time
	}
	
	# Emitir señal para mostrar mensaje
	SignalManager.message_requested.emit(message, config)
	
	# Esperar a que termine el mensaje
	await SignalManager.message_finished
	context.continue_execution()

func is_async() -> bool:
	return true
