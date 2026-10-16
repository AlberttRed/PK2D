extends CharacterBody3D
## Player sandbox del spike Overworld3D.
## No comparte lógica con Scripts/Overworld/Actors/Player.gd.

enum MoveMode { GRID, FREE }

@export var move_mode: MoveMode = MoveMode.GRID
@export var walk_speed: float = 4.0
@export var run_speed: float = 7.0
@export var floor_grid_path: NodePath
@export var objects_grid_path: NodePath

@onready var _visual: Node3D = $Visual
@onready var _grid_motion: GridMotion3D = $GridMotion3D

var _facing: Vector2i = Vector2i(0, 1)


func _ready() -> void:
	motion_mode = MOTION_MODE_FLOATING
	var floor_map := _resolve_grid(floor_grid_path, "Floor")
	var objects_map := _resolve_grid(objects_grid_path, "Objects")
	_grid_motion.setup(self, floor_map, objects_map)
	_grid_motion.direction_changed.connect(_on_direction_changed)
	if move_mode == MoveMode.GRID:
		_grid_motion.snap_to_cell_center()
		_apply_facing(_facing)
	# Asegurar bake cuando Floor/Objects ya han terminado su _ready.
	await get_tree().process_frame
	_grid_motion.rebuild_blocked_cells()


func _physics_process(delta: float) -> void:
	if move_mode == MoveMode.FREE:
		_process_free_move()
	else:
		# En GRID no usamos velocity; evitamos que el cuerpo interfiera con el tween.
		velocity = Vector3.ZERO


func _process(delta: float) -> void:
	if move_mode == MoveMode.GRID:
		_process_grid_move(delta)


func _process_free_move() -> void:
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


func _process_grid_move(delta: float) -> void:
	var input_dir := _read_cardinal_input()
	_grid_motion.is_running = Input.is_action_pressed("run")

	if input_dir != Vector2i.ZERO:
		_grid_motion.hold_time += delta
	else:
		_grid_motion.hold_time = 0.0

	if input_dir != Vector2i.ZERO and not _grid_motion.moving:
		_grid_motion.try_step(input_dir)


func _read_cardinal_input() -> Vector2i:
	# Prioridad como en 2D: una sola dirección (sin diagonales).
	if Input.is_action_pressed("move_up"):
		return Vector2i(0, -1)
	if Input.is_action_pressed("move_down"):
		return Vector2i(0, 1)
	if Input.is_action_pressed("move_left"):
		return Vector2i(-1, 0)
	if Input.is_action_pressed("move_right"):
		return Vector2i(1, 0)
	return Vector2i.ZERO


func _on_direction_changed(new_dir: Vector2i) -> void:
	_facing = new_dir
	_apply_facing(new_dir)


func _apply_facing(d: Vector2i) -> void:
	if d == Vector2i.ZERO:
		return
	# Visual mira hacia +Z local; rotar según dir XZ.
	_visual.rotation.y = atan2(float(d.x), float(d.y))


func _resolve_grid(path: NodePath, fallback_name: String) -> GridMap:
	if path != NodePath(""):
		var node := get_node_or_null(path)
		if node is GridMap:
			return node as GridMap
	var sibling := get_parent().get_node_or_null(fallback_name) if get_parent() else null
	if sibling is GridMap:
		return sibling as GridMap
	return null
