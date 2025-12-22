extends EventCommand
class_name ClosePortraitCommand

## Comando para cerrar el portrait box actual si está visible
## Solo tiene efecto si hay un portrait box abierto con modo NO_CLOSE

func execute(_context: Node) -> void:
	print("ClosePortraitCommand: Cerrando portrait box")

	# Cerrar el portrait box usando DisplayManager
	DisplayManager.close_portrait_box()

	# Este comando no es asíncrono - el EventController continuará automáticamente
	# No llamar a context.continue_execution() para comandos síncronos

func is_async() -> bool:
	return false

func is_safe_for_parallel() -> bool:
	return false
