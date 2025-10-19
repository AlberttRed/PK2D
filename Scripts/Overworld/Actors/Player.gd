extends Node2D

@onready var motion = $GridMotion
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var input_dir := Vector2.ZERO
var holding := false
var movement_enabled: bool = true

func _ready() -> void:
	if !is_in_group("Player"):
		add_to_group("Player")
	motion.step_started.connect(_on_step_started)
	motion.step_finished.connect(_on_step_finished)
	
	# Conectar señales de control del jugador
	SignalManager.player_control_blocked.connect(_on_player_control_blocked)
	SignalManager.player_control_unblocked.connect(_on_player_control_unblocked)
	
	sprite.animation = "walk_down_right"

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
	
	# Actualizar flag de correr en GridMotion
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

func _on_step_finished(_tile: Vector2i) -> void:
	if not Input.is_action_pressed("move_up") \
	and not Input.is_action_pressed("move_down") \
	and not Input.is_action_pressed("move_left") \
	and not Input.is_action_pressed("move_right"):
		stop()
		
func stop():
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
	var map_system: MapSystem = get_tree().get_first_node_in_group("MapSystem")
	if not map_system:
		push_error("Player: No se encontró el MapSystem en la escena")
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
