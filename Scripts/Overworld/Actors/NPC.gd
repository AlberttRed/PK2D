extends Event
class_name NPC

## Sistema de NPCs como extensión de Event
## 
## Los NPCs pueden comportarse como eventos interactivos (diálogos, combates, cutscenes)
## manteniendo compatibilidad total con el sistema de eventos, pero añadiendo capacidades
## de movimiento, animación y colisión mediante GridMotion, Occupancy y ActorAnimator.

## Tipo de movimiento del NPC
@export_enum("None", "Random", "Path", "RandomTurning", "LookPattern") var movement_type: int = 0

## Comportamiento de orientación al interactuar
@export_enum("Face Player", "Fixed", "Face and Restore") var orientation_behavior: int = 0

## Dirección inicial del NPC
@export_enum("Up", "Down", "Left", "Right") var initial_direction: int = 1  # 1 = Down

## Velocidad de movimiento del NPC
@export_enum("Slowest", "Slower", "Normal", "Faster", "Fastest") var movement_speed: int = 2  # 2 = Normal

@export_group("Random Movement")
## Tiempo mínimo entre movimientos aleatorios (en segundos)
@export var random_move_interval_min: float = 2.0
## Tiempo máximo entre movimientos aleatorios (en segundos)
@export var random_move_interval_max: float = 5.0

@export_group("Path Movement")
## Array de direcciones a seguir en bucle (UP, DOWN, LEFT, RIGHT, LOOK_UP, LOOK_DOWN, LOOK_LEFT, LOOK_RIGHT)
@export var path_directions: Array[DirectionEnum.Type] = []

@export_group("")  # Cerrar el grupo

@export_group("Look Pattern")
## Array de direcciones de mirada a seguir en bucle (LOOK_UP, LOOK_DOWN, LOOK_LEFT, LOOK_RIGHT)
@export var look_pattern_directions: Array[DirectionEnum.Type] = []
## Tiempo en segundos que el NPC mira en cada dirección antes de cambiar
@export var look_pattern_delay: float = 2.0

@export_group("")  # Cerrar el grupo

# === PROPIEDADES PARA RANDOM TURNING ===
@export_group("Random Turning", "random_turning_")
## Intervalo mínimo entre giros aleatorios
@export var random_turning_interval_min: float = 2.0
## Intervalo máximo entre giros aleatorios
@export var random_turning_interval_max: float = 5.0

# === PROPIEDADES PARA AWARENESS (DETECCIÓN DE JUGADOR) ===
@export_group("Player Awareness", "awareness_")
## Si está activo, el NPC puede detectar y girar hacia el jugador
@export var awareness_enabled: bool = false
## Probabilidad base de girar hacia el jugador (0.0 a 1.0)
@export var awareness_chance: float = 0.3
## Multiplicador de probabilidad cuando el jugador corre
@export var awareness_running_multiplier: float = 2.0
## Distancia máxima para detectar al jugador (en tiles)
@export var awareness_detection_distance: float = 3.0

@export_group("")  # Cerrar el grupo

## Ruta convertida a Vector2 (uso interno)
var _path_directions_vector2: Array[Vector2] = []

## Patrón de mirada (uso interno)
var _look_pattern_index: int = 0

## Componentes del NPC
@onready var motion: GridMotion = $GridMotion
@onready var animator = $ActorAnimator  # ActorAnimator (sin tipo explícito por compatibilidad del linter)

## Estado interno para movimiento
var movement_enabled: bool = true
var path_index: int = 0
var looking_at_player: bool = false
var _movement_paused: bool = false  # Flag para pausar movimiento durante comandos

## Timers para gestión eficiente de movimiento
var _random_timer: Timer
var _look_delay_timer: Timer
var _random_turning_timer: Timer
var _look_pattern_timer: Timer

func _ready() -> void:
	# El NPC usa ActorAnimator en lugar del sprite directo de Event
	# Ocultar el sprite del Event si existe para evitar duplicados
	if has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.visible = false
	
	super._ready()
	
	# Ocultar el sprite por defecto del Event base si está usando DefaultNPCSprite
	_hide_default_npc_sprite_if_needed()
	
	# Configurar dirección inicial y velocidad
	if motion:
		motion.dir = DirectionEnum.to_vector2(initial_direction)
		motion.base_speed = MoveSpeedEnum.to_multiplier(movement_speed)
	
	# Configurar animación idle inicial
	if animator:
		animator.idle(DirectionEnum.to_vector2(initial_direction))
	
	# Conectar señales de GridMotion
	if motion:
		motion.step_started.connect(_on_step_started)
		motion.step_finished.connect(_on_step_finished)
	
	# Conectar señales del sistema de eventos
	SignalManager.event_finished.connect(_on_event_finished)
	
	# Conectar a la señal step_finished del Player si el awareness está activo
	if awareness_enabled and movement_type in [0, 3, 4]:  # NONE, RANDOM_TURNING, LOOK_PATTERN
		_connect_to_player_movement()
	
	# Convertir el path de enum a Vector2 (2 = PATH)
	if movement_type == 2:
		_convert_path_to_vector2()
	
	# Reemplazar el sprite del Event con el ActorAnimator
	# Si el evento tiene sprite_frames configurados en su página, aplicarlos al animator
	_update_animator_from_current_page()
	
	# Configurar timers según el tipo de movimiento
	_setup_timers()
	
	# Iniciar path movement si corresponde
	if movement_type == 2:
		_try_execute_next_path_action()

## Override del trigger() de Event para pausar movimiento
func trigger() -> void:
	SignalManager.player_control_blocked.emit()
	if motion.moving:
		await motion.step_finished
	# Pausar movimiento antes de ejecutar comandos
	_pause_movement()
	
	# Manejar orientación según el comportamiento
	match orientation_behavior:
		OrientationBehaviorEnum.Type.FACE_PLAYER:
			_face_player()
		OrientationBehaviorEnum.Type.FIXED:
			# No hacer nada, mantener dirección actual
			pass
		OrientationBehaviorEnum.Type.FACE_AND_RESTORE:
			_face_player()
	
	# Llamar al trigger() de la clase padre
	SignalManager.player_control_unblocked.emit()
	super.trigger()

func _process(_delta: float) -> void:
	# Los timers manejan todo ahora, no necesitamos _process
	pass

## Actualiza el animator con el sprite_frames de la página actual del evento
func _update_animator_from_current_page() -> void:
	if not animator:
		return
	
	if current_page:
		# Usar el método get_sprite_frames() que soporta generación automática
		var frames = current_page.get_sprite_frames()
		if frames:
			animator.set_sprite_frames(frames)
			animator.show_sprite()
			
			# Configurar la dirección inicial después de asignar los frames
			if motion:
				var initial_dir = motion.dir if motion.dir != Vector2.ZERO else DirectionEnum.to_vector2(initial_direction)
				animator.idle(initial_dir)
		else:
			animator.hide_sprite()
	else:
		animator.hide_sprite()

## Override del método de Event para actualizar también el animator
func update_sprite_from_current_page() -> void:
	super.update_sprite_from_current_page()
	_update_animator_from_current_page()

## Configura los timers según el tipo de movimiento
func _setup_timers() -> void:
	# Timer para movimiento aleatorio (solo para Random)
	if movement_type == 1:  # RANDOM
		_random_timer = Timer.new()
		add_child(_random_timer)
		_random_timer.timeout.connect(_on_random_timer_timeout)
		_random_timer.start(randf_range(random_move_interval_min, random_move_interval_max))
	
	# Timer para giro aleatorio (solo para RandomTurning)
	elif movement_type == 3:  # RANDOM_TURNING
		_random_turning_timer = Timer.new()
		add_child(_random_turning_timer)
		_random_turning_timer.timeout.connect(_on_random_turning_timer_timeout)
		_random_turning_timer.start(randf_range(random_turning_interval_min, random_turning_interval_max))
	
	# Timer para patrón de mirada (solo para LookPattern)
	elif movement_type == 4:  # LOOK_PATTERN
		_look_pattern_timer = Timer.new()
		add_child(_look_pattern_timer)
		_look_pattern_timer.timeout.connect(_on_look_pattern_timer_timeout)
		if not look_pattern_directions.is_empty():
			# Ejecutar primera mirada inmediatamente, luego el timer
			_execute_next_look_pattern()

## Conecta a la señal step_finished del Player para awareness
func _connect_to_player_movement() -> void:
	# Buscar al jugador
	var player = get_tree().get_first_node_in_group("Player")
	if player and player.has_node("GridMotion"):
		var player_motion = player.get_node("GridMotion")
		if player_motion:
			player_motion.step_finished.connect(_on_player_moved)

## Callback del timer de movimiento aleatorio
func _on_random_timer_timeout() -> void:
	if not movement_enabled or motion.moving or _movement_paused:
		return
	
	# Todas las acciones disponibles (movimiento + LOOK)
	var actions_to_use = [
		DirectionEnum.Type.UP, DirectionEnum.Type.DOWN, 
		DirectionEnum.Type.LEFT, DirectionEnum.Type.RIGHT,
		DirectionEnum.Type.LOOK_UP, DirectionEnum.Type.LOOK_DOWN, 
		DirectionEnum.Type.LOOK_LEFT, DirectionEnum.Type.LOOK_RIGHT
	]
	
	# Elegir una acción aleatoria
	var random_action = actions_to_use[randi() % actions_to_use.size()]
	var direction = DirectionEnum.to_vector2(random_action)
	
	# Ejecutar según sea movimiento o LOOK
	if DirectionEnum.is_movement(random_action):
		# Movimiento normal: usar GridMotion
		motion.hold_time = motion.initial_delay
		motion.try_step(direction)
	else:
		# Comando LOOK: solo girar sin moverse
		motion.hold_time = 0.0
		motion.try_step(direction)
	
	# Reiniciar timer con intervalo aleatorio
	_random_timer.start(randf_range(random_move_interval_min, random_move_interval_max))

## Callback del timer de giro aleatorio (RandomTurning)
func _on_random_turning_timer_timeout() -> void:
	if not movement_enabled or _movement_paused:
		return
	
	# Solo comandos LOOK (sin movimiento)
	var look_actions = [
		DirectionEnum.Type.LOOK_UP, DirectionEnum.Type.LOOK_DOWN, 
		DirectionEnum.Type.LOOK_LEFT, DirectionEnum.Type.LOOK_RIGHT
	]
	
	# Elegir una dirección aleatoria para mirar
	var random_look = look_actions[randi() % look_actions.size()]
	var direction = DirectionEnum.to_vector2(random_look)
	
	# Solo girar sin moverse
	motion.face(direction)
	animator.idle(direction)
	
	# Reiniciar timer con intervalo aleatorio
	_random_turning_timer.start(randf_range(random_turning_interval_min, random_turning_interval_max))

## Callback del timer de Look Pattern
func _on_look_pattern_timer_timeout() -> void:
	if not movement_enabled or _movement_paused:
		return
	
	_execute_next_look_pattern()

## Ejecuta la siguiente dirección del patrón de mirada
func _execute_next_look_pattern() -> void:
	if look_pattern_directions.is_empty():
		return
	
	# Obtener la dirección actual del patrón
	var look_direction_enum = look_pattern_directions[_look_pattern_index]
	var look_direction = DirectionEnum.to_vector2(look_direction_enum)
	
	# Validar que sea un comando LOOK
	if not DirectionEnum.is_movement(look_direction_enum):
		# Girar hacia la dirección
		motion.face(look_direction)
		if animator:
			animator.idle(look_direction)
	else:
		push_warning("NPC: Look Pattern contiene comandos de movimiento. Solo debe contener LOOK_UP/DOWN/LEFT/RIGHT")
	
	# Avanzar al siguiente índice (bucle infinito)
	_look_pattern_index = (_look_pattern_index + 1) % look_pattern_directions.size()
	
	# Iniciar timer para la siguiente mirada
	_look_pattern_timer.start(look_pattern_delay)

## Callback cuando el jugador se mueve (para awareness)
func _on_player_moved(_tile_pos: Vector2) -> void:
	if not movement_enabled or _movement_paused or not awareness_enabled:
		return
	
	# Solo activar en tipos sin movimiento
	if movement_type not in [0, 3, 4]:  # NONE, RANDOM_TURNING, LOOK_PATTERN
		return
	
	# OPTIMIZACIÓN: Verificar distancia con tiles ANTES de buscar el player
	var npc_tile = motion.current_tile()
	var distance_tiles = npc_tile.distance_to(_tile_pos)
	
	# Early return si está muy lejos (evita búsquedas costosas)
	if distance_tiles > awareness_detection_distance:
		return
	
	# Solo si está cerca, buscar el player
	var player = get_tree().get_first_node_in_group("Player")
	if not player:
		return
	
	# Calcular distancia exacta en píxeles para mayor precisión
	var distance_in_pixels = global_position.distance_to(player.global_position)
	var detection_distance_pixels = awareness_detection_distance * 32
	
	if distance_in_pixels > detection_distance_pixels:
		return
	
	# Calcular probabilidad de giro
	var chance = awareness_chance
	
	# Aumentar probabilidad si el jugador está corriendo
	if player.has_node("GridMotion"):
		var player_motion = player.get_node("GridMotion")
		if player_motion and player_motion.is_running:
			chance *= awareness_running_multiplier
	
	# Verificar si debe girar
	if randf() < chance:
		# Calcular dirección hacia el jugador
		var direction_to_player = (player.global_position - global_position).normalized()
		var look_direction = _get_closest_direction(direction_to_player)
		
		# Girar hacia el jugador
		motion.face(look_direction)
		if animator:
			animator.idle(look_direction)

## Obtiene la dirección más cercana a un vector dado
func _get_closest_direction(direction: Vector2) -> Vector2:
	var directions = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
	var closest_dir = Vector2.UP
	var max_dot = -1.0
	
	for dir in directions:
		var dot = direction.dot(dir)
		if dot > max_dot:
			max_dot = dot
			closest_dir = dir
	
	return closest_dir

## Convierte el array de enum a Vector2
func _convert_path_to_vector2() -> void:
	_path_directions_vector2.clear()
	for dir_enum in path_directions:
		match dir_enum:
			DirectionEnum.Type.UP: _path_directions_vector2.append(Vector2.UP)
			DirectionEnum.Type.DOWN: _path_directions_vector2.append(Vector2.DOWN)
			DirectionEnum.Type.LEFT: _path_directions_vector2.append(Vector2.LEFT)
			DirectionEnum.Type.RIGHT: _path_directions_vector2.append(Vector2.RIGHT)
			DirectionEnum.Type.LOOK_UP: _path_directions_vector2.append(Vector2.UP)
			DirectionEnum.Type.LOOK_DOWN: _path_directions_vector2.append(Vector2.DOWN)
			DirectionEnum.Type.LOOK_LEFT: _path_directions_vector2.append(Vector2.LEFT)
			DirectionEnum.Type.LOOK_RIGHT: _path_directions_vector2.append(Vector2.RIGHT)
			_: push_warning("NPC: Dirección inválida en path_directions: %d" % dir_enum)

## Intenta ejecutar la siguiente acción del path
func _try_execute_next_path_action() -> void:
	if not movement_enabled or motion.moving or _path_directions_vector2.is_empty() or _movement_paused:
		return
	
	# Obtener el comando actual de la ruta (enum y vector)
	var dir_enum = path_directions[path_index]
	var direction = _path_directions_vector2[path_index]
	
	# Verificar si es un comando LOOK (solo girar) o movimiento real
	if DirectionEnum.is_movement(dir_enum):

		var from = motion.current_tile()
		var to = from + Vector2i(direction)
		var can_step = motion.grid.can_step_to(motion.actor, from, to)

		# Movimiento normal: usar GridMotion
		motion.face(direction)
		animator.idle(direction)

		if can_step:
			# Avanzar solo si empezó a moverse
			motion.try_step(direction)
			path_index = (path_index + 1) % _path_directions_vector2.size()
		else:
			await get_tree().create_timer(0.5).timeout

	else:
		# Comando LOOK: solo girar sin moverse
		motion.face(direction)
		animator.idle(direction)
		path_index = (path_index + 1) % _path_directions_vector2.size()
		await get_tree().create_timer(0.5).timeout
	call_deferred("_try_execute_next_path_action")


## Procesa el comportamiento de mirar al jugador

## Hace que el NPC mire hacia el jugador
func _face_player() -> void:
	# Buscar al jugador
	var player = get_tree().get_first_node_in_group("Player")
	if not player or not motion:
		return
	
	# Calcular dirección hacia el jugador
	var player_tile = motion.grid.world_to_tile(player.global_position)
	var npc_tile = motion.current_tile()
	var diff = player_tile - npc_tile
	
	# Determinar la dirección predominante
	var new_direction = Vector2.ZERO
	if abs(diff.x) > abs(diff.y):
		new_direction = Vector2.RIGHT if diff.x > 0 else Vector2.LEFT
	else:
		new_direction = Vector2.DOWN if diff.y > 0 else Vector2.UP
	
	# Solo actualizar si cambió la dirección
	if new_direction != motion.dir:
		motion.face(new_direction)
		if animator:
			animator.idle(new_direction)

## Callback cuando GridMotion inicia un paso
func _on_step_started() -> void:
	if not animator or not motion:
		return
	
	var use_run: bool = (motion.speed_multiplier > 1.0 and not motion.initial_step)
	var prefix := "run" if use_run else "walk"
	var stride := ("left" if motion.stride_is_left else "right")
	
	animator.set_direction(motion.dir, prefix, stride)
	animator.set_speed_scale(motion.speed_multiplier)

## Callback cuando GridMotion finaliza un paso
func _on_step_finished(_tile: Vector2i) -> void:
	if animator:
		animator.idle(motion.dir)
	
	# Para Path movement, intentar ejecutar la siguiente acción
	# Usar call_deferred para esperar a que GridMotion alterne el stride_is_left
	if movement_type == 2:  # PATH
		call_deferred("_try_execute_next_path_action")

## Detiene el movimiento del NPC
func stop_movement() -> void:
	if motion:
		motion.moving = false
	if animator:
		animator.idle(motion.dir)

## Habilita o deshabilita el movimiento del NPC
func set_movement_enabled(enabled: bool) -> void:
	movement_enabled = enabled
	if not enabled:
		stop_movement()

## Teletransporta el NPC a una posición específica
func teleport_to_tile(tile: Vector2i) -> void:
	if has_node("Occupancy"):
		$Occupancy.teleport_to_tile(tile)
	else:
		# Fallback: teletransporte directo
		if motion and motion.grid:
			global_position = motion.grid.tile_to_world_center(tile)

## Establece la dirección que mira el NPC
func set_facing_direction(new_direction: Vector2) -> void:
	if motion:
		motion.dir = new_direction
	if animator:
		animator.idle(new_direction)

## Pausa el movimiento del NPC cuando se activa un comando
func _pause_movement() -> void:
	_movement_paused = true
	
	# Detener timers si están activos
	if _random_timer and _random_timer.time_left > 0:
		_random_timer.stop()
	if _look_delay_timer and _look_delay_timer.time_left > 0:
		_look_delay_timer.stop()
	if _random_turning_timer and _random_turning_timer.time_left > 0:
		_random_turning_timer.stop()
	if _look_pattern_timer and _look_pattern_timer.time_left > 0:
		_look_pattern_timer.stop()
	
	print("NPC: Movimiento pausado para ejecutar comandos")

## Reanuda el movimiento del NPC cuando terminan los comandos
func _resume_movement() -> void:
	_movement_paused = false
	
	# Reiniciar timers según el tipo de movimiento
	if movement_type == 1 and _random_timer:  # RANDOM
		_random_timer.start(randf_range(random_move_interval_min, random_move_interval_max))
	elif movement_type == 2:  # PATH
		# Reanudar path movement
		call_deferred("_try_execute_next_path_action")
	elif movement_type == 3 and _random_turning_timer:  # RANDOM_TURNING
		_random_turning_timer.start(randf_range(random_turning_interval_min, random_turning_interval_max))
	elif movement_type == 4 and _look_pattern_timer:  # LOOK_PATTERN
		_look_pattern_timer.start(look_pattern_delay)
	
	print("NPC: Movimiento reanudado")

## Callback cuando termina un evento (para reanudar movimiento)
func _on_event_finished(_event: Event) -> void:
	# Solo reanudar si este NPC estaba pausado
	if _movement_paused:
		# Restaurar dirección inicial si es necesario
		if orientation_behavior == OrientationBehaviorEnum.Type.FACE_AND_RESTORE:
			var initial_dir = DirectionEnum.to_vector2(initial_direction)
			motion.dir = initial_dir
			if animator:
				animator.idle(initial_dir)
		
		_resume_movement()

## Oculta el sprite por defecto si el NPC está usando DefaultNPCSprite (solo visible en editor)
func _hide_default_npc_sprite_if_needed() -> void:
	# El NPC usa ActorAnimator, así que verificamos si el sprite del Event base está visible
	if not sprite or not sprite.sprite_frames:
		return
	
	# Verificar si está usando el sprite por defecto de NPC
	var is_using_default = _is_using_default_npc_sprite()
	
	if is_using_default:
		# Ocultar el sprite durante la ejecución del juego
		sprite.visible = false
		print("NPC '%s': DefaultNPCSprite ocultado en ejecución (usando ActorAnimator)" % name)

## Verifica si el NPC está usando el sprite por defecto
func _is_using_default_npc_sprite() -> bool:
	if not sprite or not sprite.sprite_frames:
		return false
	
	# Obtener la ruta del sprite actual
	var current_sprite_path = sprite.sprite_frames.resource_path
	
	# Verificar si coincide con el sprite por defecto de NPC
	var default_sprite_path = "res://Sprites/Eventos/DefaultNPCSprite.png"
	
	# Verificar por el nombre del recurso
	if current_sprite_path.find("DefaultNPCSprite") != -1:
		return true
	
	# Verificar si la primera animación usa la textura por defecto
	if sprite.sprite_frames.has_animation("default"):
		var frame_count = sprite.sprite_frames.get_frame_count("default")
		if frame_count > 0:
			var frame_texture = sprite.sprite_frames.get_frame_texture("default", 0)
			if frame_texture and frame_texture.resource_path == default_sprite_path:
				return true
	
	return false
