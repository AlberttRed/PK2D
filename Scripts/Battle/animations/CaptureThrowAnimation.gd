extends Node2D
class_name CaptureThrowAnimation

## Fase 1: lanzamiento → apertura/cierre en aire → caída con rebotes.
## Fase 2: `play_resolve` — balanceos (0–3), escape (abrir) o éxito (oscurecer + estrellas).

const CLOSE_FRAMES_SEC := 0.32
const STAR_FRAMES := preload("res://Sprites/Batalla/Battle Animations/StarFrames.png")
const SCENE_PATH := "res://Scenes/Battle/animations/capture/CaptureThrowAnimation.tscn"

@onready var ball: Sprite2D = $Ball

var _ball_sprite_id: String = PokeballItemEffect.DEFAULT_BALL_SPRITE_ID

var _target_spot: BattleSpot = null
var _throw_start: Vector2 = Vector2.ZERO
var _throw_apex: Vector2 = Vector2.ZERO
var _throw_hover: Vector2 = Vector2.ZERO
var _sprite_rest_pos: Vector2 = Vector2.ZERO
var _sprite_rest_scale: Vector2 = Vector2.ONE
var _sprite_rest_modulate: Color = Color(1, 1, 1, 1)
var _did_store_sprite_rest: bool = false


static func play_throw(
	ui: BattleUI,
	target_spot: BattleSpot,
	ball_sprite_id: String = PokeballItemEffect.DEFAULT_BALL_SPRITE_ID
) -> CaptureThrowAnimation:
	if ui == null or target_spot == null:
		return null
	var layer: Node2D = ui.get_animation_layer()
	if layer == null:
		return null
	var packed: PackedScene = load(SCENE_PATH) as PackedScene
	if packed == null:
		push_warning("CaptureThrowAnimation: no se pudo cargar la escena.")
		return null
	var inst: CaptureThrowAnimation = packed.instantiate() as CaptureThrowAnimation
	if inst == null:
		return null
	inst._ball_sprite_id = PokeballItemEffect.normalize_ball_sprite_id(ball_sprite_id)
	layer.add_child(inst)
	await inst.run(target_spot, ui)
	return inst


func run(target_spot: BattleSpot, ui: BattleUI = null) -> void:
	_target_spot = target_spot
	if ball == null:
		ball = get_node_or_null("Ball") as Sprite2D
	if ball == null or target_spot == null:
		return

	var ground_global := target_spot.get_anchor_global_position(BattleSpot.ANCHOR_BALL_GROUND)
	var head_global := target_spot.get_anchor_global_position(BattleSpot.ANCHOR_HEAD)
	global_position = ground_global
	rotation = 0.0
	scale = Vector2.ONE

	var head_local := to_local(head_global)
	# Un poco por encima de la cabeza (como en el original).
	var hover := Vector2(head_local.x, head_local.y - 8.0)
	# Fuera por la izquierda, a la altura del player base (BALL_GROUND del jugador).
	var start := _offscreen_left_at_player_base(ui, hover)
	# Pico del arco ~mitad del trayecto; altura similar a la HP bar rival (ya ok en el original).
	var apex := Vector2(lerpf(start.x, hover.x, 0.52), minf(start.y, hover.y) - 72.0)

	ball.visible = true
	ball.texture = PokeballThrowSpriteFrames.get_fly_frame(_ball_sprite_id, 0)
	PokeballThrowSpriteFrames.apply_field_scale(ball)
	ball.modulate = Color(1, 1, 1, 1)
	ball.rotation = 0.0
	ball.position = start
	# Absoluto: debajo del HPBar (z=6), como recall/throw de campo.
	z_as_relative = false
	z_index = FieldUI.FIELD_POKEBALL_Z

	await _tween_throw(start, apex, hover)
	await _tween_squash()
	ball.texture = PokeballThrowSpriteFrames.get_frame(_ball_sprite_id, PokeballThrowSpriteFrames.OPEN_START_FRAME)
	var open_anim := _animate_open_frames_tween(1.12)
	# Todas las luces (flash, orbes) mientras la ball está abierta.
	await _flash_and_absorb_pokemon()
	var absorb_ring: Sprite2D = await _play_absorb_ring_halo_expand()
	if open_anim != null and open_anim.is_running():
		await open_anim.finished
	var halo_shrink := _shrink_absorb_ring_halo(absorb_ring, CLOSE_FRAMES_SEC)
	await _animate_close_frames_tween(CLOSE_FRAMES_SEC).finished
	if halo_shrink != null and halo_shrink.is_running():
		await halo_shrink.finished
	if is_instance_valid(absorb_ring):
		absorb_ring.queue_free()
	_close_ball()
	await _tween_gold_flash()
	await get_tree().create_timer(0.08).timeout
	await _tween_fall_and_bounce(hover)


## Origen off-screen izquierdo a ~altura del suelo del player base.
func _offscreen_left_at_player_base(ui: BattleUI, hover_local: Vector2) -> Vector2:
	var canvas := get_viewport().get_canvas_transform()
	var inv := canvas.affine_inverse()
	var start_y_global := _resolve_player_base_ground_y(ui)
	if is_nan(start_y_global):
		# Fallback: bastante más abajo que el hover del rival.
		var hover_screen: Vector2 = canvas * to_global(hover_local)
		return to_local(inv * Vector2(-32.0, hover_screen.y + 110.0))
	# Misma Y de pantalla que el BALL_GROUND del jugador; X fuera por la izquierda.
	var start_screen_y: float = (canvas * Vector2(0.0, start_y_global)).y
	var start_global: Vector2 = inv * Vector2(-32.0, start_screen_y)
	start_global.y -= 6.0
	return to_local(start_global)


func _resolve_player_base_ground_y(ui: BattleUI) -> float:
	if ui == null or ui.field_ui == null:
		return NAN
	var player_spot := ui.field_ui.get_node_or_null("PlayerBase/PokemonSpotA") as BattleSpot
	if player_spot == null or not is_instance_valid(player_spot):
		return NAN
	return player_spot.get_anchor_global_position(BattleSpot.ANCHOR_BALL_GROUND).y


func cleanup() -> void:
	if is_instance_valid(self):
		queue_free()


func restore_target_sprite() -> void:
	if _target_spot == null or not is_instance_valid(_target_spot):
		return
	var spr: Sprite2D = _target_spot.sprite
	if spr != null and is_instance_valid(spr) and _did_store_sprite_rest:
		spr.position = _sprite_rest_pos
		spr.scale = _sprite_rest_scale
		spr.modulate = _sprite_rest_modulate
	var shadow: Sprite2D = _target_spot.shadow
	if shadow != null and is_instance_valid(shadow):
		shadow.modulate.a = 1.0
	_target_spot.set_pokemon_sprite_visible(true)


## Fase 2: `shake_count` inclinaciones (0–3). Si no hay éxito, abre y libera el Pokémon.
func play_resolve(shake_count: int, success: bool) -> void:
	if ball == null:
		ball = get_node_or_null("Ball") as Sprite2D
	if ball == null:
		return

	ball.texture = _closed_texture()
	ball.scale = Vector2.ONE
	ball.rotation = 0.0
	ball.position = Vector2.ZERO
	ball.modulate = Color(1, 1, 1, 1)
	# Pivote en el borde inferior (contacto con el suelo) para inclinarse sin deslizar.
	_apply_ball_bottom_pivot()

	# Breve pausa en el suelo antes de los balanceos.
	await get_tree().create_timer(0.4).timeout

	var count := clampi(shake_count, 0, 3)
	if count == 0 and not success:
		await play_escape_open()
		return

	for i in range(count):
		await play_wobble(i)
		await get_tree().create_timer(0.95).timeout

	if success:
		await play_capture_success_hold()
	else:
		await play_escape_open()


## Offset + posición: pivote en el borde inferior sin desplazar el dibujo.
func _apply_ball_bottom_pivot() -> void:
	if ball == null or ball.texture == null:
		return
	ball.centered = true
	var tex_h := float(ball.texture.get_height())
	var half_h := tex_h * 0.5
	var bottom_from_top := tex_h
	var img := ball.texture.get_image()
	if img != null:
		var used := img.get_used_rect()
		if used.size.y > 0:
			bottom_from_top = float(used.position.y + used.size.y)
	var bottom_delta := bottom_from_top - half_h
	# Sube el dibujo respecto al origen… y baja el nodo la misma cantidad:
	# el centro visual no salta; la rotación gira sobre el borde inferior.
	ball.offset = Vector2(0.0, -bottom_delta)
	ball.position = Vector2(ball.position.x, bottom_delta)


## Sacudida según índice (0-based): 1º izq→der, 2º solo der, 3º solo izq.
func play_wobble(index: int = 0) -> void:
	if ball == null:
		return
	const TILT := 0.42
	const HALF := 0.11
	var tw := create_tween()
	match index:
		0:
			# Primer shake: izquierda → centro → derecha → centro.
			tw.tween_property(ball, "rotation", -TILT, HALF).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tw.tween_property(ball, "rotation", 0.0, HALF).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			tw.tween_property(ball, "rotation", TILT, HALF).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tw.tween_property(ball, "rotation", 0.0, HALF).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		1:
			# Segundo shake: solo derecha → centro.
			tw.tween_property(ball, "rotation", TILT, HALF).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tw.tween_property(ball, "rotation", 0.0, HALF).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		_:
			# Tercer shake: solo izquierda → centro.
			tw.tween_property(ball, "rotation", -TILT, HALF).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tw.tween_property(ball, "rotation", 0.0, HALF).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw.finished
	ball.rotation = 0.0


## Fallo: animación ball_fail + flash; el Pokémon sale como send-in (blanco → color, crece).
func play_escape_open() -> void:
	if ball == null:
		return
	ball.rotation = 0.0
	_reset_ball_ground_center()
	ball.modulate = Color(1, 1, 1, 1)
	ball.texture = PokeballFailSpriteFrames.get_frame(_ball_sprite_id, 0)

	if _target_spot != null and is_instance_valid(_target_spot):
		_target_spot.set_pokemon_sprite_visible(false)

	const FAIL_SEC := 0.40
	const ENTER_DELAY := 0.10
	var layer := get_parent() as Node2D
	var done := {"fail": false, "enter": false}
	_run_escape_fail(FAIL_SEC, done)
	_run_escape_enter(layer, ENTER_DELAY, done)
	while not (done.fail and done.enter):
		if not is_instance_valid(self) or get_tree() == null:
			return
		await get_tree().process_frame

	ball.visible = false
	ball.scale = Vector2.ONE
	ball.modulate = Color(1, 1, 1, 1)
	if _target_spot != null and is_instance_valid(_target_spot):
		_target_spot.set_pokemon_sprite_visible(true)


func _run_escape_fail(duration: float, done: Dictionary) -> void:
	var tw := _animate_fail_frames_tween(duration)
	if tw != null and tw.is_valid() and tw.is_running():
		await tw.finished
	done.fail = true


func _run_escape_enter(layer: Node2D, delay: float, done: Dictionary) -> void:
	await get_tree().create_timer(delay).timeout
	_prepare_escape_enter_sprite()
	if _target_spot != null and is_instance_valid(_target_spot):
		await BattleAnimationUtils.pokemon_enter_spot(_target_spot, 0.42, 0.65, layer)
	done.enter = true


func _prepare_escape_enter_sprite() -> void:
	if _target_spot == null or not is_instance_valid(_target_spot):
		return
	var spr: Sprite2D = _target_spot.sprite
	if spr != null and is_instance_valid(spr) and _did_store_sprite_rest:
		spr.position = _sprite_rest_pos
		spr.scale = _sprite_rest_scale
		spr.modulate = _sprite_rest_modulate
	_target_spot.set_pokemon_sprite_visible(false)


## Éxito: oscurece, se inclina a la derecha y salen 3 estrellas hacia arriba.
func play_capture_success_hold() -> void:
	if ball == null:
		return
	ball.texture = _closed_texture()
	ball.rotation = 0.0
	const DARKEN_SEC := 0.175
	const TILT_RIGHT := 0.2
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(ball, "modulate", Color(0.28, 0.28, 0.32, 1.0), DARKEN_SEC)
	tw.tween_property(ball, "rotation", TILT_RIGHT, DARKEN_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished
	await _play_capture_success_stars()


## Tres estrellas: suben separándose + fade-in → en el pico rotan y caen con “gravedad”.
func _play_capture_success_stars() -> void:
	if ball == null:
		return
	const STAR_SCALE := 0.42  # +50% respecto a 0.28
	const RISE_SEC := 0.38
	const FALL_SEC := 0.42
	const TOTAL_SEC := RISE_SEC + FALL_SEC
	const RISE_FRAC := RISE_SEC / TOTAL_SEC

	# Pico (más separados) y caída lateral tras el pico.
	var peaks: Array[Vector2] = [
		Vector2(-30.0, -68.0),
		Vector2(0.0, -80.0),
		Vector2(30.0, -68.0),
	]
	var fall_deltas: Array[Vector2] = [
		Vector2(-16.0, 30.0),
		Vector2(12.0, 34.0),
		Vector2(20.0, 30.0),
	]
	var rot_at_peak: Array[float] = [-0.2, 0.12, 0.28]
	var rot_at_end: Array[float] = [-0.85, 0.55, 1.05]

	var origin_global := ball.to_global(_ball_content_center_offset() + Vector2(0.0, -6.0))
	var origin := to_local(origin_global)
	var stars: Array[Sprite2D] = []
	var tw := create_tween()
	tw.set_parallel(true)

	for i in peaks.size():
		var star := Sprite2D.new()
		star.name = "CaptureStar%d" % i
		star.texture = STAR_FRAMES
		star.centered = true
		star.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		star.scale = Vector2(STAR_SCALE, STAR_SCALE)
		star.modulate = Color(1.0, 0.95, 0.35, 0.0)
		star.rotation = 0.0
		star.z_as_relative = false
		star.z_index = FieldUI.FIELD_POKEBALL_Z + 1
		star.position = origin
		add_child(star)
		stars.append(star)

		var peak := origin + peaks[i]
		var fall_d := fall_deltas[i]
		var r_peak := rot_at_peak[i]
		var r_end := rot_at_end[i]
		var delay := float(i) * 0.035
		tw.tween_method(
			func(t: float) -> void:
				if not is_instance_valid(star):
					return
				_update_capture_star_flight(
					star, origin, peak, fall_d, r_peak, r_end, t, RISE_FRAC
				),
			0.0,
			1.0,
			TOTAL_SEC
		).set_delay(delay)

	await tw.finished
	for star in stars:
		if is_instance_valid(star):
			star.queue_free()


func _update_capture_star_flight(
	star: Sprite2D,
	origin: Vector2,
	peak: Vector2,
	fall_delta: Vector2,
	rot_peak: float,
	rot_end: float,
	t: float,
	rise_frac: float
) -> void:
	var col := Color(1.0, 0.95, 0.35, 1.0)
	if t <= rise_frac:
		# Subida: fade-in + separar hacia el pico.
		var u := t / rise_frac
		u = sin(u * PI * 0.5)  # ease-out
		star.position = origin.lerp(peak, u)
		col.a = u
		star.modulate = col
		star.rotation = lerpf(0.0, rot_peak, u)
	else:
		# Caída: gravedad en Y + deriva lateral + fade-out + más rotación.
		var u := (t - rise_frac) / maxf(1.0 - rise_frac, 0.001)
		var g := u * u
		star.position = peak + Vector2(fall_delta.x * u, fall_delta.y * g)
		col.a = 1.0 - u
		star.modulate = col
		star.rotation = lerpf(rot_peak, rot_end, u)


func _tween_throw(start: Vector2, apex: Vector2, hover: Vector2) -> void:
	# Un solo arco Bezier (no dos segmentos rectos).
	const DURATION := 0.62
	_throw_start = start
	_throw_apex = apex
	_throw_hover = hover
	var tw := create_tween()
	tw.tween_method(_update_throw_flight, 0.0, 1.0, DURATION)
	await tw.finished


func _update_throw_flight(t: float) -> void:
	_update_throw_bezier(t)
	if ball == null or not is_instance_valid(ball):
		return
	var fly_count := PokeballThrowSpriteFrames.FLY_FRAME_COUNT
	var idx := clampi(int(t * float(fly_count)), 0, fly_count - 1)
	if t >= 1.0:
		idx = fly_count - 1
	ball.texture = PokeballThrowSpriteFrames.get_fly_frame(_ball_sprite_id, idx)


func _update_throw_bezier(t: float) -> void:
	if ball != null and is_instance_valid(ball):
		ball.position = _quad_bezier(_throw_start, _throw_apex, _throw_hover, t)


func _quad_bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return (u * u * p0) + (2.0 * u * t * p1) + (t * t * p2)


func _tween_squash() -> void:
	var base := Vector2.ONE
	var tw := create_tween()
	tw.tween_property(ball, "scale", base * Vector2(1.4, 0.58), 0.07)
	tw.tween_property(ball, "scale", base, 0.09)
	await tw.finished


func _animate_open_frames_tween(duration: float, reverse: bool = false) -> Tween:
	var start_f := float(
		PokeballThrowSpriteFrames.OPEN_END_FRAME
		if reverse
		else PokeballThrowSpriteFrames.OPEN_START_FRAME
	)
	var end_f := float(
		PokeballThrowSpriteFrames.OPEN_START_FRAME
		if reverse
		else PokeballThrowSpriteFrames.OPEN_END_FRAME
	)
	var tw := create_tween()
	tw.tween_method(
		func(t: float) -> void:
			if ball == null or not is_instance_valid(ball):
				return
			var idx := int(lerpf(start_f, end_f, t))
			ball.texture = PokeballThrowSpriteFrames.get_frame(_ball_sprite_id, idx),
		0.0,
		1.0,
		duration
	)
	return tw


func _animate_close_frames_tween(duration: float = CLOSE_FRAMES_SEC) -> Tween:
	return _animate_open_frames_tween(duration, true)


func _reset_ball_ground_center() -> void:
	if ball == null:
		return
	ball.centered = true
	ball.offset = Vector2.ZERO
	ball.position = Vector2.ZERO
	ball.scale = Vector2.ONE


func _animate_fail_frames_tween(duration: float) -> Tween:
	var frame_count := PokeballFailSpriteFrames.TOTAL_FRAMES
	var tw := create_tween()
	tw.tween_method(
		func(t: float) -> void:
			if ball == null or not is_instance_valid(ball):
				return
			var idx := clampi(int(t * float(frame_count)), 0, frame_count - 1)
			if t >= 1.0:
				idx = frame_count - 1
			var frame_tex := PokeballFailSpriteFrames.get_frame(_ball_sprite_id, idx)
			if frame_tex != null:
				ball.texture = frame_tex,
		0.0,
		1.0,
		duration
	).set_trans(Tween.TRANS_LINEAR)
	return tw


## Tras abrir: flash grande (≈25) → orbes + centro más pequeño/menos blanco (≈26) + absorción.
func _flash_and_absorb_pokemon() -> void:
	if _target_spot == null or not is_instance_valid(_target_spot):
		await get_tree().create_timer(0.55).timeout
		return
	var spr: Sprite2D = _target_spot.sprite
	if spr == null or not is_instance_valid(spr):
		await get_tree().create_timer(0.55).timeout
		return

	_sprite_rest_pos = spr.position
	_sprite_rest_scale = spr.scale
	_sprite_rest_modulate = spr.modulate
	_did_store_sprite_rest = true
	spr.visible = true

	# Escalas: crece → snap+orbes → crece un poco más (sin tapar orbes).
	const FLASH_BALL_SCALE := 0.85
	const FLASH_MAX_SCALE := 3.2
	const FLASH_SHRINK_SCALE := 1.15
	const FLASH_FINAL_SCALE := 3.2
	## Distancia del anillo ≈ radio visual del flash + margen.
	const ORB_RADIUS_PER_FLASH_SCALE := 30.0
	const ORB_HOLDER_SCALE_END := 1.35
	# Amarillo suave (no blanco puro como los orbes).
	const FLASH_YELLOW := Color(1.0, 0.94, 0.68, 1.0)
	const FLASH_YELLOW_DIM := Color(1.0, 0.88, 0.52, 1.0)

	var flash_center := _ball_content_center_offset()
	var circle := _make_center_flash_effect()
	ball.add_child(circle)
	circle.position = flash_center
	circle.scale = Vector2(FLASH_BALL_SCALE, FLASH_BALL_SCALE)
	circle.modulate = Color(FLASH_YELLOW.r, FLASH_YELLOW.g, FLASH_YELLOW.b, 0.0)
	circle.z_as_relative = true
	circle.z_index = 0
	ball.z_as_relative = true
	ball.z_index = 1

	# ≈25: círculo sale desde la ball y crece al primer máximo.
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(circle, "modulate", Color(FLASH_YELLOW.r, FLASH_YELLOW.g, FLASH_YELLOW.b, 0.55), 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(circle, "scale", Vector2(FLASH_MAX_SCALE, FLASH_MAX_SCALE), 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished

	# Snap: círculo pequeño + orbes cerca.
	var ball_center_global := ball.to_global(flash_center)
	var target_pos := _target_spot.to_local(ball_center_global)
	target_pos.x = _sprite_rest_pos.x
	var ring_r0 := FLASH_SHRINK_SCALE * ORB_RADIUS_PER_FLASH_SCALE
	var ring_r1 := FLASH_FINAL_SCALE * ORB_RADIUS_PER_FLASH_SCALE * 1.35
	var orbs := _spawn_capture_ring_orbs(ball, flash_center, ring_r0)
	var shadow: Sprite2D = _target_spot.shadow
	var shadow_rest_scale := Vector2.ONE
	if shadow != null and is_instance_valid(shadow):
		shadow_rest_scale = shadow.scale
	const CIRCLE_ALPHA := 0.85
	# Ventana abierta ≈ 1.0 s (0.18 + 0.10 blanco + 0.22 + 0.17 + 0.33 halo).
	const EXPAND_SEC := 0.22
	const COLLAPSE_SEC := 0.17

	circle.scale = Vector2(FLASH_SHRINK_SCALE, FLASH_SHRINK_SCALE)
	circle.modulate = Color(FLASH_YELLOW_DIM.r, FLASH_YELLOW_DIM.g, FLASH_YELLOW_DIM.b, CIRCLE_ALPHA)
	circle.z_index = 0
	for orb in orbs:
		orb.modulate = Color(1, 1, 1, 1.0)
		orb.scale = Vector2.ONE
		orb.z_index = 2

	# Primero blanco en el suelo; luego sube y se encoge ya blanco.
	var white_overlay := BattleAnimationUtils._make_white_overlay(spr)
	white_overlay.modulate.a = 0.0
	spr.add_child(white_overlay)
	const WHITE_SEC := 0.10
	tw = create_tween()
	tw.tween_property(white_overlay, "modulate:a", 1.0, WHITE_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished

	# Expansión: orbes se alejan más rápido; desde 80% el círculo se desvanece hasta 100%.
	tw = create_tween()
	tw.set_parallel(true)
	tw.tween_method(
		func(t: float) -> void:
			if is_instance_valid(circle):
				var sc := lerpf(FLASH_SHRINK_SCALE, FLASH_FINAL_SCALE, t)
				circle.scale = Vector2(sc, sc)
				var ca := CIRCLE_ALPHA
				if t >= 0.8:
					ca = lerpf(CIRCLE_ALPHA, 0.0, (t - 0.8) / 0.2)
				circle.modulate = Color(FLASH_YELLOW_DIM.r, FLASH_YELLOW_DIM.g, FLASH_YELLOW_DIM.b, ca)
			# Orbes adelantan al círculo (curva más agresiva).
			var ot := _orb_out_progress(t)
			var radius := lerpf(ring_r0, ring_r1, ot)
			var orb_sc := lerpf(1.0, ORB_HOLDER_SCALE_END, ot)
			_apply_orb_ring_expand(orbs, flash_center, radius, orb_sc),
		0.0,
		1.0,
		EXPAND_SEC
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(spr, "position", target_pos, EXPAND_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(spr, "scale", _sprite_rest_scale * 0.12, EXPAND_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if shadow != null and is_instance_valid(shadow) and shadow.visible:
		tw.tween_property(shadow, "modulate:a", 0.0, EXPAND_SEC * 0.75)
		tw.tween_property(shadow, "scale", shadow_rest_scale * 0.2, EXPAND_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw.finished

	# Círculo ya a alpha 0 → limpiar; orbes vuelven al centro encogiendo.
	if is_instance_valid(circle):
		circle.queue_free()
	if is_instance_valid(white_overlay):
		white_overlay.queue_free()

	spr.visible = false
	spr.position = _sprite_rest_pos
	spr.scale = _sprite_rest_scale
	spr.modulate = _sprite_rest_modulate
	if shadow != null and is_instance_valid(shadow):
		shadow.visible = false
		shadow.modulate.a = 1.0
		shadow.scale = shadow_rest_scale

	tw = create_tween()
	tw.tween_method(
		func(t: float) -> void:
			# Más rápido hacia la ball: ease-in agresivo.
			var ct := t * t
			var radius := lerpf(ring_r1, 0.0, ct)
			var orb_sc := lerpf(ORB_HOLDER_SCALE_END, 0.08, ct)
			var oa := lerpf(1.0, 0.0, t)
			_apply_orb_ring_expand(orbs, flash_center, radius, orb_sc)
			for orb in orbs:
				if is_instance_valid(orb):
					orb.modulate = Color(1, 1, 1, oa),
		0.0,
		1.0,
		COLLAPSE_SEC
	).set_trans(Tween.TRANS_LINEAR)
	await tw.finished

	for orb in orbs:
		if is_instance_valid(orb):
			orb.queue_free()


const CAPTURE_RING_ORB_COUNT := 9
const CAPTURE_RING_ORB_SCALE := 0.78
## Halo = brillo suave alrededor (más grande, más transparente).
const CAPTURE_RING_HALO_SCALE := 1.35

static var _orb_white_tex: Texture2D = null
static var _orb_hard_core_tex: Texture2D = null
static var _ring_halo_tex: Texture2D = null


func _spawn_capture_ring_orbs(parent: Node2D, center: Vector2, radius: float) -> Array[Node2D]:
	var orbs: Array[Node2D] = []
	for i in CAPTURE_RING_ORB_COUNT:
		var holder := Node2D.new()
		holder.name = "CaptureRingOrb%d" % i
		var angle := -PI * 0.5 + TAU * float(i) / float(CAPTURE_RING_ORB_COUNT)
		holder.set_meta(&"ring_angle", angle)
		holder.position = center + Vector2(cos(angle), sin(angle)) * radius
		holder.z_as_relative = true
		holder.z_index = 2
		holder.modulate = Color(1, 1, 1, 0)

		# Halo exterior suave (el “brillo alrededor”), no un flare aditivo fuerte.
		var halo := _make_orb_white_sprite("Halo", CAPTURE_RING_HALO_SCALE, false)
		halo.modulate = Color(1, 1, 1, 0.35)
		halo.z_as_relative = true
		halo.z_index = 0
		halo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

		var core := _make_orb_white_sprite("Core", CAPTURE_RING_ORB_SCALE, false)
		core.modulate = Color(1, 1, 1, 0.92)
		core.z_as_relative = true
		core.z_index = 1

		holder.add_child(halo)
		holder.add_child(core)
		parent.add_child(holder)
		orbs.append(holder)
	return orbs


func _orb_out_progress(t: float) -> float:
	# Orbes adelantan al círculo (llegan antes al radio máximo).
	return clampf(1.0 - pow(1.0 - t, 2.6), 0.0, 1.0)


func _apply_orb_ring_expand(
	orbs: Array[Node2D],
	center: Vector2,
	radius: float,
	orb_scale: float
) -> void:
	for orb in orbs:
		if not is_instance_valid(orb):
			continue
		var angle: float = float(orb.get_meta(&"ring_angle"))
		orb.position = center + Vector2(cos(angle), sin(angle)) * radius
		orb.scale = Vector2(orb_scale, orb_scale)
		orb.z_index = 2


## Mismo efecto que los orbes, con núcleo duro (más opaco) + halo suave.
func _make_center_flash_effect() -> Node2D:
	var holder := Node2D.new()
	holder.name = "CaptureCenterFlash"
	var halo := _make_orb_white_sprite("Halo", 1.25, false)
	halo.modulate = Color(1, 1, 1, 0.18)
	halo.z_as_relative = true
	halo.z_index = 0
	halo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# Núcleo duro: disco casi sólido (la textura suave no se notaba al escalar).
	var core := _make_orb_hard_core_sprite("Core", 0.95)
	core.modulate = Color(1, 1, 1, 1.0)
	core.z_as_relative = true
	core.z_index = 1
	var core_hot := _make_orb_hard_core_sprite("CoreHot", 0.55)
	core_hot.modulate = Color(1, 1, 1, 1.0)
	core_hot.z_as_relative = true
	core_hot.z_index = 2
	holder.add_child(halo)
	holder.add_child(core)
	holder.add_child(core_hot)
	return holder


## Círculo blanco procedural. `additive` solo si se quiere flare; el halo usa mix normal.
func _make_orb_white_sprite(node_name: String, start_scale: float, additive: bool = false) -> Sprite2D:
	var circle := Sprite2D.new()
	circle.name = node_name
	circle.texture = _get_orb_white_texture()
	circle.centered = true
	circle.scale = Vector2(start_scale, start_scale)
	circle.modulate = Color(1, 1, 1, 1)
	if additive:
		var canvas_mat := CanvasItemMaterial.new()
		canvas_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		circle.material = canvas_mat
	return circle


func _make_orb_hard_core_sprite(node_name: String, start_scale: float) -> Sprite2D:
	var circle := Sprite2D.new()
	circle.name = node_name
	circle.texture = _get_orb_hard_core_texture()
	circle.centered = true
	circle.scale = Vector2(start_scale, start_scale)
	circle.modulate = Color(1, 1, 1, 1)
	return circle


func _get_orb_white_texture() -> Texture2D:
	if _orb_white_tex != null:
		return _orb_white_tex
	const S := 64
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var mid := Vector2((S - 1) * 0.5, (S - 1) * 0.5)
	var max_r := float(S) * 0.48
	for y in S:
		for x in S:
			var d := Vector2(float(x), float(y)).distance_to(mid) / max_r
			var a := 0.0
			if d < 1.0:
				a = pow(1.0 - d, 1.55)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_orb_white_tex = ImageTexture.create_from_image(img)
	return _orb_white_tex


## Anillo que sale de la ball tras absorber: crece (blanco → amarillo) y luego encoge al cerrar.
func _play_absorb_ring_halo_expand() -> Sprite2D:
	if ball == null:
		return null
	const START_SCALE := 0.55
	const END_SCALE := 1.66
	const DURATION := 0.33
	const COL_WHITE := Color(1.0, 1.0, 1.0, 0.85)
	const COL_YELLOW := Color(1.0, 0.9, 0.35, 0.55)

	var ring := Sprite2D.new()
	ring.name = "AbsorbRingHalo"
	ring.texture = _get_ring_halo_texture()
	ring.centered = true
	ring.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	ring.scale = Vector2(START_SCALE, START_SCALE)
	ring.modulate = Color(COL_WHITE.r, COL_WHITE.g, COL_WHITE.b, 0.0)
	ring.z_as_relative = true
	ring.z_index = -1
	ball.add_child(ring)
	ring.position = _ball_content_center_offset()

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector2(END_SCALE, END_SCALE), DURATION).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_OUT)
	tw.tween_method(
		func(t: float) -> void:
			if not is_instance_valid(ring):
				return
			var col := COL_WHITE.lerp(COL_YELLOW, t)
			var a := 0.0
			if t < 0.15:
				a = lerpf(0.0, COL_WHITE.a, t / 0.15)
			else:
				a = lerpf(COL_WHITE.a, COL_YELLOW.a, minf((t - 0.15) / 0.35, 1.0))
			ring.modulate = Color(col.r, col.g, col.b, a),
		0.0,
		1.0,
		DURATION
	)
	await tw.finished
	return ring


func _shrink_absorb_ring_halo(ring: Sprite2D, duration: float) -> Tween:
	if ring == null or not is_instance_valid(ring):
		return null
	const END_SCALE := 0.35
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector2(END_SCALE, END_SCALE), duration).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_IN)
	tw.tween_property(ring, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN
	)
	return tw


## Textura de anillo (borde suave, interior vacío).
func _get_ring_halo_texture() -> Texture2D:
	if _ring_halo_tex != null:
		return _ring_halo_tex
	const S := 128
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var mid := Vector2((S - 1) * 0.5, (S - 1) * 0.5)
	var max_r := float(S) * 0.48
	var ring_r := 0.72
	var half_w := 0.11
	for y in S:
		for x in S:
			var d := Vector2(float(x), float(y)).distance_to(mid) / max_r
			var band := absf(d - ring_r)
			var a := 0.0
			if band < half_w:
				a = pow(1.0 - band / half_w, 1.35)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_ring_halo_tex = ImageTexture.create_from_image(img)
	return _ring_halo_tex


## Disco con centro totalmente opaco (para que el núcleo del flash se note al escalar).
func _get_orb_hard_core_texture() -> Texture2D:
	if _orb_hard_core_tex != null:
		return _orb_hard_core_tex
	const S := 64
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var mid := Vector2((S - 1) * 0.5, (S - 1) * 0.5)
	var max_r := float(S) * 0.48
	for y in S:
		for x in S:
			var d := Vector2(float(x), float(y)).distance_to(mid) / max_r
			var a := 0.0
			if d < 0.55:
				a = 1.0
			elif d < 1.0:
				a = pow(1.0 - (d - 0.55) / 0.45, 1.2)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_orb_hard_core_tex = ImageTexture.create_from_image(img)
	return _orb_hard_core_tex


## Offset del centro del dibujo opaco respecto al origen del Sprite2D (centered).
func _ball_content_center_offset() -> Vector2:
	if ball == null or ball.texture == null:
		return Vector2.ZERO
	var img := ball.texture.get_image()
	if img == null:
		return Vector2.ZERO
	var used := img.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return Vector2.ZERO
	var tex_center := Vector2(float(ball.texture.get_width()), float(ball.texture.get_height())) * 0.5
	var used_center := Vector2(used.position) + Vector2(used.size) * 0.5
	return used_center - tex_center


func _close_ball() -> void:
	ball.texture = _closed_texture()
	ball.scale = Vector2.ONE
	ball.rotation = 0.0


func _closed_texture() -> Texture2D:
	return PokeballItemEffect.get_battle_closed_texture(_ball_sprite_id)


func _tween_gold_flash() -> void:
	const GOLD_PEAK := Color(2.15, 1.75, 0.08, 1.0)
	var tw := create_tween()
	tw.tween_property(ball, "modulate", GOLD_PEAK, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.16)
	tw.tween_property(ball, "modulate", Color(1, 1, 1, 1), 0.38).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw.finished


func _tween_fall_and_bounce(from_hover: Vector2) -> void:
	ball.position = from_hover
	var tw := create_tween()
	# Caída al suelo.
	tw.tween_property(ball, "position", Vector2(0, 0), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(ball, "scale", Vector2(1.25, 0.7), 0.05)
	tw.tween_property(ball, "scale", Vector2(1, 1), 0.06)
	# Rebote 1.
	tw.tween_property(ball, "position", Vector2(0, -26), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(ball, "position", Vector2(0, 0), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(ball, "scale", Vector2(1.18, 0.78), 0.04)
	tw.tween_property(ball, "scale", Vector2(1, 1), 0.05)
	# Rebote 2.
	tw.tween_property(ball, "position", Vector2(0, -14), 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(ball, "position", Vector2(0, 0), 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(ball, "scale", Vector2(1.12, 0.85), 0.04)
	tw.tween_property(ball, "scale", Vector2(1, 1), 0.04)
	# Rebote 3.
	tw.tween_property(ball, "position", Vector2(0, -7), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(ball, "position", Vector2(0, 0), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(ball, "scale", Vector2(1.08, 0.9), 0.03)
	tw.tween_property(ball, "scale", Vector2(1, 1), 0.04)
	await tw.finished
	ball.position = Vector2.ZERO
	ball.scale = Vector2.ONE
	ball.rotation = 0.0
