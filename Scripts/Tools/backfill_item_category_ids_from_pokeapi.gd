@tool
extends EditorScript

const POKEAPI_BASE_URL := "https://pokeapi.co/api/v2"
const ITEMS_DIR := "res://Resources/Data/Items"

var _processed := 0
var _updated := 0
var _errors: Array[String] = []


func _run() -> void:
	var dir := DirAccess.open(ITEMS_DIR)
	if dir == null:
		push_error("[backfill_item_category_ids] No se pudo abrir %s" % ITEMS_DIR)
		return

	var files := dir.get_files()
	files.sort()

	for file_name in files:
		if not file_name.ends_with(".tres"):
			continue

		var path := ITEMS_DIR + "/" + file_name
		var res: Resource = ResourceLoader.load(path)
		if res == null:
			continue

		var item_id := int(res.get("id"))
		if item_id <= 0:
			continue

		_processed += 1
		var category_id := _fetch_item_category_id(item_id)
		if category_id <= 0:
			_errors.append("No category_id para item %d (%s)" % [item_id, file_name])
			continue

		res.set("item_category_id", category_id)
		var err := ResourceSaver.save(res, path)
		if err == OK:
			_updated += 1
		else:
			_errors.append("Error guardando %s (%d)" % [path, err])

	print("[backfill_item_category_ids] procesados=%d actualizados=%d errores=%d" % [_processed, _updated, _errors.size()])
	for e in _errors:
		print(" - %s" % e)


func _fetch_item_category_id(item_id: int) -> int:
	var data := _http_request("%s/item/%d" % [POKEAPI_BASE_URL, item_id])
	if data.is_empty():
		return 0
	var category := data.get("category", {}) as Dictionary
	var category_url := category.get("url", "") as String
	return _extract_id_from_url(category_url)


func _http_request(url: String) -> Dictionary:
	var http := HTTPClient.new()
	var url_parts := url.replace("https://", "").replace("http://", "").split("/", false, 1)
	if url_parts.is_empty():
		return {}

	var host := url_parts[0]
	var path := "/" + url_parts[1] if url_parts.size() > 1 else "/"

	var tls_options := TLSOptions.client()
	var err := http.connect_to_host(host, 443, tls_options)
	if err != OK:
		return {}

	while http.get_status() == HTTPClient.STATUS_CONNECTING or http.get_status() == HTTPClient.STATUS_RESOLVING:
		http.poll()
		OS.delay_msec(10)
	if http.get_status() != HTTPClient.STATUS_CONNECTED:
		return {}

	err = http.request(HTTPClient.METHOD_GET, path, [])
	if err != OK:
		return {}
	while http.get_status() == HTTPClient.STATUS_REQUESTING:
		http.poll()
		OS.delay_msec(10)

	var body := PackedByteArray()
	while http.get_status() == HTTPClient.STATUS_BODY:
		http.poll()
		var chunk := http.read_response_body_chunk()
		if chunk.size() == 0:
			OS.delay_msec(10)
		else:
			body.append_array(chunk)

	if http.get_response_code() != 200:
		return {}

	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		return {}
	return json.get_data()


func _extract_id_from_url(url: String) -> int:
	var parts := url.split("/")
	for i in range(parts.size() - 1, -1, -1):
		var part := parts[i].trim_suffix("/")
		if part.is_valid_int():
			return int(part)
	return 0
