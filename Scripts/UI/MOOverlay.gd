extends Control
class_name MOOverlay

const DEFAULT_ANIMATION := "show_MO_overlay"

@onready var curtain: TextureRect = $Curtain
@onready var pokemon_sprite: Sprite2D = $PokemonSprite
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var _current_animation: StringName = DEFAULT_ANIMATION
var _is_playing := false

# Señales para notificar cuando empieza/termina la animación MO
signal mo_animation_started
signal mo_animation_finished

func play(pokemon_visual: Variant = null) -> void:
	if _is_playing:
		animation_player.stop()

	_is_playing = true
	mo_animation_started.emit()
	_prepare_nodes()
	_apply_pokemon_visual(pokemon_visual)

	animation_player.play(_current_animation)
	await animation_player.animation_finished

	_is_playing = false
	mo_animation_finished.emit()

func _prepare_nodes() -> void:
	if curtain:
		curtain.modulate = Color.WHITE
	if pokemon_sprite:
		pokemon_sprite.position = Vector2(640, 192)
		pokemon_sprite.visible = true
		pokemon_sprite.modulate = Color.WHITE

func _apply_pokemon_visual(pokemon_visual: Variant) -> void:
	if pokemon_visual is Texture2D:
		_set_texture(pokemon_visual)
	else:
		_hide_pokemon_visuals()

func _set_texture(texture: Texture2D) -> void:
	if not pokemon_sprite:
		return
	pokemon_sprite.texture = texture
	pokemon_sprite.visible = texture != null
	if texture != null:
		pokemon_sprite.modulate = Color.WHITE

func _hide_pokemon_visuals() -> void:
	if pokemon_sprite:
		pokemon_sprite.visible = false
