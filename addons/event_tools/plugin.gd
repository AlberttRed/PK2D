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
	# Verificar si es el menú del viewport (click derecho en viewport vacío)
	if _is_viewport_context_menu(popup_menu):
		_handle_viewport_context_menu(popup_menu)
		return

	# Verificar si es el menú del SceneTree
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

	_add_edit_event_to_menu(popup_menu, node)

## Verifica si un PopupMenu es un menú contextual del SceneTree
func _is_context_menu(popup_menu: PopupMenu) -> bool:
	# Solo añadir al menú del SceneTree, no a otros menús
	# Verificar jerarquía del menú para asegurar que es del SceneTree
	var parent = popup_menu.get_parent()
	var depth = 0
	var found_scenetree = false

	while parent and depth < 6:  # Buscar hasta 6 niveles arriba
		var name_lower = parent.name.to_lower()
		var class_lower = parent.get_class().to_lower()

		# Verificar si es el SceneTree
		if "scenetree" in name_lower or "scene_tree" in name_lower or "SceneTree" in parent.get_class():
			found_scenetree = true
			break

		# Excluir explícitamente otros docks/paneles
		if "project" in name_lower and "dock" in name_lower:
			return false
		if "filesystem" in name_lower or "file_system" in name_lower:
			return false
		if "inspector" in name_lower:
			return false
		if "import" in name_lower and "dock" in name_lower:
			return false
		if "output" in name_lower and "dock" in name_lower:
			return false
		if "debugger" in name_lower:
			return false
		if "remote" in name_lower and "dock" in name_lower:
			return false

		parent = parent.get_parent()
		depth += 1

	# Solo proceder si encontramos el SceneTree en la jerarquía
	if not found_scenetree:
		return false

	# Verificar que tiene items de menú contextual típicos del SceneTree
	var item_count = popup_menu.get_item_count()
	if item_count < 2:
		return false

	# Verificar que tiene al menos uno de los items típicos del menú contextual del SceneTree
	for i in range(min(item_count, 15)):
		var text = popup_menu.get_item_text(i)
		for context_item in CONTEXT_MENU_ITEMS:
			if text.contains(context_item):
				return true

	# Si no tiene items típicos, no es el menú del SceneTree
	return false

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

	# Pasar referencia al EditorInterface para refrescar el Inspector usando metadata
	window.set_meta("editor_interface", EditorInterface)

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
		var script_path = script.resource_path
		var script_class = script.get_global_name()

		# Verificar si es Event, NPC o Trainer directamente
		if script_class == "Event" or script_class == "NPC" or script_class == "Trainer":
			return true

		# Verificar por ruta del script
		if script_path.ends_with("Event.gd") or script_path.ends_with("NPC.gd") or script_path.ends_with("Trainer.gd"):
			return true

	# Fallback: verificar si tiene métodos característicos de Event
	return node.has_method("trigger") and node.has_method("setup_current_page")

## Verifica si un PopupMenu es un menú contextual del viewport
func _is_viewport_context_menu(popup_menu: PopupMenu) -> bool:
	# No verificar si hay nodos seleccionados - queremos que aparezca siempre
	# cuando se hace click derecho en el viewport

	# Buscar en la jerarquía del menú para ver si es del viewport
	# El menú del viewport 2D tiene CanvasItemEditor como padre directo
	var parent = popup_menu.get_parent()
	var depth = 0
	var found_canvas_editor = false

	while parent and depth < 5:
		var parent_class = parent.get_class()

		# Verificar si es CanvasItemEditor (editor del viewport 2D)
		if parent_class == "CanvasItemEditor":
			found_canvas_editor = true
			break

		# También verificar si es un viewport
		if "viewport" in parent_class.to_lower() and "scenetree" not in parent_class.to_lower():
			found_canvas_editor = true
			break

		parent = parent.get_parent()
		depth += 1

	if not found_canvas_editor:
		return false

	# Verificar que hay una escena abierta
	var edited_scene_root = EditorInterface.get_edited_scene_root()
	if not edited_scene_root:
		return false

	# Verificar que tiene el nodo Events
	var events_node = _find_events_node(edited_scene_root)
	if not events_node:
		return false

	return true

## Maneja el menú contextual del viewport
func _handle_viewport_context_menu(popup_menu: PopupMenu) -> void:
	# Verificar que hay una escena abierta
	var edited_scene_root = EditorInterface.get_edited_scene_root()
	if not edited_scene_root:
		return

	# Buscar el nodo "Events" en la escena
	var events_node = _find_events_node(edited_scene_root)
	if not events_node:
		return

	# Guardar la posición del mouse cuando se muestra el menú
	# Buscar el CanvasItemEditor para obtener la posición del mouse
	var canvas_editor = popup_menu.get_parent()
	if canvas_editor and canvas_editor.get_class() == "CanvasItemEditor":
		# Guardar la posición del mouse en metadata del menú para usarla después
		var mouse_pos = _get_mouse_position_from_canvas_editor(canvas_editor, edited_scene_root)
		popup_menu.set_meta("click_position", mouse_pos)
		popup_menu.set_meta("edited_scene_root", edited_scene_root)

	# Verificar si hay un nodo seleccionado y si es un Evento
	var selection = EditorInterface.get_selection()
	var selected_nodes = selection.get_selected_nodes()

	if selected_nodes.size() > 0:
		var selected_node = selected_nodes[0]
		if _is_event_node(selected_node):
			# Si el nodo seleccionado es un Evento, mostrar "Editar Evento" primero
			_add_edit_event_menu_item(popup_menu, selected_node)
			# Y luego el grupo "Añadir"
			_add_viewport_menu_items(popup_menu, events_node)
		else:
			# Si el nodo seleccionado no es un Evento, mostrar solo las opciones de añadir
			_add_viewport_menu_items(popup_menu, events_node)
	else:
		# Si no hay nodos seleccionados, mostrar solo las opciones de añadir
		_add_viewport_menu_items(popup_menu, events_node)

## Busca el nodo "Events" en la escena
func _find_events_node(root: Node) -> Node:
	# Buscar recursivamente el nodo "Events"
	var events_node = root.find_child("Events", true, false)
	if events_node:
		return events_node

	# Si no se encuentra directamente, buscar en OverworldGrid
	var grid = root.find_child("OverworldGrid", true, false)
	if grid:
		events_node = grid.find_child("Events", true, false)
		if events_node:
			return events_node

	return null

## Añade la opción "Editar Evento" al menú
func _add_edit_event_menu_item(popup_menu: PopupMenu, event_node: Node) -> void:
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

	# Reconstruir menú con nuestras opciones al principio
	popup_menu.clear()
	popup_menu.add_item("Editar Evento", 2000)
	popup_menu.set_item_metadata(0, {"event_node": event_node})
	popup_menu.add_item("Duplicar", 2001)
	popup_menu.set_item_metadata(1, {"event_node": event_node})
	popup_menu.add_item("Eliminar", 2002)
	popup_menu.set_item_metadata(2, {"event_node": event_node})
	popup_menu.add_separator()

	# No añadir separador aquí, se añadirá después si se añade el grupo "Añadir"

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
	if not popup_menu.id_pressed.is_connected(_on_viewport_menu_item_selected):
		popup_menu.id_pressed.connect(_on_viewport_menu_item_selected.bind(popup_menu))

## Añade las opciones del viewport al menú
func _add_viewport_menu_items(popup_menu: PopupMenu, events_node: Node) -> void:
	# Verificar si el submenú "Añadir" ya existe
	var has_add_submenu = false
	for i in range(popup_menu.get_item_count()):
		var submenu_name = popup_menu.get_item_submenu(i)
		if submenu_name == "AddEventSubmenu":
			has_add_submenu = true
			break

	# Si ya existe, no hacer nada
	if has_add_submenu:
		return

	# Guardar todos los items actuales del menú
	var all_items = []
	for i in range(popup_menu.get_item_count()):
		all_items.append({
			"text": popup_menu.get_item_text(i),
			"icon": popup_menu.get_item_icon(i),
			"is_separator": popup_menu.is_item_separator(i),
			"is_disabled": popup_menu.is_item_disabled(i),
			"submenu": popup_menu.get_item_submenu(i),
			"metadata": popup_menu.get_item_metadata(i),
			"id": popup_menu.get_item_id(i)
		})

	# Guardar items originales de Godot si no están guardados
	if not popup_menu.has_meta("saved_items"):
		# Filtrar solo los items que no son nuestros (no tienen ID 2000-2002 ni submenu "AddEventSubmenu")
		var original_items = []
		for item in all_items:
			if item.id not in [2000, 2001, 2002] and item.submenu != "AddEventSubmenu":
				original_items.append(item)
		popup_menu.set_meta("saved_items", original_items)

	# Crear un submenú para agrupar las opciones de añadir
	var submenu = PopupMenu.new()
	submenu.name = "AddEventSubmenu"
	submenu.add_item("Evento", 1000)
	submenu.set_item_metadata(0, {"type": "add_event", "events_node": events_node})
	submenu.add_item("NPC", 1001)
	submenu.set_item_metadata(1, {"type": "add_npc", "events_node": events_node})
	submenu.add_item("Trainer", 1002)
	submenu.set_item_metadata(2, {"type": "add_trainer", "events_node": events_node})

	# Conectar la señal del submenú
	submenu.id_pressed.connect(func(id: int): _on_submenu_item_selected(id, submenu, popup_menu))

	# Añadir el submenú como hijo
	popup_menu.add_child(submenu)

	# Reconstruir el menú en el orden correcto
	popup_menu.clear()

	# 1. Si hay "Editar Evento", "Duplicar" o "Eliminar", añadirlos primero
	var edit_event_item = null
	var duplicate_item = null
	var delete_item = null
	for item in all_items:
		if item.id == 2000:
			edit_event_item = item
		elif item.id == 2001:
			duplicate_item = item
		elif item.id == 2002:
			delete_item = item

	if edit_event_item:
		popup_menu.add_item(edit_event_item.text, edit_event_item.id)
		popup_menu.set_item_metadata(popup_menu.get_item_count() - 1, edit_event_item.metadata)

	if duplicate_item:
		popup_menu.add_item(duplicate_item.text, duplicate_item.id)
		popup_menu.set_item_metadata(popup_menu.get_item_count() - 1, duplicate_item.metadata)

	if delete_item:
		popup_menu.add_item(delete_item.text, delete_item.id)
		popup_menu.set_item_metadata(popup_menu.get_item_count() - 1, delete_item.metadata)

	# No añadir separador entre "Editar Evento/Duplicar/Eliminar" y "Añadir"

	# 2. Añadir el grupo "Añadir"
	popup_menu.add_submenu_item("Añadir", submenu.name)
	popup_menu.add_separator()

	# 3. Restaurar items originales de Godot (excluyendo "Editar Evento" y "Añadir")
	var saved_items = popup_menu.get_meta("saved_items")
	for item in saved_items:
		if item.get("is_separator", false):
			popup_menu.add_separator()
		elif item.get("submenu", "") != "":
			popup_menu.add_submenu_item(item.get("text", ""), item.get("submenu", ""))
		else:
			var item_id = item.get("id", -1)
			if item_id >= 0:
				popup_menu.add_item(item.get("text", ""), item_id)
			else:
				popup_menu.add_item(item.get("text", ""))
			var item_idx = popup_menu.get_item_count() - 1
			if item.has("icon") and item.icon:
				popup_menu.set_item_icon(item_idx, item.icon)
			if item.get("is_disabled", false):
				popup_menu.set_item_disabled(item_idx, true)
			if item.has("metadata") and item.metadata != null:
				popup_menu.set_item_metadata(item_idx, item.metadata)

	# Conectar señal si no está conectada
	if not popup_menu.id_pressed.is_connected(_on_viewport_menu_item_selected):
		popup_menu.id_pressed.connect(_on_viewport_menu_item_selected.bind(popup_menu))

## Maneja la selección de items del submenú "Añadir"
func _on_submenu_item_selected(id: int, submenu: PopupMenu, popup_menu: PopupMenu) -> void:
	# Obtener la metadata del item seleccionado en el submenú
	var item_index = submenu.get_item_index(id)
	if item_index < 0:
		return

	var metadata = submenu.get_item_metadata(item_index)
	if not metadata or not metadata.has("type"):
		return

	var events_node = metadata.get("events_node")
	if not events_node:
		return

	var type = metadata.get("type")
	match type:
		"add_event":
			_create_event_at_viewport_click(events_node, popup_menu)
		"add_npc":
			_create_npc_at_viewport_click(events_node, popup_menu)
		"add_trainer":
			_create_trainer_at_viewport_click(events_node, popup_menu)

## Maneja la selección de items del menú del viewport
func _on_viewport_menu_item_selected(id: int, popup_menu: PopupMenu) -> void:
	# Manejar "Editar Evento"
	if id == 2000:
		var item_index = popup_menu.get_item_index(id)
		if item_index >= 0:
			var metadata = popup_menu.get_item_metadata(item_index)
			if metadata and metadata.has("event_node"):
				var event_node = metadata.get("event_node")
				_open_event_editor_deferred(event_node)
		return

	# Manejar "Duplicar"
	if id == 2001:
		var item_index = popup_menu.get_item_index(id)
		if item_index >= 0:
			var metadata = popup_menu.get_item_metadata(item_index)
			if metadata and metadata.has("event_node"):
				var event_node = metadata.get("event_node")
				_duplicate_event_node(event_node)
		return

	# Manejar "Eliminar"
	if id == 2002:
		var item_index = popup_menu.get_item_index(id)
		if item_index >= 0:
			var metadata = popup_menu.get_item_metadata(item_index)
			if metadata and metadata.has("event_node"):
				var event_node = metadata.get("event_node")
				_delete_event_node(event_node)
		return

	# Manejar opciones de añadir (1000-1002)
	if id < 1000 or id > 1002:
		return

	var metadata = popup_menu.get_item_metadata(id - 1000)
	if not metadata or not metadata.has("type"):
		return

	var events_node = metadata.get("events_node")
	if not events_node:
		return

	var type = metadata.get("type")
	match type:
		"add_event":
			_create_event_at_viewport_click(events_node, popup_menu)
		"add_npc":
			_create_npc_at_viewport_click(events_node, popup_menu)
		"add_trainer":
			_create_trainer_at_viewport_click(events_node, popup_menu)

## Obtiene la posición del mouse desde el CanvasItemEditor
func _get_mouse_position_from_canvas_editor(canvas_editor: Node, edited_scene_root: Node) -> Vector2:
	# Intentar obtener la transformación del canvas para convertir coordenadas
	var canvas_transform: Transform2D = Transform2D.IDENTITY

	if canvas_editor.has_method("get_canvas_transform"):
		canvas_transform = canvas_editor.call("get_canvas_transform")

	# El CanvasItemEditor es un Control, podemos obtener su rectángulo
	if not (canvas_editor is Control):
		return Vector2.ZERO

	var canvas_control = canvas_editor as Control

	# Obtener la posición del mouse en la pantalla
	var screen_mouse_pos = DisplayServer.mouse_get_position()

	# Obtener el rectángulo global del CanvasItemEditor
	var editor_global_rect = canvas_control.get_global_rect()
	if editor_global_rect.size.x <= 0 or editor_global_rect.size.y <= 0:
		return Vector2.ZERO

	# Buscar el viewport dentro del CanvasItemEditor para obtener su posición
	# El viewport puede tener un offset dentro del editor que necesitamos considerar
	var viewport_2d = EditorInterface.get_editor_viewport_2d()
	var editor_local_pos: Vector2

	if viewport_2d:
		# Buscar el control que contiene el viewport (SubViewportContainer)
		# El viewport está dentro de un Control que puede tener un offset
		var viewport_control: Control = null
		var parent = viewport_2d.get_parent()
		while parent:
			if parent is Control:
				viewport_control = parent as Control
				break
			parent = parent.get_parent()

		if viewport_control:
			# Obtener la posición del mouse relativa al SubViewportContainer
			var viewport_control_global_rect = viewport_control.get_global_rect()
			var container_local_pos = Vector2(screen_mouse_pos) - viewport_control_global_rect.position

			# El SubViewportContainer puede tener un offset interno (stretch, padding, etc.)
			# Intentar obtener la posición del viewport dentro del container
			# El viewport puede estar centrado o tener un offset
			var viewport_offset = Vector2.ZERO

			# Si el container tiene stretch habilitado, el viewport puede estar centrado
			# Calcular el offset basado en la diferencia de tamaños
			var container_size = viewport_control.size
			var viewport_size = viewport_2d.size

			# Calcular el offset del viewport dentro del container
			if container_size.x > viewport_size.x:
				viewport_offset.x = (container_size.x - viewport_size.x) / 2.0
			if container_size.y > viewport_size.y:
				viewport_offset.y = (container_size.y - viewport_size.y) / 2.0

			# La posición relativa al viewport es la posición en el container menos el offset
			editor_local_pos = container_local_pos - viewport_offset

			print("Event Tools Debug - viewport_control: ", viewport_control.get_class())
			print("Event Tools Debug - container_local_pos: ", container_local_pos)
			print("Event Tools Debug - container_size: ", container_size)
			print("Event Tools Debug - viewport_size: ", viewport_size)
			print("Event Tools Debug - viewport_offset: ", viewport_offset)
			print("Event Tools Debug - editor_local_pos: ", editor_local_pos)
		else:
			# Si no encontramos el control del viewport, usar el editor completo
			editor_local_pos = Vector2(screen_mouse_pos) - editor_global_rect.position
			print("Event Tools Debug - usando editor completo")
	else:
		# Si no hay viewport, usar el editor completo
		editor_local_pos = Vector2(screen_mouse_pos) - editor_global_rect.position

	# Convertir usando la transformación del canvas
	# La transformación del canvas ya incluye zoom y scroll
	var world_pos: Vector2
	if canvas_transform != Transform2D.IDENTITY:
		# Usar la transformación inversa para convertir de editor a escena
		world_pos = canvas_transform.affine_inverse() * editor_local_pos
	else:
		# Sin transformación, usar directamente la posición del editor
		world_pos = editor_local_pos

	# Restar offset de 64px (2 tiles) a la coordenada X
	world_pos.x -= 64.0
	# Restar offset de 176px a la coordenada Y (192 - 16)
	world_pos.y -= 176.0
	print("Event Tools Debug - restando offset de 64px a X y 176px a Y")

	# Convertir a coordenadas locales de la escena editada
	if edited_scene_root is Node2D:
		world_pos = edited_scene_root.to_local(world_pos)

	# Debug temporal - remover después
	print("Event Tools Debug - screen_mouse_pos: ", screen_mouse_pos)
	print("Event Tools Debug - editor_local_pos: ", editor_local_pos)
	print("Event Tools Debug - canvas_transform: ", canvas_transform)
	print("Event Tools Debug - world_pos (antes to_local): ", world_pos if not (edited_scene_root is Node2D) else canvas_transform.affine_inverse() * editor_local_pos)
	print("Event Tools Debug - world_pos (final): ", world_pos)

	return world_pos

## Obtiene la posición del click en el viewport (desde metadata del menú o recalculando)
func _get_viewport_click_position(popup_menu: PopupMenu = null) -> Vector2:
	# Si tenemos la posición guardada en metadata, usarla
	if popup_menu and popup_menu.has_meta("click_position"):
		return popup_menu.get_meta("click_position")

	# Si no, recalcular
	var viewport_2d = EditorInterface.get_editor_viewport_2d()
	if not viewport_2d:
		return Vector2.ZERO

	var edited_scene_root = EditorInterface.get_edited_scene_root()
	if not edited_scene_root:
		return Vector2.ZERO

	var camera = viewport_2d.get_camera_2d()
	if camera:
		var world_pos = camera.get_global_mouse_position()
		if edited_scene_root is Node2D:
			world_pos = edited_scene_root.to_local(world_pos)
		return world_pos

	return Vector2.ZERO

## Redondea una posición a múltiplos de 32px
func _snap_to_grid(pos: Vector2) -> Vector2:
	return Vector2(
		floor(pos.x / 32) * 32,
		floor(pos.y / 32) * 32
	)

## Muestra un diálogo para introducir el nombre del evento/NPC/Trainer
func _show_name_dialog_for_creation(event_type: String, events_node: Node, popup_menu: PopupMenu = null) -> void:
	var world_pos = _get_viewport_click_position(popup_menu)
	var snapped_pos = _snap_to_grid(world_pos)

	# Crear un diálogo para introducir el nombre
	var dialog = AcceptDialog.new()
	var dialog_title = ""
	match event_type:
		"event":
			dialog_title = "Crear Evento"
		"npc":
			dialog_title = "Crear NPC"
		"trainer":
			dialog_title = "Crear Trainer"

	dialog.title = dialog_title
	dialog.dialog_text = "Introduce el nombre:"

	# Ocultar el botón OK por defecto
	dialog.get_ok_button().visible = false

	# Añadir botones personalizados: Aceptar a la izquierda, Cancelar a la derecha
	# En add_button, false = izquierda, true = derecha
	var accept_button = dialog.add_button("Aceptar", false, "accept")
	var cancel_button = dialog.add_button("Cancelar", true, "cancel")

	# Crear un LineEdit para el nombre
	var name_input = LineEdit.new()
	name_input.text = ""
	name_input.placeholder_text = "Nombre"
	name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_input.custom_minimum_size = Vector2(300, 0)

	# Conectar Enter para confirmar el diálogo
	name_input.text_submitted.connect(func(_text: String): dialog.custom_action.emit("accept"))

	# Crear un Label de error (inicialmente oculto)
	var error_label = Label.new()
	error_label.name = "ErrorLabel"
	error_label.text = ""
	error_label.add_theme_color_override("font_color", Color.RED)
	error_label.visible = false
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	error_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	error_label.custom_minimum_size = Vector2(0, 0)
	error_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Limitar el ancho máximo para evitar que el diálogo se expanda demasiado
	error_label.max_lines_visible = 3

	# Crear un VBoxContainer para el contenido
	var content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.custom_minimum_size = Vector2(350, 0)
	content.add_child(Label.new())
	content.get_child(0).text = "Nombre:"
	content.add_child(name_input)
	content.add_child(error_label)

	# Añadir el contenido al diálogo
	dialog.add_child(content)
	EditorInterface.get_base_control().add_child(dialog)

	# Conectar señales
	dialog.custom_action.connect(func(action: String):
		if action == "accept":
			_on_name_dialog_confirmed_for_creation(dialog, name_input, error_label, event_type, events_node, snapped_pos)
		elif action == "cancel":
			dialog.queue_free()
	)

	# Mostrar el diálogo
	dialog.popup_centered(Vector2(400, 150))

	# Enfocar el LineEdit cuando se muestre el diálogo
	await get_tree().process_frame
	name_input.grab_focus()

## Muestra un diálogo de error (usado con call_deferred para evitar conflictos con ventanas modales)
func _show_error_dialog(message: String) -> void:
	var error_dialog = AcceptDialog.new()
	error_dialog.title = "Error"
	error_dialog.dialog_text = message
	EditorInterface.get_base_control().add_child(error_dialog)
	error_dialog.popup_centered(Vector2(400, 100))
	error_dialog.confirmed.connect(func(): error_dialog.queue_free())

## Verifica si ya existe un evento/NPC/Trainer con el nombre especificado en el mapa
func _event_name_exists_in_map(name: String, events_node: Node, exclude_node: Node = null) -> bool:
	if not events_node:
		return false

	# Buscar todos los hijos del nodo Events
	for child in events_node.get_children():
		# Excluir el nodo que estamos modificando (si se proporciona)
		if exclude_node and child == exclude_node:
			continue

		# Verificar si el nombre coincide
		if child.name == name:
			return true

	return false

## Se llama cuando se confirma el diálogo de nombre para crear un evento/NPC/Trainer
func _on_name_dialog_confirmed_for_creation(dialog: AcceptDialog, name_input: LineEdit, error_label: Label, event_type: String, events_node: Node, snapped_pos: Vector2) -> void:
	var new_name = name_input.text.strip_edges()

	# Ocultar el error anterior
	error_label.visible = false
	error_label.text = ""

	if new_name.is_empty():
		# Mostrar error si el nombre está vacío (sin cerrar el diálogo de nombre)
		error_label.text = "El nombre no puede estar vacío."
		error_label.visible = true
		# No cerrar el diálogo de nombre, dejar que el usuario corrija
		return

	# Verificar si ya existe un evento con ese nombre
	if _event_name_exists_in_map(new_name, events_node):
		# Mostrar el error (sin cerrar el diálogo de nombre)
		error_label.text = "Ya existe un evento/NPC/Trainer con el nombre '" + new_name + "' en el mapa."
		error_label.visible = true
		# No cerrar el diálogo de nombre, dejar que el usuario corrija
		return

	# Cerrar el diálogo de nombre solo si todo está bien
	dialog.queue_free()

	# Crear el evento/NPC/Trainer según el tipo
	match event_type:
		"event":
			_create_event_with_name(events_node, snapped_pos, new_name)
		"npc":
			_create_npc_with_name(events_node, snapped_pos, new_name)
		"trainer":
			_create_trainer_with_name(events_node, snapped_pos, new_name)

## Crea un Evento con el nombre especificado y abre el editor
func _create_event_with_name(events_node: Node, snapped_pos: Vector2, event_name: String) -> void:
	var event_scene = load("res://Scenes/Events/Event.tscn")
	if not event_scene:
		push_error("No se pudo cargar la escena Event.tscn")
		return

	var event_instance = event_scene.instantiate()
	if not event_instance:
		push_error("No se pudo instanciar el Event")
		return

	event_instance.name = event_name
	event_instance.position = snapped_pos
	events_node.add_child(event_instance)
	event_instance.owner = events_node.owner if events_node.owner else events_node

	var selection = EditorInterface.get_selection()
	selection.clear()
	selection.add_node(event_instance)
	EditorInterface.mark_scene_as_unsaved()

	# Abrir el editor de eventos
	_open_event_editor_deferred(event_instance)

## Crea un NPC con el nombre especificado y abre el editor
func _create_npc_with_name(events_node: Node, snapped_pos: Vector2, npc_name: String) -> void:
	var npc_scene = load("res://Scenes/Overworld/Actors/NPC.tscn")
	if not npc_scene:
		push_error("No se pudo cargar la escena NPC.tscn")
		return

	var npc_instance = npc_scene.instantiate()
	if not npc_instance:
		push_error("No se pudo instanciar el NPC")
		return

	npc_instance.name = npc_name
	npc_instance.position = snapped_pos
	events_node.add_child(npc_instance)
	npc_instance.owner = events_node.owner if events_node.owner else events_node

	var selection = EditorInterface.get_selection()
	selection.clear()
	selection.add_node(npc_instance)
	EditorInterface.mark_scene_as_unsaved()

	# Abrir el editor de eventos (NPCs también usan el editor de eventos)
	_open_event_editor_deferred(npc_instance)

## Crea un Trainer con el nombre especificado y abre el editor
func _create_trainer_with_name(events_node: Node, snapped_pos: Vector2, trainer_name: String) -> void:
	var trainer_scene = load("res://Scenes/Overworld/Actors/Trainer.tscn")
	if not trainer_scene:
		push_error("No se pudo cargar la escena Trainer.tscn")
		return

	var trainer_instance = trainer_scene.instantiate()
	if not trainer_instance:
		push_error("No se pudo instanciar el Trainer")
		return

	trainer_instance.name = trainer_name
	trainer_instance.position = snapped_pos
	events_node.add_child(trainer_instance)
	trainer_instance.owner = events_node.owner if events_node.owner else events_node

	var selection = EditorInterface.get_selection()
	selection.clear()
	selection.add_node(trainer_instance)
	EditorInterface.mark_scene_as_unsaved()

	# Abrir el editor de eventos (Trainers también usan el editor de eventos)
	_open_event_editor_deferred(trainer_instance)

## Crea un Evento en la posición del click
func _create_event_at_viewport_click(events_node: Node, popup_menu: PopupMenu = null) -> void:
	_show_name_dialog_for_creation("event", events_node, popup_menu)

## Crea un NPC en la posición del click
func _create_npc_at_viewport_click(events_node: Node, popup_menu: PopupMenu = null) -> void:
	_show_name_dialog_for_creation("npc", events_node, popup_menu)

## Crea un Trainer en la posición del click
func _create_trainer_at_viewport_click(events_node: Node, popup_menu: PopupMenu = null) -> void:
	_show_name_dialog_for_creation("trainer", events_node, popup_menu)

## Duplica un nodo Event
func _duplicate_event_node(event_node: Node) -> void:
	if not event_node or not _is_event_node(event_node):
		return

	var parent = event_node.get_parent()
	if not parent:
		return

	# Usar el sistema de deshacer/rehacer de Godot
	var undo_redo = get_undo_redo()

	# Duplicar el nodo
	var duplicated_node = event_node.duplicate()
	if not duplicated_node:
		push_error("Event Tools: No se pudo duplicar el nodo")
		return

	# Generar un nombre único para el nodo duplicado (estilo Godot)
	var new_name = _generate_unique_name_godot_style(event_node.name, parent)
	duplicated_node.name = new_name

	# Crear acción de deshacer/rehacer
	undo_redo.create_action("Duplicar Evento")

	# Acción de hacer: añadir el nodo duplicado
	undo_redo.add_do_method(parent, "add_child", duplicated_node)
	undo_redo.add_do_method(duplicated_node, "set_owner", EditorInterface.get_edited_scene_root())
	undo_redo.add_do_property(duplicated_node, "name", new_name)
	undo_redo.add_do_reference(duplicated_node)

	# Acción de deshacer: eliminar el nodo duplicado
	undo_redo.add_undo_method(parent, "remove_child", duplicated_node)
	undo_redo.add_undo_reference(duplicated_node)
	undo_redo.add_undo_method(duplicated_node, "queue_free")

	# Ejecutar la acción
	undo_redo.commit_action()

	# Seleccionar el nodo duplicado
	var selection = EditorInterface.get_selection()
	if selection:
		selection.clear()
		selection.add_node(duplicated_node)

## Elimina un nodo Event
func _delete_event_node(event_node: Node) -> void:
	if not event_node or not _is_event_node(event_node):
		return

	# Mostrar diálogo de confirmación
	var dialog = AcceptDialog.new()
	dialog.title = "Eliminar Evento"
	dialog.dialog_text = "¿Estás seguro de que deseas eliminar el evento '" + event_node.name + "'?"

	# Ocultar el botón OK por defecto
	dialog.get_ok_button().visible = false

	# Añadir botones personalizados
	var accept_button = dialog.add_button("Eliminar", false, "accept")
	var cancel_button = dialog.add_button("Cancelar", true, "cancel")

	EditorInterface.get_base_control().add_child(dialog)

	# Conectar señales
	dialog.custom_action.connect(func(action: String):
		if action == "accept":
			# Usar el sistema de deshacer/rehacer de Godot
			var undo_redo = get_undo_redo()
			var parent = event_node.get_parent()
			if parent:
				# Crear acción de deshacer/rehacer
				undo_redo.create_action("Eliminar Evento")

				# Guardar información para poder restaurar
				var node_name = event_node.name
				var node_owner = event_node.owner
				var node_index = event_node.get_index()

				# Duplicar el nodo completo para poder restaurarlo
				var node_copy = event_node.duplicate(true)

				# Acción de hacer: eliminar el nodo
				undo_redo.add_do_method(parent, "remove_child", event_node)
				undo_redo.add_do_reference(event_node)
				undo_redo.add_do_method(event_node, "queue_free")

				# Acción de deshacer: restaurar el nodo
				undo_redo.add_undo_method(parent, "add_child", node_copy)
				undo_redo.add_undo_method(parent, "move_child", node_copy, node_index)
				undo_redo.add_undo_method(node_copy, "set_owner", node_owner)
				undo_redo.add_undo_property(node_copy, "name", node_name)
				undo_redo.add_undo_reference(node_copy)

				# Ejecutar la acción
				undo_redo.commit_action()

				# Marcar la escena como modificada
				EditorInterface.mark_scene_as_unsaved()
		dialog.queue_free()
	)

	dialog.popup_centered(Vector2(400, 150))

## Genera un nombre único al estilo de Godot para duplicados
## Si el nombre es "Chico", genera "Chico2"
## Si el nombre es "Chico1", genera "Chico2"
## Si el nombre es "Chico2", genera "Chico3", etc.
func _generate_unique_name_godot_style(original_name: String, parent: Node) -> String:
	var base_name = original_name
	var start_number = 2

	# Verificar si el nombre termina en un número
	var regex = RegEx.new()
	regex.compile("^(.*?)(\\d+)$")
	var result = regex.search(original_name)

	if result:
		# El nombre termina en número, extraer base y número
		base_name = result.get_string(1)
		var number_str = result.get_string(2)
		var number = number_str.to_int()
		if number > 0:
			start_number = number + 1

	# Buscar el siguiente número disponible
	var counter = start_number
	var new_name = base_name + str(counter)
	while parent.get_node_or_null(NodePath(new_name)) != null:
		counter += 1
		new_name = base_name + str(counter)

	return new_name

