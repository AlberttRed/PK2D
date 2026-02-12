@tool
extends EditorContextMenuPlugin

## Plugin de editor que añade la opción "Editar Pokémon" al menú contextual
## cuando se hace clic derecho sobre un archivo .tres de PokemonData

var pokemon_editor_scene: PackedScene = null
var database_editor_window: Window = null

func _enter_tree() -> void:
	print("[PokemonContextMenu] _enter_tree() llamado")
	# Cargar la escena del editor de Pokémon
	pokemon_editor_scene = load("res://addons/database_editor/pokemon_editor_window.tscn")
	if not pokemon_editor_scene:
		push_error("[PokemonContextMenu] No se pudo cargar pokemon_editor_window.tscn")

## Se llama cuando se muestra el menú contextual
## paths: Array de rutas de los archivos/nodos seleccionados
func _popup_menu(paths: PackedStringArray) -> void:
	print("[PokemonContextMenu] _popup_menu llamado con %d paths" % paths.size())

	if paths.is_empty():
		print("[PokemonContextMenu] No hay paths, saliendo")
		return

	# Solo procesar si hay exactamente un archivo seleccionado
	if paths.size() != 1:
		print("[PokemonContextMenu] Hay %d paths, se necesita exactamente 1" % paths.size())
		return

	var file_path: String = paths[0]
	print("[PokemonContextMenu] Procesando archivo: %s" % file_path)

	# Verificar que es un archivo .tres
	if not file_path.ends_with(".tres"):
		print("[PokemonContextMenu] No es un archivo .tres")
		return

	# Verificar que el archivo existe
	if not ResourceLoader.exists(file_path):
		print("[PokemonContextMenu] El archivo no existe: %s" % file_path)
		return

	# Intentar cargar el recurso para verificar que es un PokemonData
	var resource = load(file_path)
	if not resource:
		print("[PokemonContextMenu] No se pudo cargar el recurso: %s" % file_path)
		return

	print("[PokemonContextMenu] Recurso cargado, tipo: %s" % resource.get_class())

	# Verificar que es un PokemonData
	if not (resource is PokemonData):
		print("[PokemonContextMenu] No es un PokemonData, es: %s" % resource.get_class())
		return

	# Añadir la opción al menú contextual como primera opción
	# Usar un ID alto para que aparezca primero
	print("[PokemonContextMenu] ✓ Añadiendo opción 'Editar Pokémon' para: %s" % file_path)
	add_context_menu_item("Editar Pokémon", _on_edit_pokemon_selected.bind(file_path))

## Se llama cuando se selecciona la opción "Editar Pokémon"
func _on_edit_pokemon_selected(file_path: String) -> void:
	print("[PokemonContextMenu] Editando Pokémon: %s" % file_path)

	if not pokemon_editor_scene:
		push_error("[PokemonContextMenu] No se pudo cargar pokemon_editor_window.tscn")
		return

	# Cargar el PokemonData
	var pokemon_data = load(file_path) as PokemonData
	if not pokemon_data:
		push_error("[PokemonContextMenu] No se pudo cargar PokemonData desde: %s" % file_path)
		return

	# Buscar si hay una ventana de DatabaseEditor abierta para obtener el callback de refresco
	var refresh_callback := Callable()
	var base_control := EditorInterface.get_base_control()

	# Buscar la ventana DatabaseEditor en los hijos del base_control
	# La ventana puede tener cualquier nombre, así que buscamos por el script
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
		push_error("[PokemonContextMenu] No se pudo instanciar PokemonEditorWindow")
		return

	# Añadir como hijo del base_control
	base_control.add_child(editor)

	# Abrir en modo Edit
	if editor.has_method("open_edit"):
		editor.open_edit(pokemon_data, refresh_callback)
		editor.popup_centered(Vector2i(900, 800))
	else:
		push_error("[PokemonContextMenu] El editor no tiene el método open_edit")
		editor.queue_free()

