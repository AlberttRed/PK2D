extends CharacterBody3D
class_name Player3D
## Player sandbox del spike Overworld3D.
## Sprite 2D (ActorStyle) en AnimatedSprite3D inclinado ~45° como los árboles.

enum MoveMode { GRID, FREE }

@export var move_mode: MoveMode = MoveMode.GRID
@export var walk_speed: float = 4.0
@export var run_speed: float = 7.0
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

## Motor de movimiento por celdas. Mismo nombre que en el Player 2D (`player.motion`): lo usan los comandos
## compartidos (BlockPlayer: espera a `motion.moving` / `motion.step_finished`).
var motion: GridMotion3D:
	get:
		return _grid_motion

## Contexto del Overworld (lo inyecta World3DSystem / el coordinador). API de control idéntica al Player 2D.
var context: OverworldContext = null
var movement_enabled: bool = true
## Contador de bloqueos anidados (eventos, UI...). Solo se libera al llegar a 0.
var _control_block_count: int = 0

## Latch de direcciones por eventos press/release. Evita el caso de Godot en el que
## `Input.is_action_pressed` se queda en true tras soltar (p.ej. tras mantener mucho
## tiempo, perder foco del game window, o soltar durante fade/pausa).
const _MOVE_ACTIONS: Array[StringName] = [
	&"move_up", &"move_down", &"move_left", &"move_right",
]
## Teclas físicas actuales del InputMap (flechas). Si la acción se "pega" pero la
## tecla ya no está abajo, cortamos el movimiento.
const _MOVE_PHYSICAL_KEYS: Dictionary = {
	&"move_up": KEY_UP,
	&"move_down": KEY_DOWN,
	&"move_left": KEY_LEFT,
	&"move_right": KEY_RIGHT,
}
var _move_held: Dictionary = {
	&"move_up": false,
	&"move_down": false,
	&"move_left": false,
	&"move_right": false,
}


func _cell_size() -> float:
	# cell_size del OverworldGrid3D si está enlazado; si no, 2 (default GridMap spike).
	if _grid_motion != null and _grid_motion.grid != null:
		return _grid_motion.grid.cell_size().x
	return 2.0


func _ready() -> void:
	motion_mode = MOTION_MODE_FLOATING
	# Igual que Player 2D: DisplayManager pausa el árbol mientras hay UI (mensajes...);
	# el player sigue vivo para terminar animaciones y reaccionar al desbloqueo.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_connect_display_manager_signals()
	# Igual que Player 2D: CollisionTrigger/TouchTrigger comprueban instigator.is_in_group("Player").
	if not is_in_group("Player"):
		add_to_group("Player")
	var overworld_grid := get_tree().get_first_node_in_group(OverworldGrid3D.GROUP) as OverworldGrid3D
	if overworld_grid == null:
		push_error("Player3D: no hay OverworldGrid3D en el mapa (añádelo como hermano de Floor/Objects).")
	_grid_motion.setup(self, overworld_grid)
	_setup_sprite()
	_grid_motion.direction_changed.connect(_on_direction_changed)
	_grid_motion.step_started.connect(_on_step_started)
	_grid_motion.step_finished.connect(_on_step_finished)
	if move_mode == MoveMode.GRID:
		_grid_motion.snap_to_cell_center()
	_apply_idle_pose()
	await get_tree().process_frame
	if overworld_grid != null:
		overworld_grid.rebuild()


## Re-enlaza al player con el OverworldGrid3D de otro mapa (cambio de mapa con el player ya creado).
func bind_grid(new_grid: OverworldGrid3D) -> void:
	_grid_motion.setup(self, new_grid)
	if new_grid != null:
		await get_tree().process_frame
		if is_instance_valid(new_grid):
			new_grid.rebuild()


## Coloca al player en el centro de una celda XZ (cancela cualquier movimiento en curso).
## `y` NAN = conserva la altura actual. `facing` ZERO = conserva la dirección.
func place_at_cell(cell: Vector2i, facing: Vector2i = Vector2i.ZERO, y: float = NAN) -> void:
	_grid_motion.cancel_movement()
	var ground_y := global_position.y if is_nan(y) else y
	global_position = _grid_motion.cell_to_world_center(cell, ground_y)
	_grid_motion.snap_to_cell_center()
	if facing != Vector2i.ZERO:
		_grid_motion.face(facing)
		_facing = facing
	_apply_idle_pose()


## Orientación desde un Vector2 (x→X, y→Z; como `set_facing_direction` del Player 2D, lo usa WarpCommand).
## Solo cardinales: si es diagonal, prioriza el eje X. ZERO no hace nada.
func set_facing_direction(direction: Vector2) -> void:
	var d := Vector2i(signi(int(direction.x)), signi(int(direction.y)))
	if d.x != 0 and d.y != 0:
		d.y = 0
	if d == Vector2i.ZERO:
		return
	_grid_motion.face(d)
	_facing = d
	if not _grid_motion.moving:
		_apply_idle_pose()


## Celda XZ actual del player.
func current_cell() -> Vector2i:
	return _grid_motion.current_cell()


## Dirección actual (cardinal XZ).
func facing_dir() -> Vector2i:
	return _grid_motion.dir


func _setup_sprite() -> void:
	# Plano fijo inclinado hacia la cámara (como Tree.glb), sin billboard yaw.
	# La configuración (tilt, escala, anclaje) es compartida con Event3D vía ActorSprite3D.
	ActorSprite3D.setup(_visual, _sprite, _cell_size(), tile_pixels, frame_pixels, sprite_back_offset)
	_apply_frames(_get_walk_frames())


func _apply_sprite_back_offset() -> void:
	if not is_node_ready() or _visual == null:
		return
	ActorSprite3D.apply_back_offset(_visual, sprite_back_offset)


func _physics_process(_delta: float) -> void:
	if move_mode == MoveMode.FREE:
		_process_free_move()
	else:
		velocity = Vector3.ZERO


func _notification(what: int) -> void:
	# Al perder el foco del juego, Godot a menudo no recibe el key-up y la acción
	# queda "pegada". Forzamos release para no seguir caminando solos.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT \
	or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_clear_move_held(true)


func _process(delta: float) -> void:
	if move_mode == MoveMode.GRID:
		# Igual que Player 2D: sin input si el juego está pausado o los controles bloqueados.
		# (El latch de teclas sí se actualiza en `_input` aunque estemos bloqueados/pausados.)
		if get_tree().paused or not movement_enabled:
			return
		_process_grid_move(delta)


func _process_free_move() -> void:
	var input_dir := Vector3.ZERO
	var card := _read_cardinal_input()
	if card == Vector2i(0, -1):
		input_dir.z -= 1.0
	elif card == Vector2i(0, 1):
		input_dir.z += 1.0
	elif card == Vector2i(-1, 0):
		input_dir.x -= 1.0
	elif card == Vector2i(1, 0):
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
	# Un comando (MoveNPC...) mueve al player: el input no debe pisar su velocidad ni sus pasos.
	if _grid_motion.is_command_controlled:
		return
	var input_dir := _read_cardinal_input()
	_grid_motion.is_running = Input.is_action_pressed("run")

	if input_dir != Vector2i.ZERO:
		_grid_motion.hold_time += delta
	else:
		_grid_motion.hold_time = 0.0

	# Igual que Player 2D: si está chocando y cambia/suelta la dirección, corta el bump.
	if _grid_motion.is_colliding and _grid_motion.dir != input_dir:
		_grid_motion.cancel_bump()
	# Un evento disparado por COLLISION no se repite hasta soltar/cambiar de dirección.
	if input_dir == Vector2i.ZERO or input_dir != _grid_motion.dir:
		_grid_motion.release_collision_latch()

	if input_dir != Vector2i.ZERO and not _grid_motion.moving:
		_grid_motion.try_step(input_dir)


## Trackea press/release de movimiento siempre (también con UI/fade/pausa), para no
## perder el key-up y quedar andando eternos.
func _input(event: InputEvent) -> void:
	for action in _MOVE_ACTIONS:
		# Sin ecos de autorepeat: un key-down echo no debe re-armar el latch.
		if event.is_action_pressed(action, false, true):
			_move_held[action] = true
		elif event.is_action_released(action):
			_move_held[action] = false
			# Si el singleton Input se desincronizó, forzamos el release.
			if Input.is_action_pressed(action):
				Input.action_release(action)


## "interact" frente a un evento → trigger ACTION (como Player 2D).
func _unhandled_input(event: InputEvent) -> void:
	if move_mode != MoveMode.GRID or _grid_motion.moving:
		return
	if get_tree().paused or not movement_enabled:
		return
	if event.is_action_pressed("interact"):
		var e := _grid_motion.event_in_front()
		if e != null and e.has_method("on_player_action"):
			e.on_player_action()


func _read_cardinal_input() -> Vector2i:
	# Latch de evento + estado Input: hace falta ambos. Así un `is_action_pressed`
	# "pegado" sin key-down reciente no encadena más pasos.
	if _is_move_active(&"move_up"):
		return Vector2i(0, -1)
	if _is_move_active(&"move_down"):
		return Vector2i(0, 1)
	if _is_move_active(&"move_left"):
		return Vector2i(-1, 0)
	if _is_move_active(&"move_right"):
		return Vector2i(1, 0)
	return Vector2i.ZERO


func _is_move_active(action: StringName) -> bool:
	if not bool(_move_held.get(action, false)):
		return false
	# Si la tecla física ya no está (acción Input desincronizada), corta aquí.
	var key: int = int(_MOVE_PHYSICAL_KEYS.get(action, KEY_NONE))
	if key != KEY_NONE and not Input.is_physical_key_pressed(key):
		_move_held[action] = false
		if Input.is_action_pressed(action):
			Input.action_release(action)
		return false
	if not Input.is_action_pressed(action):
		_move_held[action] = false
		return false
	return true


func _clear_move_held(release_input: bool = false) -> void:
	for action in _MOVE_ACTIONS:
		_move_held[action] = false
		if release_input and Input.is_action_pressed(action):
			Input.action_release(action)
	if _grid_motion != null:
		_grid_motion.hold_time = 0.0
		_grid_motion.release_collision_latch()
		if not _grid_motion.moving and is_node_ready():
			_apply_idle_pose()


func _on_direction_changed(new_dir: Vector2i) -> void:
	_facing = new_dir
	# Cambio de dirección sin giro ni paso (p.ej. andando a la izquierda y cambiando a arriba sin soltar
	# contra un evento COLLISION): esa ruta no emite step_started, así que reflejamos ya la pose.
	# En pasos/giros/bumps normales step_started reproduce la animación en este mismo frame.
	if not _grid_motion.moving:
		_apply_idle_pose()


func _on_step_started() -> void:
	# Correr = velocidad > 1 (tecla "run" o comandos MoveNPC con SPEED_*); igual que NPC3D y el 2D.
	var use_run: bool = not _grid_motion.initial_step and _grid_motion.speed_multiplier > 1.0
	_play_walk_anim(use_run)


func _on_step_finished(_cell: Vector2i) -> void:
	# Con controles bloqueados no se encadena otro paso: pose idle aunque siga pulsada la tecla.
	# Usa el mismo latch que el movimiento (no solo Input.is_action_pressed).
	if not movement_enabled or _read_cardinal_input() == Vector2i.ZERO:
		_apply_idle_pose()


# --- API de control (misma que Player 2D; la usan OverworldContext / EventController) ---

func set_movement_enabled(enabled: bool) -> void:
	movement_enabled = enabled
	if not enabled and not _grid_motion.moving:
		_apply_idle_pose()


## Bloquea los controles. Usa un contador para permitir bloqueos anidados.
func block_controls() -> void:
	_control_block_count += 1
	set_movement_enabled(false)


## Desbloquea los controles; solo se liberan de verdad cuando el contador llega a 0.
func unblock_controls() -> void:
	_control_block_count = maxi(0, _control_block_count - 1)
	if _control_block_count == 0:
		movement_enabled = true


## Fuerza el desbloqueo inmediato (resetea el contador).
func force_unblock_controls() -> void:
	_control_block_count = 0
	movement_enabled = true


func are_controls_blocked() -> bool:
	return not movement_enabled


## Equivalentes a Event.show_sprite()/hide_sprite() (SetActorVisibilityCommand con target Player).
func show_sprite() -> void:
	if _visual != null:
		_visual.visible = true


func hide_sprite() -> void:
	if _visual != null:
		_visual.visible = false


## Establece el contexto del Overworld (llamado desde World3DSystem).
func set_context(overworld_context: OverworldContext) -> void:
	context = overworld_context
	if context:
		if not context.player_control_blocked.is_connected(_on_player_control_blocked):
			context.player_control_blocked.connect(_on_player_control_blocked)
		if not context.player_control_unblocked.is_connected(_on_player_control_unblocked):
			context.player_control_unblocked.connect(_on_player_control_unblocked)
	_connect_display_manager_signals()


func _on_player_control_blocked() -> void:
	set_movement_enabled(false)


func _on_player_control_unblocked() -> void:
	# UI (mochila/party/pausa) emite unblock al cerrar; no debe pisar un bloqueo de evento.
	if _control_block_count > 0:
		movement_enabled = false
		return
	set_movement_enabled(true)


## Conecta con las señales de bloqueo del DisplayManager (si existe; no en la escena aislada).
func _connect_display_manager_signals() -> void:
	var dm := DisplayManager.instance
	if dm == null:
		return
	if not dm.player_control_blocked.is_connected(_on_player_control_blocked):
		dm.player_control_blocked.connect(_on_player_control_blocked)
	if not dm.player_control_unblocked.is_connected(_on_player_control_unblocked):
		dm.player_control_unblocked.connect(_on_player_control_unblocked)


func _play_walk_anim(use_run: bool) -> void:
	# Lógica de animación compartida con NPC3D (ActorSpriteAnim3D).
	ActorSpriteAnim3D.play_stride(_sprite, _get_run_frames() if use_run else _get_walk_frames(),
		_facing, _grid_motion.stride_is_left)


func _apply_idle_pose() -> void:
	ActorSpriteAnim3D.apply_idle(_sprite, _get_walk_frames(), _facing)


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
