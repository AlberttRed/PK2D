extends EventCommand
class_name SetFlashlightCommand

## Comando para habilitar o deshabilitar la máscara de destello del OverlayLayer

@export var enabled: bool = true
@export_range(0.05, 1.0, 0.01) var radius: float = 0.35
@export_range(0.01, 0.5, 0.01) var softness: float = 0.25
@export var apply_center: bool = false
@export var center: Vector2 = Vector2(0.5, 0.5)

func execute(context: Node) -> void:
	var overworld_context := _get_overworld_context(context)
	if not overworld_context:
		push_warning("SetFlashlightCommand: OverworldContext no disponible")
		context.continue_execution()
		return

	var mo_system := overworld_context.get_mo_system()
	if not mo_system:
		push_warning("SetFlashlightCommand: MOSystem no disponible")
		context.continue_execution()
		return

	var config: Dictionary = {
		"radius": radius,
		"softness": softness,
	}

	if apply_center:
		config["center"] = center

	mo_system.apply_flash_light(enabled, config)
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

