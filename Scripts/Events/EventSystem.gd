extends Node
class_name EventSystem

## EventSystem - Sistema global centralizado de ejecución de eventos
## - Un único EventController global (hijo)
## - Cola de EventPage (copias) con prioridad para Autorun
## - Ejecución secuencial (no hay dos a la vez)
##
## Utiliza OverworldContext para acceso directo al Player y otros sistemas
##
# Señales locales del EventSystem
signal event_requested(event)
signal event_started(event)
signal event_finished(event)

# Referencia al OverworldContext (inyectada desde OverworldCoordinator)
var context: OverworldContext = null

var controller: EventController
var page_queue: Array[EventPage] = []
var parallel_controllers: Array[EventController] = []

func _ready() -> void:
	# Crear el controlador global (Nodo) y añadirlo al árbol con nombre
	controller = EventController.new()
	controller.name = "EventController"
	add_child(controller)

	# Reaccionar al fin de página para despachar la siguiente
	controller.page_finished.connect(_on_page_finished)

	# Inyectar contexto al controlador si está disponible
	if context:
		controller.context = context

## Solicita la ejecución de un evento desde un nodo Event
func request_event(event: Event) -> void:
	if not event or not event.current_page:
		return

	# Verificar si este mismo evento ya está en ejecución
	if _is_event_running(event):
		print("EventSystem: Evento '%s' ya está en ejecución - ignorando solicitud duplicada" % event.name)
		return

	# Emitir señal local para notificar la solicitud
	event_requested.emit(event)

	# Copiar la EventPage para desacoplarla del nodo/escena original
	var page_copy := event.current_page.duplicate(true) as EventPage
	if not page_copy:
		push_warning("EventSystem: No se pudo duplicar la EventPage")
		return

	# Asignar el Event de origen a la copia
	page_copy.source_event = event

	# Si la página es paralela, crear un controlador independiente y no bloquear la cola principal
	if page_copy.execution_mode == EventPage.ExecutionMode.PARALLEL:
		_start_parallel_page(page_copy)
		# No emitir event_started para paralelas (no bloquean); quienes lo necesiten pueden escuchar page_finished
		return

	# Verificar si es autorun usando el nuevo sistema de triggers
	var page_trigger = page_copy.get_effective_trigger()
	var is_autorun = page_trigger is AutorunTrigger

	enqueue_page(page_copy, is_autorun)

## Encola una EventPage (copiada). Autorun va al frente con prioridad.
func enqueue_page(page: EventPage, autorun_priority: bool) -> void:
	if autorun_priority:
		page_queue.insert(0, page)
	else:
		page_queue.append(page)

	# Intentar arrancar si el controlador está libre
	_try_start_next()

## Arranca la siguiente página si el controlador está libre
func _try_start_next() -> void:
	if controller and not controller.is_busy() and not page_queue.is_empty():
		var next_page: EventPage = page_queue.pop_front()
		# Emitir señal local de comienzo
		event_started.emit(next_page.source_event)
		controller.start_page(next_page)

## Al terminar una página, emitir la señal local y arrancar la siguiente
func _on_page_finished(_page: EventPage) -> void:
	event_finished.emit(_page.source_event)
	_try_start_next()

func _start_parallel_page(page: EventPage) -> void:
	var ctrl := EventController.new()
	ctrl.name = "ParallelController_%s" % str(Time.get_ticks_msec())
	add_child(ctrl)
	parallel_controllers.append(ctrl)
	# No bloquear jugador aquí: el control se conserva salvo bloqueo explícito por comando
	ctrl.page_finished.connect(_on_parallel_page_finished)
	if context:
		ctrl.context = context
	# Emitir que el evento comenzó (modo paralelo)
	event_started.emit(page.source_event)
	ctrl.start_page(page)
	ctrl.set_process(true)


func _on_parallel_page_finished(_page: EventPage) -> void:
	# Limpiar lista de controladores paralelos ya finalizados
	parallel_controllers = parallel_controllers.filter(func(c): return is_instance_valid(c) and c.is_busy())

## Exponer estado para otros sistemas
func is_any_controller_busy() -> bool:
	var any_parallel := false
	for c in parallel_controllers:
		if is_instance_valid(c) and c.is_busy():
			any_parallel = true
			break
	return (controller != null and controller.is_busy()) or any_parallel

## (Opcional) helpers de bloqueo de jugador si otros sistemas lo requieren
## NOTA: Se prefiere usar context.get_player().block_controls() directamente
func block_player_control() -> void:
	if context:
		context.block_player_control()
	else:
		push_warning("EventSystem: Contexto no disponible para bloquear control del jugador")

func unblock_player_control() -> void:
	if context:
		context.unblock_player_control()
	else:
		push_warning("EventSystem: Contexto no disponible para desbloquear control del jugador")

## Verifica si un evento específico ya está en ejecución
func _is_event_running(event: Event) -> bool:
	# Verificar en el controlador principal
	if controller and controller.current_page and controller.current_page.source_event == event:
		return true

	# Verificar en la cola de eventos
	if page_queue.any(func(page): return page.source_event == event):
		return true

	# Verificar en los controladores paralelos
	if parallel_controllers.any(func(ctrl): return is_instance_valid(ctrl) and ctrl.current_page and ctrl.current_page.source_event == event):
		return true

	return false

func set_context(overworld_context: OverworldContext) -> void:
	context = overworld_context
	if controller:
		controller.context = context
