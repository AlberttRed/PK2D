@tool
extends Control
class_name ResourceTab

## Clase base reutilizable para pestañas de recursos
## Define la estructura común: buscador, lista, detalle y botones

signal resource_selected(resource: Resource)
signal create_requested()
signal edit_requested(resource: Resource)
signal delete_requested(resource: Resource)
signal duplicate_requested(resource: Resource)

# Referencias a nodos UI (deben ser asignadas desde la escena)
@onready var search_line_edit: LineEdit = $VBoxContainer/SearchContainer/SearchLineEdit
@onready var resource_list: ItemList = $VBoxContainer/ContentContainer/LeftPanel/ResourceList
@onready var detail_panel: Panel = $VBoxContainer/ContentContainer/RightPanel/DetailPanel
var detail_label: Label = null
@onready var create_button: Button = $VBoxContainer/ActionButtons/CreateButton
@onready var edit_button: Button = $VBoxContainer/ActionButtons/EditButton
@onready var delete_button: Button = $VBoxContainer/ActionButtons/DeleteButton
@onready var duplicate_button: Button = $VBoxContainer/ActionButtons/DuplicateButton

var current_resource = null  # Puede ser Resource o Dictionary (metadata)
var all_resources: Array = []  # Puede contener Resource o Dictionary (metadata)
var filtered_resources: Array = []  # Puede contener Resource o Dictionary (metadata)
var resources_loaded: bool = false

## Configuración específica del tipo de recurso (debe ser implementada por subclases)
## Retorna el nombre del tipo de recurso (ej: "Pokémon", "Move", "Item")
func get_resource_type_name() -> String:
	return "Resource"

## Retorna el directorio donde se encuentran los recursos
func get_resource_directory() -> String:
	return ""

## Retorna la clase de script esperada (ej: PokemonData, MoveData, ItemData)
func get_resource_class() -> String:
	return "Resource"

## Carga todos los recursos del tipo correspondiente
func load_resources() -> void:
	print("[ResourceTab] load_resources() llamado para %s" % get_resource_type_name())

	# Si ya están cargados, no volver a cargar
	if resources_loaded:
		print("[ResourceTab] Recursos ya cargados, saltando...")
		return

	all_resources.clear()
	filtered_resources.clear()

	if not resource_list:
		push_error("ResourceTab: resource_list no está disponible")
		return

	resource_list.clear()

	var dir_path := get_resource_directory()
	if dir_path.is_empty():
		push_error("ResourceTab: Directorio no configurado para %s" % get_resource_type_name())
		return

	print("[ResourceTab] Cargando recursos desde: %s" % dir_path)
	print("[ResourceTab] Engine.is_editor_hint(): %s" % Engine.is_editor_hint())

	# Usar DatabaseService si está disponible, o cargar directamente
	if Engine.is_editor_hint():
		_load_resources_from_directory(dir_path)
	else:
		# En runtime, usar DatabaseService
		_load_resources_from_service()

	print("[ResourceTab] Recursos cargados: %d" % all_resources.size())

	resources_loaded = true
	_update_filtered_list("")

## Carga recursos desde un directorio (modo editor)
## Usa nombres de archivo para extraer metadatos sin cargar recursos completos (más rápido)
func _load_resources_from_directory(dir_path: String) -> void:
	var resource_class_name := get_resource_class()

	# Para Pokémon: escanear directorio y extraer metadatos del nombre del archivo
	if dir_path == "res://Resources/Data/Pokemon":
		print("[ResourceTab] Escaneando directorio de Pokémon: %s" % dir_path)

		# Usar el mismo enfoque que DatabaseService (funciona en runtime)
		# En el editor, DirAccess puede funcionar directamente con "res://"
		var dir := DirAccess.open(dir_path)
		if dir == null:
			# Fallback: intentar con ruta del sistema de archivos
			var fs_path := ProjectSettings.globalize_path(dir_path)
			dir = DirAccess.open(fs_path)
			if dir == null:
				push_error("ResourceTab: No se pudo abrir directorio: %s" % dir_path)
				return

		dir.list_dir_begin()
		var file_name := dir.get_next()
		var files_found := 0

		while file_name != "":
			if dir.current_is_dir() or not file_name.ends_with(".tres"):
				file_name = dir.get_next()
				continue

			files_found += 1

			# Extraer ID y nombre del nombre del archivo
			# Formato: "001 - Bulbasaur.tres" o "001.tres" (compatibilidad)
			var file_base := file_name.get_basename()
			var parts := file_base.split(" - ", false, 1)

			var id_str := parts[0].strip_edges()
			var name_str := ""
			if parts.size() >= 2:
				name_str = parts[1].strip_edges()

			if id_str.is_valid_int():
				var id := int(id_str)
				if id >= 0 and id < 152:
					var file_path := dir_path + "/" + file_name

					# Si tenemos el nombre del archivo, crear metadata sin cargar
					if name_str != "":
						var metadata := {
							"id": id,
							"name": name_str,
							"path": file_path,
							"file_name": file_name
						}
						all_resources.append(metadata)
						if all_resources.size() <= 5:  # Debug: mostrar los primeros
							print("[ResourceTab] Añadido metadata: ID %d - %s" % [id, name_str])
					else:
						# Fallback: cargar recurso si no tenemos nombre en el archivo
						print("[ResourceTab] Archivo sin nombre en formato, cargando recurso: %s" % file_name)
						_try_load_resource(file_path, resource_class_name)
				else:
					print("[ResourceTab] ID fuera de rango: %d (archivo: %s)" % [id, file_name])
			else:
				print("[ResourceTab] ID no válido en archivo: %s" % file_name)

			file_name = dir.get_next()

		dir.list_dir_end()
		print("[ResourceTab] Archivos encontrados: %d, recursos añadidos: %d" % [files_found, all_resources.size()])

		# Ordenar por ID
		if all_resources.size() > 0:
			all_resources.sort_custom(_sort_by_id)

		return

	# Para Moves: DESHABILITADO TEMPORALMENTE (solo probamos Pokémon)
	# if dir_path == "res://Resources/Data/Moves":
	# 	for i in range(1, 622):
	# 		var path := "%s/%03d.tres" % [dir_path, i]
	# 		_try_load_resource(path, resource_class_name)
	# 	return

	# Para Items: DESHABILITADO TEMPORALMENTE (solo probamos Pokémon)
	# if dir_path == "res://Resources/Data/Items":
	# 	for i in range(1, 1000):
	# 		var path := "%s/%03d.tres" % [dir_path, i]
	# 		_try_load_resource(path, resource_class_name)
	# 	return

	# Fallback: intentar usar DirAccess si está disponible (solo en editor)
	if Engine.is_editor_hint():
		var dir := DirAccess.open(dir_path)
		if dir != null:
			dir.list_dir_begin()
			var file_name := dir.get_next()

			while file_name != "":
				if dir.current_is_dir():
					file_name = dir.get_next()
					continue

				if not file_name.ends_with(".tres"):
					file_name = dir.get_next()
					continue

				var file_path := dir_path + "/" + file_name
				_try_load_resource(file_path, resource_class_name)
				file_name = dir.get_next()

			dir.list_dir_end()
		else:
			push_warning("ResourceTab: No se pudo abrir directorio: %s" % dir_path)

	# Ordenar por ID si existe (solo si hay recursos)
	if all_resources.size() > 0:
		all_resources.sort_custom(_sort_by_id)

## Intenta cargar un recurso y verificar que sea del tipo correcto
func _try_load_resource(path: String, expected_class: String) -> void:
	if not ResourceLoader.exists(path):
		return

	var resource := load(path) as Resource
	if resource == null:
		return

	# Verificar que sea del tipo correcto
	var script := resource.get_script()
	if script == null:
		return

	# Intentar obtener el nombre de clase global
	var script_class: String = script.get_global_name()

	# Si no tiene nombre global, intentar verificar por el path del script
	if script_class.is_empty():
		var script_path: String = script.resource_path
		if script_path != "":
			# Extraer el nombre de clase del path (ej: "PokemonData.gd" -> "PokemonData")
			var file_name: String = script_path.get_file().get_basename()
			if file_name == expected_class:
				all_resources.append(resource)
				return

	# Verificar por nombre de clase global
	if script_class == expected_class:
		all_resources.append(resource)
	else:
		# Debug: ver qué clase tiene realmente
		if all_resources.size() < 5:  # Solo mostrar los primeros para no saturar
			print("[ResourceTab] Recurso %s tiene clase '%s', esperado '%s'" % [path, script_class, expected_class])

## Carga recursos desde DatabaseService (modo runtime, no usado en editor)
func _load_resources_from_service() -> void:
	# No se usa en editor, pero se deja para consistencia
	pass

## Ordena recursos por ID (puede ser Resource o Dictionary)
func _sort_by_id(a, b) -> bool:
	var a_id := _get_resource_id(a)
	var b_id := _get_resource_id(b)
	return a_id < b_id

## Obtiene el ID de un recurso (puede ser Resource o Dictionary con metadata)
func _get_resource_id(resource_or_metadata) -> int:
	if resource_or_metadata is Dictionary:
		return resource_or_metadata.get("id", 0)
	if resource_or_metadata is Resource:
		if resource_or_metadata.has_method("get"):
			var id_value: Variant = resource_or_metadata.get("id")
			if id_value != null:
				return int(id_value)
	return 0

## Obtiene el nombre para mostrar de un recurso (puede ser Resource o Dictionary con metadata)
func _get_resource_display_name(resource_or_metadata) -> String:
	# Si es metadata (Dictionary), usar el nombre del archivo
	if resource_or_metadata is Dictionary:
		return resource_or_metadata.get("name", "Unknown")

	# Si es Resource, intentar diferentes campos de nombre
	if resource_or_metadata is Resource:
		if resource_or_metadata.has_method("get"):
			var display_name: Variant = resource_or_metadata.get("display_name")
			if display_name != null and display_name != "":
				return str(display_name)
			var name_field: Variant = resource_or_metadata.get("Name")
			if name_field != null and name_field != "":
				return str(name_field)
			var internal_name: Variant = resource_or_metadata.get("internal_name")
			if internal_name != null and internal_name != "":
				return str(internal_name)

	return "Resource #%d" % _get_resource_id(resource_or_metadata)

## Filtra la lista según el texto de búsqueda
func _update_filtered_list(search_text: String) -> void:
	if not resource_list:
		push_warning("ResourceTab: resource_list no está disponible en _update_filtered_list")
		return

	filtered_resources.clear()
	resource_list.clear()

	print("[ResourceTab] Actualizando lista filtrada. Recursos totales: %d, texto búsqueda: '%s'" % [all_resources.size(), search_text])

	var search_lower := search_text.to_lower()

	for resource_or_metadata in all_resources:
		var matches := false

		# Buscar por ID
		var resource_id := _get_resource_id(resource_or_metadata)
		if str(resource_id).contains(search_text):
			matches = true

		# Buscar por nombre
		if not matches:
			var display_name := _get_resource_display_name(resource_or_metadata)
			if display_name.to_lower().contains(search_lower):
				matches = true

		# Buscar por internal_name (solo si es Resource, no metadata)
		if not matches and resource_or_metadata is Resource and resource_or_metadata.has_method("get"):
			var internal_name: Variant = resource_or_metadata.get("internal_name")
			if internal_name != null and str(internal_name).to_lower().contains(search_lower):
				matches = true

		if matches or search_text.is_empty():
			filtered_resources.append(resource_or_metadata)
			var list_text := "%d - %s" % [resource_id, _get_resource_display_name(resource_or_metadata)]
			resource_list.add_item(list_text)

	print("[ResourceTab] Recursos filtrados: %d" % filtered_resources.size())

	# Si hay recursos, seleccionar el primero
	if resource_list.get_item_count() > 0:
		resource_list.select(0)
		_on_resource_list_item_selected(0)

## Actualiza el panel de detalle con la información del recurso seleccionado
func _update_detail_panel(resource: Resource) -> void:
	current_resource = resource

	if resource == null:
		if detail_label:
			detail_label.text = "Ningún recurso seleccionado"
		if edit_button:
			edit_button.disabled = true
		if delete_button:
			delete_button.disabled = true
		if duplicate_button:
			duplicate_button.disabled = true
		return

	# Habilitar botones
	edit_button.disabled = false
	delete_button.disabled = false
	duplicate_button.disabled = false

	# Construir texto de detalle
	var detail_text := ""
	detail_text += "Tipo: %s\n" % get_resource_type_name()
	detail_text += "ID: %d\n" % _get_resource_id(resource)

	var display_name := _get_resource_display_name(resource)
	detail_text += "Nombre: %s\n" % display_name

	# Intentar obtener internal_name
	if resource.has_method("get"):
		var internal_name: Variant = resource.get("internal_name")
		if internal_name != null and internal_name != "":
			detail_text += "Nombre interno: %s\n" % str(internal_name)

		# Intentar obtener path del archivo
		var resource_path := resource.resource_path
		if resource_path != "":
			detail_text += "\nPath: %s" % resource_path

	if detail_label:
		detail_label.text = detail_text

## Señales y callbacks
func _ready() -> void:
	print("[ResourceTab] _ready() llamado para %s" % get_resource_type_name())
	var script_obj = get_script()
	print("[ResourceTab] Script path: %s" % (script_obj.resource_path if script_obj else "null"))
	print("[ResourceTab] Tiene método load_resources: %s" % has_method("load_resources"))

	# Intentar obtener detail_label si existe (solo para pestañas que lo tienen)
	detail_label = get_node_or_null("VBoxContainer/ContentContainer/RightPanel/DetailPanel/DetailLabel")

	# Esperar varios frames para asegurar que todos los nodos estén listos
	await get_tree().process_frame
	await get_tree().process_frame

	if search_line_edit:
		search_line_edit.text_changed.connect(_on_search_text_changed)

	if resource_list:
		resource_list.item_selected.connect(_on_resource_list_item_selected)

	if create_button:
		create_button.pressed.connect(_on_create_button_pressed)

	if edit_button:
		edit_button.pressed.connect(_on_edit_button_pressed)
		edit_button.disabled = true

	if delete_button:
		delete_button.pressed.connect(_on_delete_button_pressed)
		delete_button.disabled = true

	if duplicate_button:
		duplicate_button.pressed.connect(_on_duplicate_button_pressed)
		duplicate_button.disabled = true

	# Cargar recursos al inicializar
	# Esperar un frame más para asegurar que resource_list esté disponible
	await get_tree().process_frame
	print("[ResourceTab] Después de esperar, resource_list disponible: %s" % (resource_list != null))
	print("[ResourceTab] Después de esperar, tiene método load_resources: %s" % has_method("load_resources"))
	if resource_list:  # Solo cargar si el nodo está disponible
		print("[ResourceTab] Llamando a load_resources() desde _ready()...")
		load_resources()
	else:
		push_error("ResourceTab: resource_list no está disponible en _ready()")

func _on_search_text_changed(new_text: String) -> void:
	_update_filtered_list(new_text)

func _on_resource_list_item_selected(index: int) -> void:
	if index < 0 or index >= filtered_resources.size():
		return

	var resource_or_metadata = filtered_resources[index]

	# Si es metadata, cargar el recurso completo solo cuando se selecciona
	var resource: Resource = null
	if resource_or_metadata is Dictionary:
		var path: String = resource_or_metadata.get("path", "")
		if path != "" and ResourceLoader.exists(path):
			resource = load(path) as Resource
	else:
		resource = resource_or_metadata as Resource

	if resource:
		_update_detail_panel(resource)
		resource_selected.emit(resource)

func _on_create_button_pressed() -> void:
	print("[DatabaseEditor] Crear nuevo %s (placeholder)" % get_resource_type_name())
	create_requested.emit()

func _on_edit_button_pressed() -> void:
	if current_resource == null:
		return

	# Asegurarse de que tenemos el recurso completo, no solo metadata
	var resource: Resource = null
	if current_resource is Dictionary:
		var path: String = current_resource.get("path", "")
		if path != "" and ResourceLoader.exists(path):
			resource = load(path) as Resource
		else:
			return
	elif current_resource is Resource:
		resource = current_resource

	if resource != null:
		print("[DatabaseEditor] Editar %s ID %d (placeholder)" % [get_resource_type_name(), _get_resource_id(resource)])
		edit_requested.emit(resource)

func _on_delete_button_pressed() -> void:
	if current_resource == null:
		return

	# Asegurarse de que tenemos el recurso completo, no solo metadata
	var resource: Resource = null
	if current_resource is Dictionary:
		var path: String = current_resource.get("path", "")
		if path != "" and ResourceLoader.exists(path):
			resource = load(path) as Resource
		else:
			return
	elif current_resource is Resource:
		resource = current_resource

	if resource != null:
		print("[DatabaseEditor] Eliminar %s ID %d (placeholder)" % [get_resource_type_name(), _get_resource_id(resource)])
		delete_requested.emit(resource)

func _on_duplicate_button_pressed() -> void:
	if current_resource == null:
		return

	# Asegurarse de que tenemos el recurso completo, no solo metadata
	var resource: Resource = null
	if current_resource is Dictionary:
		var path: String = current_resource.get("path", "")
		if path != "" and ResourceLoader.exists(path):
			resource = load(path) as Resource
		else:
			return
	elif current_resource is Resource:
		resource = current_resource

	if resource is Resource:
		print("[DatabaseEditor] Duplicar %s ID %d (placeholder)" % [get_resource_type_name(), _get_resource_id(resource)])
		duplicate_requested.emit(resource)
