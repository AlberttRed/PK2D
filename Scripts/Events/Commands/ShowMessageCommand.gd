extends EventCommand
class_name ShowMessageCommand

## Comando para mostrar un mensaje al jugador
@export_multiline var message: String = "¡Hola mundo!"
@export var wait_input: bool = true
@export var close_at_end: bool = true
@export var wait_time: float = 0.0
@export var show_icon_at_end: bool = false  ## Si true, muestra icono al final aunque no haya más mensajes (batalla)

func execute(context: Node) -> void:
	print("ShowMessage: %s" % message)

	# Configurar parámetros del mensaje
	var config = {
		"waitInput": wait_input,
		"closeAtEnd": close_at_end,
		"waitTime": wait_time,
		"showIconAtEnd": show_icon_at_end
	}

	# Mostrar mensaje usando DisplayManager
	await DisplayManager.show_message(message, config)
	context.continue_execution()

func is_async() -> bool:
	return true

func is_safe_for_parallel() -> bool:
	return false
