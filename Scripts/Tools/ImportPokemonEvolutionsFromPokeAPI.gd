@tool
extends EditorScript

const EvoRow := preload("res://Scripts/Resources/Classes/PokemonEvolutionRow.gd")

## Importa evoluciones desde PokeAPI en PokemonData existentes (solo toca `evolutions`).
## Cada fila es un `PokemonEvolutionRow` embebido en el mismo .tres del Pokémon (no un archivo aparte).
##
## Ejecución: abrir script → **Archivo → Ejecutar**. Requiere red.

const POKEAPI_HOST := "pokeapi.co"
const POKEAPI_BASE_PATH := "/api/v2"

const POKEMON_DIR := "res://Resources/Data/Pokemon"

const START_ID: int = 1
const END_ID: int = 151

const REQUEST_DELAY_MS: int = 80
const DRY_RUN: bool = false

var _errors: int = 0
var _updated: int = 0
var _skipped: int = 0


func _run() -> void:
	print("========================================")
	print("[ImportPokemonEvolutionsFromPokeAPI] Inicio (IDs %d–%d, DRY_RUN=%s)" % [START_ID, END_ID, DRY_RUN])
	print("========================================")

	var chain_cache: Dictionary = {}

	for species_id in range(START_ID, END_ID + 1):
		var tres_path := _resolve_pokemon_tres_path(species_id)
		if tres_path.is_empty():
			push_warning("[Evolutions] No hay .tres para species_id=%d — salto." % species_id)
			_skipped += 1
			continue

		var species_json := _http_get_json(POKEAPI_HOST, "%s/pokemon-species/%d/" % [POKEAPI_BASE_PATH, species_id])
		_delay()
		if species_json.is_empty():
			push_error("[Evolutions] No se pudo leer pokemon-species/%d" % species_id)
			_errors += 1
			continue

		var chain_url: String = str(species_json.get("evolution_chain", {}).get("url", ""))
		if chain_url.is_empty():
			push_warning("[Evolutions] species %d sin evolution_chain" % species_id)
			_errors += 1
			continue

		if not chain_cache.has(chain_url):
			var host_path := _host_and_path_from_pokeapi_url(chain_url)
			if host_path.is_empty():
				_errors += 1
				continue
			var chain_json := _http_get_json(host_path.host, host_path.path)
			_delay()
			if chain_json.is_empty():
				push_error("[Evolutions] No se pudo leer cadena: %s" % chain_url)
				_errors += 1
				continue
			chain_cache[chain_url] = chain_json

		var chain_doc: Dictionary = chain_cache[chain_url]
		var chain_root: Dictionary = chain_doc.get("chain", {}) as Dictionary
		var bundle := _extract_evolutions_for_species(chain_root, species_id)

		if DRY_RUN:
			print("[DRY] %s | rows=%d" % [tres_path, bundle.evolutions.size()])
			_updated += 1
			continue

		var res := load(tres_path)
		if res == null or not (res is PokemonData):
			push_error("[Evolutions] No es PokemonData: %s" % tres_path)
			_errors += 1
			continue

		var pd := res as PokemonData
		var new_evolutions: Array = []
		for r in bundle.evolutions:
			new_evolutions.append(r.duplicate(true) as EvoRow)
		pd.evolutions = new_evolutions

		var err := ResourceSaver.save(pd, tres_path)
		if err != OK:
			push_error("[Evolutions] Error guardando %s: %d" % [tres_path, err])
			_errors += 1
		else:
			_updated += 1
			print("[Evolutions] OK id=%d rows=%d → %s" % [species_id, pd.evolutions.size(), tres_path])

	EditorInterface.get_resource_filesystem().scan()

	print("========================================")
	print("[ImportPokemonEvolutionsFromPokeAPI] Fin | actualizados=%d omitidos=%d errores=%d" % [_updated, _skipped, _errors])
	print("========================================")


func _resolve_pokemon_tres_path(species_id: int) -> String:
	var prefix := "%03d" % species_id
	var dir := DirAccess.open(POKEMON_DIR)
	if dir == null:
		return ""
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			if file_name.begins_with(prefix):
				dir.list_dir_end()
				return "%s/%s" % [POKEMON_DIR, file_name]
		file_name = dir.get_next()
	dir.list_dir_end()
	return ""


func _extract_evolutions_for_species(chain_root: Dictionary, species_id: int) -> _EvoBundle:
	var b := _EvoBundle.new()
	var node := _find_chain_node_for_species(chain_root, species_id)
	if node.is_empty():
		return b

	for ev in node.get("evolves_to", []) as Array:
		var ev_d := ev as Dictionary
		var target_url: String = str(ev_d.get("species", {}).get("url", ""))
		var target_id := _extract_id_from_url(target_url)
		if target_id <= 0:
			continue
		for det_any in ev_d.get("evolution_details", []) as Array:
			var det := det_any as Dictionary
			var row := _build_evolution_row(det, target_id)
			b.evolutions.append(row)

	b._sort_evolutions()
	return b


func _build_evolution_row(det: Dictionary, target_species_id: int) -> EvoRow:
	var trigger_name: String = str(det.get("trigger", {}).get("name", ""))
	var row := EvoRow.new()
	row.method = _map_trigger_to_method(trigger_name)
	row.target_species_id = target_species_id
	row.trigger_raw = trigger_name
	row.min_level = _opt_int(det, "min_level", 0)
	row.min_happiness = _opt_int(det, "min_happiness", -1)
	row.min_affection = _opt_int(det, "min_affection", -1)
	row.min_beauty = _opt_int(det, "min_beauty", -1)
	row.gender_id = _opt_int(det, "gender", 0)
	row.relative_physical_stats = _opt_int(det, "relative_physical_stats", -999)
	row.needs_overworld_rain = bool(det.get("needs_overworld_rain", false))
	row.turn_upside_down = bool(det.get("turn_upside_down", false))
	row.time_of_day = str(det.get("time_of_day", ""))
	row.item_id = _url_id(det, "item")
	row.held_item_id = _url_id(det, "held_item")
	row.trade_species_id = _url_id(det, "trade_species")
	row.location_id = _url_id(det, "location")
	row.known_move_id = _url_id(det, "known_move")
	row.known_move_type_id = _url_id(det, "known_move_type")
	row.party_species_id = _url_id(det, "party_species")
	row.party_type_id = _url_id(det, "party_type")
	return row


func _opt_int(det: Dictionary, key: String, absent: int) -> int:
	if not det.has(key):
		return absent
	var v: Variant = det[key]
	if v == null:
		return absent
	return int(v)


func _url_id(det: Dictionary, key: String) -> int:
	if not det.has(key):
		return 0
	var named: Variant = det[key]
	if named == null or not (named is Dictionary):
		return 0
	var url: String = str((named as Dictionary).get("url", ""))
	return _extract_id_from_url(url)


func _map_trigger_to_method(trigger_name: String) -> int:
	match trigger_name:
		"level-up":
			return 0
		"trade":
			return 1
		"use-item":
			return 2
		_:
			return 10


func _find_chain_node_for_species(node: Dictionary, species_id: int) -> Dictionary:
	var url: String = str(node.get("species", {}).get("url", ""))
	if _extract_id_from_url(url) == species_id:
		return node
	for sub_any in node.get("evolves_to", []) as Array:
		var sub := sub_any as Dictionary
		var found := _find_chain_node_for_species(sub, species_id)
		if not found.is_empty():
			return found
	return {}


func _host_and_path_from_pokeapi_url(full_url: String) -> Dictionary:
	var s := full_url.strip_edges().trim_suffix("/")
	s = s.replace("https://", "").replace("http://", "")
	var slash := s.find("/")
	if slash < 0:
		return {}
	var host := s.substr(0, slash)
	var path := s.substr(slash)
	return {"host": host, "path": path}


func _http_get_json(host: String, path: String) -> Dictionary:
	var http := HTTPClient.new()
	var tls := TLSOptions.client()
	if http.connect_to_host(host, 443, tls) != OK:
		return {}
	while http.get_status() == HTTPClient.STATUS_CONNECTING or http.get_status() == HTTPClient.STATUS_RESOLVING:
		http.poll()
		OS.delay_msec(5)
	if http.get_status() != HTTPClient.STATUS_CONNECTED:
		return {}
	if http.request(HTTPClient.METHOD_GET, path, []) != OK:
		return {}
	while http.get_status() == HTTPClient.STATUS_REQUESTING:
		http.poll()
		OS.delay_msec(5)
	var body := PackedByteArray()
	while http.get_status() == HTTPClient.STATUS_BODY:
		http.poll()
		var chunk := http.read_response_body_chunk()
		if chunk.is_empty():
			OS.delay_msec(5)
		else:
			body.append_array(chunk)
	if http.get_response_code() != 200:
		return {}
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		return {}
	var data = json.get_data()
	return data as Dictionary


func _extract_id_from_url(url: String) -> int:
	var parts := url.split("/")
	for i in range(parts.size() - 1, -1, -1):
		var part := parts[i].trim_suffix("/")
		if part.is_valid_int():
			return int(part)
	return 0


func _delay() -> void:
	if REQUEST_DELAY_MS > 0:
		OS.delay_msec(REQUEST_DELAY_MS)


class _EvoBundle extends RefCounted:
	var evolutions: Array[EvoRow] = []


	func _sort_evolutions() -> void:
		evolutions.sort_custom(func(a: EvoRow, b: EvoRow) -> bool:
			if a.target_species_id != b.target_species_id:
				return a.target_species_id < b.target_species_id
			if a.method != b.method:
				return a.method < b.method
			return a.trigger_raw < b.trigger_raw
		)
