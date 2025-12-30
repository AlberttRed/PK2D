extends EventCommand
class_name SetTriggerCommand

## Comando para cambiar el trigger de una página específica de un evento
## Útil para activar/desactivar eventos dinámicamente o cambiar su comportamiento

@export_group("Target Event")
## Nombre del evento objetivo. Si está vacío, usa el evento actual
@export var target_event_name: String = ""

@export_group("Page")
## Índice de la página a modificar (0 = primera página)
@export var page_index: int = 0

@export_group("Trigger")
## El trigger a asignar a la página. Si es null, la página no se activará
## En el inspector, se asigna el script del tipo de trigger (ActionTrigger, TouchTrigger, etc.)
@export var trigger: EventTrigger = null

func execute(context: Node) -> void:
	var target_event: Event = null

	# Si target_event_name está vacío, usar el evento actual (self)
	if target_event_name.is_empty():
		# El contexto es el EventController, necesitamos obtener el evento origen
		if context is EventController and context.current_page:
			target_event = context.current_page.source_event
			if target_event:
				print("SetTriggerCommand: Usando evento actual '%s'" % target_event.name)

		if not target_event:
			push_warning("SetTriggerCommand: No se pudo obtener el evento actual")
			return
	else:
		# Buscar el evento por nombre
		target_event = _find_event(context, target_event_name)

		if not target_event:
			push_warning("SetTriggerCommand: No se encontró el evento '%s'" % target_event_name)
			return

	# Validar que el índice de página sea válido
	if page_index < 0 or page_index >= target_event.pages.size():
		push_warning("SetTriggerCommand: Índice de página %d inválido para evento '%s' (tiene %d páginas)" % [page_index, target_event.name, target_event.pages.size()])
		return

	# Obtener la página a modificar
	var page = target_event.pages[page_index]
	if not page:
		push_warning("SetTriggerCommand: La página %d del evento '%s' es null" % [page_index, target_event.name])
		return

	# Duplicar la página para poder modificarla (evitar modificar el Resource original)
	var editable_page = page.duplicate(true) as EventPage
	if not editable_page:
		push_warning("SetTriggerCommand: No se pudo duplicar la página")
		return

	# Asignar el nuevo trigger
	if trigger:
		# Duplicar el trigger para evitar compartir referencias
		editable_page.trigger = trigger.duplicate(true) as EventTrigger
	else:
		editable_page.trigger = null

	# Reemplazar la página en el array
	target_event.pages[page_index] = editable_page

	print("SetTriggerCommand: Trigger de página %d del evento '%s' cambiado" % [page_index, target_event.name])

	# Si la página modificada es la actual, refrescar para aplicar el cambio
	if target_event.current_page_index == page_index:
		target_event.refresh_active_page()

	# Los comandos síncronos NO llaman a continue_execution()
	# El EventController lo hace automáticamente

## Busca un evento por nombre en la escena
func _find_event(context: Node, event_name: String) -> Event:
	var tree = context.get_tree()
	if not tree:
		return null

	# Buscar en el grupo de eventos
	var events = tree.get_nodes_in_group("events")
	for event in events:
		if event.name == event_name:
			return event

	# Si no se encuentra en el grupo, buscar en toda la escena
	var all_nodes = tree.get_nodes_in_group("OverworldGrid")
	for grid in all_nodes:
		if grid.has_node("Events"):
			var events_container = grid.get_node("Events")
			if events_container.has_node(event_name):
				return events_container.get_node(event_name)

	return null

func is_async() -> bool:
	return false

func is_safe_for_parallel() -> bool:
	return true

