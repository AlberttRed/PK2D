extends Node2D
class_name ActorAnimator

## Componente reutilizable para gestionar la animación visual de actores del overworld
## (Player, NPCs y eventos animados).
## 
## Ofrece métodos genéricos para controlar animaciones según el movimiento
## o comandos del sistema de eventos.

signal animation_started(anim_name: String)

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

## Dirección actual del actor (usada para idle y animaciones direccionales)
var current_direction: Vector2 = Vector2.DOWN

## Reproduce una animación por nombre
## @param anim_name: Nombre de la animación a reproducir
func play(anim_name: String) -> void:
	if not sprite or not sprite.sprite_frames:
		return
	
	if sprite.sprite_frames.has_animation(anim_name):
		if sprite.is_playing():
			sprite.stop()
		sprite.play(anim_name)
		animation_started.emit(anim_name)
	else:
		push_warning("ActorAnimator: Animación '%s' no encontrada" % anim_name)

## Establece la dirección y reproduce la animación correspondiente
## @param dir: Dirección del movimiento (Vector2.UP, DOWN, LEFT, RIGHT)
## @param prefix: Prefijo de la animación (ej. "walk", "run")
## @param stride: Sufijo de zancada ("left" o "right")
func set_direction(dir: Vector2, prefix: String = "walk", stride: String = "right") -> void:
	if dir == Vector2.ZERO:
		return
	
	current_direction = dir
	var dir_name := _get_direction_name(dir)
	var anim_name := "%s_%s_%s" % [prefix, dir_name, stride]
	
	play(anim_name)

## Reproduce la animación idle en la dirección actual
## @param dir: Dirección opcional (si no se proporciona, usa current_direction)
func idle(dir: Vector2 = Vector2.ZERO) -> void:
	if dir != Vector2.ZERO:
		current_direction = dir
	
	if not sprite or not sprite.sprite_frames:
		return
	
	sprite.animation = "idle"
	sprite.stop()
	
	# Establecer el frame correcto según la dirección
	match current_direction:
		Vector2.UP: sprite.frame = 3
		Vector2.DOWN: sprite.frame = 0
		Vector2.LEFT: sprite.frame = 1
		Vector2.RIGHT: sprite.frame = 2

## Detiene la animación actual
func stop() -> void:
	if sprite:
		sprite.stop()

## Establece el speed_scale del sprite
## @param scale: Multiplicador de velocidad (1.0 = normal, 2.0 = doble velocidad)
func set_speed_scale(scale: float) -> void:
	if sprite:
		sprite.speed_scale = scale

## Verifica si el sprite está reproduciendo una animación
func is_playing() -> bool:
	return sprite and sprite.is_playing()

## Obtiene el nombre de la animación actual
func get_current_animation() -> String:
	if sprite:
		return sprite.animation
	return ""

## Establece el SpriteFrames del sprite (para cambiar el conjunto de animaciones)
## @param frames: Recurso SpriteFrames a asignar
func set_sprite_frames(frames: SpriteFrames) -> void:
	if sprite:
		sprite.sprite_frames = frames

## Obtiene el SpriteFrames actual
func get_sprite_frames() -> SpriteFrames:
	if sprite:
		return sprite.sprite_frames
	return null

## Muestra el sprite
func show_sprite() -> void:
	if sprite:
		sprite.visible = true

## Oculta el sprite
func hide_sprite() -> void:
	if sprite:
		sprite.visible = false

## Establece el offset del sprite
## @param offset: Desplazamiento en píxeles
func set_sprite_offset(offset: Vector2) -> void:
	if sprite:
		sprite.offset = offset

## Convierte un Vector2 de dirección a string
func _get_direction_name(dir: Vector2) -> String:
	match dir:
		Vector2.UP: return "up"
		Vector2.DOWN: return "down"
		Vector2.LEFT: return "left"
		Vector2.RIGHT: return "right"
		_: return "down"
