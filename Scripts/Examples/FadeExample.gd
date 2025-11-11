extends Node

## Ejemplo de uso del sistema de fade
## Este script muestra cómo usar DisplayManager para ejecutar fades

func _ready():
	print("FadeExample: Ejemplo de uso del sistema de fade")

	# Esperar un poco para que todo se inicialice
	await get_tree().create_timer(1.0).timeout

	# Ejemplo 1: Fade in (fundido a negro)
	print("FadeExample: Ejecutando fade in...")
	await DisplayManager.fade_in(0.3)
	print("FadeExample: Fade in completado")

	# Esperar un poco
	await get_tree().create_timer(1.0).timeout

	# Ejemplo 2: Fade out (desde negro a visible)
	print("FadeExample: Ejecutando fade out...")
	await DisplayManager.fade_out(0.3)
	print("FadeExample: Fade out completado")

	# Esperar un poco
	await get_tree().create_timer(1.0).timeout

	# Ejemplo 3: Fade in de nuevo
	print("FadeExample: Ejecutando fade in...")
	await DisplayManager.fade_in(0.5)
	print("FadeExample: Ciclo de fade completado")

## Método para ejecutar fade in manualmente
func execute_fade_in(duration: float = 1.0):
	await DisplayManager.fade_in(duration)

## Método para ejecutar fade out manualmente
func execute_fade_out(duration: float = 1.0):
	await DisplayManager.fade_out(duration)
