extends EventCommand
class_name SwitchCommand

## SwitchCommand - Ejecuta bloques de comandos según el valor de una variable
##
## Permite crear lógica de tipo switch/case dentro de eventos,
## evaluando el valor de una variable global y ejecutando el bloque correspondiente.
##
## Uso:
## 1. Añadir este comando a la lista de comandos de una EventPage
## 2. Crear SwitchCase para cada caso posible
## 3. Configurar los valores que activan cada caso en SwitchCase.values
## 4. Configurar los comandos a ejecutar en SwitchCase.commands
## 5. (Opcional) Configurar default_commands para el caso por defecto
##
## Ejemplo:
## variable_name = "player_level"
## Case 0: values=[1, 2, 3] → [ShowMessageCommand("Eres novato")]
## Case 1: values=[10, 20, 30] → [ShowMessageCommand("Eres experimentado")]
## Case 2: values=[50, 100] → [ShowMessageCommand("Eres experto")]
## default_commands: [ShowMessageCommand("Nivel desconocido")]

@export_group("Switch Configuration")

## Nombre de la variable a evaluar (debe existir en GameStateService.game_variables)
@export var variable_name: String = ""

## Lista de casos a evaluar en orden
## Se ejecuta solo el primer caso cuyo values contenga el valor evaluado
@export var cases: Array[SwitchCase] = []

## Comandos a ejecutar si ningún caso coincide (opcional)
## Si está vacío y ningún caso coincide, el comando finaliza sin error
@export var default_commands: Array[EventCommand] = []


func execute(context: Node) -> void:
	# Validar configuración
	if not _validate_configuration():
		push_error("SwitchCommand: Configuración inválida, saltando comando")
		context.continue_execution()
		return

	# Obtener el valor de la variable
	var variable_value = GameStateService.get_variable(variable_name, null)

	# Buscar el primer caso que coincida
	var matched_case = _find_matching_case(variable_value)

	if matched_case != null:
		# Ejecutar los comandos del caso que coincidió
		_execute_case_commands(matched_case, context)
		return

	# Si ningún caso coincidió, ejecutar default_commands si está definido
	if not default_commands.is_empty():
		_execute_default_commands(context)
		return

	# Si no hay default_commands, finalizar sin error
	context.continue_execution()


## Busca el primer caso cuyo values contenga el valor evaluado
func _find_matching_case(variable_value: Variant) -> SwitchCase:
	for i in range(cases.size()):
		var switch_case = cases[i]
		if switch_case == null:
			push_warning("SwitchCommand: Case %d es null, saltando" % i)
			continue

		# Verificar si el valor evaluado está en la lista de values de este caso
		if _value_matches_case(variable_value, switch_case.values):
			return switch_case

	return null


## Verifica si el valor evaluado coincide con alguno de los values del caso
func _value_matches_case(variable_value: Variant, case_values: Array[Variant]) -> bool:
	for case_value in case_values:
		# Comparación estricta usando ==
		# Esto funciona correctamente para int, bool, String, float, etc.
		if variable_value == case_value:
			return true

	return false


## Ejecuta los comandos de un caso secuencialmente
func _execute_case_commands(switch_case: SwitchCase, context: Node) -> void:
	# Activar el flag de branch para prevenir que continue_execution() avance el EventController
	if context is EventController:
		context.executing_branch = true

	# Ejecutar cada comando del caso secuencialmente
	for i in range(switch_case.commands.size()):
		var command = switch_case.commands[i]
		if command == null:
			push_warning("SwitchCommand: Comando null en case (índice %d)" % i)
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


## Ejecuta los comandos por defecto secuencialmente
func _execute_default_commands(context: Node) -> void:
	# Activar el flag de branch para prevenir que continue_execution() avance el EventController
	if context is EventController:
		context.executing_branch = true

	# Ejecutar cada comando por defecto secuencialmente
	for i in range(default_commands.size()):
		var command = default_commands[i]
		if command == null:
			push_warning("SwitchCommand: Comando null en default_commands (índice %d)" % i)
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
	if variable_name.is_empty():
		push_warning("SwitchCommand: variable_name está vacío, el comando no hará nada")
		# No es un error fatal, simplemente no ejecutará nada
		return true

	if cases.is_empty() and default_commands.is_empty():
		push_warning("SwitchCommand: No hay cases ni default_commands configurados, el comando no hará nada")
		# No es un error fatal, simplemente no ejecutará nada
		return true

	# Validar cada case
	for i in range(cases.size()):
		var switch_case = cases[i]
		if switch_case == null:
			push_warning("SwitchCommand: Case %d es null, se ignorará" % i)
			continue

		# Validar que tenga valores (aunque puede estar vacío, no es un error)
		if switch_case.values.is_empty():
			push_warning("SwitchCommand: Case %d no tiene values, nunca coincidirá" % i)

		# Validar que tenga comandos (aunque puede estar vacío, no es un error)
		if switch_case.commands.is_empty():
			push_warning("SwitchCommand: Case %d no tiene comandos, no ejecutará nada" % i)

	return true


## Indica si este comando es asíncrono
func is_async() -> bool:
	return true  # Es asíncrono porque ejecuta comandos hijos


## Indica si este comando es seguro para ejecución paralela
func is_safe_for_parallel() -> bool:
	return false  # No es seguro para paralelo porque ejecuta comandos hijos secuencialmente

