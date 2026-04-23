extends RefCounted
class_name PokedexController

const POKEDEX_CATALOG_SCRIPT = preload("res://Scripts/Runtime/PokedexCatalog.gd")

var _entries: Array[Dictionary] = []
var _dex_defs: Array[Dictionary] = []
var _active_dex_id: String = ""
var _active_search_filters: Dictionary = {}


func _init() -> void:
	refresh()


func refresh() -> void:
	_rebuild_dex_registry()
	_rebuild_entries()


func apply_search_filters(filters: Dictionary) -> void:
	_active_search_filters = filters.duplicate(true)
	_rebuild_entries()


func clear_search_filters() -> void:
	_active_search_filters.clear()
	_rebuild_entries()


func has_active_search_filters() -> bool:
	return not _active_search_filters.is_empty()


func get_entry_count() -> int:
	return _entries.size()


## Número de registros navegables: hasta el nº más alto visto en la dex activa.
## Si no hay ninguno visto, mantener al menos 1 para no dejar la UI sin foco.
func get_navigation_limit_count() -> int:
	if _entries.is_empty():
		return 0
	var max_seen_dex_number := 0
	for entry in _entries:
		if not bool(entry.get("seen", false)):
			continue
		var dex_number := int(entry.get("dex_number", 0))
		if dex_number > max_seen_dex_number:
			max_seen_dex_number = dex_number
	if max_seen_dex_number <= 0:
		return 1
	return mini(max_seen_dex_number, _entries.size())


func get_seen_count() -> int:
	return _count_seen_for_active_dex()


func get_caught_count() -> int:
	return _count_caught_for_active_dex()


func get_active_dex_name() -> String:
	var dex_def := _get_active_dex_def()
	return str(dex_def.get("display_name", "Pokédex"))


func get_region_rows() -> Array[Dictionary]:
	var pokedex = GameStateService.get_pokedex()
	var out: Array[Dictionary] = []
	for dex_def in _dex_defs:
		var dex_id := str(dex_def.get("id", ""))
		var seen := 0
		var caught := 0
		var entries: Array = dex_def.get("entries", [])
		for e_any in entries:
			var e: Dictionary = e_any
			var species_id := int(e.get("species_id", 0))
			if species_id <= 0:
				continue
			if pokedex.is_seen(species_id):
				seen += 1
			if pokedex.is_caught(species_id):
				caught += 1
		out.append({
			"dex_id": dex_id,
			"display_name": str(dex_def.get("display_name", dex_id)),
			"seen_count": seen,
			"caught_count": caught,
			"unlocked": GameStateService.is_pokedex_unlocked(dex_id),
			"active": dex_id == _active_dex_id,
		})
	return out


func try_select_region(index: int) -> Dictionary:
	var rows := get_region_rows()
	if index < 0 or index >= rows.size():
		return {"ok": false, "exit": false}
	var row: Dictionary = rows[index]
	if not bool(row.get("unlocked", false)):
		return {"ok": false, "exit": false}
	var dex_id := str(row.get("dex_id", ""))
	if dex_id.is_empty():
		return {"ok": false, "exit": false}
	if not GameStateService.set_active_pokedex_id(dex_id):
		return {"ok": false, "exit": false}
	_active_dex_id = dex_id
	_rebuild_entries()
	return {"ok": true, "exit": false}


func get_list_entry(index: int) -> Dictionary:
	if index < 0 or index >= _entries.size():
		return {}
	return _entries[index]


func is_entry_discovered(index: int) -> bool:
	if index < 0 or index >= _entries.size():
		return false
	var e: Dictionary = _entries[index]
	return bool(e.get("seen", false)) or bool(e.get("caught", false))


func get_previous_discovered_index(from_index: int) -> int:
	if _entries.is_empty():
		return -1
	var start := clampi(from_index, 0, _entries.size() - 1)
	for i in range(start - 1, -1, -1):
		if is_entry_discovered(i):
			return i
	# Wrap-around: desde el inicio buscar al final.
	for i in range(_entries.size() - 1, start, -1):
		if is_entry_discovered(i):
			return i
	return start


func get_next_discovered_index(from_index: int) -> int:
	if _entries.is_empty():
		return -1
	var start := clampi(from_index, 0, _entries.size() - 1)
	for i in range(start + 1, _entries.size()):
		if is_entry_discovered(i):
			return i
	# Wrap-around: desde el final buscar al inicio.
	for i in range(0, start):
		if is_entry_discovered(i):
			return i
	return start


func get_detail_for_index(index: int) -> Dictionary:
	var entry := get_list_entry(index)
	if entry.is_empty():
		return {
			"name": "----",
			"number_text": "---",
			"types_text": "Tipo: ---",
			"sprite": null,
			"seen": false,
		}
	if not bool(entry.get("seen", false)):
		return {
			"name": "????",
			"number_text": "%03d" % int(entry.get("species_id", 0)),
			"types_text": "Tipo: ???",
			"sprite": null,
			"seen": false,
		}
	return {
		"name": str(entry.get("name", "----")),
		"number_text": "%03d" % int(entry.get("dex_number", 0)),
		"types_text": str(entry.get("types_text", "Tipo: ---")),
		"sprite": entry.get("sprite", null),
		"seen": true,
	}


func _rebuild_entries() -> void:
	var base_entries: Array[Dictionary] = []
	var dex_def := _get_active_dex_def()
	var dex_entries: Array = dex_def.get("entries", [])
	if dex_entries.is_empty():
		_entries.clear()
		return
	var pokedex = GameStateService.get_pokedex()
	for dex_entry_any in dex_entries:
		var dex_entry: Dictionary = dex_entry_any
		var species_id := int(dex_entry.get("species_id", 0))
		var dex_number := int(dex_entry.get("dex_number", 0))
		if species_id <= 0 or dex_number <= 0:
			continue
		var data := DatabaseService.get_pokemon(species_id) as PokemonData
		if data == null:
			continue
		var seen: bool = pokedex.is_seen(species_id)
		var caught: bool = pokedex.is_caught(species_id)
		var t1 := DatabaseService.get_type(data.type_a_id) as TypeData
		var t2 := DatabaseService.get_type(data.type_b_id) as TypeData
		var types_text := "Tipo: ---"
		if t1 != null and t2 != null and t1.id != t2.id:
			types_text = "Tipo: %s / %s" % [t1.Name, t2.Name]
		elif t1 != null:
			types_text = "Tipo: %s" % t1.Name
		base_entries.append({
			"species_id": species_id,
			"dex_number": dex_number,
			"name": data.Name,
			"seen": seen,
			"caught": caught,
			"sprite": data.battle_front_sprite,
			"types_text": types_text,
			"type_a_id": int(data.type_a_id),
			"type_b_id": int(data.type_b_id),
			"height": float(data.height),
			"weight": float(data.weight),
		})
	_entries = _apply_active_filters(base_entries)


func _apply_active_filters(source_entries: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var name_group := str(_active_search_filters.get("name_group", "Sin especificar"))
	var type1_name := str(_active_search_filters.get("type1_name", "Ninguno"))
	var type2_name := str(_active_search_filters.get("type2_name", "Ninguno"))
	var order_mode := str(_active_search_filters.get("order_mode", "Modo num."))

	var type1_id := _resolve_type_id_from_name(type1_name)
	var type2_id := _resolve_type_id_from_name(type2_name)
	var has_name_filter := name_group != "Sin especificar"
	var has_type_filter := type1_id > 0 or type2_id > 0

	for entry in source_entries:
		var seen := bool(entry.get("seen", false))
		var caught := bool(entry.get("caught", false))
		var include := true

		if has_name_filter:
			if not seen:
				include = false
			else:
				var first_letter := str(entry.get("name", "")).strip_edges().substr(0, 1).to_upper()
				if first_letter.is_empty() or not name_group.contains(first_letter):
					include = false

		if include and has_type_filter:
			if not caught:
				include = false
			else:
				var a_id := int(entry.get("type_a_id", 0))
				var b_id := int(entry.get("type_b_id", 0))
				if type1_id > 0 and not (a_id == type1_id or b_id == type1_id):
					include = false
				if include and type2_id > 0 and not (a_id == type2_id or b_id == type2_id):
					include = false

		if include:
			out.append(entry)

	_sort_entries_by_mode(out, order_mode)
	return out


func _sort_entries_by_mode(entries: Array[Dictionary], mode: String) -> void:
	match mode:
		"Modo alfab.":
			entries = _restrict_to_discovered(entries)
			entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return str(a.get("name", "")).to_lower() < str(b.get("name", "")).to_lower()
			)
		"Más pesado":
			entries = _restrict_to_discovered(entries)
			entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return float(a.get("weight", 0.0)) > float(b.get("weight", 0.0))
			)
		"Más ligero":
			entries = _restrict_to_discovered(entries)
			entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return float(a.get("weight", 0.0)) < float(b.get("weight", 0.0))
			)
		"Más alto":
			entries = _restrict_to_discovered(entries)
			entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return float(a.get("height", 0.0)) > float(b.get("height", 0.0))
			)
		"Más bajo":
			entries = _restrict_to_discovered(entries)
			entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return float(a.get("height", 0.0)) < float(b.get("height", 0.0))
			)
		_:
			entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return int(a.get("dex_number", 0)) < int(b.get("dex_number", 0))
			)


func _restrict_to_discovered(entries: Array[Dictionary]) -> Array[Dictionary]:
	var discovered: Array[Dictionary] = []
	for e in entries:
		var seen := bool(e.get("seen", false))
		var caught := bool(e.get("caught", false))
		if seen or caught:
			discovered.append(e)
	entries.clear()
	for d in discovered:
		entries.append(d)
	return entries


func _resolve_type_id_from_name(type_name: String) -> int:
	var name := type_name.strip_edges()
	if name.is_empty() or name == "Ninguno":
		return 0
	var direct := DatabaseService.get_type(name) as TypeData
	if direct != null:
		return int(direct.id)
	var normalized := name.to_lower()
	for type_data in DatabaseService.get_all_types_sorted():
		if type_data == null:
			continue
		if str(type_data.Name).strip_edges().to_lower() == normalized:
			return int(type_data.id)
		if str(type_data.internal_name).strip_edges().to_lower() == normalized:
			return int(type_data.id)
	return 0


func _rebuild_dex_registry() -> void:
	_dex_defs = POKEDEX_CATALOG_SCRIPT.get_all_dex_definitions()
	var unlocked := GameStateService.get_unlocked_pokedex_ids()
	for dex_def in _dex_defs:
		var dex_id := str(dex_def.get("id", ""))
		if dex_id.is_empty():
			continue
		if not unlocked.has(dex_id):
			continue
		# Mantener catálogo desbloqueado solo en estado del jugador.
		pass
	if unlocked.is_empty() and not _dex_defs.is_empty():
		var fallback_id := str(_dex_defs[0].get("id", ""))
		if not fallback_id.is_empty():
			GameStateService.unlock_pokedex(fallback_id)
			unlocked = GameStateService.get_unlocked_pokedex_ids()
	_active_dex_id = GameStateService.get_active_pokedex_id()
	if _active_dex_id.is_empty() and not unlocked.is_empty():
		_active_dex_id = unlocked[0]
		GameStateService.set_active_pokedex_id(_active_dex_id)
	if _get_active_dex_def().is_empty():
		for dex_def in _dex_defs:
			var dex_id := str(dex_def.get("id", ""))
			if GameStateService.is_pokedex_unlocked(dex_id):
				_active_dex_id = dex_id
				GameStateService.set_active_pokedex_id(dex_id)
				break


func _get_active_dex_def() -> Dictionary:
	if _active_dex_id.is_empty():
		return {}
	for dex_def in _dex_defs:
		if str(dex_def.get("id", "")) == _active_dex_id:
			return dex_def
	return {}


func _count_seen_for_active_dex() -> int:
	var dex_def := _get_active_dex_def()
	var entries: Array = dex_def.get("entries", [])
	var pokedex = GameStateService.get_pokedex()
	var seen := 0
	for e_any in entries:
		var e: Dictionary = e_any
		var species_id := int(e.get("species_id", 0))
		if species_id > 0 and pokedex.is_seen(species_id):
			seen += 1
	return seen


func _count_caught_for_active_dex() -> int:
	var dex_def := _get_active_dex_def()
	var entries: Array = dex_def.get("entries", [])
	var pokedex = GameStateService.get_pokedex()
	var caught := 0
	for e_any in entries:
		var e: Dictionary = e_any
		var species_id := int(e.get("species_id", 0))
		if species_id > 0 and pokedex.is_caught(species_id):
			caught += 1
	return caught
