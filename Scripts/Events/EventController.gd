extends Node
class_name EventController

## EventController - Ejecutor de eventos específico de un mapa
## Gestiona la ejecución de eventos de un mapa individual

signal event_started(event: Event)
signal event_finished(event: Event)

enum State { IDLE, RUNNING }

var current_state: State = State.IDLE
var current_event: Event = null
var command_queue: Array[EventCommand] = []
var current_command_index: int = 0

# Referencias del mapa
var map_node: Node = null
var grid: OverworldGrid = null

func _ready() -> void:
	# El EventController debe ser hijo de un mapa
	map_node = get_parent()
	
	# Buscar el OverworldGrid de este mapa
	grid = map_node.get_node_or_null("OverworldGrid")
	if not grid:
		push_warning("EventController: No se encontró OverworldGrid en el mapa '%s'" % map_node.name)
	
	# Conectar señales
	event_finished.connect(_on_event_finished)
	
	# Registrarse en el EventSystem
	# Por defecto, el primer controlador se registra como principal
	# Esto se puede cambiar dinámicamente cuando el jugador cambie de mapa
	EventSystem.register_controller(self, true)

## --- Control de Estado ---
func is_busy() -> bool:
	return current_state == State.RUNNING

func can_start_event(event: Event) -> bool:
	return current_state == State.IDLE and event != null

## --- Ejecución de Eventos ---
func start_event(event: Event) -> bool:
	if not can_start_event(event):
		print("EventController: No se puede iniciar evento '%s' - ya hay uno en curso" % event.event_name)
		return false
	
	if not event.current_page or event.current_page.commands.is_empty():
		print("EventController: Evento '%s' no tiene comandos para ejecutar" % event.event_name)
		return false
	
	# Configurar estado
	current_state = State.RUNNING
	current_event = event
	command_queue = event.current_page.commands.duplicate()
	current_command_index = 0
	
	# Bloquear control del jugador
	block_player_control()
	
	# Emitir señal
	event_started.emit(event)
	
	print("EventController: Iniciando evento '%s' con %d comandos" % [event.event_name, command_queue.size()])
	
	# Ejecutar primer comando
	execute_next_command()
	
	return true

func execute_next_command() -> void:
	if current_command_index >= command_queue.size():
		finish_event()
		return
	
	var command = command_queue[current_command_index]
	print("EventController: Ejecutando comando %d: %s" % [current_command_index, command.command_name])
	
	# Ejecutar comando
	command.execute(self)
	
	# Avanzar al siguiente comando
	current_command_index += 1
	
	# Si el comando no es asíncrono, continuar inmediatamente
	if not command.has_method("is_async") or not command.is_async():
		call_deferred("execute_next_command")

func finish_event() -> void:
	if current_state != State.RUNNING:
		return
	
	var finished_event = current_event
	
	# Limpiar estado
	current_state = State.IDLE
	current_event = null
	command_queue.clear()
	current_command_index = 0
	
	# Desbloquear control del jugador
	unblock_player_control()
	
	# Emitir señal
	event_finished.emit(finished_event)
	
	print("EventController: Evento '%s' finalizado" % finished_event.event_name)

## --- Control del Jugador ---
func block_player_control() -> void:
	# Delegar al EventSystem para control global
	EventSystem.block_player_control()

func unblock_player_control() -> void:
	# Delegar al EventSystem para control global
	EventSystem.unblock_player_control()


##Llamado por comandos asíncronos cuando terminan
func continue_execution() -> void:
	if current_state == State.RUNNING:
		call_deferred("execute_next_command")

##Permite a los comandos saltarse a sí mismos
func skip_current_command() -> void:
	if current_state == State.RUNNING:
		current_command_index += 1
		call_deferred("execute_next_command")

##Notifica al EventSystem que terminó un evento
func _on_event_finished(event: Event) -> void:
	EventSystem.on_controller_event_finished(self)
