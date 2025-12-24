extends EventCommand
class_name ShowChoicesCommand

## ShowChoicesCommand - Muestra opciones al jugador y ejecuta comandos según la elección
##
## Permite crear branching condicional basado en la decisión del jugador,
## similar al sistema de opciones de Pokémon y RPG Maker.
##
## Uso:
## 1. Añadir este comando a la lista de comandos de una EventPage
## 2. Configurar el mensaje que aparecerá antes de las opciones
## 3. Crear ChoiceBranch para cada opción disponible
## 4. En cada branch, añadir los comandos que se ejecutarán si esa opción es seleccionada
##
## Ejemplo:
## Mensaje: "¿Te gusta este juego?"
## Branch 0: label="Sí" → [ShowMessageCommand("¡Genial!")]
## Branch 1: label="No" → [ShowMessageCommand("Oh vaya...")]
##
## El jugador verá el mensaje, luego automáticamente aparecerán las opciones.
## Al seleccionar una, se ejecutarán solo los comandos de ese branch.

@export_group("Message Configuration")

## Mensaje que se muestra antes de las opciones
@export_multiline var message: String = ""

@export_group("Choices Configuration")

## Lista de branches (ramas) disponibles para el jugador
## Cada branch contiene un label (texto de la opción) y comandos a ejecutar
@export var branches: Array[ChoiceBranch] = []

@export_group("Optional")

## (Opcional) Nombre de variable global donde guardar el resultado (índice seleccionado)
## Si está vacío, no se guarda el resultado
@export var store_result_in: String = ""

## Estado interno
var _selected_index: int = -1


func execute(context: Node) -> void:
	print("ShowChoicesCommand: Mostrando mensaje con opciones")

	# Validar configuración
	if not _validate_configuration():
		push_error("ShowChoicesCommand: Configuración inválida, saltando comando")
		context.continue_execution()
		return

	# Extraer las opciones de texto de los branches
	var options: Array[String] = []
	for branch in branches:
		options.append(branch.label)

	# Mostrar mensaje con opciones usando DisplayManager
	# Siempre pasar close_at_end=false para dejar que el branch decida
	_selected_index = await DisplayManager.show_message_with_choices(message, options, false)

	print("ShowChoicesCommand: Opción seleccionada: %d (%s)" % [_selected_index, options[_selected_index] if _selected_index >= 0 else "Cancelado"])

	# Ejecutar los comandos del branch seleccionado
	if _selected_index >= 0 and _selected_index < branches.size():
		var selected_branch = branches[_selected_index]

		# Guardar resultado en variable global si está configurado
		if not store_result_in.is_empty():
			# Si el branch tiene value_stored informado, usar ese valor
			# Si no, guardar null
			var value_to_store: Variant
			if selected_branch.value_stored != null:
				# Verificar si es string vacío (también se considera "no informado")
				if typeof(selected_branch.value_stored) == TYPE_STRING and selected_branch.value_stored == "":
					value_to_store = null
				else:
					value_to_store = selected_branch.value_stored
			else:
				value_to_store = null

			GameStateService.set_variable(store_result_in, value_to_store)
			print("ShowChoicesCommand: Resultado guardado en variable '%s' = %s (tipo: %s)" % [store_result_in, value_to_store, typeof(value_to_store)])
		print("ShowChoicesCommand: Ejecutando branch '%s' con %d comandos" % [selected_branch.label, selected_branch.commands.size()])

		# Activar el flag de branch para prevenir que continue_execution() avance el EventController
		if context is EventController:
			context.executing_branch = true

		# Ejecutar cada comando del branch secuencialmente
		for i in range(selected_branch.commands.size()):
			var command = selected_branch.commands[i]
			if command == null:
				push_warning("ShowChoicesCommand: Comando null en branch '%s' (índice %d)" % [selected_branch.label, i])
				continue

			print("ShowChoicesCommand: Ejecutando comando: %s" % command.get_command_name())
			await command.execute(context)

			# Esperar un frame entre comandos para evitar bloqueos
			await context.get_tree().process_frame

		# Desactivar el flag de branch
		if context is EventController:
			context.executing_branch = false

		# Cerrar el MessageBox si el branch lo indica
		if selected_branch.close_previous_message:
			DisplayManager.close_message()
	elif _selected_index == -1:
		print("ShowChoicesCommand: El jugador canceló la selección")
		# Si se cancela, cerrar el MessageBox
		DisplayManager.close_message()
	else:
		push_error("ShowChoicesCommand: Índice seleccionado fuera de rango: %d" % _selected_index)

	# Continuar con el siguiente comando del evento principal
	print("ShowChoicesCommand: Finalizando, continuando ejecución del evento")
	context.continue_execution()


## Valida que la configuración del comando sea correcta
func _validate_configuration() -> bool:
	if message.is_empty():
		push_error("ShowChoicesCommand: El mensaje está vacío")
		return false

	if branches.is_empty():
		push_error("ShowChoicesCommand: No hay branches configurados")
		return false

	if branches.size() < 2:
		push_warning("ShowChoicesCommand: Solo hay %d branch(es), se recomienda al menos 2" % branches.size())

	if branches.size() > 4:
		push_warning("ShowChoicesCommand: Hay %d branches, puede ser difícil de leer en pantalla" % branches.size())

	# Validar cada branch
	for i in range(branches.size()):
		var branch = branches[i]
		if branch == null:
			push_error("ShowChoicesCommand: Branch %d es null" % i)
			return false
		if branch.label.is_empty():
			push_error("ShowChoicesCommand: Branch %d tiene label vacío" % i)
			return false

	return true


## Indica si este comando es asíncrono
func is_async() -> bool:
	return true


## Indica si este comando es seguro para ejecución paralela
func is_safe_for_parallel() -> bool:
	return false  # Las opciones requieren input del jugador y bloquean el flujo
