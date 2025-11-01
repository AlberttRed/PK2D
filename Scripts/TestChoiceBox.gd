extends Node2D

## Script de prueba para ChoiceBox
## Prueba la navegación y selección de opciones

@onready var gui = $GUI

func _ready() -> void:
	print("=== TEST CHOICEBOX ===")
	print("Iniciando prueba del sistema de choices...")

	# Ocultar el FadeLayer para que no tape todo
	gui.fade_layer.hide()

	# Esperar un frame para que todo esté inicializado
	await get_tree().process_frame

	# Mostrar mensaje con opciones automáticas (estilo Pokémon)
	print("Mostrando mensaje con opciones...")
	var opciones:Array[String] = ["Sí", "No", "Tal vez", "Quizás", "No tengo ni idea"]
	var selected = await gui.show_message_with_choices("¿Te gusta este juego?", opciones)

	print("Opción seleccionada: ", selected, " (", opciones[selected] if selected >= 0 else "Cancelado", ")")

	# Mostrar resultado según la selección
	match selected:
		0:
			await gui.msg.show_input("¡Qué bien que te guste!")
		1:
			await gui.msg.show_input("Vaya, lo siento...")
		2:
			await gui.msg.show_input("Bueno, tal vez te convenzas.")
		3:
			await gui.msg.show_input("¡Pues deberías decidirte!")
		4:
			await gui.msg.show_input("Está bien, respeto tu decisión.")
		-1:
			await gui.msg.show_input("Cancelaste la selección.")

	print("=== PRUEBA COMPLETADA ===")
	print("Presiona ESC para salir")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and !gui.isVisible():
		get_tree().quit()
