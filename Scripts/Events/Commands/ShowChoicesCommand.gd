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
## 3. Crear EventBranch para cada opción disponible
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
@export var branches: Array[EventBranch] = []

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

	# Usar SignalManager para comunicarse con el GUI (método correcto)
	if not SignalManager:
		push_error("ShowChoicesCommand: SignalManager no disponible")
		context.continue_execution()
		return

	# Mostrar mensaje con opciones usando SignalManager
	SignalManager.choice_requested.emit(message, options)
	_selected_index = await SignalManager.choice_finished

	print("ShowChoicesCommand: Opción seleccionada: %d (%s)" % [_selected_index, options[_selected_index] if _selected_index >= 0 else "Cancelado"])

	# Guardar resultado en variable global si está configurado
	if not store_result_in.is_empty():
		GameStateManager.set_event_variable(store_result_in, _selected_index)
		print("ShowChoicesCommand: Resultado guardado en variable '%s' = %d" % [store_result_in, _selected_index])

	# Ejecutar los comandos del branch seleccionado
	if _selected_index >= 0 and _selected_index < branches.size():
		var selected_branch = branches[_selected_index]
		print("ShowChoicesCommand: Ejecutando branch '%s' con %d comandos" % [selected_branch.label, selected_branch.commands.size()])

		# Ejecutar cada comando del branch secuencialmente
		for command in selected_branch.commands:
			if command == null:
				push_warning("ShowChoicesCommand: Comando null en branch '%s'" % selected_branch.label)
				continue

			print("ShowChoicesCommand: Ejecutando comando: %s" % command.get_command_name())
			await command.execute(context)

			# Esperar un frame entre comandos para evitar bloqueos
			await context.get_tree().process_frame
	elif _selected_index == -1:
		print("ShowChoicesCommand: El jugador canceló la selección")
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
