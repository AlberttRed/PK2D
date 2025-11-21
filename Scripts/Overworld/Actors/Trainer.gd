extends NPC
class_name Trainer

## Sistema de entrenadores NPCs que detectan al jugador
##
## Los Trainers extienden de NPC y añaden:
## - Detección del jugador en línea recta
## - Secuencia de batalla: Exclamación → Movimiento → Diálogo → Combate
## - Persistencia de estado de derrota
## - Integración con Battler para gestión de equipo Pokémon
##
## Uso:
## 1. Asignar TrainerData en el inspector (se pasa automáticamente al Battler hijo)
## 2. Configurar detection_range y transition_type
## 3. El Trainer detectará automáticamente al jugador y iniciará la batalla

## === CONFIGURACIÓN DE ENTRENADOR ===

@export_group("State Tracking")
## Flag para guardar si el entrenador fue derrotado (usa GameStateService)
## Si está vacío, no se guarda el estado
## Ejemplo: "route_1_youngster_joey_defeated"
@export var defeated_flag: String = ""

## Animación de exclamación a mostrar sobre el trainer (64x32px, ocupa 2 tiles de alto)
var exclamation_sprite: SpriteFrames = preload("res://Resources/Animations/Overworld/trainer_exclamation.tres")

## Tiempo que dura la exclamación (en segundos)
var exclamation_duration: float = 1.5

## === ESTADO INTERNO ===

## Referencia al Battler hijo (se obtiene automáticamente)
var battler: Battler = null

## Si el trainer está actualmente en proceso de iniciar batalla
var _initiating_battle: bool = false

## Si el trainer ya detectó al jugador (evita múltiples detecciones)
var _player_detected: bool = false

## Nodo para la exclamación visual
var _exclamation_node: AnimatedSprite2D = null


func _ready() -> void:
	super._ready()

	# Buscar el Battler hijo
	_find_battler()

	# Restaurar estado desde GameStateService si hay un defeated_flag configurado
	if battler and not defeated_flag.is_empty():
		var is_defeated_saved = GameStateService.get_event_flag(defeated_flag)
		if is_defeated_saved:
			battler.is_defeated = true
			print("Trainer '%s': Estado restaurado desde GameStateService - Ya fue derrotado" % name)

	# Conectar señal de batalla terminada desde DisplayManager
	call_deferred("_connect_display_manager_signals")

	# Activar/desactivar detección según la página activa
	# (se hace después de que Event base haya llamado setup_current_page en super._ready())
	call_deferred("_update_detection_state")

func _connect_display_manager_signals() -> void:
	var dm := DisplayManager.instance
	if not dm:
		call_deferred("_connect_display_manager_signals")
		return

	if not dm.battle_finished.is_connected(_on_battle_finished):
		dm.battle_finished.connect(_on_battle_finished)

## Limpia las conexiones de señales al eliminar el Trainer
func _exit_tree() -> void:
	_disconnect_detection_signals()

## Busca el nodo Battler hijo
func _find_battler() -> void:
	for child in get_children():
		if child is Battler:
			battler = child
			return

	push_warning("Trainer '%s': No se encontró un nodo Battler hijo. Configura un Battler para este entrenador." % name)


## Conecta a la señal de movimiento del jugador para detección
func _connect_to_player_for_detection() -> void:
	var context = _get_context()
	if not context:
		push_warning("Trainer '%s': OverworldContext no disponible. La detección no funcionará." % name)
		return

	var player = context.get_player()
	if not player or not is_instance_valid(player):
		push_warning("Trainer '%s': No se encontró el Player válido. La detección no funcionará." % name)
		return

	if not player.has_node("GridMotion"):
		push_warning("Trainer '%s': El Player no tiene GridMotion. La detección no funcionará." % name)
		return

	var player_motion = player.get_node("GridMotion")
	if player_motion:
		# Verificar si ya está conectado para evitar duplicados
		if not player_motion.step_finished.is_connected(_on_movement_detected):
			player_motion.step_finished.connect(_on_movement_detected)
	else:
		push_warning("Trainer '%s': No se pudo obtener GridMotion del Player." % name)


## Conecta a las señales del propio movimiento del Trainer para detección
func _connect_own_movement_for_detection() -> void:
	if not motion:
		push_warning("Trainer '%s': No tiene GridMotion. La detección no funcionará." % name)
		return

	# Conectar a step_finished (cuando termina un movimiento) - verificar si ya está conectado
	if not motion.step_finished.is_connected(_on_movement_detected):
		motion.step_finished.connect(_on_movement_detected)

	# Conectar a direction_changed (cuando gira sin moverse - LOOK commands) - verificar si ya está conectado
	if not motion.direction_changed.is_connected(_on_direction_changed):
		motion.direction_changed.connect(_on_direction_changed)


## Actualiza el estado de detección según la página activa
## Si el evento está activo (en un chunk activo), reconecta/desconecta las señales según la página
func _update_detection_state() -> void:
	# Verificar que el evento está en un mapa activo antes de intentar conectar
	if not is_inside_tree() or not motion or not is_instance_valid(motion):
		return

	if not motion.grid or not is_instance_valid(motion.grid):
		return

	# Validar que solo los Trainers puedan usar detección
	if current_page and current_page.enable_trainer_detection and not self is Trainer:
		push_error("EventPage: enable_trainer_detection=true pero el Event '%s' NO es un Trainer" % name)
		return

	# Si el evento está activo (process_mode != DISABLED), actualizar las conexiones
	# Esto puede pasar cuando cambia la página del evento mientras está en un chunk activo
	if process_mode != Node.PROCESS_MODE_DISABLED:
		# Desconectar primero (por si acaso)
		disconnect_external_signals()
		# Reconectar si la página actual requiere detección
		connect_external_signals()


## Sobrescribe el método virtual de Event para conectar señales externas
## Se llama cuando el Trainer se activa en un chunk
func connect_external_signals() -> void:
	super.connect_external_signals()
	# Conectar detección si está habilitada en la página actual
	if current_page and current_page.enable_trainer_detection:
		_connect_to_player_for_detection()
		_connect_own_movement_for_detection()

## Sobrescribe el método virtual de Event para desconectar señales externas
## Se llama cuando el Trainer se desactiva en un chunk
func disconnect_external_signals() -> void:
	super.disconnect_external_signals()
	# Desconectar todas las señales de detección
	_disconnect_detection_signals()

## Desconecta todas las señales de detección
func _disconnect_detection_signals() -> void:
	# Desconectar del jugador (con verificación robusta)
	var context = _get_context()
	if context:
		var player = context.get_player()
		if player and is_instance_valid(player) and player.has_node("GridMotion"):
			var player_motion = player.get_node("GridMotion")
			if player_motion and is_instance_valid(player_motion):
				if player_motion.step_finished.is_connected(_on_movement_detected):
					player_motion.step_finished.disconnect(_on_movement_detected)

	# Desconectar de propio movimiento
	if motion and is_instance_valid(motion):
		if motion.step_finished.is_connected(_on_movement_detected):
			motion.step_finished.disconnect(_on_movement_detected)
		if motion.direction_changed.is_connected(_on_direction_changed):
			motion.direction_changed.disconnect(_on_direction_changed)


## Verifica si el trainer está derrotado
func is_defeated() -> bool:
	if battler:
		return battler.is_defeated
	return false


## Callback cuando el trainer cambia de dirección (giros)
func _on_direction_changed(_new_direction: Vector2) -> void:
	# Reutilizar la lógica de detección
	_on_movement_detected()


## Callback cuando hay movimiento (del jugador o del trainer)
func _on_movement_detected(_tile: Vector2i = Vector2i.ZERO) -> void:
	# No detectar si ya está iniciando batalla
	if _initiating_battle or _player_detected:
		return

	# No detectar durante eventos o movimiento pausado
	if _movement_paused or not movement_enabled:
		return

	# Obtener posición actual del jugador
	var context = _get_context()
	var player: Node = context.get_player() if context else null
	if not player or not motion or not motion.grid:
		return

	var player_tile = motion.grid.world_to_tile(player.global_position)

	# Verificar si el jugador está en el campo de visión
	if _is_player_in_sight(player_tile):
		print("Trainer '%s': ¡Jugador detectado en tile %s!" % [name, player_tile])
		_player_detected = true
		_start_battle_sequence()


## Verifica si el jugador está en la línea de visión del trainer
func _is_player_in_sight(player_tile: Vector2i) -> bool:
	if not motion or not motion.grid or not current_page:
		return false

	# Obtener detection_range de la página activa
	var detect_range = current_page.detection_range if current_page.enable_trainer_detection else 0
	if detect_range <= 0:
		return false

	var trainer_tile = motion.current_tile()
	var direction = motion.dir

	# Verificar solo en la dirección que mira el trainer
	var offset = Vector2i.ZERO

	# Determinar el eje de detección según la dirección
	if direction == Vector2.UP:
		# Mirar hacia arriba (Y negativo)
		for i in range(1, detect_range + 1):
			offset = Vector2i(0, -i)
			if trainer_tile + offset == player_tile:
				return true

	elif direction == Vector2.DOWN:
		# Mirar hacia abajo (Y positivo)
		for i in range(1, detect_range + 1):
			offset = Vector2i(0, i)
			if trainer_tile + offset == player_tile:
				return true

	elif direction == Vector2.LEFT:
		# Mirar hacia la izquierda (X negativo)
		for i in range(1, detect_range + 1):
			offset = Vector2i(-i, 0)
			if trainer_tile + offset == player_tile:
				return true

	elif direction == Vector2.RIGHT:
		# Mirar hacia la derecha (X positivo)
		for i in range(1, detect_range + 1):
			offset = Vector2i(i, 0)
			if trainer_tile + offset == player_tile:
				return true

	return false


## Inicia la secuencia de batalla: Exclamación → Movimiento → Batalla
func _start_battle_sequence() -> void:
	_initiating_battle = true

	# Bloquear controles del jugador
	var context = _get_context()
	if context:
		context.block_player_control()
	else:
		push_warning("Trainer '%s': OverworldContext no disponible para bloquear el control del jugador" % name)
	# Pausar movimiento del trainer
	_pause_movement()

	# 1. Mostrar exclamación
	await _show_exclamation()

	# 2. Moverse hacia el jugador
	await _approach_player()

	await get_tree().create_timer(0.2).timeout

	# 3. Buscar StartBattleEventCommand en la página activa e iniciar batalla
	await _initiate_battle_from_page()


## Muestra la exclamación sobre el trainer
func _show_exclamation() -> void:
	if not exclamation_sprite:
		return

	# Crear sprite de exclamación temporal
	_exclamation_node = AnimatedSprite2D.new()
	_exclamation_node.sprite_frames = exclamation_sprite

	# Posición: 2 tiles arriba del trainer (64px de alto = 2 tiles)
	# El sprite tiene 64px de alto, con centro a 32px, así que -64 lo centra en los 2 tiles superiores
	_exclamation_node.position = Vector2(0, -64)

	add_child(_exclamation_node)

	# Determinar qué animación usar
	var anim_name = "default"

	# Reproducir animación una vez (sin loop)
	_exclamation_node.play(anim_name)

	# Esperar a que termine la animación
	await _exclamation_node.animation_finished

	# Detener en el último frame
	_exclamation_node.stop()

	# Establecer el último frame manualmente
	var frame_count = _exclamation_node.sprite_frames.get_frame_count(anim_name)
	if frame_count > 0:
		_exclamation_node.frame = frame_count - 1

	# Esperar el tiempo restante (duración total - tiempo de animación)
	# Calculamos el tiempo de la animación
	var animation_duration = 0.0
	if _exclamation_node.sprite_frames:
		var fps = _exclamation_node.sprite_frames.get_animation_speed(anim_name)
		if fps > 0:
			animation_duration = frame_count / fps

	var remaining_time = max(0.0, exclamation_duration - animation_duration)
	if remaining_time > 0:
		await get_tree().create_timer(remaining_time).timeout

	# Eliminar exclamación
	if _exclamation_node:
		_exclamation_node.queue_free()
		_exclamation_node = null


## Mueve el trainer hacia el jugador
func _approach_player() -> void:
	var context = _get_context()
	var player: Node = context.get_player() if context else null
	if not player or not motion or not motion.grid:
		return

	var player_tile = motion.grid.world_to_tile(player.global_position)
	var trainer_tile = motion.current_tile()

	# Calcular distancia en la dirección que mira
	var direction = motion.dir
	var distance = 0

	if direction == Vector2.UP:
		distance = trainer_tile.y - player_tile.y - 1  # Detenerse a 1 tile
	elif direction == Vector2.DOWN:
		distance = player_tile.y - trainer_tile.y - 1
	elif direction == Vector2.LEFT:
		distance = trainer_tile.x - player_tile.x - 1
	elif direction == Vector2.RIGHT:
		distance = player_tile.x - trainer_tile.x - 1

	# Moverse hacia el jugador (detenerse a 1 tile de distancia)
	var steps = max(0, distance)

	for i in range(steps):
		motion.try_step(direction)
		# Esperar a que termine el paso
		if motion.moving:
			await motion.step_finished


## Busca el StartBattleEventCommand en la página activa e inicia la batalla
func _initiate_battle_from_page() -> void:
	if not overworld_context:
		push_error("Trainer '%s': OverworldContext no disponible" % name)
		_initiating_battle = false
		return

	if not current_page:
		push_error("Trainer '%s': No hay página activa" % name)
		if overworld_context:
			overworld_context.unblock_player_control()
		_initiating_battle = false
		return


	# Buscar StartBattleEventCommand usando el método helper de EventPage
	var battle_command = current_page.get_battle_command()

	if not battle_command:
		push_error("Trainer '%s': No se encontró StartBattleEventCommand en la página activa" % name)
		overworld_context.unblock_player_control()
		_initiating_battle = false
		return

	# Obtener trainer_data del comando
	var trainer_data_from_command = battle_command.trainer_data
	if not trainer_data_from_command:
		push_error("Trainer '%s': StartBattleEventCommand no tiene trainer_data configurado" % name)
		overworld_context.unblock_player_control()
		_initiating_battle = false
		return

	# Asignar el trainer_data del comando al battler
	battler.trainer_data = trainer_data_from_command
	battler.is_player = false
	battler._load_from_trainer_data()
	battler._initialize_party()

	# Mostrar mensaje intro del TrainerData
	var intro_text = battler.get_intro_text()
	if not intro_text.is_empty():
		var config = {
			"waitInput": true,
			"closeAtEnd": false,
			"waitTime": 0.0,
			"showIconAtEnd": false
		}
		await DisplayManager.show_message(intro_text, config)

	# Obtener Battler del jugador
	var player: Node = overworld_context.get_player()
	if not player:
		push_error("Trainer '%s': Player no disponible" % name)
		overworld_context.unblock_player_control()
		_initiating_battle = false
		return

	# Crear participantes
	var player_participant = player.battler.to_battle_participant()
	var trainer_participant = battler.to_battle_participant()

	# Crear reglas
	var rules = BattleRules.new(BattleRules.BattleTypes.TRAINER, battle_command.battle_mode)

	# Iniciar batalla
	var participants: Array[BattleParticipant] = [player_participant, trainer_participant]
	print("Trainer '%s': Iniciando batalla (por detección)" % name)
	var winner = await DisplayManager.start_battle(participants, rules)
	print("Trainer '%s': Batalla terminada. Ganador: %s" % [name, winner])


## Callback cuando la batalla termina
func _on_battle_finished(winner_side: String) -> void:
	# Verificar si este trainer participó en la batalla
	if not _initiating_battle:
		return

	print("Trainer '%s': Batalla terminada. Ganador: %s" % [name, winner_side])

	# Marcar como derrotado si perdió y guardar en GameStateService
	if winner_side == "player" and battler:
		battler.is_defeated = true
		print("Trainer '%s': Marcado como derrotado" % name)

		# Guardar estado en GameStateService si hay un defeated_flag configurado
		if not defeated_flag.is_empty():
			GameStateService.set_event_flag(defeated_flag, true)
			print("Trainer '%s': Estado guardado en GameStateService (flag: '%s')" % [name, defeated_flag])
			# La señal flag_changed hará que el Event reevalúe páginas
			# y _update_detection_state() se encargará de desconectar si es necesario

	# Resetear flags
	_initiating_battle = false
	_player_detected = false

	# Desbloquear controles del jugador
	if overworld_context:
		overworld_context.unblock_player_control()

	# Reanudar movimiento del trainer
	_resume_movement()

## Resetea el estado del trainer (útil para testing o rematches)
func reset_trainer() -> void:
	if battler:
		battler.is_defeated = false

	_player_detected = false
	_initiating_battle = false

	print("Trainer '%s': Estado reseteado" % name)


## Override de refresh_active_page para actualizar detección al cambiar de página
func refresh_active_page() -> void:
	super.refresh_active_page()
	# Actualizar estado de detección con la nueva página
	_update_detection_state()
