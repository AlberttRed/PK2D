extends EventCommand
class_name StartBattleEventCommand

## Comando para iniciar combates desde eventos
## 
## Permite iniciar combates de tipo WILD, TRAINER o CUSTOM desde cualquier evento.
## El evento se pausa durante el combate y continúa al finalizar.
##
## Uso:
## 1. Añadir este comando a la lista de comandos de una EventPage
## 2. Configurar battle_type (WILD, TRAINER, CUSTOM)
## 3. Asignar trainer_data (para TRAINER) o wild_pokemon (para WILD)
## 4. Opcionalmente configurar intro_message y transition_type
## 5. El combate se iniciará usando SignalManager.battle_requested

## === ENUMS ===

enum BattleType {
	WILD,      ## Combate contra Pokémon salvajes
	TRAINER,   ## Combate contra un entrenador (usa TrainerData)
	CUSTOM     ## Combate personalizado (futuro)
}

## === CONFIGURACIÓN DEL COMBATE ===

@export_group("Battle Configuration")

## Tipo de combate a iniciar
@export var battle_type: BattleType = BattleType.WILD

## TrainerData del entrenador enemigo (solo para battle_type = TRAINER)
@export var trainer_data: TrainerData = null

## Pokémon salvajes para el combate (solo para battle_type = WILD)
## Configura cada Pokemon desde el inspector con su nivel, movimientos, IVs, etc.
@export var wild_pokemon: Array[Pokemon] = []

## Modo de batalla (SINGLE, DOUBLE, TRIPLE)
@export_enum("SINGLE", "DOUBLE", "TRIPLE") var battle_mode: int = 0  # SINGLE por defecto

@export_group("Messages")

## Mensaje de introducción antes del combate (opcional)
## Si está vacío, no se muestra mensaje
## Para TRAINER, usa el intro_text del TrainerData si este está vacío
@export_multiline var intro_message: String = ""

## Mostrar mensaje de inicio incluso si está vacío (usar mensaje del TrainerData)
@export var use_trainer_intro: bool = true

@export_group("Visual")

## Tipo de transición de batalla (futuro uso)
@export_enum("Battle1", "Battle2", "Battle3", "Battle4", "Normal01", "Normal02", "Hexatr", "Hexatrc", "Hexatzr", "WipeVertical") var transition_type: int = 0

@export_group("State Tracking")

## Flag para guardar si el entrenador fue derrotado (solo para TRAINER)
## Si está vacío, usa automáticamente el defeated_flag del Trainer (si el Event es un Trainer)
## Solo necesitas configurarlo para batallas sin Trainer NPC o para usar un flag diferente
@export var defeated_flag: String = ""

## === ESTADO INTERNO ===

var _battle_finished: bool = false
var _battle_winner: String = ""


func execute(context: Node) -> void:
	print("StartBattleCommand: Iniciando combate tipo %s" % BattleType.keys()[battle_type])
	
	# Validar configuración
	if not _validate_configuration():
		push_error("StartBattleCommand: Configuración inválida, saltando comando")
		context.continue_execution()
		return
	
	# Obtener el Battler del jugador
	var player_battler = _get_player_battler(context)
	if not player_battler:
		push_error("StartBattleCommand: No se encontró el Battler del jugador")
		context.continue_execution()
		return
	
	# Mostrar mensaje de introducción si está configurado
	if not intro_message.is_empty() or (use_trainer_intro and battle_type == BattleType.TRAINER):
		await _show_intro_message()
	
	# Crear participantes según el tipo de batalla
	var enemy_participant: BattleParticipant = null
	
	match battle_type:
		BattleType.TRAINER:
			enemy_participant = _create_trainer_participant()
		BattleType.WILD:
			enemy_participant = _create_wild_participant()
		BattleType.CUSTOM:
			push_warning("StartBattleCommand: CUSTOM battle type no está implementado aún")
			context.continue_execution()
			return
	
	if not enemy_participant:
		push_error("StartBattleCommand: No se pudo crear el participante enemigo")
		context.continue_execution()
		return
	
	# Crear participante del jugador
	var player_participant = player_battler.to_battle_participant()
	
	# Determinar modo de batalla
	var mode: BattleRules.BattleModes = BattleRules.BattleModes.SINGLE
	match battle_mode:
		0:
			mode = BattleRules.BattleModes.SINGLE
		1:
			mode = BattleRules.BattleModes.DOUBLE
		2:
			mode = BattleRules.BattleModes.TRIPLE
	
	# Determinar tipo de batalla para las reglas
	var type: BattleRules.BattleTypes = BattleRules.BattleTypes.WILD
	if battle_type == BattleType.TRAINER:
		type = BattleRules.BattleTypes.TRAINER
	
	# Crear reglas de batalla
	var rules = BattleRules.new(type, mode)
	
	# Preparar array de participantes
	var participants: Array[BattleParticipant] = [player_participant, enemy_participant]
	
	# Conectar señal de batalla terminada
	_battle_finished = false
	SignalManager.battle_finished.connect(_on_battle_finished)
	
	# Emitir señal de batalla solicitada
	print("StartBattleCommand: Iniciando batalla (%s vs %s)" % [player_participant.name, enemy_participant.name])
	SignalManager.battle_requested.emit(participants, rules)
	
	# Esperar a que termine la batalla
	while not _battle_finished:
		await context.get_tree().process_frame
	
	# Desconectar señal
	SignalManager.battle_finished.disconnect(_on_battle_finished)
	
	# Guardar estado si es un entrenador derrotado
	if battle_type == BattleType.TRAINER and _battle_winner == "player":
		# Intentar marcar el Trainer NPC como derrotado (si existe)
		# Esto también guardará el defeated_flag del Trainer automáticamente
		_mark_trainer_as_defeated(context)
	
	# Continuar con el siguiente comando
	context.continue_execution()


## Valida que la configuración del comando sea correcta
func _validate_configuration() -> bool:
	match battle_type:
		BattleType.TRAINER:
			if trainer_data == null:
				push_error("StartBattleCommand: battle_type es TRAINER pero no hay trainer_data asignado")
				return false
			if not trainer_data.has_valid_party():
				push_error("StartBattleCommand: TrainerData no tiene un equipo válido")
				return false
		
		BattleType.WILD:
			if wild_pokemon.is_empty():
				push_error("StartBattleCommand: battle_type es WILD pero no hay wild_pokemon configurados")
				return false
			# Verificar que todos los Pokemon estén inicializados
			for pokemon in wild_pokemon:
				if pokemon == null:
					push_error("StartBattleCommand: Hay un Pokemon null en wild_pokemon")
					return false
	
	return true


## Obtiene el Battler del jugador
func _get_player_battler(context: Node) -> Battler:
	var player = context.get_tree().get_first_node_in_group("Player")
	if not player:
		return null
	
	# Buscar el Battler hijo del jugador
	for child in player.get_children():
		if child is Battler:
			return child
	
	return null


## Muestra el mensaje de introducción
func _show_intro_message() -> void:
	var message_text = intro_message
	
	# Si no hay mensaje configurado pero se debe usar el del trainer
	if message_text.is_empty() and use_trainer_intro and battle_type == BattleType.TRAINER:
		if trainer_data:
			message_text = trainer_data.get_intro_message()
	
	# Si aún está vacío, no mostrar nada
	if message_text.is_empty():
		return
	
	var config = {
		"waitInput": true,
		"closeAtEnd": false,
		"waitTime": 0.0,
		"showIconAtEnd": false
	}
	
	SignalManager.message_requested.emit(message_text, config)
	await SignalManager.message_finished


## Crea un participante de entrenador desde TrainerData
func _create_trainer_participant() -> BattleParticipant:
	if not trainer_data:
		return null
	
	# Inicializar TrainerData (carga clase, equipo, etc.)
	trainer_data.initialize()
	
	# Crear un Battler temporal para convertir a BattleParticipant
	var temp_battler = Battler.new()
	temp_battler.trainer_data = trainer_data
	temp_battler.is_player = false
	
	# Cargar datos del TrainerData
	temp_battler._load_from_trainer_data()
	temp_battler._initialize_party()
	
	# Convertir a BattleParticipant
	var participant = temp_battler.to_battle_participant()
	
	# Limpiar el Battler temporal
	temp_battler.queue_free()
	
	return participant


## Crea un participante salvaje desde Pokemon runtime
func _create_wild_participant() -> BattleParticipant:
	if wild_pokemon.is_empty():
		return null
	
	# Crear BattlePokemon salvajes
	var battle_pokemon_team: Array[BattlePokemon] = []
	
	for pokemon in wild_pokemon:
		# Asegurarse de que el Pokemon esté inicializado
		if pokemon.base == null:
			pokemon._post_init()
		
		# Convertir a BattlePokemon
		var battle_pkmn = pokemon.to_battle_pokemon()
		battle_pkmn.is_wild = true
		battle_pokemon_team.append(battle_pkmn)
	
	# Crear participante salvaje
	var wild_participant = BattleParticipantWild.new(battle_pokemon_team)
	
	return wild_participant


## Marca el Trainer NPC como derrotado (si existe) y guarda el estado
func _mark_trainer_as_defeated(context: Node) -> void:
	var trainer: Trainer = null
	
	# Detectar automáticamente el Trainer desde current_page.source_event
	if context.current_page != null:
		var page = context.current_page
		# EventPage tiene source_event (asignado por EventSystem)
		if page.source_event and page.source_event is Trainer:
			trainer = page.source_event
			print("StartBattleCommand: Trainer detectado automáticamente: '%s'" % trainer.name)
	
	# Determinar qué flag usar para GameStateManager
	var flag_to_save = defeated_flag  # Primero, intentar usar el configurado en el comando
	
	# Si no hay flag en el comando pero hay un Trainer con flag, usar el del Trainer
	if flag_to_save.is_empty() and trainer and not trainer.defeated_flag.is_empty():
		flag_to_save = trainer.defeated_flag
		print("StartBattleCommand: Usando defeated_flag del Trainer: '%s'" % flag_to_save)
	
	# Guardar flag en GameStateManager
	if not flag_to_save.is_empty():
		GameStateManager.set_event_flag(flag_to_save, true)
		print("StartBattleCommand: Estado guardado en GameStateManager (flag: '%s')" % flag_to_save)
	
	# Marcar el Battler del Trainer como derrotado (si hay un Trainer detectado)
	if trainer and trainer.battler:
		trainer.battler.is_defeated = true
		print("StartBattleCommand: Trainer '%s' marcado como derrotado" % trainer.name)
		
		# Desconectar las señales de detección si el Trainer no permite rematches
		if not trainer.allow_rematch:
			trainer._disconnect_detection_signals()
			print("StartBattleCommand: Señales de detección desconectadas del Trainer '%s'" % trainer.name)
	elif trainer and not trainer.battler:
		push_warning("StartBattleCommand: El Trainer '%s' no tiene un Battler hijo" % trainer.name)


## Callback cuando la batalla termina
func _on_battle_finished(winner_side: String) -> void:
	_battle_finished = true
	_battle_winner = winner_side
	print("StartBattleCommand: Batalla terminada, ganador: %s" % winner_side)


## Indica si este comando es asíncrono
func is_async() -> bool:
	return true


## Indica si este comando es seguro para ejecución paralela
func is_safe_for_parallel() -> bool:
	return false  # Las batallas bloquean el flujo
