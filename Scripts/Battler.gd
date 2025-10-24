extends Node
class_name Battler
## Representa un entrenador (Trainer) o al jugador en combate.
## Gestiona el equipo de Pokémon y convierte los datos a BattleParticipant.
##
## El equipo se puede configurar de dos formas:
## 1. **Resources (recomendado)**: Array exportado de Pokemon resources
## 2. **Nodos hijos (legacy)**: Pokemon como nodos hijos (para testing/compatibilidad)

## === CONFIGURACIÓN DEL ENTRENADOR ===

@export_group("Trainer Info")
@export var trainer_id: int = -1
@export var trainer_name: String = ""
@export var is_player: bool = false

@export_group("Battle Settings")
@export var battler_type: CONST.BATTLER_TYPES = CONST.BATTLER_TYPES.TRAINER
@export var battle_ia: BattleIA = null
@export var allow_double_battle: bool = false

@export_group("Sprites")
@export var battle_front_sprite: Texture
@export var battle_back_sprite: Texture = null

@export_group("Messages")
@export_multiline var before_battle_message: String = ""
@export_multiline var init_battle_message: String = ""
@export_multiline var end_battle_message: String = ""

@export_group("State")
@export var is_defeated: bool = false

@export_group("Party (Equipo Pokémon)")
## Configura el equipo desde el inspector:
## Puedes arrastrar Pokemon (runtime .tres) ya creados,
## O dejar vacío y construir el equipo en código con add_pokemon_from_data()
@export var party: Array[Pokemon] = []

@export_group("Partner (for Double Battles)")
@export var partner_path: NodePath = ""


func _ready() -> void:
	_initialize_party()


## Inicializa el equipo
## Si ya hay Pokemon en el array party (configurados desde inspector), inicializarlos
## Si está vacío, se debe construir el equipo con add_pokemon_from_data()
func _initialize_party() -> void:
	if party.is_empty():
		push_warning("Battler '%s': No tiene Pokémon en el equipo. Configúralos desde el inspector o usa add_pokemon_from_data()." % trainer_name)
		return
	
	# Inicializar cada Pokemon del array (configurados desde inspector)
	for pokemon in party:
		if pokemon:
			pokemon._post_init()
	
	print("Battler '%s': Equipo cargado e inicializado (%d Pokémon)" % [trainer_name, party.size()])


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


## === CONVERSIÓN A BATTLEPARTICIPANT ===

## Convierte este Battler a un BattleParticipant para usar en combate
func to_battle_participant() -> BattleParticipant:
	var participant := BattleParticipant.new()
	
	# Configurar datos del participante
	participant.trainer_id = trainer_id
	var effective_name: String = trainer_name if not trainer_name.is_empty() else str(name)
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
