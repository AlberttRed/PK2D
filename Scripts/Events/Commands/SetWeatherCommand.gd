extends EventCommand
class_name SetWeatherCommand

## Comando para cambiar el clima visual del OverlayLayer

@export_enum("none", "rain", "snow", "fog", "storm")
var weather_type: String = "none"

func execute(context: Node) -> void:
	var overworld_context := _get_overworld_context(context)
	if not overworld_context:
		push_warning("SetWeatherCommand: OverworldContext no disponible")
		context.continue_execution()
		return

	var overlay := overworld_context.get_overlay_layer()
	if not overlay:
		push_warning("SetWeatherCommand: OverlayLayer no disponible")
		context.continue_execution()
		return

	overlay.set_weather(weather_type)
	context.continue_execution()


func is_async() -> bool:
	return false


func is_safe_for_parallel() -> bool:
	return true


func _get_overworld_context(context: Node) -> OverworldContext:
	if context is EventController:
		var event_system = context.get_parent() as EventSystem
		if event_system and event_system.context:
			return event_system.context
	return null

