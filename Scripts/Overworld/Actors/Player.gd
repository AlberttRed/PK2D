extends Node2D

@onready var motion: GridMotion = $GridMotion
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var input_dir := Vector2.ZERO
var holding := false

func _ready() -> void:
	motion.step_started.connect(_on_step_started)
	motion.step_finished.connect(_on_step_finished)

func _process(_delta: float):
	# lee input continuamente
	 #print(motion.hold_time)
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
	match motion.dir:
		Vector2.UP:    sprite.play("walk_up")
		Vector2.DOWN:  sprite.play("walk_down")
		Vector2.LEFT:  sprite.play("walk_left")
		Vector2.RIGHT: sprite.play("walk_right")

	sprite.speed_scale = 1.0   # usa el FPS que pusiste en el editor

func _on_step_finished(tile: Vector2i) -> void:
	if not Input.is_action_pressed("move_up") \
	and not Input.is_action_pressed("move_down") \
	and not Input.is_action_pressed("move_left") \
	and not Input.is_action_pressed("move_right"):
		sprite.stop()
		sprite.frame = 0  # idle
