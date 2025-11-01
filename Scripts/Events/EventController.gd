extends Node
class_name EventController

## Controlador GLOBAL de ejecución de eventos (EventPage)
## Debe ser hijo de EventSystem. Ejecuta páginas de evento (copias) en orden.

signal page_started(page: EventPage)
signal page_finished(page: EventPage)

enum State { IDLE, RUNNING }

var current_state: State = State.IDLE
var current_page: EventPage = null
var command_queue: Array[EventCommand] = []
var current_command_index: int = 0
var is_parallel: bool = false
var waiting_async: bool = false
var blocked_by_page: bool = false

func is_busy() -> bool:
	return current_state == State.RUNNING

## Inicia la ejecución de una EventPage (se asume que ya es una copia)
func start_page(page: EventPage) -> bool:
	if current_state != State.IDLE or page == null:
		push_warning("EventController: No se puede iniciar página - ya hay una en curso o es nula")
		return false

	if page.commands.is_empty():
		push_warning("EventController: La página no tiene comandos para ejecutar")
		return false

	current_state = State.RUNNING
	current_page = page
	command_queue.clear()
	current_command_index = 0
	waiting_async = false
	is_parallel = page.execution_mode == EventPage.ExecutionMode.PARALLEL

	# Trabajar con copias de los comandos para desacoplar de recursos originales
	for c in page.commands:
		if not c:
			continue
		var cmd: EventCommand = c.duplicate(true)
		if is_parallel:
			if cmd and cmd.has_method("is_safe_for_parallel") and cmd.is_safe_for_parallel():
				command_queue.append(cmd)
			else:
				var command_name := "<unknown>"
				if cmd != null:
					command_name = cmd.get_command_name()
				push_error("EventController(Parallel): Comando '%s' no es válido en paralelo. Se ignora." % command_name)
		else:
			command_queue.append(cmd)

	# Bloqueo de jugador según la página
	blocked_by_page = (not is_parallel) and page.blocks_player
	if blocked_by_page:
		SignalManager.player_control_blocked.emit()
	else:
		SignalManager.player_control_unblocked.emit()

	page_started.emit(page)
	if is_parallel:
		set_process(true)
	else:
		call_deferred("execute_next_command")
	return true

func execute_next_command() -> void:
	if current_command_index >= command_queue.size():
		finish_page()
		return

	var command = command_queue[current_command_index]
	# Ejecutar comando con este controlador como contexto
	if command and command.has_method("execute"):
		command.execute(self)

	# Si el comando no es asíncrono, continuar inmediatamente
	if not command or not command.has_method("is_async") or not command.is_async():
		current_command_index += 1
		call_deferred("execute_next_command")
	else:
		# Es asíncrono: incrementar índice ahora para que continue_execution() ejecute el siguiente
		current_command_index += 1

func continue_execution() -> void:
	if current_state != State.RUNNING:
		return
	if is_parallel:
		waiting_async = false
		current_command_index += 1
	else:
		call_deferred("execute_next_command")

func skip_current_command() -> void:
	if current_state != State.RUNNING:
		return
	current_command_index += 1
	if is_parallel:
		waiting_async = false
	else:
		call_deferred("execute_next_command")

func finish_page() -> void:
	if current_state != State.RUNNING:
		return

	var finished := current_page

	# Comprobar si hay comandos todavía ejecutándose
	if _has_commands_still_running():
		await _wait_for_commands_to_complete()

	# Desbloquear control del jugador solo si fue bloqueado por la página (modo en cola)
	if blocked_by_page:
		SignalManager.player_control_unblocked.emit()

	# Limpiar estado
	current_state = State.IDLE
	current_page = null
	command_queue.clear()
	current_command_index = 0
	waiting_async = false
	if is_parallel:
		set_process(false)
	is_parallel = false

	page_finished.emit(finished)

## Compatibilidad con comandos existentes
func block_player_control() -> void:
	SignalManager.player_control_blocked.emit()

func unblock_player_control() -> void:
	SignalManager.player_control_unblocked.emit()

## Comprueba si hay comandos todavía ejecutándose
func _has_commands_still_running() -> bool:
	for cmd in command_queue:
		if cmd and cmd.has_method("is_running") and cmd.is_running():
			return true
	return false

## Espera a que todos los comandos terminen su ejecución
func _wait_for_commands_to_complete() -> void:
	while _has_commands_still_running():
		await get_tree().process_frame

func _process(_delta: float) -> void:
	if current_state != State.RUNNING or not is_parallel:
		return
	if waiting_async:
		return
	if current_command_index >= command_queue.size():
		finish_page()
		return
	var command := command_queue[current_command_index]
	if command and command.has_method("execute"):
		command.execute(self)
	# Si es asíncrono, esperar a continue_execution; si no, avanzar para el próximo frame
	if command and command.has_method("is_async") and command.is_async():
		waiting_async = true
	else:
		current_command_index += 1
