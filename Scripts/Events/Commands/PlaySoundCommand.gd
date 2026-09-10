extends EventCommand
class_name PlaySoundCommand

## Reproduce un SFX vía AudioManager (puertas, cofres, switches, cutscenes…).
## Con wait_until_finished=false es síncrono: NO llamar continue_execution (lo hace EventController).
@export var sound: AudioStream = null
@export var bus: String = "SFX"
@export var wait_until_finished: bool = false
@export var volume_db: float = 0.0
## Si true, pausa la BGM y la reanuda al terminar el sonido (fanfares). Puertas/SFX cortos: false.
@export var pause_bgm: bool = false

## Timeout de seguridad por encima de la duración del stream (acceptance: no colgar el evento).
const WAIT_TIMEOUT_PADDING := 0.5
const WAIT_TIMEOUT_FALLBACK := 2.0

var _context: Node = null
var _timer: Timer = null
var _finished: bool = false
var _sfx_player: AudioStreamPlayer = null


func execute(context: Node) -> void:
	_context = context
	_finished = false

	if sound == null:
		push_warning("PlaySoundCommand: No se especificó un AudioStream (sound)")
		# Solo los async deben avisar al controller; los sync los avanza él solo.
		if wait_until_finished:
			context.continue_execution()
		return

	_sfx_player = AudioManager.play_sfx(sound, bus, volume_db, pause_bgm)

	if not wait_until_finished:
		return

	if _sfx_player != null and is_instance_valid(_sfx_player):
		if not _sfx_player.finished.is_connected(_on_sfx_finished):
			_sfx_player.finished.connect(_on_sfx_finished, CONNECT_ONE_SHOT)

	var wait_time := sound.get_length()
	if wait_time <= 0.0:
		wait_time = WAIT_TIMEOUT_FALLBACK
	wait_time += WAIT_TIMEOUT_PADDING

	_timer = Timer.new()
	_timer.wait_time = wait_time
	_timer.one_shot = true
	_timer.timeout.connect(_on_wait_timeout)
	context.get_tree().current_scene.add_child(_timer)
	_timer.start()


func _on_sfx_finished() -> void:
	_finish_wait()


func _on_wait_timeout() -> void:
	_finish_wait()


func _finish_wait() -> void:
	if _finished:
		return
	_finished = true

	if _sfx_player != null and is_instance_valid(_sfx_player):
		if _sfx_player.finished.is_connected(_on_sfx_finished):
			_sfx_player.finished.disconnect(_on_sfx_finished)
	_sfx_player = null

	if is_instance_valid(_timer):
		_timer.queue_free()
		_timer = null

	if _context:
		_context.continue_execution()
		_context = null


func is_async() -> bool:
	return wait_until_finished


func is_safe_for_parallel() -> bool:
	return not wait_until_finished
