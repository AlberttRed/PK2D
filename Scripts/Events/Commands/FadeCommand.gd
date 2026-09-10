extends EventCommand
class_name FadeCommand

## Comando para cubrir/revelar la pantalla (fade sólido o máscara).
## IN = a negro (cubrir). OUT = desde negro (revelar).
enum FadeMode { IN, OUT }
enum FadeEffect { SOLID, MASK }

@export var mode: FadeMode = FadeMode.OUT
@export var effect: FadeEffect = FadeEffect.SOLID
@export var mask: ScreenTransitionEnum.Type = ScreenTransitionEnum.Type.DOOR
@export var duration: float = 1.0
@export var wait_for_completion: bool = true


func execute(context: Node) -> void:
	if duration < 0.0:
		push_error("FadeCommand: Duración inválida %.2f. Debe ser >= 0" % duration)
		if wait_for_completion:
			context.continue_execution()
		return

	var to_black := mode == FadeMode.IN

	match effect:
		FadeEffect.SOLID:
			if wait_for_completion:
				if to_black:
					await DisplayManager.fade_in(duration)
				else:
					await DisplayManager.fade_out(duration)
			else:
				if to_black:
					DisplayManager.fade_in(duration)
				else:
					DisplayManager.fade_out(duration)
		FadeEffect.MASK:
			if wait_for_completion:
				await DisplayManager.fade_with_mask(to_black, mask, duration)
			else:
				DisplayManager.fade_with_mask(to_black, mask, duration)

	if wait_for_completion:
		context.continue_execution()


func is_async() -> bool:
	return wait_for_completion


func is_safe_for_parallel() -> bool:
	return false
