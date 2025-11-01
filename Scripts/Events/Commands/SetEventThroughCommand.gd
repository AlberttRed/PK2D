extends EventCommand
class_name SetEventThroughCommand

## Comando para cambiar la propiedad 'through' de un evento
## Útil para puertas que se abren/cierran, objetos que se activan/desactivan, etc.

@export var target_event_name: String = ""
@export var through: bool = true

func execute(context: Node) -> void:
	var target_event: Event = null

	# Si target_event_name está vacío, usar el evento actual (self)
	if target_event_name.is_empty():
		# El contexto es el EventController, necesitamos obtener el evento origen
		if context is EventController and context.current_page:
			target_event = context.current_page.source_event
			if target_event:
				print("SetEventThroughCommand: Usando evento actual '%s'" % target_event.name)

		if not target_event:
			push_warning("SetEventThroughCommand: No se pudo obtener el evento actual")
			return
	else:
		# Buscar el evento por nombre
		target_event = _find_event(context, target_event_name)

		if not target_event:
			push_warning("SetEventThroughCommand: No se encontró el evento '%s'" % target_event_name)
			return

	# Cambiar la propiedad through de la página actual
	if target_event.current_page:
		target_event.current_page.through = through
		print("SetEventThroughCommand: Evento '%s' through = %s" % [target_event.name, through])

		# Actualizar ocupación en el grid
		if target_event.has_method("_refresh_occupancy"):
			target_event._refresh_occupancy()
	else:
		push_warning("SetEventThroughCommand: El evento '%s' no tiene página activa" % target_event.name)

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
