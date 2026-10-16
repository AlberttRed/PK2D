extends CharacterBody3D
## Player sandbox del spike Overworld3D.
## No comparte lógica con Scripts/Overworld/Actors/Player.gd.

@export var walk_speed: float = 4.0
@export var run_speed: float = 7.0

@onready var _visual: Node3D = $Visual

func _ready() -> void:
	motion_mode = MOTION_MODE_FLOATING

func _physics_process(_delta: float) -> void:
	var input_dir := Vector3.ZERO
	if Input.is_action_pressed("move_up"):
		input_dir.z -= 1.0
	if Input.is_action_pressed("move_down"):
		input_dir.z += 1.0
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1.0
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1.0

	if input_dir != Vector3.ZERO:
		input_dir = input_dir.normalized()
		var speed := run_speed if Input.is_action_pressed("run") else walk_speed
		velocity.x = input_dir.x * speed
		velocity.z = input_dir.z * speed
		_visual.rotation.y = atan2(input_dir.x, input_dir.z)
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	velocity.y = 0.0
	move_and_slide()
