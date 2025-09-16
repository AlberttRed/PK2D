extends Node2D

@onready var motion: GridMotion = $GridMotion
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var input_dir := Vector2.ZERO
var holding := false
var movement_enabled: bool = true

func _ready() -> void:
	if !is_in_group("Player"):
		add_to_group("Player")
	motion.step_started.connect(_on_step_started)
	motion.step_finished.connect(_on_step_finished)
	sprite.animation = "walk_down"

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
	
	if input_dir != Vector2.ZERO:
		motion.hold_time += _delta
	else:
		motion.hold_time = 0.0

	#If one direction has been pressed and is not doing move animation, try move to next tile
	if input_dir != Vector2.ZERO and not motion.moving:
		motion.try_step(input_dir)

func _on_step_started() -> void:
	var anim_prefix = "walk"
	if motion.speed_multiplier > 1.0:
		anim_prefix = "run"
	match motion.dir:
		Vector2.UP:    sprite.play(anim_prefix + "_up")
		Vector2.DOWN:  sprite.play(anim_prefix + "_down")
		Vector2.LEFT:  sprite.play(anim_prefix + "_left")
		Vector2.RIGHT: sprite.play(anim_prefix + "_right")

	sprite.speed_scale = motion.speed_multiplier#1.0 / motion.get_step_duration()   # usa el FPS que pusiste en el editor

func _on_step_finished(tile: Vector2i) -> void:
	if not Input.is_action_pressed("move_up") \
	and not Input.is_action_pressed("move_down") \
	and not Input.is_action_pressed("move_left") \
	and not Input.is_action_pressed("move_right"):
		stop()
		
func stop():
	match motion.dir:
		Vector2.UP: sprite.animation = "walk_up"
		Vector2.DOWN: sprite.animation = "walk_down"
		Vector2.LEFT: sprite.animation = "walk_left"
		Vector2.RIGHT: sprite.animation = "walk_right"
	sprite.stop()
	sprite.frame = 0  # idle
	
func _unhandled_input(event: InputEvent) -> void:
	if not movement_enabled:
		return
		
	if event.is_action_pressed("interact") and not motion.moving:
		var e := motion.event_in_front()
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

func teleport_to_tile(tile: Vector2i) -> void:
	"""Teletransporta al jugador a la posición especificada"""
	var grid: OverworldGrid = get_tree().get_first_node_in_group("OverworldGrid")
	if grid:
		# Usar el método de Occupancy si está disponible
		if has_node("Occupancy"):
			$Occupancy.teleport_to_tile(tile)
		else:
			# Fallback: teletransporte directo
			global_position = grid.tile_to_world_center(tile)
