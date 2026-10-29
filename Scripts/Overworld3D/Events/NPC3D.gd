@tool
extends Event3D
class_name NPC3D
## Equivalente 3D de NPC (2D). PBI #976.
##
## Es un Event3D (páginas, triggers, comandos, visual por página, registro en el grid) al que se
## añade un cuerpo que se mueve por celdas: un GridMotion3D hijo + sprite plano animado con el mismo
## ActorStyle que el Player3D. Las decisiones de comportamiento (random, path, look pattern, awareness)
## las toma NPCBehavior, compartido con el 2D; este script es solo su adaptador 3D.
##
## Ocupación: al empezar un paso reserva la celda destino en el OverworldGrid3D (así ni el Player ni
## otro NPC pueden entrar) y libera la de origen al terminar. El propio GridMotion3D impide que el NPC
## atraviese al Player.
##
## `@tool` solo para que el preview de Event3D siga funcionando en el editor; aquí no se ejecuta lógica.

## Motor de movimiento por celdas (mismo nombre que en el NPC 2D: `npc.motion`).
var motion: GridMotion3D = null
## Cerebro compartido con el NPC 2D.
var behavior: NPCBehavior = null
var movement_enabled: bool = true

var _facing: Vector2i = Vector2i(0, 1)
var _npc_started: bool = false
## Página para la que ya se configuró el NPC (evita reiniciar el comportamiento al refrescar sin cambio).
var _applied_page: EventPage = null
var _previous_sprite_key: Dictionary = {}
## Celda destino reservada durante un paso (Vector2i.MAX = ninguna).
var _reserved_cell: Vector2i = Vector2i.MAX
var _walk_frames: SpriteFrames = null
var _run_frames: SpriteFrames = null
## Pausas acumuladas del comportamiento (evento propio + comandos MoveNPC...). Solo se reanuda al llegar a 0.
var _pause_count: int = 0
## true si este NPC ya se pausó por su propio evento (se libera una sola vez en event_finished).
var _paused_by_event: bool = false
var _event_system: Object = null


func _ready() -> void:
	if Engine.is_editor_hint():
		super._ready()
		return
	motion = get_node_or_null("GridMotion3D") as GridMotion3D
	if motion == null:
		motion = GridMotion3D.new()
		motion.name = "GridMotion3D"
		add_child(motion)
	motion.play_bump_sound = false
	behavior = NPCBehavior.new()
	behavior.name = "NPCBehavior"
	add_child(behavior)
	behavior.setup(self)

	# Event3D._ready: grid, registro en celda, páginas (llama a _on_page_applied).
	super._ready()

	if grid != null:
		motion.setup(self, grid)
		motion.snap_to_cell_center()
	motion.step_started.connect(_on_step_started)
	motion.step_finished.connect(_on_step_finished)
	_npc_started = true
	_npc_apply_page()


func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		_release_reserved_cell()
		if behavior != null and is_instance_valid(behavior):
			behavior.stop()
	super._exit_tree()


# --- Datos de la página activa (mismos getters que NPC 2D) ---

func get_movement_type() -> int:
	return current_page.movement_type if current_page else MovementTypeEnum.Type.NONE


func get_orientation_behavior() -> int:
	return current_page.orientation_behavior if current_page else OrientationBehaviorEnum.Type.FACE_PLAYER


func get_initial_direction() -> int:
	return current_page.initial_direction if current_page else DirectionEnum.Type.DOWN


func get_movement_speed() -> int:
	return current_page.movement_speed if current_page else MoveSpeedEnum.Type.NORMAL


# --- Página ---

func _on_page_applied() -> void:
	super._on_page_applied()
	if _npc_started:
		_npc_apply_page()


## Aplica la configuración de movimiento/animación de la página activa. Solo si la página cambió.
func _npc_apply_page() -> void:
	if motion == null or behavior == null:
		return
	var page := current_page as EventPage
	if page == null:
		_applied_page = null
		behavior.stop()
		return
	if page == _applied_page:
		return
	_applied_page = page

	motion.base_speed = MoveSpeedEnum.to_multiplier(page.movement_speed)
	_capture_frames(page)

	# Mantener la dirección si la página lo pide y el sprite no cambia (p.ej. NPC mirando al player).
	var key := _sprite_key(page)
	var preserve := page.preserve_direction_on_sprite_match and key == _previous_sprite_key
	_previous_sprite_key = key
	if not preserve:
		_facing = _initial_facing()
	motion.face(_facing)
	_apply_idle()
	behavior.restart()


func _capture_frames(page: EventPage) -> void:
	var style: ActorStyle = page.actor_style
	var sprite := get_flat_sprite()
	if style != null:
		_walk_frames = style.walk_frames
		_run_frames = style.run_frames if style.run_frames != null else style.walk_frames
	else:
		_walk_frames = sprite.sprite_frames if sprite != null else null
		_run_frames = _walk_frames


func _sprite_key(page: EventPage) -> Dictionary:
	return {
		"actor_style": page.actor_style,
		"sprite_frames": page.sprite_frames,
		"sprite_texture": page.sprite_texture,
		"is_spritesheet": page.is_spritesheet,
	}


func _initial_facing() -> Vector2i:
	var v := DirectionEnum.to_vector2(get_initial_direction())
	return Vector2i(int(v.x), int(v.y))


# --- Orientación / animación ---

## Gira sin moverse y actualiza la pose.
func face(dir: Vector2i) -> void:
	if dir == Vector2i.ZERO:
		return
	_facing = dir
	if motion != null:
		motion.face(dir)
	if motion == null or not motion.moving:
		_apply_idle()


## Misma API que NPC/Player 2D (comandos compartidos): Vector2 → cardinal XZ.
func set_facing_direction(direction: Vector2) -> void:
	var d := Vector2i(signi(int(direction.x)), signi(int(direction.y)))
	if d.x != 0 and d.y != 0:
		d.y = 0
	face(d)


func facing_dir() -> Vector2i:
	return _facing


func _apply_idle() -> void:
	ActorSpriteAnim3D.apply_idle(get_flat_sprite(), _walk_frames, _facing)


func _on_step_started() -> void:
	# Reserva la celda destino: nadie más puede entrar mientras el NPC se desplaza hacia ella.
	if grid != null:
		var target := motion.target_cell()
		if target != _cell:
			grid.register_event(target, self)
			_reserved_cell = target
	_facing = motion.dir
	var use_run := motion.speed_multiplier > 1.0 and not motion.initial_step
	ActorSpriteAnim3D.play_stride(get_flat_sprite(), _run_frames if use_run else _walk_frames,
		_facing, motion.stride_is_left)


func _on_step_finished(cell: Vector2i) -> void:
	if grid != null and cell != _cell:
		grid.unregister_event(_cell, self)
		_cell = cell
	_reserved_cell = Vector2i.MAX
	_apply_idle()
	if behavior != null:
		behavior.notify_step_finished()


func _release_reserved_cell() -> void:
	if grid != null and is_instance_valid(grid) and _reserved_cell != Vector2i.MAX:
		grid.unregister_event(_reserved_cell, self)
	_reserved_cell = Vector2i.MAX


# --- Posición ---

## Mueve el NPC a otra celda (warp, page_position, MoveNPC...): cancela el paso en curso.
func move_to_cell(cell: Vector2i) -> void:
	if grid == null:
		return
	_release_reserved_cell()
	if motion != null and motion.grid != null and motion.moving:
		motion.cancel_movement()
	super.move_to_cell(cell)
	if motion != null and motion.grid != null:
		motion.snap_to_cell_center()
	if _npc_started and behavior != null:
		behavior.nudge()


## Alias de la API 2D (WarpCommand, MoveNPC...).
func teleport_to_tile(tile: Vector2i) -> void:
	move_to_cell(tile)


## Corta el paso en curso y deja al NPC quieto.
func stop_movement() -> void:
	if motion != null and motion.moving:
		var previous_cell := _cell
		motion.cancel_movement()
		_release_reserved_cell()
		if grid != null and motion.current_cell() != previous_cell:
			grid.unregister_event(previous_cell, self)
			_cell = motion.current_cell()
			grid.register_event(_cell, self)
	_apply_idle()


func set_movement_enabled(enabled: bool) -> void:
	movement_enabled = enabled
	if behavior != null:
		behavior.set_enabled(enabled)
	if not enabled:
		stop_movement()


# --- Trigger (equivalente a NPC.trigger) ---

func trigger() -> void:
	if _is_runtime_disabled():
		return
	# Si la página no bloquea al player, el NPC lo bloquea mientras se orienta.
	var page := current_page as EventPage
	var npc_blocks: bool = page != null and not page.blocks_player and overworld_context != null
	if npc_blocks:
		overworld_context.block_player_control()

	if motion != null and motion.moving:
		await motion.step_finished
	if not _paused_by_event:
		_paused_by_event = true
		_pause_movement()

	match get_orientation_behavior():
		OrientationBehaviorEnum.Type.FACE_PLAYER, OrientationBehaviorEnum.Type.FACE_AND_RESTORE:
			_face_player()
		_:
			pass

	super.trigger()

	if npc_blocks:
		# Un frame para que el EventController alcance a bloquear antes de liberar.
		await get_tree().process_frame
		if overworld_context != null:
			overworld_context.unblock_player_control()


func _face_player() -> void:
	var toward := NPCBehavior.direction_toward(get_actor_cell(), get_player_cell())
	if toward != Vector2i.ZERO:
		face(toward)


func _pause_movement() -> void:
	_pause_count += 1
	if _pause_count == 1 and behavior != null:
		behavior.pause()


func _resume_movement() -> void:
	_pause_count = maxi(0, _pause_count - 1)
	if _pause_count == 0 and behavior != null:
		behavior.resume()


## Un comando (MoveNPC...) toma el control del NPC: pausa su comportamiento y espera a que acabe el
## paso en curso. Debe cerrarse con `end_command_control()`.
func begin_command_control() -> void:
	_pause_movement()
	if motion != null and motion.moving:
		await motion.step_finished


func end_command_control() -> void:
	_resume_movement()


func set_overworld_context(context: OverworldContext) -> void:
	super.set_overworld_context(context)
	# Reanudar el movimiento cuando termina el evento de este NPC.
	var event_sys: Object = context.get_event_system() if context != null else null
	if event_sys != null and event_sys != _event_system:
		_event_system = event_sys
		if not event_sys.event_finished.is_connected(_on_event_finished):
			event_sys.event_finished.connect(_on_event_finished)


func _on_event_finished(event) -> void:
	if event != self or not _paused_by_event:
		return
	_paused_by_event = false
	if get_orientation_behavior() == OrientationBehaviorEnum.Type.FACE_AND_RESTORE:
		face(_initial_facing())
	_resume_movement()


# --- Interfaz que usa NPCBehavior ---

func get_behavior_page() -> EventPage:
	return current_page as EventPage


func is_actor_moving() -> bool:
	return motion != null and motion.moving


func get_actor_cell() -> Vector2i:
	return motion.current_cell() if motion != null and motion.grid != null else _cell


func actor_step(dir: Vector2i) -> void:
	if motion == null:
		return
	# Igual que el NPC 2D: sin pausa de giro previa (la orientación ya se aplicó con actor_face).
	motion.hold_time = motion.initial_delay
	motion.try_step(dir)


func actor_can_step(dir: Vector2i) -> bool:
	return motion != null and motion.can_step(dir)


func actor_face(dir: Vector2i) -> void:
	face(dir)


func actor_set_speed(multiplier: float) -> void:
	if motion != null:
		motion.base_speed = multiplier


func get_player_cell() -> Vector2i:
	var player := get_tree().get_first_node_in_group("Player")
	if player != null and player.has_method("current_cell"):
		return player.current_cell()
	return Vector2i.MAX


func get_player_motion() -> Object:
	var player := get_tree().get_first_node_in_group("Player")
	if player != null:
		return player.get("motion")
	return null


func is_player_running() -> bool:
	var player_motion := get_player_motion()
	return player_motion != null and bool(player_motion.get("is_running"))
