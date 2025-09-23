extends Node

## Ejemplo de uso del sistema de fade
## Este script muestra cómo usar las señales del SignalManager para ejecutar fades

var fade_cycle_completed = false

func _ready():
	print("FadeExample: Ejemplo de uso del sistema de fade")
	
	# Conectar a las señales del SignalManager
	SignalManager.fade_finished.connect(_on_fade_finished)
	
	# Esperar un poco para que todo se inicialice
	await get_tree().create_timer(1.0).timeout
	
	# Ejemplo 1: Fade in (fundido a negro)
	print("FadeExample: Ejecutando fade in...")
	SignalManager.fade_requested.emit("fade_in", 0.3)

func _on_fade_finished():
	print("FadeExample: Fade completado")
	
	# Solo ejecutar fade out si no hemos completado el ciclo
	if not fade_cycle_completed:
		fade_cycle_completed = true
		# Esperar un poco y luego hacer fade out
		await get_tree().create_timer(1.0).timeout
		print("FadeExample: Ejecutando fade out...")
		SignalManager.fade_requested.emit("fade_out", 0.3)
	else:
		print("FadeExample: Ciclo de fade completado. Usa los métodos manuales para más fades.")

## Método para ejecutar fade in manualmente
func execute_fade_in(duration: float = 1.0):
	SignalManager.fade_requested.emit("fade_in", duration)

## Método para ejecutar fade out manualmente
func execute_fade_out(duration: float = 1.0):
	SignalManager.fade_requested.emit("fade_out", duration)
