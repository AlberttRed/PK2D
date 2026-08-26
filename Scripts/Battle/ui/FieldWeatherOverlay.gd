extends Control
class_name FieldWeatherOverlay

## Capa de clima sobre el campo (debajo de HPBar/MessageBox, encima de sprites y VFX).
## One-shot: oscurecimiento + gotas al activar clima o movimiento; no persiste entre turnos.

const RAIN_FRAMES := preload("res://Sprites/Batalla/Moves Animations/RainFrames.png")
const FRAME_COUNT := 7
const FRAME_DURATION := 0.038
const SPAWN_INTERVAL := 0.024
const BURST_SPAWN_SEC := 2.2
const MAX_POOL := 32
const FIELD_SIZE := Vector2(512, 384)
const DARKEN_TARGET := Color(0.02, 0.05, 0.12, 0.38)
const DARKEN_INTRO_SEC := 0.8
const DARKEN_OUTRO_SEC := 0.7

@onready var _darken: ColorRect = $Darken
@onready var _rain_layer: Node2D = $RainLayer

var _playing := false
var _play_generation := 0
var _spawn_timer: Timer = null
var _drop_pool: Array[Sprite2D] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	if _darken != null:
		_darken.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_darken.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_darken.color = Color(DARKEN_TARGET.r, DARKEN_TARGET.g, DARKEN_TARGET.b, 0.0)
	_build_drop_pool()
	_setup_spawn_timer()


func is_playing() -> bool:
	return _playing


## Reproduce oscurecimiento + ráfaga de gotas + fade out. Awaitable.
func play_rain_burst() -> void:
	_abort_burst()
	_playing = true
	_play_generation += 1
	var gen := _play_generation
	visible = true
	if _darken != null:
		_darken.color = Color(DARKEN_TARGET.r, DARKEN_TARGET.g, DARKEN_TARGET.b, 0.0)
		var intro_tw := create_tween()
		intro_tw.tween_property(_darken, "color", DARKEN_TARGET, DARKEN_INTRO_SEC)
		await intro_tw.finished
	if not _is_current_play(gen):
		return
	_ensure_spawn_timer()
	await get_tree().create_timer(BURST_SPAWN_SEC).timeout
	if not _is_current_play(gen):
		return
	if _spawn_timer != null:
		_spawn_timer.stop()
	await get_tree().create_timer(FRAME_COUNT * FRAME_DURATION).timeout
	if not _is_current_play(gen):
		return
	if _darken != null:
		var out_tw := create_tween()
		out_tw.tween_property(_darken, "color:a", 0.0, DARKEN_OUTRO_SEC)
		await out_tw.finished
	_finish_burst(gen)


func clear() -> void:
	_abort_burst()


func _abort_burst() -> void:
	_play_generation += 1
	_playing = false
	if _spawn_timer != null:
		_spawn_timer.stop()
	if _darken != null:
		_darken.color = Color(DARKEN_TARGET.r, DARKEN_TARGET.g, DARKEN_TARGET.b, 0.0)
	_hide_all_drops()
	visible = false


func _finish_burst(gen: int) -> void:
	if not _is_current_play(gen):
		return
	_playing = false
	_hide_all_drops()
	visible = false
	if _darken != null:
		_darken.color = Color(DARKEN_TARGET.r, DARKEN_TARGET.g, DARKEN_TARGET.b, 0.0)


func _is_current_play(gen: int) -> bool:
	return _playing and gen == _play_generation


func _setup_spawn_timer() -> void:
	_spawn_timer = Timer.new()
	_spawn_timer.wait_time = SPAWN_INTERVAL
	_spawn_timer.one_shot = false
	_spawn_timer.timeout.connect(_on_spawn_tick)
	add_child(_spawn_timer)


func _ensure_spawn_timer() -> void:
	if _spawn_timer != null:
		_spawn_timer.start()


func _build_drop_pool() -> void:
	if _rain_layer == null:
		return
	for i in MAX_POOL:
		var spr := Sprite2D.new()
		spr.texture = RAIN_FRAMES
		spr.hframes = 1
		spr.vframes = FRAME_COUNT
		spr.visible = false
		spr.z_as_relative = false
		spr.z_index = 0
		_rain_layer.add_child(spr)
		_drop_pool.append(spr)


func _on_spawn_tick() -> void:
	if not _playing:
		return
	var spr := _acquire_drop()
	if spr == null:
		return
	spr.position = Vector2(
		randf_range(-12.0, FIELD_SIZE.x + 12.0),
		randf_range(24.0, FIELD_SIZE.y - 8.0)
	)
	spr.frame = 0
	spr.visible = true
	_run_drop_frames(spr, _play_generation)


func _acquire_drop() -> Sprite2D:
	for spr in _drop_pool:
		if spr != null and is_instance_valid(spr) and not spr.visible:
			return spr
	return null


func _run_drop_frames(spr: Sprite2D, gen: int) -> void:
	for frame_idx in FRAME_COUNT:
		if not _is_current_play(gen) or spr == null or not is_instance_valid(spr):
			if spr != null and is_instance_valid(spr):
				spr.visible = false
			return
		spr.frame = frame_idx
		await get_tree().create_timer(FRAME_DURATION).timeout
	if spr != null and is_instance_valid(spr):
		spr.visible = false


func _hide_all_drops() -> void:
	for spr in _drop_pool:
		if spr != null and is_instance_valid(spr):
			spr.visible = false
