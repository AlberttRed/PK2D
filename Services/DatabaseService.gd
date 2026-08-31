extends Node

## DatabaseService - Autoload para centralizar acceso a Resources del juego
## Carga e indexa Pokémon, Movimientos, Tipos, Habilidades, Naturalezas y Climas.
## Accesible globalmente como autoload: DatabaseService

const POKEMON_DIR := "res://Resources/Data/Pokemon"
const MOVES_DIR := "res://Resources/Data/Moves"
const TYPES_DIR := "res://Resources/Data/Types"
const ABILITIES_DIR := "res://Resources/Data/Abilities"
const WEATHERS_DIR := "res://Resources/Data/Weather" # opcional, si existe
const TRAINER_CLASSES_DIR := "res://Resources/Trainer Classes"
const ITEMS_DIR := "res://Resources/Data/Items"
const _POKEMON_INDEX := preload("res://Services/PokemonResourceIndex.gd")
const _MOVE_INDEX := preload("res://Services/MoveResourceIndex.gd")
const _ITEM_INDEX := preload("res://Services/ItemResourceIndex.gd")
const _ABILITY_INDEX := preload("res://Services/AbilityResourceIndex.gd")
const _WEATHER_INDEX := preload("res://Services/WeatherResourceIndex.gd")

var _pokemon_by_id: Dictionary = {}
var _pokemon_by_name: Dictionary = {}

var _moves_by_id: Dictionary = {}
var _moves_by_name: Dictionary = {}

var _types_by_id: Dictionary = {}
var _types_by_name: Dictionary = {}

var _abilities_by_id: Dictionary = {}
var _abilities_by_name: Dictionary = {}

var _natures_by_id: Dictionary = {}
var _natures_by_name: Dictionary = {}

var _weathers_by_id: Dictionary = {}
var _weathers_by_name: Dictionary = {}

var _trainer_classes_by_id: Dictionary = {}
var _trainer_classes_by_name: Dictionary = {}

var _items_by_id: Dictionary = {}
var _items_by_name: Dictionary = {}

func _ready() -> void:
	_load_all()
	_print_summary()

func _load_all() -> void:
	_pokemon_by_id.clear(); _pokemon_by_name.clear()
	_moves_by_id.clear(); _moves_by_name.clear()
	_types_by_id.clear(); _types_by_name.clear()
	_abilities_by_id.clear(); _abilities_by_name.clear()
	_natures_by_id.clear(); _natures_by_name.clear()
	_weathers_by_id.clear(); _weathers_by_name.clear()
	_trainer_classes_by_id.clear(); _trainer_classes_by_name.clear()
	_items_by_id.clear(); _items_by_name.clear()

	load_resources_from_dir(POKEMON_DIR, func(res):
		if res == null: return
		if not (res is PokemonData): return
		_pokemon_by_id[res.id] = res
		if typeof(res.internal_name) == TYPE_STRING and res.internal_name != "":
			_pokemon_by_name[res.internal_name.to_lower()] = res
	)

	_load_moves()
	_load_types()
	_load_abilities()
	_load_natures()
	_load_weathers()
	_load_trainer_classes()
	_load_items()

	if _pokemon_by_id.is_empty():
		push_error(
			"DatabaseService: no hay especies Pokémon cargadas. En exports suele deberse a no incluir `res://Resources/Data/Pokemon/` en el paquete; en Editor → Exportar → Recursos use «Exportar todos los recursos del proyecto» o filtros que incluyan esa carpeta."
		)

	if _moves_by_id.is_empty():
		push_error(
			"DatabaseService: no hay movimientos cargados. Comprueba que `res://Resources/Data/Moves/` esté en el paquete de exportación."
		)

	if _items_by_id.is_empty():
		push_error(
			"DatabaseService: no hay items cargados. Comprueba que `res://Resources/Data/Items/` esté en el paquete de exportación."
		)

	if _weathers_by_id.is_empty():
		push_error(
			"DatabaseService: no hay climas cargados. Comprueba que `res://Resources/Data/Weather/` contenga .tres (p. ej. RAIN.tres) y esté en el paquete de exportación."
		)

func _print_summary() -> void:
	pass

func _load_moves() -> void:
	load_resources_from_dir(MOVES_DIR, func(res):
		if res == null: return
		if not (res is MoveData): return
		_moves_by_id[res.id] = res
		if typeof(res.internal_name) == TYPE_STRING and res.internal_name != "":
			_moves_by_name[res.internal_name.to_lower()] = res
	)

func _load_types() -> void:
	load_resources_from_dir(TYPES_DIR, func(res):
		if res == null: return
		if not (res is TypeData): return
		_types_by_id[res.id] = res
		if typeof(res.internal_name) == TYPE_STRING and res.internal_name != "":
			_types_by_name[res.internal_name.to_lower()] = res
	)

func _load_abilities() -> void:
	var loaded := [0]
	load_resources_from_dir(ABILITIES_DIR, func(res):
		if res == null:
			return
		if not (res is AbilityData):
			return
		_abilities_by_id[int(res.id)] = res
		if typeof(res.internal_name) == TYPE_STRING and res.internal_name != "":
			_abilities_by_name[res.internal_name.to_lower()] = res
		loaded[0] += 1
	)
	if loaded[0] == 0:
		push_error("DatabaseService: no se cargaron habilidades desde %s" % ABILITIES_DIR)

func _load_natures() -> void:
	for i in NaturesEnum.Values.size():
		var nat_id := NaturesEnum.get_id(i)
		if nat_id == "NONE":
			continue
		var nat := NatureData.new()
		nat.id = nat_id.to_lower()
		nat.display_name = nat_id.capitalize()
		_natures_by_id[nat.id] = nat
		_natures_by_name[nat.id] = nat

func _load_weathers() -> void:
	var dir := DirAccess.open(WEATHERS_DIR)
	if dir == null:
		return
	load_resources_from_dir(WEATHERS_DIR, func(res):
		if res == null: return
		if not (res is WeatherData): return
		_weathers_by_id[res.id] = res
		if typeof(res.internal_name) == TYPE_STRING and res.internal_name != "":
			_weathers_by_name[res.internal_name.to_lower()] = res
	)

func _load_trainer_classes() -> void:
	var dir := DirAccess.open(TRAINER_CLASSES_DIR)
	if dir == null:
		# Si no existe el directorio, no hay problema (se crearán temporales)
		return

	load_resources_from_dir(TRAINER_CLASSES_DIR, func(res):
		if res == null: return
		if not (res is TrainerClassData): return
		_trainer_classes_by_id[res.id] = res
		if typeof(res.internal_name) == TYPE_STRING and res.internal_name != "":
			_trainer_classes_by_name[res.internal_name.to_lower()] = res
	)

func _load_items() -> void:
	var dir := DirAccess.open(ITEMS_DIR)
	if dir == null:
		# Si no existe el directorio, no hay problema (se crearán más adelante)
		return

	var duplicate_ids: Array[int] = []
	var duplicate_names: Array[String] = []

	load_resources_from_dir(ITEMS_DIR, func(res):
		if res == null: return
		if not (res is ItemData): return

		# Validar duplicados por ID (AC-06)
		if _items_by_id.has(res.id):
			var existing := _items_by_id[res.id] as ItemData
			push_warning("DatabaseService: ItemData duplicado por ID %d. Existente: %s, Nuevo: %s" % [
				res.id,
				existing.internal_name if existing else "null",
				res.internal_name
			])
			duplicate_ids.append(res.id)
		else:
			_items_by_id[res.id] = res

		# Validar duplicados por nombre interno (AC-06)
		if typeof(res.internal_name) == TYPE_STRING and res.internal_name != "":
			var name_key: String = res.internal_name.to_lower()
			if _items_by_name.has(name_key):
				var existing := _items_by_name[name_key] as ItemData
				push_warning("DatabaseService: ItemData duplicado por internal_name '%s'. Existente ID: %d, Nuevo ID: %d" % [
					res.internal_name,
					existing.id if existing else 0,
					res.id
				])
				duplicate_names.append(res.internal_name)
			else:
				_items_by_name[name_key] = res
	)

	# Reportar resumen de duplicados si los hay
	if not duplicate_ids.is_empty() or not duplicate_names.is_empty():
		push_warning("DatabaseService: Se encontraron %d IDs duplicados y %d nombres duplicados en Items" % [
			duplicate_ids.size(),
			duplicate_names.size()
		])

## Carga recursos usando ResourceLoader (funciona en debug y exports)
## Soporta tanto formato numérico simple ("001.tres") como con nombre ("001 - Bulbasaur.tres")
func _load_resources_by_pattern(dir_path: String, on_loaded: Callable) -> void:
	# Para Pokémon: usar índice estático id -> ruta para no depender de DirAccess en export.
	if dir_path == POKEMON_DIR:
		var ids: Array[int] = []
		for id_any in _POKEMON_INDEX.BY_ID.keys():
			ids.append(int(id_any))
		ids.sort()
		for species_id in ids:
			var path: String = _POKEMON_INDEX.BY_ID.get(species_id, "")
			if path.is_empty():
				continue
			if ResourceLoader.exists(path):
				var res := load(path)
				if res != null:
					on_loaded.call(res)
		return

	# Para Moves: índice estático id -> ruta (mismo motivo que Pokémon en export).
	if dir_path == MOVES_DIR:
		var move_ids: Array[int] = []
		for id_any in _MOVE_INDEX.BY_ID.keys():
			move_ids.append(int(id_any))
		move_ids.sort()
		for move_id in move_ids:
			var path_move: String = _MOVE_INDEX.BY_ID.get(move_id, "")
			if path_move.is_empty():
				continue
			if ResourceLoader.exists(path_move):
				var res_move := load(path_move)
				if res_move != null:
					on_loaded.call(res_move)
		return

	# Para Types: intentar cargar del 01 al 18 (rango conocido)
	if dir_path == TYPES_DIR:
		for i in range(1, 19):
			var path := "%s/%02d.tres" % [dir_path, i]
			if ResourceLoader.exists(path):
				var res := load(path)
				if res != null:
					on_loaded.call(res)
		return

	# Para Abilities: índice estático id -> ruta (evita depender de DirAccess en export).
	if dir_path == ABILITIES_DIR:
		var ability_ids: Array[int] = []
		for id_any in _ABILITY_INDEX.BY_ID.keys():
			ability_ids.append(int(id_any))
		ability_ids.sort()
		for ability_id in ability_ids:
			var path_ability: String = _ABILITY_INDEX.BY_ID.get(ability_id, "")
			if path_ability.is_empty():
				continue
			if ResourceLoader.exists(path_ability):
				var res_ability := load(path_ability)
				if res_ability != null:
					on_loaded.call(res_ability)
		return

	# Para Weather: índice estático id -> ruta (evita depender de DirAccess en export).
	if dir_path == WEATHERS_DIR:
		var weather_ids: Array[int] = []
		for id_any in _WEATHER_INDEX.BY_ID.keys():
			weather_ids.append(int(id_any))
		weather_ids.sort()
		for weather_id in weather_ids:
			var path_weather: String = _WEATHER_INDEX.BY_ID.get(weather_id, "")
			if path_weather.is_empty():
				continue
			if ResourceLoader.exists(path_weather):
				var res_weather := load(path_weather)
				if res_weather != null:
					on_loaded.call(res_weather)
		return

	# Para Items: índice estático id -> ruta (evita depender de DirAccess en export).
	if dir_path == ITEMS_DIR:
		var item_ids: Array[int] = []
		for id_any in _ITEM_INDEX.BY_ID.keys():
			item_ids.append(int(id_any))
		item_ids.sort()
		for item_id in item_ids:
			var path_item: String = _ITEM_INDEX.BY_ID.get(item_id, "")
			if path_item.is_empty():
				continue
			if ResourceLoader.exists(path_item):
				var res_item := load(path_item)
				if res_item != null:
					on_loaded.call(res_item)
		return

	# Para Trainer Classes: no hay un patrón numérico claro
	# Intentar usar DirAccess como fallback solo si está disponible
	var dir := DirAccess.open(dir_path)
	if dir != null:
		dir.list_dir_begin()
		while true:
			var file := dir.get_next()
			if file == "":
				break
			if dir.current_is_dir():
				continue
			if not file.ends_with(".tres"):
				continue
			var path := dir_path + "/" + file
			if ResourceLoader.exists(path):
				var res := load(path)
				if res != null:
					on_loaded.call(res)
		dir.list_dir_end()
	else:
		push_warning("DatabaseService: No se pudo cargar recursos de %s (sin patrón numérico y DirAccess no disponible)" % dir_path)

## Utilidad genérica para escanear un directorio y cargar .tres
## Usa ResourceLoader que funciona tanto en debug como en builds exportados
func load_resources_from_dir(dir_path: String, on_loaded: Callable) -> void:
	_load_resources_by_pattern(dir_path, on_loaded)

# === API DE ACCESO ===

func get_pokemon(name_or_id) -> Resource:
	var t := typeof(name_or_id)
	if t == TYPE_INT or t == TYPE_FLOAT:
		return _get_pokemon_by_species_id(int(name_or_id))
	var key := str(name_or_id).to_lower()
	if key.is_valid_int():
		return _get_pokemon_by_species_id(int(key))
	return _pokemon_by_name.get(key, null)


func _get_pokemon_by_species_id(species_id: int) -> Resource:
	if _pokemon_by_id.has(species_id):
		return _pokemon_by_id[species_id]
	var lazy := _lazy_load_pokemon_by_species_id(species_id)
	if lazy != null:
		_pokemon_by_id[species_id] = lazy
		if typeof(lazy.internal_name) == TYPE_STRING and lazy.internal_name != "":
			_pokemon_by_name[lazy.internal_name.to_lower()] = lazy
		return lazy
	return null


func _lazy_load_pokemon_by_species_id(species_id: int) -> PokemonData:
	if species_id < 0 or species_id > 151:
		return null
	var path: String = _POKEMON_INDEX.BY_ID.get(species_id, "")
	if path.is_empty():
		return null
	if ResourceLoader.exists(path):
		return load(path) as PokemonData
	return null


## IDs de especies cargadas, en orden ascendente estable (Pokédex).
func get_all_pokemon_species_ids() -> Array[int]:
	var ids: Array[int] = []
	for id_any in _pokemon_by_id.keys():
		var species_id := int(id_any)
		if species_id <= 0:
			continue
		ids.append(species_id)
	ids.sort()
	return ids


## Dataset de especies ordenado por id.
func get_all_pokemon_sorted() -> Array[PokemonData]:
	var out: Array[PokemonData] = []
	var ids := get_all_pokemon_species_ids()
	for species_id in ids:
		var data := _pokemon_by_id.get(species_id, null) as PokemonData
		if data != null:
			out.append(data)
	return out

func get_move(name_or_id) -> MoveData:
	var t := typeof(name_or_id)
	if t == TYPE_INT or t == TYPE_FLOAT:
		return _get_move_by_id(int(name_or_id))
	var key := str(name_or_id).to_lower()
	if key.is_valid_int():
		return _get_move_by_id(int(key))
	return _moves_by_name.get(key, null)


func _get_move_by_id(move_id: int) -> MoveData:
	if _moves_by_id.has(move_id):
		return _moves_by_id[move_id]
	var lazy_move := _lazy_load_move_by_id(move_id)
	if lazy_move != null:
		_moves_by_id[move_id] = lazy_move
		if typeof(lazy_move.internal_name) == TYPE_STRING and lazy_move.internal_name != "":
			_moves_by_name[lazy_move.internal_name.to_lower()] = lazy_move
		return lazy_move
	return null


func _lazy_load_move_by_id(move_id: int) -> MoveData:
	var path_move: String = _MOVE_INDEX.BY_ID.get(move_id, "")
	if path_move.is_empty():
		return null
	if ResourceLoader.exists(path_move):
		return load(path_move) as MoveData
	return null

func get_type(name_or_id) -> Resource:
	if typeof(name_or_id) == TYPE_INT:
		return _types_by_id.get(name_or_id, null)
	var key := str(name_or_id).to_lower()
	if key.is_valid_int():
		return _types_by_id.get(int(key), null)
	return _types_by_name.get(key, null)


## Dataset de tipos ordenado por id.
func get_all_types_sorted() -> Array[TypeData]:
	var out: Array[TypeData] = []
	var ids: Array[int] = []
	for id_any in _types_by_id.keys():
		var type_id := int(id_any)
		if type_id <= 0:
			continue
		ids.append(type_id)
	ids.sort()
	for type_id in ids:
		var data := _types_by_id.get(type_id, null) as TypeData
		if data != null:
			out.append(data)
	return out

func get_ability(name_or_id) -> Resource:
	if name_or_id == null:
		return null
	var t := typeof(name_or_id)
	if t == TYPE_INT or t == TYPE_FLOAT:
		return _get_ability_by_id(int(name_or_id))
	var key := str(name_or_id).to_lower()
	if key.is_valid_int():
		return _get_ability_by_id(int(key))
	return _abilities_by_name.get(key, null)


func _get_ability_by_id(ability_id: int) -> AbilityData:
	if _abilities_by_id.has(ability_id):
		return _abilities_by_id[ability_id]
	var lazy_ability := _lazy_load_ability_by_id(ability_id)
	if lazy_ability != null:
		_abilities_by_id[ability_id] = lazy_ability
		if typeof(lazy_ability.internal_name) == TYPE_STRING and lazy_ability.internal_name != "":
			_abilities_by_name[lazy_ability.internal_name.to_lower()] = lazy_ability
		return lazy_ability
	return null


func _lazy_load_ability_by_id(ability_id: int) -> AbilityData:
	var path_ability: String = _ABILITY_INDEX.BY_ID.get(ability_id, "")
	if path_ability.is_empty():
		return null
	if ResourceLoader.exists(path_ability):
		return load(path_ability) as AbilityData
	return null

func get_nature(name_or_id) -> Resource:
	var key := str(name_or_id).to_lower()
	return _natures_by_id.get(key, _natures_by_name.get(key, null))

func get_weather(name_or_id) -> WeatherData:
	if typeof(name_or_id) == TYPE_INT:
		return _get_weather_by_id(int(name_or_id))
	var key := str(name_or_id).to_lower()
	if key.is_valid_int():
		return _get_weather_by_id(int(key))
	return _weathers_by_name.get(key, null)


func _get_weather_by_id(weather_id: int) -> WeatherData:
	if _weathers_by_id.has(weather_id):
		return _weathers_by_id[weather_id]
	var lazy_weather := _lazy_load_weather_by_id(weather_id)
	if lazy_weather != null:
		_weathers_by_id[weather_id] = lazy_weather
		if typeof(lazy_weather.internal_name) == TYPE_STRING and lazy_weather.internal_name != "":
			_weathers_by_name[lazy_weather.internal_name.to_lower()] = lazy_weather
		return lazy_weather
	return null


func _lazy_load_weather_by_id(weather_id: int) -> WeatherData:
	var path_weather: String = _WEATHER_INDEX.BY_ID.get(weather_id, "")
	if path_weather.is_empty():
		return null
	if ResourceLoader.exists(path_weather):
		return load(path_weather) as WeatherData
	return null

func get_trainer_class(name_or_id) -> TrainerClassData:
	if typeof(name_or_id) == TYPE_INT:
		return _trainer_classes_by_id.get(name_or_id, null)
	var key := str(name_or_id).to_lower()
	if key.is_valid_int():
		return _trainer_classes_by_id.get(int(key), null)
	return _trainer_classes_by_name.get(key, null)

func get_item(name_or_id) -> ItemData:
	var result: ItemData = null

	var t := typeof(name_or_id)
	if t == TYPE_INT or t == TYPE_FLOAT:
		result = _get_item_by_id(int(name_or_id))
	else:
		var key := str(name_or_id).to_lower()
		if key.is_valid_int():
			result = _get_item_by_id(int(key))
		else:
			result = _items_by_name.get(key, null)

	# Comportamiento ante no encontrado (AC-04)
	if result == null:
		push_warning("DatabaseService: Item no encontrado: %s (tipo: %s)" % [str(name_or_id), typeof(name_or_id)])

	return result


func _get_item_by_id(item_id: int) -> ItemData:
	if _items_by_id.has(item_id):
		return _items_by_id[item_id]
	var lazy_item := _lazy_load_item_by_id(item_id)
	if lazy_item != null:
		_items_by_id[item_id] = lazy_item
		if typeof(lazy_item.internal_name) == TYPE_STRING and lazy_item.internal_name != "":
			_items_by_name[lazy_item.internal_name.to_lower()] = lazy_item
		return lazy_item
	return null


func _lazy_load_item_by_id(item_id: int) -> ItemData:
	var path_item: String = _ITEM_INDEX.BY_ID.get(item_id, "")
	if path_item.is_empty():
		return null
	if ResourceLoader.exists(path_item):
		return load(path_item) as ItemData
	return null

## Verifica si existe un item por ID (AC-03)
func has_item_id(id: int) -> bool:
	return _items_by_id.has(id)

## Verifica si existe un item por nombre interno (AC-03)
func has_item_name(item_name: String) -> bool:
	var key := str(item_name).to_lower()
	return _items_by_name.has(key)

## Obtiene un item por ID (método explícito, AC-03)
func get_item_by_id(id: int) -> ItemData:
	return get_item(id)

## Obtiene un item por nombre interno (método explícito, AC-03)
func get_item_by_name(item_name: String) -> ItemData:
	return get_item(item_name)
