@tool
extends Window

## Ventana principal del Database Editor
## Contiene pestañas para gestionar diferentes tipos de recursos
## También puede funcionar en modo "picker" para seleccionar recursos desde otros editores

## Tipos de recursos soportados en el picker
## Extensible: Para añadir nuevos tipos (ej: TRAINER), agregar aquí y en _configure_picker_tabs
enum ResourceType {
	POKEMON,
	MOVE,
	ITEM,
	# TRAINER,  # Futuro: descomentar cuando se implemente
}

## Señal emitida cuando se confirma una selección en modo picker
signal resource_selected(result: ResourcePickerResult)
## Señal emitida cuando se cancela el picker
signal picker_cancelled

@onready var tab_container: TabContainer = $VBoxContainer/TabContainer
@onready var pokemon_tab: Control = $VBoxContainer/TabContainer/PokemonTab
@onready var move_tab: Control = $VBoxContainer/TabContainer/MoveTab
@onready var item_tab: Control = $VBoxContainer/TabContainer/ItemTab

var pokemon_editor_scene: PackedScene = null
var current_pokemon_editor: Window = null
var move_editor_scene: PackedScene = null
var current_move_editor: Window = null
var item_editor_scene: PackedScene = null
var current_item_editor: Window = null

# Modo picker
var is_picker_mode: bool = false
var picker_resource_type: ResourceType = ResourceType.POKEMON
var selected_resource: Resource = null
var selected_resource_id: int = 0
var selected_resource_path: String = ""
var selected_display_name: String = ""

func _ready() -> void:
	title = "Database Editor"
	unresizable = false
	always_on_top = false

	# Configurar tamaño mínimo
	min_size = Vector2i(800, 600)

	# Cargar escenas de editores
	pokemon_editor_scene = load("res://addons/database_editor/pokemon_editor_window.tscn")
	move_editor_scene = load("res://addons/database_editor/move_editor_window.tscn")
	item_editor_scene = load("res://addons/database_editor/item_editor_window.tscn")

	# Conectar señal de cierre
	close_requested.connect(_on_close_requested)

	# Configurar botones inferiores (se configurarán según el modo)
	_setup_bottom_buttons()

	# Conectar señal de cambio de pestaña para cargar recursos solo cuando se activa
	if tab_container:
		tab_container.tab_selected.connect(_on_tab_selected)
		# Establecer títulos de los tabs
		tab_container.set_tab_title(0, "Pokémon")
		tab_container.set_tab_title(1, "Movimientos")
		tab_container.set_tab_title(2, "Items")

	# Esperar varios frames para que todos los nodos y scripts estén completamente listos
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_connect_tab_signals()

	# Cargar solo la pestaña inicial activa (Pokémon)
	# Esperar más tiempo para que los scripts se carguen completamente
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	if tab_container:
		var initial_tab := tab_container.current_tab
		print("[DatabaseEditor] Pestaña inicial: %d" % initial_tab)
		# Llamar directamente después de esperar
		await get_tree().process_frame
		_on_tab_selected(initial_tab)
	else:
		print("[DatabaseEditor] ERROR: tab_container es null")

## Conecta las señales de las pestañas después de que estén listas
func _connect_tab_signals() -> void:
	# Conectar señales de las pestañas directamente
	# Las señales están definidas en resource_tab.gd y heredadas por las pestañas
	# NOTA: Para Pokémon, no conectamos las señales del ResourceTab porque usamos
	# el sistema directo de botones en _load_pokemon_resources_directly
	# if pokemon_tab:
	#	_connect_tab_signals_to_callbacks(pokemon_tab,
	#		_on_pokemon_create_requested,
	#		_on_pokemon_edit_requested,
	#		_on_pokemon_delete_requested,
	#		_on_pokemon_duplicate_requested
	#	)

	if move_tab:
		_connect_tab_signals_to_callbacks(move_tab,
			_on_move_create_requested,
			_on_move_edit_requested,
			_on_move_delete_requested,
			_on_move_duplicate_requested
		)

	if item_tab:
		_connect_tab_signals_to_callbacks(item_tab,
			_on_item_create_requested,
			_on_item_edit_requested,
			_on_item_delete_requested,
			_on_item_duplicate_requested
		)

## Conecta las señales de una pestaña a sus callbacks
func _connect_tab_signals_to_callbacks(tab: Control, create_cb: Callable, edit_cb: Callable, delete_cb: Callable, duplicate_cb: Callable) -> void:
	if not tab:
		return

	# Verificar que el script esté cargado y las señales disponibles
	if not tab.get_script():
		push_error("DatabaseEditor: La pestaña %s no tiene script cargado" % tab.name)
		return

	# Conectar señales usando connect() con nombre de señal como string
	# Esto es más seguro que acceder directamente a las propiedades de señal
	_safe_connect_signal(tab, "create_requested", create_cb)
	_safe_connect_signal(tab, "edit_requested", edit_cb)
	_safe_connect_signal(tab, "delete_requested", delete_cb)
	_safe_connect_signal(tab, "duplicate_requested", duplicate_cb)

## Conecta una señal de forma segura si existe y no está ya conectada
func _safe_connect_signal(tab: Control, signal_name: String, callback: Callable) -> void:
	if not tab.has_signal(signal_name):
		return

	# Verificar si ya está conectada
	var signal_obj := tab.get(signal_name)
	if signal_obj == null:
		return

	if not (signal_obj is Signal):
		return

	var signal_connections := (signal_obj as Signal).get_connections()
	for conn in signal_connections:
		if conn["callable"] == callback:
			return  # Ya está conectada

	# Conectar la señal
	tab.connect(signal_name, callback)


## Callbacks para Pokémon
func _on_pokemon_create_requested() -> void:
	_open_pokemon_editor_create()

func _on_pokemon_edit_requested(resource: Resource) -> void:
	if not resource:
		_show_warning("No hay ningún Pokémon seleccionado")
		return

	var pokemon_data := resource as PokemonData
	if not pokemon_data:
		_show_warning("El recurso seleccionado no es un PokemonData válido")
		return

	_open_pokemon_editor_edit(pokemon_data)

func _on_pokemon_delete_requested(resource: Resource) -> void:
	print("[DatabaseEditor] Eliminar Pokémon: %s" % resource.resource_path)
	# TODO: Implementar eliminación

func _on_pokemon_duplicate_requested(resource: Resource) -> void:
	if not resource:
		_show_warning("No hay ningún Pokémon seleccionado")
		return

	var pokemon_data := resource as PokemonData
	if not pokemon_data:
		_show_warning("El recurso seleccionado no es un PokemonData válido")
		return

	_open_pokemon_editor_duplicate(pokemon_data)

## Abre el editor de Pokémon en modo Create
func _open_pokemon_editor_create() -> void:
	if not pokemon_editor_scene:
		push_error("DatabaseEditor: No se pudo cargar pokemon_editor_window.tscn")
		return

	# Cerrar editor anterior si existe
	if current_pokemon_editor and is_instance_valid(current_pokemon_editor):
		current_pokemon_editor.queue_free()

	await get_tree().process_frame

	var editor := pokemon_editor_scene.instantiate()
	if not editor:
		push_error("DatabaseEditor: No se pudo instanciar PokemonEditorWindow")
		return

	# Añadir como hijo del DatabaseEditor para que sea modal
	add_child(editor)
	current_pokemon_editor = editor

	# Abrir en modo Create primero
	if editor.has_method("open_create"):
		editor.open_create(_refresh_pokemon_tab)

	# Conectar señales después de que se haya abierto
	await get_tree().process_frame
	await get_tree().process_frame
	_connect_pokemon_editor_signals(editor)

## Abre el editor de Pokémon en modo Edit
func _open_pokemon_editor_edit(pokemon_data: PokemonData) -> void:
	if not pokemon_editor_scene:
		push_error("DatabaseEditor: No se pudo cargar pokemon_editor_window.tscn")
		return

	# Si ya hay un editor abierto, cerrarlo primero
	if current_pokemon_editor and is_instance_valid(current_pokemon_editor):
		print("[DatabaseEditor] Editor ya está abierto, cerrando el anterior...")
		current_pokemon_editor.queue_free()
		await get_tree().process_frame

	await get_tree().process_frame

	var editor := pokemon_editor_scene.instantiate()
	if not editor:
		push_error("DatabaseEditor: No se pudo instanciar PokemonEditorWindow")
		return

	# Añadir como hijo del DatabaseEditor para que sea modal
	add_child(editor)
	current_pokemon_editor = editor

	# Abrir en modo Edit primero
	if editor.has_method("open_edit"):
		editor.open_edit(pokemon_data, _refresh_pokemon_tab)

	# Conectar señales después de que se haya abierto
	await get_tree().process_frame
	await get_tree().process_frame
	_connect_pokemon_editor_signals(editor)

## Abre el editor de Pokémon en modo Duplicate
func _open_pokemon_editor_duplicate(pokemon_data: PokemonData) -> void:
	if not pokemon_editor_scene:
		push_error("DatabaseEditor: No se pudo cargar pokemon_editor_window.tscn")
		return

	# Cerrar editor anterior si existe
	if current_pokemon_editor and is_instance_valid(current_pokemon_editor):
		current_pokemon_editor.queue_free()

	await get_tree().process_frame

	var editor := pokemon_editor_scene.instantiate()
	if not editor:
		push_error("DatabaseEditor: No se pudo instanciar PokemonEditorWindow")
		return

	# Añadir como hijo del DatabaseEditor para que sea modal
	add_child(editor)
	current_pokemon_editor = editor

	# Abrir en modo Duplicate primero
	if editor.has_method("open_duplicate"):
		editor.open_duplicate(pokemon_data, _refresh_pokemon_tab)

	# Conectar señales después de que se haya abierto
	await get_tree().process_frame
	await get_tree().process_frame
	_connect_pokemon_editor_signals(editor)

## Callback cuando se guarda en el editor de Pokémon
## Conecta las señales del editor de Pokémon
func _connect_pokemon_editor_signals(editor: Window) -> void:
	if not editor or not is_instance_valid(editor):
		return

	# Esperar varios frames para asegurar que el script esté completamente cargado
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	# Intentar conectar señales directamente
	# Usar call_deferred para asegurar que se ejecute después de que todo esté listo
	call_deferred("_do_connect_signals", editor)

## Conecta las señales directamente (llamado de forma diferida)
func _do_connect_signals(editor: Window) -> void:
	if not editor or not is_instance_valid(editor):
		return

	# Intentar conectar directamente sin verificar
	# Si falla, simplemente no se conectarán (pero no debería fallar si el script está cargado)
	var script := editor.get_script()
	if script:
		# Verificar que el script tiene las señales
		var signals_list: Array = script.get_script_signal_list()
		var has_saved := false
		var has_cancelled := false

		for sig in signals_list:
			if sig.name == "saved":
				has_saved = true
			elif sig.name == "cancelled":
				has_cancelled = true

		if has_saved and has_cancelled:
			# Conectar las señales
			editor.saved.connect(_on_pokemon_editor_saved)
			editor.cancelled.connect(_on_pokemon_editor_cancelled)
		else:
			push_warning("[DatabaseEditor] Las señales no están disponibles en el script")

func _on_pokemon_editor_saved(pokemon_data: PokemonData, was_new: bool) -> void:
	print("[DatabaseEditor] Pokémon guardado: %s (nuevo: %s)" % [pokemon_data.resource_path, was_new])
	current_pokemon_editor = null

	# Si estamos en modo picker, refrescar y seleccionar el recurso guardado
	if is_picker_mode and picker_resource_type == ResourceType.POKEMON:
		_refresh_pokemon_tab()
		# Esperar a que se cargue la lista y luego seleccionar
		await get_tree().process_frame
		await get_tree().process_frame
		_set_initial_selection(pokemon_data.id)

## Callback cuando se cancela el editor de Pokémon
func _on_pokemon_editor_cancelled() -> void:
	current_pokemon_editor = null


## Callback cuando se cambia de pestaña
func _on_tab_selected(tab_index: int) -> void:
	print("[DatabaseEditor] _on_tab_selected llamado con índice: %d" % tab_index)

	if not tab_container:
		push_error("[DatabaseEditor] tab_container es null")
		return

	# Obtener la pestaña actual directamente del TabContainer
	var current_tab_node := tab_container.get_child(tab_index)
	if not current_tab_node:
		push_error("[DatabaseEditor] No se pudo obtener pestaña en índice %d" % tab_index)
		return

	print("[DatabaseEditor] Pestaña obtenida: %s (tipo: %s)" % [current_tab_node.name, current_tab_node.get_class()])

	# Verificar si el script está cargado
	var script := current_tab_node.get_script()
	if script:
		print("[DatabaseEditor] Script encontrado: %s" % script.resource_path)
	else:
		push_error("[DatabaseEditor] El nodo no tiene script adjunto!")
		return

	# Cargar recursos solo de la pestaña activa
	match tab_index:
		0:  # Pokémon
			print("[DatabaseEditor] Intentando cargar Pokémon...")
			_load_pokemon_resources_directly(current_tab_node)
		1:  # Moves
			print("[DatabaseEditor] Intentando cargar Moves...")
			_load_move_resources_directly(current_tab_node)
		2:  # Items
			if item_tab:
				_load_item_resources_directly(current_tab_node)

## Refresca la pestaña de Pokémon
## Carga recursos de Pokémon directamente sin depender de que el script se ejecute
func _load_pokemon_resources_directly(tab_node: Control) -> void:
	print("[DatabaseEditor] Cargando recursos de Pokémon directamente...")

	# Obtener el ItemList directamente del nodo
	var resource_list: ItemList = tab_node.get_node_or_null("VBoxContainer/ContentContainer/LeftPanel/ResourceList")
	if not resource_list:
		push_error("[DatabaseEditor] No se encontró ResourceList en PokemonTab")
		return

	resource_list.clear()

	# Cargar recursos desde el directorio
	var dir_path := "res://Resources/Data/Pokemon"
	var filesystem_path := ProjectSettings.globalize_path(dir_path)
	var dir := DirAccess.open(filesystem_path)
	if dir == null:
		# Fallback: intentar con ruta directa
		dir = DirAccess.open(dir_path)
		if dir == null:
			push_error("[DatabaseEditor] No se pudo abrir directorio: %s" % dir_path)
			return

	var all_resources: Array = []
	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if dir.current_is_dir() or not file_name.ends_with(".tres"):
			file_name = dir.get_next()
			continue

		# Extraer ID y nombre del nombre del archivo
		var file_base := file_name.get_basename()
		var parts := file_base.split(" - ", false, 1)

		var id_str := parts[0].strip_edges()
		var name_str := ""
		if parts.size() >= 2:
			name_str = parts[1].strip_edges()

		# Si no tiene el formato "XXX - Nombre", intentar extraer solo el ID
		if not id_str.is_valid_int() and file_base.is_valid_int():
			id_str = file_base

		# Si aún no es válido, intentar extraer números del inicio
		if not id_str.is_valid_int():
			var id_match := file_base.split(" ")[0]
			if id_match.is_valid_int():
				id_str = id_match

		if id_str.is_valid_int():
			var id := int(id_str)
			# Cargar el recurso para obtener el nombre si no está en el nombre del archivo
			if name_str == "":
				var file_path := dir_path + "/" + file_name
				if ResourceLoader.exists(file_path):
					var resource := load(file_path) as PokemonData
					if resource:
						if resource.Name != "":
							name_str = resource.Name
						elif resource.internal_name != "":
							name_str = resource.internal_name

			if name_str == "":
				name_str = "Pokémon #%d" % id

			var file_path := dir_path + "/" + file_name
			var metadata := {
				"id": id,
				"name": name_str,
				"path": file_path,
				"file_name": file_name
			}
			all_resources.append(metadata)

		file_name = dir.get_next()

	dir.list_dir_end()

	# Ordenar por ID
	all_resources.sort_custom(func(a, b): return int(a.get("id", 0)) < int(b.get("id", 0)))

	# Guardar metadata para poder accederla cuando se seleccione un item
	tab_node.set_meta("pokemon_metadata", all_resources)
	tab_node.set_meta("pokemon_metadata_all", all_resources)  # Guardar todos los recursos sin filtrar

	# Conectar señal de selección usando lambda que capture tab_node
	print("[DatabaseEditor] Conectando señal item_selected para tab_node: %s" % tab_node.name)
	var connection_result = resource_list.item_selected.connect(func(idx: int):
		print("[DatabaseEditor] Señal item_selected recibida con índice: %d" % idx)
		_on_pokemon_item_selected(idx, tab_node)
	)
	if connection_result != OK:
		push_error("[DatabaseEditor] Error al conectar señal item_selected: %d" % connection_result)
	else:
		print("[DatabaseEditor] Señal item_selected conectada correctamente")

	# Conectar señal de búsqueda
	var search_line_edit: LineEdit = tab_node.get_node_or_null("VBoxContainer/SearchContainer/SearchLineEdit")
	if search_line_edit:
		if not search_line_edit.text_changed.is_connected(_on_pokemon_search_text_changed.bind(tab_node)):
			search_line_edit.text_changed.connect(_on_pokemon_search_text_changed.bind(tab_node))

	# Conectar botones de acción
	var create_button: Button = tab_node.get_node_or_null("VBoxContainer/ActionButtons/CreateButton")
	var edit_button: Button = tab_node.get_node_or_null("VBoxContainer/ActionButtons/EditButton")
	var delete_button: Button = tab_node.get_node_or_null("VBoxContainer/ActionButtons/DeleteButton")
	var duplicate_button: Button = tab_node.get_node_or_null("VBoxContainer/ActionButtons/DuplicateButton")
	var rename_button: Button = tab_node.get_node_or_null("VBoxContainer/ActionButtons/RenameButton")

	if create_button:
		if not create_button.pressed.is_connected(_on_pokemon_create_requested):
			create_button.pressed.connect(_on_pokemon_create_requested)
	if edit_button:
		if not edit_button.pressed.is_connected(_on_pokemon_edit_button_pressed.bind(tab_node)):
			edit_button.pressed.connect(_on_pokemon_edit_button_pressed.bind(tab_node))
	if delete_button:
		if not delete_button.pressed.is_connected(_on_pokemon_delete_button_pressed.bind(tab_node)):
			delete_button.pressed.connect(_on_pokemon_delete_button_pressed.bind(tab_node))
	if duplicate_button:
		if not duplicate_button.pressed.is_connected(_on_pokemon_duplicate_button_pressed.bind(tab_node)):
			duplicate_button.pressed.connect(_on_pokemon_duplicate_button_pressed.bind(tab_node))
	if rename_button:
		if not rename_button.pressed.is_connected(_on_pokemon_rename_button_pressed.bind(tab_node)):
			rename_button.pressed.connect(_on_pokemon_rename_button_pressed.bind(tab_node))

	# Mostrar todos los recursos inicialmente
	_update_pokemon_list(tab_node, "")

	print("[DatabaseEditor] Recursos de Pokémon cargados: %d" % all_resources.size())


## Callback cuando se selecciona un item en la lista de Pokémon
func _on_pokemon_item_selected(index: int, tab_node: Control) -> void:
	print("[DatabaseEditor] _on_pokemon_item_selected llamado con índice: %d" % index)
	var resource_list: ItemList = tab_node.get_node_or_null("VBoxContainer/ContentContainer/LeftPanel/ResourceList")
	var detail_container: VBoxContainer = tab_node.get_node_or_null("VBoxContainer/ContentContainer/RightPanel/DetailPanel/ScrollContainer/DetailContainer")

	if not resource_list:
		push_error("[DatabaseEditor] No se encontró ResourceList")
		return
	if not detail_container:
		push_error("[DatabaseEditor] No se encontró DetailContainer")
		return

	# Obtener metadata guardada
	var metadata_array: Array = tab_node.get_meta("pokemon_metadata", [])
	print("[DatabaseEditor] Metadata array size: %d" % metadata_array.size())
	if index < 0 or index >= metadata_array.size():
		push_error("[DatabaseEditor] Índice fuera de rango: %d (size: %d)" % [index, metadata_array.size()])
		return

	var metadata: Dictionary = metadata_array[index]
	var file_path: String = metadata.get("path", "")

	# Limpiar el contenedor (excepto el placeholder si existe)
	print("[DatabaseEditor] Limpiando contenedor, hijos actuales: %d" % detail_container.get_child_count())
	var children = detail_container.get_children()
	for child in children:
		detail_container.remove_child(child)
		child.queue_free()

	# Cargar el recurso completo
	if file_path == "" or not ResourceLoader.exists(file_path):
		_add_detail_label(detail_container, "Error: No se pudo cargar el recurso", true)
		return

	var resource := load(file_path) as Resource
	if not resource or not (resource is PokemonData):
		_add_detail_label(detail_container, "Error: El recurso no es un PokemonData válido", true)
		return

	var pokemon_data := resource as PokemonData

	# Guardar el recurso seleccionado para que los botones puedan usarlo
	tab_node.set_meta("selected_pokemon_data", pokemon_data)

	# Si estamos en modo picker, actualizar la selección
	if is_picker_mode and picker_resource_type == ResourceType.POKEMON:
		var display_name: String = pokemon_data.Name if pokemon_data.Name != "" else pokemon_data.internal_name
		_update_picker_selection(pokemon_data, pokemon_data.id, file_path, display_name)

	# Crear secciones con Labels individuales
	_add_section_header(detail_container, "INFORMACIÓN DEL POKÉMON")

	_add_detail_row(detail_container, "ID", str(pokemon_data.id))
	if pokemon_data.Name != "":
		_add_detail_row(detail_container, "Nombre", pokemon_data.Name)
	if pokemon_data.internal_name != "":
		_add_detail_row(detail_container, "Nombre interno", pokemon_data.internal_name)

	# Tipos
	if pokemon_data.type_a:
		var type_a_name: String = ""
		if pokemon_data.type_a.has_method("get"):
			var type_name: Variant = pokemon_data.type_a.get("Name")
			if type_name != null:
				type_a_name = str(type_name)
		_add_detail_row(detail_container, "Tipo A", type_a_name if type_a_name != "" else "N/A")

	if pokemon_data.type_b:
		var type_b_name: String = ""
		if pokemon_data.type_b.has_method("get"):
			var type_name: Variant = pokemon_data.type_b.get("Name")
			if type_name != null:
				type_b_name = str(type_name)
		_add_detail_row(detail_container, "Tipo B", type_b_name if type_b_name != "" else "N/A")

	_add_section_header(detail_container, "ESTADÍSTICAS BASE")
	_add_detail_row(detail_container, "HP", str(pokemon_data.hp_base))
	_add_detail_row(detail_container, "Ataque", str(pokemon_data.attack_base))
	_add_detail_row(detail_container, "Defensa", str(pokemon_data.defense_base))
	_add_detail_row(detail_container, "Ataque Especial", str(pokemon_data.special_attack_base))
	_add_detail_row(detail_container, "Defensa Especial", str(pokemon_data.special_defense_base))
	_add_detail_row(detail_container, "Velocidad", str(pokemon_data.speed_base))
	_add_detail_row(detail_container, "Total", str(pokemon_data.total_base))

	_add_section_header(detail_container, "INFORMACIÓN ADICIONAL")
	_add_detail_row(detail_container, "Altura", "%.2f m" % pokemon_data.height)
	_add_detail_row(detail_container, "Peso", "%.2f kg" % pokemon_data.weight)
	_add_detail_row(detail_container, "Experiencia base", str(pokemon_data.base_exprience))
	_add_detail_row(detail_container, "Tasa de captura", str(pokemon_data.capture_rate))
	_add_detail_row(detail_container, "Felicidad base", str(pokemon_data.base_happiness))

	# Descripción
	if pokemon_data.description != "":
		_add_section_header(detail_container, "DESCRIPCIÓN")
		_add_detail_label(detail_container, pokemon_data.description, false)

	# Ruta del archivo
	_add_section_header(detail_container, "ARCHIVO")
	_add_detail_label(detail_container, file_path, false)

## Añade una fila de información (label + valor)
func _add_detail_row(container: VBoxContainer, label_text: String, value_text: String) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	container.add_child(hbox)

	var label := Label.new()
	label.text = label_text + ":"
	label.custom_minimum_size.x = 150
	label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	hbox.add_child(label)

	var value := Label.new()
	value.text = value_text
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hbox.add_child(value)

## Añade un header de sección
func _add_section_header(container: VBoxContainer, text: String) -> void:
	var separator := HSeparator.new()
	container.add_child(separator)

	var header := Label.new()
	header.text = "=== " + text + " ==="
	header.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	header.add_theme_font_size_override("font_size", 14)
	container.add_child(header)

## Añade un label de texto completo (para descripción, etc.)
func _add_detail_label(container: VBoxContainer, text: String, is_error: bool = false) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if is_error:
		label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	container.add_child(label)

## Actualiza la lista de Pokémon según el texto de búsqueda
func _update_pokemon_list(tab_node: Control, search_text: String) -> void:
	print("[DatabaseEditor] _update_pokemon_list llamado con search_text: '%s'" % search_text)
	var resource_list: ItemList = tab_node.get_node_or_null("VBoxContainer/ContentContainer/LeftPanel/ResourceList")
	if not resource_list:
		push_error("[DatabaseEditor] No se encontró ResourceList en _update_pokemon_list")
		return

	# Obtener todos los recursos
	var all_metadata: Array = tab_node.get_meta("pokemon_metadata_all", [])

	resource_list.clear()

	var search_lower := search_text.to_lower()
	var filtered_metadata: Array = []

	# Filtrar y añadir a la lista
	for metadata in all_metadata:
		var matches := false

		# Buscar por ID
		var id: int = metadata.get("id", 0)
		if str(id).contains(search_text):
			matches = true

		# Buscar por nombre
		if not matches:
			var name: String = metadata.get("name", "")
			if name.to_lower().contains(search_lower):
				matches = true

		# Si coincide o el texto de búsqueda está vacío, añadir a la lista
		if matches or search_text.is_empty():
			var display_name: String = metadata.get("name", "Unknown")
			resource_list.add_item("%d - %s" % [id, display_name])
			filtered_metadata.append(metadata)

	# Guardar metadata filtrada para la selección
	tab_node.set_meta("pokemon_metadata", filtered_metadata)

	# Limpiar selección anterior y recurso seleccionado
	tab_node.remove_meta("selected_pokemon_data")
	var detail_container: VBoxContainer = tab_node.get_node_or_null("VBoxContainer/ContentContainer/RightPanel/DetailPanel/ScrollContainer/DetailContainer")
	if detail_container:
		for child in detail_container.get_children():
			child.queue_free()

## Callback cuando cambia el texto de búsqueda
func _on_pokemon_search_text_changed(new_text: String, tab_node: Control) -> void:
	_update_pokemon_list(tab_node, new_text)

func _refresh_pokemon_tab() -> void:
	print("[DatabaseEditor] _refresh_pokemon_tab() llamado")
	if pokemon_tab:
		print("[DatabaseEditor] Recargando lista de Pokémon...")
		_load_pokemon_resources_directly(pokemon_tab)
	else:
		print("[DatabaseEditor] ERROR: pokemon_tab es null")

	# No refrescar el explorador aquí si ya se refrescó antes (para evitar doble refresco)
	# _refresh_filesystem() se llama explícitamente donde se necesita


## Callbacks para los botones de la pestaña de Pokémon
func _on_pokemon_edit_button_pressed(tab_node: Control) -> void:
	var pokemon_data: PokemonData = tab_node.get_meta("selected_pokemon_data", null)
	if not pokemon_data:
		_show_warning("No hay ningún Pokémon seleccionado")
		return
	_open_pokemon_editor_edit(pokemon_data)

func _on_pokemon_delete_button_pressed(tab_node: Control) -> void:
	var pokemon_data: PokemonData = tab_node.get_meta("selected_pokemon_data", null)
	if not pokemon_data:
		_show_warning("No hay ningún Pokémon seleccionado")
		return

	var file_path: String = pokemon_data.resource_path
	if file_path == "" or not ResourceLoader.exists(file_path):
		_show_warning("No se pudo encontrar el archivo del Pokémon")
		return

	# Obtener el nombre del Pokémon para el mensaje
	var pokemon_name := ""
	if pokemon_data.Name != "":
		pokemon_name = pokemon_data.Name
	elif pokemon_data.internal_name != "":
		pokemon_name = pokemon_data.internal_name
	else:
		pokemon_name = "Pokémon #%d" % pokemon_data.id

	# Mostrar diálogo de confirmación
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "¿Estás seguro de que quieres eliminar el recurso '%s'?\n\nEsta acción no se puede deshacer." % pokemon_name
	dialog.ok_button_text = "Eliminar"
	dialog.cancel_button_text = "Cancelar"

	# Añadir como hijo de esta ventana para que sea modal
	add_child(dialog)

	dialog.confirmed.connect(func():
		_delete_pokemon_file_async(file_path, tab_node)
		dialog.queue_free()
	)

	dialog.canceled.connect(func():
		dialog.queue_free()
	)

	dialog.popup_centered()

## Elimina un archivo de Pokémon (versión async)
func _delete_pokemon_file_async(file_path: String, tab_node: Control) -> void:
	_delete_pokemon_file(file_path, tab_node)
	# Esperar dos frames para asegurar que el archivo se haya eliminado completamente
	await get_tree().process_frame
	await get_tree().process_frame
	print("[DatabaseEditor] Refrescando lista después de eliminar...")
	_refresh_pokemon_tab()

## Elimina un archivo de Pokémon
func _delete_pokemon_file(file_path: String, tab_node: Control) -> void:
	var filesystem_path := ProjectSettings.globalize_path(file_path)
	var dir := DirAccess.open(filesystem_path.get_base_dir())

	if not dir:
		# Fallback: intentar con ruta directa
		var dir_path := file_path.get_base_dir()
		dir = DirAccess.open(ProjectSettings.globalize_path(dir_path))
		if not dir:
			_show_warning("No se pudo abrir el directorio para eliminar el archivo")
			return

	var file_name := file_path.get_file()
	var error := dir.remove(file_name)

	if error != OK:
		_show_warning("Error al eliminar el archivo: %s" % error_string(error))
		return

	print("[DatabaseEditor] Archivo eliminado: %s" % file_path)

	# Refrescar el explorador de archivos de Godot
	_refresh_filesystem()

	# Limpiar la selección
	tab_node.remove_meta("selected_pokemon_data")

	# Limpiar el panel de detalles
	var detail_container: VBoxContainer = tab_node.get_node_or_null("VBoxContainer/ContentContainer/RightPanel/DetailPanel/ScrollContainer/DetailContainer")
	if detail_container:
		var children = detail_container.get_children()
		for child in children:
			detail_container.remove_child(child)
			child.queue_free()

	# Deseleccionar en la lista
	var resource_list: ItemList = tab_node.get_node_or_null("VBoxContainer/ContentContainer/LeftPanel/ResourceList")
	if resource_list:
		resource_list.deselect_all()

	# El refresco se hará en _delete_pokemon_file_async usando await

func _on_pokemon_duplicate_button_pressed(tab_node: Control) -> void:
	var pokemon_data: PokemonData = tab_node.get_meta("selected_pokemon_data", null)
	if not pokemon_data:
		_show_warning("No hay ningún Pokémon seleccionado")
		return
	_open_pokemon_editor_duplicate(pokemon_data)

func _on_pokemon_rename_button_pressed(tab_node: Control) -> void:
	var pokemon_data: PokemonData = tab_node.get_meta("selected_pokemon_data", null)
	if not pokemon_data:
		_show_warning("No hay ningún Pokémon seleccionado")
		return

	var file_path: String = pokemon_data.resource_path
	if file_path == "" or not ResourceLoader.exists(file_path):
		_show_warning("No se pudo encontrar el archivo del Pokémon")
		return

	# Obtener el nombre actual del Pokémon
	var current_name := ""
	if pokemon_data.Name != "":
		current_name = pokemon_data.Name
	elif pokemon_data.internal_name != "":
		current_name = pokemon_data.internal_name
	else:
		current_name = "Pokémon #%d" % pokemon_data.id

	# Crear diálogo para introducir el nuevo nombre
	var dialog := AcceptDialog.new()
	dialog.title = "Cambiar nombre del archivo"

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)

	var label := Label.new()
	label.text = "Nuevo nombre para el archivo:"
	vbox.add_child(label)

	var line_edit := LineEdit.new()
	line_edit.text = current_name
	line_edit.select_all_on_focus = true
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(line_edit)

	dialog.add_child(vbox)

	# Añadir como hijo de esta ventana para que sea modal
	add_child(dialog)

	var confirmed := false
	dialog.confirmed.connect(func():
		var new_name := line_edit.text.strip_edges()
		if new_name != "":
			_rename_pokemon_file(file_path, new_name, tab_node)
			confirmed = true
		dialog.queue_free()
	)

	dialog.canceled.connect(func():
		dialog.queue_free()
	)

	# Conectar Enter en el LineEdit para confirmar
	line_edit.text_submitted.connect(func(_text: String):
		dialog.confirmed.emit()
	)

	dialog.popup_centered(Vector2i(400, 150))
	line_edit.grab_focus()

## Renombra un archivo de Pokémon
func _rename_pokemon_file(old_path: String, new_name: String, tab_node: Control) -> void:
	# Limpiar el nombre para que sea válido como nombre de archivo
	var clean_name := new_name.strip_edges()
	clean_name = clean_name.replace("/", "-").replace("\\", "-").replace(":", "-")
	clean_name = clean_name.replace("*", "").replace("?", "").replace("\"", "")
	clean_name = clean_name.replace("<", "").replace(">", "").replace("|", "")

	if clean_name == "":
		_show_warning("El nombre no puede estar vacío")
		return

	# Cargar el recurso para obtener el ID
	var pokemon_data: PokemonData = load(old_path) as PokemonData
	if not pokemon_data:
		_show_warning("No se pudo cargar el recurso del Pokémon")
		return

	# Construir el nuevo nombre del archivo
	var dir_path := old_path.get_base_dir()
	var new_file_name := "%03d - %s.tres" % [pokemon_data.id, clean_name]
	var new_path := dir_path + "/" + new_file_name

	# Si el nuevo archivo ya existe, avisar
	if ResourceLoader.exists(new_path) and new_path != old_path:
		_show_warning("Ya existe un archivo con ese nombre")
		return

	# Renombrar el archivo
	var filesystem_dir := ProjectSettings.globalize_path(dir_path)
	var dir := DirAccess.open(filesystem_dir)
	if not dir:
		_show_warning("No se pudo abrir el directorio para renombrar el archivo")
		return

	var old_file_name := old_path.get_file()
	var error := dir.rename(old_file_name, new_file_name)

	if error != OK:
		_show_warning("Error al renombrar el archivo: %s" % error_string(error))
		return

	print("[DatabaseEditor] Archivo renombrado: %s -> %s" % [old_path, new_path])

	# Actualizar el resource_path del recurso si está cargado
	if pokemon_data:
		pokemon_data.resource_path = new_path
		ResourceSaver.save(pokemon_data, new_path)

	# Refrescar el explorador de archivos de Godot
	_refresh_filesystem()

	# Refrescar la lista
	await get_tree().process_frame
	_refresh_pokemon_tab()

## Refresca el explorador de archivos de Godot
func _refresh_filesystem() -> void:
	var filesystem = EditorInterface.get_resource_filesystem()
	if filesystem:
		filesystem.scan()
		print("[DatabaseEditor] Explorador de archivos refrescado")

## Muestra un mensaje de advertencia
func _show_warning(message: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.dialog_text = message
	dialog.title = "Aviso"
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered()
	await dialog.confirmed
	dialog.queue_free()

## Callbacks para Moves
func _on_move_create_requested() -> void:
	print("[DatabaseEditor] Crear nuevo Move (placeholder)")

func _on_move_edit_requested(resource: Resource) -> void:
	print("[DatabaseEditor] Editar Move: %s" % resource.resource_path)
	# TODO: Abrir MoveEditor

func _on_move_delete_requested(resource: Resource) -> void:
	print("[DatabaseEditor] Eliminar Move: %s" % resource.resource_path)
	# TODO: Implementar eliminación

func _on_move_duplicate_requested(resource: Resource) -> void:
	print("[DatabaseEditor] Duplicar Move: %s" % resource.resource_path)
	# TODO: Implementar duplicación

## Callbacks para Items
func _on_item_create_requested() -> void:
	print("[DatabaseEditor] Crear nuevo Item")
	_open_item_editor_create()

func _on_item_edit_requested(resource: Resource) -> void:
	print("[DatabaseEditor] Editar Item: %s" % resource.resource_path)
	if resource is ItemData:
		_open_item_editor_edit(resource as ItemData)

func _on_item_delete_requested(resource: Resource) -> void:
	print("[DatabaseEditor] Eliminar Item: %s" % resource.resource_path)
	if resource is ItemData:
		_show_delete_item_confirmation_dialog(resource as ItemData, item_tab)

func _on_item_duplicate_requested(resource: Resource) -> void:
	print("[DatabaseEditor] Duplicar Item: %s" % resource.resource_path)
	if resource is ItemData:
		_open_item_editor_duplicate(resource as ItemData)

## Manejo del cierre de ventana
func _on_close_requested() -> void:
	if is_picker_mode:
		# En modo picker, emitir señal de cancelación
		picker_cancelled.emit()
	queue_free()

## Configura los botones inferiores según el modo (normal o picker)
func _setup_bottom_buttons() -> void:
	var bottom_buttons = get_node_or_null("VBoxContainer/BottomButtons")
	if not bottom_buttons:
		return

	# Limpiar botones existentes
	for child in bottom_buttons.get_children():
		child.queue_free()

	if is_picker_mode:
		# Modo picker: botones Seleccionar y Cancelar
		var select_button = Button.new()
		select_button.text = "Seleccionar"
		select_button.custom_minimum_size = Vector2(100, 0)
		select_button.disabled = true  # Deshabilitado inicialmente hasta que se seleccione un recurso
		select_button.pressed.connect(_on_picker_select_pressed)
		bottom_buttons.add_child(select_button)

		var cancel_button = Button.new()
		cancel_button.text = "Cancelar"
		cancel_button.custom_minimum_size = Vector2(100, 0)
		cancel_button.pressed.connect(_on_picker_cancel_pressed)
		bottom_buttons.add_child(cancel_button)

		# Guardar referencia al botón de seleccionar para habilitar/deshabilitar
		select_button.name = "SelectButton"

		# Ocultar todos los botones de acción en modo picker
		_hide_action_buttons_in_picker_mode()
	else:
		# Modo normal: botón Cerrar
		var close_button = Button.new()
		close_button.text = "Cerrar"
		close_button.custom_minimum_size = Vector2(100, 0)
		close_button.pressed.connect(_on_close_requested)
		bottom_buttons.add_child(close_button)
		close_button.name = "CloseButton"

## Abre el DatabaseEditor en modo picker
## @param resource_type: Tipo de recurso a seleccionar (ResourceType.POKEMON, MOVE, ITEM)
## @param initial_selection: ID o path del recurso preseleccionado (opcional)
func open_picker_mode(resource_type: ResourceType, initial_selection = null) -> void:
	is_picker_mode = true
	picker_resource_type = resource_type

	# Configurar título según el tipo
	match resource_type:
		ResourceType.POKEMON:
			title = "Seleccionar Pokémon"
		ResourceType.MOVE:
			title = "Seleccionar Movimiento"
		ResourceType.ITEM:
			title = "Seleccionar Item"

	# Esperar a que _ready() termine antes de modificar las pestañas
	call_deferred("_configure_picker_tabs", resource_type)
	call_deferred("_setup_bottom_buttons")

	# Si hay selección inicial, seleccionarla después de que todo esté listo
	if initial_selection != null:
		call_deferred("_set_initial_selection", initial_selection)

## Configura las pestañas para el modo picker (llamado deferred)
func _configure_picker_tabs(resource_type: ResourceType) -> void:
	if not tab_container:
		return

	# Ocultar pestañas no relevantes
	for i in range(tab_container.get_tab_count()):
		match resource_type:
			ResourceType.POKEMON:
				tab_container.set_tab_hidden(i, i != 0)
			ResourceType.MOVE:
				tab_container.set_tab_hidden(i, i != 1)
			ResourceType.ITEM:
				tab_container.set_tab_hidden(i, i != 2)

	# Activar la pestaña correcta
	match resource_type:
		ResourceType.POKEMON:
			tab_container.current_tab = 0
			_on_tab_selected(0)
		ResourceType.MOVE:
			tab_container.current_tab = 1
			_on_tab_selected(1)
		ResourceType.ITEM:
			tab_container.current_tab = 2
			_on_tab_selected(2)

	# Ocultar botones de acción en modo picker
	_hide_action_buttons_in_picker_mode()

## Establece la selección inicial en modo picker
func _set_initial_selection(selection) -> void:
	if selection == null:
		return

	# Esperar a que las pestañas estén listas
	await get_tree().process_frame
	await get_tree().process_frame

	var tab_node: Control = null
	var resource_list: ItemList = null

	# Obtener la pestaña y lista correctas según el tipo
	match picker_resource_type:
		ResourceType.POKEMON:
			tab_node = pokemon_tab
		ResourceType.MOVE:
			tab_node = move_tab
		ResourceType.ITEM:
			tab_node = item_tab

	if not tab_node:
		return

	resource_list = tab_node.get_node_or_null("VBoxContainer/ContentContainer/LeftPanel/ResourceList")
	if not resource_list:
		return

	# Buscar el recurso en la lista
	var target_id: int = -1
	if typeof(selection) == TYPE_INT:
		target_id = selection
	elif typeof(selection) == TYPE_STRING:
		# Si es un path, intentar cargar y obtener el ID
		if ResourceLoader.exists(selection):
			var resource = load(selection)
			if resource and "id" in resource:
				target_id = resource.id

	if target_id < 0:
		return

	# Buscar en la lista por ID
	var metadata_key := ""
	match picker_resource_type:
		ResourceType.POKEMON:
			metadata_key = "pokemon_metadata"
		ResourceType.MOVE:
			metadata_key = "move_metadata"
		ResourceType.ITEM:
			metadata_key = "item_metadata"

	var metadata_array: Array = tab_node.get_meta(metadata_key, [])
	for i in range(metadata_array.size()):
		var metadata: Dictionary = metadata_array[i]
		if metadata.get("id", -1) == target_id:
			# Seleccionar en la lista
			resource_list.select(i)
			resource_list.emit_signal("item_selected", i)
			break

## Callback cuando se presiona "Seleccionar" en modo picker
func _on_picker_select_pressed() -> void:
	if not selected_resource:
		# No hay selección, mostrar aviso o deshabilitar botón
		return

	# Crear resultado
	var result = ResourcePickerResult.new(
		selected_resource_id,
		selected_resource_path,
		selected_display_name,
		_get_resource_type_string(),
		selected_resource
	)

	# Emitir señal
	resource_selected.emit(result)

	# Cerrar ventana
	queue_free()

## Callback cuando se presiona "Cancelar" en modo picker
func _on_picker_cancel_pressed() -> void:
	picker_cancelled.emit()
	queue_free()

## Obtiene el string del tipo de recurso actual
func _get_resource_type_string() -> String:
	match picker_resource_type:
		ResourceType.POKEMON:
			return "POKEMON"
		ResourceType.MOVE:
			return "MOVE"
		ResourceType.ITEM:
			return "ITEM"
	return ""

## Actualiza la selección cuando el usuario selecciona un recurso en la lista
func _update_picker_selection(resource: Resource, resource_id: int, resource_path: String, display_name: String) -> void:
	selected_resource = resource
	selected_resource_id = resource_id
	selected_resource_path = resource_path
	selected_display_name = display_name

	# Habilitar/deshabilitar botón de seleccionar
	var select_button = get_node_or_null("VBoxContainer/BottomButtons/SelectButton")
	if select_button:
		select_button.disabled = (selected_resource == null)

## Deshabilita los botones Eliminar en modo picker (opcional según AC-02)
## Oculta todos los botones de acción en modo picker (Crear, Editar, Eliminar, Duplicar, Renombrar)
func _hide_action_buttons_in_picker_mode() -> void:
	if not is_picker_mode:
		return

	var tab_node: Control = null
	match picker_resource_type:
		ResourceType.POKEMON:
			tab_node = pokemon_tab
		ResourceType.MOVE:
			tab_node = move_tab
		ResourceType.ITEM:
			tab_node = item_tab

	if tab_node:
		# Ocultar el contenedor completo de botones de acción
		var action_buttons_container: HBoxContainer = tab_node.get_node_or_null("VBoxContainer/ActionButtons")
		if action_buttons_container:
			action_buttons_container.visible = false

## ============================================
## FUNCIONES PARA MOVES
## ============================================

## Carga recursos de Moves directamente
func _load_move_resources_directly(tab_node: Control) -> void:
	print("[DatabaseEditor] Cargando recursos de Moves directamente...")

	# Obtener el ItemList directamente del nodo
	var resource_list: ItemList = tab_node.get_node_or_null("VBoxContainer/ContentContainer/LeftPanel/ResourceList")
	if not resource_list:
		push_error("[DatabaseEditor] No se encontró ResourceList en MoveTab")
		return

	resource_list.clear()

	# Cargar recursos desde el directorio
	var dir_path := "res://Resources/Data/Moves"
	var filesystem_path := ProjectSettings.globalize_path(dir_path)
	var dir := DirAccess.open(filesystem_path)
	if dir == null:
		push_error("[DatabaseEditor] No se pudo abrir directorio: %s" % dir_path)
		return

	var all_resources: Array = []
	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if dir.current_is_dir() or not file_name.ends_with(".tres"):
			file_name = dir.get_next()
			continue

		# Extraer ID y nombre del nombre del archivo
		var file_base := file_name.get_basename()
		var parts := file_base.split(" - ", false, 1)

		var id_str := parts[0].strip_edges()
		var name_str := ""
		if parts.size() >= 2:
			name_str = parts[1].strip_edges()

		# Si no tiene el formato "XXX - Nombre", intentar extraer solo el ID
		if not id_str.is_valid_int() and file_base.is_valid_int():
			id_str = file_base

		# Si aún no es válido, intentar extraer números del inicio
		if not id_str.is_valid_int():
			var id_match := file_base.split(" ")[0]
			if id_match.is_valid_int():
				id_str = id_match

		if id_str.is_valid_int():
			var id := int(id_str)
			# Cargar el recurso para obtener el nombre si no está en el nombre del archivo
			if name_str == "":
				var file_path := dir_path + "/" + file_name
				if ResourceLoader.exists(file_path):
					var resource := load(file_path) as MoveData
					if resource:
						if resource.Name != "":
							name_str = resource.Name
						elif resource.internal_name != "":
							name_str = resource.internal_name

			if name_str == "":
				name_str = "Move #%d" % id

			var file_path := dir_path + "/" + file_name
			var metadata := {
				"id": id,
				"name": name_str,
				"path": file_path,
				"file_name": file_name
			}
			all_resources.append(metadata)

		file_name = dir.get_next()

	dir.list_dir_end()

	# Ordenar por ID
	all_resources.sort_custom(func(a, b): return int(a.get("id", 0)) < int(b.get("id", 0)))

	# Guardar metadata para poder accederla cuando se seleccione un item
	tab_node.set_meta("move_metadata", all_resources)
	tab_node.set_meta("move_metadata_all", all_resources)

	# Conectar señal de selección
	var connection_result = resource_list.item_selected.connect(func(idx: int):
		_on_move_item_selected(idx, tab_node)
	)
	if connection_result != OK:
		push_error("[DatabaseEditor] Error al conectar señal item_selected para Moves: %d" % connection_result)

	# Conectar señal de búsqueda
	var search_line_edit: LineEdit = tab_node.get_node_or_null("VBoxContainer/SearchContainer/SearchLineEdit")
	if search_line_edit:
		if not search_line_edit.text_changed.is_connected(_on_move_search_text_changed.bind(tab_node)):
			search_line_edit.text_changed.connect(_on_move_search_text_changed.bind(tab_node))

	# Conectar botones de acción
	var create_button: Button = tab_node.get_node_or_null("VBoxContainer/ActionButtons/CreateButton")
	var edit_button: Button = tab_node.get_node_or_null("VBoxContainer/ActionButtons/EditButton")
	var delete_button: Button = tab_node.get_node_or_null("VBoxContainer/ActionButtons/DeleteButton")
	var duplicate_button: Button = tab_node.get_node_or_null("VBoxContainer/ActionButtons/DuplicateButton")

	if create_button:
		if not create_button.pressed.is_connected(_on_move_create_button_pressed.bind(tab_node)):
			create_button.pressed.connect(_on_move_create_button_pressed.bind(tab_node))
	if edit_button:
		if not edit_button.pressed.is_connected(_on_move_edit_button_pressed.bind(tab_node)):
			edit_button.pressed.connect(_on_move_edit_button_pressed.bind(tab_node))
	if delete_button:
		if not delete_button.pressed.is_connected(_on_move_delete_button_pressed.bind(tab_node)):
			delete_button.pressed.connect(_on_move_delete_button_pressed.bind(tab_node))
	if duplicate_button:
		if not duplicate_button.pressed.is_connected(_on_move_duplicate_button_pressed.bind(tab_node)):
			duplicate_button.pressed.connect(_on_move_duplicate_button_pressed.bind(tab_node))

	# Mostrar todos los recursos inicialmente
	_update_move_list(tab_node, "")

	print("[DatabaseEditor] Recursos de Moves cargados: %d" % all_resources.size())

## Callback cuando se selecciona un item en la lista de Moves
func _on_move_item_selected(index: int, tab_node: Control) -> void:
	var resource_list: ItemList = tab_node.get_node_or_null("VBoxContainer/ContentContainer/LeftPanel/ResourceList")
	var detail_container: VBoxContainer = tab_node.get_node_or_null("VBoxContainer/ContentContainer/RightPanel/DetailPanel/ScrollContainer/DetailContainer")

	if not resource_list:
		push_error("[DatabaseEditor] No se encontró ResourceList")
		return
	if not detail_container:
		# Intentar encontrar recursivamente o crearlo
		var right_panel = tab_node.get_node_or_null("VBoxContainer/ContentContainer/RightPanel")
		if not right_panel:
			push_error("[DatabaseEditor] No se encontró RightPanel en MoveTab")
			return

		var detail_panel = right_panel.get_node_or_null("DetailPanel")
		if not detail_panel:
			push_error("[DatabaseEditor] No se encontró DetailPanel en MoveTab")
			return

		# Buscar ScrollContainer
		var scroll_container: ScrollContainer = null
		for child in detail_panel.get_children():
			if child is ScrollContainer:
				scroll_container = child
				break

		# Si no hay ScrollContainer, crearlo
		if not scroll_container:
			scroll_container = ScrollContainer.new()
			scroll_container.set_anchors_preset(Control.PRESET_FULL_RECT)
			scroll_container.offset_left = 8
			scroll_container.offset_top = 8
			scroll_container.offset_right = -8
			scroll_container.offset_bottom = -8
			detail_panel.add_child(scroll_container)

		# Buscar DetailContainer dentro del ScrollContainer
		for child in scroll_container.get_children():
			if child is VBoxContainer:
				detail_container = child
				break

		# Si no hay DetailContainer, crearlo
		if not detail_container:
			detail_container = VBoxContainer.new()
			detail_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			detail_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
			detail_container.add_theme_constant_override("separation", 8)
			scroll_container.add_child(detail_container)

	# Obtener metadata guardada
	var metadata_array: Array = tab_node.get_meta("move_metadata", [])
	if index < 0 or index >= metadata_array.size():
		return

	var metadata: Dictionary = metadata_array[index]
	var file_path: String = metadata.get("path", "")

	if file_path == "" or not ResourceLoader.exists(file_path):
		return

	# Cargar el recurso completo
	var move_data = load(file_path) as MoveData
	if not move_data:
		return

	# Guardar el recurso seleccionado para los botones de acción
	tab_node.set_meta("selected_move_data", move_data)

	# Si estamos en modo picker, actualizar la selección
	if is_picker_mode and picker_resource_type == ResourceType.MOVE:
		var display_name: String = move_data.Name if move_data.Name != "" else move_data.internal_name
		_update_picker_selection(move_data, move_data.id, file_path, display_name)

	# Limpiar el contenedor (igual que en PokemonTab)
	print("[DatabaseEditor] Limpiando DetailContainer, hijos actuales: %d" % detail_container.get_child_count())
	var children = detail_container.get_children()
	for child in children:
		print("[DatabaseEditor] Eliminando hijo: %s (tipo: %s)" % [child.name, child.get_class()])
		detail_container.remove_child(child)
		child.queue_free()
	print("[DatabaseEditor] Hijos después de limpiar: %d" % detail_container.get_child_count())

	# Mostrar información del movimiento
	_add_section_header(detail_container, "Información General")
	_add_detail_row(detail_container, "ID", str(move_data.id))
	_add_detail_row(detail_container, "Nombre interno", move_data.internal_name if move_data.internal_name else "")
	_add_detail_row(detail_container, "Nombre", move_data.Name if move_data.Name else "")
	_add_detail_row(detail_container, "Descripción", move_data.description if move_data.description else "")

	_add_section_header(detail_container, "Tipo y Categoría")
	var type_name := "None"
	# Usar type_id directamente (optimización)
	if move_data.type_id > 0:
		var type_data: TypeData = null
		# En runtime, usar DatabaseService
		if Engine.has_singleton("DatabaseService") and not Engine.is_editor_hint():
			type_data = DatabaseService.get_type(move_data.type_id) as TypeData
		# En editor, cargar directamente desde archivo
		else:
			var type_path := "res://Resources/Data/Types/%02d.tres" % move_data.type_id
			if ResourceLoader.exists(type_path):
				type_data = load(type_path) as TypeData
		if type_data:
			type_name = type_data.Name
	# Compatibilidad: si type_id es 0 pero existe type (Resource), usarlo
	elif move_data.type != null and move_data.type is TypeData:
		type_name = (move_data.type as TypeData).Name
	_add_detail_row(detail_container, "Tipo", type_name)
	var damage_class_names := ["None", "Estado", "Físico", "Especial"]
	var damage_class_name: String = damage_class_names[move_data.damage_class_id] if move_data.damage_class_id < damage_class_names.size() else "Unknown"
	_add_detail_row(detail_container, "Categoría", damage_class_name)

	_add_section_header(detail_container, "Estadísticas")
	_add_detail_row(detail_container, "Poder", str(move_data.power))
	_add_detail_row(detail_container, "Precisión", str(move_data.accuracy))
	_add_detail_row(detail_container, "PP", str(move_data.pp))

	# Habilitar botones de acción
	var edit_button: Button = tab_node.get_node_or_null("VBoxContainer/ActionButtons/EditButton")
	var delete_button: Button = tab_node.get_node_or_null("VBoxContainer/ActionButtons/DeleteButton")
	var duplicate_button: Button = tab_node.get_node_or_null("VBoxContainer/ActionButtons/DuplicateButton")
	if edit_button:
		edit_button.disabled = false
	if delete_button:
		delete_button.disabled = false
	if duplicate_button:
		duplicate_button.disabled = false

## Callback cuando cambia el texto de búsqueda de Moves
func _on_move_search_text_changed(new_text: String, tab_node: Control) -> void:
	_update_move_list(tab_node, new_text)

## Actualiza la lista de Moves según el texto de búsqueda
func _update_move_list(tab_node: Control, search_text: String) -> void:
	var resource_list: ItemList = tab_node.get_node_or_null("VBoxContainer/ContentContainer/LeftPanel/ResourceList")
	if not resource_list:
		return

	# Obtener todos los recursos
	var all_metadata: Array = tab_node.get_meta("move_metadata_all", [])

	resource_list.clear()

	var search_lower := search_text.to_lower()
	var filtered_metadata: Array = []

	# Filtrar y añadir a la lista
	for metadata in all_metadata:
		var matches := false

		# Buscar por ID
		var id: int = metadata.get("id", 0)
		if str(id).contains(search_text):
			matches = true

		# Buscar por nombre
		if not matches:
			var name: String = metadata.get("name", "")
			if name.to_lower().contains(search_lower):
				matches = true

		# Si coincide o el texto de búsqueda está vacío, añadir a la lista
		if matches or search_text.is_empty():
			var display_name: String = metadata.get("name", "Unknown")
			resource_list.add_item("%d - %s" % [id, display_name])
			filtered_metadata.append(metadata)

	# Guardar metadata filtrada para la selección
	tab_node.set_meta("move_metadata", filtered_metadata)

	# Limpiar selección anterior y recurso seleccionado
	tab_node.remove_meta("selected_move_data")
	var detail_container: VBoxContainer = tab_node.get_node_or_null("VBoxContainer/ContentContainer/RightPanel/DetailPanel/ScrollContainer/DetailContainer")
	if detail_container:
		for child in detail_container.get_children():
			child.queue_free()

## Abre el editor de Moves en modo Create
func _on_move_create_button_pressed(tab_node: Control) -> void:
	_open_move_editor_create()

## Abre el editor de Moves en modo Edit
func _on_move_edit_button_pressed(tab_node: Control) -> void:
	var move_data: MoveData = tab_node.get_meta("selected_move_data", null)
	if not move_data:
		_show_warning("No hay ningún movimiento seleccionado")
		return
	_open_move_editor_edit(move_data)

## Abre el editor de Moves en modo Duplicate
func _on_move_duplicate_button_pressed(tab_node: Control) -> void:
	var move_data: MoveData = tab_node.get_meta("selected_move_data", null)
	if not move_data:
		_show_warning("No hay ningún movimiento seleccionado")
		return
	_open_move_editor_duplicate(move_data)

## Abre el editor de Moves en modo Delete
func _on_move_delete_button_pressed(tab_node: Control) -> void:
	var move_data: MoveData = tab_node.get_meta("selected_move_data", null)
	if not move_data:
		_show_warning("No hay ningún movimiento seleccionado")
		return
	_show_delete_move_confirmation_dialog(move_data, tab_node)

## Abre el editor de Moves en modo Create
func _open_move_editor_create() -> void:
	if not move_editor_scene:
		push_error("DatabaseEditor: No se pudo cargar move_editor_window.tscn")
		return

	# Cerrar editor anterior si existe
	if current_move_editor and is_instance_valid(current_move_editor):
		current_move_editor.queue_free()

	await get_tree().process_frame

	var editor := move_editor_scene.instantiate()
	if not editor:
		push_error("DatabaseEditor: No se pudo instanciar MoveEditorWindow")
		return

	# Añadir como hijo del DatabaseEditor para que sea modal
	add_child(editor)
	current_move_editor = editor

	# Abrir en modo Create
	if editor.has_method("open_create"):
		editor.open_create(_refresh_move_tab)

	# Conectar señales después de que se haya abierto
	await get_tree().process_frame
	await get_tree().process_frame
	_connect_move_editor_signals(editor)

## Abre el editor de Moves en modo Edit
func _open_move_editor_edit(move_data: MoveData) -> void:
	if not move_editor_scene:
		push_error("DatabaseEditor: No se pudo cargar move_editor_window.tscn")
		return

	# Cerrar editor anterior si existe
	if current_move_editor and is_instance_valid(current_move_editor):
		current_move_editor.queue_free()

	await get_tree().process_frame

	var editor := move_editor_scene.instantiate()
	if not editor:
		push_error("DatabaseEditor: No se pudo instanciar MoveEditorWindow")
		return

	# Añadir como hijo del DatabaseEditor para que sea modal
	add_child(editor)
	current_move_editor = editor

	# Abrir en modo Edit
	if editor.has_method("open_edit"):
		editor.open_edit(move_data, _refresh_move_tab)

	# Conectar señales después de que se haya abierto
	await get_tree().process_frame
	await get_tree().process_frame
	_connect_move_editor_signals(editor)

## Abre el editor de Moves en modo Duplicate
func _open_move_editor_duplicate(move_data: MoveData) -> void:
	if not move_editor_scene:
		push_error("DatabaseEditor: No se pudo cargar move_editor_window.tscn")
		return

	# Cerrar editor anterior si existe
	if current_move_editor and is_instance_valid(current_move_editor):
		current_move_editor.queue_free()

	await get_tree().process_frame

	var editor := move_editor_scene.instantiate()
	if not editor:
		push_error("DatabaseEditor: No se pudo instanciar MoveEditorWindow")
		return

	# Añadir como hijo del DatabaseEditor para que sea modal
	add_child(editor)
	current_move_editor = editor

	# Abrir en modo Duplicate
	if editor.has_method("open_duplicate"):
		editor.open_duplicate(move_data, _refresh_move_tab)

	# Conectar señales después de que se haya abierto
	await get_tree().process_frame
	await get_tree().process_frame
	_connect_move_editor_signals(editor)

## Conecta las señales del editor de Moves
func _connect_move_editor_signals(editor: Window) -> void:
	if not editor or not is_instance_valid(editor):
		return

	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	call_deferred("_do_connect_move_signals", editor)

## Conecta las señales directamente (llamado de forma diferida)
func _do_connect_move_signals(editor: Window) -> void:
	if not editor or not is_instance_valid(editor):
		return

	var script := editor.get_script()
	if script:
		var signals_list: Array = script.get_script_signal_list()
		var has_saved := false
		var has_cancelled := false

		for sig in signals_list:
			if sig.name == "saved":
				has_saved = true
			elif sig.name == "cancelled":
				has_cancelled = true

		if has_saved and has_cancelled:
			editor.saved.connect(_on_move_editor_saved)
			editor.cancelled.connect(_on_move_editor_cancelled)
		else:
			push_warning("[DatabaseEditor] Las señales no están disponibles en el script de MoveEditor")

func _on_move_editor_saved(move_data: MoveData, was_new: bool) -> void:
	print("[DatabaseEditor] Movimiento guardado: %s (nuevo: %s)" % [move_data.resource_path, was_new])
	current_move_editor = null
	_refresh_move_tab()

	# Si estamos en modo picker, seleccionar el recurso guardado
	if is_picker_mode and picker_resource_type == ResourceType.MOVE:
		await get_tree().process_frame
		await get_tree().process_frame
		_set_initial_selection(move_data.id)

func _on_move_editor_cancelled() -> void:
	print("[DatabaseEditor] Editor de Moves cancelado")

## Refresca la pestaña de Moves
func _refresh_move_tab() -> void:
	if move_tab:
		_load_move_resources_directly(move_tab)

## Muestra diálogo de confirmación para eliminar un movimiento
func _show_delete_move_confirmation_dialog(move_data: MoveData, tab_node: Control) -> void:
	var move_name := move_data.Name if move_data.Name != "" else move_data.internal_name
	var file_path := move_data.resource_path

	if file_path == "":
		_show_warning("No se pudo obtener la ruta del archivo para eliminar.")
		return

	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "¿Estás seguro de que quieres eliminar el movimiento '%s'?\n\nEsta acción no se puede deshacer." % move_name
	dialog.ok_button_text = "Eliminar"
	dialog.cancel_button_text = "Cancelar"
	dialog.title = "Confirmar Eliminación"

	add_child(dialog)
	dialog.popup_centered()

	dialog.confirmed.connect(func():
		_delete_move_file(file_path, tab_node)
		dialog.queue_free()
	)

	dialog.canceled.connect(func():
		dialog.queue_free()
	)

## Elimina un archivo de Movimiento
func _delete_move_file(file_path: String, tab_node: Control) -> void:
	var filesystem_path := ProjectSettings.globalize_path(file_path)
	var dir := DirAccess.open(filesystem_path.get_base_dir())

	if not dir:
		var dir_path := file_path.get_base_dir()
		dir = DirAccess.open(ProjectSettings.globalize_path(dir_path))
		if not dir:
			_show_warning("No se pudo abrir el directorio para eliminar el archivo")
			return

	var file_name := file_path.get_file()
	var error := dir.remove(file_name)

	if error != OK:
		_show_warning("Error al eliminar el archivo: %s" % error_string(error))
		return

	print("[DatabaseEditor] Archivo eliminado: %s" % file_path)

	_refresh_filesystem()

	# Limpiar la selección
	tab_node.remove_meta("selected_move_data")

	# Limpiar el panel de detalles
	var detail_container: VBoxContainer = tab_node.get_node_or_null("VBoxContainer/ContentContainer/RightPanel/DetailPanel/ScrollContainer/DetailContainer")
	if detail_container:
		var children = detail_container.get_children()
		for child in children:
			detail_container.remove_child(child)
			child.queue_free()

	# Deseleccionar en la lista
	var resource_list: ItemList = tab_node.get_node_or_null("VBoxContainer/ContentContainer/LeftPanel/ResourceList")
	if resource_list:
		resource_list.deselect_all()

	# Refrescar la lista después de esperar frames
	await get_tree().process_frame
	await get_tree().process_frame
	_refresh_move_tab()

## ============================================
## FUNCIONES PARA ITEMS
## ============================================

## Carga recursos de Items directamente
func _load_item_resources_directly(tab_node: Control) -> void:
	print("[DatabaseEditor] Cargando recursos de Items directamente...")

	# Obtener el ItemList directamente del nodo
	var resource_list: ItemList = tab_node.get_node_or_null("VBoxContainer/ContentContainer/LeftPanel/ResourceList")
	if not resource_list:
		push_error("[DatabaseEditor] No se encontró ResourceList en ItemTab")
		return

	resource_list.clear()

	# Cargar recursos desde el directorio
	var dir_path := "res://Resources/Data/Items"
	var filesystem_path := ProjectSettings.globalize_path(dir_path)
	var dir := DirAccess.open(filesystem_path)
	if dir == null:
		push_error("[DatabaseEditor] No se pudo abrir directorio: %s" % dir_path)
		return

	var all_resources: Array = []
	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if dir.current_is_dir() or not file_name.ends_with(".tres"):
			file_name = dir.get_next()
			continue

		# Extraer ID y nombre del nombre del archivo
		var file_base := file_name.get_basename()
		var parts := file_base.split(" - ", false, 1)

		var id_str := parts[0].strip_edges()
		var name_str := ""
		if parts.size() >= 2:
			name_str = parts[1].strip_edges()

		# Si no tiene el formato "XXX - Nombre", intentar extraer solo el ID
		if not id_str.is_valid_int() and file_base.is_valid_int():
			id_str = file_base

		# Si aún no es válido, intentar extraer números del inicio
		if not id_str.is_valid_int():
			var id_match := file_base.split(" ")[0]
			if id_match.is_valid_int():
				id_str = id_match

		if id_str.is_valid_int():
			var id := int(id_str)
			# Si el nombre no está en el archivo, usar un nombre por defecto
			# (No cargamos el recurso para hacer la carga más rápida)
			if name_str == "":
				name_str = "Item #%d" % id

			var file_path := dir_path + "/" + file_name
			var metadata := {
				"id": id,
				"name": name_str,
				"path": file_path,
				"file_name": file_name
			}
			all_resources.append(metadata)

		file_name = dir.get_next()

	dir.list_dir_end()

	# Ordenar por ID
	all_resources.sort_custom(func(a, b): return int(a.get("id", 0)) < int(b.get("id", 0)))

	# Guardar metadata para poder accederla cuando se seleccione un item
	tab_node.set_meta("item_metadata", all_resources)
	tab_node.set_meta("item_metadata_all", all_resources)

	# Conectar señal de selección
	var connection_result = resource_list.item_selected.connect(func(idx: int):
		_on_item_item_selected(idx, tab_node)
	)
	if connection_result != OK:
		push_error("[DatabaseEditor] Error al conectar señal item_selected para Items: %d" % connection_result)

	# Conectar señal de búsqueda
	var search_line_edit: LineEdit = tab_node.get_node_or_null("VBoxContainer/SearchContainer/SearchLineEdit")
	if search_line_edit:
		if not search_line_edit.text_changed.is_connected(_on_item_search_text_changed.bind(tab_node)):
			search_line_edit.text_changed.connect(_on_item_search_text_changed.bind(tab_node))

	# Conectar botones de acción
	var create_button: Button = tab_node.get_node_or_null("VBoxContainer/ActionButtons/CreateButton")
	var edit_button: Button = tab_node.get_node_or_null("VBoxContainer/ActionButtons/EditButton")
	var delete_button: Button = tab_node.get_node_or_null("VBoxContainer/ActionButtons/DeleteButton")
	var duplicate_button: Button = tab_node.get_node_or_null("VBoxContainer/ActionButtons/DuplicateButton")

	if create_button:
		if not create_button.pressed.is_connected(_on_item_create_button_pressed.bind(tab_node)):
			create_button.pressed.connect(_on_item_create_button_pressed.bind(tab_node))
	if edit_button:
		if not edit_button.pressed.is_connected(_on_item_edit_button_pressed.bind(tab_node)):
			edit_button.pressed.connect(_on_item_edit_button_pressed.bind(tab_node))
	if delete_button:
		if not delete_button.pressed.is_connected(_on_item_delete_button_pressed.bind(tab_node)):
			delete_button.pressed.connect(_on_item_delete_button_pressed.bind(tab_node))
	if duplicate_button:
		if not duplicate_button.pressed.is_connected(_on_item_duplicate_button_pressed.bind(tab_node)):
			duplicate_button.pressed.connect(_on_item_duplicate_button_pressed.bind(tab_node))

	# Mostrar todos los recursos inicialmente
	_update_item_list(tab_node, "")

	print("[DatabaseEditor] Recursos de Items cargados: %d" % all_resources.size())

## Callback cuando se selecciona un item en la lista de Items
func _on_item_item_selected(index: int, tab_node: Control) -> void:
	var resource_list: ItemList = tab_node.get_node_or_null("VBoxContainer/ContentContainer/LeftPanel/ResourceList")
	var detail_container: VBoxContainer = tab_node.get_node_or_null("VBoxContainer/ContentContainer/RightPanel/DetailPanel/ScrollContainer/DetailContainer")

	if not resource_list:
		push_error("[DatabaseEditor] No se encontró ResourceList")
		return
	if not detail_container:
		# Intentar encontrar recursivamente o crearlo
		var right_panel = tab_node.get_node_or_null("VBoxContainer/ContentContainer/RightPanel")
		if not right_panel:
			push_error("[DatabaseEditor] No se encontró RightPanel en ItemTab")
			return

		var detail_panel = right_panel.get_node_or_null("DetailPanel")
		if not detail_panel:
			push_error("[DatabaseEditor] No se encontró DetailPanel en ItemTab")
			return

		# Buscar ScrollContainer
		var scroll_container: ScrollContainer = null
		for child in detail_panel.get_children():
			if child is ScrollContainer:
				scroll_container = child
				break

		# Si no hay ScrollContainer, crearlo
		if not scroll_container:
			scroll_container = ScrollContainer.new()
			scroll_container.set_anchors_preset(Control.PRESET_FULL_RECT)
			scroll_container.offset_left = 8
			scroll_container.offset_top = 8
			scroll_container.offset_right = -8
			scroll_container.offset_bottom = -8
			detail_panel.add_child(scroll_container)

		# Buscar DetailContainer dentro del ScrollContainer
		for child in scroll_container.get_children():
			if child is VBoxContainer:
				detail_container = child
				break

		# Si no hay DetailContainer, crearlo
		if not detail_container:
			detail_container = VBoxContainer.new()
			detail_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			detail_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
			detail_container.add_theme_constant_override("separation", 8)
			scroll_container.add_child(detail_container)

	# Eliminar el DetailLabel placeholder si existe (está directamente en DetailPanel, no en DetailContainer)
	var detail_panel = tab_node.get_node_or_null("VBoxContainer/ContentContainer/RightPanel/DetailPanel")
	if detail_panel:
		var detail_label = detail_panel.get_node_or_null("DetailLabel")
		if detail_label:
			detail_panel.remove_child(detail_label)
			detail_label.queue_free()

	# Limpiar el contenedor (eliminar todos los hijos, incluyendo placeholders)
	var children = detail_container.get_children()
	for child in children:
		detail_container.remove_child(child)
		child.queue_free()

	# Obtener metadata del item seleccionado
	var metadata_array: Array = tab_node.get_meta("item_metadata", [])
	if index < 0 or index >= metadata_array.size():
		push_error("[DatabaseEditor] Índice de item inválido: %d" % index)
		return

	var metadata: Dictionary = metadata_array[index]
	var file_path: String = metadata.get("path", "")

	if file_path.is_empty() or not ResourceLoader.exists(file_path):
		push_error("[DatabaseEditor] No se pudo cargar el recurso desde: %s" % file_path)
		return

	var item_data: ItemData = load(file_path) as ItemData
	if not item_data:
		push_error("[DatabaseEditor] No se pudo cargar ItemData desde: %s" % file_path)
		return

	# Guardar el ItemData seleccionado en metadata del tab
	tab_node.set_meta("selected_item_data", item_data)

	# Si estamos en modo picker, actualizar la selección
	if is_picker_mode and picker_resource_type == ResourceType.ITEM:
		var display_name: String = item_data.display_name if item_data.display_name != "" else item_data.internal_name
		_update_picker_selection(item_data, item_data.id, file_path, display_name)

	# Mostrar información del item
	_add_section_header(detail_container, "Información General")
	_add_detail_row(detail_container, "ID", str(item_data.id))
	_add_detail_row(detail_container, "Nombre interno", item_data.internal_name if item_data.internal_name != "" else "N/A")
	_add_detail_row(detail_container, "Nombre", item_data.display_name if item_data.display_name != "" else "N/A")
	_add_detail_row(detail_container, "Descripción", item_data.description if item_data.description != "" else "N/A")

	# Clasificación
	_add_section_header(detail_container, "Clasificación")
	var pocket_names := ["None", "Items", "Medicine", "Balls", "TM/HM", "Berries", "Key Items", "Machines", "Battle Items"]
	var pocket_name := "Unknown"
	if item_data.pocket >= 0 and item_data.pocket < pocket_names.size():
		pocket_name = pocket_names[item_data.pocket]
	_add_detail_row(detail_container, "Bolsillo", pocket_name)

	var kind_names := ["Generic", "Heal HP", "Heal PP", "Cure Status", "Revive", "Poké Ball", "TM/HM", "Held", "Key", "Evolution", "Stat Boost", "Repel", "Berry"]
	var kind_name := "Unknown"
	if item_data.kind >= 0 and item_data.kind < kind_names.size():
		kind_name = kind_names[item_data.kind]
	_add_detail_row(detail_container, "Tipo", kind_name)

	# Icono
	if item_data.icon:
		_add_section_header(detail_container, "Icono")
		var icon_texture_rect := TextureRect.new()
		icon_texture_rect.texture = item_data.icon
		icon_texture_rect.custom_minimum_size = Vector2(64, 64)
		icon_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		detail_container.add_child(icon_texture_rect)

## Actualiza la lista de Items según el texto de búsqueda
func _update_item_list(tab_node: Control, search_text: String) -> void:
	var resource_list: ItemList = tab_node.get_node_or_null("VBoxContainer/ContentContainer/LeftPanel/ResourceList")
	if not resource_list:
		return

	var all_metadata: Array = tab_node.get_meta("item_metadata_all", [])
	resource_list.clear()

	var search_lower := search_text.to_lower()
	for metadata in all_metadata:
		var name_str: String = metadata.get("name", "")
		var id: int = metadata.get("id", 0)

		if search_text.is_empty() or name_str.to_lower().contains(search_lower) or str(id).contains(search_lower):
			resource_list.add_item("%03d - %s" % [id, name_str])

	# Guardar metadata filtrada
	var filtered_metadata: Array = []
	for i in range(resource_list.get_item_count()):
		var item_text := resource_list.get_item_text(i)
		# Extraer ID del texto (formato "001 - Nombre")
		var parts := item_text.split(" - ", false, 1)
		if parts.size() >= 1:
			var id_str := parts[0].strip_edges()
			if id_str.is_valid_int():
				var item_id := int(id_str)
				# Buscar metadata por ID
				for metadata in all_metadata:
					if metadata.get("id", 0) == item_id:
						filtered_metadata.append(metadata)
						break

	tab_node.set_meta("item_metadata", filtered_metadata)

## Callback cuando cambia el texto de búsqueda de Items
func _on_item_search_text_changed(new_text: String, tab_node: Control) -> void:
	_update_item_list(tab_node, new_text)

## Maneja el botón Crear de Items
func _on_item_create_button_pressed(tab_node: Control) -> void:
	_open_item_editor_create()

## Abre el editor de Items en modo Edit
func _on_item_edit_button_pressed(tab_node: Control) -> void:
	var item_data: ItemData = tab_node.get_meta("selected_item_data", null)
	if not item_data:
		_show_warning("No hay ningún item seleccionado")
		return
	_open_item_editor_edit(item_data)

## Abre el editor de Items en modo Duplicate
func _on_item_duplicate_button_pressed(tab_node: Control) -> void:
	var item_data: ItemData = tab_node.get_meta("selected_item_data", null)
	if not item_data:
		_show_warning("No hay ningún item seleccionado")
		return
	_open_item_editor_duplicate(item_data)

## Abre el editor de Items en modo Delete
func _on_item_delete_button_pressed(tab_node: Control) -> void:
	var item_data: ItemData = tab_node.get_meta("selected_item_data", null)
	if not item_data:
		_show_warning("No hay ningún item seleccionado")
		return
	_show_delete_item_confirmation_dialog(item_data, tab_node)

## Abre el editor de Items en modo Create
func _open_item_editor_create() -> void:
	if not item_editor_scene:
		push_error("DatabaseEditor: No se pudo cargar item_editor_window.tscn")
		return

	# Cerrar editor anterior si existe
	if current_item_editor and is_instance_valid(current_item_editor):
		current_item_editor.queue_free()

	await get_tree().process_frame

	var editor := item_editor_scene.instantiate()
	if not editor:
		push_error("DatabaseEditor: No se pudo instanciar ItemEditorWindow")
		return

	# Añadir como hijo del DatabaseEditor para que sea modal
	add_child(editor)
	current_item_editor = editor

	# Abrir en modo Create
	if editor.has_method("open_create"):
		editor.open_create(_refresh_item_tab)

	# Conectar señales después de que se haya abierto
	await get_tree().process_frame
	_connect_item_editor_signals(editor)

## Abre el editor de Items en modo Edit
func _open_item_editor_edit(item_data: ItemData) -> void:
	if not item_editor_scene:
		push_error("DatabaseEditor: No se pudo cargar item_editor_window.tscn")
		return

	# Cerrar editor anterior si existe
	if current_item_editor and is_instance_valid(current_item_editor):
		current_item_editor.queue_free()

	await get_tree().process_frame

	var editor := item_editor_scene.instantiate()
	if not editor:
		push_error("DatabaseEditor: No se pudo instanciar ItemEditorWindow")
		return

	# Añadir como hijo del DatabaseEditor para que sea modal
	add_child(editor)
	current_item_editor = editor

	# Abrir en modo Edit
	if editor.has_method("open_edit"):
		editor.open_edit(item_data, _refresh_item_tab)

	# Conectar señales después de que se haya abierto
	await get_tree().process_frame
	_connect_item_editor_signals(editor)

## Abre el editor de Items en modo Duplicate
func _open_item_editor_duplicate(item_data: ItemData) -> void:
	if not item_editor_scene:
		push_error("DatabaseEditor: No se pudo cargar item_editor_window.tscn")
		return

	# Cerrar editor anterior si existe
	if current_item_editor and is_instance_valid(current_item_editor):
		current_item_editor.queue_free()

	await get_tree().process_frame

	var editor := item_editor_scene.instantiate()
	if not editor:
		push_error("DatabaseEditor: No se pudo instanciar ItemEditorWindow")
		return

	# Añadir como hijo del DatabaseEditor para que sea modal
	add_child(editor)
	current_item_editor = editor

	# Abrir en modo Duplicate
	if editor.has_method("open_duplicate"):
		editor.open_duplicate(item_data, _refresh_item_tab)

	# Conectar señales después de que se haya abierto
	await get_tree().process_frame
	_connect_item_editor_signals(editor)

## Conecta las señales del editor de Items
func _connect_item_editor_signals(editor: Window) -> void:
	if not editor or not is_instance_valid(editor):
		return

	await get_tree().process_frame
	await get_tree().process_frame

	# Intentar conectar señales usando el script del editor
	var script := editor.get_script()
	if script:
		# Verificar si las señales existen en el script
		if script.has_method("get") or script.has_method("has_signal"):
			# Las señales deberían estar disponibles automáticamente
			# Intentar conectar directamente
			if editor.has_signal("saved"):
				editor.saved.connect(_on_item_editor_saved)
			if editor.has_signal("cancelled"):
				editor.cancelled.connect(_on_item_editor_cancelled)
		else:
			push_warning("[DatabaseEditor] Las señales no están disponibles en el script de ItemEditor")
	else:
		push_warning("[DatabaseEditor] No se pudo obtener el script del ItemEditor")

func _on_item_editor_saved(item_data: ItemData, was_new: bool) -> void:
	print("[DatabaseEditor] Item guardado: %s (nuevo: %s)" % [item_data.resource_path, was_new])
	current_item_editor = null
	_refresh_item_tab()

	# Si estamos en modo picker, seleccionar el recurso guardado
	if is_picker_mode and picker_resource_type == ResourceType.ITEM:
		await get_tree().process_frame
		await get_tree().process_frame
		_set_initial_selection(item_data.id)

func _on_item_editor_cancelled() -> void:
	print("[DatabaseEditor] Editor de Items cancelado")

## Refresca la pestaña de Items
func _refresh_item_tab() -> void:
	if item_tab:
		_load_item_resources_directly(item_tab)

## Muestra diálogo de confirmación para eliminar un item
func _show_delete_item_confirmation_dialog(item_data: ItemData, tab_node: Control) -> void:
	var dialog := ConfirmationDialog.new()
	var item_name := item_data.display_name if item_data.display_name != "" else item_data.internal_name
	if item_name == "":
		item_name = "Item #%d" % item_data.id
	dialog.dialog_text = "¿Está seguro de que desea eliminar el item '%s'?" % item_name
	dialog.ok_button_text = "Eliminar"
	dialog.cancel_button_text = "Cancelar"
	dialog.title = "Confirmar Eliminación"

	add_child(dialog)
	dialog.popup_centered()

	dialog.confirmed.connect(func():
		_delete_item_file(item_data, tab_node)
		dialog.queue_free()
	)

	dialog.canceled.connect(func():
		dialog.queue_free()
	)

## Elimina el archivo de un item
func _delete_item_file(item_data: ItemData, tab_node: Control) -> void:
	if not item_data or not item_data.resource_path:
		_show_warning("No se puede eliminar: el item no tiene ruta de archivo")
		return

	var file_path := item_data.resource_path
	var dir := DirAccess.open(ProjectSettings.globalize_path(file_path.get_base_dir()))
	if not dir:
		_show_warning("No se pudo abrir el directorio para eliminar el archivo")
		return

	var file_name := file_path.get_file()
	if dir.file_exists(file_name):
		var error := dir.remove(file_name)
		if error != OK:
			_show_warning("Error al eliminar el archivo: %s" % error_string(error))
		else:
			print("[DatabaseEditor] Item eliminado: %s" % file_path)
			_refresh_filesystem()
			_refresh_item_tab()

