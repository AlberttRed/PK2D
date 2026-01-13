extends EventCommand
class_name ConditionalCommand

## ConditionalCommand - Ejecuta ramas de comandos según condiciones evaluadas
##
## Permite crear lógica condicional (if/else if/else) dentro de eventos,
## similar al sistema de condicionales de RPG Maker.
##
## Uso:
## 1. Añadir este comando a la lista de comandos de una EventPage
## 2. Crear EventBranch para cada rama condicional
## 3. Configurar la condición (EventCondition) en cada branch
## 4. Si condition == null, la rama actúa como ELSE (rama por defecto)
##
## Ejemplo:
## Branch 0: condition=GlobalFlagCondition("has_pokeball") → [ShowMessageCommand("Tienes una Pokéball")]
## Branch 1: condition=VariableCondition("money", GREATER, 1000) → [ShowMessageCommand("Tienes mucho dinero")]
## Branch 2: condition=null (ELSE) → [ShowMessageCommand("No cumples ninguna condición")]
##
## Las ramas se evalúan en orden y se ejecuta solo la primera que cumpla la condición.
## Si ninguna condición se cumple y no hay rama ELSE, no se ejecuta nada.

@export_group("Branches Configuration")

## Lista de ramas condicionales a evaluar
## Se evalúan en orden y se ejecuta solo la primera que cumpla la condición
## Si condition == null, la rama actúa como ELSE (rama por defecto)
@export var branches: Array[EventBranch] = []


func execute(context: Node) -> void:
	# Validar configuración
	if not _validate_configuration():
		push_error("ConditionalCommand: Configuración inválida, saltando comando")
		context.continue_execution()
		return

	# Obtener el event_uid para crear el contexto de evaluación
	var event_uid = _get_current_event_id(context)

	# Obtener el evento fuente desde el contexto
	var source_event: Event = null
	if context is EventController and context.current_page:
		source_event = context.current_page.source_event

	# Crear el contexto de evaluación de condiciones
	var condition_context = EventConditionContext.new(event_uid, GameStateService)
	condition_context.source_event = source_event

	# Primero, evaluar todas las ramas que tienen condición
	# Solo si ninguna se cumple, buscar y ejecutar la rama ELSE (condition == null)
	var else_branch: EventBranch = null

	for i in range(branches.size()):
		var branch = branches[i]
		if branch == null:
			push_warning("ConditionalCommand: Branch %d es null, saltando" % i)
			continue

		# Si la condición es null, guardar como rama ELSE pero no ejecutarla aún
		if branch.condition == null:
			else_branch = branch
			continue

		# Evaluar la condición
		var condition_met = branch.condition.evaluate(condition_context)

		if condition_met:
			# Esta rama se cumple, ejecutarla y retornar
			_execute_branch_commands(branch, context)
			return

	# Si llegamos aquí, ninguna condición se cumplió
	# Si hay una rama ELSE, ejecutarla
	if else_branch != null:
		_execute_branch_commands(else_branch, context)
		return

	# Si no hay rama ELSE y ninguna condición se cumplió, no hacer nada
	# Continuar con el siguiente comando del evento principal
	context.continue_execution()


## Ejecuta los comandos de una rama secuencialmente
func _execute_branch_commands(branch: EventBranch, context: Node) -> void:
	# Activar el flag de branch para prevenir que continue_execution() avance el EventController
	if context is EventController:
		context.executing_branch = true

	# Ejecutar cada comando del branch secuencialmente
	for i in range(branch.commands.size()):
		var command = branch.commands[i]
		if command == null:
			push_warning("ConditionalCommand: Comando null en branch (índice %d)" % i)
			continue

		await command.execute(context)

		# Esperar un frame entre comandos para evitar bloqueos
		if context.has_method("get_tree"):
			await context.get_tree().process_frame

	# Desactivar el flag de branch
	if context is EventController:
		context.executing_branch = false

	# Continuar con el siguiente comando del evento principal
	context.continue_execution()


## Valida que la configuración del comando sea correcta
func _validate_configuration() -> bool:
	if branches.is_empty():
		push_warning("ConditionalCommand: No hay branches configurados, el comando no hará nada")
		# No es un error, simplemente no ejecutará nada
		return true

	# Validar cada branch
	for i in range(branches.size()):
		var branch = branches[i]
		if branch == null:
			push_warning("ConditionalCommand: Branch %d es null, se ignorará" % i)
			continue

		# Validar que tenga comandos (aunque puede estar vacío, no es un error)
		if branch.commands.is_empty():
			push_warning("ConditionalCommand: Branch %d no tiene comandos, no ejecutará nada" % i)

	return true


## Obtiene el ID del evento que está ejecutando este comando
func _get_current_event_id(context: Node) -> String:
	# context es EventController, que tiene current_page con source_event
	if context is EventController and context.current_page != null:
		var page = context.current_page
		if page.source_event:
			# Usar el método _get_event_id() del Event para incluir el map_id
			if page.source_event.has_method("_get_event_id"):
				return page.source_event._get_event_id()
			return page.source_event.name  # Fallback si no tiene el método

	return ""


## Indica si este comando es asíncrono
func is_async() -> bool:
	return true  # Es asíncrono porque ejecuta comandos hijos


## Indica si este comando es seguro para ejecución paralela
func is_safe_for_parallel() -> bool:
	return false  # No es seguro para paralelo porque ejecuta comandos hijos secuencialmente
