@tool
extends EditorPlugin

## Plugin principal de Event Tools
## Añade la opción "Edit Event" al menú contextual del SceneTree y Viewport

var popup_scene: PackedScene = null
var processing_edit_event: bool = false

const EDIT_EVENT_ID = 99999
const EDIT_EVENT_TEXT = "Edit Event"
const MAIN_MENU_NAMES = ["scene", "project", "debug", "editor", "help", "tools", "file", "view"]
const MAIN_MENU_ITEMS = ["Escena", "Scene", "Proyecto", "Project", "Depurar", "Debug", "Herramientas", "Tools", "Ayuda", "Help", "Editor", "Archivo", "File", "Ver", "View"]
const CONTEXT_MENU_ITEMS = ["Rename", "Renombrar", "Delete", "Borrar", "Copy", "Copiar", "Paste", "Pegar", "Duplicate", "Duplicar", "Change Scene", "Cambiar Escena", "Attach Script", "Añadir Script"]
const CONTEXT_KEYWORDS = ["scene", "tree", "viewport", "dock", "subviewport"]

func _enter_tree() -> void:
	popup_scene = load("res://addons/event_tools/event_editor_popup.tscn")
	if not popup_scene:
		push_error("Event Tools: No se pudo cargar event_editor_popup.tscn")

	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	_connect_to_all_popup_menus(EditorInterface.get_base_control())

func _exit_tree() -> void:
	_disconnect_from_all_popup_menus(EditorInterface.get_base_control())
	popup_scene = null

## Conecta/desconecta recursivamente a todos los PopupMenu del editor
func _connect_to_all_popup_menus(node: Node) -> void:
	if node is PopupMenu:
		var popup = node as PopupMenu
		if not popup.about_to_popup.is_connected(_on_popup_menu_about_to_show):
			popup.about_to_popup.connect(_on_popup_menu_about_to_show.bind(popup))

	for child in node.get_children():
		_connect_to_all_popup_menus(child)

func _disconnect_from_all_popup_menus(node: Node) -> void:
	if node is PopupMenu:
		var popup = node as PopupMenu
		if popup.about_to_popup.is_connected(_on_popup_menu_about_to_show):
			popup.about_to_popup.disconnect(_on_popup_menu_about_to_show)

	for child in node.get_children():
		_disconnect_from_all_popup_menus(child)

## Se llama cuando cualquier PopupMenu está a punto de mostrarse
func _on_popup_menu_about_to_show(popup_menu: PopupMenu) -> void:
	if not _is_context_menu(popup_menu):
		return

	var selection = EditorInterface.get_selection()
	var selected_nodes = selection.get_selected_nodes()
	if selected_nodes.size() != 1:
		return

	var node = selected_nodes[0]
	if not _is_event_node(node):
		return

	# Actualizar metadata si ya existe, o añadir el item
	for i in range(popup_menu.get_item_count()):
		if popup_menu.get_item_text(i) == EDIT_EVENT_TEXT:
			popup_menu.set_item_metadata(i, node)
			return

	print("Event Tools: Event detectado: '", node.name, "' (ruta: ", node.get_path(), ")")
	_add_edit_event_to_menu(popup_menu, node)

## Verifica si un PopupMenu es un menú contextual
func _is_context_menu(popup_menu: PopupMenu) -> bool:
	var item_count = popup_menu.get_item_count()
	if item_count < 2:
		return false

	# Excluir menús principales del editor
	for i in range(min(item_count, 15)):
		var text = popup_menu.get_item_text(i)
		if text in MAIN_MENU_ITEMS:
			return false
		for context_item in CONTEXT_MENU_ITEMS:
			if text.contains(context_item):
				return true

	# Verificar jerarquía del menú (parent y grandparent)
	var parent = popup_menu.get_parent()
	for depth in range(2):
		if not parent:
			break
		var name_lower = parent.name.to_lower()
		var class_lower = parent.get_class().to_lower()
		for keyword in CONTEXT_KEYWORDS:
			if keyword in name_lower or keyword in class_lower:
				return true
		parent = parent.get_parent()

	return item_count >= 3 and item_count <= 30

## Añade "Edit Event" al principio del menú
func _add_edit_event_to_menu(popup_menu: PopupMenu, node: Node) -> void:
	if not is_instance_valid(popup_menu):
		return

	# Guardar items actuales
	var items = []
	for i in range(popup_menu.get_item_count()):
		items.append({
			"text": popup_menu.get_item_text(i),
			"icon": popup_menu.get_item_icon(i),
			"is_separator": popup_menu.is_item_separator(i),
			"is_disabled": popup_menu.is_item_disabled(i),
			"submenu": popup_menu.get_item_submenu(i),
			"metadata": popup_menu.get_item_metadata(i)
		})

	# Reconstruir menú con "Edit Event" al principio
	popup_menu.clear()
	popup_menu.add_item(EDIT_EVENT_TEXT, EDIT_EVENT_ID)
	popup_menu.set_item_metadata(0, node)
	popup_menu.add_separator()

	# Restaurar items originales
	for item in items:
		if item.is_separator:
			popup_menu.add_separator()
		elif item.submenu != "":
			popup_menu.add_submenu_item(item.text, item.submenu)
		else:
			popup_menu.add_item(item.text)
			var item_idx = popup_menu.get_item_count() - 1
			if item.icon:
				popup_menu.set_item_icon(item_idx, item.icon)
			if item.is_disabled:
				popup_menu.set_item_disabled(item_idx, true)
			if item.metadata != null:
				popup_menu.set_item_metadata(item_idx, item.metadata)

	# Conectar señal si no está conectada
	if not popup_menu.id_pressed.is_connected(_on_menu_item_selected):
		popup_menu.id_pressed.connect(_on_menu_item_selected.bind(popup_menu))

	# Ajustar posición del menú para que sea visible
	var estimated_height = popup_menu.get_item_count() * 20 + 10
	popup_menu.position.y = max(popup_menu.position.y - estimated_height / 4, 10)

## Se llama cuando se selecciona un item del menú
func _on_menu_item_selected(id: int, popup_menu: PopupMenu) -> void:
	if processing_edit_event or id != EDIT_EVENT_ID:
		return

	# Verificar que NO es un menú principal del editor
	if popup_menu.name.to_lower() in MAIN_MENU_NAMES:
		return

	# Encontrar el índice real del item (el ID es solo para identificar)
	var item_index = -1
	for i in range(popup_menu.get_item_count()):
		if popup_menu.get_item_id(i) == EDIT_EVENT_ID:
			item_index = i
			break

	if item_index == -1:
		return

	processing_edit_event = true
	popup_menu.hide()
	call_deferred("_handle_edit_event_selected", popup_menu, item_index)

## Maneja la selección de "Edit Event"
func _handle_edit_event_selected(popup_menu: PopupMenu, item_id: int) -> void:
	var event_node = popup_menu.get_item_metadata(item_id)

	# Si no hay metadata, obtener de la selección actual
	if not event_node:
		var selection = EditorInterface.get_selection()
		var selected_nodes = selection.get_selected_nodes()
		if selected_nodes.size() == 1 and _is_event_node(selected_nodes[0]):
			event_node = selected_nodes[0]

	if not event_node or not _is_event_node(event_node):
		processing_edit_event = false
		return

	# Abrir el editor después de varios frames
	call_deferred("_open_event_editor_deferred", event_node)

## Abre el editor de eventos de forma diferida
func _open_event_editor_deferred(event_node: Node) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	if not event_node or not popup_scene:
		processing_edit_event = false
		return

	var window = popup_scene.instantiate()
	if not window:
		push_error("Event Tools: No se pudo instanciar la ventana del editor")
		processing_edit_event = false
		return

	EditorInterface.get_base_control().add_child(window)

	# Pasar referencia al EditorInterface para refrescar el Inspector
	window.editor_interface = EditorInterface

	# Esperar varios frames para que el nodo esté completamente inicializado
	await get_tree().process_frame
	await get_tree().process_frame

	# Asignar el event_node como metadata después de que esté en el árbol
	window.set_meta("pending_event_node", event_node)

	# Forzar que _ready() se ejecute si no se ha ejecutado aún
	if not window.is_node_ready():
		await window.ready

	# Procesar el evento desde metadata
	if window.has_meta("pending_event_node"):
		var pending_event = window.get_meta("pending_event_node")
		window.remove_meta("pending_event_node")
		window.event_node = pending_event
		if window.has_method("_setup_for_event"):
			window._setup_for_event()

	processing_edit_event = false

## Verifica si un nodo es de tipo Event
func _is_event_node(node: Node) -> bool:
	if not node:
		return false

	var script = node.get_script()
	if script:
		if script.resource_path.ends_with("Event.gd") or script.get_global_name() == "Event":
			return true

	return node.has_method("trigger") and node.has_method("setup_current_page")
