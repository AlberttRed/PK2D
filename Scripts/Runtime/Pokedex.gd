extends RefCounted
class_name Pokedex

const SERIALIZE_VERSION: int = 1

# species_id -> {"seen": bool, "caught": bool}
var _entries: Dictionary = {}


func mark_seen(species_id: int) -> void:
	if species_id <= 0:
		return
	var entry := _ensure_entry(species_id)
	entry["seen"] = true
	_entries[species_id] = entry


func is_seen(species_id: int) -> bool:
	if species_id <= 0:
		return false
	var entry: Dictionary = _entries.get(species_id, {})
	return bool(entry.get("seen", false))


func mark_caught(species_id: int) -> void:
	if species_id <= 0:
		return
	var entry := _ensure_entry(species_id)
	entry["caught"] = true
	# En la práctica, capturado implica visto.
	entry["seen"] = true
	_entries[species_id] = entry


func is_caught(species_id: int) -> bool:
	if species_id <= 0:
		return false
	var entry: Dictionary = _entries.get(species_id, {})
	return bool(entry.get("caught", false))


func get_seen_count() -> int:
	var count := 0
	for entry_any in _entries.values():
		var entry: Dictionary = entry_any
		if bool(entry.get("seen", false)):
			count += 1
	return count


func get_caught_count() -> int:
	var count := 0
	for entry_any in _entries.values():
		var entry: Dictionary = entry_any
		if bool(entry.get("caught", false)):
			count += 1
	return count


func to_serializable_data() -> Dictionary:
	var by_species: Dictionary = {}
	for species_key in _entries.keys():
		var species_id := int(species_key)
		var entry: Dictionary = _entries[species_key]
		by_species[str(species_id)] = {
			"seen": bool(entry.get("seen", false)),
			"caught": bool(entry.get("caught", false)),
		}
	return {
		"v": SERIALIZE_VERSION,
		"entries": by_species,
	}


func load_serializable_data(data: Dictionary) -> void:
	_entries.clear()
	if data.is_empty():
		return
	var entries_any: Variant = data.get("entries", {})
	if typeof(entries_any) != TYPE_DICTIONARY:
		return
	var entries: Dictionary = entries_any
	for key in entries.keys():
		var id_str := str(key).strip_edges()
		if not id_str.is_valid_int():
			continue
		var species_id := int(id_str)
		if species_id <= 0:
			continue
		var value_any: Variant = entries[key]
		if typeof(value_any) != TYPE_DICTIONARY:
			continue
		var value: Dictionary = value_any
		_entries[species_id] = {
			"seen": bool(value.get("seen", false)),
			"caught": bool(value.get("caught", false)),
		}


func _ensure_entry(species_id: int) -> Dictionary:
	var entry: Dictionary = _entries.get(species_id, {})
	if entry.is_empty():
		entry = {"seen": false, "caught": false}
	return entry
