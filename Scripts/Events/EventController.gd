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
	
	# Trabajar con copias de los comandos para desacoplar de recursos originales
	for c in page.commands:
		if c:
			command_queue.append(c.duplicate(true))
	
	# Bloqueo de jugador según la página
	if page.blocks_player:
		SignalManager.player_control_blocked.emit()
	else:
		SignalManager.player_control_unblocked.emit()
	
	page_started.emit(page)
	
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
	
	current_command_index += 1
	
	# Si el comando no es asíncrono, continuar inmediatamente
	if not command or not command.has_method("is_async") or not command.is_async():
		call_deferred("execute_next_command")

func continue_execution() -> void:
	if current_state == State.RUNNING:
		call_deferred("execute_next_command")

func skip_current_command() -> void:
	if current_state == State.RUNNING:
		current_command_index += 1
		call_deferred("execute_next_command")

func finish_page() -> void:
	if current_state != State.RUNNING:
		return
	
	var finished := current_page
	
	# SIEMPRE desbloquear control del jugador al terminar
	SignalManager.player_control_unblocked.emit()
	
	# Limpiar estado
	current_state = State.IDLE
	current_page = null
	command_queue.clear()
	current_command_index = 0
	
	page_finished.emit(finished)

## Compatibilidad con comandos existentes
func block_player_control() -> void:
	SignalManager.player_control_blocked.emit()

func unblock_player_control() -> void:
	SignalManager.player_control_unblocked.emit()
