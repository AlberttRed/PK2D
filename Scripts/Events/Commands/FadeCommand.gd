extends EventCommand
class_name FadeCommand

## Comando para realizar fade in/out
enum FadeMode { IN, OUT }
@export var mode: FadeMode = FadeMode.OUT
@export var duration: float = 1.0  # Duración en segundos

func execute(context: Node) -> void:
	# Validar parámetros
	if duration < 0.0:
		push_error("FadeCommand: Duración inválida %.2f. Debe ser >= 0" % duration)
		context.continue_execution()
		return

	# Ejecutar el fade usando DisplayManager
	match mode:
		FadeMode.IN:
			print("FadeCommand: Ejecutando fade in durante %.2f segundos" % duration)
			await DisplayManager.fade_in(duration)
			print("FadeCommand: Fade in completado")
		FadeMode.OUT:
			print("FadeCommand: Ejecutando fade out durante %.2f segundos" % duration)
			await DisplayManager.fade_out(duration)
			print("FadeCommand: Fade out completado")

	# Continuar ejecución
	context.continue_execution()

func is_async() -> bool:
	return true

func is_safe_for_parallel() -> bool:
	return false
