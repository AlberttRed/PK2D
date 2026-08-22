extends Node2D
class_name BattlePartyBarUI

## Barra de party en campo (Line + PKMN1..6). Solo presentación.

const TEX_NORMAL_PATH := "res://Sprites/Pictures/ballnormal.png"
const TEX_EMPTY_PATH := "res://Sprites/Pictures/ballempty.png"
const TEX_FAINTED_PATH := "res://Sprites/Pictures/ballfainted.png"
const TEX_STATUS_PATH := "res://Sprites/Pictures/ballstatus.PNG"

const SLOT_COUNT := 6
const SLIDE_OFFSET := 300.0
const SLIDE_IN_DURATION := 0.38
const SLIDE_OUT_DURATION := 0.32
const FADE_OUT_DURATION := 0.45

const BALL_ROLL_ENTRY_DISTANCE := 220.0
const BALL_ROLL_EXIT_DISTANCE := 520.0
const INTRO_LINE_SLIDE_SEC := 0.32
const INTRO_LINE_SLIDE_DISTANCE := 280.0
## Bolas empiezan cuando la línea lleva ~esta fracción del slide.
const INTRO_BALLS_START_AT_LINE_FRACTION := 0.72
const INTRO_BALL_ROLL_SEC := 0.16
const INTRO_BALL_EXIT_ROLL_SEC := 0.58
const INTRO_BALL_STAGGER_SEC := 0.05
const INTRO_BALL_IDLE_SPIN_SEC := 0.34
## Vueltas en cluster (tras el roll-in); la 1ª para antes por el stagger de entrada.
const INTRO_BALL_COAST_TURNS_BASE := 3.0
const INTRO_BALL_COAST_TURNS_STAGGER := 0.15
const INTRO_BALL_CLUSTER_SHIFT := 18.0
const INTRO_BALL_CLUSTER_HOLD_SEC := 0.07
const INTRO_BALL_BOUNCE_SEC := 0.24
const INTRO_BALL_EXIT_STAGGER_SEC := 0.11
const INTRO_ROLL_OUT_FADE_SEC := 0.82
const BALL_ROLL_TURNS := 2.0

var _rest_position: Vector2 = Vector2.ZERO
var _slide_from_right := true
var _tex_normal: Texture2D
var _tex_empty: Texture2D
var _tex_fainted: Texture2D
var _tex_status: Texture2D
var _line: Sprite2D
var _line_rest_position: Vector2 = Vector2.ZERO
var _slot_sprites: Array[Sprite2D] = []
var _slot_rest_positions: Array[Vector2] = []
var _intro_ball_spin_tweens: Array[Tween] = []


func _ready() -> void:
	_rest_position = position
	visible = false
	_load_textures()
	_cache_nodes()


func configure(slide_from_right: bool) -> void:
	_slide_from_right = slide_from_right


func park_offscreen() -> void:
	_reset_visual_state()
	position = _offscreen_position()
	visible = false


func refresh_from_party(party: Array) -> void:
	for i in SLOT_COUNT:
		var spr := _slot_sprites[i] if i < _slot_sprites.size() else null
		if spr == null:
			continue
		spr.texture = _texture_for_slot(party, i)


## Intro: línea slide lateral → bolas rodando hacia su slot (casi al final del slide).
func intro_roll_in(host: Node) -> void:
	if host == null or not is_instance_valid(host):
		return
	_prepare_intro_enter()

	var line_rest := _line_rest_position
	var line_start := _line_entry_start(line_rest)
	_line.position = line_start

	var line_tw := host.create_tween()
	line_tw.tween_property(_line, "position", line_rest, INTRO_LINE_SLIDE_SEC).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_OUT)

	var ball_delay := INTRO_LINE_SLIDE_SEC * INTRO_BALLS_START_AT_LINE_FRACTION
	await host.get_tree().create_timer(ball_delay).timeout

	for slot_idx in SLOT_COUNT:
		await _roll_ball(host, slot_idx, true)
		if slot_idx < SLOT_COUNT - 1:
			await host.get_tree().create_timer(INTRO_BALL_STAGGER_SEC).timeout

	await host.get_tree().create_timer(INTRO_BALL_CLUSTER_HOLD_SEC).timeout
	await _bounce_balls_to_rest(host)

	if line_tw.is_running():
		await line_tw.finished
	_line.position = line_rest
	position = _rest_position


## Intro send-in: bolas salen rodando; línea y bolas se desvanecen a la vez.
func intro_roll_out(host: Node) -> void:
	if host == null or not is_instance_valid(host) or not visible:
		return

	var total_exit_sec := INTRO_BALL_EXIT_STAGGER_SEC * float(SLOT_COUNT - 1) + INTRO_BALL_EXIT_ROLL_SEC

	var fade_tw := host.create_tween()
	fade_tw.tween_property(self, "modulate:a", 0.0, INTRO_ROLL_OUT_FADE_SEC)

	for slot_idx in SLOT_COUNT:
		var delay := INTRO_BALL_EXIT_STAGGER_SEC * float(slot_idx)
		_start_delayed_ball_roll_out(host, slot_idx, delay)

	await host.get_tree().create_timer(total_exit_sec).timeout
	_finalize_hidden()


## Cambio rival mid-battle: slide de toda la barra (izq→der).
func slide_in(host: Node) -> void:
	if host == null or not is_instance_valid(host):
		return
	_reset_visual_state()
	position = _offscreen_position()
	visible = true
	var tw := host.create_tween()
	tw.tween_property(self, "position", _rest_position, SLIDE_IN_DURATION).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_OUT)
	await tw.finished
	position = _rest_position


func slide_out(host: Node) -> void:
	if host == null or not is_instance_valid(host) or not visible:
		return
	var tw := host.create_tween()
	tw.tween_property(self, "position", _offscreen_position(), SLIDE_OUT_DURATION).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_IN)
	await tw.finished
	_finalize_hidden()


func fade_out(host: Node, duration: float = FADE_OUT_DURATION) -> void:
	if host == null or not is_instance_valid(host) or not visible:
		return
	var tw := host.create_tween()
	tw.tween_property(self, "modulate:a", 0.0, duration).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_IN)
	await tw.finished
	_finalize_hidden()


func _prepare_intro_enter() -> void:
	_stop_intro_ball_spins()
	_reset_visual_state()
	position = _rest_position
	visible = true
	if _line != null:
		_line.visible = true
		_line.modulate = Color(1, 1, 1, 1)
		_line.position = _line_entry_start(_line_rest_position)
	for i in _slot_sprites.size():
		var spr := _slot_sprites[i]
		var rest := _slot_rest_positions[i]
		spr.visible = false
		spr.rotation = 0.0
		spr.position = _ball_entry_start(rest)


func _start_delayed_ball_roll_out(host: Node, slot_idx: int, delay: float) -> void:
	if delay > 0.0:
		await host.get_tree().create_timer(delay).timeout
	await _roll_ball(host, slot_idx, false)


func _roll_ball(host: Node, slot_idx: int, entering: bool) -> void:
	if slot_idx < 0 or slot_idx >= _slot_sprites.size():
		return
	var spr := _slot_sprites[slot_idx]
	var rest := _slot_rest_positions[slot_idx]
	var from_pos := _ball_entry_start(rest) if entering else rest
	var to_pos := _ball_cluster_position(slot_idx) if entering else _ball_exit_end(rest)
	var roll_sign := _ball_roll_sign(from_pos, to_pos)
	var duration := INTRO_BALL_ROLL_SEC if entering else INTRO_BALL_EXIT_ROLL_SEC

	spr.position = from_pos
	spr.rotation = 0.0
	if entering:
		spr.visible = true
	var tw := host.create_tween()
	tw.set_parallel(true)
	tw.tween_property(spr, "position", to_pos, duration).set_trans(
		Tween.TRANS_LINEAR
	)
	tw.tween_property(
		spr, "rotation", roll_sign * TAU * BALL_ROLL_TURNS, duration
	).set_trans(Tween.TRANS_LINEAR)
	await tw.finished
	spr.position = to_pos
	if entering:
		_normalize_ball_rotation_flat(spr)
		_start_ball_coast_to_flat(host, slot_idx, roll_sign)
	else:
		_normalize_ball_rotation_flat(spr)


func _coast_turns_for_slot(slot_idx: int) -> float:
	return INTRO_BALL_COAST_TURNS_BASE + float(slot_idx) * INTRO_BALL_COAST_TURNS_STAGGER


func _start_ball_coast_to_flat(host: Node, slot_idx: int, roll_sign: float) -> void:
	if host == null or not is_instance_valid(host):
		return
	if slot_idx < 0 or slot_idx >= _slot_sprites.size():
		return
	var spr := _slot_sprites[slot_idx]
	var turns := _coast_turns_for_slot(slot_idx)
	var flat_turns := ceilf(turns)
	var target := roll_sign * TAU * flat_turns
	var duration := turns * INTRO_BALL_IDLE_SPIN_SEC
	var spin_tw := host.create_tween()
	spin_tw.tween_property(spr, "rotation", target, duration).set_trans(Tween.TRANS_LINEAR)
	_intro_ball_spin_tweens.append(spin_tw)
	(
		func() -> void:
			await spin_tw.finished
			_normalize_ball_rotation_flat(spr)
	).call()


func _normalize_ball_rotation_flat(spr: Sprite2D) -> void:
	if spr == null:
		return
	var flat_rot := roundf(spr.rotation / TAU) * TAU
	if absf(spr.rotation - flat_rot) < 0.08:
		spr.rotation = 0.0
	else:
		spr.rotation = flat_rot
		if absf(spr.rotation) < 0.01:
			spr.rotation = 0.0


func _stop_intro_ball_spins() -> void:
	for tw in _intro_ball_spin_tweens:
		if tw != null and is_instance_valid(tw):
			tw.kill()
	_intro_ball_spin_tweens.clear()


func _bounce_balls_to_rest(host: Node) -> void:
	if host == null or not is_instance_valid(host):
		return
	_stop_intro_ball_spins()
	var tw := host.create_tween()
	tw.set_parallel(true)
	for i in _slot_sprites.size():
		var spr := _slot_sprites[i]
		var rest := _slot_rest_positions[i]
		var flat_rot := roundf(spr.rotation / TAU) * TAU
		if absf(spr.rotation - flat_rot) > 0.05:
			tw.tween_property(spr, "rotation", flat_rot, 0.1).set_trans(Tween.TRANS_LINEAR)
		else:
			spr.rotation = 0.0
		tw.tween_property(spr, "position", rest, INTRO_BALL_BOUNCE_SEC).set_trans(
			Tween.TRANS_BACK
		).set_ease(Tween.EASE_OUT)
	await tw.finished
	for i in _slot_sprites.size():
		var spr := _slot_sprites[i]
		spr.position = _slot_rest_positions[i]
		_normalize_ball_rotation_flat(spr)


func _ball_cluster_position(slot_idx: int) -> Vector2:
	var rest := _slot_rest_positions[slot_idx]
	if _slot_rest_positions.is_empty():
		return rest
	var leftmost := _slot_rest_positions[0].x
	var rightmost := _slot_rest_positions[SLOT_COUNT - 1].x
	var step := _ball_display_step()
	var cluster_x := 0.0
	if _slide_from_right:
		# Player: fila compacta (sin hueco) desplazada a la izquierda.
		var cluster_start := leftmost - INTRO_BALL_CLUSTER_SHIFT
		cluster_x = cluster_start + float(slot_idx) * step
	else:
		# Rival: fila compacta desplazada a la derecha visual (local +X).
		var cluster_start := rightmost + INTRO_BALL_CLUSTER_SHIFT
		cluster_x = cluster_start - float(slot_idx) * step
	return Vector2(cluster_x, rest.y)


func _ball_display_step() -> float:
	if _slot_sprites.is_empty():
		return 32.0
	var spr := _slot_sprites[0]
	if spr == null or spr.texture == null:
		return 32.0
	var tex_w := float(spr.texture.get_width())
	if spr.region_enabled:
		tex_w = spr.region_rect.size.x
	return tex_w * absf(spr.scale.x)


func _line_entry_start(rest: Vector2) -> Vector2:
	return rest + Vector2(INTRO_LINE_SLIDE_DISTANCE, 0.0)


func _ball_entry_start(rest: Vector2) -> Vector2:
	# Player: entra desde la derecha. Rival (scale.x=-1): entra desde la izq. visual.
	return rest + Vector2(BALL_ROLL_ENTRY_DISTANCE, 0.0)


func _ball_exit_end(rest: Vector2) -> Vector2:
	# Player: sale por la izquierda. Rival: sale por la derecha visual.
	return rest + Vector2(-BALL_ROLL_EXIT_DISTANCE, 0.0)


func _ball_roll_sign(from_pos: Vector2, to_pos: Vector2) -> float:
	return signf(to_pos.x - from_pos.x) if absf(to_pos.x - from_pos.x) > 0.01 else -1.0


func _reset_visual_state() -> void:
	_stop_intro_ball_spins()
	modulate = Color(1, 1, 1, 1)
	if _line != null:
		_line.modulate = Color(1, 1, 1, 1)
		_line.position = _line_rest_position
	for i in _slot_sprites.size():
		var spr := _slot_sprites[i]
		spr.rotation = 0.0
		spr.position = _slot_rest_positions[i]
		spr.visible = true


func _finalize_hidden() -> void:
	_reset_visual_state()
	position = _rest_position
	visible = false


func _load_textures() -> void:
	_tex_normal = load(TEX_NORMAL_PATH) as Texture2D
	_tex_empty = load(TEX_EMPTY_PATH) as Texture2D
	_tex_fainted = load(TEX_FAINTED_PATH) as Texture2D
	_tex_status = load(TEX_STATUS_PATH) as Texture2D


func _cache_nodes() -> void:
	_line = get_node_or_null("Line") as Sprite2D
	if _line != null:
		_line_rest_position = _line.position
	_slot_sprites.clear()
	_slot_rest_positions.clear()
	for i in SLOT_COUNT:
		var spr := get_node_or_null("PKMN%d" % (i + 1)) as Sprite2D
		if spr != null:
			_slot_sprites.append(spr)
			_slot_rest_positions.append(spr.position)


func _texture_for_slot(party: Array, index: int) -> Texture2D:
	if index >= party.size():
		return _tex_empty
	var bp: BattlePokemon = party[index]
	if bp == null:
		return _tex_empty
	if bp.is_fainted():
		return _tex_fainted
	if bp.status != null:
		return _tex_status
	return _tex_normal


func _offscreen_position() -> Vector2:
	var dir := 1.0 if _slide_from_right else -1.0
	return _rest_position + Vector2(SLIDE_OFFSET * dir, 0.0)
