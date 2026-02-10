@tool
extends EditorScript

## Script de importación de items desde PokeAPI
## Genera ItemData resources y empaqueta iconos en atlas textures
## Ejecutar desde: Editor > Tools > Import Items from PokeAPI

const POKEAPI_BASE_URL := "https://pokeapi.co/api/v2"
const ITEMS_DIR := "res://Resources/Data/Items"
const ICONS_ATLAS_DIR := "res://Sprites/Iconos/Items"
const ITEMS_PER_ATLAS := 100  # Número de iconos por atlas (ajustable)
const LIMIT_ITEMS := 0  # Límite de items para pruebas (0 = sin límite)

# ItemData está disponible como class_name

# Estadísticas del import
var items_processed: int = 0
var icons_downloaded: int = 0
var items_without_icon: int = 0
var items_created: int = 0
var items_updated: int = 0
var errors: Array[String] = []

func _run() -> void:
	print("========================================")
	print("[ImportItemsFromPokeAPI] Iniciando importación...")
	print("========================================")

	# Crear directorios necesarios
	_ensure_directories()

	# Obtener lista de items desde PokeAPI
	var item_list := _fetch_item_list()
	if item_list.is_empty():
		push_error("[ImportItemsFromPokeAPI] No se pudieron obtener items desde PokeAPI")
		return

	print("[ImportItemsFromPokeAPI] Encontrados %d items en PokeAPI" % item_list.size())

	# Limitar items para pruebas si está configurado
	var items_to_process := item_list
	if LIMIT_ITEMS > 0:
		items_to_process = item_list.slice(0, LIMIT_ITEMS)
		print("[ImportItemsFromPokeAPI] Modo prueba: procesando solo %d items" % LIMIT_ITEMS)

	# Procesar cada item
	var current_atlas_index := 0
	var current_atlas_items: Array[Dictionary] = []  # Array de {item_id, image, resource}

	for item_url in items_to_process:
		var item_id := _extract_id_from_url(item_url)
		if item_id <= 0:
			continue

		print("[ImportItemsFromPokeAPI] Procesando item %d..." % item_id)

		# Obtener datos del item
		var item_data := _fetch_item_data(item_id)
		if item_data.is_empty():
			push_error("[ImportItemsFromPokeAPI] Error obteniendo datos del item %d" % item_id)
			continue

		# Descargar icono si existe
		var icon_image: Image = null
		var sprites := item_data.get("sprites", {}) as Dictionary
		var icon_url := sprites.get("default", "") as String
		if icon_url != "":
			icon_image = _download_image(icon_url)
			if icon_image != null:
				icons_downloaded += 1
			else:
				items_without_icon += 1
		else:
			items_without_icon += 1

		# Crear o actualizar ItemData (sin icono todavía)
		var item_resource: Resource = _create_or_update_item_data(item_id, item_data)
		if item_resource != null:
			items_processed += 1

		# Si tenemos icono, añadirlo al atlas actual
		# Guardamos la referencia al archivo para poder actualizarlo después
		if icon_image != null and item_resource != null:
			var file_path := ITEMS_DIR + "/%03d.tres" % item_id
			current_atlas_items.append({
				"item_id": item_id,
				"image": icon_image,
				"resource": item_resource,
				"file_path": file_path
			})

			# Si llegamos al límite, crear atlas y resetear
			if current_atlas_items.size() >= ITEMS_PER_ATLAS:
				_create_atlas_for_items(current_atlas_index, current_atlas_items)
				current_atlas_index += 1
				current_atlas_items.clear()

	# Crear atlas final si quedan items
	if not current_atlas_items.is_empty():
		_create_atlas_for_items(current_atlas_index, current_atlas_items)

	# Mostrar resumen
	_print_summary()

	# Refrescar filesystem del editor
	EditorInterface.get_resource_filesystem().scan()

	print("========================================")
	print("[ImportItemsFromPokeAPI] Importación completada")
	print("========================================")

func _ensure_directories() -> void:
	# Crear directorios si no existen
	var dirs := [ITEMS_DIR, ICONS_ATLAS_DIR]
	for dir_path in dirs:
		if not DirAccess.dir_exists_absolute(dir_path):
			DirAccess.make_dir_recursive_absolute(dir_path)
			print("[ImportItemsFromPokeAPI] Creado directorio: %s" % dir_path)

func _fetch_item_list() -> Array[String]:
	# Obtener lista de items desde PokeAPI
	# PokeAPI tiene paginación, pero podemos obtener todos de una vez con un límite alto
	var url := POKEAPI_BASE_URL + "/item?limit=2000"
	var result := _http_request(url)

	if result.is_empty():
		return []

	var items: Array[String] = []
	var results := result.get("results", []) as Array
	for item in results:
		var item_dict := item as Dictionary
		var item_url := item_dict.get("url", "") as String
		if item_url != "":
			items.append(item_url)

	return items

func _fetch_item_data(item_id: int) -> Dictionary:
	var url := POKEAPI_BASE_URL + "/item/" + str(item_id)
	return _http_request(url)

func _http_request(url: String) -> Dictionary:
	var http := HTTPClient.new()

	# Parsear URL manualmente
	var url_parts := url.replace("https://", "").replace("http://", "").split("/", false, 1)
	if url_parts.is_empty():
		push_error("[ImportItemsFromPokeAPI] URL inválida: %s" % url)
		return {}

	var host := url_parts[0]
	var path := "/" + url_parts[1] if url_parts.size() > 1 else "/"

	# Conectar
	var tls_options := TLSOptions.client()
	var error := http.connect_to_host(host, 443, tls_options)
	if error != OK:
		push_error("[ImportItemsFromPokeAPI] Error conectando: %d" % error)
		return {}

	# Esperar conexión
	while http.get_status() == HTTPClient.STATUS_CONNECTING or http.get_status() == HTTPClient.STATUS_RESOLVING:
		http.poll()
		OS.delay_msec(10)

	if http.get_status() != HTTPClient.STATUS_CONNECTED:
		push_error("[ImportItemsFromPokeAPI] No se pudo conectar")
		return {}

	# Hacer petición
	error = http.request(HTTPClient.METHOD_GET, path, [])
	if error != OK:
		push_error("[ImportItemsFromPokeAPI] Error en request: %d" % error)
		return {}

	# Esperar respuesta
	while http.get_status() == HTTPClient.STATUS_REQUESTING:
		http.poll()
		OS.delay_msec(10)

	# Leer respuesta
	var body := PackedByteArray()
	while http.get_status() == HTTPClient.STATUS_BODY:
		http.poll()
		var chunk := http.read_response_body_chunk()
		if chunk.size() == 0:
			OS.delay_msec(10)
		else:
			body.append_array(chunk)

	var response_code := http.get_response_code()
	if response_code != 200:
		push_error("[ImportItemsFromPokeAPI] HTTP %d para %s" % [response_code, url])
		return {}

	# Parsear JSON
	var json := JSON.new()
	var parse_error := json.parse(body.get_string_from_utf8())
	if parse_error != OK:
		push_error("[ImportItemsFromPokeAPI] Error parseando JSON: %d" % parse_error)
		return {}

	return json.get_data()

func _download_image(url: String) -> Image:
	var http := HTTPClient.new()

	# Parsear URL manualmente
	var url_parts := url.replace("https://", "").replace("http://", "").split("/", false, 1)
	if url_parts.is_empty():
		return null

	var host := url_parts[0]
	var path := "/" + url_parts[1] if url_parts.size() > 1 else "/"

	# Conectar
	var tls_options := TLSOptions.client()
	var error := http.connect_to_host(host, 443, tls_options)
	if error != OK:
		return null

	# Esperar conexión
	while http.get_status() == HTTPClient.STATUS_CONNECTING or http.get_status() == HTTPClient.STATUS_RESOLVING:
		http.poll()
		OS.delay_msec(10)

	if http.get_status() != HTTPClient.STATUS_CONNECTED:
		return null

	# Hacer petición
	error = http.request(HTTPClient.METHOD_GET, path, [])
	if error != OK:
		return null

	# Esperar respuesta
	while http.get_status() == HTTPClient.STATUS_REQUESTING:
		http.poll()
		OS.delay_msec(10)

	# Leer respuesta
	var body := PackedByteArray()
	while http.get_status() == HTTPClient.STATUS_BODY:
		http.poll()
		var chunk := http.read_response_body_chunk()
		if chunk.size() == 0:
			OS.delay_msec(10)
		else:
			body.append_array(chunk)

	var response_code := http.get_response_code()
	if response_code != 200:
		return null

	# Cargar imagen
	var image := Image.new()
	var image_error := image.load_png_from_buffer(body)
	if image_error != OK:
		# Intentar como JPEG
		image_error = image.load_jpg_from_buffer(body)
		if image_error != OK:
			return null

	return image

func _extract_id_from_url(url: String) -> int:
	# Extraer ID de URL como "https://pokeapi.co/api/v2/item/1/"
	var parts := url.split("/")
	for i in range(parts.size() - 1, -1, -1):
		var part := parts[i].trim_suffix("/")
		if part.is_valid_int():
			return int(part)
	return 0

func _create_or_update_item_data(item_id: int, item_data: Dictionary) -> Resource:
	# Obtener nombres y descripción
	var internal_name := item_data.get("name", "") as String
	var display_name_es := _get_name_in_language(item_data, "es")
	var display_name_en := _get_name_in_language(item_data, "en")
	var display_name := display_name_es if display_name_es != "" else display_name_en

	var description_es := _get_description_in_language(item_data, "es")
	var description_en := _get_description_in_language(item_data, "en")
	var description := description_es if description_es != "" else description_en

	# Cargar o crear ItemData
	var file_path := ITEMS_DIR + "/%03d.tres" % item_id
	var item_resource: Resource

	# Cargar el script de ItemData
	var item_data_script := load("res://Scripts/Resources/Classes/ItemData.gd") as GDScript
	if item_data_script == null:
		push_error("[ImportItemsFromPokeAPI] No se pudo cargar ItemData.gd")
		return null

	if ResourceLoader.exists(file_path):
		var loaded := load(file_path)
		if loaded != null and loaded.get_script() == item_data_script:
			item_resource = loaded
			items_updated += 1
		else:
			item_resource = item_data_script.new()
			items_created += 1
	else:
		item_resource = item_data_script.new()
		items_created += 1

	# Actualizar campos básicos
	item_resource.id = item_id
	item_resource.internal_name = internal_name
	item_resource.display_name = display_name
	item_resource.description = description

	# Mapear categoría de PokeAPI a nuestro Pocket
	# IMPORTANTE: Siempre mapear, no verificar si es >= 0 porque puede devolver 0 (ITEMS)
	var pocket := _map_pokeapi_category_to_pocket(item_data, internal_name)
	print("[ImportItemsFromPokeAPI] Item %s (id: %d) -> Pocket: %d" % [internal_name, item_id, pocket])
	item_resource.set("pocket", pocket)

	# Mapear kind según la categoría y el nombre
	var kind := _map_item_to_kind(item_data, internal_name)
	if kind >= 0:
		item_resource.set("kind", kind)

	# Mapear contextos permitidos según el tipo de item
	var allowed_contexts := _map_item_to_allowed_contexts(item_data, internal_name, kind)
	if allowed_contexts >= 0:
		item_resource.set("allowed_contexts", allowed_contexts)

	# Mapear target_type según el tipo de item
	var target_type := _map_item_to_target_type(item_data, internal_name, kind)
	if target_type >= 0:
		item_resource.set("target_type", target_type)

	# Mapear is_consumable y stack_limit
	var consumable_info := _map_item_consumable_info(item_data, internal_name, kind)
	item_resource.set("is_consumable", consumable_info.consumable)
	if consumable_info.stack_limit >= 0:
		item_resource.set("stack_limit", consumable_info.stack_limit)

	# Guardar resource
	var error := ResourceSaver.save(item_resource, file_path)
	if error != OK:
		push_error("[ImportItemsFromPokeAPI] Error guardando %s: %d" % [file_path, error])
		errors.append("Error guardando item %d: %d" % [item_id, error])
		return null

	return item_resource

func _get_name_in_language(item_data: Dictionary, lang: String) -> String:
	var names := item_data.get("names", []) as Array
	for name_entry in names:
		var name_dict := name_entry as Dictionary
		var lang_dict := name_dict.get("language", {}) as Dictionary
		var language := lang_dict.get("name", "") as String
		if language == lang:
			return name_dict.get("name", "") as String
	return ""

func _get_description_in_language(item_data: Dictionary, lang: String) -> String:
	var flavor_text_entries := item_data.get("flavor_text_entries", []) as Array
	# Buscar la primera entrada en el idioma solicitado
	for entry in flavor_text_entries:
		var entry_dict := entry as Dictionary
		var lang_dict := entry_dict.get("language", {}) as Dictionary
		var language := lang_dict.get("name", "") as String
		if language == lang:
			var text := entry_dict.get("text", "") as String
			return text.replace("\n", " ").replace("\f", " ")
	return ""

func _create_atlas_for_items(atlas_index: int, items: Array[Dictionary]) -> void:
	if items.is_empty():
		return

	# Calcular tamaño del atlas (asumiendo iconos de 64x64, ajustable)
	var icon_size := Vector2i(64, 64)
	var items_per_row := 10
	var items_per_col := 10
	var atlas_width := items_per_row * icon_size.x
	var atlas_height := items_per_col * icon_size.y

	# Crear imagen del atlas
	var atlas_image := Image.create(atlas_width, atlas_height, false, Image.FORMAT_RGBA8)
	atlas_image.fill(Color(0, 0, 0, 0))  # Transparente

	# Colocar iconos en el atlas
	var item_regions: Dictionary = {}  # item_id -> Rect2i
	for i in range(items.size()):
		var item_info := items[i] as Dictionary
		var item_id := item_info.get("item_id", 0) as int
		var icon_image := item_info.get("image") as Image

		if icon_image == null:
			continue

		# Redimensionar si es necesario
		if icon_image.get_size() != icon_size:
			icon_image.resize(icon_size.x, icon_size.y, Image.INTERPOLATE_LANCZOS)

		# Calcular posición en el atlas
		var col := i % items_per_row
		var row := int(i / items_per_row)  # División entera explícita
		var pos := Vector2i(col * icon_size.x, row * icon_size.y)

		# Blit icono en el atlas
		atlas_image.blit_rect(icon_image, Rect2i(0, 0, icon_size.x, icon_size.y), pos)

		# Guardar región
		item_regions[item_id] = Rect2i(pos, icon_size)

	# Guardar atlas como PNG
	var atlas_path := ICONS_ATLAS_DIR + "/items_atlas_%03d.png" % atlas_index
	var error := atlas_image.save_png(atlas_path)
	if error != OK:
		push_error("[ImportItemsFromPokeAPI] Error guardando atlas: %s (error %d)" % [atlas_path, error])
		errors.append("Error guardando atlas %d: %d" % [atlas_index, error])
		return

	# Importar el atlas como recurso
	# Godot necesita procesar el archivo, así que forzamos la importación
	EditorInterface.get_resource_filesystem().update_file(atlas_path)

	# Esperar un momento para que Godot procese
	OS.delay_msec(500)

	# Cargar el atlas como Texture2D
	var atlas_texture := load(atlas_path) as Texture2D
	if atlas_texture == null:
		# Si no se puede cargar directamente, crear desde Image
		var texture := ImageTexture.new()
		texture.set_image(atlas_image)
		atlas_texture = texture

		# Guardar como .tres
		var atlas_resource_path := atlas_path.replace(".png", ".tres")
		ResourceSaver.save(atlas_texture, atlas_resource_path)
		atlas_texture = load(atlas_resource_path) as Texture2D

		if atlas_texture == null:
			push_error("[ImportItemsFromPokeAPI] No se pudo cargar atlas: %s" % atlas_path)
			return

	# Asignar AtlasTexture a cada ItemData
	for item_info in items:
		var item_dict := item_info as Dictionary
		var item_id := item_dict.get("item_id", 0) as int
		var file_path := item_dict.get("file_path", "") as String

		if file_path == "":
			file_path = ITEMS_DIR + "/%03d.tres" % item_id

		# Recargar el ItemData desde disco para asegurar que tenemos la versión más reciente
		var item_resource: Resource = null
		if ResourceLoader.exists(file_path):
			item_resource = load(file_path)
		else:
			push_warning("[ImportItemsFromPokeAPI] No existe el archivo para item %d: %s" % [item_id, file_path])
			continue

		if item_resource == null:
			push_warning("[ImportItemsFromPokeAPI] No se pudo cargar item %d desde %s" % [item_id, file_path])
			continue

		var region := item_regions.get(item_id) as Rect2i
		if region == Rect2i():
			push_warning("[ImportItemsFromPokeAPI] No hay región para item %d" % item_id)
			continue

		# Crear AtlasTexture
		var atlas_tex := AtlasTexture.new()
		atlas_tex.atlas = atlas_texture
		atlas_tex.region = region

		# Asignar al ItemData
		item_resource.set("icon", atlas_tex)

		# Guardar ItemData actualizado con ResourceSaver
		var save_error := ResourceSaver.save(item_resource, file_path, ResourceSaver.FLAG_CHANGE_PATH)
		if save_error != OK:
			push_error("[ImportItemsFromPokeAPI] Error guardando item %d con icono: %d" % [item_id, save_error])
			errors.append("Error guardando icono para item %d: %d" % [item_id, save_error])
		else:
			print("[ImportItemsFromPokeAPI] ✓ Icono asignado y guardado para item %d" % item_id)

	print("[ImportItemsFromPokeAPI] Creado atlas %d con %d iconos" % [atlas_index, items.size()])

# ============================================================================
# Funciones de mapeo desde PokeAPI
# ============================================================================

func _map_pokeapi_category_to_pocket(item_data: Dictionary, internal_name: String) -> int:
	# PokeAPI tiene item.category.name que puede ser:
	# "stat-boosts", "effort-drop", "medicine", "other", "in-a-pinch",
	# "picky-healing", "type-protection", "baking-only", "collectibles",
	# "evolution", "spelunking", "held-items", "choice", "effort-training",
	# "bad-held-items", "training", "plates", "species-specific", "type-enhancement",
	# "event-items", "gameplay", "plot-advancement", "unused", "loot", "all-mail",
	# "vitamins", "healing", "pp-recovery", "revival", "status-cures", "mulch",
	# "special-balls", "standard-balls", "dex-completion", "scarves", "all-machines",
	# "flutes", "apricorn-balls", "apricorn-box", "data-cards", "jewels",
	# "miracle-shooter", "mega-stones", "memories"

	var name_lower := internal_name.to_lower()

	# PRIMERO: Verificar el nombre interno (tiene MÁXIMA prioridad)
	# Pokéballs (verificar PRIMERO, antes que cualquier otra cosa)
	if name_lower.contains("ball") and not name_lower.contains("crystal"):
		# Asegurarse de que no es un TM/HM que contenga "ball" en el nombre
		if not (name_lower.begins_with("tm") or name_lower.begins_with("hm")):
			print("[ImportItemsFromPokeAPI] Detectada pokéball por nombre: %s -> BALLS" % internal_name)
			return ItemEnums.Pocket.BALLS

	# TMs/HMs
	if name_lower.begins_with("tm") or name_lower.begins_with("hm"):
		return ItemEnums.Pocket.TM_HM

	# Berries
	if name_lower.contains("berry") or name_lower.contains("baya"):
		return ItemEnums.Pocket.BERRIES

	# SEGUNDO: Verificar la categoría de PokeAPI
	var category := item_data.get("category", {}) as Dictionary
	var category_name := category.get("name", "") as String

	# Mapeo básico por nombre de categoría
	match category_name:
		"standard-balls", "special-balls", "apricorn-balls":
			print("[ImportItemsFromPokeAPI] Detectada pokéball por categoría: %s -> BALLS" % category_name)
			return ItemEnums.Pocket.BALLS
		"medicine", "healing", "status-cures", "pp-recovery", "revival", "vitamins":
			return ItemEnums.Pocket.MEDICINE
		"all-machines", "all-mail":
			return ItemEnums.Pocket.TM_HM
		"berries":
			return ItemEnums.Pocket.BERRIES
		"held-items", "bad-held-items":
			return ItemEnums.Pocket.ITEMS
		"plot-advancement", "event-items", "gameplay":
			return ItemEnums.Pocket.KEY_ITEMS
		"stat-boosts", "effort-training", "training":
			return ItemEnums.Pocket.BATTLE_ITEMS
		_:
			# Por defecto: Items generales
			return ItemEnums.Pocket.ITEMS

func _infer_pocket_from_name(category_name: String, internal_name: String) -> int:
	# Inferir del nombre si la categoría no es clara
	var name_lower := internal_name.to_lower()

	# Pokéballs (verificar PRIMERO, antes que TMs/HMs)
	# Incluye variaciones: "poke-ball", "pokeball", "ultra-ball", etc.
	if name_lower.contains("ball") and not name_lower.contains("crystal"):
		# Asegurarse de que no es un TM/HM que contenga "ball" en el nombre
		if not (name_lower.begins_with("tm") or name_lower.begins_with("hm")):
			return ItemEnums.Pocket.BALLS

	# TMs/HMs (verificar después de balls)
	if name_lower.begins_with("tm") or name_lower.begins_with("hm"):
		return ItemEnums.Pocket.TM_HM

	# Berries
	if name_lower.contains("berry") or name_lower.contains("baya"):
		return ItemEnums.Pocket.BERRIES

	# Por defecto: Items generales
	return ItemEnums.Pocket.ITEMS

func _map_item_to_kind(item_data: Dictionary, internal_name: String) -> int:
	var name_lower := internal_name.to_lower()
	var category := item_data.get("category", {}) as Dictionary
	var category_name := category.get("name", "") as String

	# Pokéballs
	if name_lower.contains("ball") and not name_lower.contains("crystal"):
		return ItemEnums.Kind.POKEBALL

	# TMs/HMs
	if name_lower.begins_with("tm") or name_lower.begins_with("hm"):
		return ItemEnums.Kind.TM_HM

	# Berries
	if name_lower.contains("berry") or category_name == "berries":
		return ItemEnums.Kind.BERRY

	# Medicina/Healing
	match category_name:
		"healing", "status-cures":
			if name_lower.contains("revive") or name_lower.contains("revivir"):
				return ItemEnums.Kind.REVIVE
			elif name_lower.contains("potion") or name_lower.contains("poción"):
				return ItemEnums.Kind.HEAL_HP
			else:
				return ItemEnums.Kind.CURE_STATUS
		"pp-recovery":
			return ItemEnums.Kind.HEAL_PP
		"stat-boosts", "effort-training":
			return ItemEnums.Kind.STAT_BOOST
		"held-items":
			return ItemEnums.Kind.HELD
		"plot-advancement", "event-items":
			return ItemEnums.Kind.KEY
		"evolution":
			return ItemEnums.Kind.EVOLUTION

	# Repelentes
	if name_lower.contains("repel"):
		return ItemEnums.Kind.REPEL

	return ItemEnums.Kind.GENERIC

func _map_item_to_allowed_contexts(item_data: Dictionary, internal_name: String, kind: int) -> int:
	var name_lower := internal_name.to_lower()

	# Pokéballs: SOLO en combate
	if kind == ItemEnums.Kind.POKEBALL or (name_lower.contains("ball") and not name_lower.contains("crystal")):
		return ItemEnums.UseContext.BATTLE

	# TMs/HMs: Solo en party menu (para enseñar movimientos)
	if kind == ItemEnums.Kind.TM_HM:
		return ItemEnums.UseContext.PARTY_MENU

	# Items de combate (X Attack, etc.): Solo en combate
	if kind == ItemEnums.Kind.STAT_BOOST:
		return ItemEnums.UseContext.BATTLE

	# Repelentes: Solo en overworld
	if kind == ItemEnums.Kind.REPEL:
		return ItemEnums.UseContext.OVERWORLD

	# Key items: Solo overworld (generalmente)
	if kind == ItemEnums.Kind.KEY:
		return ItemEnums.UseContext.OVERWORLD

	# Medicina: Overworld y Party Menu (puedes curar fuera y dentro del party)
	if kind == ItemEnums.Kind.HEAL_HP or kind == ItemEnums.Kind.CURE_STATUS or kind == ItemEnums.Kind.REVIVE:
		return ItemEnums.UseContext.OVERWORLD | ItemEnums.UseContext.PARTY_MENU

	# Por defecto: Overworld
	return ItemEnums.UseContext.OVERWORLD

func _map_item_to_target_type(item_data: Dictionary, internal_name: String, kind: int) -> int:
	# Pokéballs: Requieren un Pokémon objetivo (en combate)
	if kind == ItemEnums.Kind.POKEBALL:
		return ItemEnums.TargetType.POKEMON

	# Medicina: Requieren un Pokémon del party
	if kind == ItemEnums.Kind.HEAL_HP or kind == ItemEnums.Kind.CURE_STATUS or kind == ItemEnums.Kind.REVIVE:
		return ItemEnums.TargetType.POKEMON

	# TMs/HMs: Requieren un slot de movimiento
	if kind == ItemEnums.Kind.TM_HM:
		return ItemEnums.TargetType.MOVE_SLOT

	# Repelentes: No requieren objetivo
	if kind == ItemEnums.Kind.REPEL:
		return ItemEnums.TargetType.NONE

	# Por defecto: Ninguno
	return ItemEnums.TargetType.NONE

func _map_item_consumable_info(item_data: Dictionary, internal_name: String, kind: int) -> Dictionary:
	var result := {"consumable": true, "stack_limit": 99}

	# Key items: No consumibles, stack_limit = 1
	if kind == ItemEnums.Kind.KEY:
		result.consumable = false
		result.stack_limit = 1
		return result

	# TMs/HMs: Consumibles pero se pueden usar múltiples veces (stack_limit alto)
	if kind == ItemEnums.Kind.TM_HM:
		result.consumable = true
		result.stack_limit = 99
		return result

	# Pokéballs: Consumibles
	if kind == ItemEnums.Kind.POKEBALL:
		result.consumable = true
		result.stack_limit = 99
		return result

	# Medicina: Consumibles
	if kind == ItemEnums.Kind.HEAL_HP or kind == ItemEnums.Kind.CURE_STATUS or kind == ItemEnums.Kind.REVIVE:
		result.consumable = true
		result.stack_limit = 99
		return result

	# Por defecto: Consumible, stack 99
	return result

func _print_summary() -> void:
	print("\n========================================")
	print("[ImportItemsFromPokeAPI] RESUMEN")
	print("========================================")
	print("Items procesados: %d" % items_processed)
	print("Items creados: %d" % items_created)
	print("Items actualizados: %d" % items_updated)
	print("Iconos descargados: %d" % icons_downloaded)
	print("Items sin icono: %d" % items_without_icon)
	if not errors.is_empty():
		print("\nErrores encontrados: %d" % errors.size())
		for error in errors:
			print("  - %s" % error)
	print("========================================\n")
