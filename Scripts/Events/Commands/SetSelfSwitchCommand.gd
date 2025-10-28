extends EventCommand
class_name SetSelfSwitchCommand

## Comando para establecer self-switches locales del evento
## Los self-switches son específicos de cada evento y se usan para trackear su estado interno

@export_group("Self Switch")
## Letra del self-switch (A, B, C o D)
@export_enum("A", "B", "C", "D") var switch_letter: int = 0

## Valor a establecer (true/false)
@export var switch_value: bool = true

func execute(context: Node) -> void:
	# Obtener el ID del evento actual
	var event_id = _get_current_event_id(context)
	if event_id.is_empty():
		push_warning("SetSelfSwitchCommand: No se pudo determinar el ID del evento")
		return
	
	var letter = ["A", "B", "C", "D"][switch_letter]
	
	print("SetSelfSwitchCommand: Event '%s' - Switch %s = %s" % [event_id, letter, switch_value])
	GameStateManager.set_self_switch(event_id, letter, switch_value)

## Obtiene el ID del evento que está ejecutando este comando
func _get_current_event_id(context: Node) -> String:
	# context es EventController, que tiene current_page con source_event
	if context.current_page != null:
		var page = context.current_page
		if page.source_event:
			return page.source_event.name  # Usa el nombre del nodo como ID
	
	return ""

func is_async() -> bool:
	return false

func is_safe_for_parallel() -> bool:
	return true
