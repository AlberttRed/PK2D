extends Control
class_name MOOverlay

const DEFAULT_ANIMATION := "show_MO_overlay"
## Centro horizontal típico del overlay (viewport 512).
const POKEMON_CENTER_X := 256.0
const CENTER_X_EPSILON := 4.0

@onready var curtain: TextureRect = $Curtain
@onready var pokemon_sprite: Sprite2D = $PokemonSprite
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var _current_animation: StringName = DEFAULT_ANIMATION
var _is_playing := false

# Señales para notificar cuando empieza/termina la animación MO
signal mo_animation_started
signal mo_animation_finished

func play(pokemon_visual: Variant = null, pokemon: Pokemon = null) -> void:
	if _is_playing:
		animation_player.stop()

	_is_playing = true
	mo_animation_started.emit()
	_prepare_nodes()
	_apply_pokemon_visual(pokemon_visual)

	animation_player.play(_current_animation)
	if pokemon != null:
		_play_cry_when_sprite_centered(pokemon)
	await animation_player.animation_finished

	_is_playing = false
	mo_animation_finished.emit()


## Reproduce el grito cuando el sprite se detiene en el centro (Gen 3).
func _play_cry_when_sprite_centered(pokemon: Pokemon) -> void:
	var delay := _resolve_center_hold_time()
	if delay < 0.0:
		# Fallback: esperar a que la X del sprite se estabilice cerca del centro.
		await _await_sprite_near_center()
	else:
		if delay > 0.0:
			await get_tree().create_timer(delay).timeout
	if not _is_playing or pokemon == null:
		return
	pokemon.play_cry()


func _resolve_center_hold_time() -> float:
	if animation_player == null:
		return -1.0
	var anim := animation_player.get_animation(_current_animation)
	if anim == null:
		return -1.0

	for track_idx in anim.get_track_count():
		if anim.track_get_type(track_idx) != Animation.TYPE_VALUE:
			continue
		var path := str(anim.track_get_path(track_idx))
		if path.find("PokemonSprite") < 0:
			continue
		if path.find("position") < 0:
			continue

		var key_count := anim.track_get_key_count(track_idx)
		for key_idx in key_count:
			var value: Variant = anim.track_get_key_value(track_idx, key_idx)
			var x := _extract_position_x(value, path)
			if x < 0.0:
				continue
			if absf(x - POKEMON_CENTER_X) <= CENTER_X_EPSILON:
				return float(anim.track_get_key_time(track_idx, key_idx))
	return -1.0


func _extract_position_x(value: Variant, path: String) -> float:
	if value is Vector2:
		return (value as Vector2).x
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		if path.find(":position:x") >= 0:
			return float(value)
	return -1.0


func _await_sprite_near_center() -> void:
	if pokemon_sprite == null:
		return
	var frames_near_center := 0
	while _is_playing and is_instance_valid(pokemon_sprite):
		if absf(pokemon_sprite.position.x - POKEMON_CENTER_X) <= CENTER_X_EPSILON:
			frames_near_center += 1
			# Un par de frames quietos cerca del centro ≈ "se detuvo".
			if frames_near_center >= 2:
				return
		else:
			frames_near_center = 0
		await get_tree().process_frame

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
