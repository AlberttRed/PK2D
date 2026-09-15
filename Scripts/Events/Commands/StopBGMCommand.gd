extends EventCommand
class_name StopBGMCommand

## Libera el hold de BGM de evento, hace fade-out de la actual (fade_out; 0 = corte)
## y al terminar arranca la BGM del mapa/Surf a volumen pleno (sin fade-in).
## Síncrono: NO espera el fade; el EventController avanza al siguiente comando al instante.

@export var fade_out: float = 0.5


func execute(context: Node) -> void:
	AudioManager.clear_event_bgm_hold()

	var overworld_context := _get_overworld_context(context)
	if overworld_context:
		var world_system: Node = overworld_context.get_world_system()
		if world_system != null and world_system.has_method("restore_map_bgm_after_event_stop"):
			world_system.restore_map_bgm_after_event_stop(maxf(fade_out, 0.0))
			return

	AudioManager.stop_bgm(maxf(fade_out, 0.0))


func _get_overworld_context(context: Node) -> OverworldContext:
	if context is EventController:
		var event_system = context.get_parent() as EventSystem
		if event_system and event_system.context:
			return event_system.context
	return null


func is_async() -> bool:
	return false


func is_safe_for_parallel() -> bool:
	return true
