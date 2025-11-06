extends EventCommand
class_name SetActorVisibilityCommand

## Comando para hacer visible/invisible un evento o al jugador
## Útil para hacer aparecer/desaparecer NPCs, objetos, efectos visuales, etc.

@export_enum("Event", "Player") var target_type: int = 0
@export var target_event_name: String = ""  # Solo si target_type = Event
@export var visible: bool = true

func execute(context: Node) -> void:
	var target_actor = null

	match target_type:
		0:  # Event
			if target_event_name.is_empty():
				push_warning("SetActorVisibilityCommand: No se especificó un nombre de evento")
				return

			target_actor = _find_event(context, target_event_name)
			if not target_actor:
				push_warning("SetActorVisibilityCommand: No se encontró el evento '%s'" % target_event_name)
				return

		1:  # Player
			var overworld_context = _get_overworld_context(context)
			if overworld_context:
				target_actor = overworld_context.get_player()
			if not target_actor:
				push_error("SetActorVisibilityCommand: Player no disponible")
				return

	# Cambiar visibilidad
	_set_visibility(target_actor, visible)

	var target_name = target_event_name if target_type == 0 else "Player"
	print("SetActorVisibilityCommand: '%s' visible = %s" % [target_name, visible])

	# Los comandos síncronos NO llaman a continue_execution()
	# El EventController lo hace automáticamente

## Establece la visibilidad de un actor (Event o Player)
func _set_visibility(actor: Node, is_visible: bool) -> void:
	# Para Events, usar el método show_sprite()/hide_sprite()
	if actor is Event:
		if is_visible:
			actor.show_sprite()
		else:
			actor.hide_sprite()
	else:
		# Para Player, controlar el sprite directamente
		if actor.has_node("AnimatedSprite2D"):
			var sprite = actor.get_node("AnimatedSprite2D")
			sprite.visible = is_visible
		else:
			# Fallback: controlar la visibilidad del nodo completo
			actor.visible = is_visible

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

## Obtiene el OverworldContext desde el EventController
func _get_overworld_context(context: Node) -> OverworldContext:
	if context is EventController:
		var event_system = context.get_parent() as EventSystem
		if event_system and event_system.context:
			return event_system.context
	return null

