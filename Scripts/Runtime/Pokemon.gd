## Clase Pokemon (runtime)
## Representa un Pokémon "vivo" durante el juego (combate, party, PC, etc.)
## Se crea a partir de un PokemonData y contiene propiedades runtime como nivel, IVs, EVs, etc.
## Es un Resource para poder exportarlo, guardarlo como .tres y configurarlo desde el inspector
extends Resource
class_name Pokemon

signal newMoveLearned

@export_group("Datos Base")
## ID del Pokémon (usa PokemonsEnum para ver la lista)
## Se cargará automáticamente el PokemonData desde DatabaseManager
@export var pokemon_id: PokemonsEnum.Values = PokemonsEnum.Values.BULBASAUR

@export_group("Información Básica")
@export var nickname: String = ""
@export_range(1, 100) var level: int = 5
@export_enum("Sin indicar", "Macho", "Hembra", "Sin Género") var gender: int = 0
@export var is_wild: bool = false
@export var shiny: bool = false

@export_group("IVs (Individual Values)")
@export_range(0, 31) var hp_IVs: int = 0
@export_range(0, 31) var attack_IVs: int = 0
@export_range(0, 31) var defense_IVs: int = 0
@export_range(0, 31) var spAttack_IVs: int = 0
@export_range(0, 31) var spDefense_IVs: int = 0
@export_range(0, 31) var speed_IVs: int = 0

@export_group("EVs (Effort Values)")
@export_range(0, 252) var hp_EVs: int = 0
@export_range(0, 252) var attack_EVs: int = 0
@export_range(0, 252) var defense_EVs: int = 0
@export_range(0, 252) var spAttack_EVs: int = 0
@export_range(0, 252) var spDefense_EVs: int = 0
@export_range(0, 252) var speed_EVs: int = 0

@export_group("Naturaleza y Habilidad")
## Usa NaturesEnum para ver la lista de naturalezas
@export var nature_id: NaturesEnum.Values = NaturesEnum.Values.SERIOUS
## Usa AbilitiesEnum para ver la lista de habilidades (NONE = aleatorio según especie)
@export var ability_id: AbilitiesEnum.Values = AbilitiesEnum.Values.NONE

@export_group("Otros")
@export var held_item_id: int = 0

@export_group("Moveset (Movimientos)")
## Define hasta 4 movimientos personalizados (IDs). 
## Si está vacío, el Pokémon aprenderá movimientos automáticamente según su nivel.
## Ejemplo: [33, 45, 98, 156] para Tackle, Growl, Quick Attack, Rest
@export var custom_move_ids: Array[MovesEnum.Values] = []

# Propiedades calculadas/runtime (no exportadas)
var base: PokemonData  # Se carga desde pokemon_id
var hp_actual: int = 0
var totalExp: int = 0
var ivs: Dictionary[StatsEnum.Values, int] = {}
var evs: Dictionary[StatsEnum.Values, int] = {}
var base_stats: Dictionary[StatsEnum.Values, int] = {}
var nature: NatureData  # Se carga desde nature_id
var ability: AbilityData  # Se carga desde ability_id
var ability_slot: int = 0
var movements: Array = []  # Array[Move]
var newLearningMove = null  # Move
var trainer_id: int = 1234
var original_trainer: String = "Red"
var capture_date: String = ""
var capture_route: String = ""
var capture_level: int = 5
var personality: String = ""

# Experiencia
var experienceGroup: PokemonExperienceGroup:
	get:
		return PokemonExperienceGroup.new(base.growth_rate_id)

var actualLevelExpBase: int:
	get:
		return experienceGroup.calculateExp(level)

var nextLevelExpBase: int:
	get:
		if level < 100:
			return experienceGroup.calculateExp(level + 1)
		else:
			return totalExp

# Battle state
var inBattle: bool = false
var inBattleParty: bool = false
var fainted: bool:
	get:
		return hp_actual == 0

var learningMoves: Array[PokemonLearningMove] = []

## Constructor principal
## 
## Creación desde inspector: Llamar sin parámetros, luego _post_init() inicializará desde @export vars
## Creación por código: Proporcionar al menos pokemon_data o pokemon_id
##
## @param pokemon_data: PokemonData, int (pokemon_id), o null (inspector)
## @param pokemon_level: Nivel inicial (5 por defecto)
## @param pokemon_gender: Género específico, 0 para aleatorio, null para mantener @export
## @param pokemon_ability: ID de habilidad, 0 para aleatorio según especie, null para mantener @export
## @param pokemon_nature: NatureEnum, 0 para aleatorio, null para mantener @export
## @param randomize_stats: Si true, genera IVs aleatorios (0-31)
func _init(
	pokemon_data = null,
	pokemon_level: int = 5,
	pokemon_gender = null,
	pokemon_ability = null,
	pokemon_nature = null,
	randomize_stats: bool = false
) -> void:
	# Creación desde inspector: sin parámetros, inicializar después con _post_init()
	if pokemon_data == null:
		return
	
	# Cargar PokemonData
	if pokemon_data is int:
		pokemon_id = pokemon_data as PokemonsEnum.Values
		base = DatabaseManager.get_pokemon(pokemon_data)
	elif pokemon_data is PokemonData:
		base = pokemon_data
		pokemon_id = base.id as PokemonsEnum.Values
	else:
		push_error("Pokemon._init: pokemon_data debe ser PokemonData o int (pokemon_id)")
		return
	
	if base == null:
		push_error("Pokemon._init: No se pudo cargar PokemonData para id %s" % str(pokemon_data))
		return
	
	# Configurar nivel
	level = pokemon_level
	
	# Configurar género
	if pokemon_gender == null:
		# Mantener valor @export o calcular si es 0 ("Sin indicar")
		if gender == 0:
			gender = _calculate_gender()
	elif pokemon_gender == 0:
		gender = _calculate_gender()
	else:
		gender = pokemon_gender
	
	# Configurar habilidad
	if pokemon_ability == null:
		# Mantener valor @export o calcular si es NONE
		if ability_id == AbilitiesEnum.Values.NONE:
			ability_id = _calculate_ability() as AbilitiesEnum.Values
	elif pokemon_ability == 0:
		ability_id = _calculate_ability() as AbilitiesEnum.Values
	else:
		ability_id = pokemon_ability as AbilitiesEnum.Values
	ability = DatabaseManager.get_ability(ability_id)
	
	# Configurar naturaleza
	if pokemon_nature == null:
		# Mantener valor @export (por defecto SERIOUS)
		pass
	elif pokemon_nature == 0:
		nature_id = NaturesEnum.get_random_nature() as NaturesEnum.Values
	else:
		nature_id = pokemon_nature as NaturesEnum.Values
	nature = DatabaseManager.get_nature(NaturesEnum.get_id(nature_id))
	
	# Inicializar stats (IVs, EVs, base_stats)
	_initialize_stats(randomize_stats)
	
	# Cargar movimientos
	_load_learnable_moves()
	_load_initial_moves()
	
	# Configurar estado inicial
	hp_actual = get_final_stat(StatsEnum.Values.HP)
	totalExp = actualLevelExpBase
	personality = get_personality_text()
	
	# Configurar nombre para el inspector
	_update_resource_name()

## Inicialización posterior (cuando se crea desde inspector)
## Battler.gd llamará esto en _ready() para inicializar Pokemon del inspector
func _post_init() -> void:
	# Cargar PokemonData desde el enum pokemon_id
	base = DatabaseManager.get_pokemon(pokemon_id)
	if base == null:
		push_error("Pokemon._post_init: No se pudo cargar PokemonData para id %d" % pokemon_id)
		return
	
	# Calcular valores automáticos si no están configurados
	if gender == 0:  # "Sin indicar"
		gender = _calculate_gender()
	
	if ability_id == AbilitiesEnum.Values.NONE:
		ability_id = _calculate_ability() as AbilitiesEnum.Values
	ability = DatabaseManager.get_ability(ability_id)
	
	nature = DatabaseManager.get_nature(NaturesEnum.get_id(nature_id))
	
	# Inicializar stats (NO aleatorizar, usar valores @export)
	_initialize_stats(false)
	
	# Cargar movimientos
	_load_learnable_moves()
	_load_initial_moves()
	
	# Configurar estado inicial
	hp_actual = get_final_stat(StatsEnum.Values.HP)
	totalExp = actualLevelExpBase
	personality = get_personality_text()
	
	# Configurar nombre para el inspector
	_update_resource_name()

## Actualiza el resource_name para que se muestre bien en el inspector
func _update_resource_name() -> void:
	if base == null:
		resource_name = "Pokemon (sin configurar)"
		return
	
	var display_text = ""
	
	# Mostrar nickname si existe
	if not nickname.is_empty():
		display_text = "%s (%s)" % [nickname, base.Name]
	else:
		display_text = base.Name
	
	# Añadir nivel
	display_text += " Lv.%d" % level
	
	# Añadir género si no es "sin indicar"
	match gender:
		CONST.GENEROS.MACHO:
			display_text += " ♂"
		CONST.GENEROS.HEMBRA:
			display_text += " ♀"
	
	resource_name = display_text

## Inicializa IVs, EVs y base stats
func _initialize_stats(_randomize: bool = false) -> void:
	# Base stats (del PokemonData)
	base_stats = {
		StatsEnum.Values.HP: base.hp_base,
		StatsEnum.Values.ATTACK: base.attack_base,
		StatsEnum.Values.DEFENSE: base.defense_base,
		StatsEnum.Values.SP_ATTACK: base.special_attack_base,
		StatsEnum.Values.SP_DEFENSE: base.special_defense_base,
		StatsEnum.Values.SPEED: base.speed_base,
		StatsEnum.Values.ACCURACY: 100,
		StatsEnum.Values.EVASION: 100
	}
	
	# IVs - usar los valores @export configurados o aleatorizar
	if _randomize:
		hp_IVs = randi_range(0, 31)
		attack_IVs = randi_range(0, 31)
		defense_IVs = randi_range(0, 31)
		spAttack_IVs = randi_range(0, 31)
		spDefense_IVs = randi_range(0, 31)
		speed_IVs = randi_range(0, 31)
	
	# Copiar IVs exportados al diccionario
	ivs = {
		StatsEnum.Values.HP: hp_IVs,
		StatsEnum.Values.ATTACK: attack_IVs,
		StatsEnum.Values.DEFENSE: defense_IVs,
		StatsEnum.Values.SP_ATTACK: spAttack_IVs,
		StatsEnum.Values.SP_DEFENSE: spDefense_IVs,
		StatsEnum.Values.SPEED: speed_IVs
	}
	
	# Copiar EVs exportados al diccionario
	evs = {
		StatsEnum.Values.HP: hp_EVs,
		StatsEnum.Values.ATTACK: attack_EVs,
		StatsEnum.Values.DEFENSE: defense_EVs,
		StatsEnum.Values.SP_ATTACK: spAttack_EVs,
		StatsEnum.Values.SP_DEFENSE: spDefense_EVs,
		StatsEnum.Values.SPEED: speed_EVs
	}

## Calcula el género basándose en gender_rate
## Calcula el género aleatorio basado en el ratio de la especie
func _calculate_gender() -> int:
	if base.gender_rate == -1:
		return CONST.GENEROS.SIN_GENERO
	else:
		var female_chance: float = float(base.gender_rate) / 8.0
		var rand_num = randf_range(0, 1)
		if rand_num <= female_chance:
			return CONST.GENEROS.HEMBRA
		else:
			return CONST.GENEROS.MACHO

## Calcula la habilidad aleatoria según las disponibles para la especie
func _calculate_ability() -> int:
	ability_slot = randi_range(0, 1)
	var selected_ability = base.abilities[ability_slot]
	
	# Si es null, usar el slot 0
	if selected_ability == null:
		selected_ability = base.abilities[0]
	
	# Convertir string a int (abilities está guardado como array de strings en .tres)
	if selected_ability is String:
		return int(selected_ability)
	else:
		return selected_ability

## Carga la lista de movimientos aprendibles según el PokemonData
func _load_learnable_moves() -> void:
	learningMoves.clear()
	for i in range(base.learn_move_id.size()):
		learningMoves.push_back(
			PokemonLearningMove.new(
				base.learn_move_id[i] as int,
				base.learn_type[i] as int,
				base.learn_lvl[i] as int
			)
		)

## Carga los movimientos iniciales según el nivel actual o movimientos personalizados
func _load_initial_moves() -> void:
	movements.clear()
	
	# Si hay movimientos personalizados definidos, usarlos en lugar de los automáticos
	if not custom_move_ids.is_empty():
		_load_custom_moves()
		return
	
	# Lógica por defecto: cargar movimientos según nivel
	var available_moves: Array[PokemonLearningMove] = learningMoves.filter(
		func(move: PokemonLearningMove):
			return move.learningType == PokemonLearningMove.Type.LVL_UP and move.learningLevel <= level
	).slice(0, 4)
	
	for learning_move in available_moves:
		movements.append(learning_move.getMove())

## Carga movimientos personalizados desde custom_move_ids
func _load_custom_moves() -> void:
	var move_count = min(custom_move_ids.size(), 4)  # Máximo 4 movimientos
	
	for i in range(move_count):
		var move_enum = custom_move_ids[i]
		var move_id = int(move_enum)  # Convertir enum a int
		
		if move_id > 0:  # Validar que sea un ID válido
			var move = Move.new(move_id)
			if move.base != null:  # Verificar que el movimiento se cargó correctamente
				movements.append(move)
			else:
				push_warning("Pokemon: No se pudo cargar el movimiento con ID %d" % move_id)

## Añade un movimiento (máximo 4)
func addMove(_move) -> void:  # _move: Move - evitamos referencia circular
	if movements.size() >= 4:
		push_warning("Pokemon ya tiene 4 movimientos")
		return
	movements.push_back(_move)

## Obtiene un stat final calculado (con IVs, EVs y naturaleza)
func get_final_stat(stat: StatsEnum.Values, _level: int = self.level) -> int:
	var base_stat = base_stats.get(stat, 0)
	var iv = ivs.get(stat, 0)
	var ev = evs.get(stat, 0)
	
	var total = ((2 * base_stat + iv + int(ev / 4)) * _level) / 100
	
	if stat == StatsEnum.Values.HP:
		return int(total) + _level + 10
	else:
		var multiplier = 1.0
		if nature:
			multiplier = nature.get_stat_multiplier(stat)
		return int((total + 5) * multiplier)

func get_base_stat(stat: StatsEnum.Values) -> int:
	return base_stats.get(stat, 0)

func get_iv(stat: StatsEnum.Values) -> int:
	return ivs.get(stat, 0)

func get_ev(stat: StatsEnum.Values) -> int:
	return evs.get(stat, 0)

## Sube de nivel
func levelUP() -> void:
	var previousHP: float = get_final_stat(StatsEnum.Values.HP)
	level += 1
	var newHP: float = get_final_stat(StatsEnum.Values.HP)
	var incrHP: float = (newHP - previousHP) / previousHP * 100.0
	var hpAdd = ceil(hp_actual * (incrHP / 100.0))
	hp_actual = hp_actual + hpAdd

## Verifica si aprendió un nuevo movimiento al subir de nivel
func checkNewLevelMoveLearned() -> void:
	newLearningMove = null
	var newMove: PokemonLearningMove = learningMoves.filter(
		func(move: PokemonLearningMove):
			return move.learningType == PokemonLearningMove.Type.LVL_UP and move.learningLevel == level
	).pop_front()
	if newMove != null:
		newLearningMove = newMove.getMove()

## Obtiene el IV más alto
func get_highest_IV() -> StatsEnum.Values:
	var highest_valor = -1
	var highest_IVs: Array[StatsEnum.Values] = []
	for iv in ivs:
		if ivs[iv] > highest_valor:
			highest_IVs.clear()
			highest_IVs.push_back(iv)
			highest_valor = ivs[iv]
		elif ivs[iv] == highest_valor:
			highest_IVs.push_back(iv)
	return highest_IVs[randi() % highest_IVs.size()]

## Obtiene el texto de personalidad basado en IVs
func get_personality_text() -> String:
	var highest_IV = get_highest_IV()
	for f in CONST.Personality_Table[highest_IV]:
		if f[0].has(ivs[highest_IV]):
			return f[1]
	return ""

## Convierte a BattlePokemon para combate
func to_battle_pokemon(ai = null):  # ai: BattleIA, return: BattlePokemon - evitamos referencia circular
	var battle_pokemon = BattlePokemon.new(self, ai)
	battle_pokemon.is_wild = self.is_wild
	battle_pokemon.prepare_battle_moves()
	return battle_pokemon

## Obtiene el nombre para mostrar (apodo o nombre de especie)
func get_display_name() -> String:
	if nickname != "":
		return nickname
	return base.Name

## Helpers de acceso a propiedades base
func get_type1() -> TypeData:
	return base.type_a as TypeData

func get_type2() -> TypeData:
	return base.type_b as TypeData

func get_types() -> Array[TypeData]:
	return [base.type_a as TypeData, base.type_b as TypeData]

func get_battle_front_sprite() -> AtlasTexture:
	return base.battle_front_shiny_sprite if shiny else base.battle_front_sprite

func get_battle_back_sprite() -> AtlasTexture:
	return base.battle_back_shiny_sprite if shiny else base.battle_back_sprite

func get_icon_sprite() -> AtlasTexture:
	return base.icon_sprite

## Helpers de estado
func has_full_health() -> bool:
	return hp_actual == get_final_stat(StatsEnum.Values.HP)

func hasItemEquipped(item_id: int) -> bool:
	return held_item_id == item_id

func _to_string() -> String:
	return get_display_name()
