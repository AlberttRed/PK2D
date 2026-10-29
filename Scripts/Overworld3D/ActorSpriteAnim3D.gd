class_name ActorSpriteAnim3D
extends RefCounted
## Animación de sprite plano compartida por Player3D y NPC3D (equivalente 3D de ActorAnimator).
##
## Usa los mismos nombres que el ActorStyle / SpriteFramesGenerator del 2D:
##  - Paso: "<dir>_<left|right>" (dir = up/down/left/right) según la zancada.
##  - Idle: animación "idle" con 4 frames: 0 = abajo, 1 = izquierda, 2 = derecha, 3 = arriba.
## Las direcciones son celdas XZ: (0,-1) = arriba (−Z), (0,1) = abajo (+Z).


## Nombre de dirección para las animaciones ("up", "down", "left", "right").
static func dir_name(d: Vector2i) -> String:
	match d:
		Vector2i(0, -1):
			return "up"
		Vector2i(-1, 0):
			return "left"
		Vector2i(1, 0):
			return "right"
		_:
			return "down"


## Frame de la animación "idle" para una dirección.
static func idle_frame(d: Vector2i) -> int:
	match d:
		Vector2i(0, -1):
			return 3 ## up
		Vector2i(-1, 0):
			return 1 ## left
		Vector2i(1, 0):
			return 2 ## right
		_:
			return 0 ## down


## Asigna los frames al sprite solo si cambian (no reinicia la animación en curso sin necesidad).
static func apply_frames(sprite: AnimatedSprite3D, frames: SpriteFrames) -> void:
	if sprite == null or frames == null:
		return
	if sprite.sprite_frames != frames:
		sprite.sprite_frames = frames


## Pose quieta mirando a `facing`. Con "idle" usa su frame por dirección; si no, solo detiene.
static func apply_idle(sprite: AnimatedSprite3D, frames: SpriteFrames, facing: Vector2i) -> void:
	if sprite == null:
		return
	apply_frames(sprite, frames)
	if sprite.sprite_frames == null:
		return
	if sprite.sprite_frames.has_animation("idle"):
		sprite.animation = "idle"
		sprite.stop()
		sprite.frame = idle_frame(facing)
	else:
		sprite.stop()


## Reproduce el paso (zancada izquierda o derecha) mirando a `facing`.
static func play_stride(sprite: AnimatedSprite3D, frames: SpriteFrames, facing: Vector2i,
		stride_is_left: bool) -> void:
	if sprite == null:
		return
	apply_frames(sprite, frames)
	var anim := "%s_%s" % [dir_name(facing), "left" if stride_is_left else "right"]
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(anim):
		return
	if sprite.is_playing():
		sprite.stop()
	sprite.play(anim)
	sprite.speed_scale = 1.0
