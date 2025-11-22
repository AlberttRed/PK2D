extends AnimatedSprite2D
class_name ReflectionSprite

## Sprite de reflejo que se muestra cuando el actor está sobre agua
## Se sincroniza automáticamente con el sprite original del actor

## Referencia al sprite original del actor
var original_sprite: AnimatedSprite2D = null

## Referencia al grid para obtener la máscara
var grid: OverworldGrid = null

func _ready() -> void:
	# Configurar propiedades del reflejo
	flip_v = true  # Invertir verticalmente
	z_index = -1  # Debajo del mundo
	visible = false  # Oculto por defecto
	position.y = 32
	# Buscar el sprite original del actor padre
	_find_original_sprite()

	# Conectar señales del sprite original
	_connect_to_original_sprite()

	# Sincronizar inicialmente
	if original_sprite:
		_sync_with_original()

func _process(_delta: float) -> void:
	# Verificar continuamente si el tile inferior es agua
	_check_bottom_tile_water()

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

## Obtiene el grid del actor
func _get_actor_grid(actor: Node2D) -> OverworldGrid:
	if not actor:
		return null

	# Para Player: usar grid activo
	if actor.is_in_group("Player"):
		var context := actor.get("context") as OverworldContext
		if context:
			var world_system := context.get_world_system()
			if world_system:
				return world_system.get_active_grid()

	# Para Events: usar home_grid
	if actor is Event:
		var occupancy := actor.get_node_or_null("Occupancy")
		if occupancy and occupancy.home_grid:
			return occupancy.home_grid

	return null

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

## Verifica si el tile inferior es agua y muestra/oculta el reflejo
func _check_bottom_tile_water() -> void:
	var actor := get_parent() as Node2D
	if not actor:
		return

	# Obtener grid del actor
	if not grid:
		grid = _get_actor_grid(actor)
		if not grid:
			return

	# Obtener tile actual del actor
	var world_pos: Vector2 = actor.global_position
	var current_tile: Vector2i = grid.world_to_tile(world_pos)

	# El tile inferior es el tile debajo (Y+1)
	var bottom_tile := current_tile + Vector2i(0, 1)
	var bottom_tile_info := grid.get_tile_info(bottom_tile)
	var is_water: bool = (bottom_tile_info.terrain == "water")

	# Mostrar/ocultar reflejo según si el tile inferior es agua
	visible = is_water
