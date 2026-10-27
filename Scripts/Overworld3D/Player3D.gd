extends CharacterBody3D
## Player sandbox del spike Overworld3D.
## Sprite 2D (ActorStyle) en AnimatedSprite3D inclinado ~45° como los árboles.

enum MoveMode { GRID, FREE }

@export var move_mode: MoveMode = MoveMode.GRID
@export var walk_speed: float = 4.0
@export var run_speed: float = 7.0
@export var floor_grid_path: NodePath
@export var objects_grid_path: NodePath
@export var actor_style: ActorStyle
## Mismo tamaño de tile 2D (Tileset 32×32). 1 tile 2D = 1 celda GridMap.
@export var tile_pixels: float = 32.0
## Alto del frame del actor en píxeles (Red walk = 32×48).
@export var frame_pixels: Vector2 = Vector2(32, 48)
## Empuja el sprite hacia la cámara (+Z) para compensar el tilt de 45°.
## Editable en remoto mientras corre (Inspector del Player3D).
@export var sprite_back_offset: float = 1.0:
	set(value):
		sprite_back_offset = value
		_apply_sprite_back_offset()

@onready var _visual: Node3D = $Visual
@onready var _sprite: AnimatedSprite3D = $Visual/AnimatedSprite3D
@onready var _grid_motion: GridMotion3D = $GridMotion3D

var _facing: Vector2i = Vector2i(0, 1)


func _cell_size() -> float:
	# Preferir cell_size del Floor si ya está enlazado; si no, 2 (default GridMap spike).
	if _grid_motion != null and _grid_motion.floor_grid != null:
		return _grid_motion.floor_grid.cell_size.x
	return 2.0


func _pixel_size() -> float:
	# Exacto: tile_pixels px 2D = 1 celda 3D.
	return _cell_size() / tile_pixels


func _sprite_world_height() -> float:
	return frame_pixels.y * _pixel_size()


func _ready() -> void:
	motion_mode = MOTION_MODE_FLOATING
	var floor_map := _resolve_grid(floor_grid_path, "Floor")
	var objects_map := _resolve_grid(objects_grid_path, "Objects")
	_grid_motion.setup(self, floor_map, objects_map)
	_setup_sprite()
	_grid_motion.direction_changed.connect(_on_direction_changed)
	_grid_motion.step_started.connect(_on_step_started)
	_grid_motion.step_finished.connect(_on_step_finished)
	if move_mode == MoveMode.GRID:
		_grid_motion.snap_to_cell_center()
	_apply_idle_pose()
	await get_tree().process_frame
	_grid_motion.rebuild_blocked_cells()


func _setup_sprite() -> void:
	# Plano fijo inclinado hacia la cámara (como Tree.glb), sin billboard yaw.
	const TILT := -PI * 0.25
	_visual.rotation = Vector3(TILT, 0.0, 0.0)
	_apply_sprite_back_offset()
	_sprite.centered = true
	# Mismo offset 2D del Player (0, -8) en píxeles de frame.
	_sprite.offset = Vector2(0, -8)
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_sprite.alpha_scissor_threshold = 0.5
	_sprite.shaded = false
	_sprite.double_sided = false
	_apply_frames(_get_walk_frames())
	_sprite.pixel_size = _pixel_size()
	_anchor_sprite_to_ground()


func _apply_sprite_back_offset() -> void:
	if not is_node_ready() or _visual == null:
		return
	_visual.position.z = sprite_back_offset


func _anchor_sprite_to_ground() -> void:
	# Con centered, el pie ≈ -H/2 (+ offset) en Y local del sprite.
	# Subimos en espacio Visual (antes del tilt del padre) para dejar el pie a Y≈0.
	var half_h := _sprite_world_height() * 0.5
	var offset_y_world := _sprite.offset.y * _sprite.pixel_size
	_sprite.position = Vector3(0.0, half_h - offset_y_world, 0.0)


func _physics_process(_delta: float) -> void:
	if move_mode == MoveMode.FREE:
		_process_free_move()
	else:
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
		var running := Input.is_action_pressed("run")
		var speed := run_speed if running else walk_speed
		velocity.x = input_dir.x * speed
		velocity.z = input_dir.z * speed
		_facing = _vector3_to_cardinal(input_dir)
		_play_walk_anim(running)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		_apply_idle_pose()

	velocity.y = 0.0
	move_and_slide()


func _process_grid_move(delta: float) -> void:
	var input_dir := _read_cardinal_input()
	_grid_motion.is_running = Input.is_action_pressed("run")

	if input_dir != Vector2i.ZERO:
		_grid_motion.hold_time += delta
	else:
		_grid_motion.hold_time = 0.0

	# Igual que Player 2D: si está chocando y cambia/suelta la dirección, corta el bump.
	if _grid_motion.is_colliding and _grid_motion.dir != input_dir:
		_grid_motion.cancel_bump()

	if input_dir != Vector2i.ZERO and not _grid_motion.moving:
		_grid_motion.try_step(input_dir)


func _read_cardinal_input() -> Vector2i:
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


func _on_step_started() -> void:
	var use_run := _grid_motion.is_running and not _grid_motion.initial_step \
		and _grid_motion.speed_multiplier > 1.0
	_play_walk_anim(use_run)


func _on_step_finished(_cell: Vector2i) -> void:
	if not Input.is_action_pressed("move_up") \
	and not Input.is_action_pressed("move_down") \
	and not Input.is_action_pressed("move_left") \
	and not Input.is_action_pressed("move_right"):
		_apply_idle_pose()


func _play_walk_anim(use_run: bool) -> void:
	_apply_frames(_get_run_frames() if use_run else _get_walk_frames())
	var dir_name := _dir_name(_facing)
	var stride := "left" if _grid_motion.stride_is_left else "right"
	var anim := "%s_%s" % [dir_name, stride]
	if _sprite.sprite_frames == null or not _sprite.sprite_frames.has_animation(anim):
		return
	if _sprite.is_playing():
		_sprite.stop()
	_sprite.play(anim)
	_sprite.speed_scale = 1.0


func _apply_idle_pose() -> void:
	_apply_frames(_get_walk_frames())
	if _sprite.sprite_frames == null:
		return
	if _sprite.sprite_frames.has_animation("idle"):
		_sprite.animation = "idle"
		_sprite.stop()
		match _facing:
			Vector2i(0, -1):
				_sprite.frame = 3 ## up
			Vector2i(-1, 0):
				_sprite.frame = 1 ## left
			Vector2i(1, 0):
				_sprite.frame = 2 ## right
			_:
				_sprite.frame = 0 ## down
	else:
		_sprite.stop()


func _dir_name(d: Vector2i) -> String:
	match d:
		Vector2i(0, -1):
			return "up"
		Vector2i(-1, 0):
			return "left"
		Vector2i(1, 0):
			return "right"
		_:
			return "down"


func _vector3_to_cardinal(v: Vector3) -> Vector2i:
	if absf(v.x) > absf(v.z):
		return Vector2i(1 if v.x > 0.0 else -1, 0)
	return Vector2i(0, 1 if v.z > 0.0 else -1)


func _apply_frames(frames: SpriteFrames) -> void:
	if frames == null:
		return
	if _sprite.sprite_frames != frames:
		_sprite.sprite_frames = frames


func _get_walk_frames() -> SpriteFrames:
	if actor_style and actor_style.walk_frames:
		return actor_style.walk_frames
	return null


func _get_run_frames() -> SpriteFrames:
	if actor_style and actor_style.run_frames:
		return actor_style.run_frames
	return _get_walk_frames()


func _resolve_grid(path: NodePath, fallback_name: String) -> GridMap:
	if path != NodePath(""):
		var node := get_node_or_null(path)
		if node is GridMap:
			return node as GridMap
	var sibling := get_parent().get_node_or_null(fallback_name) if get_parent() else null
	if sibling is GridMap:
		return sibling as GridMap
	return null
