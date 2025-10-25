extends Node
class_name Battler
## Representa un entrenador (Trainer) o al jugador en combate.
## Gestiona el equipo de Pokémon y convierte los datos a BattleParticipant.
##
## Configuración:
## - Asignar TrainerData en el inspector (contiene equipo, textos, IA, sprites)
## - Marcar is_player=true para el jugador
## - Todas las propiedades se cargan automáticamente desde TrainerData

## === CONFIGURACIÓN DEL ENTRENADOR ===

@export_group("Trainer Data")
## TrainerData Resource con toda la información del entrenador (equipo, textos, IA, sprites, etc.)
@export var trainer_data: TrainerData = null

@export_group("Player Config")
## Marcar como true si este Battler pertenece al jugador
@export var is_player: bool = false

@export_group("State")
## Si el entrenador ya fue derrotado
@export var is_defeated: bool = false

@export_group("Partner (for Double Battles)")
## Ruta al Battler del partner para combates dobles
@export var partner_path: NodePath = ""

## === PROPIEDADES INTERNAS (cargadas desde TrainerData) ===

## Estos campos se cargan automáticamente desde trainer_data en _ready()
var trainer_id: int = -1
var trainer_name: String = ""
var battler_type: CONST.BATTLER_TYPES = CONST.BATTLER_TYPES.TRAINER
var battle_ia: BattleIA = null
var allow_double_battle: bool = false
var battle_front_sprite: Texture
var battle_back_sprite: Texture = null
var before_battle_message: String = ""
var init_battle_message: String = ""
var end_battle_message: String = ""
var party: Array[Pokemon] = []


func _ready() -> void:
	_load_from_trainer_data()
	_initialize_party()


## Carga la configuración desde TrainerData si existe
func _load_from_trainer_data() -> void:
	if trainer_data == null:
		push_warning("Battler: No se ha asignado TrainerData. El Battler no tendrá datos configurados.")
		return
	
	# Inicializar TrainerData (carga TrainerClassData desde el enum)
	trainer_data.initialize()
	
	# Cargar propiedades básicas
	trainer_id = trainer_data.trainer_id
	trainer_name = trainer_data.display_name
	battle_ia = trainer_data.ai_profile
	allow_double_battle = trainer_data.double_battle
	
	# Cargar sprites (front y back) con fallback a los de la clase
	battle_front_sprite = trainer_data.get_battle_front_sprite()
	battle_back_sprite = trainer_data.get_battle_back_sprite()
	
	# Cargar textos
	before_battle_message = trainer_data.intro_text
	init_battle_message = trainer_data.intro_text  # Usar intro para ambos
	end_battle_message = trainer_data.defeat_text
	
	# Cargar equipo desde TrainerData
	party = trainer_data.create_party()
	
	print("Battler: Cargado desde TrainerData '%s' (%d Pokémon)" % [trainer_data.get_full_name(), party.size()])


## Inicializa el equipo cargado desde TrainerData
## Si el equipo está vacío, muestra una advertencia
func _initialize_party() -> void:
	var trainer_display_name = trainer_data.display_name if trainer_data else trainer_name
	
	if party.is_empty():
		push_warning("Battler '%s': No tiene Pokémon en el equipo. Asegúrate de configurar party_data en el TrainerData." % trainer_display_name)
		return
	
	# Inicializar cada Pokemon del array (cargados desde TrainerData)
	for pokemon in party:
		if pokemon:
			# Solo llamar _post_init si el Pokemon no está inicializado
			if pokemon.base == null:
				pokemon._post_init()
	
	print("Battler '%s': Equipo cargado e inicializado (%d Pokémon)" % [trainer_display_name, party.size()])


## Agrega un Pokémon al equipo (runtime)
func add_pokemon_to_party(pokemon) -> void:  # pokemon: Pokemon
	if pokemon == null:
		push_warning("Battler: Intentando agregar un Pokémon nulo")
		return
	
	party.append(pokemon)

## Agrega un Pokémon desde PokemonData (crea el runtime automáticamente)
func add_pokemon_from_data(pokemon_data: PokemonData, level: int = 5, gender: int = -1) -> void:
	if pokemon_data == null:
		push_warning("Battler: PokemonData nulo")
		return
	
	# Crear Pokemon con stats aleatorios
	var pokemon = Pokemon.new(
		pokemon_data,     # pokemon_data
		level,            # pokemon_level
		gender,           # pokemon_gender (0 = aleatorio)
		0,                # pokemon_ability (0 = aleatorio según especie)
		0,                # pokemon_nature (0 = aleatorio)
		true              # randomize_stats (IVs aleatorios)
	)
	
	if battler_type == CONST.BATTLER_TYPES.TRAINER:
		pokemon.trainer_id = trainer_id
		pokemon.original_trainer = trainer_name if not trainer_name.is_empty() else "Desconocido"
	
	party.append(pokemon)


## Elimina un Pokémon del equipo
func remove_pokemon_from_party(pokemon) -> void:  # pokemon: Pokemon
	var index = party.find(pokemon)
	if index != -1:
		party.remove_at(index)


## Verifica si tiene un Pokémon específico
func has_pokemon(pokemon) -> bool:  # pokemon: Pokemon
	return party.has(pokemon)


## Obtiene el número de Pokémon en el equipo
func get_party_size() -> int:
	return party.size()


## Obtiene el número de Pokémon no debilitados
func get_alive_pokemon_count() -> int:
	var count := 0
	for pokemon in party:
		if pokemon.hp_actual > 0:
			count += 1
	return count


## Verifica si el entrenador puede pelear
func can_battle() -> bool:
	return get_alive_pokemon_count() > 0


## Obtiene el nombre completo del entrenador (clase + nombre si trainer_data existe)
func get_full_name() -> String:
	if trainer_data:
		return trainer_data.get_full_name()
	return trainer_name


## Obtiene la recompensa en dinero por ganar
func get_reward_money() -> int:
	if trainer_data:
		return trainer_data.calculate_reward()
	return 0  # Sin trainer_data, no hay recompensa definida


## Obtiene el texto de introducción
func get_intro_text() -> String:
	if trainer_data:
		return trainer_data.get_intro_message()
	return before_battle_message if not before_battle_message.is_empty() else "¡Vamos a combatir!"


## Obtiene el texto de derrota
func get_defeat_text() -> String:
	if trainer_data:
		return trainer_data.get_defeat_message()
	return end_battle_message if not end_battle_message.is_empty() else "He perdido..."


## === CONVERSIÓN A BATTLEPARTICIPANT ===

## Convierte este Battler a un BattleParticipant para usar en combate
func to_battle_participant() -> BattleParticipant:
	var participant := BattleParticipant.new()
	
	# Configurar datos del participante
	participant.trainer_id = trainer_id
	# Usar get_full_name() para incluir la clase del trainer (ej: "Cazabichos Jano")
	var effective_name: String = get_full_name() if trainer_data else (trainer_name if not trainer_name.is_empty() else str(name))
	participant.name = effective_name
	participant.is_player = is_player
	participant.ai_controller = battle_ia
	participant.is_trainer = (battler_type != CONST.BATTLER_TYPES.WILD_POKEMON)
	
	# Convertir el equipo a BattlePokemon
	for pokemon in party:
		var battle_pokemon = pokemon.to_battle_pokemon()  # BattlePokemon
		battle_pokemon.controllable = is_player
		battle_pokemon.participant = participant
		participant.add_pokemon(battle_pokemon)
	
	return participant


## === MÉTODOS DE UTILIDAD ===

## Obtiene el partner para batallas dobles
func get_partner() -> Battler:
	if partner_path.is_empty():
		return null
	
	var partner_node = get_node_or_null(partner_path)
	if partner_node and partner_node is Battler:
		return partner_node
	
	return null


## Imprime información del equipo (debug)
func print_party_info() -> void:
	print("=== Battler: %s ===" % trainer_name)
	print("  Tipo: %s" % CONST.BATTLER_TYPES.keys()[battler_type])
	print("  Es jugador: %s" % is_player)
	print("  Equipo (%d):" % party.size())
	for i in party.size():
		var pokemon = party[i]
		print("    %d. %s (Lv.%d) - HP: %d/%d" % [
			i + 1,
			pokemon.get_display_name(),
			pokemon.level,
			pokemon.hp_actual,
			pokemon.get_final_stat(StatsEnum.Values.HP)
		])


## === MÉTODOS LEGACY (compatibilidad) ===

## Crea un Battler programáticamente (para código legacy)
func create(
	_type: CONST.BATTLER_TYPES,
	_party: Array,
	_IA: BattleIA,
	_name: String = "",
	_battle_front_sprite: Texture = null,
	_battle_back_sprite: Texture = null,
	_before_battle_message: String = "",
	_init_battle_message: String = "",
	_end_battle_message: String = "",
	_is_defeated: bool = false,
	_double_battle: bool = false,
	_is_playable: bool = false,
	_partner: NodePath = NodePath("")
) -> Battler:
	
	battler_type = _type
	battle_ia = _IA
	trainer_name = _name
	battle_front_sprite = _battle_front_sprite
	battle_back_sprite = _battle_back_sprite
	before_battle_message = _before_battle_message
	init_battle_message = _init_battle_message
	end_battle_message = _end_battle_message
	is_defeated = _is_defeated
	allow_double_battle = _double_battle
	is_player = _is_playable
	partner_path = _partner
	
	# Agregar Pokémon al equipo
	party.clear()
	for p in _party:
		if p is Pokemon:
			add_pokemon_to_party(p)
	
	return self
