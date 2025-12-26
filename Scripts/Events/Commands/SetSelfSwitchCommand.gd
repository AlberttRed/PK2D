extends EventCommand
class_name SetSelfSwitchCommand

## Comando para establecer self-switches (event_self_flags) locales del evento
## Los self-switches se guardan en event_self_flags con formato "event_uid:switch_name"
## Son específicos de cada evento y se usan para trackear su estado interno
## Si no se especifica target_event_name, se usará el evento actual donde se ejecuta el comando
## El switch_name puede ser cualquier string (no limitado a A, B, C, D)

@export_group("Target Event")
## Nombre del evento objetivo. Si está vacío, usa el evento actual
@export var target_event_name: String = ""

@export_group("Self Switch")
## Nombre del self-switch (puede ser cualquier string, no limitado a A, B, C, D)
## Ejemplos: "A", "B", "cut", "talked", "opened", etc.
@export var switch_name: String = "A"

## Valor a establecer (true/false)
@export var switch_value: bool = true

func execute(context: Node) -> void:
	var event_id: String = ""

	# Si no se especificó nombre, usar el evento actual
	if target_event_name.is_empty():
		event_id = _get_current_event_id(context)
		if event_id.is_empty():
			push_warning("SetSelfSwitchCommand: No se pudo determinar el ID del evento actual")
			return
	else:
		# Buscar el evento por nombre y usar su _get_event_id() para incluir el map_id
		var target_event = _find_event(context, target_event_name)
		if not target_event:
			push_warning("SetSelfSwitchCommand: No se encontró el evento '%s'" % target_event_name)
			return
		# Usar el método _get_event_id() del Event para incluir el map_id
		if target_event.has_method("_get_event_id"):
			event_id = target_event._get_event_id()
		else:
			event_id = target_event.name  # Fallback si no tiene el método

	# Validar que el nombre del switch no esté vacío
	if switch_name.is_empty():
		push_error("SetSelfSwitchCommand: El nombre del self-switch está vacío")
		return

	print("SetSelfSwitchCommand: Event '%s' - Switch %s = %s" % [event_id, switch_name, switch_value])
	# Establecer self-switch en GameStateService (usa event_self_flags internamente)
	GameStateService.set_self_switch(event_id, switch_name, switch_value)

## Obtiene el ID del evento que está ejecutando este comando
func _get_current_event_id(context: Node) -> String:
	# context es EventController, que tiene current_page con source_event
	if context.current_page != null:
		var page = context.current_page
		if page.source_event:
			# Usar el método _get_event_id() del Event para incluir el map_id
			if page.source_event.has_method("_get_event_id"):
				return page.source_event._get_event_id()
			return page.source_event.name  # Fallback si no tiene el método

	return ""

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
