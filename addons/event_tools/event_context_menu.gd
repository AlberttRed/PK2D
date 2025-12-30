@tool
extends EditorContextMenuPlugin

## Plugin de editor que añade la opción "Edit Event" al menú contextual
## del SceneTree cuando se selecciona un nodo de tipo Event

var popup_scene: PackedScene = null

func _enter_tree() -> void:
	print("Event Tools: EditorContextMenuPlugin _enter_tree() llamado")
	# Intentar establecer el slot del menú contextual
	# Nota: Este método puede no existir en todas las versiones
	if has_method("set_context_menu_slot"):
		call("set_context_menu_slot", CONTEXT_SLOT_SCENE_TREE)
		print("Event Tools: Context menu slot establecido")

## Carga el popup de forma lazy
func _get_popup_scene() -> PackedScene:
	if not popup_scene:
		popup_scene = load("res://addons/event_tools/event_editor_popup.tscn")
		if not popup_scene:
			push_error("Event Tools: No se pudo cargar event_editor_popup.tscn")
	return popup_scene

## Se llama cuando se muestra el menú contextual del SceneTree
## paths: Array de rutas de los nodos seleccionados
func _popup_menu(paths: PackedStringArray) -> void:
	print("Event Tools: _popup_menu llamado con paths: ", paths)

	# Obtener la selección del editor usando EditorInterface
	var selection = EditorInterface.get_selection()
	var selected_nodes = selection.get_selected_nodes()

	print("Event Tools: Nodos seleccionados: ", selected_nodes.size())

	# Solo mostrar si hay exactamente un nodo seleccionado
	if selected_nodes.size() != 1:
		print("Event Tools: No hay exactamente un nodo seleccionado, saliendo")
		return

	var node = selected_nodes[0]
	print("Event Tools: Nodo seleccionado: ", node.name, " - Es Event: ", _is_event_node(node))

	# Verificar si el nodo es de tipo Event
	if _is_event_node(node):
		# Añadir la opción al menú contextual
		print("Event Tools: Añadiendo opción 'Edit Event' al menú")
		add_context_menu_item("Edit Event", _on_edit_event_selected.bind(node))
	else:
		print("Event Tools: El nodo no es un Event")

## Se llama cuando se selecciona la opción "Edit Event"
func _on_edit_event_selected(event_node: Node) -> void:
	if not event_node:
		return

	var scene = _get_popup_scene()
	if not scene:
		push_error("Event Tools: El popup no está disponible")
		return

	# Instanciar y mostrar el popup
	var popup = scene.instantiate()
	if popup and popup.has_method("open_for_event"):
		EditorInterface.get_base_control().add_child(popup)
		popup.open_for_event(event_node)
		popup.popup_centered()
	else:
		push_error("Event Tools: El popup no tiene el método open_for_event")

## Verifica si un nodo es de tipo Event
func _is_event_node(node: Node) -> bool:
	if not node:
		return false

	# Verificar si el nodo tiene el script Event.gd, NPC.gd o Trainer.gd
	var script = node.get_script()
	if script:
		var script_path = script.resource_path
		var script_class = script.get_global_name()

		# Verificar si es de clase Event, NPC o Trainer usando class_name
		if script_class == "Event" or script_class == "NPC" or script_class == "Trainer":
			return true

		# Verificar por ruta del script
		if script_path.ends_with("Event.gd") or script_path.ends_with("NPC.gd") or script_path.ends_with("Trainer.gd"):
			return true

	# Verificar si el nodo tiene métodos característicos de Event
	# (método alternativo para detectar Events)
	if node.has_method("trigger") and node.has_method("setup_current_page"):
		return true

	return false

