@tool
extends EditorScript

## Importa en PokemonData:
## - `pokedex_numbers` (pokemon-species.pokedex_numbers)
## - `category` (pokemon-species.genera, es -> en)
##
## Ejecución: abrir script -> Archivo -> Ejecutar (requiere red).

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
	print("[ImportPokemonPokedexDataFromPokeAPI] Inicio (IDs %d-%d, DRY_RUN=%s)" % [START_ID, END_ID, DRY_RUN])
	print("========================================")

	for species_id in range(START_ID, END_ID + 1):
		var tres_path := _resolve_pokemon_tres_path(species_id)
		if tres_path.is_empty():
			push_warning("[PokedexData] No hay .tres para species_id=%d - salto." % species_id)
			_skipped += 1
			continue

		var species_json := _http_get_json(POKEAPI_HOST, "%s/pokemon-species/%d/" % [POKEAPI_BASE_PATH, species_id])
		_delay()
		if species_json.is_empty():
			push_error("[PokedexData] No se pudo leer pokemon-species/%d" % species_id)
			_errors += 1
			continue

		var imported_numbers := _extract_pokedex_numbers(species_json)
		var imported_category := _extract_category(species_json)

		if DRY_RUN:
			print("[DRY] id=%d | dex_keys=%d | category='%s' | %s" % [
				species_id, imported_numbers.size(), imported_category, tres_path
			])
			_updated += 1
			continue

		var res := load(tres_path)
		if res == null or not (res is PokemonData):
			push_error("[PokedexData] No es PokemonData: %s" % tres_path)
			_errors += 1
			continue

		var pd := res as PokemonData
		pd.pokedex_numbers = imported_numbers
		pd.category = imported_category

		var err := ResourceSaver.save(pd, tres_path)
		if err != OK:
			push_error("[PokedexData] Error guardando %s: %d" % [tres_path, err])
			_errors += 1
		else:
			_updated += 1
			print("[PokedexData] OK id=%d dex_keys=%d category='%s' -> %s" % [
				species_id, pd.pokedex_numbers.size(), pd.category, tres_path
			])

	EditorInterface.get_resource_filesystem().scan()

	print("========================================")
	print("[ImportPokemonPokedexDataFromPokeAPI] Fin | actualizados=%d omitidos=%d errores=%d" % [_updated, _skipped, _errors])
	print("========================================")


func _extract_pokedex_numbers(species_json: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var entries: Array = species_json.get("pokedex_numbers", []) as Array
	for entry_any in entries:
		var entry: Dictionary = entry_any as Dictionary
		var dex_name := str(entry.get("pokedex", {}).get("name", "")).strip_edges()
		var entry_number := int(entry.get("entry_number", 0))
		if dex_name.is_empty() or entry_number <= 0:
			continue
		out[dex_name] = entry_number
	return out


func _extract_category(species_json: Dictionary) -> String:
	var genera: Array = species_json.get("genera", []) as Array
	for g_any in genera:
		var g: Dictionary = g_any as Dictionary
		if str(g.get("language", {}).get("name", "")) == "es":
			var val_es := str(g.get("genus", "")).strip_edges()
			if not val_es.is_empty():
				return val_es
	for g_any in genera:
		var g: Dictionary = g_any as Dictionary
		if str(g.get("language", {}).get("name", "")) == "en":
			var val_en := str(g.get("genus", "")).strip_edges()
			if not val_en.is_empty():
				return val_en
	return ""


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


func _delay() -> void:
	if REQUEST_DELAY_MS > 0:
		OS.delay_msec(REQUEST_DELAY_MS)
