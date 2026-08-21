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
