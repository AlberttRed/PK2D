extends EventCommand
class_name CloseMessageCommand

## Comando para cerrar el MessageBox actual si está visible
## Útil tras ShowMessage/ShowChoices con close_at_end=false

func execute(_context: Node) -> void:
	print("CloseMessageCommand: Cerrando MessageBox")
	DisplayManager.close_message()

	# Síncrono: el EventController continúa automáticamente
	# No llamar a context.continue_execution()

func is_async() -> bool:
	return false

func is_safe_for_parallel() -> bool:
	return false
