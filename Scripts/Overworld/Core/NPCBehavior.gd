class_name NPCBehavior
extends Node
## "Cerebro" de un NPC, independiente de la dimensión (2D / 3D). PBI #976.
##
## Decide QUÉ hace el NPC según los datos de la página activa (EventPage): movimiento aleatorio,
## ruta (path), patrón de mirada, giros aleatorios y awareness. No mueve nada por sí mismo: le pide
## las cosas al actor (`host`) mediante una interfaz mínima en celdas (Vector2i; arriba = (0,-1)).
##
## Interfaz que debe implementar el host (duck typing):
##   get_behavior_page() -> EventPage        página activa (o null)
##   is_actor_moving() -> bool               true mientras dura un paso/giro
##   get_actor_cell() -> Vector2i            celda lógica del actor
##   actor_step(dir: Vector2i) -> void       intenta dar un paso (gira antes si hace falta)
##   actor_can_step(dir: Vector2i) -> bool   true si el paso es posible ahora
##   actor_face(dir: Vector2i) -> void       gira sin moverse (y actualiza la pose)
##   actor_set_speed(multiplier: float)      velocidad base (comandos SPEED_* del path)
##   get_player_cell() -> Vector2i           celda del player (Vector2i.MAX si no hay)
##   get_player_motion() -> Object           motor del player con señal `step_finished` (o null)
##   is_player_running() -> bool
## Y debe llamar a `notify_step_finished()` cuando termine cada paso del actor.
##
## Limitaciones conocidas del path (se amplían en el PBI de migración del NPC 2D): TURN_* se trata
## como LOOK_* y EXCLAMATION_ANIM se ignora.

## Espera (s) antes de reintentar un paso del path que está bloqueado.
const PATH_BLOCKED_RETRY := 0.5
## Espera (s) tras una orden de mirar en el path.
const PATH_LOOK_DELAY := 0.5

var host: Object = null
## Si es false el NPC no toma decisiones (set_movement_enabled del actor).
var enabled: bool = true

var _paused: bool = false
var _running: bool = false
var _timer: Timer = null
var _path_index: int = 0
var _look_index: int = 0
## Se incrementa al parar/pausar/reiniciar: invalida los `await` pendientes.
var _generation: int = 0
var _path_waiting: bool = false
var _awareness_motion: Object = null


func setup(p_host: Object) -> void:
	host = p_host
	if _timer == null:
		_timer = Timer.new()
		_timer.name = "BehaviorTimer"
		_timer.one_shot = true
		_timer.timeout.connect(_on_timer_timeout)
		add_child(_timer)


# --- Ciclo de vida ---

## (Re)inicia el comportamiento según la página activa. Reinicia índices de path y mirada.
func restart() -> void:
	stop()
	_path_index = 0
	_look_index = 0
	start()


func start() -> void:
	if host == null or _timer == null:
		return
	_running = true
	_generation += 1
	_path_waiting = false
	var page: EventPage = host.get_behavior_page()
	if page == null:
		return
	_connect_awareness(page)
	# Si hay un evento en curso (pausa), la página nueva no arranca hasta resume().
	if _paused:
		return
	match page.movement_type:
		MovementTypeEnum.Type.RANDOM, MovementTypeEnum.Type.RANDOM_VERTICAL, \
		MovementTypeEnum.Type.RANDOM_HORIZONTAL:
			_start_timer(page.random_move_interval_min, page.random_move_interval_max)
		MovementTypeEnum.Type.PATH:
			call_deferred("_path_step")
		MovementTypeEnum.Type.RANDOM_TURNING, MovementTypeEnum.Type.RANDOM_TURNING_HORIZONTAL, \
		MovementTypeEnum.Type.RANDOM_TURNING_VERTICAL:
			_start_timer(page.random_turning_interval_min, page.random_turning_interval_max)
		MovementTypeEnum.Type.LOOK_PATTERN:
			_execute_next_look_pattern()


func stop() -> void:
	_running = false
	_generation += 1
	_path_waiting = false
	if _timer != null:
		_timer.stop()
	_disconnect_awareness()


## Pausa las decisiones (p.ej. mientras corre un evento). El paso en curso termina solo.
func pause() -> void:
	_paused = true
	_generation += 1
	_path_waiting = false
	if _timer != null:
		_timer.stop()


## Reanuda tras `pause()` sin reiniciar los índices del path ni del patrón de mirada.
func resume() -> void:
	if not _running:
		return
	_paused = false
	_generation += 1
	_resume_decisions()


func set_enabled(value: bool) -> void:
	if enabled == value:
		return
	enabled = value
	if enabled and _running and not _paused:
		_resume_decisions()


## El actor terminó un paso: el path encadena el siguiente.
func notify_step_finished() -> void:
	var page: EventPage = host.get_behavior_page() if host != null else null
	if _running and page != null and page.movement_type == MovementTypeEnum.Type.PATH:
		call_deferred("_path_step")


## Tras un teletransporte el paso en curso se cancela sin step_finished: reengancha el path.
func nudge() -> void:
	notify_step_finished()


func _resume_decisions() -> void:
	var page: EventPage = host.get_behavior_page() if host != null else null
	if page == null:
		return
	match page.movement_type:
		MovementTypeEnum.Type.RANDOM, MovementTypeEnum.Type.RANDOM_VERTICAL, \
		MovementTypeEnum.Type.RANDOM_HORIZONTAL:
			_start_timer(page.random_move_interval_min, page.random_move_interval_max)
		MovementTypeEnum.Type.PATH:
			call_deferred("_path_step")
		MovementTypeEnum.Type.RANDOM_TURNING, MovementTypeEnum.Type.RANDOM_TURNING_HORIZONTAL, \
		MovementTypeEnum.Type.RANDOM_TURNING_VERTICAL:
			_start_timer(page.random_turning_interval_min, page.random_turning_interval_max)
		MovementTypeEnum.Type.LOOK_PATTERN:
			_start_timer(page.look_pattern_delay, page.look_pattern_delay)


func _can_decide() -> bool:
	return _running and enabled and not _paused and host != null


func _start_timer(min_s: float, max_s: float) -> void:
	if _timer == null:
		return
	var lo := maxf(0.05, minf(min_s, max_s))
	var hi := maxf(lo, maxf(min_s, max_s))
	_timer.start(randf_range(lo, hi))


# --- Timer (random / turning / look pattern) ---

func _on_timer_timeout() -> void:
	var page: EventPage = host.get_behavior_page() if host != null else null
	if page == null or not _running:
		return
	if not _can_decide():
		# Pausado/deshabilitado: se reanuda en resume() / set_enabled().
		return
	match page.movement_type:
		MovementTypeEnum.Type.RANDOM:
			_random_action(page, true, true)
			_start_timer(page.random_move_interval_min, page.random_move_interval_max)
		MovementTypeEnum.Type.RANDOM_VERTICAL:
			_random_action(page, true, false, [Vector2i.UP, Vector2i.DOWN])
			_start_timer(page.random_move_interval_min, page.random_move_interval_max)
		MovementTypeEnum.Type.RANDOM_HORIZONTAL:
			_random_action(page, true, false, [Vector2i.LEFT, Vector2i.RIGHT])
			_start_timer(page.random_move_interval_min, page.random_move_interval_max)
		MovementTypeEnum.Type.RANDOM_TURNING:
			host.actor_face(_pick([Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]))
			_start_timer(page.random_turning_interval_min, page.random_turning_interval_max)
		MovementTypeEnum.Type.RANDOM_TURNING_HORIZONTAL:
			host.actor_face(_pick([Vector2i.LEFT, Vector2i.RIGHT]))
			_start_timer(page.random_turning_interval_min, page.random_turning_interval_max)
		MovementTypeEnum.Type.RANDOM_TURNING_VERTICAL:
			host.actor_face(_pick([Vector2i.UP, Vector2i.DOWN]))
			_start_timer(page.random_turning_interval_min, page.random_turning_interval_max)
		MovementTypeEnum.Type.LOOK_PATTERN:
			_execute_next_look_pattern()


## Acción aleatoria: mover (solo a celdas posibles y, si la página lo pide, dentro de
## `random_movement_valid_tiles`) o mirar. `dirs` limita los ejes (vacío = 4 direcciones).
func _random_action(page: EventPage, allow_move: bool, allow_look: bool, dirs: Array = []) -> void:
	if host.is_actor_moving():
		return
	if dirs.is_empty():
		dirs = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	var options: Array = []
	if allow_move:
		var cell: Vector2i = host.get_actor_cell()
		for d in dirs:
			if not page.random_movement_valid_tiles.is_empty() \
					and not page.random_movement_valid_tiles.has(cell + d):
				continue
			if host.actor_can_step(d):
				options.append({"move": true, "dir": d})
	if allow_look:
		for d in dirs:
			options.append({"move": false, "dir": d})
	if options.is_empty():
		return
	var choice: Dictionary = options[randi() % options.size()]
	if choice["move"]:
		host.actor_step(choice["dir"])
	else:
		host.actor_face(choice["dir"])


func _pick(options: Array) -> Vector2i:
	return options[randi() % options.size()]


# --- Look pattern ---

func _execute_next_look_pattern() -> void:
	var page: EventPage = host.get_behavior_page()
	if page == null or page.look_pattern_directions.is_empty():
		return
	var dirs := page.look_pattern_directions
	_look_index = _look_index % dirs.size()
	var cmd: int = dirs[_look_index]
	if DirectionEnum.is_movement(cmd):
		push_warning("NPCBehavior: LookPattern contiene un comando de movimiento; solo debe tener LOOK_*.")
	else:
		var d := _dir_from_enum(cmd)
		if d != Vector2i.ZERO:
			host.actor_face(d)
	_look_index = (_look_index + 1) % dirs.size()
	_start_timer(page.look_pattern_delay, page.look_pattern_delay)


# --- Path ---

func _path_step() -> void:
	if not _can_decide() or _path_waiting or host.is_actor_moving():
		return
	var page: EventPage = host.get_behavior_page()
	if page == null or page.movement_type != MovementTypeEnum.Type.PATH or page.path_directions.is_empty():
		return
	var dirs := page.path_directions
	_path_index = _path_index % dirs.size()
	var cmd: int = dirs[_path_index]
	var next_index := (_path_index + 1) % dirs.size()

	if DirectionEnum.is_movement(cmd):
		var d := _dir_from_enum(cmd)
		host.actor_face(d)
		if host.actor_can_step(d):
			_path_index = next_index
			# El siguiente comando se encadena en notify_step_finished().
			host.actor_step(d)
		else:
			await _path_delay(PATH_BLOCKED_RETRY)
	elif DirectionEnum.is_wait(cmd):
		_path_index = next_index
		await _path_delay(DirectionEnum.get_wait_duration(cmd))
	elif DirectionEnum.is_speed_change(cmd):
		_path_index = next_index
		host.actor_set_speed(MoveSpeedEnum.to_multiplier(DirectionEnum.to_speed_enum(cmd)))
		call_deferred("_path_step")
	elif cmd == DirectionEnum.Type.LOOK_PLAYER:
		_path_index = next_index
		var toward := _dir_toward_player()
		if toward != Vector2i.ZERO:
			host.actor_face(toward)
		await _path_delay(PATH_LOOK_DELAY)
	elif cmd == DirectionEnum.Type.EXCLAMATION_ANIM:
		# Sin equivalente 3D todavía: se salta.
		_path_index = next_index
		call_deferred("_path_step")
	else:
		# LOOK_* y TURN_*: solo orientar.
		_path_index = next_index
		var look := _dir_from_enum(cmd)
		if look != Vector2i.ZERO:
			host.actor_face(look)
		await _path_delay(PATH_LOOK_DELAY)


## Espera `seconds` y reencadena el path, salvo que se haya parado/pausado/reiniciado mientras tanto.
func _path_delay(seconds: float) -> void:
	_path_waiting = true
	var gen := _generation
	await get_tree().create_timer(maxf(0.0, seconds)).timeout
	if gen != _generation:
		return
	_path_waiting = false
	_path_step()


# --- Awareness ---

func _connect_awareness(page: EventPage) -> void:
	_disconnect_awareness()
	if not page.awareness_enabled:
		return
	# Solo en tipos que no se mueven (como en 2D).
	if page.movement_type not in [MovementTypeEnum.Type.NONE, MovementTypeEnum.Type.RANDOM_TURNING,
			MovementTypeEnum.Type.LOOK_PATTERN, MovementTypeEnum.Type.RANDOM_TURNING_HORIZONTAL,
			MovementTypeEnum.Type.RANDOM_TURNING_VERTICAL]:
		return
	var player_motion: Object = host.get_player_motion()
	if player_motion != null and player_motion.has_signal("step_finished"):
		player_motion.connect("step_finished", _on_player_moved)
		_awareness_motion = player_motion


func _disconnect_awareness() -> void:
	if _awareness_motion != null and is_instance_valid(_awareness_motion) \
			and _awareness_motion.is_connected("step_finished", _on_player_moved):
		_awareness_motion.disconnect("step_finished", _on_player_moved)
	_awareness_motion = null


func _on_player_moved(_arg = null) -> void:
	if not _can_decide() or host.is_actor_moving():
		return
	var page: EventPage = host.get_behavior_page()
	if page == null or not page.awareness_enabled:
		return
	var player_cell: Vector2i = host.get_player_cell()
	if player_cell == Vector2i.MAX:
		return
	var npc_cell: Vector2i = host.get_actor_cell()
	if Vector2(npc_cell).distance_to(Vector2(player_cell)) > page.awareness_detection_distance:
		return
	var chance := page.awareness_chance
	if host.is_player_running():
		chance *= page.awareness_running_multiplier
	if randf() < chance:
		var toward := _dir_toward_player()
		if toward != Vector2i.ZERO:
			host.actor_face(toward)


# --- Utilidades ---

## Dirección cardinal predominante hacia el player (ZERO si no hay player o misma celda).
func _dir_toward_player() -> Vector2i:
	var player_cell: Vector2i = host.get_player_cell()
	if player_cell == Vector2i.MAX:
		return Vector2i.ZERO
	return direction_toward(host.get_actor_cell(), player_cell)


## Dirección cardinal predominante de `from` a `to` (empates → vertical, como en 2D).
static func direction_toward(from: Vector2i, to: Vector2i) -> Vector2i:
	var diff := to - from
	if diff == Vector2i.ZERO:
		return Vector2i.ZERO
	if absi(diff.x) > absi(diff.y):
		return Vector2i.RIGHT if diff.x > 0 else Vector2i.LEFT
	return Vector2i.DOWN if diff.y > 0 else Vector2i.UP


## DirectionEnum → dirección en celdas (UP = (0,-1)). ZERO para comandos sin dirección.
static func _dir_from_enum(cmd: int) -> Vector2i:
	var v := DirectionEnum.to_vector2(cmd)
	return Vector2i(int(v.x), int(v.y))
