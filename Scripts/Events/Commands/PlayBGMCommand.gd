extends EventCommand
class_name PlayBGMCommand

## Cambia la BGM vía AudioManager (override explícito desde eventos).
## Misma BGM que ya suena → no reinicia (lo garantiza AudioManager).
## Síncrono: NO llamar continue_execution (lo hace EventController).

enum TransitionMode {
	FADE_IN,           ## play_bgm con fade_in (0 = corte)
	CROSSFADE,         ## crossfade paralelo
	FADE_OUT_THEN_PLAY ## Gen 3: fade-out completo → play
}

@export var bgm: AudioStream = null
@export var transition_mode: TransitionMode = TransitionMode.FADE_IN
@export var fade_duration: float = 0.5
@export var loop: bool = true
## Si true, warps y restauración post-combate no pisan esta BGM hasta un StopBGM.
@export var persist_across_maps: bool = false


func execute(_context: Node) -> void:
	if bgm == null:
		push_warning("PlayBGMCommand: No se especificó un AudioStream (bgm)")
		return

	if persist_across_maps:
		AudioManager.set_event_bgm_hold(bgm, loop)
	else:
		AudioManager.clear_event_bgm_hold()

	var dur := maxf(fade_duration, 0.0)
	match transition_mode:
		TransitionMode.FADE_IN:
			AudioManager.play_bgm(bgm, dur, loop)
		TransitionMode.CROSSFADE:
			AudioManager.crossfade_bgm(bgm, dur if dur > 0.0 else 1.0, loop)
		TransitionMode.FADE_OUT_THEN_PLAY:
			AudioManager.fade_out_then_play_bgm(bgm, dur if dur > 0.0 else 1.0, loop)


func is_async() -> bool:
	return false


func is_safe_for_parallel() -> bool:
	return true
