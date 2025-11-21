extends Node
class_name WildEncounterSystem

## Sistema de encuentros salvajes
## Gestiona la probabilidad y generación de combates salvajes
##
## Este sistema escucha las señales de TileEffectSystem cuando el jugador
## pisa tiles con encounter_type, y gestiona la lógica de probabilidad
## y generación de combates salvajes.

signal battle_requested(participants: Array, rules: BattleRules)

var context: OverworldContext = null
var world_system: WorldSystem = null
var tile_effect_system: TileEffectSystem = null

# Cache del MapAreaEncounters del mapa actual
var current_map_encounters: MapAreaEncounters = null
var current_map_name: String = ""

# Cooldown entre encuentros (en pasos)
var encounter_cooldown: int = 0
var steps_since_last_encounter: int = 0

# Flag para deshabilitar encuentros
@export var encounters_enabled: bool = false


func _ready() -> void:
	pass  # Sistema inicializado


## Inicializa el sistema con el contexto
func initialize(overworld_context: OverworldContext) -> void:
	context = overworld_context
	world_system = context.get_world_system()
	tile_effect_system = context.get_system("TileEffect")

	# Conectar a la señal de TileEffectSystem
	if tile_effect_system:
		tile_effect_system.tile_effect_triggered.connect(_on_tile_effect_triggered)

	# Conectar a señales de cambio de mapa
	if context:
		context.seamless_map_crossed.connect(_on_map_changed)
		var warp_sys = context.get_warp_system()
		if warp_sys:
			warp_sys.warp_finished.connect(_on_map_changed_warp)

	_update_encounters_cache()


## Se ejecuta cuando TileEffectSystem detecta un tile de encuentro
func _on_tile_effect_triggered(_tile_pos: Vector2i, encounter_type: String, actor: Node2D) -> void:
	# Solo procesar si es el jugador
	if not actor.is_in_group("Player"):
		return

	# Verificar cooldown
	if steps_since_last_encounter < encounter_cooldown:
		steps_since_last_encounter += 1
		return

	# Verificar si los encuentros están habilitados
	if not encounters_enabled:
		return

	# Verificar si el mapa tiene encuentros configurados
	if not current_map_encounters:
		return

	# Convertir encounter_type string a enum
	var encounter_type_enum = EncounterAreaTypeEnum.parse_type(encounter_type)
	if not encounter_type_enum or encounter_type_enum == EncounterAreaTypeEnum.Values.NONE:
		return

	# Verificar si hay encuentros para este tipo
	if not current_map_encounters.has_encounters_for_area(encounter_type_enum):
		return

	# Intentar generar encuentro
	_try_trigger_encounter(encounter_type_enum)


## Intenta generar un encuentro salvaje
func _try_trigger_encounter(encounter_type: EncounterAreaTypeEnum.Values) -> void:
	if not current_map_encounters:
		return

	var encounter_data = current_map_encounters.try_wild_encounter(encounter_type)
	if encounter_data.is_empty():
		return  # No hubo encuentro esta vez

	# Hay un encuentro, generar el combate
	print("WildEncounterSystem: ¡Encuentro salvaje!")
	print("  Pokémon: %d, Nivel: %d" % [encounter_data["pokemon_id"], encounter_data["level"]])

	steps_since_last_encounter = 0  # Resetear cooldown
	_start_wild_battle(encounter_data)


## Inicia un combate salvaje
func _start_wild_battle(encounter_data: Dictionary) -> void:
	var wild_pokemon_instance = _create_wild_pokemon(
		encounter_data["pokemon_id"],
		encounter_data["level"]
	)
	if not wild_pokemon_instance:
		push_error("WildEncounterSystem: No se pudo crear el Pokémon salvaje")
		return

	var wild_participant = BattleParticipantWild.new([wild_pokemon_instance.to_battle_pokemon()])
	var player_participant = _get_player_participant()
	if not player_participant:
		push_error("WildEncounterSystem: No se pudo obtener el participante del jugador")
		return

	var rules = BattleRules.new(
		BattleRules.BattleTypes.WILD,
		BattleRules.BattleModes.SINGLE
	)

	var participants: Array[BattleParticipant] = [player_participant, wild_participant]

	# Emitir señal para que DisplayManager inicie el combate
	battle_requested.emit(participants, rules)


## Obtiene el BattleParticipant del jugador
func _get_player_participant() -> BattleParticipant:
	if not context:
		return null

	var player = context.get_player()
	if not player:
		return null

	var battler = player.get_node_or_null("Battler")
	if battler and battler is Battler:
		if battler.can_battle():
			return battler.to_battle_participant()

	# Fallback: usar GameStateService
	var player_team: Array = GameStateService.get_player_party()
	if player_team.is_empty():
		return null

	var battle_team: Array[BattlePokemon] = []
	for pokemon_instance in player_team:
		if pokemon_instance is Pokemon:
			battle_team.append(pokemon_instance.to_battle_pokemon())

	var participant = BattleParticipant.new(battle_team)
	participant.name = "Player"
	participant.is_player = true
	return participant


## Crea un Pokémon salvaje
func _create_wild_pokemon(pokemon_id: int, level: int):
	var pokemon_data = DatabaseService.get_pokemon(pokemon_id)
	var pokemon = Pokemon.new(
		pokemon_data,
		level,
		0,  # gender (aleatorio)
		0,  # ability (aleatorio)
		0,  # nature (aleatorio)
		true  # randomize_stats
	)
	pokemon.is_wild = true
	return pokemon


## Actualiza el cache de MapAreaEncounters
func _update_encounters_cache() -> void:
	current_map_encounters = null
	current_map_name = ""

	if not world_system:
		return

	var active_grid = world_system.get_active_grid()
	if not active_grid:
		return

	var current_map = active_grid.get_parent()
	if not current_map:
		return

	current_map_name = current_map.name

	# Buscar MapAreaEncounters
	var encounters_node = current_map.get_node_or_null("MapAreaEncounters")
	if encounters_node and encounters_node is MapAreaEncounters:
		current_map_encounters = encounters_node
		print("WildEncounterSystem: Mapa '%s' → CON encuentros" % current_map_name)
		return

	# Buscar recursivamente
	for child in current_map.get_children():
		if child is MapAreaEncounters:
			current_map_encounters = child
			print("WildEncounterSystem: Mapa '%s' → CON encuentros" % current_map_name)
			return

	print("WildEncounterSystem: Mapa '%s' → SIN encuentros" % current_map_name)


## Callback cuando se cambia de mapa
func _on_map_changed(from_map: String, _to_map: String) -> void:
	if from_map != current_map_name:
		steps_since_last_encounter = 0  # Resetear cooldown
	_update_encounters_cache()


## Callback cuando se hace warp
func _on_map_changed_warp(_map_id: String, _spawn_id: String) -> void:
	steps_since_last_encounter = 0
	_update_encounters_cache()


## Habilita o deshabilita los encuentros
func set_encounters_enabled(enabled: bool) -> void:
	encounters_enabled = enabled
	print("WildEncounterSystem: Encuentros %s" % ("habilitados" if enabled else "deshabilitados"))
