extends EventCommand
class_name FadeCommand

## Comando para realizar fade in/out
enum FadeMode { IN, OUT }
@export var mode: FadeMode = FadeMode.OUT
@export var duration: float = 1.0  # Duración en segundos
@export var wait_for_completion: bool = true  # Si true, espera a que termine el fade antes de continuar

func execute(context: Node) -> void:
	# Validar parámetros
	if duration < 0.0:
		push_error("FadeCommand: Duración inválida %.2f. Debe ser >= 0" % duration)
		if wait_for_completion:
			context.continue_execution()
		return

	# Ejecutar el fade usando DisplayManager
	match mode:
		FadeMode.IN:
			print("FadeCommand: Ejecutando fade in durante %.2f segundos" % duration)
			if wait_for_completion:
				await DisplayManager.fade_in(duration)
				print("FadeCommand: Fade in completado")
			else:
				DisplayManager.fade_in(duration)  # Sin await
				print("FadeCommand: Fade in iniciado (sin esperar)")
		FadeMode.OUT:
			print("FadeCommand: Ejecutando fade out durante %.2f segundos" % duration)
			if wait_for_completion:
				await DisplayManager.fade_out(duration)
				print("FadeCommand: Fade out completado")
			else:
				DisplayManager.fade_out(duration)  # Sin await
				print("FadeCommand: Fade out iniciado (sin esperar)")

	# Continuar ejecución solo si esperamos la finalización
	if wait_for_completion:
		context.continue_execution()

func is_async() -> bool:
	return wait_for_completion

func is_safe_for_parallel() -> bool:
	return false
