extends EventCommand
class_name ShowMessageCommand

## Comando para mostrar un mensaje al jugador
@export_multiline var message: String = "¡Hola mundo!"
@export var wait_input: bool = true
@export var close_at_end: bool = true
@export var wait_time: float = 0.0
@export var show_icon_at_end: bool = false  ## Si true, muestra icono al final aunque no haya más mensajes (batalla)
@export var frame_style: MessageBoxFrameStyle.Values = MessageBoxFrameStyle.Values.HGSS  ## Estilo de marco del mensaje

@export_group("Text Color")
## Si está activo, usa un color personalizado para el texto
@export var use_custom_color: bool = false
## Color personalizado del texto (solo se aplica si use_custom_color es true)
@export var text_color: Color = Color.WHITE

func execute(context: Node) -> void:
	print("ShowMessage: %s" % message)

	# Preparar el texto (aplicar color si es necesario)
	var final_message = message
	if use_custom_color:
		final_message = "[color=#%s]%s[/color]" % [text_color.to_html(false), message]

	# Configurar parámetros del mensaje
	var config = {
		"waitInput": wait_input,
		"closeAtEnd": close_at_end,
		"waitTime": wait_time,
		"showIconAtEnd": show_icon_at_end,
		"frameStyle": frame_style
	}

	# Mostrar mensaje usando DisplayManager
	await DisplayManager.show_message(final_message, config)
	context.continue_execution()

func is_async() -> bool:
	return true

func is_safe_for_parallel() -> bool:
	return false
