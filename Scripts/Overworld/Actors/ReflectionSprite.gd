extends AnimatedSprite2D
class_name ReflectionSprite

## Sprite de reflejo que se muestra cuando el actor está sobre agua
## Se sincroniza automáticamente con el sprite original del actor

## Referencia al sprite original del actor
var original_sprite: AnimatedSprite2D = null


func _ready() -> void:
	# Configurar propiedades del reflejo
	flip_v = true  # Invertir verticalmente
	z_index = -1  # Debajo del mundo
	visible = false  # Oculto por defecto
	position.y = 32
	# El offset del reflejo siempre debe ser 0,0 (no heredar el offset del sprite original)
	offset = Vector2.ZERO
	# Buscar el sprite original del actor padre
	_find_original_sprite()

	# Conectar señales del sprite original
	_connect_to_original_sprite()

	# Sincronizar inicialmente
	if original_sprite:
		_sync_with_original()

	# La visibilidad se controla desde ReflectionEffectHandler
	# No necesitamos conectar a señales de movimiento aquí

## Busca el sprite original del actor
func _find_original_sprite() -> void:
	var actor := get_parent() as Node2D
	if not actor:
		return

	# Para Events: buscar en ActorAnimator
	if actor is Event:
		var animator := actor.get_node_or_null("ActorAnimator")
		if animator and "sprite" in animator:
			var sprite_ref = animator.get("sprite")
			if sprite_ref and sprite_ref is AnimatedSprite2D:
				original_sprite = sprite_ref as AnimatedSprite2D
				return
		# Fallback: buscar directamente en ActorAnimator
		if animator:
			var animator_sprite := animator.get_node_or_null("AnimatedSprite2D")
			if animator_sprite and animator_sprite is AnimatedSprite2D:
				original_sprite = animator_sprite as AnimatedSprite2D
				return

	# Buscar AnimatedSprite2D directamente en el actor (para Player)
	var direct_sprite := actor.get_node_or_null("AnimatedSprite2D")
	if direct_sprite and direct_sprite is AnimatedSprite2D:
		original_sprite = direct_sprite as AnimatedSprite2D

## Conecta señales del sprite original
func _connect_to_original_sprite() -> void:
	if not original_sprite:
		return

	if not original_sprite.animation_changed.is_connected(_on_original_animation_changed):
		original_sprite.animation_changed.connect(_on_original_animation_changed)
	if not original_sprite.frame_changed.is_connected(_on_original_frame_changed):
		original_sprite.frame_changed.connect(_on_original_frame_changed)

## Sincroniza con el sprite original
func _sync_with_original() -> void:
	if not original_sprite:
		return

	# Sincronizar SpriteFrames
	if original_sprite.sprite_frames != sprite_frames:
		sprite_frames = original_sprite.sprite_frames

	# Sincronizar animación si existe
	if sprite_frames:
		var anim_name = original_sprite.animation
		if sprite_frames.has_animation(anim_name):
			animation = anim_name
			frame = original_sprite.frame
			speed_scale = original_sprite.speed_scale

	# Sincronizar flip horizontal
	flip_h = original_sprite.flip_h

	# Asegurar que el offset siempre sea 0,0 (no heredar el offset del sprite original)
	offset = Vector2.ZERO

## Callback cuando cambia la animación del sprite original
func _on_original_animation_changed() -> void:
	_sync_with_original()

## Callback cuando cambia el frame del sprite original
func _on_original_frame_changed() -> void:
	if original_sprite:
		# Sincronizar frame y verificar si cambió SpriteFrames
		if original_sprite.sprite_frames != sprite_frames:
			sprite_frames = original_sprite.sprite_frames
		frame = original_sprite.frame

	# La visibilidad se controla desde ReflectionEffectHandler
	# Este sprite solo se encarga de la sincronización visual con el sprite original
