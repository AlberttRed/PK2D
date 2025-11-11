extends Node2D

## Script de prueba para ChoiceBox
## Prueba la navegación y selección de opciones

func _ready() -> void:
	print("=== TEST CHOICEBOX ===")
	print("Iniciando prueba del sistema de choices...")

	# Esperar a que DisplayManager esté listo
	await get_tree().process_frame
	await get_tree().process_frame

	# Ocultar el FadeLayer para que no tape todo
	if DisplayManager.instance and DisplayManager.instance.fade_layer:
		DisplayManager.instance.fade_layer.hide()

	# Mostrar mensaje con opciones automáticas (estilo Pokémon)
	print("Mostrando mensaje con opciones...")
	var opciones:Array[String] = ["Sí", "No", "Tal vez", "Quizás", "No tengo ni idea"]
	var selected = await DisplayManager.show_message_with_choices("¿Te gusta este juego?", opciones)

	print("Opción seleccionada: ", selected, " (", opciones[selected] if selected >= 0 else "Cancelado", ")")

	# Mostrar resultado según la selección
	match selected:
		0:
			await DisplayManager.show_message("¡Qué bien que te guste!", {"waitInput": true})
		1:
			await DisplayManager.show_message("Vaya, lo siento...", {"waitInput": true})
		2:
			await DisplayManager.show_message("Bueno, tal vez te convenzas.", {"waitInput": true})
		3:
			await DisplayManager.show_message("¡Pues deberías decidirte!", {"waitInput": true})
		4:
			await DisplayManager.show_message("Está bien, respeto tu decisión.", {"waitInput": true})
		-1:
			await DisplayManager.show_message("Cancelaste la selección.", {"waitInput": true})

	print("=== PRUEBA COMPLETADA ===")
	print("Presiona ESC para salir")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and !DisplayManager.is_fading():
		get_tree().quit()
