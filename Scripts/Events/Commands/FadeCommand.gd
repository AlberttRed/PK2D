extends EventCommand
class_name FadeCommand

## Comando para realizar fade in/out
enum FadeMode { IN, OUT }
@export var mode: FadeMode = FadeMode.OUT
@export var duration: float = 1.0  # Duración en segundos

func execute(context: Node) -> void:
	# Convertir enum a string para el FadeLayer
	var fade_mode_string: String = "fade_out"
	match mode:
		FadeMode.IN:
			fade_mode_string = "fade_in"
		FadeMode.OUT:
			fade_mode_string = "fade_out"
	
	print("FadeCommand: Ejecutando fade %s durante %.2f segundos" % [fade_mode_string, duration])
	
	# Validar parámetros
	if duration < 0.0:
		push_error("FadeCommand: Duración inválida %.2f. Debe ser >= 0" % duration)
		context.continue_execution()
		return
	
	# Emitir señal para iniciar el fade
	SignalManager.fade_requested.emit(fade_mode_string, duration)
	
	# Siempre esperar a que termine el fade antes de continuar
	await SignalManager.fade_finished
	print("FadeCommand: Fade %s completado" % fade_mode_string)
	
	# Continuar ejecución
	context.continue_execution()

func is_async() -> bool:
	return true

func is_safe_for_parallel() -> bool:
	return false
