extends EventCommand
class_name ShowMessageCommand

## Comando para mostrar un mensaje al jugador
@export var message: String = "¡Hola mundo!"

func _init():
	command_name = "ShowMessage"

func execute(context: Node) -> void:
	print("ShowMessage: %s" % message)
	# TODO: Integrar con MessageBox real
	# Por ahora solo mostramos en consola y continuamos inmediatamente
	context.continue_execution()

func is_async() -> bool:
	# Este comando será asíncrono cuando se integre con MessageBox
	# Por ahora es síncrono (placeholder)
	return false
