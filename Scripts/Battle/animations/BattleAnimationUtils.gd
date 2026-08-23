extends Object
class_name BattleAnimationUtils

## Helpers visuales reutilizables de combate (solo presentación).
## Contrato: Docs/battle/BattleAnimationContract.md

const DEFAULT_FLASH_STEP := 0.1
const DEFAULT_HIT_END_PAUSE := 0.5
const ENTER_LIGHT_SCENE := preload(
	"res://Scenes/Battle/animations/intro/PokemonEnterLightAnimation.tscn"
)
const ENTER_RAY_TEXTURE := preload(
	"res://Sprites/Batalla/Battle Animations/EnterRayFrames2.png"
)
const ENTER_FLASH_TEXTURE := preload(
	"res://Sprites/Batalla/Battle Animations/EnterFlashFrames.png"
)
## En BattleAnimationLayer: encima del Pokémon en spot, debajo de la ball (z=1).
const ENTER_LIGHT_Z_INDEX := 0
const ENTER_FLASH_SCALE_START := 0.85
const ENTER_FLASH_SCALE_END := 2.85
const POKEMON_ENTER_SCALE_START := 0.12
## Rayos de entrada: ángulo (° desde arriba), retardo, longitud (scale.y), duración de crecimiento.
## Abanico asimétrico (ref. frames originales): más separados; uno marcado hacia la derecha.
const ENTER_RAY_SPECS: Array[Dictionary] = [
	{"angle": -62.0, "delay": 0.10, "max_y": 3.0, "max_x": 0.78, "grow": 0.34},
	{"angle": -36.0, "delay": 0.02, "max_y": 3.5, "max_x": 0.86, "grow": 0.40},
	{"angle": -14.0, "delay": 0.16, "max_y": 2.7, "max_x": 0.72, "grow": 0.32},
	{"angle": 16.0, "delay": 0.06, "max_y": 2.85, "max_x": 0.74, "grow": 0.38},
	{"angle": 42.0, "delay": 0.20, "max_y": 3.1, "max_x": 0.76, "grow": 0.30},
	{"angle": 68.0, "delay": 0.12, "max_y": 3.3, "max_x": 0.82, "grow": 0.36},
]
const ENTER_RAY_COLOR_START := Color(1.0, 1.0, 0.98, 1.0)
const ENTER_RAY_COLOR_END := Color(1.0, 0.76, 0.18, 1.0)
const ENTER_RAY_REGION := Rect2(13.0, 16.0, 34.0, 40.0)
## Ancho final ≈ 90% del inicial al llegar a longitud máxima (estrechamiento suave).
const ENTER_RAY_WIDTH_END_RATIO := 0.9
## Cascada: chispas → rayos → foco circular.
const ENTER_SPARK_FADE_LEAD_BEFORE_FLASH := 0.34
const ENTER_RAY_FADE_LEAD_BEFORE_FLASH := 0.18
const ENTER_SPARK_RAY_FADE_GAP := 0.08
const ENTER_FLASH_FADE_EXTRA_HOLD := 0.18
const ENTER_FLASH_FADE_DURATION_SCALE := 1.08
const ENTER_RAY_FADE_DURATION_SCALE := 0.72
const ENTER_SPARK_FADE_DURATION_SCALE := 0.68
## Alpha máxima de rayos (< flash) para que se lean detrás del brillo circular.
const ENTER_RAY_ALPHA_PEAK := 0.58
## Chispas: mini bolas EnterFlash; spawn/reach definen dónde nacen y hasta dónde llegan.
## Radio máx. ≈ longitud de rayo (max_y 3.5 × región 40 px).
const ENTER_SPARK_MAX_REACH := 118.0
const ENTER_SPARK_SPECS: Array[Dictionary] = [
	# Junto al foco — deriva corta
	{"angle": -22.0, "spawn": 0.0, "reach": 0.22, "delay": 0.00, "scale": 0.22},
	{"angle": 18.0, "spawn": 0.02, "reach": 0.26, "delay": 0.03, "scale": 0.26},
	{"angle": -48.0, "spawn": 0.0, "reach": 0.20, "delay": 0.05, "scale": 0.20},
	{"angle": 52.0, "spawn": 0.03, "reach": 0.24, "delay": 0.07, "scale": 0.24},
	# Desde abajo — recorrido medio
	{"angle": 178.0, "spawn": 0.0, "reach": 0.34, "delay": 0.06, "scale": 0.28, "offset": Vector2(0, 6)},
	{"angle": 165.0, "spawn": 0.02, "reach": 0.40, "delay": 0.10, "scale": 0.30, "offset": Vector2(-4, 8)},
	{"angle": 192.0, "spawn": 0.0, "reach": 0.38, "delay": 0.14, "scale": 0.26, "offset": Vector2(5, 7)},
	{"angle": 172.0, "spawn": 0.04, "reach": 0.32, "delay": 0.18, "scale": 0.24, "offset": Vector2(0, 5)},
	# Recorrido medio
	{"angle": -14.0, "spawn": 0.0, "reach": 0.58, "delay": 0.08, "scale": 0.32},
	{"angle": 38.0, "spawn": 0.04, "reach": 0.52, "delay": 0.06, "scale": 0.30},
	# Largo alcance — hasta donde llegan los rayos (mismos ángulos)
	{"angle": -62.0, "spawn": 0.0, "reach": 0.98, "delay": 0.01, "scale": 0.36},
	{"angle": -36.0, "spawn": 0.02, "reach": 1.05, "delay": 0.03, "scale": 0.42},
	{"angle": 16.0, "spawn": 0.0, "reach": 0.92, "delay": 0.05, "scale": 0.38},
	{"angle": 68.0, "spawn": 0.0, "reach": 1.0, "delay": 0.04, "scale": 0.40},
]
const ENTER_SPARK_ALPHA_PEAK := 0.90
const ENTER_SPARK_ALPHA_PEAK_INNER := 0.62
const ENTER_SPARK_ALPHA_FLOOR := 0.50
const ENTER_SPARK_FADE_IN_SEC := 0.10
const ENTER_SPARK_SCALE_START_RATIO := 0.28
## 1.0 = velocidad de alejamiento constante durante toda la vida visible.
const ENTER_SPARK_MOVE_POWER := 1.0
const ENTER_SPARK_DEFAULT_LIFE := 0.64
## Posición de reposo de la ball en campo rival (global = Feet + offset) — solo enter flash.
const ENEMY_BALL_GROUND_OFFSET := Vector2(0.0, -44.0)
const ENTER_FLASH_ENEMY_BALL_OFFSET := ENEMY_BALL_GROUND_OFFSET
const ENTER_FLASH_PLAYER_BALL_OFFSET := Vector2(0.0, 10.0)


## Parpadeo del sprite del spot (hit). Awaitable.
static func flash_spot(
	spot: BattleSpot,
	flashes: int = 2,
	step_duration: float = DEFAULT_FLASH_STEP,
	end_pause: float = DEFAULT_HIT_END_PAUSE
) -> void:
	if not _spot_sprite_ready(spot):
		return
	var spr: Sprite2D = spot.sprite
	var tw := spot.create_tween()
	tw.set_parallel(false)
	for _i in maxi(flashes, 1):
		tw.tween_property(spr, "modulate", Color(1, 1, 1, 0.0), step_duration)
		tw.tween_property(spr, "modulate", Color(1, 1, 1, 1.0), step_duration)
	await tw.finished
	if end_pause > 0.0 and is_instance_valid(spot) and spot.get_tree() != null:
		await spot.get_tree().create_timer(end_pause).timeout


## Sacudida horizontal del sprite. Awaitable.
static func shake_spot(
	spot: BattleSpot,
	intensity: float = 4.0,
	duration: float = 0.25
) -> void:
	if not _spot_sprite_ready(spot):
		return
	var spr: Sprite2D = spot.sprite
	var origin := spr.position
	var tw := spot.create_tween()
	tw.set_parallel(false)
	var steps := 4
	var step_t := duration / float(steps)
	for i in steps:
		var dir_sign := 1.0 if (i % 2) == 0 else -1.0
		var amp := intensity * (1.0 - float(i) / float(steps))
		tw.tween_property(spr, "position", origin + Vector2(dir_sign * amp, 0.0), step_t)
	tw.tween_property(spr, "position", origin, step_t)
	await tw.finished
	if is_instance_valid(spr):
		spr.position = origin


## Desplaza solo el sprite hacia el rival y vuelve (HP bar / UI del spot no se mueven). Awaitable.
static func move_spot_forward(
	spot: BattleSpot,
	distance: float = 16.0,
	duration: float = 0.12
) -> void:
	if not _spot_sprite_ready(spot):
		return
	var spr: Sprite2D = spot.sprite
	var dir := _forward_sign(spot)
	var origin := spr.position
	var tw := spot.create_tween()
	tw.set_parallel(false)
	tw.tween_property(spr, "position", origin + Vector2(dir * distance, 0.0), duration)
	tw.tween_property(spr, "position", origin, duration)
	await tw.finished
	if is_instance_valid(spr):
		spr.position = origin


## Oscurece el campo con un Polygon2D hijo de `parent`. Devuelve el overlay (o null).
static func darken_overlay(
	parent: Node,
	alpha: float = 0.45,
	duration: float = 0.15
) -> Polygon2D:
	if parent == null or not is_instance_valid(parent):
		return null
	var overlay := Polygon2D.new()
	overlay.name = "BattleAnimDarkenOverlay"
	overlay.z_index = 100
	overlay.color = Color(0, 0, 0, 0)
	overlay.polygon = PackedVector2Array([
		Vector2(-2000, -2000),
		Vector2(4000, -2000),
		Vector2(4000, 4000),
		Vector2(-2000, 4000),
	])
	parent.add_child(overlay)
	var tw := overlay.create_tween()
	tw.tween_property(overlay, "color", Color(0, 0, 0, alpha), duration)
	await tw.finished
	return overlay


## Restaura y elimina un overlay creado por darken_overlay. Awaitable.
static func restore_overlay(overlay: Polygon2D, duration: float = 0.15) -> void:
	if overlay == null or not is_instance_valid(overlay):
		return
	var tw := overlay.create_tween()
	tw.tween_property(overlay, "color", Color(0, 0, 0, 0), duration)
	await tw.finished
	if is_instance_valid(overlay):
		overlay.queue_free()


static func wait(host: Node, seconds: float) -> void:
	if host == null or not is_instance_valid(host) or host.get_tree() == null:
		return
	if seconds <= 0.0:
		return
	await host.get_tree().create_timer(seconds).timeout


## Contenedor del destello + rayos en animation layer. Devuelve la raíz o null.
static func _spawn_enter_light_root(animation_layer: Node2D, spot: BattleSpot) -> Node2D:
	if animation_layer == null or not is_instance_valid(animation_layer):
		return null
	if spot == null or not is_instance_valid(spot):
		return null
	var instance: Node2D = ENTER_LIGHT_SCENE.instantiate() as Node2D
	if instance == null:
		return null

	animation_layer.add_child(instance)
	instance.z_index = ENTER_LIGHT_Z_INDEX
	instance.z_as_relative = true

	var ball_offset := _get_enter_flash_ball_offset(spot)
	instance.global_position = spot.get_anchor_global_position(BattleSpot.ANCHOR_FEET) + ball_offset

	var ground_flash := instance.get_node_or_null("GroundFlash") as Sprite2D
	if ground_flash == null:
		instance.queue_free()
		return null

	ground_flash.modulate = Color(1, 1, 1, 0)
	ground_flash.frame = 0
	ground_flash.z_index = 1
	ground_flash.scale = Vector2(ENTER_FLASH_SCALE_START, ENTER_FLASH_SCALE_START)
	var rays := _setup_enter_rays(instance)
	var sparks := _setup_enter_sparks(animation_layer, instance, instance.global_position)
	instance.set_meta(&"enter_rays", rays)
	instance.set_meta(&"enter_sparks", sparks)
	return instance


static func _get_enter_sparks_from_light_root(light_root: Node2D) -> Array[Sprite2D]:
	if light_root == null or not is_instance_valid(light_root):
		return []
	if light_root.has_meta(&"enter_sparks"):
		var stored: Variant = light_root.get_meta(&"enter_sparks")
		if stored is Array:
			return stored as Array[Sprite2D]
	var collected: Array[Sprite2D] = []
	if light_root.has_meta(&"enter_sparks_root"):
		var sparks_root: Node = light_root.get_meta(&"enter_sparks_root") as Node
		if sparks_root != null and is_instance_valid(sparks_root):
			for child in sparks_root.get_children():
				if child is Sprite2D:
					collected.append(child as Sprite2D)
	return collected


static func _get_enter_rays_from_light_root(light_root: Node2D) -> Array[Sprite2D]:
	if light_root == null or not is_instance_valid(light_root):
		return []
	if light_root.has_meta(&"enter_rays"):
		return light_root.get_meta(&"enter_rays") as Array[Sprite2D]
	return []


static func _enter_vfx_max_duration() -> float:
	var max_time := _enter_specs_max_duration(ENTER_RAY_SPECS, 0.24)
	for spec in ENTER_SPARK_SPECS:
		max_time = maxf(
			max_time,
			float(spec["delay"]) + float(spec.get("life", ENTER_SPARK_DEFAULT_LIFE))
		)
	return max_time


static func _enter_specs_max_duration(specs: Array[Dictionary], visual_tail: float) -> float:
	var max_time := 0.0
	for spec in specs:
		max_time = maxf(max_time, float(spec.delay) + float(spec.grow) + visual_tail)
	return max_time


static func _enter_rays_max_duration() -> float:
	return _enter_vfx_max_duration()


static func _make_enter_beam_sprite(start_y: float) -> Sprite2D:
	var beam := Sprite2D.new()
	beam.texture = ENTER_RAY_TEXTURE
	beam.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	beam.region_enabled = true
	beam.region_rect = ENTER_RAY_REGION
	beam.centered = false
	var start_x := 0.28
	beam.scale = Vector2(start_x, start_y)
	beam.position = _enter_ray_position_for_scale(beam.scale)
	beam.modulate = Color(1, 1, 1, 0)
	return beam


static func _make_enter_spark_sprite(frame: int) -> Sprite2D:
	var spark := Sprite2D.new()
	spark.texture = ENTER_FLASH_TEXTURE
	spark.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spark.hframes = 3
	spark.frame = frame
	spark.centered = true
	spark.modulate = Color(1, 1, 1, 0)
	return spark


static func _setup_enter_sparks(
	animation_layer: Node2D,
	light_root: Node2D,
	center_global: Vector2
) -> Array[Sprite2D]:
	var sparks: Array[Sprite2D] = []
	if (
		animation_layer == null
		or not is_instance_valid(animation_layer)
		or light_root == null
		or not is_instance_valid(light_root)
	):
		return sparks

	var sparks_root := Node2D.new()
	sparks_root.name = "EnterSparks"
	sparks_root.z_index = 2
	sparks_root.z_as_relative = true
	sparks_root.global_position = center_global
	animation_layer.add_child(sparks_root)
	light_root.set_meta(&"enter_sparks_root", sparks_root)

	for spec in ENTER_SPARK_SPECS:
		var spark := _make_enter_spark_sprite(0)
		var spawn_reach := float(spec.get("spawn", 0.0))
		spark.position = _enter_spark_position(spec, spawn_reach)
		var end_scale := float(spec.get("scale", 0.35))
		spark.scale = Vector2.ONE * end_scale * ENTER_SPARK_SCALE_START_RATIO
		sparks_root.add_child(spark)
		sparks.append(spark)
	return sparks


static func _setup_enter_rays(light_root: Node2D) -> Array[Sprite2D]:
	var rays: Array[Sprite2D] = []
	if light_root == null or not is_instance_valid(light_root):
		return rays

	var rays_root := Node2D.new()
	rays_root.name = "Rays"
	rays_root.z_index = -1
	light_root.add_child(rays_root)

	for spec in ENTER_RAY_SPECS:
		var pivot := Node2D.new()
		pivot.rotation = deg_to_rad(float(spec.angle))
		var ray := _make_enter_beam_sprite(0.18)
		ray.scale = Vector2(float(spec.max_x), 0.18)
		ray.position = _enter_ray_position_for_scale(ray.scale)
		pivot.add_child(ray)
		rays_root.add_child(pivot)
		rays.append(ray)
	return rays


static func _enter_ray_position_for_scale(scale: Vector2) -> Vector2:
	return Vector2(
		-ENTER_RAY_REGION.size.x * 0.5 * scale.x,
		-ENTER_RAY_REGION.size.y * scale.y
	)


static func _apply_enter_ray_frame(ray: Sprite2D, spec: Dictionary, progress: float) -> void:
	_apply_enter_beam_frame(
		ray,
		spec,
		progress,
		0.18,
		ENTER_RAY_WIDTH_END_RATIO,
		0.62
	)


static func _enter_spark_direction(angle_deg: float) -> Vector2:
	return Vector2.from_angle(deg_to_rad(angle_deg - 90.0))


static func _enter_spark_position(spec: Dictionary, dist_reach: float) -> Vector2:
	var angle_deg := float(spec.get("angle", 0.0))
	var radial := _enter_spark_direction(angle_deg) * dist_reach * ENTER_SPARK_MAX_REACH
	if spec.has("offset"):
		return radial + (spec["offset"] as Vector2)
	return radial


static func _enter_spark_travel_duration(
	spec: Dictionary,
	vfx_end: float
) -> float:
	var delay := float(spec.get("delay", 0.0))
	var life := float(spec.get("life", ENTER_SPARK_DEFAULT_LIFE))
	return maxf(life, vfx_end - delay)


static func _compute_enter_light_fade_schedule(
	scale_duration: float,
	white_duration: float
) -> Dictionary:
	var white_fade := maxf(white_duration - scale_duration * 0.35, scale_duration * 0.55)
	var white_delay := maxf(white_duration - white_fade, 0.0)
	var flash_fade_start := white_delay + ENTER_FLASH_FADE_EXTRA_HOLD
	var flash_fade_dur := white_fade * ENTER_FLASH_FADE_DURATION_SCALE
	var spark_fade_start := maxf(
		flash_fade_start - ENTER_SPARK_FADE_LEAD_BEFORE_FLASH,
		scale_duration * 0.26
	)
	var ray_fade_start := maxf(
		flash_fade_start - ENTER_RAY_FADE_LEAD_BEFORE_FLASH,
		spark_fade_start + ENTER_SPARK_RAY_FADE_GAP
	)
	var vfx_end := flash_fade_start + flash_fade_dur
	return {
		"flash_fade_start": flash_fade_start,
		"flash_fade_dur": flash_fade_dur,
		"ray_fade_start": ray_fade_start,
		"ray_fade_dur": maxf(
			(flash_fade_start - ray_fade_start) + flash_fade_dur * ENTER_RAY_FADE_DURATION_SCALE,
			0.24
		),
		"spark_fade_start": spark_fade_start,
		"spark_fade_dur": maxf(
			(flash_fade_start - spark_fade_start) + flash_fade_dur * ENTER_SPARK_FADE_DURATION_SCALE,
			0.22
		),
		"vfx_end": vfx_end,
	}


static func _apply_enter_spark_frame(
	spark: Sprite2D,
	spec: Dictionary,
	progress: float,
	fade_schedule: Dictionary
) -> void:
	if spark == null or not is_instance_valid(spark):
		return
	var spawn_reach := float(spec.get("spawn", 0.0))
	var end_reach := maxf(float(spec.get("reach", spawn_reach + 0.14)), spawn_reach + 0.10)
	var end_scale := float(spec.get("scale", 0.35))
	var delay := float(spec.get("delay", 0.0))
	var vfx_end := float(fade_schedule.get("vfx_end", 0.75))
	var travel_dur := _enter_spark_travel_duration(spec, vfx_end)
	var elapsed := delay + progress * travel_dur

	var move_t := clampf(progress, 0.0, 1.0)
	if ENTER_SPARK_MOVE_POWER != 1.0:
		move_t = pow(move_t, ENTER_SPARK_MOVE_POWER)
	var dist_reach := lerpf(spawn_reach, end_reach, move_t)
	spark.position = _enter_spark_position(spec, dist_reach)

	var scale_t := clampf(progress / 0.52, 0.0, 1.0)
	scale_t = scale_t * scale_t * (3.0 - 2.0 * scale_t)
	var sc := lerpf(end_scale * ENTER_SPARK_SCALE_START_RATIO, end_scale, scale_t)
	if progress > 0.82:
		var shrink_t := clampf((progress - 0.82) / 0.18, 0.0, 1.0)
		sc = lerpf(end_scale, end_scale * 0.7, shrink_t)
	spark.scale = Vector2(sc, sc)

	# Frame + modulate: avanzan con la distancia recorrida.
	var warm_t := clampf(dist_reach * 0.88 + move_t * 0.12, 0.0, 1.0)
	if warm_t < 0.34:
		spark.frame = 0
	elif warm_t < 0.67:
		spark.frame = 1
	else:
		spark.frame = 2
	var rgb := ENTER_RAY_COLOR_START.lerp(ENTER_RAY_COLOR_END, warm_t)
	var alpha_peak := maxf(
		lerpf(ENTER_SPARK_ALPHA_PEAK_INNER, ENTER_SPARK_ALPHA_PEAK, end_reach),
		ENTER_SPARK_ALPHA_FLOOR
	)
	var alpha := _enter_spark_alpha_at(elapsed, delay, fade_schedule, alpha_peak)
	spark.modulate = Color(rgb.r, rgb.g, rgb.b, alpha)


static func _enter_spark_alpha_at(
	elapsed: float,
	delay: float,
	fade_schedule: Dictionary,
	alpha_peak: float
) -> float:
	if elapsed < delay:
		return 0.0
	var fade_in := ENTER_SPARK_FADE_IN_SEC
	if elapsed < delay + fade_in:
		var t := clampf((elapsed - delay) / fade_in, 0.0, 1.0)
		t = t * t * (3.0 - 2.0 * t)
		return lerpf(0.0, alpha_peak, t)
	var fade_start := float(fade_schedule.get("spark_fade_start", 0.35))
	if elapsed < fade_start:
		return alpha_peak
	var fade_dur := float(fade_schedule.get("spark_fade_dur", 0.28))
	var fade_t := clampf((elapsed - fade_start) / fade_dur, 0.0, 1.0)
	return lerpf(alpha_peak, 0.0, fade_t)


static func _apply_enter_beam_frame(
	beam: Sprite2D,
	spec: Dictionary,
	progress: float,
	start_y: float,
	width_end_ratio: float,
	grow_window: float
) -> void:
	if beam == null or not is_instance_valid(beam):
		return
	var grow_t := clampf(progress / grow_window, 0.0, 1.0)
	var max_x := float(spec.get("max_x", 0.28))
	var scale_y := lerpf(start_y, float(spec.get("max_y", start_y)), grow_t)
	var scale_x := lerpf(max_x, max_x * width_end_ratio, grow_t)
	beam.scale = Vector2(scale_x, scale_y)
	beam.position = _enter_ray_position_for_scale(beam.scale)
	_apply_enter_ray_color(beam, progress)


static func _apply_enter_ray_color(ray: Sprite2D, progress: float) -> void:
	if ray == null or not is_instance_valid(ray):
		return
	var color_t := clampf(progress / 0.75, 0.0, 1.0)
	var rgb := ENTER_RAY_COLOR_START.lerp(ENTER_RAY_COLOR_END, color_t)
	ray.modulate = Color(rgb.r, rgb.g, rgb.b, ray.modulate.a)


static func _start_enter_beam_alpha_tween(
	spot: BattleSpot,
	beam: Sprite2D,
	delay: float,
	fade_start: float,
	fade_dur: float,
	alpha_peak: float
) -> void:
	if spot == null or beam == null or not is_instance_valid(beam):
		return
	var beam_fade_start := maxf(fade_start, delay + 0.06)
	var tw := spot.create_tween()
	tw.tween_property(beam, "modulate:a", alpha_peak, 0.05).set_delay(delay)
	var hold := maxf(beam_fade_start - delay - 0.05, 0.0)
	if hold > 0.0:
		tw.tween_interval(hold)
	tw.tween_property(beam, "modulate:a", 0.0, fade_dur).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_OUT)


static func _start_enter_ray_alpha_tween(
	spot: BattleSpot,
	ray: Sprite2D,
	delay: float,
	fade_schedule: Dictionary
) -> void:
	_start_enter_beam_alpha_tween(
		spot,
		ray,
		delay,
		float(fade_schedule.get("ray_fade_start", 0.3)),
		float(fade_schedule.get("ray_fade_dur", 0.28)),
		ENTER_RAY_ALPHA_PEAK
	)


static func _start_enter_ray_tweens(
	spot: BattleSpot,
	rays: Array[Sprite2D],
	fade_schedule: Dictionary
) -> void:
	if spot == null or not is_instance_valid(spot):
		return

	for i in rays.size():
		var ray: Sprite2D = rays[i]
		if ray == null or not is_instance_valid(ray):
			continue
		var spec: Dictionary = ENTER_RAY_SPECS[i]
		var delay: float = float(spec.delay)
		var grow: float = float(spec.grow)
		var visual_dur := grow + 0.24

		_start_enter_ray_alpha_tween(spot, ray, delay, fade_schedule)

		var tw := spot.create_tween()
		tw.tween_method(
			func(t: float) -> void: _apply_enter_ray_frame(ray, spec, t),
			0.0,
			1.0,
			visual_dur
		).set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


static func _start_enter_spark_tweens(
	vfx_host: Node,
	sparks: Array[Sprite2D],
	fade_schedule: Dictionary
) -> void:
	if vfx_host == null or not is_instance_valid(vfx_host):
		return
	var vfx_end := float(fade_schedule.get("vfx_end", 0.75))

	for i in sparks.size():
		var spark: Sprite2D = sparks[i]
		if spark == null or not is_instance_valid(spark):
			continue
		var spec: Dictionary = ENTER_SPARK_SPECS[i]
		var delay: float = float(spec["delay"])
		var travel_dur := _enter_spark_travel_duration(spec, vfx_end)

		var tw := vfx_host.create_tween()
		tw.tween_method(
			func(t: float) -> void: _apply_enter_spark_frame(spark, spec, t, fade_schedule),
			0.0,
			1.0,
			travel_dur
		).set_delay(delay).set_trans(Tween.TRANS_LINEAR)


static func _apply_enter_ground_flash_scale(ground_flash: Sprite2D, pokemon_scale_factor: float) -> void:
	if ground_flash == null or not is_instance_valid(ground_flash):
		return
	var t := inverse_lerp(POKEMON_ENTER_SCALE_START, 1.0, pokemon_scale_factor)
	var sc := lerpf(ENTER_FLASH_SCALE_START, ENTER_FLASH_SCALE_END, t)
	ground_flash.scale = Vector2(sc, sc)
	if t < 0.33:
		ground_flash.frame = 0
	elif t < 0.66:
		ground_flash.frame = 1
	else:
		ground_flash.frame = 2


static func _get_enter_flash_ball_offset(spot: BattleSpot) -> Vector2:
	if spot != null and spot.side != null and spot.side.type == BattleSide.Types.ENEMY:
		return ENTER_FLASH_ENEMY_BALL_OFFSET
	return ENTER_FLASH_PLAYER_BALL_OFFSET


## Aparición de Pokémon: pequeño + blanco → tamaño/color normales. Awaitable.
## Crece desde los pies (altura de la ball) hacia arriba, sin teleport final.
## El flash blanco es un overlay que se desvanece sobre el sprite a color real
## (evita el pop oscuro al quitar el shader del propio sprite).
## Si `animation_layer` no es null, añade el destello naranja sincronizado al crecimiento.
static func pokemon_enter_spot(
	spot: BattleSpot,
	scale_duration: float = 0.45,
	white_duration: float = 0.75,
	animation_layer: Node2D = null
) -> void:
	if spot == null or not is_instance_valid(spot):
		return
	var spr: Sprite2D = spot.sprite
	if spr == null or not is_instance_valid(spr):
		return
	var shadow: Sprite2D = spot.shadow
	var orig_scale := spr.scale
	if orig_scale.length_squared() < 0.0001:
		orig_scale = Vector2.ONE
	var orig_pos := spr.position
	var half_h := _sprite_half_height(spr)
	var show_shadow := (
		shadow != null
		and is_instance_valid(shadow)
		and spot.pokemon != null
		and spot.pokemon.is_wild
	)
	var shadow_orig_pos := Vector2.ZERO
	var shadow_half_h := 0.0
	if show_shadow:
		shadow_orig_pos = shadow.position
		shadow_half_h = _sprite_half_height(shadow)

	spr.visible = true
	spr.modulate = Color(1, 1, 1, 1)
	var start_scale := orig_scale * POKEMON_ENTER_SCALE_START
	spr.scale = start_scale
	# Pies fijos: al reducir scale el centro subiría; bajamos position para anclar abajo.
	spr.position = _position_with_feet_anchored(orig_pos, half_h, orig_scale.y, start_scale.y)

	var flash := _make_white_overlay(spr)
	spr.add_child(flash)

	if show_shadow:
		shadow.visible = true
		shadow.scale = start_scale
		shadow.modulate = Color(1, 1, 1, 0.35)
		shadow.position = _position_with_feet_anchored(
			shadow_orig_pos, shadow_half_h, orig_scale.y, start_scale.y
		)

	# Blanco se mantiene y luego baja; acaba después del scale.
	var white_fade := maxf(white_duration - scale_duration * 0.35, scale_duration * 0.55)
	var white_delay := maxf(white_duration - white_fade, 0.0)
	var fade_schedule := _compute_enter_light_fade_schedule(scale_duration, white_duration)

	var ground_flash: Sprite2D = null
	var light_root: Node2D = null
	var enter_rays: Array[Sprite2D] = []
	if animation_layer != null and is_instance_valid(animation_layer):
		light_root = _spawn_enter_light_root(animation_layer, spot)
		if light_root != null:
			ground_flash = light_root.get_node_or_null("GroundFlash") as Sprite2D
			enter_rays = _get_enter_rays_from_light_root(light_root)
			var enter_sparks := _get_enter_sparks_from_light_root(light_root)
			_start_enter_ray_tweens(spot, enter_rays, fade_schedule)
			_start_enter_spark_tweens(light_root, enter_sparks, fade_schedule)

	var ground_flash_alpha_tw: Tween = null
	if ground_flash != null:
		var flash_fade_start := float(fade_schedule.get("flash_fade_start", white_delay))
		var flash_fade_dur := float(fade_schedule.get("flash_fade_dur", white_fade))
		ground_flash_alpha_tw = spot.create_tween()
		ground_flash_alpha_tw.tween_property(ground_flash, "modulate:a", 1.0, 0.06)
		var hold := maxf(flash_fade_start - 0.06, 0.0)
		if hold > 0.0:
			ground_flash_alpha_tw.tween_interval(hold)
		ground_flash_alpha_tw.tween_property(ground_flash, "modulate:a", 0.0, flash_fade_dur).set_trans(
			Tween.TRANS_SINE
		).set_ease(Tween.EASE_OUT)

	var tw := spot.create_tween()
	tw.set_parallel(true)
	tw.tween_method(
		func(s: float):
			var sc := orig_scale * s
			spr.scale = sc
			spr.position = _position_with_feet_anchored(orig_pos, half_h, orig_scale.y, sc.y)
			if show_shadow and is_instance_valid(shadow):
				shadow.scale = sc
				shadow.position = _position_with_feet_anchored(
					shadow_orig_pos, shadow_half_h, orig_scale.y, sc.y
				)
			if ground_flash != null and is_instance_valid(ground_flash):
				_apply_enter_ground_flash_scale(ground_flash, s),
		POKEMON_ENTER_SCALE_START,
		1.0,
		scale_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(flash, "modulate:a", 0.0, white_fade).set_delay(white_delay).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_OUT)
	if show_shadow:
		tw.tween_property(shadow, "modulate:a", 1.0, scale_duration)
	await tw.finished
	var vfx_end := maxf(float(fade_schedule.get("vfx_end", white_delay + white_fade)), _enter_vfx_max_duration())
	await wait(spot, maxf(vfx_end - scale_duration, 0.0))

	if light_root != null and is_instance_valid(light_root):
		if light_root.has_meta(&"enter_sparks_root"):
			var sparks_root: Node = light_root.get_meta(&"enter_sparks_root") as Node
			if sparks_root != null and is_instance_valid(sparks_root):
				sparks_root.queue_free()
		light_root.queue_free()
	if is_instance_valid(flash):
		flash.queue_free()
	if is_instance_valid(spr):
		spr.scale = orig_scale
		spr.position = orig_pos
		spr.modulate = Color(1, 1, 1, 1)
	if show_shadow and is_instance_valid(shadow):
		shadow.scale = orig_scale
		shadow.position = shadow_orig_pos
		shadow.modulate = Color(1, 1, 1, 1)


## Copia el sprite del spot como silueta blanca (hijo: hereda scale/position).
static func _make_white_overlay(spr: Sprite2D) -> Sprite2D:
	var flash := Sprite2D.new()
	flash.name = "EnterWhiteFlash"
	flash.texture = spr.texture
	flash.centered = spr.centered
	flash.offset = spr.offset
	flash.flip_h = spr.flip_h
	flash.flip_v = spr.flip_v
	flash.region_enabled = spr.region_enabled
	flash.region_rect = spr.region_rect
	flash.hframes = spr.hframes
	flash.vframes = spr.vframes
	flash.frame = spr.frame
	flash.texture_filter = spr.texture_filter
	flash.position = Vector2.ZERO
	flash.scale = Vector2.ONE
	flash.z_as_relative = true
	flash.z_index = 1
	flash.modulate = Color(1, 1, 1, 1)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://Shaders/evolution_white.gdshader") as Shader
	mat.set_shader_parameter("white_mix", 1.0)
	flash.material = mat
	return flash


## Intro: trainers fijos en la base; se animan PlayerBase/EnemyBase.
## Player base: der→izq. Rival base: izq→der. (CONST.BATTLE.*_BASE_*POSITION)
static func park_bases_offscreen(player_base: Node2D, enemy_base: Node2D) -> void:
	if player_base != null and is_instance_valid(player_base):
		var player_rest := _ensure_base_rest_pos(player_base)
		var player_delta := (
			CONST.BATTLE.PLAYER_BASE_INITIALPOSITION - CONST.BATTLE.PLAYER_BASE_FINALPOSITION
		)
		player_base.position = player_rest + player_delta
	if enemy_base != null and is_instance_valid(enemy_base):
		var enemy_rest := _ensure_base_rest_pos(enemy_base)
		var enemy_delta := (
			CONST.BATTLE.ENEMY_BASE_INITIALPOSITION - CONST.BATTLE.ENEMY_BASE_FINALPOSITION
		)
		enemy_base.position = enemy_rest + enemy_delta


static func battle_bases_enter(
	player_base: Node2D,
	enemy_base: Node2D,
	host: Node,
	duration: float = 0.7
) -> void:
	if host == null or not is_instance_valid(host):
		return
	# Asegura posición inicial (por si no se llamó park_bases_offscreen).
	park_bases_offscreen(player_base, enemy_base)
	var tw := host.create_tween()
	tw.set_parallel(true)
	var any := false
	if player_base != null and is_instance_valid(player_base):
		var player_rest := _ensure_base_rest_pos(player_base)
		tw.tween_property(player_base, "position", player_rest, duration).set_trans(
			Tween.TRANS_SINE
		).set_ease(Tween.EASE_OUT)
		any = true
	if enemy_base != null and is_instance_valid(enemy_base):
		var enemy_rest := _ensure_base_rest_pos(enemy_base)
		tw.tween_property(enemy_base, "position", enemy_rest, duration).set_trans(
			Tween.TRANS_SINE
		).set_ease(Tween.EASE_OUT)
		any = true
	if not any:
		return
	await tw.finished
	if player_base != null and is_instance_valid(player_base):
		player_base.position = _ensure_base_rest_pos(player_base)
	if enemy_base != null and is_instance_valid(enemy_base):
		enemy_base.position = _ensure_base_rest_pos(enemy_base)


static func _ensure_base_rest_pos(base: Node2D) -> Vector2:
	if not base.has_meta("battle_base_rest_pos"):
		base.set_meta("battle_base_rest_pos", base.position)
	return base.get_meta("battle_base_rest_pos")


static func set_trainer_idle_frame(trainer_root: Node2D) -> void:
	if trainer_root == null or not is_instance_valid(trainer_root):
		return
	var spr := trainer_root.get_node_or_null("Sprite") as Sprite2D
	if spr == null or not is_instance_valid(spr):
		return
	spr.frame = 0


## Entrada del trainer al campo (inverso de trainer_exit). Idle en frame 0. Awaitable.
## `from_left`: player (izq→der). `from_left == false`: rival (der→izq).
static func trainer_enter(
	trainer_root: Node2D,
	from_left: bool,
	duration: float = 0.55,
	slide_distance: float = 360.0
) -> void:
	if trainer_root == null or not is_instance_valid(trainer_root):
		return
	if not trainer_root.has_meta("trainer_rest_pos"):
		trainer_root.set_meta("trainer_rest_pos", trainer_root.position)
	var rest: Vector2 = trainer_root.get_meta("trainer_rest_pos")
	set_trainer_idle_frame(trainer_root)
	var start := rest
	start.x = rest.x - slide_distance if from_left else rest.x + slide_distance
	trainer_root.position = start
	_show_trainer_visual(trainer_root)
	var tw := trainer_root.create_tween()
	tw.tween_property(trainer_root, "position", rest, duration).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_OUT
	)
	await tw.finished
	trainer_root.position = rest


## Salida del trainer del campo (solo el nodo Trainer, la base permanece).
## Player: sale a la izquierda. Rival: sale a la derecha. Awaitable.
static func trainer_exit(
	trainer_root: Node2D,
	to_left: bool,
	duration: float = 0.55,
	slide_distance: float = 360.0
) -> void:
	var tw := start_trainer_exit_tween(trainer_root, to_left, duration, slide_distance)
	if tw == null:
		return
	await tw.finished
	finalize_trainer_exit(trainer_root)


## Inicia el slide de salida y devuelve el Tween (para solapar con la ball).
static func start_trainer_exit_tween(
	trainer_root: Node2D,
	to_left: bool,
	duration: float = 0.55,
	slide_distance: float = 360.0
) -> Tween:
	if trainer_root == null or not is_instance_valid(trainer_root):
		return null
	if not trainer_root.visible:
		return null
	if not trainer_root.has_meta("trainer_rest_pos"):
		trainer_root.set_meta("trainer_rest_pos", trainer_root.position)
	var rest: Vector2 = trainer_root.get_meta("trainer_rest_pos")
	var end := rest
	end.x = rest.x - slide_distance if to_left else rest.x + slide_distance
	var tw := trainer_root.create_tween()
	tw.tween_property(trainer_root, "position", end, duration).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN
	)
	tw.tween_callback(func(): finalize_trainer_exit(trainer_root))
	return tw


## Player: frames de throw (trback) + slide a la izquierda, en paralelo.
static func start_player_trainer_exit_with_throw(
	trainer_root: Node2D,
	duration: float = 1.1,
	slide_distance: float = 360.0
) -> Tween:
	if trainer_root == null or not is_instance_valid(trainer_root):
		return null
	if not trainer_root.visible:
		return null
	if not trainer_root.has_meta("trainer_rest_pos"):
		trainer_root.set_meta("trainer_rest_pos", trainer_root.position)
	var rest: Vector2 = trainer_root.get_meta("trainer_rest_pos")
	var end := rest + Vector2(-slide_distance, 0.0)
	var spr := trainer_root.get_node_or_null("Sprite") as Sprite2D
	var tw := trainer_root.create_tween()
	tw.set_parallel(true)
	if spr != null and spr.hframes > 1:
		var last_frame := float(spr.hframes - 1)
		# Gesto en la primera parte del slide (como en los juegos).
		tw.tween_method(
			func(v: float):
				if is_instance_valid(spr):
					spr.frame = clampi(int(v), 0, spr.hframes - 1),
			0.0,
			last_frame + 0.99,
			duration * 0.4
		).set_trans(Tween.TRANS_LINEAR)
	tw.tween_property(trainer_root, "position", end, duration).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN
	)
	tw.chain().tween_callback(func(): finalize_trainer_exit(trainer_root))
	return tw


static func finalize_trainer_exit(trainer_root: Node2D) -> void:
	if trainer_root == null or not is_instance_valid(trainer_root):
		return
	var rest: Vector2 = (
		trainer_root.get_meta("trainer_rest_pos")
		if trainer_root.has_meta("trainer_rest_pos")
		else trainer_root.position
	)
	trainer_root.position = rest
	set_trainer_idle_frame(trainer_root)
	_hide_trainer_visual(trainer_root)
	if trainer_root.has_meta("trainer_send_in_exit_active"):
		trainer_root.remove_meta("trainer_send_in_exit_active")


## Muestra al entrenador en su posición de reposo (requiere `trainer_rest_pos` previo).
static func show_trainer_at_rest(trainer_root: Node2D) -> void:
	if trainer_root == null or not is_instance_valid(trainer_root):
		return
	if trainer_root.has_meta("trainer_rest_pos"):
		trainer_root.position = trainer_root.get_meta("trainer_rest_pos")
	set_trainer_idle_frame(trainer_root)
	_show_trainer_visual(trainer_root)


static func _show_trainer_visual(trainer_root: Node2D) -> void:
	if trainer_root == null or not is_instance_valid(trainer_root):
		return
	trainer_root.visible = true
	var spr := trainer_root.get_node_or_null("Sprite") as Sprite2D
	if spr != null:
		spr.visible = true


static func _hide_trainer_visual(trainer_root: Node2D) -> void:
	if trainer_root == null or not is_instance_valid(trainer_root):
		return
	trainer_root.visible = false
	var spr := trainer_root.get_node_or_null("Sprite") as Sprite2D
	if spr != null:
		spr.visible = false


## Recall / salida del Pokémon del spot. Player: slide izq. Rival: ball + blanco + scale.
static func pokemon_exit_spot(spot: BattleSpot) -> void:
	if spot == null or not is_instance_valid(spot):
		return
	var spr: Sprite2D = spot.sprite
	if spr == null or not is_instance_valid(spr) or not spr.visible:
		if spot.hp_bar != null and spot.hp_bar.visible:
			await spot.play_hp_bar_slide_out()
		return
	var is_enemy := spot.side != null and spot.side.type == BattleSide.Types.ENEMY
	if is_enemy:
		await pokemon_exit_enemy_recall(spot)
	else:
		await pokemon_exit_player_slide(spot)


## Player: el sprite se va hacia la izquierda hasta desaparecer.
static func pokemon_exit_player_slide(
	spot: BattleSpot,
	duration: float = 0.55,
	slide_distance: float = 340.0
) -> void:
	if spot == null or not is_instance_valid(spot):
		return
	var spr: Sprite2D = spot.sprite
	if spr == null or not is_instance_valid(spr) or not spr.visible:
		return
	var orig_pos := spr.position
	var shadow: Sprite2D = spot.shadow
	var shadow_orig := Vector2.ZERO
	var move_shadow := shadow != null and is_instance_valid(shadow) and shadow.visible
	if move_shadow:
		shadow_orig = shadow.position
	var tw := spot.create_tween()
	tw.set_parallel(true)
	tw.tween_property(spr, "position", orig_pos + Vector2(-slide_distance, 0.0), duration).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_IN)
	if move_shadow:
		tw.tween_property(
			shadow, "position", shadow_orig + Vector2(-slide_distance, 0.0), duration
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw.finished
	if is_instance_valid(spr):
		spr.visible = false
		spr.position = orig_pos
	if move_shadow and is_instance_valid(shadow):
		shadow.visible = false
		shadow.position = shadow_orig
	if spot.hp_bar != null and spot.hp_bar.visible:
		await spot.play_hp_bar_slide_out()


## Rival recall (ref. frames cambio pokemon rival):
## ball cerrada 0.5s → abierta 0.5s → blanco a tamaño completo → scale↓ + ball cierra a la vez →
## sprite desaparece → ball cerrada 0.5s → ball out.
## Recall rival: centro de la ball en BallGround (suelo del spot).
const ENEMY_RECALL_BALL_OFFSET := Vector2.ZERO
const ENEMY_RECALL_CLOSED_INTRO_SEC := 0.5
const ENEMY_RECALL_OPEN_HOLD_SEC := 0.5
const ENEMY_RECALL_WHITE_SEC := 0.28
const ENEMY_RECALL_SCALE_SEC := 0.55
const ENEMY_RECALL_CLOSED_HOLD_SEC := 0.5
const ENEMY_RECALL_BALL_FADE_SEC := 0.15

static func pokemon_exit_enemy_recall(spot: BattleSpot) -> void:
	if spot == null or not is_instance_valid(spot):
		return
	var spr: Sprite2D = spot.sprite
	if spr == null or not is_instance_valid(spr) or not spr.visible:
		return
	var orig_scale := spr.scale
	if orig_scale.length_squared() < 0.0001:
		orig_scale = Vector2.ONE
	var orig_pos := spr.position
	var half_h := _sprite_half_height(spr)
	var shadow: Sprite2D = spot.shadow
	var shadow_orig_pos := Vector2.ZERO
	var shadow_orig_scale := Vector2.ONE
	var has_shadow := shadow != null and is_instance_valid(shadow) and shadow.visible
	if has_shadow:
		shadow_orig_pos = shadow.position
		shadow_orig_scale = shadow.scale

	var tex_closed := load("res://Sprites/Pictures/ball00.png") as Texture2D
	var tex_open := load("res://Sprites/Pictures/ball00_open.png") as Texture2D

	var ball := Sprite2D.new()
	ball.name = "RecallBall"
	ball.texture = tex_closed
	ball.z_as_relative = false
	ball.z_index = FieldUI.FIELD_POKEBALL_Z
	ball.modulate = Color(1, 1, 1, 0)
	spot.add_child(ball)
	var ball_ground := spot.get_anchor_node(BattleSpot.ANCHOR_BALL_GROUND)
	if ball_ground != null:
		ball.global_position = ball_ground.global_position + ENEMY_RECALL_BALL_OFFSET
	else:
		var feet := spot.get_anchor_node(BattleSpot.ANCHOR_FEET)
		if feet != null:
			ball.global_position = feet.global_position + Vector2(0.0, -56.0)
		else:
			ball.position = Vector2(0.0, -56.0)

	# 1) Ball cerrada visible ~0.5s.
	var tw_in := spot.create_tween()
	tw_in.tween_property(ball, "modulate:a", 1.0, ENEMY_RECALL_BALL_FADE_SEC)
	await tw_in.finished
	await wait(spot, ENEMY_RECALL_CLOSED_INTRO_SEC)

	# 2) Abre y se mantiene ~0.5s.
	if is_instance_valid(ball):
		ball.texture = tex_open
	await wait(spot, ENEMY_RECALL_OPEN_HOLD_SEC)

	# 2) Transición a blanco a tamaño completo (aún sin scale).
	var flash := _make_white_overlay(spr)
	flash.name = "RecallWhiteFlash"
	flash.modulate.a = 0.0
	spr.add_child(flash)
	var tw_white := spot.create_tween()
	tw_white.tween_property(flash, "modulate:a", 1.0, ENEMY_RECALL_WHITE_SEC).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_OUT)
	await tw_white.finished

	# 3) Empieza el scale↓ y a la vez la ball se cierra.
	if is_instance_valid(ball):
		ball.texture = tex_closed

	var tw_scale := spot.create_tween()
	tw_scale.tween_method(
		func(s: float):
			if not is_instance_valid(spr):
				return
			var sc := orig_scale * s
			spr.scale = sc
			spr.position = _position_with_feet_anchored(orig_pos, half_h, orig_scale.y, sc.y)
			if has_shadow and is_instance_valid(shadow):
				shadow.scale = shadow_orig_scale * s
				shadow.position = _position_with_feet_anchored(
					shadow_orig_pos, half_h, shadow_orig_scale.y, shadow.scale.y
				),
		1.0,
		0.06,
		ENEMY_RECALL_SCALE_SEC
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw_scale.finished

	# 4) Sprite desaparece; ball cerrada se mantiene ~1s.
	if is_instance_valid(flash):
		flash.queue_free()
	if is_instance_valid(spr):
		spr.visible = false
		spr.scale = orig_scale
		spr.position = orig_pos
		spr.modulate = Color(1, 1, 1, 1)
	if has_shadow and is_instance_valid(shadow):
		shadow.visible = false
		shadow.scale = shadow_orig_scale
		shadow.position = shadow_orig_pos

	await wait(spot, ENEMY_RECALL_CLOSED_HOLD_SEC)

	# 5) Ball desaparece.
	if is_instance_valid(ball):
		var tw_out := spot.create_tween()
		tw_out.tween_property(ball, "modulate:a", 0.0, ENEMY_RECALL_BALL_FADE_SEC)
		await tw_out.finished
		if is_instance_valid(ball):
			ball.queue_free()

	if spot.hp_bar != null and spot.hp_bar.visible:
		await spot.play_hp_bar_slide_out()


## Mantiene el borde inferior del sprite fijo al cambiar el scale.y (Sprite2D centered).
static func _position_with_feet_anchored(
	orig_pos: Vector2,
	half_height: float,
	full_scale_y: float,
	current_scale_y: float
) -> Vector2:
	var pos := orig_pos
	pos.y = orig_pos.y + half_height * (full_scale_y - current_scale_y)
	return pos


static func _sprite_half_height(spr: Sprite2D) -> float:
	if spr == null or spr.texture == null:
		return 0.0
	var tex_h := 0.0
	if spr.region_enabled:
		tex_h = spr.region_rect.size.y
	elif spr.texture is AtlasTexture:
		tex_h = (spr.texture as AtlasTexture).region.size.y
	else:
		tex_h = float(spr.texture.get_height())
	# centered: de centro a borde = h/2; offset.y también cuenta (ya escalado aparte en formula vía half).
	if spr.centered:
		return tex_h * 0.5 + spr.offset.y
	return tex_h + spr.offset.y


static func _spot_sprite_ready(spot: BattleSpot) -> bool:
	if spot == null or not is_instance_valid(spot):
		return false
	if not spot.is_visible():
		return false
	return spot.sprite != null and is_instance_valid(spot.sprite)


static func _forward_sign(spot: BattleSpot) -> float:
	if spot.side != null and spot.side.type == BattleSide.Types.ENEMY:
		return -1.0
	return 1.0
