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

## Estilo actual aplicado al animator
var current_style: ActorStyle = null

var _current_mode: String = "walk"
var _mode_frames: Dictionary[String, SpriteFrames] = {}
var _frames_mode_lookup: Dictionary[int, String] = {}
var _extra_animation_frames: Dictionary[String, SpriteFrames] = {}
var _restore_after_temp: bool = false
var _previous_frames_before_temp: SpriteFrames = null
var _restore_mode_after_temp: String = "walk"
var _last_animation_name: String = ""

func _ready() -> void:
	if sprite:
		# Configurar process_mode para que las animaciones funcionen aunque el árbol esté pausado
		# Esto es crítico para animaciones de eventos (puertas, cofres, etc.) durante transiciones
		sprite.process_mode = Node.PROCESS_MODE_ALWAYS
		if not sprite.animation_finished.is_connected(_on_animation_finished_internal):
			sprite.animation_finished.connect(_on_animation_finished_internal)

## Reproduce una animación por nombre
## @param anim_name: Nombre de la animación a reproducir
func play(anim_name: String) -> void:
	if not sprite:
		return

	_ensure_frames_for_animation(anim_name)

	if not sprite.sprite_frames:
		return

	if sprite.sprite_frames.has_animation(anim_name):
		if sprite.is_playing():
			sprite.stop()
		sprite.play(anim_name)
		_last_animation_name = anim_name
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

	_prepare_mode_for_prefix(prefix)
	current_direction = dir
	var dir_name := _get_direction_name(dir)
	var anim_name := "%s_%s" % [dir_name, stride]

	play(anim_name)

## Reproduce la animación idle en la dirección actual
## @param dir: Dirección opcional (si no se proporciona, usa current_direction)
func idle(dir: Vector2 = Vector2.ZERO) -> void:
	if dir != Vector2.ZERO:
		current_direction = dir

	if current_style:
		_prepare_mode_for_prefix(_current_mode)

	if not sprite or not sprite.sprite_frames:
		return

	# Verificar si existe la animación "idle", si no, usar "default" como fallback
	var anim_to_use = "idle"
	if not sprite.sprite_frames.has_animation("idle"):
		# Si no hay "idle", intentar usar "default"
		if sprite.sprite_frames.has_animation("default"):
			anim_to_use = "default"
		else:
			# Si no hay ninguna animación válida, obtener la primera disponible
			var anim_names = sprite.sprite_frames.get_animation_names()
			if anim_names.size() > 0:
				anim_to_use = anim_names[0]
			else:
				# No hay animaciones disponibles, salir
				return

	sprite.animation = anim_to_use
	sprite.stop()
	_last_animation_name = anim_to_use

	# Establecer el frame correcto según la dirección (solo si es "idle" o tiene suficientes frames)
	# Si es "default" u otra animación, usar el frame 0
	if anim_to_use == "idle":
		match current_direction:
			Vector2.UP: sprite.frame = 3
			Vector2.DOWN: sprite.frame = 0
			Vector2.LEFT: sprite.frame = 1
			Vector2.RIGHT: sprite.frame = 2
	else:
		# Para otras animaciones, usar el frame 0
		var frame_count = sprite.sprite_frames.get_frame_count(anim_to_use)
		if frame_count > 0:
			sprite.frame = 0

## Detiene la animación actual
func stop() -> void:
	if sprite:
		sprite.stop()
		_last_animation_name = sprite.animation

## Establece el speed_scale del sprite
## @param scale: Multiplicador de velocidad (1.0 = normal, 2.0 = doble velocidad)
func set_speed_scale(scale_value: float) -> void:
	if sprite:
		sprite.speed_scale = scale_value

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
	_clear_style_state()
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

## Obtiene el offset actual del sprite
## @return: Vector2 con el offset actual, o Vector2.ZERO si no hay sprite
func get_sprite_offset() -> Vector2:
	if sprite:
		return sprite.offset
	return Vector2.ZERO

func play_mo_sequence() -> void:
	await _play_mo_animation("mo_start")
	await _play_mo_animation("mo_end")

## Aplica un ActorStyle con conjuntos de animaciones predefinidos
func apply_style(style: ActorStyle) -> void:
	if style == null:
		_clear_style_state()
		return

	current_style = style
	_register_style_frames(style)

	var previous_animation: String = ""
	var was_playing: bool = false
	if sprite:
		previous_animation = sprite.animation
		was_playing = sprite.is_playing()

	_prepare_mode_for_prefix(_current_mode)

	if not sprite:
		return

	_restore_animation(previous_animation, was_playing)

## Convierte un Vector2 de dirección a string
func _get_direction_name(dir: Vector2) -> String:
	match dir:
		Vector2.UP: return "up"
		Vector2.DOWN: return "down"
		Vector2.LEFT: return "left"
		Vector2.RIGHT: return "right"
		_: return "down"

func _prepare_mode_for_prefix(prefix: String) -> void:
	if not current_style:
		return
	_use_mode(prefix)

func _use_mode(mode: String) -> void:
	if not current_style or not sprite:
		return

	var normalized := _normalize_mode_name(mode)
	var frames := _get_frames_for_mode(normalized)

	if frames == null:
		frames = _get_default_style_frames()
		if frames:
			var frames_id = frames.get_instance_id()
			normalized = _frames_mode_lookup.get(frames_id, "walk")

	if frames and sprite.sprite_frames != frames:
		sprite.sprite_frames = frames

	if frames:
		_current_mode = normalized
		_restore_after_temp = false
		_previous_frames_before_temp = null

func _ensure_frames_for_animation(anim_name: String) -> void:
	if not current_style or not sprite:
		return

	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		return

	var frames := _find_frames_with_animation(anim_name)
	if frames:
		var frames_id = frames.get_instance_id()
		if _frames_mode_lookup.has(frames_id):
			_use_mode(_frames_mode_lookup[frames_id])
		else:
			_previous_frames_before_temp = sprite.sprite_frames
			_restore_mode_after_temp = _current_mode
			_restore_after_temp = true
			sprite.sprite_frames = frames

func _find_frames_with_animation(anim_name: String) -> SpriteFrames:
	for mode in _mode_frames.keys():
		var frames: SpriteFrames = _mode_frames[mode]
		if frames and frames.has_animation(anim_name):
			return frames

	for frames in _extra_animation_frames.values():
		if frames and frames.has_animation(anim_name):
			return frames

	return null

func _register_style_frames(style: ActorStyle) -> void:
	_mode_frames.clear()
	_frames_mode_lookup.clear()
	_extra_animation_frames = style.extra_animations.duplicate() as Dictionary[String, SpriteFrames]

	_store_mode_frame("walk", style.walk_frames)
	_store_mode_frame("run", style.run_frames)
	_store_mode_frame("surf", style.surf_frames)
	_store_mode_frame("mo_start", style.mo_start_frames)
	_store_mode_frame("mo_end", style.mo_end_frames)
	_store_mode_frame("bike", style.bike_frames)

func _store_mode_frame(mode: String, frames: SpriteFrames) -> void:
	if not frames:
		return
	_mode_frames[mode] = frames
	_frames_mode_lookup[frames.get_instance_id()] = mode

func _get_frames_for_mode(mode: String) -> SpriteFrames:
	if _mode_frames.has(mode):
		return _mode_frames[mode]
	return null

func _get_default_style_frames() -> SpriteFrames:
	var order = ["walk", "run", "surf", "bike", "mo_start", "mo_end"]
	for mode in order:
		if _mode_frames.has(mode) and _mode_frames[mode]:
			return _mode_frames[mode]
	return null

func _normalize_mode_name(mode: String) -> String:
	var lowered = mode.to_lower()
	match lowered:
		"walk", "run", "surf", "bike", "mo_start", "mo_end":
			return lowered
		_:
			return "walk"

func _clear_style_state() -> void:
	current_style = null
	_mode_frames.clear()
	_frames_mode_lookup.clear()
	_extra_animation_frames.clear()
	_current_mode = "walk"
	_restore_after_temp = false
	_previous_frames_before_temp = null

func _on_animation_finished_internal() -> void:
	if _restore_after_temp and sprite:
		_restore_after_temp = false
		if _previous_frames_before_temp:
			sprite.sprite_frames = _previous_frames_before_temp
		_prepare_mode_for_prefix(_restore_mode_after_temp)

func _play_mo_animation(mode: String) -> void:
	if not current_style or not sprite:
		return

	var frames := _get_frames_for_mode(mode)
	if not frames:
		return

	var previous_mode := _current_mode
	var previous_animation := sprite.animation
	var was_playing := sprite.is_playing()

	_use_mode(mode)

	if not sprite.sprite_frames:
		_use_mode(previous_mode)
		return

	var anim_name := sprite.animation
	if anim_name.is_empty() or not sprite.sprite_frames.has_animation(anim_name):
		anim_name = "default"

	if not sprite.sprite_frames.has_animation(anim_name):
		_use_mode(previous_mode)
		return

	sprite.play(anim_name)
	await sprite.animation_finished
	_use_mode(previous_mode)
	_restore_animation(previous_animation, was_playing)

func _restore_animation(previous_animation: String, was_playing: bool) -> void:
	if previous_animation == "idle" or previous_animation.is_empty():
		idle(current_direction)
		return

	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(previous_animation):
		if was_playing:
			play(previous_animation)
		else:
			sprite.animation = previous_animation
			_last_animation_name = previous_animation
			sprite.stop()
	else:
		idle(current_direction)
