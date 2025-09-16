extends EventCommand
class_name WaitCommand

## Comando para esperar un tiempo determinado
@export var duration: float = 1.0

func _init():
	command_name = "Wait"

func execute(context: Node) -> void:
	print("Wait: Esperando %.2f segundos" % duration)
	
	# Crear timer para esperar
	var timer = Timer.new()
	timer.wait_time = duration
	timer.one_shot = true
	timer.timeout.connect(_on_timer_timeout.bind(context))
	
	# Añadir timer a la escena
	context.get_tree().current_scene.add_child(timer)
	timer.start()

func _on_timer_timeout(context: Node) -> void:
	# Limpiar timer
	var timer = get_tree().current_scene.get_children().filter(func(child): return child is Timer and child.one_shot)
	if not timer.is_empty():
		timer[0].queue_free()
	
	# Continuar ejecución
	context.continue_execution()

func is_async() -> bool:
	return true
