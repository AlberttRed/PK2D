extends Node2D

@onready var motion = $GridMotion
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var battler: Battler = $Battler

#const DEFAULT_WALK_FRAMES: SpriteFrames = preload("res://Resources/Animations/Overworld/Player_Walk.tres")
#const DEFAULT_SURF_FRAMES: SpriteFrames = preload("res://Resources/Animations/Overworld/Player_Surf.tres")

@export var actor_style: ActorStyle
# Referencia al OverworldContext (opcional, para acceso a sistemas)
var context: OverworldContext = null

var input_dir := Vector2.ZERO
var holding := false
var movement_enabled: bool = true
var is_surfing: bool = false  # Modo surfing activado
var _control_block_count: int = 0  # Contador de bloqueos anidados
var _is_playing_mo_segment: bool = false
var _mo_sequence_active: bool = false
var _mo_idle_direction: Vector2 = Vector2.DOWN

func _ready() -> void:
	if !is_in_group("Player"):
		add_to_group("Player")
	motion.step_started.connect(_on_step_started)
	motion.step_finished.connect(_on_step_finished)
	$Shadow.visible = false

	_refresh_actor_style_frames()
	sprite.animation = "down_right"
	call_deferred("_connect_display_manager_signals")

func _process(_delta: float):
	if not movement_enabled:
		return

	input_dir = Vector2.ZERO
	if Input.is_action_pressed("move_up"):
		input_dir = Vector2.UP
	elif Input.is_action_pressed("move_down"):
		input_dir = Vector2.DOWN
	elif Input.is_action_pressed("move_left"):
		input_dir = Vector2.LEFT
	elif Input.is_action_pressed("move_right"):
		input_dir = Vector2.RIGHT

	# Actualizar flag de correr en GridMotion (solo si no está siendo controlado por comando)
	if not motion.is_command_controlled:
		motion.is_running = Input.is_action_pressed("run")

	if input_dir != Vector2.ZERO:
		motion.hold_time += _delta
	else:
		motion.hold_time = 0.0

	#If one direction has been pressed and is not doing move animation, try move to next tile
	if input_dir != Vector2.ZERO and not motion.moving:
		motion.try_step(input_dir)

func _on_step_started() -> void:
	var use_run: bool = (motion.speed_multiplier > 1.0 and not motion.initial_step)
	_apply_ground_frames_for_motion(use_run)
	var dir_name := "down"
	match motion.dir:
		Vector2.UP: dir_name = "up"
		Vector2.DOWN: dir_name = "down"
		Vector2.LEFT: dir_name = "left"
		Vector2.RIGHT: dir_name = "right"

	# Animaciones con zancada: <dir>_<left|right>
	var stride := ("left" if motion.stride_is_left else "right")
	var anim_to_play := dir_name + "_" + stride
	if sprite.is_playing():
		sprite.stop()
	sprite.play(anim_to_play)

	sprite.speed_scale = motion.speed_multiplier#1.0 / motion.get_step_duration()   # usa el FPS que pusiste en el editor

func _on_step_finished(tile: Vector2i) -> void:
	# Si está en modo surfing, verificar si llegó a tierra
	if is_surfing:
		if context:
			var map_system: MapSystem = context.get_map_system()
			if map_system:
				var grid: OverworldGrid = map_system.get_active_grid()
				if grid:
					var terrain = grid.terrain_at(tile)
					if terrain != "water":
						# Llegó a tierra, desactivar surfing
						set_surfing_mode(false)

	if not Input.is_action_pressed("move_up") \
	and not Input.is_action_pressed("move_down") \
	and not Input.is_action_pressed("move_left") \
	and not Input.is_action_pressed("move_right"):
		stop()

func stop():
	if _mo_sequence_active:
		return
	# Resetear velocidad de animación a normal
	sprite.speed_scale = 1.0

	if is_surfing:
		# En modo surfing, usar animaciones idle direccionales
		match motion.dir:
			Vector2.UP: sprite.animation = "idle_up"
			Vector2.DOWN: sprite.animation = "idle_down"
			Vector2.LEFT: sprite.animation = "idle_left"
			Vector2.RIGHT: sprite.animation = "idle_right"
		sprite.play()
	else:
		# Modo normal: idle con frames direccionales
		sprite.animation = "idle"
		sprite.stop()
		match motion.dir:
			Vector2.UP: sprite.frame = 3
			Vector2.DOWN: sprite.frame = 0
			Vector2.LEFT: sprite.frame = 1
			Vector2.RIGHT: sprite.frame = 2

func _unhandled_input(event: InputEvent) -> void:
	if not movement_enabled:
		return

	if event.is_action_pressed("interact") and not motion.moving:
		# Primero verificar si hay agua frente al jugador (para SURF)
		if _try_activate_surf():
			return  # Ya procesado, no continuar

		# Si no hay agua, procesar interacción normal con eventos
		var e: Event = motion.event_in_front()
		if e:
			e.on_player_action()

## --- Control de Movimiento ---
func set_movement_enabled(enabled: bool) -> void:
	movement_enabled = enabled
	if not enabled:
		# Detener movimiento actual si está en curso
		if motion.moving:
			motion.moving = false
		stop()

##Teletransporta al jugador a la posición especificada
func teleport_to_tile(tile: Vector2i) -> void:
	if not context:
		push_error("Player: Contexto no disponible para teleport")
		return

	var map_system: MapSystem = context.get_map_system()
	if not map_system:
		push_error("Player: MapSystem no disponible en el contexto")
		return

	var grid: OverworldGrid = map_system.get_active_grid()
	if not grid:
		push_error("Player: No se pudo obtener el OverworldGrid del MapSystem")
		return

	# Usar el método de Occupancy si está disponible
	if has_node("Occupancy"):
		$Occupancy.teleport_to_tile(tile)
	else:
		# Fallback: teletransporte directo
		global_position = grid.tile_to_world_center(tile)

## --- Señales del SignalManager ---
## Maneja el bloqueo del control del jugador
func _on_player_control_blocked() -> void:
	set_movement_enabled(false)

## Maneja el desbloqueo del control del jugador
func _on_player_control_unblocked() -> void:
	set_movement_enabled(true)

func set_facing_direction(new_direction:Vector2):
	motion.dir = new_direction
	stop()

## --- SURF System ---
## Intenta activar SURF si el jugador mira hacia agua
func _try_activate_surf() -> bool:
	if is_surfing:
		return false  # Ya está en modo surfing

	# Obtener el grid del contexto
	if not context:
		return false

	var map_system: MapSystem = context.get_map_system()
	if not map_system:
		return false

	var grid: OverworldGrid = map_system.get_active_grid()
	if not grid:
		return false

	# Calcular tile frente al jugador
	var current_tile = grid.world_to_tile(global_position)
	var target_tile = current_tile + Vector2i(motion.dir)

	# Verificar si el tile frente es agua
	var terrain = grid.terrain_at(target_tile)
	if terrain != "water":
		return false

	# Es agua - solicitar la MO de SURF a través del contexto
	call_deferred("_request_surf_mo")
	return true

func _request_surf_mo() -> void:
	if not context:
		return
	await context.request_mo("SURF", null)

## Activa o desactiva el modo surfing
func set_surfing_mode(enabled: bool) -> void:
	if is_surfing == enabled:
		return  # Ya está en ese modo

	is_surfing = enabled

	if enabled:
		# Cambiar a sprite de surfing
		var surf_frames = _get_surf_frames()
		if surf_frames:
			sprite.sprite_frames = surf_frames
		# Convertir animación idle a idle direccional según la dirección actual
		match motion.dir:
			Vector2.UP: sprite.animation = "idle_up"
			Vector2.DOWN: sprite.animation = "idle_down"
			Vector2.LEFT: sprite.animation = "idle_left"
			Vector2.RIGHT: sprite.animation = "idle_right"
		sprite.play()
		set_meta("can_surf", true)
	else:
		# Volver al sprite normal
		_refresh_actor_style_frames()
		# En modo normal, usar idle estático
		sprite.animation = "idle"
		sprite.stop()
		match motion.dir:
			Vector2.UP: sprite.frame = 3
			Vector2.DOWN: sprite.frame = 0
			Vector2.LEFT: sprite.frame = 1
			Vector2.RIGHT: sprite.frame = 2
		remove_meta("can_surf")

## Verifica si el jugador puede moverse al tile destino en modo surfing
## Se llama desde GridMotion antes de validar movimiento
func can_surf_to_tile(_tile: Vector2i) -> bool:
	if not is_surfing:
		return true  # No está en surfing, movimiento normal

	# En modo surfing, SIEMPRE permitir el movimiento
	# Si es a tierra, el surf se desactivará automáticamente en _on_step_finished()
	return true

## ============================================================================
## API DE CONTROL DIRECTO (método preferido sobre SignalManager)
## ============================================================================

## Bloquea los controles del jugador (método directo preferido)
## Usa un contador para permitir bloqueos anidados
func block_controls() -> void:
	_control_block_count += 1
	movement_enabled = false
	# print("Player: Controles bloqueados (count: %d)" % _control_block_count)

## Desbloquea los controles del jugador (método directo preferido)
## Solo desbloquea realmente cuando el contador llega a 0
func unblock_controls() -> void:
	_control_block_count = max(0, _control_block_count - 1)
	if _control_block_count == 0:
		movement_enabled = true
		# print("Player: Controles desbloqueados")

## Fuerza el desbloqueo inmediato (resetea el contador)
func force_unblock_controls() -> void:
	_control_block_count = 0
	movement_enabled = true
	print("Player: Controles forzosamente desbloqueados")

## Verifica si los controles están bloqueados
func are_controls_blocked() -> bool:
	return not movement_enabled

## Establece el contexto del Overworld (llamado desde MapSystem)
func set_context(overworld_context: OverworldContext) -> void:
	context = overworld_context
	print("Player: Contexto del Overworld establecido")

	if context:
		if not context.player_control_blocked.is_connected(_on_player_control_blocked):
			context.player_control_blocked.connect(_on_player_control_blocked)
		if not context.player_control_unblocked.is_connected(_on_player_control_unblocked):
			context.player_control_unblocked.connect(_on_player_control_unblocked)

	# Propagar el contexto a los componentes hijos
	if motion and motion.has_method("set_context"):
		motion.set_context(context)

	# Propagar a Occupancy si existe
	var occupancy = get_node_or_null("Occupancy")
	if occupancy and occupancy.has_method("set_context"):
		occupancy.set_context(context)

	# Propagar a WildEncounterDetector si existe
	var encounter_detector = get_node_or_null("WildEncounterDetector")
	if encounter_detector and encounter_detector.has_method("set_context"):
		encounter_detector.set_context(context)
		encounter_detector.player = self

func _connect_display_manager_signals() -> void:
	var dm := DisplayManager.instance
	if not dm:
		call_deferred("_connect_display_manager_signals")
		return

	if not dm.player_control_blocked.is_connected(_on_player_control_blocked):
		dm.player_control_blocked.connect(_on_player_control_blocked)
	if not dm.player_control_unblocked.is_connected(_on_player_control_unblocked):
		dm.player_control_unblocked.connect(_on_player_control_unblocked)

func apply_actor_style(style: ActorStyle) -> void:
	actor_style = style
	_refresh_actor_style_frames()

func _refresh_actor_style_frames() -> void:
	if _mo_sequence_active:
		return
	if is_surfing:
		sprite.sprite_frames = _get_surf_frames()
	else:
		_apply_ground_frames_for_motion(_should_use_run_frames())

func _get_walk_frames() -> SpriteFrames:
	if actor_style and actor_style.walk_frames:
		return actor_style.walk_frames
	return null#DEFAULT_WALK_FRAMES

func _get_surf_frames() -> SpriteFrames:
	if actor_style and actor_style.surf_frames:
		return actor_style.surf_frames
	return null#DEFAULT_SURF_FRAMES

func _get_run_frames() -> SpriteFrames:
	if actor_style and actor_style.run_frames:
		return actor_style.run_frames
	return _get_walk_frames()

func _apply_ground_frames_for_motion(use_run: bool) -> void:
	if is_surfing or _mo_sequence_active:
		return
	var target_frames = _get_run_frames() if use_run else _get_walk_frames()
	if target_frames and sprite.sprite_frames != target_frames:
		sprite.sprite_frames = target_frames

func _should_use_run_frames() -> bool:
	if not motion:
		return false
	return motion.speed_multiplier > 1.0 and not motion.initial_step

func play_mo_start() -> void:
	if _mo_sequence_active:
		return
	_mo_sequence_active = true
	_mo_idle_direction = motion.dir
	await _play_mo_segment(_get_mo_start_frames(), true)

func play_mo_end() -> void:
	if not _mo_sequence_active:
		return
	await _play_mo_segment(_get_mo_end_frames(), false)
	_mo_sequence_active = false
	_restore_mo_state()

func _get_mo_start_frames() -> SpriteFrames:
	if actor_style and actor_style.mo_start_frames:
		return actor_style.mo_start_frames
	return null

func _get_mo_end_frames() -> SpriteFrames:
	if actor_style and actor_style.mo_end_frames:
		return actor_style.mo_end_frames
	return null

func _play_mo_segment(frames: SpriteFrames, keep_pose: bool) -> void:
	if _is_playing_mo_segment or not frames:
		return
	_is_playing_mo_segment = true
	var anim_name := "default"
	if not frames.has_animation(anim_name):
		var names := frames.get_animation_names()
		if names.is_empty():
			_is_playing_mo_segment = false
			return
		anim_name = names[0]

	sprite.sprite_frames = frames
	if not sprite.sprite_frames.has_animation(anim_name):
		sprite.sprite_frames = _get_walk_frames()
		_is_playing_mo_segment = false
		return

	sprite.play(anim_name)
	await sprite.animation_finished

	if keep_pose:
		var last_frame: int = max(sprite.sprite_frames.get_frame_count(anim_name) - 1, 0)
		sprite.animation = anim_name
		sprite.frame = last_frame
	else:
		sprite.stop()
	_is_playing_mo_segment = false

func _restore_mo_state() -> void:
	_refresh_actor_style_frames()
	motion.face(_mo_idle_direction)
	stop()
