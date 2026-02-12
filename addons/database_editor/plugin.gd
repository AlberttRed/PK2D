@tool
extends EditorPlugin

## Plugin principal de Database Editor
## Añade la opción "Database Editor" al menú de herramientas del editor

var database_editor_scene: PackedScene = null
var pokemon_editor_scene: PackedScene = null
var move_editor_scene: PackedScene = null

func _enter_tree() -> void:
	# Cargar la escena del editor
	database_editor_scene = load("res://addons/database_editor/database_editor.tscn")
	if not database_editor_scene:
		push_error("Database Editor: No se pudo cargar database_editor.tscn")
		return

	# Cargar la escena del editor de Pokémon
	pokemon_editor_scene = load("res://addons/database_editor/pokemon_editor_window.tscn")
	if not pokemon_editor_scene:
		push_error("Database Editor: No se pudo cargar pokemon_editor_window.tscn")

	# Cargar la escena del editor de Movimientos
	# Esperar un frame para asegurar que los recursos estén disponibles
	await get_tree().process_frame
	var move_editor_path := "res://addons/database_editor/move_editor_window.tscn"
	if not ResourceLoader.exists(move_editor_path):
		push_error("Database Editor: El archivo move_editor_window.tscn no existe en: %s" % move_editor_path)
	else:
		move_editor_scene = load(move_editor_path)
		if not move_editor_scene:
			push_error("Database Editor: No se pudo cargar move_editor_window.tscn desde: %s" % move_editor_path)
		else:
			print("[DatabaseEditor Plugin] ✓ move_editor_window.tscn cargado correctamente")

	# Añadir al menú de herramientas
	add_tool_menu_item("Database Editor", _open_database_editor)

	# Conectar a los menús contextuales del FileSystem
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_connect_to_filesystem_menus(EditorInterface.get_base_control())

func _exit_tree() -> void:
	remove_tool_menu_item("Database Editor")
	_disconnect_from_filesystem_menus(EditorInterface.get_base_control())
	database_editor_scene = null
	pokemon_editor_scene = null
	move_editor_scene = null

## Abre la ventana del Database Editor
func _open_database_editor() -> void:
	if not database_editor_scene:
		push_error("Database Editor: La escena no está cargada")
		return

	var window = database_editor_scene.instantiate()
	if not window:
		push_error("Database Editor: No se pudo instanciar la ventana")
		return

	EditorInterface.get_base_control().add_child(window)
	window.popup_centered(Vector2i(1200, 800))

## Conecta recursivamente a todos los PopupMenu del FileSystem dock
func _connect_to_filesystem_menus(node: Node) -> void:
	if node is PopupMenu:
		var popup = node as PopupMenu
		if not popup.about_to_popup.is_connected(_on_filesystem_menu_about_to_show):
			popup.about_to_popup.connect(_on_filesystem_menu_about_to_show.bind(popup))
			print("[DatabaseEditor Plugin] Conectado a PopupMenu: %s" % popup.name)

	for child in node.get_children():
		_connect_to_filesystem_menus(child)

## Desconecta de todos los PopupMenu del FileSystem dock
func _disconnect_from_filesystem_menus(node: Node) -> void:
	if node is PopupMenu:
		var popup = node as PopupMenu
		if popup.about_to_popup.is_connected(_on_filesystem_menu_about_to_show):
			popup.about_to_popup.disconnect(_on_filesystem_menu_about_to_show)

	for child in node.get_children():
		_disconnect_from_filesystem_menus(child)

## Verifica si un PopupMenu es del FileSystem dock
func _is_filesystem_menu(popup_menu: PopupMenu) -> bool:
	var parent = popup_menu.get_parent()
	var depth = 0

	while parent and depth < 10:  # Aumentar profundidad
		var name_lower = parent.name.to_lower()
		var node_class = parent.get_class()

		# Verificar si es el FileSystem dock
		if "filesystem" in name_lower or "file_system" in name_lower or "FileSystem" in node_class:
			print("[DatabaseEditor Plugin] Es un menú del FileSystem (profundidad %d, nombre: %s, clase: %s)" % [depth, parent.name, node_class])
			return true

		# Excluir otros docks
		if "scenetree" in name_lower or "scene_tree" in name_lower:
			return false
		if "inspector" in name_lower and "filesystem" not in name_lower:
			return false

		parent = parent.get_parent()
		depth += 1

	return false

## Se llama cuando un menú contextual del FileSystem está a punto de mostrarse
func _on_filesystem_menu_about_to_show(popup_menu: PopupMenu) -> void:
	print("[DatabaseEditor Plugin] _on_filesystem_menu_about_to_show llamado para: %s" % popup_menu.name)

	if not _is_filesystem_menu(popup_menu):
		return

	print("[DatabaseEditor Plugin] Es un menú del FileSystem, items: %d" % popup_menu.get_item_count())

	# Intentar obtener los archivos seleccionados directamente
	var selected_paths := _get_selected_filesystem_paths()
	print("[DatabaseEditor Plugin] Archivos seleccionados: %s" % selected_paths)

	if selected_paths.is_empty():
		# Si no podemos obtener los paths directamente, intentar desde el EditorFileSystem
		var filesystem = EditorInterface.get_resource_filesystem()
		if filesystem:
			# El EditorFileSystem no tiene un método directo para obtener la selección
			# Intentar buscar en el árbol de nodos del FileSystem dock
			selected_paths = _get_selected_paths_from_dock()
			print("[DatabaseEditor Plugin] Archivos seleccionados (desde dock): %s" % selected_paths)

	if selected_paths.is_empty() or selected_paths.size() != 1:
		return

	var file_path: String = selected_paths[0]
	print("[DatabaseEditor Plugin] Procesando archivo: %s" % file_path)

	# Verificar que es un archivo .tres
	if not file_path.ends_with(".tres"):
		return

	# Verificar que el archivo existe
	if not ResourceLoader.exists(file_path):
		return

	# Intentar cargar el recurso para verificar que es un PokemonData
	var resource = load(file_path)
	if not resource:
		return

	print("[DatabaseEditor Plugin] Recurso cargado, tipo: %s" % resource.get_class())

	# Verificar que es un PokemonData o MoveData
	if resource is PokemonData:
		print("[DatabaseEditor Plugin] ✓ Es un PokemonData, añadiendo opción al menú")
		# Añadir "Editar Pokémon" al principio del menú
		_add_edit_pokemon_to_menu(popup_menu, file_path)
	elif resource is MoveData:
		print("[DatabaseEditor Plugin] ✓ Es un MoveData, añadiendo opción al menú")
		# Añadir "Editar Movimiento" al principio del menú
		_add_edit_move_to_menu(popup_menu, file_path)

## Obtiene los archivos seleccionados del FileSystem dock
func _get_selected_filesystem_paths() -> PackedStringArray:
	var selected_paths := PackedStringArray()

	# Intentar obtener la selección desde el FileSystem dock
	var base_control = EditorInterface.get_base_control()
	var filesystem_dock = _find_filesystem_dock(base_control)

	if filesystem_dock:
		print("[DatabaseEditor Plugin] FileSystem dock encontrado: %s" % filesystem_dock.name)
		# Intentar obtener la selección desde el dock
		if filesystem_dock.has_method("get_selected_paths"):
			selected_paths = filesystem_dock.get_selected_paths()
			print("[DatabaseEditor Plugin] Usando get_selected_paths()")
		elif filesystem_dock.has_method("get_selected"):
			var selected = filesystem_dock.get_selected()
			if selected is Array:
				for path in selected:
					if path is String:
						selected_paths.append(path)
			print("[DatabaseEditor Plugin] Usando get_selected()")
		else:
			print("[DatabaseEditor Plugin] FileSystem dock no tiene métodos conocidos, buscando Tree")
			# Intentar buscar un Tree dentro del dock
			selected_paths = _get_selected_paths_from_dock()
	else:
		print("[DatabaseEditor Plugin] FileSystem dock no encontrado")

	return selected_paths

## Intenta obtener los paths seleccionados buscando en el árbol del FileSystem dock
func _get_selected_paths_from_dock() -> PackedStringArray:
	var selected_paths := PackedStringArray()
	var base_control = EditorInterface.get_base_control()
	var filesystem_dock = _find_filesystem_dock(base_control)

	if not filesystem_dock:
		return selected_paths

	# Buscar un Tree dentro del dock
	var tree = _find_node_by_class(filesystem_dock, "Tree")
	if tree:
		print("[DatabaseEditor Plugin] Tree encontrado en FileSystem dock")
		if tree.has_method("get_selected"):
			var selected = tree.get_selected()
			if selected:
				# Intentar obtener el path desde el TreeItem
				var path = selected.get_metadata(0)
				if path is String:
					selected_paths.append(path)
					print("[DatabaseEditor Plugin] Path obtenido desde Tree: %s" % path)

	return selected_paths

## Busca un nodo por su clase en el árbol
func _find_node_by_class(node: Node, target_class: String) -> Node:
	if node.get_class() == target_class:
		return node

	for child in node.get_children():
		var result = _find_node_by_class(child, target_class)
		if result:
			return result

	return null

## Busca el FileSystem dock en el árbol de nodos
func _find_filesystem_dock(node: Node) -> Node:
	if node == null:
		return null

	var name_lower = node.name.to_lower()
	var node_class = node.get_class()

	# Verificar si es el FileSystem dock
	if "filesystem" in name_lower or "file_system" in name_lower or "FileSystem" in node_class:
		return node

	# Buscar recursivamente en los hijos
	for child in node.get_children():
		var result = _find_filesystem_dock(child)
		if result:
			return result

	return null

## Añade "Editar Pokémon" al principio del menú
func _add_edit_pokemon_to_menu(popup_menu: PopupMenu, file_path: String) -> void:
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
			"metadata": popup_menu.get_item_metadata(i),
			"id": popup_menu.get_item_id(i)
		})

	# Reconstruir menú con "Editar Pokémon" al principio
	popup_menu.clear()
	popup_menu.add_item("Editar Pokémon", 99999)
	popup_menu.set_item_metadata(0, file_path)
	popup_menu.add_separator()

	# Restaurar items originales
	for item in items:
		if item.is_separator:
			popup_menu.add_separator()
		elif item.submenu != "":
			popup_menu.add_submenu_item(item.text, item.submenu)
		else:
			var item_id = item.id if item.id >= 0 else popup_menu.get_item_count()
			popup_menu.add_item(item.text, item_id)
			var item_idx = popup_menu.get_item_count() - 1
			if item.icon:
				popup_menu.set_item_icon(item_idx, item.icon)
			if item.is_disabled:
				popup_menu.set_item_disabled(item_idx, true)
			if item.metadata != null:
				popup_menu.set_item_metadata(item_idx, item.metadata)

	# Conectar señal si no está conectada
	if not popup_menu.id_pressed.is_connected(_on_filesystem_menu_item_selected):
		popup_menu.id_pressed.connect(_on_filesystem_menu_item_selected.bind(popup_menu))

## Maneja la selección de items del menú contextual del FileSystem
func _on_filesystem_menu_item_selected(id: int, popup_menu: PopupMenu) -> void:
	if id == 99999:  # "Editar Pokémon" o "Editar Movimiento"
		var file_path: String = popup_menu.get_item_metadata(0)
		var item_text: String = popup_menu.get_item_text(0)

		if item_text == "Editar Pokémon":
			_open_pokemon_editor_from_file(file_path)
		elif item_text == "Editar Movimiento":
			_open_move_editor_from_file(file_path)

## Abre el editor de Pokémon desde un archivo
func _open_pokemon_editor_from_file(file_path: String) -> void:
	if not pokemon_editor_scene:
		push_error("Database Editor: No se pudo cargar pokemon_editor_window.tscn")
		return

	# Cargar el PokemonData
	var pokemon_data = load(file_path) as PokemonData
	if not pokemon_data:
		push_error("Database Editor: No se pudo cargar PokemonData desde: %s" % file_path)
		return

	# Buscar si hay una ventana de DatabaseEditor abierta para obtener el callback de refresco
	var refresh_callback := Callable()
	var base_control := EditorInterface.get_base_control()

	# Buscar la ventana DatabaseEditor en los hijos del base_control
	for child in base_control.get_children():
		if child is Window:
			var script = child.get_script()
			if script and script.resource_path.ends_with("database_editor.gd"):
				# Si tiene el método _refresh_pokemon_tab, usarlo como callback
				if child.has_method("_refresh_pokemon_tab"):
					refresh_callback = child._refresh_pokemon_tab
				break

	# Instanciar y mostrar el editor
	var editor = pokemon_editor_scene.instantiate()
	if not editor:
		push_error("Database Editor: No se pudo instanciar PokemonEditorWindow")
		return

	# Añadir como hijo del base_control
	base_control.add_child(editor)

	# Abrir en modo Edit
	if editor.has_method("open_edit"):
		editor.open_edit(pokemon_data, refresh_callback)
		editor.popup_centered(Vector2i(900, 800))
	else:
		push_error("Database Editor: El editor no tiene el método open_edit")
		editor.queue_free()

## Añade "Editar Movimiento" al principio del menú
func _add_edit_move_to_menu(popup_menu: PopupMenu, file_path: String) -> void:
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
			"metadata": popup_menu.get_item_metadata(i),
			"id": popup_menu.get_item_id(i)
		})

	# Reconstruir menú con "Editar Movimiento" al principio
	popup_menu.clear()
	popup_menu.add_item("Editar Movimiento", 99999)
	popup_menu.set_item_metadata(0, file_path)
	popup_menu.add_separator()

	# Restaurar items originales
	for item in items:
		if item.is_separator:
			popup_menu.add_separator()
		elif item.submenu != "":
			popup_menu.add_submenu_item(item.text, item.submenu)
		else:
			var item_id = item.id if item.id >= 0 else popup_menu.get_item_count()
			popup_menu.add_item(item.text, item_id)
			var item_idx = popup_menu.get_item_count() - 1
			if item.icon:
				popup_menu.set_item_icon(item_idx, item.icon)
			if item.is_disabled:
				popup_menu.set_item_disabled(item_idx, true)
			if item.metadata != null:
				popup_menu.set_item_metadata(item_idx, item.metadata)

	# Conectar señal si no está conectada
	if not popup_menu.id_pressed.is_connected(_on_filesystem_menu_item_selected):
		popup_menu.id_pressed.connect(_on_filesystem_menu_item_selected.bind(popup_menu))

## Abre el editor de Movimientos desde un archivo
func _open_move_editor_from_file(file_path: String) -> void:
	if not move_editor_scene:
		# Intentar cargar de nuevo si no está cargado
		var move_editor_path := "res://addons/database_editor/move_editor_window.tscn"
		if ResourceLoader.exists(move_editor_path):
			move_editor_scene = load(move_editor_path)
			print("[DatabaseEditor Plugin] Reintentando cargar move_editor_window.tscn: %s" % ("✓ OK" if move_editor_scene else "✗ FALLO"))

		if not move_editor_scene:
			push_error("Database Editor: No se pudo cargar move_editor_window.tscn")
			return

	# Cargar el MoveData
	var move_data = load(file_path) as MoveData
	if not move_data:
		push_error("Database Editor: No se pudo cargar MoveData desde: %s" % file_path)
		return

	# Buscar si hay una ventana de DatabaseEditor abierta para obtener el callback de refresco
	var refresh_callback := Callable()
	var base_control := EditorInterface.get_base_control()

	# Buscar la ventana DatabaseEditor en los hijos del base_control
	for child in base_control.get_children():
		if child is Window:
			var script = child.get_script()
			if script and script.resource_path.ends_with("database_editor.gd"):
				# Si tiene el método _refresh_move_tab, usarlo como callback
				if child.has_method("_refresh_move_tab"):
					refresh_callback = child._refresh_move_tab
				break

	# Instanciar y mostrar el editor
	var editor = move_editor_scene.instantiate()
	if not editor:
		push_error("Database Editor: No se pudo instanciar MoveEditorWindow")
		return

	# Añadir como hijo del base_control
	base_control.add_child(editor)

	# Abrir en modo Edit
	if editor.has_method("open_edit"):
		editor.open_edit(move_data, refresh_callback)
		editor.popup_centered(Vector2i(700, 600))
	else:
		push_error("Database Editor: El editor no tiene el método open_edit")
		editor.queue_free()
