extends EventCommand
class_name SetDarknessCommand

## Comando para ajustar la oscuridad global del OverlayLayer

@export_range(0.0, 1.0, 0.01)
var darkness: float = 0.0

@export_range(0.0, 5.0, 0.05)
var transition_time: float = 0.3

func execute(context: Node) -> void:
	var overworld_context := _get_overworld_context(context)
	if not overworld_context:
		push_warning("SetDarknessCommand: OverworldContext no disponible")
		context.continue_execution()
		return

	var overlay := overworld_context.get_overlay_layer()
	if not overlay:
		push_warning("SetDarknessCommand: OverlayLayer no disponible")
		context.continue_execution()
		return

	overlay.set_darkness(darkness, transition_time)
	context.continue_execution()


func is_async() -> bool:
	return false


func is_safe_for_parallel() -> bool:
	return false


func _get_overworld_context(context: Node) -> OverworldContext:
	if context is EventController:
		var event_system = context.get_parent() as EventSystem
		if event_system and event_system.context:
			return event_system.context
	return null

