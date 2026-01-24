extends Event
class_name NPC

## Sistema de NPCs como extensión de Event
##
## Los NPCs pueden comportarse como eventos interactivos (diálogos, combates, cutscenes)
## manteniendo compatibilidad total con el sistema de eventos, pero añadiendo capacidades
## de movimiento, animación y colisión mediante GridMotion, Occupancy y ActorAnimator.

## Establece el contexto del Overworld (llamado desde OverworldGrid)
func set_overworld_context(context: OverworldContext) -> void:
	overworld_context = context
	super.set_overworld_context(context)

	# Propagar a componentes hijos si existen
	var grid_motion = get_node_or_null("GridMotion")
	if grid_motion and grid_motion.has_method("set_context"):
		grid_motion.set_context(context)

	var occupancy = get_node_or_null("Occupancy")
	if occupancy and occupancy.has_method("set_context"):
		occupancy.set_context(context)

	# Conectar a las señales locales del EventSystem para reanudar movimiento
	if overworld_context:
		var event_sys = overworld_context.get_event_system()
		if event_sys and not event_sys.event_finished.is_connected(_on_event_finished):
			event_sys.event_finished.connect(_on_event_finished)

## Helper para obtener el OverworldContext
func _get_context() -> OverworldContext:
	return overworld_context

## Obtiene el movement_type desde current_page
func get_movement_type() -> int:
	if current_page:
		return current_page.movement_type
	# Fallback por si no hay página actual (no debería pasar en uso normal)
	return 0  # None

## Obtiene el orientation_behavior desde current_page
func get_orientation_behavior() -> int:
	if current_page:
		return current_page.orientation_behavior
	# Fallback por si no hay página actual (no debería pasar en uso normal)
	return 0  # Face Player

## Obtiene el initial_direction desde current_page
func get_initial_direction() -> int:
	if current_page:
		return current_page.initial_direction
	# Fallback por si no hay página actual (no debería pasar en uso normal)
	return 1  # Down

## Obtiene el movement_speed desde current_page
func get_movement_speed() -> int:
	if current_page:
		return current_page.movement_speed
	# Fallback por si no hay página actual (no debería pasar en uso normal)
	return 2  # Normal

## Obtiene random_move_interval_min desde current_page
func get_random_move_interval_min() -> float:
	if current_page:
		return current_page.random_move_interval_min
	return 2.0

## Obtiene random_move_interval_max desde current_page
func get_random_move_interval_max() -> float:
	if current_page:
		return current_page.random_move_interval_max
	return 5.0

## Obtiene path_directions desde current_page
func get_path_directions() -> Array[DirectionEnum.Type]:
	if current_page:
		return current_page.path_directions
	return []

## Obtiene look_pattern_directions desde current_page
func get_look_pattern_directions() -> Array[DirectionEnum.Type]:
	if current_page:
		return current_page.look_pattern_directions
	return []

## Obtiene look_pattern_delay desde current_page
func get_look_pattern_delay() -> float:
	if current_page:
		return current_page.look_pattern_delay
	return 2.0

## Obtiene random_turning_interval_min desde current_page
func get_random_turning_interval_min() -> float:
	if current_page:
		return current_page.random_turning_interval_min
	return 2.0

## Obtiene random_turning_interval_max desde current_page
func get_random_turning_interval_max() -> float:
	if current_page:
		return current_page.random_turning_interval_max
	return 5.0

## Obtiene awareness_enabled desde current_page
func get_awareness_enabled() -> bool:
	if current_page:
		return current_page.awareness_enabled
	return false

## Obtiene awareness_chance desde current_page
func get_awareness_chance() -> float:
	if current_page:
		return current_page.awareness_chance
	return 0.3

## Obtiene awareness_running_multiplier desde current_page
func get_awareness_running_multiplier() -> float:
	if current_page:
		return current_page.awareness_running_multiplier
	return 2.0

## Obtiene awareness_detection_distance desde current_page
func get_awareness_detection_distance() -> float:
	if current_page:
		return current_page.awareness_detection_distance
	return 3.0

## Ruta convertida a Vector2 (uso interno)
var _path_directions_vector2: Array[Vector2] = []

## Patrón de mirada (uso interno)
var _look_pattern_index: int = 0

## Datos del sprite de la página anterior (para comparar si hay cambio de sprite)
var _previous_page_sprite_data: Dictionary = {}

## Componentes del NPC
var motion: GridMotion
var animator: ActorAnimator  # Heredado de Event

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
var _random_vertical_timer: Timer
var _random_horizontal_timer: Timer
var _random_turning_horizontal_timer: Timer
var _random_turning_vertical_timer: Timer

func _ready() -> void:
	super._ready()

	# Obtener referencias a los componentes (después de super._ready())
	motion = $GridMotion
	animator = actor_animator  # Usar el ActorAnimator heredado de Event

	# Configurar dirección inicial y velocidad (leer desde current_page si está disponible)
	if motion:
		motion.dir = DirectionEnum.to_vector2(get_initial_direction())
		motion.base_speed = MoveSpeedEnum.to_multiplier(get_movement_speed())

	# Configurar animación idle inicial
	if animator:
		animator.idle(DirectionEnum.to_vector2(get_initial_direction()))

	# Conectar señales de GridMotion
	if motion:
		motion.step_started.connect(_on_step_started)
		motion.step_finished.connect(_on_step_finished)

	# NO conectar awareness aquí - se conectará cuando el chunk se active
	# La conexión se hace en connect_external_signals() que se llama desde WorldChunkController

	# Convertir el path de enum a Vector2 (2 = PATH)
	if get_movement_type() == 2:
		_convert_path_to_vector2()

	# Inicializar look_pattern_index
	_look_pattern_index = 0

	# Reemplazar el sprite del Event con el ActorAnimator
	# Si el evento tiene sprite_frames configurados en su página, aplicarlos al animator
	_update_animator_from_current_page()

	# Configurar timers según el tipo de movimiento
	_setup_timers()

	# Iniciar path movement si corresponde
	# Diferir hasta que el grid esté disponible
	if get_movement_type() == 2:
		call_deferred("_deferred_start_path_movement")

## Override del trigger() de Event para pausar movimiento
func trigger() -> void:
	# Solo bloquear el player si el evento NO tiene blocks_player = true
	# Si el evento tiene blocks_player = true, el EventController lo manejará
	var should_npc_block = true
	if current_page and not current_page.blocks_player:
		# El evento no bloquea al player, el NPC debe bloquearlo temporalmente
		if overworld_context:
			overworld_context.block_player_control()
		else:
			push_warning("NPC '%s': OverworldContext no disponible para bloquear control" % name)
	else:
		# El evento tiene blocks_player = true, el EventController lo manejará
		should_npc_block = false

	if motion.moving:
		await motion.step_finished
	# Pausar movimiento antes de ejecutar comandos
	_pause_movement()

	# Manejar orientación según el comportamiento
	match get_orientation_behavior():
		OrientationBehaviorEnum.Type.FACE_PLAYER:
			_face_player()
		OrientationBehaviorEnum.Type.FIXED:
			# No hacer nada, mantener dirección actual
			pass
		OrientationBehaviorEnum.Type.FACE_AND_RESTORE:
			_face_player()

	# Llamar al trigger() de la clase padre
	super.trigger()

	# Si el evento tiene blocks_player = true, el EventController manejará el bloqueo/desbloqueo
	# No debemos desbloquear aquí porque el EventController lo hará cuando termine
	# Si el evento NO tiene blocks_player = true, el NPC debe desbloquear inmediatamente
	# porque el EventController no lo bloqueará
	if should_npc_block:
		# Esperar un frame para que el EventController tenga tiempo de empezar a ejecutar
		# Esto evita que el player se desbloquee antes de que el EventController lo bloquee
		await get_tree().process_frame
		if overworld_context:
			overworld_context.unblock_player_control()
		else:
			push_warning("NPC '%s': OverworldContext no disponible para desbloquear control" % name)

func _process(_delta: float) -> void:
	# Los timers manejan todo ahora, no necesitamos _process
	pass

## Actualiza el animator con el sprite_frames de la página actual del evento
func _update_animator_from_current_page() -> void:
	if not animator:
		return

	if current_page:
		var style: ActorStyle = current_page.actor_style
		# Para NPCs, usar offset por defecto de (0, -8) solo si no ha sido configurado explícitamente
		var offset = current_page.sprite_offset
		# Si el offset es (0, 0) y no ha sido configurado explícitamente, usar (0, -8) por defecto
		if offset == Vector2(0, 0) and not current_page.sprite_offset_configured:
			offset = Vector2(0, -8)

		if style:
			animator.apply_style(style)
			animator.set_sprite_offset(offset)
			animator.show_sprite()

			if motion:
				var initial_dir = motion.dir if motion.dir != Vector2.ZERO else DirectionEnum.to_vector2(get_initial_direction())
				animator.idle(initial_dir)
		else:
			animator.apply_style(null)
			# Usar el método get_sprite_frames() que soporta generación automática
			# Pasar el nodo NPC para que pueda detectar si es NPC y generar animaciones apropiadas
			var frames = current_page.get_sprite_frames(self)
			if frames:
				animator.set_sprite_frames(frames)
				animator.set_sprite_offset(offset)
				animator.show_sprite()

				# Configurar la dirección inicial después de asignar los frames
				if motion:
					var initial_dir = motion.dir if motion.dir != Vector2.ZERO else DirectionEnum.to_vector2(get_initial_direction())
					animator.idle(initial_dir)
			else:
				animator.hide_sprite()
	else:
		animator.apply_style(null)
		animator.hide_sprite()

## Override del método de Event para actualizar también el animator y el movimiento
func update_sprite_from_current_page() -> void:
	# Guardar datos del sprite de la página actual antes de cambiar
	# (esto se usará como "página anterior" en la próxima comparación)
	if current_page:
		_previous_page_sprite_data = _get_sprite_data_from_page(current_page)

	super.update_sprite_from_current_page()
	_update_animator_from_current_page()
	_update_movement_from_current_page()

## Actualiza los valores de movimiento cuando cambia la página actual
func _update_movement_from_current_page() -> void:
	if not current_page or not motion:
		return

	# Actualizar velocidad desde la página actual
	motion.base_speed = MoveSpeedEnum.to_multiplier(get_movement_speed())

	# Verificar si debemos preservar la dirección
	var should_preserve_direction = false
	if current_page.preserve_direction_on_sprite_match:
		# Comparar sprites entre la página anterior y la nueva
		should_preserve_direction = _has_same_sprite_as_previous_page()

	# Aplicar dirección: preservar actual o usar initial_direction
	if should_preserve_direction:
		# Mantener la dirección actual (no cambiar)
		# Solo actualizar el animator con la dirección actual
		if animator:
			animator.idle(motion.dir)
	else:
		# Aplicar la dirección inicial de la nueva página
		motion.dir = DirectionEnum.to_vector2(get_initial_direction())
		if animator:
			animator.idle(motion.dir)

	# Si cambió el tipo de movimiento, reconfigurear timers
	# Primero eliminar timers existentes
	if _random_timer:
		_random_timer.queue_free()
		_random_timer = null
	if _random_turning_timer:
		_random_turning_timer.queue_free()
		_random_turning_timer = null
	if _look_pattern_timer:
		_look_pattern_timer.queue_free()
		_look_pattern_timer = null
	if _random_turning_horizontal_timer:
		_random_turning_horizontal_timer.queue_free()
		_random_turning_horizontal_timer = null
	if _random_turning_vertical_timer:
		_random_turning_vertical_timer.queue_free()
		_random_turning_vertical_timer = null
	if _random_vertical_timer:
		_random_vertical_timer.queue_free()
		_random_vertical_timer = null
	if _random_horizontal_timer:
		_random_horizontal_timer.queue_free()
		_random_horizontal_timer = null

	# Convertir path si es necesario
	if get_movement_type() == 2:
		_convert_path_to_vector2()
		path_index = 0  # Reiniciar índice del path

	# Reiniciar look_pattern_index cuando cambia la página
	_look_pattern_index = 0

	# Actualizar conexiones de awareness si es necesario
	_disconnect_from_player_movement()
	if get_awareness_enabled() and get_movement_type() in [0, 3, 4, 7, 8]:  # NONE, RANDOM_TURNING, LOOK_PATTERN, RANDOM_TURNING_HORIZONTAL, RANDOM_TURNING_VERTICAL
		_connect_to_player_movement()

	# Reconfigurear timers según el nuevo tipo de movimiento
	_setup_timers()

	# Si es path movement, iniciarlo
	if get_movement_type() == 2:
		call_deferred("_deferred_start_path_movement")

## Verifica si la página actual tiene el mismo sprite que la página anterior
## Retorna true si los sprites son iguales (mismo actor_style, sprite_frames, o sprite_texture)
func _has_same_sprite_as_previous_page() -> bool:
	# Si no hay datos de página anterior, no hay coincidencia
	if _previous_page_sprite_data.is_empty():
		return false

	# Obtener datos del sprite de la página actual
	var current_data = _get_sprite_data_from_page(current_page)

	# Comparar datos de sprite
	return _previous_page_sprite_data == current_data

## Obtiene un identificador único del sprite de una página para comparación
func _get_sprite_data_from_page(page: EventPage) -> Dictionary:
	if not page:
		return {}

	return {
		"actor_style": page.actor_style,
		"sprite_frames": page.sprite_frames,
		"sprite_texture": page.sprite_texture,
		"is_spritesheet": page.is_spritesheet
	}

## Configura los timers según el tipo de movimiento
func _setup_timers() -> void:
	# No configurar timers si el evento no está en el árbol de escena
	# (puede ocurrir cuando se des-renderiza el mapa y se aplican cambios diferidos)
	if not is_inside_tree():
		return

	# Timer para movimiento aleatorio (solo para Random)
	if get_movement_type() == 1:  # RANDOM
		# Eliminar timer anterior si existe
		if _random_timer:
			_random_timer.queue_free()
			_random_timer = null

		_random_timer = Timer.new()
		add_child(_random_timer)
		_random_timer.timeout.connect(_on_random_timer_timeout)
		_random_timer.start(randf_range(get_random_move_interval_min(), get_random_move_interval_max()))

	# Timer para giro aleatorio (solo para RandomTurning)
	elif get_movement_type() == 3:  # RANDOM_TURNING
		_random_turning_timer = Timer.new()
		add_child(_random_turning_timer)
		_random_turning_timer.timeout.connect(_on_random_turning_timer_timeout)
		_random_turning_timer.start(randf_range(get_random_turning_interval_min(), get_random_turning_interval_max()))

	# Timer para patrón de mirada (solo para LookPattern)
	elif get_movement_type() == 4:  # LOOK_PATTERN
		_look_pattern_timer = Timer.new()
		add_child(_look_pattern_timer)
		_look_pattern_timer.timeout.connect(_on_look_pattern_timer_timeout)
		if not get_look_pattern_directions().is_empty():
			# Ejecutar primera mirada inmediatamente, luego el timer
			_execute_next_look_pattern()

	# Timer para movimiento vertical aleatorio (solo para RandomVertical)
	elif get_movement_type() == 5:  # RANDOM_VERTICAL
		_random_vertical_timer = Timer.new()
		add_child(_random_vertical_timer)
		_random_vertical_timer.timeout.connect(_on_random_vertical_timer_timeout)
		_random_vertical_timer.start(randf_range(get_random_move_interval_min(), get_random_move_interval_max()))

	# Timer para movimiento horizontal aleatorio (solo para RandomHorizontal)
	elif get_movement_type() == 6:  # RANDOM_HORIZONTAL
		_random_horizontal_timer = Timer.new()
		add_child(_random_horizontal_timer)
		_random_horizontal_timer.timeout.connect(_on_random_horizontal_timer_timeout)
		_random_horizontal_timer.start(randf_range(get_random_move_interval_min(), get_random_move_interval_max()))

## Conecta a la señal step_finished del Player para awareness
func _connect_to_player_movement() -> void:
	# Buscar al jugador del contexto
	var context = _get_context()
	var player: Node = context.get_player() if context else null
	if player and player.has_node("GridMotion"):
		var player_motion = player.get_node("GridMotion")
		if player_motion:
			if not player_motion.step_finished.is_connected(_on_player_moved):
				player_motion.step_finished.connect(_on_player_moved)

## Desconecta de la señal step_finished del Player para awareness
func _disconnect_from_player_movement() -> void:
	var context = _get_context()
	if context:
		var player = context.get_player()
		if player and is_instance_valid(player) and player.has_node("GridMotion"):
			var player_motion = player.get_node("GridMotion")
			if player_motion and is_instance_valid(player_motion):
				if player_motion.step_finished.is_connected(_on_player_moved):
					player_motion.step_finished.disconnect(_on_player_moved)

## Sobrescribe el método virtual de Event para conectar señales externas
## Se llama cuando el NPC se activa en un chunk
func connect_external_signals() -> void:
	super.connect_external_signals()
	# Conectar awareness si está habilitado
	if get_awareness_enabled() and get_movement_type() in [0, 3, 4, 7, 8]:  # NONE, RANDOM_TURNING, LOOK_PATTERN, RANDOM_TURNING_HORIZONTAL, RANDOM_TURNING_VERTICAL
		_connect_to_player_movement()

	# Reiniciar timers si están configurados (por si se detuvieron al desactivarse)
	# Usar call_deferred si el nodo no está en el árbol todavía
	if is_inside_tree():
		_start_movement_timers()
	else:
		call_deferred("_start_movement_timers")


## Inicia los timers de movimiento según el tipo configurado
func _start_movement_timers() -> void:
	if not is_inside_tree():
		return

	if get_movement_type() == 1 and _random_timer:  # RANDOM
		_random_timer.stop()
		_random_timer.start(randf_range(get_random_move_interval_min(), get_random_move_interval_max()))
	elif get_movement_type() == 3 and _random_turning_timer:  # RANDOM_TURNING
		_random_turning_timer.stop()
		_random_turning_timer.start(randf_range(get_random_turning_interval_min(), get_random_turning_interval_max()))
	elif get_movement_type() == 4 and _look_pattern_timer:  # LOOK_PATTERN
		_look_pattern_timer.stop()
		_look_pattern_timer.start(get_look_pattern_delay())
	elif get_movement_type() == 5 and _random_vertical_timer:  # RANDOM_VERTICAL
		_random_vertical_timer.stop()
		_random_vertical_timer.start(randf_range(get_random_move_interval_min(), get_random_move_interval_max()))
	elif get_movement_type() == 6 and _random_horizontal_timer:  # RANDOM_HORIZONTAL
		_random_horizontal_timer.stop()
		_random_horizontal_timer.start(randf_range(get_random_move_interval_min(), get_random_move_interval_max()))
	elif get_movement_type() == 7 and _random_turning_horizontal_timer:  # RANDOM_TURNING_HORIZONTAL
		_random_turning_horizontal_timer.stop()
		_random_turning_horizontal_timer.start(randf_range(get_random_turning_interval_min(), get_random_turning_interval_max()))
	elif get_movement_type() == 8 and _random_turning_vertical_timer:  # RANDOM_TURNING_VERTICAL
		_random_turning_vertical_timer.stop()
		_random_turning_vertical_timer.start(randf_range(get_random_turning_interval_min(), get_random_turning_interval_max()))

## Sobrescribe el método virtual de Event para desconectar señales externas
## Se llama cuando el NPC se desactiva en un chunk
func disconnect_external_signals() -> void:
	super.disconnect_external_signals()
	# Desconectar awareness
	_disconnect_from_player_movement()

## Callback del timer de movimiento aleatorio
func _on_random_timer_timeout() -> void:
	if not movement_enabled or motion.moving or _movement_paused:
		return

	# Todas las acciones disponibles (movimiento + LOOK)
	var all_actions: Array[DirectionEnum.Type] = [
		DirectionEnum.Type.UP, DirectionEnum.Type.DOWN,
		DirectionEnum.Type.LEFT, DirectionEnum.Type.RIGHT,
		DirectionEnum.Type.LOOK_UP, DirectionEnum.Type.LOOK_DOWN,
		DirectionEnum.Type.LOOK_LEFT, DirectionEnum.Type.LOOK_RIGHT
	]

	# Filtrar acciones de movimiento según celdas válidas (si están definidas)
	var actions_to_use: Array[DirectionEnum.Type] = []
	var valid_tiles: Array[Vector2i] = []

	# Obtener celdas válidas de la página actual (para RANDOM, RANDOM_VERTICAL y RANDOM_HORIZONTAL)
	var movement = get_movement_type()
	if current_page and movement in [1, 5, 6]:  # RANDOM, RANDOM_VERTICAL, RANDOM_HORIZONTAL
		valid_tiles = current_page.random_movement_valid_tiles

	# Si hay celdas válidas definidas, filtrar las acciones de movimiento
	if valid_tiles.size() > 0:
		var current_tile = motion.current_tile()

		for action in all_actions:
			if DirectionEnum.is_movement(action):
				var action_direction = DirectionEnum.to_vector2(action)
				var destination_tile = current_tile + Vector2i(action_direction)

				# Solo incluir si la celda destino está en las celdas válidas
				if destination_tile in valid_tiles:
					actions_to_use.append(action)
			else:
				# Los comandos LOOK siempre están disponibles
				actions_to_use.append(action)
	else:
		# No hay restricciones, usar todas las acciones
		actions_to_use = all_actions

	# Si no hay acciones disponibles (todas las direcciones están bloqueadas), no hacer nada
	if actions_to_use.is_empty():
		# Reiniciar timer con intervalo aleatorio
		_random_timer.start(randf_range(get_random_move_interval_min(), get_random_move_interval_max()))
		return

	# Elegir una acción aleatoria de las disponibles
	var random_action = actions_to_use[randi() % actions_to_use.size()]
	var direction = DirectionEnum.to_vector2(random_action)

	# Ejecutar según sea movimiento o LOOK
	if DirectionEnum.is_movement(random_action):
		# Movimiento normal: usar GridMotion
		motion.hold_time = motion.initial_delay
		motion.try_step(direction)
	else:
		# Comando LOOK: solo girar sin moverse
		set_facing_direction(direction)

	# Reiniciar timer con intervalo aleatorio
	_random_timer.start(randf_range(get_random_move_interval_min(), get_random_move_interval_max()))

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
	_random_turning_timer.start(randf_range(get_random_turning_interval_min(), get_random_turning_interval_max()))

## Callback del timer de Look Pattern
func _on_look_pattern_timer_timeout() -> void:
	if not movement_enabled or _movement_paused:
		return

	_execute_next_look_pattern()

## Callback del timer de movimiento vertical aleatorio (RandomVertical)
func _on_random_vertical_timer_timeout() -> void:
	if not movement_enabled or motion.moving or _movement_paused:
		return

	# Solo movimientos verticales (UP y DOWN)
	var vertical_actions: Array[DirectionEnum.Type] = [
		DirectionEnum.Type.UP,
		DirectionEnum.Type.DOWN
	]

	# Filtrar según celdas válidas si están definidas
	var valid_tiles: Array[Vector2i] = []
	if current_page:
		valid_tiles = current_page.random_movement_valid_tiles

	var actions_to_use: Array[DirectionEnum.Type] = []
	if valid_tiles.size() > 0:
		var current_tile = motion.current_tile()
		for action in vertical_actions:
			var action_direction = DirectionEnum.to_vector2(action)
			var destination_tile = current_tile + Vector2i(action_direction)
			if destination_tile in valid_tiles:
				actions_to_use.append(action)
	else:
		actions_to_use = vertical_actions

	# Si no hay acciones válidas, no hacer nada
	if actions_to_use.is_empty():
		_random_vertical_timer.start(randf_range(get_random_move_interval_min(), get_random_move_interval_max()))
		return

	# Elegir una dirección vertical aleatoria de las válidas
	var random_action = actions_to_use[randi() % actions_to_use.size()]
	var direction = DirectionEnum.to_vector2(random_action)

	# Ejecutar movimiento
	motion.hold_time = motion.initial_delay
	motion.try_step(direction)

	# Reiniciar timer con intervalo aleatorio
	_random_vertical_timer.start(randf_range(get_random_move_interval_min(), get_random_move_interval_max()))

## Callback del timer de movimiento horizontal aleatorio (RandomHorizontal)
func _on_random_horizontal_timer_timeout() -> void:
	if not movement_enabled or motion.moving or _movement_paused:
		return

	# Solo movimientos horizontales (LEFT y RIGHT)
	var horizontal_actions: Array[DirectionEnum.Type] = [
		DirectionEnum.Type.LEFT,
		DirectionEnum.Type.RIGHT
	]

	# Filtrar según celdas válidas si están definidas
	var valid_tiles: Array[Vector2i] = []
	if current_page:
		valid_tiles = current_page.random_movement_valid_tiles

	var actions_to_use: Array[DirectionEnum.Type] = []
	if valid_tiles.size() > 0:
		var current_tile = motion.current_tile()
		for action in horizontal_actions:
			var action_direction = DirectionEnum.to_vector2(action)
			var destination_tile = current_tile + Vector2i(action_direction)
			if destination_tile in valid_tiles:
				actions_to_use.append(action)
	else:
		actions_to_use = horizontal_actions

	# Si no hay acciones válidas, no hacer nada
	if actions_to_use.is_empty():
		_random_horizontal_timer.start(randf_range(get_random_move_interval_min(), get_random_move_interval_max()))
		return

	# Elegir una dirección horizontal aleatoria de las válidas
	var random_action = actions_to_use[randi() % actions_to_use.size()]
	var direction = DirectionEnum.to_vector2(random_action)

	# Ejecutar movimiento
	motion.hold_time = motion.initial_delay
	motion.try_step(direction)

	# Reiniciar timer con intervalo aleatorio
	_random_horizontal_timer.start(randf_range(get_random_move_interval_min(), get_random_move_interval_max()))

## Callback del timer de giro aleatorio horizontal (RandomTurningHorizontal)
func _on_random_turning_horizontal_timer_timeout() -> void:
	if not movement_enabled or _movement_paused:
		return

	# Solo comandos LOOK horizontal (LEFT y RIGHT)
	var look_actions = [
		DirectionEnum.Type.LOOK_LEFT,
		DirectionEnum.Type.LOOK_RIGHT
	]

	# Elegir una dirección horizontal aleatoria para mirar
	var random_look = look_actions[randi() % look_actions.size()]
	var direction = DirectionEnum.to_vector2(random_look)

	# Solo girar sin moverse
	motion.face(direction)
	animator.idle(direction)

	# Reiniciar timer con intervalo aleatorio
	_random_turning_horizontal_timer.start(randf_range(get_random_turning_interval_min(), get_random_turning_interval_max()))

## Callback del timer de giro aleatorio vertical (RandomTurningVertical)
func _on_random_turning_vertical_timer_timeout() -> void:
	if not movement_enabled or _movement_paused:
		return

	# Solo comandos LOOK vertical (UP y DOWN)
	var look_actions = [
		DirectionEnum.Type.LOOK_UP,
		DirectionEnum.Type.LOOK_DOWN
	]

	# Elegir una dirección vertical aleatoria para mirar
	var random_look = look_actions[randi() % look_actions.size()]
	var direction = DirectionEnum.to_vector2(random_look)

	# Solo girar sin moverse
	motion.face(direction)
	animator.idle(direction)

	# Reiniciar timer con intervalo aleatorio
	_random_turning_vertical_timer.start(randf_range(get_random_turning_interval_min(), get_random_turning_interval_max()))

## Ejecuta la siguiente dirección del patrón de mirada
func _execute_next_look_pattern() -> void:
	var look_pattern_dirs = get_look_pattern_directions()
	if look_pattern_dirs.is_empty():
		return

	# Obtener la dirección actual del patrón
	var look_direction_enum = look_pattern_dirs[_look_pattern_index]
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
	_look_pattern_index = (_look_pattern_index + 1) % look_pattern_dirs.size()

	# Iniciar timer para la siguiente mirada
	_look_pattern_timer.start(get_look_pattern_delay())

## Callback cuando el jugador se mueve (para awareness)
func _on_player_moved(_tile_pos: Vector2) -> void:
	if not movement_enabled or _movement_paused or not get_awareness_enabled():
		return

	# Solo activar en tipos sin movimiento
	if get_movement_type() not in [0, 3, 4, 7, 8]:  # NONE, RANDOM_TURNING, LOOK_PATTERN, RANDOM_TURNING_HORIZONTAL, RANDOM_TURNING_VERTICAL
		return

	# OPTIMIZACIÓN: Verificar distancia con tiles ANTES de buscar el player
	var npc_tile = motion.current_tile()
	var distance_tiles = npc_tile.distance_to(_tile_pos)

	# Early return si está muy lejos (evita búsquedas costosas)
	if distance_tiles > get_awareness_detection_distance():
		return

	# Solo si está cerca, buscar el player
	var context = _get_context()
	var player: Node = context.get_player() if context else null
	if not player:
		return

	# Calcular distancia exacta en píxeles para mayor precisión
	var distance_in_pixels = global_position.distance_to(player.global_position)
	var detection_distance_pixels = get_awareness_detection_distance() * 32

	if distance_in_pixels > detection_distance_pixels:
		return

	# Calcular probabilidad de giro
	var chance = get_awareness_chance()

	# Aumentar probabilidad si el jugador está corriendo
	if player.has_node("GridMotion"):
		var player_motion = player.get_node("GridMotion")
		if player_motion and player_motion.is_running:
			chance *= get_awareness_running_multiplier()

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
	for dir_enum in get_path_directions():
		match dir_enum:
			DirectionEnum.Type.UP: _path_directions_vector2.append(Vector2.UP)
			DirectionEnum.Type.DOWN: _path_directions_vector2.append(Vector2.DOWN)
			DirectionEnum.Type.LEFT: _path_directions_vector2.append(Vector2.LEFT)
			DirectionEnum.Type.RIGHT: _path_directions_vector2.append(Vector2.RIGHT)
			DirectionEnum.Type.LOOK_UP: _path_directions_vector2.append(Vector2.UP)
			DirectionEnum.Type.LOOK_DOWN: _path_directions_vector2.append(Vector2.DOWN)
			DirectionEnum.Type.LOOK_LEFT: _path_directions_vector2.append(Vector2.LEFT)
			DirectionEnum.Type.LOOK_RIGHT: _path_directions_vector2.append(Vector2.RIGHT)
			DirectionEnum.Type.LOOK_PLAYER: _path_directions_vector2.append(Vector2.ZERO)  # Se calculará dinámicamente
			_: push_warning("NPC: Dirección inválida en path_directions: %d" % dir_enum)

## Inicia el path movement después de que el grid esté disponible
func _deferred_start_path_movement() -> void:
	# Esperar hasta que el grid esté disponible
	await get_tree().process_frame

	# Verificar que el grid esté disponible antes de iniciar
	if motion.grid == null:
		motion._refresh_grid()

	# Si aún no está disponible, esperar un frame más
	if motion.grid == null:
		await get_tree().process_frame
		motion._refresh_grid()

	# Iniciar el path movement
	_try_execute_next_path_action()

## Intenta ejecutar la siguiente acción del path
func _try_execute_next_path_action() -> void:
	if not movement_enabled or motion.moving or _path_directions_vector2.is_empty() or _movement_paused:
		return

	# Obtener el comando actual de la ruta (enum y vector)
	var path_dirs = get_path_directions()
	var dir_enum = path_dirs[path_index]
	var direction = _path_directions_vector2[path_index]

	# Verificar el tipo de comando
	var is_movement = DirectionEnum.is_movement(dir_enum)
	# Verificar si es wait (usando números directamente como workaround)
	var is_wait = (dir_enum >= 9)  # WAIT_025=9, WAIT_050=10, WAIT_100=11 (LOOK_PLAYER=8)

	if is_movement:
		# Verificar que el grid esté disponible antes de obtener current_tile
		if motion.grid == null:
			push_warning("NPC '%s': Grid no disponible aún, esperando..." % name)
			return

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

	elif is_wait:
		# Comando WAIT: esperar sin moverse ni cambiar dirección
		# Obtener duración según el tipo de wait (usando números directamente)
		var wait_duration = 0.0
		match dir_enum:
			9:  # WAIT_025
				wait_duration = 0.25
			10:  # WAIT_050
				wait_duration = 0.50
			11: # WAIT_100
				wait_duration = 1.00
		path_index = (path_index + 1) % _path_directions_vector2.size()
		await get_tree().create_timer(wait_duration).timeout

	else:
		# Comando LOOK: solo girar sin moverse
		# Si es LOOK_PLAYER, calcular la dirección hacia el jugador
		if dir_enum == DirectionEnum.Type.LOOK_PLAYER:
			var look_direction = _calculate_direction_to_player_for_path()
			if look_direction != Vector2.ZERO:
				direction = look_direction
			else:
				# Si no se pudo calcular, saltar este comando
				path_index = (path_index + 1) % _path_directions_vector2.size()
				return

		motion.face(direction)
		animator.idle(direction)
		path_index = (path_index + 1) % _path_directions_vector2.size()
		await get_tree().create_timer(0.5).timeout
	call_deferred("_try_execute_next_path_action")


## Calcula la dirección hacia el jugador para uso en path movement
func _calculate_direction_to_player_for_path() -> Vector2:
	var context = _get_context()
	var player: Node = context.get_player() if context else null
	if not player or not motion or not motion.grid:
		return Vector2.ZERO

	# Calcular diferencia en tiles
	var npc_tile = motion.current_tile()
	var player_tile = motion.grid.world_to_tile(player.global_position)
	var diff = player_tile - npc_tile

	# Determinar la dirección predominante
	var direction = Vector2.ZERO
	if abs(diff.x) > abs(diff.y):
		# Movimiento horizontal predominante
		direction = Vector2.RIGHT if diff.x > 0 else Vector2.LEFT
	else:
		# Movimiento vertical predominante
		direction = Vector2.DOWN if diff.y > 0 else Vector2.UP

	return direction

## Procesa el comportamiento de mirar al jugador

## Hace que el NPC mire hacia el jugador
func _face_player() -> void:
	# Buscar al jugador del contexto
	var context = _get_context()
	var player: Node = context.get_player() if context else null
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
	# No aplicar speed_multiplier a la animación cuando se corre
	# Las animaciones de correr ya tienen velocidad base 15.0 (vs 7.5 de caminar)
	# El speed_multiplier solo afecta la velocidad de movimiento, no la animación
	animator.set_speed_scale(1.0)

## Callback cuando GridMotion finaliza un paso
func _on_step_finished(_tile: Vector2i) -> void:
	if animator:
		animator.idle(motion.dir)

	# Para Path movement, intentar ejecutar la siguiente acción
	# Usar call_deferred para esperar a que GridMotion alterne el stride_is_left
	if get_movement_type() == 2:  # PATH
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
	if _random_turning_horizontal_timer and _random_turning_horizontal_timer.time_left > 0:
		_random_turning_horizontal_timer.stop()
	if _random_turning_vertical_timer and _random_turning_vertical_timer.time_left > 0:
		_random_turning_vertical_timer.stop()


## Reanuda el movimiento del NPC cuando terminan los comandos
func _resume_movement() -> void:
	_movement_paused = false

	# Reiniciar timers según el tipo de movimiento
	if get_movement_type() == 1 and _random_timer:  # RANDOM
		_random_timer.start(randf_range(get_random_move_interval_min(), get_random_move_interval_max()))
	elif get_movement_type() == 2:  # PATH
		# Reanudar path movement
		call_deferred("_try_execute_next_path_action")
	elif get_movement_type() == 3 and _random_turning_timer:  # RANDOM_TURNING
		_random_turning_timer.start(randf_range(get_random_turning_interval_min(), get_random_turning_interval_max()))
	elif get_movement_type() == 4 and _look_pattern_timer:  # LOOK_PATTERN
		_look_pattern_timer.start(get_look_pattern_delay())
	elif get_movement_type() == 7 and _random_turning_horizontal_timer:  # RANDOM_TURNING_HORIZONTAL
		_random_turning_horizontal_timer.start(randf_range(get_random_turning_interval_min(), get_random_turning_interval_max()))
	elif get_movement_type() == 8 and _random_turning_vertical_timer:  # RANDOM_TURNING_VERTICAL
		_random_turning_vertical_timer.start(randf_range(get_random_turning_interval_min(), get_random_turning_interval_max()))


## Callback cuando termina un evento (para reanudar movimiento)
func _on_event_finished(_event) -> void:
	# Solo reanudar si este NPC estaba pausado
	if _movement_paused:
		# Restaurar dirección inicial si es necesario
		if get_orientation_behavior() == OrientationBehaviorEnum.Type.FACE_AND_RESTORE:
			var initial_dir = DirectionEnum.to_vector2(get_initial_direction())
			motion.dir = initial_dir
			if animator:
				animator.idle(initial_dir)

		_resume_movement()

# Las funciones de ocultar sprites por defecto ya no son necesarias
# Event.gd maneja el placeholder automáticamente
