extends Panel

class_name EvolutionUI

const ENTER_FADE_SECONDS: float = 0.6
const PARTIAL_WIPE_SECONDS: float = 0.75
const PARTIAL_WIPE_PROGRESS: float = 0.5
const PARTIAL_WIPE_TEXTURE := "res://Sprites/Transiciones/wipe-vertical-reflected.png"
const WHITE_SHADER := preload("res://Shaders/evolution_white.gdshader")
const FINAL_FLASH_IN_SECONDS: float = 0.38
const FINAL_FLASH_OUT_SECONDS: float = 0.85
const EXIT_FADE_TO_BLACK_SECONDS: float = 1.0
const CANCEL_PRESS_THRESHOLD: int = 4
const SWAP_COUNT: int = 18
const CYCLE_SECONDS_START: float = 0.70
const CYCLE_SECONDS_END: float = 0.18
const SHRINK_SCALE_START: float = 0.78
const SHRINK_SCALE_END: float = 0.56

@onready var pokemon_sprite: Sprite2D = $PokemonSprite
var _base_scale_origin: Vector2 = Vector2.ONE
var _base_scale_target: Vector2 = Vector2.ONE
var _cancel_press_count: int = 0
var _cancel_requested: bool = false
var _can_cancel_current_evolution: bool = true
var _mask_active: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_ensure_white_material()


## Secuencia bloqueante: mensajes + animación. Retorna { "cancelled": bool }.
func play_evolution_sequence(pokemon: Pokemon, target_data: PokemonData, can_cancel: bool = true) -> Dictionary:
	_reset_cancel_state(can_cancel)

	# Sprite del Pokémon antes de mostrar/fundir (evita un frame con textura por defecto de la escena).
	pokemon_sprite.scale = Vector2.ONE
	pokemon_sprite.modulate = Color.WHITE
	_set_sprite_from_pokemon(pokemon)

	var name_a: String = pokemon.get_display_name()

	visible = true
	modulate.a = 0.0
	var fade_in := create_tween()
	fade_in.tween_property(self, "modulate:a", 1.0, ENTER_FADE_SECONDS)
	await fade_in.finished
	await get_tree().process_frame

	await DisplayManager.show_message("¡Anda!", {
		"typingMode": MessageBox.TypingMode.TYPING,
	})
	await DisplayManager.show_message("¡%s está evolucionando!" % name_a, {
		"typingMode": MessageBox.TypingMode.TYPING,
	})
	var dm := DisplayManager.instance
	if dm != null and dm.fade_layer != null:
		await dm.fade_layer.hold_mask_transition(PARTIAL_WIPE_TEXTURE, PARTIAL_WIPE_PROGRESS, PARTIAL_WIPE_SECONDS)
		_mask_active = true

	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_SINE)
	tw.tween_property(pokemon_sprite, "scale", Vector2.ONE, 0.35)
	tw.tween_property(pokemon_sprite, "modulate", Color.WHITE, 0.35)
	tw.tween_method(_set_white_amount, 0.0, 1.0, 0.35)
	if await _await_tween_cancelable(tw):
		await _finish_cancelled_evolution(dm, name_a, pokemon.get_battle_front_sprite())
		return {"cancelled": true}
	await _wait_seconds_cancelable(0.15)

	# Cancelación habilitada solo durante la alternancia de sprites (fase clásica cancelable).
	_can_cancel_current_evolution = can_cancel

	if await _play_accelerating_sprite_swaps(pokemon.get_battle_front_sprite(), target_data.battle_front_sprite):
		await _finish_cancelled_evolution(dm, name_a, pokemon.get_battle_front_sprite())
		return {"cancelled": true}

	# A partir del flash final ya no se permite cancelar.
	_can_cancel_current_evolution = false
	await _play_final_white_flash_and_recover(PARTIAL_WIPE_PROGRESS, PARTIAL_WIPE_SECONDS)
	# Dar un frame para que MessageBox/FadeLayer queden en estado estable antes del mensaje final.
	await get_tree().process_frame
	pokemon_sprite.scale = Vector2.ONE
	pokemon_sprite.modulate = Color.WHITE

	await DisplayManager.show_message(
		"¡Enhorabuena! ¡Tu %s ha evolucionado a %s!" % [name_a, target_data.Name],
		{
			"typingMode": MessageBox.TypingMode.TYPING,
			"waitInput": false,
			"waitTime": 4.0,
			"closeAtEnd": false,
			"showIconAtEnd": false,
		},
	)
	if dm != null and dm.fade_layer != null:
		# Cierre de evolución: fundido a negro por encima del MessageBox.
		var prev_fade_z: int = dm.fade_layer.z_index
		dm.fade_layer.z_index = 300
		await dm.fade_layer.fade_in(EXIT_FADE_TO_BLACK_SECONDS)
		dm.fade_layer.z_index = prev_fade_z
		DisplayManager.close_message()
	visible = false
	modulate.a = 1.0
	return {"cancelled": false}


func _set_sprite_from_pokemon(pokemon: Pokemon) -> void:
	var t: Texture2D = pokemon.get_battle_front_sprite()
	if t != null:
		pokemon_sprite.texture = t


func _ensure_white_material() -> void:
	if pokemon_sprite == null:
		return
	var mat := pokemon_sprite.material as ShaderMaterial
	if mat == null or mat.shader == null or mat.shader.resource_path != WHITE_SHADER.resource_path:
		var shader_mat := ShaderMaterial.new()
		shader_mat.shader = WHITE_SHADER
		pokemon_sprite.material = shader_mat
	_set_white_amount(0.0)


func _set_white_amount(v: float) -> void:
	var mat := pokemon_sprite.material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("white_mix", clampf(v, 0.0, 1.0))


func _play_final_white_flash_and_recover(mask_progress: float, mask_release_seconds: float) -> void:
	# El sprite llega totalmente blanco al final de ciclos.
	_set_white_amount(1.0)

	var dm := DisplayManager.instance
	if dm != null and dm.fade_layer != null:
		# Flash de pantalla completa con FadeLayer.
		# El sprite empieza a recuperar color justo cuando termina la subida del flash (inicio de la bajada).
		var recover := create_tween()
		recover.tween_interval(FINAL_FLASH_IN_SECONDS)
		recover.tween_method(_set_white_amount, 1.0, 0.0, FINAL_FLASH_OUT_SECONDS)
		await dm.fade_layer.flash_white_and_release_mask(
			mask_progress,
			FINAL_FLASH_IN_SECONDS,
			FINAL_FLASH_OUT_SECONDS,
			mask_release_seconds
		)
		_mask_active = false
		while recover.is_running():
			await get_tree().process_frame
	else:
		var recover_fallback := create_tween()
		recover_fallback.tween_method(_set_white_amount, 1.0, 0.0, FINAL_FLASH_OUT_SECONDS)
		await recover_fallback.finished


func _play_accelerating_sprite_swaps(origin_tex: Texture2D, target_tex: Texture2D) -> bool:
	if origin_tex == null or target_tex == null:
		if target_tex != null:
			pokemon_sprite.texture = target_tex
		return false

	_compute_base_scales(origin_tex, target_tex)
	pokemon_sprite.texture = origin_tex
	pokemon_sprite.scale = _base_scale_origin
	var showing_target := false

	for i in range(SWAP_COUNT):
		var t := float(i) / float(maxi(SWAP_COUNT - 1, 1))
		var eased := t * t
		var cycle_seconds := lerpf(CYCLE_SECONDS_START, CYCLE_SECONDS_END, eased)
		var shrink_scale := lerpf(SHRINK_SCALE_START, SHRINK_SCALE_END, eased)
		var cycle_base_scale: Vector2 = _base_scale_target if showing_target else _base_scale_origin

		# 1) Encoger
		var tw_shrink := create_tween()
		tw_shrink.tween_property(pokemon_sprite, "scale", cycle_base_scale * shrink_scale, cycle_seconds * 0.5)
		if await _await_tween_cancelable(tw_shrink):
			return true

		# 2) Swap justo en el punto de tamaño mínimo
		showing_target = not showing_target
		pokemon_sprite.texture = target_tex if showing_target else origin_tex
		cycle_base_scale = _base_scale_target if showing_target else _base_scale_origin

		# 3) Volver progresivamente a tamaño original
		var tw_grow := create_tween()
		tw_grow.tween_property(pokemon_sprite, "scale", cycle_base_scale, cycle_seconds * 0.5)
		if await _await_tween_cancelable(tw_grow):
			return true

	# Garantizar estado final en la evolución.
	pokemon_sprite.texture = target_tex
	pokemon_sprite.scale = _base_scale_target
	return false


func _compute_base_scales(origin_tex: Texture2D, target_tex: Texture2D) -> void:
	var min_h: float = 1.0
	var origin_h: float = _texture_height(origin_tex)
	var target_h: float = _texture_height(target_tex)
	origin_h = max(origin_h, min_h)
	target_h = max(target_h, min_h)
	var max_h: float = max(origin_h, target_h)
	_base_scale_origin = Vector2.ONE * (max_h / origin_h)
	_base_scale_target = Vector2.ONE * (max_h / target_h)


func _texture_height(tex: Texture2D) -> float:
	if tex == null:
		return 1.0
	var s := tex.get_size()
	return max(float(s.y), 1.0)


func _reset_cancel_state(can_cancel: bool) -> void:
	_cancel_press_count = 0
	_cancel_requested = false
	_can_cancel_current_evolution = can_cancel
	_mask_active = false


func _poll_cancel_input() -> void:
	if not _can_cancel_current_evolution or _cancel_requested:
		return
	if Input.is_action_just_pressed("ui_cancel"):
		_cancel_press_count += 1
		if _cancel_press_count >= CANCEL_PRESS_THRESHOLD:
			_cancel_requested = true


func _await_tween_cancelable(tween: Tween) -> bool:
	while tween != null and tween.is_running():
		_poll_cancel_input()
		if _cancel_requested:
			tween.kill()
			return true
		await get_tree().process_frame
	return _cancel_requested


func _wait_seconds_cancelable(seconds: float) -> bool:
	var end_ts: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end_ts:
		_poll_cancel_input()
		if _cancel_requested:
			return true
		await get_tree().process_frame
	return _cancel_requested


func _finish_cancelled_evolution(dm: DisplayManager, pokemon_name: String, origin_tex: Texture2D) -> void:
	_can_cancel_current_evolution = false
	if origin_tex != null:
		pokemon_sprite.texture = origin_tex
	# Recuperación visual previa al mensaje: volver a tamaño base y color original progresivamente.
	var recover_vis := create_tween().set_parallel(true)
	recover_vis.tween_property(pokemon_sprite, "scale", Vector2.ONE, 0.28)
	recover_vis.tween_method(_set_white_amount, 1.0, 0.0, 0.32)
	await recover_vis.finished
	pokemon_sprite.scale = Vector2.ONE
	pokemon_sprite.modulate = Color.WHITE

	if dm != null and dm.fade_layer != null and _mask_active:
		await dm.fade_layer.release_mask_transition(PARTIAL_WIPE_PROGRESS, PARTIAL_WIPE_SECONDS)
		_mask_active = false
	await DisplayManager.show_message("¿Eh? ¡La evolución de %s se ha detenido!" % pokemon_name, {
		"typingMode": MessageBox.TypingMode.TYPING,
	})
	if dm != null and dm.fade_layer != null:
		var prev_fade_z: int = dm.fade_layer.z_index
		dm.fade_layer.z_index = 300
		await dm.fade_layer.fade_in(EXIT_FADE_TO_BLACK_SECONDS)
		dm.fade_layer.z_index = prev_fade_z
		DisplayManager.close_message()
	visible = false
	modulate.a = 1.0
