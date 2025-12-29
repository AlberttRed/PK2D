@tool
extends EditorContextMenuPlugin

## Plugin de editor que añade opciones para crear Eventos, NPCs y Trainers
## desde el menú contextual del viewport

const CELL_SIZE = 32  # Tamaño de celda del grid en píxeles

func _enter_tree() -> void:
	print("Viewport Context Menu: _enter_tree() llamado")
	# Los EditorContextMenuPlugin se detectan automáticamente
	# No establecer slot específico - el plugin se aplicará a todos los contextos
	# Filtreremos en _popup_menu según el contexto

## Se llama cuando se muestra el menú contextual del viewport
## paths: Array de rutas de los nodos seleccionados (vacío si se hace click en el viewport vacío)
func _popup_menu(paths: PackedStringArray) -> void:
	print("Viewport Context Menu: _popup_menu llamado con paths: ", paths)

	# Solo mostrar si no hay nodos seleccionados (click en el viewport vacío)
	if paths.size() > 0:
		print("Viewport Context Menu: Hay nodos seleccionados, saliendo")
		return

	# Verificar que hay una escena abierta
	var edited_scene_root = EditorInterface.get_edited_scene_root()
	if not edited_scene_root:
		print("Viewport Context Menu: No hay escena abierta")
		return

	# Buscar el nodo "Events" en la escena
	var events_node = _find_events_node(edited_scene_root)
	if not events_node:
		print("Viewport Context Menu: No se encontró el nodo Events")
		return

	print("Viewport Context Menu: Añadiendo opciones al menú")
	# Añadir opciones al menú
	add_context_menu_item("Añadir Evento", _on_add_event.bind(events_node))
	add_context_menu_item("Añadir NPC", _on_add_npc.bind(events_node))
	add_context_menu_item("Añadir Trainer", _on_add_trainer.bind(events_node))

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

## Obtiene la posición del click en el viewport y la convierte a coordenadas del mundo
func _get_click_world_position() -> Vector2:
	# Obtener el viewport 2D del editor
	var viewport_2d = EditorInterface.get_editor_viewport_2d()
	if not viewport_2d:
		return Vector2.ZERO

	# Obtener la escena editada
	var edited_scene_root = EditorInterface.get_edited_scene_root()
	if not edited_scene_root:
		return Vector2.ZERO

	# Obtener la posición del mouse en coordenadas del viewport
	var mouse_pos = viewport_2d.get_global_mouse_position()

	# Convertir a coordenadas locales de la escena
	# El viewport puede tener una cámara, necesitamos convertir correctamente
	var camera = viewport_2d.get_camera_2d()
	if camera:
		# Si hay cámara, usar su método para obtener la posición del mundo
		var world_pos = camera.get_global_mouse_position()
		# Convertir a coordenadas locales de la escena editada
		if edited_scene_root is Node2D:
			world_pos = edited_scene_root.to_local(world_pos)
		return world_pos
	else:
		# Sin cámara, convertir directamente desde el viewport
		# La posición del mouse en el viewport ya está en coordenadas del mundo
		# pero necesitamos convertirla a coordenadas locales de la escena
		var world_pos = viewport_2d.get_global_mouse_position()
		if edited_scene_root is Node2D:
			world_pos = edited_scene_root.to_local(world_pos)
		return world_pos

## Busca un viewport recursivamente
func _find_viewport_recursive(node: Node) -> Viewport:
	if node is Viewport:
		return node as Viewport

	for child in node.get_children():
		var result = _find_viewport_recursive(child)
		if result:
			return result

	return null

## Redondea una posición a múltiplos de CELL_SIZE
func _snap_to_grid(pos: Vector2) -> Vector2:
	return Vector2(
		floor(pos.x / CELL_SIZE) * CELL_SIZE,
		floor(pos.y / CELL_SIZE) * CELL_SIZE
	)

## Crea un Evento en la posición del click
func _on_add_event(events_node: Node) -> void:
	var world_pos = _get_click_world_position()
	var snapped_pos = _snap_to_grid(world_pos)

	# Cargar la escena del Event
	var event_scene = load("res://Scenes/Events/Event.tscn")
	if not event_scene:
		push_error("No se pudo cargar la escena Event.tscn")
		return

	# Crear instancia del Event
	var event_instance = event_scene.instantiate()
	if not event_instance:
		push_error("No se pudo instanciar el Event")
		return

	# Posicionar el evento
	event_instance.position = snapped_pos

	# Añadir como hijo del nodo Events
	events_node.add_child(event_instance)
	event_instance.owner = events_node.owner if events_node.owner else events_node

	# Seleccionar el nuevo nodo
	var selection = EditorInterface.get_selection()
	selection.clear()
	selection.add_node(event_instance)

	# Marcar la escena como modificada
	EditorInterface.mark_scene_as_unsaved()

## Crea un NPC en la posición del click
func _on_add_npc(events_node: Node) -> void:
	var world_pos = _get_click_world_position()
	var snapped_pos = _snap_to_grid(world_pos)

	# Cargar la escena del NPC
	var npc_scene = load("res://Scenes/Overworld/Actors/NPC.tscn")
	if not npc_scene:
		push_error("No se pudo cargar la escena NPC.tscn")
		return

	# Crear instancia del NPC
	var npc_instance = npc_scene.instantiate()
	if not npc_instance:
		push_error("No se pudo instanciar el NPC")
		return

	# Posicionar el NPC
	npc_instance.position = snapped_pos

	# Añadir como hijo del nodo Events
	events_node.add_child(npc_instance)
	npc_instance.owner = events_node.owner if events_node.owner else events_node

	# Seleccionar el nuevo nodo
	var selection = EditorInterface.get_selection()
	selection.clear()
	selection.add_node(npc_instance)

	# Marcar la escena como modificada
	EditorInterface.mark_scene_as_unsaved()

## Crea un Trainer en la posición del click
func _on_add_trainer(events_node: Node) -> void:
	var world_pos = _get_click_world_position()
	var snapped_pos = _snap_to_grid(world_pos)

	# Cargar la escena del Trainer
	var trainer_scene = load("res://Scenes/Overworld/Actors/Trainer.tscn")
	if not trainer_scene:
		push_error("No se pudo cargar la escena Trainer.tscn")
		return

	# Crear instancia del Trainer
	var trainer_instance = trainer_scene.instantiate()
	if not trainer_instance:
		push_error("No se pudo instanciar el Trainer")
		return

	# Posicionar el Trainer
	trainer_instance.position = snapped_pos

	# Añadir como hijo del nodo Events
	events_node.add_child(trainer_instance)
	trainer_instance.owner = events_node.owner if events_node.owner else events_node

	# Seleccionar el nuevo nodo
	var selection = EditorInterface.get_selection()
	selection.clear()
	selection.add_node(trainer_instance)

	# Marcar la escena como modificada
	EditorInterface.mark_scene_as_unsaved()

