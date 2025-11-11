extends Node2D

@onready var motion = $GridMotion
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var battler: Battler = $Battler

# Referencia al OverworldContext (opcional, para acceso a sistemas)
var context: OverworldContext = null

# SpriteFrames para diferentes modos de movimiento
var normal_spriteframes: SpriteFrames = preload("res://Resources/Animations/Overworld/Player_Walk.tres")
var surf_spriteframes: SpriteFrames = preload("res://Resources/Animations/Overworld/Player_Surf.tres")

var input_dir := Vector2.ZERO
var holding := false
var movement_enabled: bool = true
var is_surfing: bool = false  # Modo surfing activado
var _control_block_count: int = 0  # Contador de bloqueos anidados

func _ready() -> void:
	if !is_in_group("Player"):
		add_to_group("Player")
	motion.step_started.connect(_on_step_started)
	motion.step_finished.connect(_on_step_finished)
	$Shadow.visible = false

	sprite.animation = "walk_down_right"
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
	var dir_name := "down"
	match motion.dir:
		Vector2.UP: dir_name = "up"
		Vector2.DOWN: dir_name = "down"
		Vector2.LEFT: dir_name = "left"
		Vector2.RIGHT: dir_name = "right"

	# Animaciones con zancada: walk_<dir>_<left|right>
	var stride := ("left" if motion.stride_is_left else "right")
	var walk_anim := "walk_" + dir_name + "_" + stride
	var run_anim := "run_" + dir_name + "_" + stride

	var frames: SpriteFrames = sprite.sprite_frames
	var anim_to_play := ""
	if use_run and frames and frames.has_animation(run_anim):
		anim_to_play = run_anim
	elif frames and frames.has_animation(walk_anim):
		anim_to_play = walk_anim
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
		sprite.sprite_frames = surf_spriteframes
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
		sprite.sprite_frames = normal_spriteframes
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
