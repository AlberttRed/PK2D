extends Node

## DatabaseService - Autoload para centralizar acceso a Resources del juego
## Carga e indexa Pokémon, Movimientos, Tipos, Habilidades, Naturalezas y Climas.
## Accesible globalmente como autoload: DatabaseService

const POKEMON_DIR := "res://Resources/Data/Pokemon"
const MOVES_DIR := "res://Resources/Data/Moves"
const TYPES_DIR := "res://Resources/Data/Types"
const ABILITIES_DIR := "res://Resources/Data/Abilities"
const NATURES_DIR := "res://Resources/Data/Natures" # opcional, si existe
const WEATHERS_DIR := "res://Resources/Data/Weather" # opcional, si existe
const TRAINER_CLASSES_DIR := "res://Resources/Trainer Classes"
const ITEMS_DIR := "res://Resources/Data/Items"

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
	load_resources_from_dir(ABILITIES_DIR, func(res):
		if res == null: return
		if not (res is AbilityData): return
		_abilities_by_id[res.id] = res
		if typeof(res.internal_name) == TYPE_STRING and res.internal_name != "":
			_abilities_by_name[res.internal_name.to_lower()] = res
	)

func _load_natures() -> void:
	var natures_loaded := false
	var dir := DirAccess.open(NATURES_DIR)
	if dir != null:
		load_resources_from_dir(NATURES_DIR, func(res):
			if res == null: return
			if not (res is NatureData): return
			_natures_by_id[res.id] = res
			var key := str(res.id).to_lower()
			_natures_by_name[key] = res
		)
		natures_loaded = _natures_by_id.size() > 0

	if not natures_loaded:
		# Construye naturalezas en memoria a partir de NaturesEnum si no hay .tres
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
	# Para Pokémon: buscar archivos que empiecen con 000-151
	if dir_path == POKEMON_DIR:
		var scan_dir := DirAccess.open(dir_path)
		if scan_dir != null:
			scan_dir.list_dir_begin()
			var file_name := scan_dir.get_next()

			while file_name != "":
				if scan_dir.current_is_dir() or not file_name.ends_with(".tres"):
					file_name = scan_dir.get_next()
					continue

				# Extraer ID del nombre del archivo
				# Soporta tanto "001.tres" como "001 - Bulbasaur.tres"
				var file_base := file_name.get_basename()
				var id_str := file_base.split(" - ")[0].split(" ")[0].strip_edges()

				if id_str.is_valid_int():
					var id := int(id_str)
					if id >= 0 and id < 152:  # Rango válido para Pokémon
						var path := dir_path + "/" + file_name
						if ResourceLoader.exists(path):
							var res := load(path)
							if res != null:
								on_loaded.call(res)

				file_name = scan_dir.get_next()

			scan_dir.list_dir_end()
		return

	# Para Moves: escanear directorio y extraer ID del nombre del archivo
	# Soporta tanto "001.tres" como "001 - Nombre.tres"
	if dir_path == MOVES_DIR:
		var scan_dir := DirAccess.open(dir_path)
		if scan_dir != null:
			scan_dir.list_dir_begin()
			var file_name := scan_dir.get_next()

			while file_name != "":
				if scan_dir.current_is_dir() or not file_name.ends_with(".tres"):
					file_name = scan_dir.get_next()
					continue

				# Extraer ID del nombre del archivo
				# Soporta tanto "001.tres" como "001 - Nombre.tres"
				var file_base := file_name.get_basename()
				var id_str := file_base.split(" - ")[0].split(" ")[0].strip_edges()

				if id_str.is_valid_int():
					var path := dir_path + "/" + file_name
					if ResourceLoader.exists(path):
						var res := load(path)
						if res != null:
							on_loaded.call(res)

				file_name = scan_dir.get_next()

			scan_dir.list_dir_end()
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

	# Para Abilities: intentar cargar del 001 al 232 (rango típico de Gen 1-3)
	if dir_path == ABILITIES_DIR:
		for i in range(1, 233):
			var path := "%s/%03d.tres" % [dir_path, i]
			if ResourceLoader.exists(path):
				var res := load(path)
				if res != null:
					on_loaded.call(res)
		return

	# Para Weather: intentar cargar del 01 al 10
	if dir_path == WEATHERS_DIR:
		for i in range(1, 11):
			var path := "%s/%02d.tres" % [dir_path, i]
			if ResourceLoader.exists(path):
				var res := load(path)
				if res != null:
					on_loaded.call(res)
		return

	# Para Items: escanear directorio y extraer ID del nombre del archivo
	# Soporta tanto "017.tres" como "017 - Poción.tres"
	if dir_path == ITEMS_DIR:
		var scan_dir := DirAccess.open(dir_path)
		if scan_dir != null:
			scan_dir.list_dir_begin()
			var file_name := scan_dir.get_next()

			while file_name != "":
				if scan_dir.current_is_dir() or not file_name.ends_with(".tres"):
					file_name = scan_dir.get_next()
					continue

				var file_base := file_name.get_basename()
				var id_str := file_base.split(" - ")[0].split(" ")[0].strip_edges()
				if id_str.is_valid_int():
					var path := dir_path + "/" + file_name
					if ResourceLoader.exists(path):
						var res := load(path)
						if res != null:
							on_loaded.call(res)

				file_name = scan_dir.get_next()

			scan_dir.list_dir_end()
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
	if typeof(name_or_id) == TYPE_INT:
		return _pokemon_by_id.get(name_or_id, null)
	var key := str(name_or_id).to_lower()
	if key.is_valid_int():
		return _pokemon_by_id.get(int(key), null)
	return _pokemon_by_name.get(key, null)

func get_move(name_or_id) -> MoveData:
	if typeof(name_or_id) == TYPE_INT:
		return _moves_by_id.get(name_or_id, null)
	var key := str(name_or_id).to_lower()
	if key.is_valid_int():
		return _moves_by_id.get(int(key), null)
	return _moves_by_name.get(key, null)

func get_type(name_or_id) -> Resource:
	if typeof(name_or_id) == TYPE_INT:
		return _types_by_id.get(name_or_id, null)
	var key := str(name_or_id).to_lower()
	if key.is_valid_int():
		return _types_by_id.get(int(key), null)
	return _types_by_name.get(key, null)

func get_ability(name_or_id) -> Resource:
	if typeof(name_or_id) == TYPE_INT:
		return _abilities_by_id.get(name_or_id, null)
	var key := str(name_or_id).to_lower()
	if key.is_valid_int():
		return _abilities_by_id.get(int(key), null)
	return _abilities_by_name.get(key, null)

func get_nature(name_or_id) -> Resource:
	var key := str(name_or_id).to_lower()
	return _natures_by_id.get(key, _natures_by_name.get(key, null))

func get_weather(name_or_id) -> WeatherData:
	if typeof(name_or_id) == TYPE_INT:
		return _weathers_by_id.get(name_or_id, null)
	var key := str(name_or_id).to_lower()
	if key.is_valid_int():
		return _weathers_by_id.get(int(key), null)
	return _weathers_by_name.get(key, null)

func get_trainer_class(name_or_id) -> TrainerClassData:
	if typeof(name_or_id) == TYPE_INT:
		return _trainer_classes_by_id.get(name_or_id, null)
	var key := str(name_or_id).to_lower()
	if key.is_valid_int():
		return _trainer_classes_by_id.get(int(key), null)
	return _trainer_classes_by_name.get(key, null)

func get_item(name_or_id) -> ItemData:
	var result: ItemData = null

	if typeof(name_or_id) == TYPE_INT:
		result = _items_by_id.get(name_or_id, null)
	else:
		var key := str(name_or_id).to_lower()
		if key.is_valid_int():
			result = _items_by_id.get(int(key), null)
		else:
			result = _items_by_name.get(key, null)

	# Comportamiento ante no encontrado (AC-04)
	if result == null:
		push_warning("DatabaseService: Item no encontrado: %s (tipo: %s)" % [str(name_or_id), typeof(name_or_id)])

	return result

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
