extends EventCommand
class_name WaitCommand

var _timer: Timer = null

## Comando para esperar un tiempo determinado
@export var duration: float = 1.0

func execute(context: Node) -> void:
	print("Wait: Esperando %.2f segundos" % duration)
	
	# Crear timer para esperar (propio de este comando)
	_timer = Timer.new()
	_timer.wait_time = duration
	_timer.one_shot = true
	_timer.timeout.connect(_on_timer_timeout.bind(context))
	
	# Añadir timer a la escena
	context.get_tree().current_scene.add_child(_timer)
	_timer.start()

func _on_timer_timeout(context: Node) -> void:
	# Limpiar solo el timer propio
	if is_instance_valid(_timer):
		_timer.queue_free()
		_timer = null
	
	# Continuar ejecución
	context.continue_execution()

func is_async() -> bool:
	return true

func is_safe_for_parallel() -> bool:
	return true
