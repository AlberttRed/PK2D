## Clase PokemonDefinition (plantilla de Pokémon)
## Representa una plantilla/spawn definition para crear Pokémon en runtime
## Se usa en TrainerData.party, eventos/commands (wild battle predefinida, regalos, etc.)
## Es un Resource para poder exportarlo, guardarlo como .tres y configurarlo desde el inspector
extends Resource
class_name PokemonDefinition

@export_group("Datos Base")
## ID del Pokémon (usa PokemonsEnum para ver la lista)
@export var pokemon_id: PokemonsEnum.Values = PokemonsEnum.Values.BULBASAUR

@export_group("Información Básica")
## Nivel del Pokémon (1-100)
@export_range(1, 100) var level: int = 5
## Apodo opcional del Pokémon
@export var nickname: String = ""
## Género: 0 = "Sin indicar" (aleatorio según especie), 1 = Macho, 2 = Hembra, 3 = Sin Género
@export_enum("Sin indicar", "Macho", "Hembra", "Sin Género") var gender: int = 0
## Si es true, el Pokémon es shiny
@export var shiny: bool = false
## Si es true, el Pokémon es salvaje (para comportamiento en combate)
@export var is_wild: bool = false

@export_group("IVs (Individual Values)")
## Si es true, los IVs se generarán aleatoriamente (0-31) al crear el Pokémon
@export var randomize_ivs: bool = false
## IVs individuales (0-31). Se usan si randomize_ivs es false
@export_range(0, 31) var hp_IVs: int = 0
@export_range(0, 31) var attack_IVs: int = 0
@export_range(0, 31) var defense_IVs: int = 0
@export_range(0, 31) var spAttack_IVs: int = 0
@export_range(0, 31) var spDefense_IVs: int = 0
@export_range(0, 31) var speed_IVs: int = 0

@export_group("EVs (Effort Values)")
## Si es true, los EVs se generarán aleatoriamente (0-252) al crear el Pokémon
@export var randomize_evs: bool = false
## EVs individuales (0-252). Se usan si randomize_evs es false
@export_range(0, 252) var hp_EVs: int = 0
@export_range(0, 252) var attack_EVs: int = 0
@export_range(0, 252) var defense_EVs: int = 0
@export_range(0, 252) var spAttack_EVs: int = 0
@export_range(0, 252) var spDefense_EVs: int = 0
@export_range(0, 252) var speed_EVs: int = 0

@export_group("Naturaleza y Habilidad")
## ID de la naturaleza (usa NaturesEnum). Si es NONE, se generará aleatoriamente
@export var nature_id: NaturesEnum.Values = NaturesEnum.Values.SERIOUS
## ID de la habilidad (usa AbilitiesEnum). NONE = aleatorio según especie
@export var ability_id: AbilitiesEnum.Values = AbilitiesEnum.Values.NONE

@export_group("Moveset (Movimientos)")
## Define hasta 4 movimientos personalizados (IDs).
## Si está vacío, el Pokémon aprenderá movimientos automáticamente según su nivel.
## Ejemplo: [33, 45, 98, 156] para Tackle, Growl, Quick Attack, Rest
@export var custom_move_ids: Array[MovesEnum.Values] = []

@export_group("Otros")
## ID del objeto equipado (0 = sin objeto)
@export var held_item_id: int = 0

## Crea un Pokemon runtime a partir de esta definición
## Retorna un Pokemon runtime listo para usar en combate, party, etc.
func create_pokemon() -> Pokemon:
	var pokemon = Pokemon.new()

	# Configurar datos base
	pokemon.pokemon_id = pokemon_id

	# Configurar información básica
	pokemon.level = level
	pokemon.nickname = nickname
	pokemon.shiny = shiny
	pokemon.is_wild = is_wild

	# Configurar género
	# Si gender es 0 ("Sin indicar"), se calculará automáticamente en _post_init
	# Si es un valor específico, se usará directamente
	pokemon.gender = gender

	# Configurar naturaleza
	# Si nature_id es NONE, se generará aleatoriamente
	if nature_id == NaturesEnum.Values.NONE:
		pokemon.nature_id = NaturesEnum.get_random_nature() as NaturesEnum.Values
	else:
		pokemon.nature_id = nature_id

	# Configurar habilidad
	# Si ability_id es NONE, se calculará automáticamente en _post_init
	pokemon.ability_id = ability_id

	# Configurar IVs
	if randomize_ivs:
		pokemon.hp_IVs = randi_range(0, 31)
		pokemon.attack_IVs = randi_range(0, 31)
		pokemon.defense_IVs = randi_range(0, 31)
		pokemon.spAttack_IVs = randi_range(0, 31)
		pokemon.spDefense_IVs = randi_range(0, 31)
		pokemon.speed_IVs = randi_range(0, 31)
	else:
		pokemon.hp_IVs = hp_IVs
		pokemon.attack_IVs = attack_IVs
		pokemon.defense_IVs = defense_IVs
		pokemon.spAttack_IVs = spAttack_IVs
		pokemon.spDefense_IVs = spDefense_IVs
		pokemon.speed_IVs = speed_IVs

	# Configurar EVs
	if randomize_evs:
		pokemon.hp_EVs = randi_range(0, 252)
		pokemon.attack_EVs = randi_range(0, 252)
		pokemon.defense_EVs = randi_range(0, 252)
		pokemon.spAttack_EVs = randi_range(0, 252)
		pokemon.spDefense_EVs = randi_range(0, 252)
		pokemon.speed_EVs = randi_range(0, 252)
	else:
		pokemon.hp_EVs = hp_EVs
		pokemon.attack_EVs = attack_EVs
		pokemon.defense_EVs = defense_EVs
		pokemon.spAttack_EVs = spAttack_EVs
		pokemon.spDefense_EVs = spDefense_EVs
		pokemon.speed_EVs = speed_EVs

	# Configurar movimientos personalizados
	pokemon.custom_move_ids = custom_move_ids.duplicate()

	# Configurar objeto equipado
	pokemon.held_item_id = held_item_id

	# Inicializar el Pokemon (cargar base, calcular stats, movimientos, etc.)
	# Esto carga el PokemonData, inicializa stats, movimientos, HP, etc.
	pokemon._post_init()

	return pokemon
