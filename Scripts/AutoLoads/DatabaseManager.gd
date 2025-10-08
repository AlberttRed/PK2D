extends Node

## DatabaseManager - Autoload para centralizar acceso a Resources del juego
## Carga e indexa Pokémon, Movimientos, Tipos, Habilidades y Naturalezas.

const POKEMON_DIR := "res://Resources/Data/Pokemon"
const MOVES_DIR := "res://Resources/Data/Moves"
const TYPES_DIR := "res://Resources/Data/Types"
const ABILITIES_DIR := "res://Resources/Data/Abilities"
const NATURES_DIR := "res://Resources/Data/Natures" # opcional, si existe

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

func _ready() -> void:
	_load_all()
	_print_summary()

func _load_all() -> void:
	_pokemon_by_id.clear(); _pokemon_by_name.clear()
	_moves_by_id.clear(); _moves_by_name.clear()
	_types_by_id.clear(); _types_by_name.clear()
	_abilities_by_id.clear(); _abilities_by_name.clear()
	_natures_by_id.clear(); _natures_by_name.clear()

	load_resources_from_dir(POKEMON_DIR, func(res):
		if res == null: return
		if not (res is Pokemon): return
		_pokemon_by_id[res.id] = res
		if typeof(res.internal_name) == TYPE_STRING and res.internal_name != "":
			_pokemon_by_name[res.internal_name.to_lower()] = res
	)

	_load_moves()
	_load_types()
	_load_abilities()
	_load_natures()

func _print_summary() -> void:
	print("DatabaseManager: Loaded %d Pokémon, %d moves, %d types, %d abilities, %d natures" % [
		_pokemon_by_id.size(), _moves_by_id.size(), _types_by_id.size(), _abilities_by_id.size(), _natures_by_id.size()
	])

func _load_moves() -> void:
	load_resources_from_dir(MOVES_DIR, func(res):
		if res == null: return
		if not (res is Move): return
		_moves_by_id[res.id] = res
		if typeof(res.internal_name) == TYPE_STRING and res.internal_name != "":
			_moves_by_name[res.internal_name.to_lower()] = res
	)

func _load_types() -> void:
	load_resources_from_dir(TYPES_DIR, func(res):
		if res == null: return
		if not (res is Type): return
		_types_by_id[res.id] = res
		if typeof(res.internal_name) == TYPE_STRING and res.internal_name != "":
			_types_by_name[res.internal_name.to_lower()] = res
	)

func _load_abilities() -> void:
	load_resources_from_dir(ABILITIES_DIR, func(res):
		if res == null: return
		if not (res is Ability): return
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
			if not (res is Nature): return
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
			var nat := Nature.new()
			nat.id = nat_id.to_lower()
			nat.display_name = nat_id.capitalize()
			_natures_by_id[nat.id] = nat
			_natures_by_name[nat.id] = nat

## Utilidad genérica para escanear un directorio y cargar .tres
func load_resources_from_dir(dir_path: String, on_loaded: Callable) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
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
		var res := load(path)
		if res != null:
			on_loaded.call(res)
	dir.list_dir_end()

# === API DE ACCESO ===

func get_pokemon(name_or_id) -> Resource:
	if typeof(name_or_id) == TYPE_INT:
		return _pokemon_by_id.get(name_or_id, null)
	var key := str(name_or_id).to_lower()
	if key.is_valid_int():
		return _pokemon_by_id.get(int(key), null)
	return _pokemon_by_name.get(key, null)

func get_move(name_or_id) -> Resource:
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
