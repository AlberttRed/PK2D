@tool
extends Window

## Ventana de edición para WarpCommand
## Permite editar todas las propiedades export del comando

signal command_edited(command: WarpCommand)
signal cancelled

var command: WarpCommand = null
var _event_node: Node = null  # Referencia al evento para obtener el mapa actual

## Setter para event_node que actualiza el dropdown cuando se asigna
var event_node: Node:
	get:
		return _event_node
	set(value):
		_event_node = value
		if actor_name_option:
			_populate_actor_names()
			if command:
				_update_actor_selection()
		if target_scene_option:
			_populate_map_names()
			if command:
				_set_option_selection(target_scene_option, command.target_scene, 0)

# Valores originales para poder cancelar
var original_actor_name: String = ""
var original_target_scene: String = ""
var original_facing_direction: int = 0
var original_target_tile: Vector2i = Vector2i.ZERO

# Referencias a los controles
var actor_name_option: OptionButton = null
var target_scene_option: OptionButton = null
var facing_direction_option: OptionButton = null
var accept_button: Button = null

# Controles para posición por tile
var tile_container: HBoxContainer = null
var tile_label: Label = null
var select_tile_button: Button = null

# Cache para evitar cargar Overworld múltiples veces
var _cached_overworld_scene: PackedScene = null

func _ready() -> void:
	title = "Editar WarpCommand"
	size = Vector2(500, 250)
	unresizable = false
	always_on_top = false
	exclusive = true
	close_requested.connect(_on_close_requested)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("margin_left", 10)
	vbox.add_theme_constant_override("margin_top", 10)
	vbox.add_theme_constant_override("margin_right", 10)
	vbox.add_theme_constant_override("margin_bottom", 10)
	add_child(vbox)

	var title_label = Label.new()
	title_label.text = "Editar WarpCommand"
	title_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title_label)
	vbox.add_child(HSeparator.new())

	# Actor Name (Dropdown)
	actor_name_option = _create_labeled_option("Nombre del actor:", vbox)
	actor_name_option.item_selected.connect(_on_actor_selected)
	call_deferred("_populate_actor_names")

	# Target Scene (Dropdown)
	target_scene_option = _create_labeled_option("Escena destino:", vbox)
	target_scene_option.item_selected.connect(_on_target_scene_selected)
	_populate_map_names()

	# Container para selección de tile
	tile_container = HBoxContainer.new()
	var tile_pos_label = Label.new()
	tile_pos_label.text = "Posición tile:"
	tile_pos_label.custom_minimum_size.x = 150
	tile_container.add_child(tile_pos_label)
	tile_label = Label.new()
	tile_label.text = "(no seleccionado)"
	tile_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile_container.add_child(tile_label)
	select_tile_button = Button.new()
	select_tile_button.text = "Seleccionar..."
	select_tile_button.pressed.connect(_on_select_tile_pressed)
	tile_container.add_child(select_tile_button)
	vbox.add_child(tile_container)

	# Facing Direction
	facing_direction_option = _create_labeled_option("Dirección:", vbox)
	facing_direction_option.add_item("Arriba")
	facing_direction_option.add_item("Abajo")
	facing_direction_option.add_item("Izquierda")
	facing_direction_option.add_item("Derecha")

	# Botones
	var buttons_container = HBoxContainer.new()
	buttons_container.alignment = BoxContainer.ALIGNMENT_END
	buttons_container.add_theme_constant_override("separation", 10)

	accept_button = Button.new()
	accept_button.text = "Aceptar"
	accept_button.pressed.connect(_on_accept_pressed)
	buttons_container.add_child(accept_button)

	var cancel_button = Button.new()
	cancel_button.text = "Cancelar"
	cancel_button.pressed.connect(_on_cancel_pressed)
	buttons_container.add_child(cancel_button)

	vbox.add_child(buttons_container)

## Helper: Crea un contenedor con label y OptionButton
func _create_labeled_option(label_text: String, parent: Container) -> OptionButton:
	var container = HBoxContainer.new()
	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 150
	container.add_child(label)

	var option = OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(option)
	parent.add_child(container)
	return option

## Helper: Obtiene el OverworldGrid del mapa actual
func _get_current_grid() -> Node:
	if not _event_node:
		return null
	var parent = _event_node.get_parent()
	if parent and parent.name == "Events":
		var grid = parent.get_parent()
		if grid and grid.is_in_group("OverworldGrid"):
			return grid
	return null

## Helper: Obtiene el MapScene del mapa actual
func _get_current_map_scene() -> Node:
	var grid = _get_current_grid()
	if grid:
		var map_scene = grid.get_parent()
		if map_scene and map_scene.get_script() and map_scene.get_script().get_global_name() == "MapScene":
			return map_scene
	return null

## Helper: Obtiene el nombre del mapa actual
func _get_current_map_name() -> String:
	var map_scene = _get_current_map_scene()
	if map_scene:
		var map_id = map_scene.get("map_id")
		if map_id and map_id != "":
			return map_id
		return map_scene.name
	return ""

## Helper: Busca y selecciona un item en un OptionButton, añadiéndolo si no existe
func _set_option_selection(option: OptionButton, value: String, default_index: int = 0) -> void:
	if not option:
		return

	var selected_index = default_index
	if value != "":
		var found = false
		for i in range(option.get_item_count()):
			if option.get_item_text(i) == value:
				selected_index = i
				found = true
				break
		if not found:
			option.add_item(value)
			selected_index = option.get_item_count() - 1

	option.selected = selected_index

## Helper: Obtiene el texto seleccionado de un OptionButton, con valor por defecto
func _get_option_text(option: OptionButton, default_value: String = "") -> String:
	if not option:
		return default_value
	var selected_index = option.selected
	if selected_index >= 0 and selected_index < option.get_item_count():
		return option.get_item_text(selected_index)
	return default_value

## Helper: Obtiene el WorldSystem desde Overworld (cachea la escena, no la instancia)
func _get_world_system() -> Node:
	const OVERWORLD_SCENE = "res://Scenes/Overworld/Overworld.tscn"
	if not _cached_overworld_scene:
		_cached_overworld_scene = load(OVERWORLD_SCENE) as PackedScene

	if not _cached_overworld_scene:
		return null

	var overworld_instance = _cached_overworld_scene.instantiate()
	if not overworld_instance:
		return null

	var world_system = overworld_instance.get_node_or_null("WorldSystem")
	overworld_instance.queue_free()

	return world_system

## Pobla el dropdown con "Player" y los nombres de los eventos del mapa actual
func _populate_actor_names() -> void:
	if not actor_name_option:
		return

	actor_name_option.clear()
	actor_name_option.add_item("Player")

	if _event_node:
		var grid = _get_current_grid()
		if grid:
			var events_container = grid.get_node_or_null("Events")
			if events_container:
				for child in events_container.get_children():
					if child is Event or (child.has_method("trigger") and child.has_method("setup_current_page")):
						if child.name != "":
							actor_name_option.add_item(child.name)

## Pobla el dropdown con el mapa actual primero y luego los mapas disponibles
func _populate_map_names() -> void:
	if not target_scene_option:
		return

	target_scene_option.clear()
	target_scene_option.add_item("(mismo mapa)")

	var current_map_name = _get_current_map_name()
	var world_system = _get_world_system()

	if world_system:
		var world_map_scenes = world_system.get("world_map_scenes")
		if world_map_scenes != null and world_map_scenes is Array:
			for packed_scene in world_map_scenes:
				if packed_scene is PackedScene:
					var scene_path = packed_scene.resource_path
					if scene_path:
						var file_name = scene_path.get_file().get_basename()
						if file_name != "" and file_name != current_map_name:
							target_scene_option.add_item(file_name)

## Carga un comando existente para editar
func load_command(cmd: WarpCommand) -> void:
	if not cmd:
		push_error("WarpCommandEditor: No se proporcionó un comando válido")
		return

	command = cmd

	# Guardar valores originales para poder cancelar
	original_actor_name = cmd.actor_name
	original_target_scene = cmd.target_scene
	original_facing_direction = cmd.facing_direction
	original_target_tile = cmd.target_tile

	# Actualizar el label del tile
	if tile_label:
		if cmd.target_tile != Vector2i.ZERO:
			tile_label.text = "(%d, %d)" % [cmd.target_tile.x, cmd.target_tile.y]
		else:
			tile_label.text = "(no seleccionado)"

	# Asegurar que los actores estén poblados antes de seleccionar
	if actor_name_option:
		_populate_actor_names()
		call_deferred("_set_actor_selection_after_load", cmd.actor_name, cmd.target_scene)
	else:
		_set_option_selection(target_scene_option, cmd.target_scene, 0)

	# Establecer la dirección guardada en el OptionButton
	if facing_direction_option:
		var direction_index = cmd.facing_direction
		if direction_index >= 0 and direction_index < facing_direction_option.get_item_count():
			facing_direction_option.selected = direction_index

	_update_accept_button_state()

## Establece la selección del actor después de que se hayan cargado los actores
func _set_actor_selection_after_load(actor_name: String, target_scene: String = "") -> void:
	if actor_name_option:
		_set_option_selection(actor_name_option, actor_name, 0)
		_update_target_scene_for_actor()
		if actor_name == "Player" and target_scene_option and target_scene != "":
			_set_option_selection(target_scene_option, target_scene, 0)

## Actualiza la selección del actor en el dropdown basándose en el comando
func _update_actor_selection() -> void:
	if not actor_name_option or not command:
		return
	_set_option_selection(actor_name_option, command.actor_name, 0)
	_update_target_scene_for_actor()

## Aplica los valores editados al comando
func _apply_values_to_command() -> void:
	if not command:
		return

	command.actor_name = _get_option_text(actor_name_option, "Player")

	var target_scene_text = _get_option_text(target_scene_option, "(mismo mapa)")
	command.target_scene = "" if target_scene_text == "(mismo mapa)" else target_scene_text

	command.facing_direction = facing_direction_option.selected if facing_direction_option else 0

## Restaura los valores originales del comando
func _restore_original_values() -> void:
	if not command:
		return

	command.actor_name = original_actor_name
	command.target_scene = original_target_scene
	command.facing_direction = original_facing_direction
	command.target_tile = original_target_tile

	_update_actor_selection()
	_set_option_selection(target_scene_option, original_target_scene, 0)

	if facing_direction_option:
		facing_direction_option.selected = original_facing_direction

	if tile_label:
		if original_target_tile != Vector2i.ZERO:
			tile_label.text = "(%d, %d)" % [original_target_tile.x, original_target_tile.y]
		else:
			tile_label.text = "(no seleccionado)"

func _on_accept_pressed() -> void:
	_apply_values_to_command()
	command_edited.emit(command)
	hide()

func _on_cancel_pressed() -> void:
	_restore_original_values()
	cancelled.emit()
	hide()

func _on_close_requested() -> void:
	_restore_original_values()
	cancelled.emit()
	hide()

## Se llama cuando cambia la selección del mapa destino
func _on_target_scene_selected(_index: int) -> void:
	# Resetear la posición del tile al cambiar de mapa
	if command:
		command.target_tile = Vector2i.ZERO
	if tile_label:
		tile_label.text = "(no seleccionado)"
	_update_accept_button_state()

## Actualiza el estado del botón de aceptar según la selección del tile
func _update_accept_button_state() -> void:
	if not accept_button:
		return

	# Verificar que hay una coordenada válida
	var has_valid_tile = command and command.target_tile != Vector2i.ZERO
	# También aceptar si el label muestra una coordenada
	if tile_label and tile_label.text != "(no seleccionado)":
		has_valid_tile = true
	accept_button.disabled = not has_valid_tile

## Se llama cuando cambia la selección del actor
func _on_actor_selected(_index: int) -> void:
	_update_target_scene_for_actor()

## Actualiza el estado del dropdown de mapa según el actor seleccionado
func _update_target_scene_for_actor() -> void:
	if not actor_name_option or not target_scene_option:
		return

	var selected_actor = _get_option_text(actor_name_option, "Player")

	if selected_actor != "Player":
		target_scene_option.disabled = true
		_set_option_selection(target_scene_option, "(mismo mapa)", 0)
		if command:
			command.target_scene = ""
	else:
		target_scene_option.disabled = false


## Se llama cuando se presiona el botón de seleccionar tile
func _on_select_tile_pressed() -> void:
	# Obtener el mapa destino
	var target_map_name = _get_option_text(target_scene_option, "(mismo mapa)")
	if target_map_name == "(mismo mapa)":
		target_map_name = _get_current_map_name()

	if target_map_name == "":
		push_error("WarpCommandEditor: No se pudo determinar el mapa destino")
		return

	# Cargar el mapa para obtener su OverworldGrid
	var grid = _load_map_grid(target_map_name)
	if not grid:
		push_error("WarpCommandEditor: No se pudo cargar el OverworldGrid del mapa: " + target_map_name)
		return

	# Cargar y crear la ventana de vista del mapa
	var selector_script = load("res://addons/event_tools/position_selector_window.gd")
	if not selector_script:
		push_error("WarpCommandEditor: No se encontró el script de la ventana de vista del mapa")
		return

	var selector_window = selector_script.new()
	add_child(selector_window)

	# Configurar la ventana (modo simple, una sola celda)
	await selector_window.setup(grid, grid.get_parent(), null)
	selector_window.set_multiple_selection_mode(false)

	# Si ya hay una celda seleccionada, mostrarla
	if command and command.target_tile != Vector2i.ZERO:
		selector_window.selected_cell = command.target_tile

	# Conectar señal para recibir la celda seleccionada
	selector_window.cell_selected.connect(func(cell_pos: Vector2i):
		if command:
			command.target_tile = cell_pos
		if tile_label:
			tile_label.text = "(%d, %d)" % [cell_pos.x, cell_pos.y]
		_update_accept_button_state()
		selector_window.queue_free()
	)

	# Conectar señal de cancelación
	selector_window.cancelled.connect(func():
		selector_window.queue_free()
	)

	# Mostrar la ventana
	selector_window.popup_centered()


## Carga el OverworldGrid de un mapa específico
func _load_map_grid(map_name: String) -> Node:
	var world_system = _get_world_system()
	if not world_system:
		return null

	var world_map_scenes = world_system.get("world_map_scenes")
	if world_map_scenes == null or not world_map_scenes is Array:
		return null

	# Buscar el mapa por nombre
	for packed_scene in world_map_scenes:
		if packed_scene is PackedScene:
			var scene_path = packed_scene.resource_path
			if scene_path:
				var file_name = scene_path.get_file().get_basename()
				if file_name == map_name:
					var map_instance = packed_scene.instantiate()
					if map_instance:
						var grid = map_instance.get_node_or_null("OverworldGrid")
						if grid:
							# Desanclar el grid del mapa para poder usarlo en la ventana
							map_instance.remove_child(grid)
							map_instance.queue_free()
							return grid
						map_instance.queue_free()
					break

	return null
