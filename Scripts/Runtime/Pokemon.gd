## Clase Pokemon (runtime)
## Representa un Pokémon "vivo" durante el juego (combate, party, PC, etc.)
## Se crea a partir de un PokemonData y contiene propiedades runtime como nivel, IVs, EVs, etc.
## Es un Resource para poder exportarlo, guardarlo como .tres y configurarlo desde el inspector
extends Resource
class_name Pokemon

const _LevelUpStatResult := preload("res://Scripts/Runtime/LevelUpStatResult.gd")
const _MoveLearnResult := preload("res://Scripts/Runtime/MoveLearnResult.gd")

signal newMoveLearned

const EvolutionCheckResult := preload("res://Scripts/Runtime/EvolutionCheckResult.gd")
const PokemonEvolutionRowScr := preload("res://Scripts/Resources/Classes/PokemonEvolutionRow.gd")

@export_group("Datos Base")
## ID del Pokémon (usa PokemonsEnum para ver la lista)
## Se cargará automáticamente el PokemonData desde DatabaseService
@export var pokemon_id: PokemonsEnum.Values = PokemonsEnum.Values.BULBASAUR

@export_group("Información Básica")
@export var nickname: String = ""
@export_range(1, 100) var level: int = 5
@export_enum("Sin indicar", "Macho", "Hembra", "Sin Género") var gender: int = 0
@export var is_wild: bool = false
@export var shiny: bool = false
## -1 = usar `shadow_size` del PokemonData; 0-3 = forzar tamaño (debug / TestBattle).
var battle_shadow_size_override: int = -1

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
## Cola pendiente para resolver por UI cuando no hay hueco (4 movimientos).
## Cada entrada: { "move": Move, "level": int, "learn_type": int }
var pending_move_learnings: Array[Dictionary] = []
## Si hay evolución por nivel pendiente: `target_species_id`, `method`, `required_level` (clave acorde a PBI).
var pending_evolution: Dictionary = {}
## Nivel en el que se canceló la evolución por nivel; evita re-dispararla inmediatamente en el mismo nivel.
var cancelled_level_evolution_level: int = -1
var trainer_id: int = 1234
var original_trainer: String = "Red"
var capture_date: String = ""
var capture_route: String = ""
var capture_level: int = 5
var captured_ball_id: String = PokeballItemEffect.DEFAULT_BALL_SPRITE_ID
var personality: String = ""

# Experiencia
var experienceGroup: PokemonExperienceGroup:
	get:
		if base == null:
			return PokemonExperienceGroup.new()
		return PokemonExperienceGroup.new(base.growth_rate_id)

var actualLevelExpBase: int:
	get:
		return experienceGroup.get_total_exp_for_level(level)

var nextLevelExpBase: int:
	get:
		if level < 100:
			return experienceGroup.get_total_exp_for_level(level + 1)
		else:
			return totalExp


## Segmento de barra EXP como si el Pokémon estuviera en `bar_level` con `absolute_total_exp` de total acumulado.
func get_exp_bar_segment_values_for_level(absolute_total_exp: int, bar_level: int) -> Vector2i:
	# Nv.100: sin siguiente nivel — barra vacía (HGSS); la EXP extra no la llena.
	if bar_level >= 100:
		return Vector2i(0, 1)
	var grp := PokemonExperienceGroup.new(base.growth_rate_id)
	var floor_exp: int = grp.get_total_exp_for_level(bar_level)
	var ceil_exp: int = grp.get_total_exp_for_level(bar_level + 1)
	var span: int = maxi(ceil_exp - floor_exp, 1)
	var seg: int = clampi(absolute_total_exp - floor_exp, 0, span)
	return Vector2i(seg, span)


## Progreso y tramo de la barra EXP del nivel actual (`self.level`); si `absolute_total_exp` es negativo, usa `totalExp`.
func get_exp_bar_segment_values(absolute_total_exp: int = -1) -> Vector2i:
	var abs_total: int = totalExp if absolute_total_exp < 0 else absolute_total_exp
	return get_exp_bar_segment_values_for_level(abs_total, level)


# Battle state
var inBattle: bool = false
var inBattleParty: bool = false
## Estado mayor fuera de combate (veneno, sueño, etc.). `CONST.STATUS.OK` = sin estado problemático.
var major_status: int = CONST.STATUS.OK
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
		# Autoloads NO cuentan para Engine.has_singleton(); en ejecución usar DatabaseService.
		if not Engine.is_editor_hint():
			base = DatabaseService.get_pokemon(int(pokemon_data))
		else:
			# En editor (herramientas / inspector): cargar desde disco sin depender del autoload.
			var pid: int = int(pokemon_data)
			var pokemon_path := "res://Resources/Data/Pokemon/%03d.tres" % pid
			if ResourceLoader.exists(pokemon_path):
				base = load(pokemon_path) as PokemonData
			if base == null:
				var dir := DirAccess.open("res://Resources/Data/Pokemon")
				if dir:
					dir.list_dir_begin()
					var file_name := dir.get_next()
					while file_name != "":
						if not dir.current_is_dir() and file_name.ends_with(".tres"):
							var file_base := file_name.get_basename()
							var parts := file_base.split(" - ", false, 1)
							if parts.size() > 0:
								var id_str := parts[0].strip_edges()
								if id_str.is_valid_int() and int(id_str) == pid:
									var full_path := "res://Resources/Data/Pokemon/" + file_name
									base = load(full_path) as PokemonData
									if base:
										break
						file_name = dir.get_next()
					dir.list_dir_end()
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

	_configure_ability(pokemon_ability)

	# Configurar naturaleza
	if pokemon_nature == null:
		# Mantener valor @export (por defecto SERIOUS)
		pass
	elif pokemon_nature == 0:
		nature_id = NaturesEnum.get_random_nature() as NaturesEnum.Values
	else:
		nature_id = pokemon_nature as NaturesEnum.Values

	if not Engine.is_editor_hint():
		nature = DatabaseService.get_nature(NaturesEnum.get_id(nature_id))

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
	# Si ya está inicializado, no hacer nada
	if base != null:
		return

	var pid: int = int(pokemon_id)

	# Cargar PokemonData desde el enum pokemon_id
	if not Engine.is_editor_hint():
		base = DatabaseService.get_pokemon(pid)

	# Si DatabaseService no funcionó o no está disponible, cargar directamente desde archivo
	if base == null:
		# Intentar primero con formato "007.tres"
		var pokemon_path := "res://Resources/Data/Pokemon/%03d.tres" % pid
		if ResourceLoader.exists(pokemon_path):
			base = load(pokemon_path) as PokemonData

		# Si no existe, buscar archivos con formato "007 - Nombre.tres"
		if base == null:
			var dir = DirAccess.open("res://Resources/Data/Pokemon")
			if dir:
				dir.list_dir_begin()
				var file_name = dir.get_next()
				while file_name != "":
					if not dir.current_is_dir() and file_name.ends_with(".tres"):
						var file_base = file_name.get_basename()
						var parts = file_base.split(" - ", false, 1)
						if parts.size() > 0:
							var id_str = parts[0].strip_edges()
							if id_str.is_valid_int() and int(id_str) == pid:
								var full_path = "res://Resources/Data/Pokemon/" + file_name
								base = load(full_path) as PokemonData
								if base:
									break
					file_name = dir.get_next()
				dir.list_dir_end()

	if base == null:
		push_error("Pokemon._post_init: No se pudo cargar PokemonData para id %d" % pid)
		return

	# Calcular valores automáticos si no están configurados
	if gender == 0:  # "Sin indicar"
		gender = _calculate_gender()

	_configure_ability()

	if not Engine.is_editor_hint():
		nature = DatabaseService.get_nature(NaturesEnum.get_id(nature_id))

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

## Resuelve ability_id (forzado, @export o aleatorio por especie). No asigna AbilityData.
func _resolve_ability_id(forced_ability: Variant = null) -> void:
	if forced_ability != null:
		if int(forced_ability) == 0:
			ability_id = _calculate_ability() as AbilitiesEnum.Values
		else:
			ability_id = int(forced_ability) as AbilitiesEnum.Values
	elif ability_id == AbilitiesEnum.Values.NONE:
		ability_id = _calculate_ability() as AbilitiesEnum.Values


## Único punto que asigna `ability` desde DatabaseService.
func _apply_ability_from_database() -> void:
	if ability_id == AbilitiesEnum.Values.NONE:
		ability = null
		return
	if Engine.is_editor_hint() and base == null:
		return
	ability = DatabaseService.get_ability(int(ability_id))
	if ability == null:
		push_warning(
			"Pokemon: no se encontró AbilityData para id %d (%s)"
			% [int(ability_id), get_display_name() if base != null else "?"]
		)


func _configure_ability(forced_ability: Variant = null) -> void:
	_resolve_ability_id(forced_ability)
	_apply_ability_from_database()


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
	var move_count: int = mini(base.learn_move_id.size(), mini(base.learn_type.size(), base.learn_lvl.size()))
	if move_count < base.learn_move_id.size() and OS.is_debug_build():
		push_warning("Pokemon._load_learnable_moves: arrays de learnset desalineados para %s" % get_display_name())
	for i in range(move_count):
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


func knows_move_id(move_id: int) -> bool:
	for mvar in movements:
		var mv: Move = mvar as Move
		if mv != null and mv.base != null and mv.base.id == move_id:
			return true
	return false


func replace_move_at(index: int, new_move: Move) -> Move:
	if new_move == null or new_move.base == null:
		return null
	if index < 0 or index >= movements.size():
		return null
	var old_move: Move = movements[index] as Move
	movements[index] = new_move
	return old_move


## Devuelve TODOS los movimientos aprendibles exactamente en `at_level` para un tipo de aprendizaje.
func get_learnable_moves_at_level(at_level: int, learn_type: int = PokemonLearningMove.Type.LVL_UP) -> Array[PokemonLearningMove]:
	var result: Array[PokemonLearningMove] = []
	for lm in learningMoves:
		if lm.learningType == learn_type and lm.learningLevel == at_level:
			result.append(lm)
	return result


## Lógica de aprendizaje al llegar a un nivel concreto (sin UI). Si no hay hueco, deja pendiente.
func resolve_level_up_move_learning_for_level(learned_level: int) -> RefCounted:
	var res: RefCounted = _MoveLearnResult.new()
	res.level = learned_level
	var learnables := get_learnable_moves_at_level(learned_level, PokemonLearningMove.Type.LVL_UP)
	for lm in learnables:
		var mv: Move = lm.getMove()
		if mv == null or mv.base == null:
			continue
		res.offered_moves.append(mv)
		if knows_move_id(mv.base.id):
			if OS.is_debug_build():
				print("[MoveLearn] %s ya conoce %s (Lv %d)" % [get_display_name(), mv.get_move_name(), learned_level])
			continue
		if movements.size() < 4:
			movements.append(mv)
			res.learned_moves.append(mv)
			if OS.is_debug_build():
				print("[MoveLearn] %s aprendió %s (Lv %d)" % [get_display_name(), mv.get_move_name(), learned_level])
		else:
			var pending := {
				"move": mv,
				"level": learned_level,
				"learn_type": int(PokemonLearningMove.Type.LVL_UP),
			}
			pending_move_learnings.append(pending)
			res.pending_moves.append(mv)
			res.requires_decision = true
			if OS.is_debug_build():
				print("[MoveLearn] %s pendiente de aprender %s (Lv %d, sin hueco)" % [get_display_name(), mv.get_move_name(), learned_level])
	return res


func pop_next_pending_move_learning() -> Dictionary:
	if pending_move_learnings.is_empty():
		return {}
	return pending_move_learnings.pop_front()

## Fórmula estándar (Gen 3+): base, IV, EV/4, nivel; naturaleza ×1.1/×0.9 en stats no-HP.
func calculate_final_stat(stat: StatsEnum.Values, for_level: int) -> int:
	if base == null:
		return 0
	var base_stat: int = base_stats.get(stat, 0)
	var iv: int = ivs.get(stat, 0)
	var ev: int = evs.get(stat, 0)
	var ev_quarter: int = int(floor(float(ev) / 4.0))
	var inner: int = int(floor(
		(2.0 * float(base_stat) + float(iv) + float(ev_quarter)) * float(for_level) / 100.0
	))

	if stat == StatsEnum.Values.HP:
		return inner + for_level + 10

	var mult: float = 1.0
	if nature != null:
		mult = nature.get_stat_multiplier(stat)
	return int(floor((inner + 5) * mult))


## Delegación habitual usando el nivel actual del Pokémon (o uno indicado).
func get_final_stat(stat: StatsEnum.Values, _level: int = self.level) -> int:
	return calculate_final_stat(stat, _level)


## Tras subir de nivel (campo `level` ya actualizado). Ajusta PS actuales por delta de PS máximos; no toca PP ni estado de combate.
func apply_stats_after_level_up(old_level: int) -> RefCounted:
	var r: RefCounted = _LevelUpStatResult.new()
	r.old_level = old_level
	r.new_level = level
	var main_stats: Array[StatsEnum.Values] = [
		StatsEnum.Values.HP,
		StatsEnum.Values.ATTACK,
		StatsEnum.Values.DEFENSE,
		StatsEnum.Values.SP_ATTACK,
		StatsEnum.Values.SP_DEFENSE,
		StatsEnum.Values.SPEED,
	]
	for s: StatsEnum.Values in main_stats:
		r.stats_before[s] = calculate_final_stat(s, old_level)
		r.stats_after[s] = calculate_final_stat(s, level)

	r.old_max_hp = int(r.stats_before.get(StatsEnum.Values.HP, 0))
	r.new_max_hp = int(r.stats_after.get(StatsEnum.Values.HP, 0))
	r.hp_actual_before = hp_actual
	var delta_hp: int = r.new_max_hp - r.old_max_hp
	hp_actual = clampi(hp_actual + delta_hp, 0, r.new_max_hp)
	r.hp_actual_after = hp_actual

	if OS.is_debug_build():
		print("[LevelUp Stats] %s | Lv %d→%d | maxHP %d→%d | PS %d→%d (ΔmaxHP %+d)" % [
			get_display_name(), old_level, level,
			r.old_max_hp, r.new_max_hp, r.hp_actual_before, r.hp_actual_after, delta_hp,
		])
		print("  Atk %d→%d | Def %d→%d | SpA %d→%d | SpD %d→%d | Spe %d→%d" % [
			r.stats_before.get(StatsEnum.Values.ATTACK, 0), r.stats_after.get(StatsEnum.Values.ATTACK, 0),
			r.stats_before.get(StatsEnum.Values.DEFENSE, 0), r.stats_after.get(StatsEnum.Values.DEFENSE, 0),
			r.stats_before.get(StatsEnum.Values.SP_ATTACK, 0), r.stats_after.get(StatsEnum.Values.SP_ATTACK, 0),
			r.stats_before.get(StatsEnum.Values.SP_DEFENSE, 0), r.stats_after.get(StatsEnum.Values.SP_DEFENSE, 0),
			r.stats_before.get(StatsEnum.Values.SPEED, 0), r.stats_after.get(StatsEnum.Values.SPEED, 0),
		])

	return r


## Stats entre dos niveles consecutivos, sin mutar `level` (p. ej. diálogos de subida uno a uno con varios niveles de golpe).
func level_up_stat_changes_between(from_level: int, to_level: int) -> RefCounted:
	var r: RefCounted = _LevelUpStatResult.new()
	if to_level != from_level + 1:
		push_warning("Pokemon.level_up_stat_changes_between: se espera to_level == from_level + 1 (got %d, %d)" % [from_level, to_level])
	r.old_level = from_level
	r.new_level = to_level
	var main_stats: Array[StatsEnum.Values] = [
		StatsEnum.Values.HP,
		StatsEnum.Values.ATTACK,
		StatsEnum.Values.DEFENSE,
		StatsEnum.Values.SP_ATTACK,
		StatsEnum.Values.SP_DEFENSE,
		StatsEnum.Values.SPEED,
	]
	for s: StatsEnum.Values in main_stats:
		r.stats_before[s] = calculate_final_stat(s, from_level)
		r.stats_after[s] = calculate_final_stat(s, to_level)
	r.old_max_hp = int(r.stats_before.get(StatsEnum.Values.HP, 0))
	r.new_max_hp = int(r.stats_after.get(StatsEnum.Values.HP, 0))
	r.hp_actual_before = hp_actual
	r.hp_actual_after = hp_actual
	return r


func get_base_stat(stat: StatsEnum.Values) -> int:
	return base_stats.get(stat, 0)

func get_iv(stat: StatsEnum.Values) -> int:
	return ivs.get(stat, 0)

func get_ev(stat: StatsEnum.Values) -> int:
	return evs.get(stat, 0)

## Sube un nivel y recalcula stats (misma regla que subida por EXP).
func levelUP() -> void:
	if level >= 100:
		return
	var old_level: int = level
	level += 1
	apply_stats_after_level_up(old_level)
	check_level_evolution()

## Verifica/ejecuta aprendizaje al nivel actual y devuelve la lista de movimientos detectados en ese nivel.
func checkNewLevelMoveLearned() -> Array[Move]:
	newLearningMove = null
	var learn_result: RefCounted = resolve_level_up_move_learning_for_level(level)
	if learn_result == null:
		return []
	var learned_now: Array = learn_result.learned_moves
	if not learned_now.is_empty():
		newLearningMove = learned_now[0]
	var offered_now: Array[Move] = []
	for mv_var in learn_result.offered_moves:
		var mv: Move = mv_var as Move
		if mv != null:
			offered_now.append(mv)
	return offered_now

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
	if base == null:
		return "Pokémon (%d)" % int(pokemon_id)
	return base.Name


func _coerce_evolution_int(value: Variant) -> int:
	if value == null:
		return 0
	if typeof(value) == TYPE_INT:
		return int(value)
	var s := str(value).strip_edges()
	if s.is_valid_int():
		return int(s)
	return 0


func _parse_level_up_evolution_entries(data: PokemonData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if data == null:
		return out
	var logical_i := 0
	for row_any in data.evolutions:
		var row := row_any as PokemonEvolutionRowScr
		if row == null:
			continue
		if row.method != CONST.EVOL_LVL_UP:
			continue
		if row.min_level <= 0:
			continue
		if row.target_species_id <= 0:
			push_warning(
				"Pokemon._parse_level_up_evolution_entries: target_species_id inválido (%s)."
				% [data.Name if data else "?"]
			)
			continue
		out.append({
			"index": logical_i,
			"method": CONST.EVOL_LVL_UP,
			"required_level": row.min_level,
			"target_id": row.target_species_id,
		})
		logical_i += 1
	return out


## Evalúa evolución por nivel (LEVEL_UP) tras subida de nivel. No ejecuta cambio de especie.
func check_level_evolution() -> EvolutionCheckResult:
	var res: EvolutionCheckResult = EvolutionCheckResult.new()
	pending_evolution.clear()
	if base == null:
		return res
	if cancelled_level_evolution_level >= 0 and cancelled_level_evolution_level != level:
		cancelled_level_evolution_level = -1
	if cancelled_level_evolution_level == level:
		return res

	var candidates: Array[Dictionary] = []
	var entries := _parse_level_up_evolution_entries(base)
	for e in entries:
		if int(e.get("method", -1)) != CONST.EVOL_LVL_UP:
			continue
		var req: int = int(e.get("required_level", 0))
		var tid: int = int(e.get("target_id", 0))
		if level < req:
			continue
		if DatabaseService.get_pokemon(tid) == null:
			push_warning(
				"Pokemon.check_level_evolution: objetivo species_id=%d no existe en DatabaseService; entrada ignorada." % tid
			)
			continue
		candidates.append(e)

	if candidates.is_empty():
		return res

	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var la: int = int(a.get("required_level", 999))
		var lb: int = int(b.get("required_level", 999))
		if la != lb:
			return la < lb
		return int(a.get("index", 0)) < int(b.get("index", 0))
	)

	var pick: Dictionary = candidates[0]
	res.can_evolve = true
	res.target_species_id = int(pick.get("target_id", 0))
	res.method = CONST.EVOL_LVL_UP
	res.required_level = int(pick.get("required_level", 0))

	pending_evolution = {
		"target_species_id": res.target_species_id,
		"method": res.method,
		"required_level": res.required_level,
	}
	return res


## Aplica cambio de especie, recalcula stats base y ajusta PS según delta de máximo (Gen 3+ habitual).
func apply_species_evolution(target_species_id: int) -> bool:
	var new_base: PokemonData = DatabaseService.get_pokemon(target_species_id)
	if new_base == null:
		push_warning("Pokemon.apply_species_evolution: species_id=%d no existe; no se modifica el Pokémon." % target_species_id)
		return false

	var old_max_hp: int = get_final_stat(StatsEnum.Values.HP)

	pokemon_id = target_species_id as PokemonsEnum.Values
	base = new_base
	_refresh_base_stats_from_species()
	_load_learnable_moves()

	_configure_ability()

	var new_max_hp: int = get_final_stat(StatsEnum.Values.HP)
	hp_actual = clampi(hp_actual + (new_max_hp - old_max_hp), 0, new_max_hp)

	pending_evolution.clear()
	cancelled_level_evolution_level = -1
	_update_resource_name()
	return true


func mark_level_evolution_cancelled() -> void:
	cancelled_level_evolution_level = level
	pending_evolution.clear()


func _refresh_base_stats_from_species() -> void:
	if base == null:
		return
	base_stats = {
		StatsEnum.Values.HP: base.hp_base,
		StatsEnum.Values.ATTACK: base.attack_base,
		StatsEnum.Values.DEFENSE: base.defense_base,
		StatsEnum.Values.SP_ATTACK: base.special_attack_base,
		StatsEnum.Values.SP_DEFENSE: base.special_defense_base,
		StatsEnum.Values.SPEED: base.speed_base,
		StatsEnum.Values.ACCURACY: 100,
		StatsEnum.Values.EVASION: 100,
	}

## Helpers de acceso a propiedades base
func get_type1() -> TypeData:
	# Usar type_a_id para cargar el TypeData solo cuando sea necesario
	if base.type_a_id > 0:
		if not Engine.is_editor_hint():
			return DatabaseService.get_type(base.type_a_id) as TypeData
	# Compatibilidad: si type_a_id es 0 pero existe type_a (Resource), usarlo
	if base.type_a != null:
		return base.type_a as TypeData
	return null

func get_type2() -> TypeData:
	# Usar type_b_id para cargar el TypeData solo cuando sea necesario
	if base.type_b_id > 0:
		if not Engine.is_editor_hint():
			return DatabaseService.get_type(base.type_b_id) as TypeData
	# Compatibilidad: si type_b_id es 0 pero existe type_b (Resource), usarlo
	if base.type_b != null:
		return base.type_b as TypeData
	return null

func get_types() -> Array[TypeData]:
	var t1 = get_type1()
	var t2 = get_type2()
	var types: Array[TypeData] = []
	if t1:
		types.append(t1)
	if t2 and t2 != t1:
		types.append(t2)
	return types

func get_battle_front_sprite() -> AtlasTexture:
	return base.battle_front_shiny_sprite if shiny else base.battle_front_sprite

func get_battle_back_sprite() -> AtlasTexture:
	return base.battle_back_shiny_sprite if shiny else base.battle_back_sprite

func get_icon_sprite() -> AtlasTexture:
	return base.icon_sprite

func get_overworld_sprite() -> Texture2D:
	if shiny and base.overworld_shiny_spritesheet:
		return base.overworld_shiny_spritesheet
	if base.overworld_spritesheet:
		return base.overworld_spritesheet
	# Fallback al sprite trasero si no existe overworld dedicado
	return get_battle_back_sprite()

## Helpers de estado
func has_full_health() -> bool:
	return hp_actual == get_final_stat(StatsEnum.Values.HP)

func hasItemEquipped(item_id: int) -> bool:
	return held_item_id == item_id


const SERIALIZE_VERSION: int = 1


## Snapshot plano para guardado / Party (sin rutas de recursos).
func to_serializable_state() -> Dictionary:
	var move_ids: Array[int] = []
	for m in custom_move_ids:
		move_ids.append(int(m))
	var pp_snapshot: Array[int] = []
	for mvar in movements:
		var mv: Move = mvar as Move
		if mv != null:
			pp_snapshot.append(mv.pp_actual)
		else:
			pp_snapshot.append(0)
	return {
		"v": SERIALIZE_VERSION,
		"pokemon_id": int(pokemon_id),
		"pending_evolution": pending_evolution.duplicate(),
		"nickname": nickname,
		"level": level,
		"gender": gender,
		"is_wild": is_wild,
		"shiny": shiny,
		"hp_IVs": hp_IVs,
		"attack_IVs": attack_IVs,
		"defense_IVs": defense_IVs,
		"spAttack_IVs": spAttack_IVs,
		"spDefense_IVs": spDefense_IVs,
		"speed_IVs": speed_IVs,
		"hp_EVs": hp_EVs,
		"attack_EVs": attack_EVs,
		"defense_EVs": defense_EVs,
		"spAttack_EVs": spAttack_EVs,
		"spDefense_EVs": spDefense_EVs,
		"speed_EVs": speed_EVs,
		"nature_id": int(nature_id),
		"ability_id": int(ability_id),
		"ability_slot": ability_slot,
		"held_item_id": held_item_id,
		"custom_move_ids": move_ids,
		"hp_actual": hp_actual,
		"move_pp_actual": pp_snapshot,
		"major_status": major_status,
		"totalExp": totalExp,
		"trainer_id": trainer_id,
		"original_trainer": original_trainer,
		"capture_date": capture_date,
		"capture_route": capture_route,
		"capture_level": capture_level,
		"captured_ball_id": captured_ball_id,
		"personality": personality,
	}


func _to_string() -> String:
	return get_display_name()
