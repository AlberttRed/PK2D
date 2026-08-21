extends Object
class_name BattleAnimationUtils

## Helpers visuales reutilizables de combate (solo presentación).
## Contrato: Docs/battle/BattleAnimationContract.md

const DEFAULT_FLASH_STEP := 0.1
const DEFAULT_HIT_END_PAUSE := 0.5


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


## Aparición de Pokémon: pequeño + blanco → tamaño/color normales. Awaitable.
## Crece desde los pies (altura de la ball) hacia arriba, sin teleport final.
## El flash blanco es un overlay que se desvanece sobre el sprite a color real
## (evita el pop oscuro al quitar el shader del propio sprite).
static func pokemon_enter_spot(
	spot: BattleSpot,
	scale_duration: float = 0.45,
	white_duration: float = 0.75
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
	var start_scale := orig_scale * 0.12
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
				),
		0.12,
		1.0,
		scale_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(flash, "modulate:a", 0.0, white_fade).set_delay(white_delay).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_OUT)
	if show_shadow:
		tw.tween_property(shadow, "modulate:a", 1.0, scale_duration)
	await tw.finished

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
