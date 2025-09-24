extends Node
class_name EventSystem

## EventSystem - Sistema global centralizado de ejecución de eventos
## - Un único EventController global (hijo)
## - Cola de EventPage (copias) con prioridad para Autorun
## - Ejecución secuencial (no hay dos a la vez)

var controller: EventController
var page_queue: Array[EventPage] = []

func _ready() -> void:
	# Conectar señales del SignalManager
	SignalManager.event_requested.connect(_on_event_requested)
	
	# Crear el controlador global (Nodo) y añadirlo al árbol con nombre
	controller = EventController.new()
	controller.name = "EventController"
	add_child(controller)
	
	# Reaccionar al fin de página para despachar la siguiente
	controller.page_finished.connect(_on_page_finished)
	
	# Notificar que el sistema está listo
	SignalManager.event_system_ready.emit(self)

## Señal: petición de ejecución de un evento desde un nodo Event
func _on_event_requested(event: Event, _controller: EventController) -> void:
	if not event or not event.current_page:
		return
	
	# Copiar la EventPage para desacoplarla del nodo/escena original
	var page_copy := event.current_page.duplicate(true) as EventPage
	if not page_copy:
		push_warning("EventSystem: No se pudo duplicar la EventPage")
		return
	
	var is_autorun := page_copy.trigger_type == EventTriggers.TriggerType.AUTORUN
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
		# Emitir señal global de comienzo (independiente del nodo Event)
		SignalManager.event_started.emit(null)
		controller.start_page(next_page)

## Al terminar una página, emitir la señal global y arrancar la siguiente
func _on_page_finished(_page: EventPage) -> void:
	SignalManager.event_finished.emit(null)
	_try_start_next()

## Exponer estado para otros sistemas
func is_any_controller_busy() -> bool:
	return controller != null and controller.is_busy()

## (Opcional) helpers de bloqueo de jugador si otros sistemas lo requieren
func block_player_control() -> void:
	SignalManager.player_control_blocked.emit()

func unblock_player_control() -> void:
	SignalManager.player_control_unblocked.emit()
