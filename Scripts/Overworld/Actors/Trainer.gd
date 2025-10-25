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

@export_group("Trainer Data")
## TrainerData del entrenador (se asigna automáticamente al Battler hijo)
@export var trainer_data: TrainerData = null

## === CONFIGURACIÓN DE DETECCIÓN ===

@export_group("Detection")
## Rango de detección en tiles (línea recta en la dirección que mira)
@export_range(1, 10) var detection_range: int = 5

## Tipo de transición de batalla a usar
@export_enum("Battle1", "Battle2", "Battle3", "Battle4", "Normal01", "Normal02", "Hexatr", "Hexatrc", "Hexatzr", "WipeVertical") var transition_type: int = 0

## Si true, el trainer puede hacer rematches incluso después de ser derrotado
@export var allow_rematch: bool = false

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
	
	# Si el Trainer tiene un TrainerData configurado, asignarlo al Battler
	if trainer_data and battler:
		battler.trainer_data = trainer_data
		# Forzar la carga del TrainerData (el Battler ya ejecutó _ready() sin trainer_data)
		battler._load_from_trainer_data()
		battler._initialize_party()
		print("Trainer '%s': TrainerData asignado y cargado al Battler" % name)
	
	# Conectar señal de batalla terminada
	SignalManager.battle_finished.connect(_on_battle_finished)
	
	# Conectar señales para detección (diferido para esperar a que Player esté listo)
	if not is_defeated() or allow_rematch:
		call_deferred("_connect_to_player_for_detection")
		_connect_own_movement_for_detection()


## Busca el nodo Battler hijo
func _find_battler() -> void:
	for child in get_children():
		if child is Battler:
			battler = child
			print("Trainer '%s': Battler encontrado (%s)" % [name, battler.get_full_name()])
			return
	
	push_warning("Trainer '%s': No se encontró un nodo Battler hijo. Configura un Battler para este entrenador." % name)


## Conecta a la señal de movimiento del jugador para detección
func _connect_to_player_for_detection() -> void:
	var player = get_tree().get_first_node_in_group("Player")
	if not player:
		push_warning("Trainer '%s': No se encontró el Player. La detección no funcionará." % name)
		return
	
	if not player.has_node("GridMotion"):
		push_warning("Trainer '%s': El Player no tiene GridMotion. La detección no funcionará." % name)
		return
	
	var player_motion = player.get_node("GridMotion")
	if player_motion:
		player_motion.step_finished.connect(_on_movement_detected)
		print("Trainer '%s': Conectado a movimiento del jugador" % name)
	else:
		push_warning("Trainer '%s': No se pudo obtener GridMotion del Player." % name)


## Conecta a las señales del propio movimiento del Trainer para detección
func _connect_own_movement_for_detection() -> void:
	if not motion:
		push_warning("Trainer '%s': No tiene GridMotion. La detección no funcionará." % name)
		return
	
	# Conectar a step_finished (cuando termina un movimiento)
	motion.step_finished.connect(_on_movement_detected)
	# Conectar a direction_changed (cuando gira sin moverse - LOOK commands)
	motion.direction_changed.connect(_on_direction_changed)
	print("Trainer '%s': Conectado a propio movimiento y giros para detección" % name)


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
	# No detectar si ya está iniciando batalla o si está derrotado (y no permite rematch)
	if _initiating_battle or _player_detected:
		return
	
	if is_defeated() and not allow_rematch:
		return
	
	# No detectar durante eventos o movimiento pausado
	if _movement_paused or not movement_enabled:
		return
	
	# Obtener posición actual del jugador
	var player = get_tree().get_first_node_in_group("Player")
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
	if not motion or not motion.grid:
		return false
	
	var trainer_tile = motion.current_tile()
	var direction = motion.dir
	
	# Verificar solo en la dirección que mira el trainer
	var offset = Vector2i.ZERO
	
	# Determinar el eje de detección según la dirección
	if direction == Vector2.UP:
		# Mirar hacia arriba (Y negativo)
		for i in range(1, detection_range + 1):
			offset = Vector2i(0, -i)
			if trainer_tile + offset == player_tile:
				return true
	
	elif direction == Vector2.DOWN:
		# Mirar hacia abajo (Y positivo)
		for i in range(1, detection_range + 1):
			offset = Vector2i(0, i)
			if trainer_tile + offset == player_tile:
				return true
	
	elif direction == Vector2.LEFT:
		# Mirar hacia la izquierda (X negativo)
		for i in range(1, detection_range + 1):
			offset = Vector2i(-i, 0)
			if trainer_tile + offset == player_tile:
				return true
	
	elif direction == Vector2.RIGHT:
		# Mirar hacia la derecha (X positivo)
		for i in range(1, detection_range + 1):
			offset = Vector2i(i, 0)
			if trainer_tile + offset == player_tile:
				return true
	
	return false


## Inicia la secuencia de batalla: Exclamación → Movimiento → Diálogo → Combate
func _start_battle_sequence() -> void:
	_initiating_battle = true
	
	# Bloquear controles del jugador
	SignalManager.player_control_blocked.emit()
	
	# Pausar movimiento del trainer
	_pause_movement()
	
	# 1. Mostrar exclamación
	await _show_exclamation()
	
	# 2. Moverse hacia el jugador
	await _approach_player()

	await get_tree().create_timer(0.2).timeout

	# 3. Mostrar diálogo de introducción
	if battler:
		await _show_intro_dialogue()
	
	# 4. Iniciar batalla
	_initiate_battle()


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
	var player = get_tree().get_first_node_in_group("Player")
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


## Muestra el diálogo de introducción del trainer
func _show_intro_dialogue() -> void:
	if not battler:
		return
	
	var intro_text = battler.get_intro_text()
	

	var config = {
		"waitInput": true,
		"closeAtEnd": false,
		"waitTime": 0.0
	}
	
	# Emitir señal para mostrar mensaje
	SignalManager.message_requested.emit(intro_text, config)
	
	# Esperar a que termine el mensaje
	await SignalManager.message_finished


## Inicia el combate con el jugador
func _initiate_battle() -> void:
	if not battler:
		push_error("Trainer '%s': No se puede iniciar batalla sin Battler configurado" % name)
		SignalManager.player_control_unblocked.emit()
		_initiating_battle = false
		return
	
	# Obtener el Battler del jugador
	var player = get_tree().get_first_node_in_group("Player")
	if not player:
		push_error("Trainer '%s': No se encontró el jugador" % name)
		SignalManager.player_control_unblocked.emit()
		_initiating_battle = false
		return
	
	# Buscar el Battler del jugador
	var player_battler: Battler = null
	for child in player.get_children():
		if child is Battler:
			player_battler = child
			break
	
	if not player_battler:
		push_error("Trainer '%s': El jugador no tiene un Battler configurado" % name)
		SignalManager.player_control_unblocked.emit()
		_initiating_battle = false
		return
	
	# Crear participantes de batalla
	var player_participant = player_battler.to_battle_participant()
	var trainer_participant = battler.to_battle_participant()
	
	# Determinar modo de batalla (single o double)
	var battle_mode = BattleRules.BattleModes.SINGLE
	if battler.allow_double_battle:
		battle_mode = BattleRules.BattleModes.DOUBLE
	
	# Crear reglas de batalla
	var rules = BattleRules.new(
		BattleRules.BattleTypes.TRAINER,
		battle_mode
	)
	
	# Configurar transición (si el sistema lo soporta)
	# TODO: Pasar transition_type a BattleRules o al sistema de transiciones
	
	# Emitir señal de batalla solicitada
	var participants: Array[BattleParticipant] = [player_participant, trainer_participant]
	print("Trainer '%s': Iniciando batalla con %s" % [battler.get_full_name(), player_participant.name])
	SignalManager.battle_requested.emit(participants, rules)


## Callback cuando la batalla termina
func _on_battle_finished(winner_side: String) -> void:
	# Verificar si este trainer participó en la batalla
	if not _initiating_battle:
		return
	
	print("Trainer '%s': Batalla terminada. Ganador: %s" % [name, winner_side])
	
	# Marcar como derrotado si perdió
	if winner_side == "PLAYER" and battler:
		battler.is_defeated = true
		print("Trainer '%s': Marcado como derrotado" % name)
	
	# Resetear flags
	_initiating_battle = false
	_player_detected = false
	
	# Desbloquear controles del jugador
	SignalManager.player_control_unblocked.emit()
	
	# Reanudar movimiento del trainer
	_resume_movement()


## Override del trigger() para mostrar mensaje post-derrota
func trigger() -> void:
	# Si está derrotado, mostrar mensaje alternativo
	if is_defeated() and battler:
		print("Trainer '%s' (derrotado): %s" % [battler.get_full_name(), battler.get_defeat_text()])
		# TODO: Integrar con sistema de MessageBox
		return
	
	# Si no está derrotado, comportamiento normal de NPC
	super.trigger()


## Resetea el estado del trainer (útil para testing o rematches)
func reset_trainer() -> void:
	if battler:
		battler.is_defeated = false
	
	_player_detected = false
	_initiating_battle = false
	
	print("Trainer '%s': Estado reseteado" % name)
