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
var original_target_spawn: String = ""
var original_facing_direction: int = 0

# Referencias a los controles
var actor_name_option: OptionButton = null
var target_scene_option: OptionButton = null
var target_spawn_option: OptionButton = null
var facing_direction_option: OptionButton = null
var accept_button: Button = null

# Cache para evitar cargar Overworld múltiples veces
var _cached_overworld_scene: PackedScene = null

func _ready() -> void:
	title = "Editar WarpCommand"
	size = Vector2(500, 300)
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

	# Target Spawn (Dropdown)
	target_spawn_option = _create_labeled_option("Spawn destino:", vbox)
	target_spawn_option.item_selected.connect(_on_target_spawn_selected)
	call_deferred("_load_spawn_points_for_selected_map")

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
	original_target_spawn = cmd.target_spawn
	original_facing_direction = cmd.facing_direction

	# Asegurar que los actores estén poblados antes de seleccionar
	if actor_name_option:
		_populate_actor_names()
		# Usar call_deferred para asegurar que la población se complete antes de seleccionar
		call_deferred("_set_actor_selection_after_load", cmd.actor_name, cmd.target_scene)
	else:
		# Si no hay actor_name_option, establecer el mapa directamente
		_set_option_selection(target_scene_option, cmd.target_scene, 0)

	if target_spawn_option:
		# Cargar spawn points primero, luego seleccionar el valor
		_load_spawn_points_for_selected_map()
		# Usar call_deferred para asegurar que los spawn points se hayan cargado
		call_deferred("_set_spawn_selection_after_load", cmd.target_spawn)

	# Establecer la dirección guardada en el OptionButton
	if facing_direction_option:
		# El enum FacingDirection coincide con el orden de los items del OptionButton
		# ARRIBA=0, ABAJO=1, IZQUIERDA=2, DERECHA=3
		var direction_index = cmd.facing_direction
		# Asegurar que el índice esté dentro del rango válido
		if direction_index >= 0 and direction_index < facing_direction_option.get_item_count():
			facing_direction_option.selected = direction_index

## Establece la selección del actor después de que se hayan cargado los actores
func _set_actor_selection_after_load(actor_name: String, target_scene: String = "") -> void:
	if actor_name_option:
		_set_option_selection(actor_name_option, actor_name, 0)
		# Actualizar el estado del dropdown de mapa según el actor
		_update_target_scene_for_actor()
		# Si el actor es "Player" y hay un target_scene, establecerlo
		# (si no es "Player", _update_target_scene_for_actor ya estableció "(mismo mapa)")
		if actor_name == "Player" and target_scene_option and target_scene != "":
			_set_option_selection(target_scene_option, target_scene, 0)

## Establece la selección del spawn point después de que se hayan cargado los spawn points
func _set_spawn_selection_after_load(spawn_name: String) -> void:
	if target_spawn_option:
		_set_option_selection(target_spawn_option, spawn_name, 0)
		_update_accept_button_state()

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

	var target_spawn_text = _get_option_text(target_spawn_option, "(ninguno)")
	command.target_spawn = "" if target_spawn_text == "(ninguno)" else target_spawn_text

	command.facing_direction = facing_direction_option.selected if facing_direction_option else 0

## Restaura los valores originales del comando
func _restore_original_values() -> void:
	if not command:
		return

	command.actor_name = original_actor_name
	command.target_scene = original_target_scene
	command.target_spawn = original_target_spawn
	command.facing_direction = original_facing_direction

	_update_actor_selection()
	_set_option_selection(target_scene_option, original_target_scene, 0)

	if target_spawn_option:
		_load_spawn_points_for_selected_map()
		call_deferred("_set_spawn_selection_after_load", original_target_spawn)

	if facing_direction_option:
		facing_direction_option.selected = original_facing_direction

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
func _on_target_scene_selected(index: int) -> void:
	_load_spawn_points_for_selected_map()

## Carga los spawn points del mapa actualmente seleccionado
func _load_spawn_points_for_selected_map() -> void:
	if not target_scene_option or not target_spawn_option:
		return

	var selected_text = _get_option_text(target_scene_option, "(mismo mapa)")
	var map_name = _get_current_map_name() if selected_text == "(mismo mapa)" else selected_text

	if map_name == "":
		target_spawn_option.clear()
		target_spawn_option.add_item("(ninguno)")
		_update_accept_button_state()
		return

	_load_spawn_points_for_map(map_name)

## Carga los spawn points de un mapa específico
func _load_spawn_points_for_map(map_name: String) -> void:
	if not target_spawn_option or map_name == "":
		return

	target_spawn_option.clear()
	target_spawn_option.add_item("(ninguno)")

	var world_system = _get_world_system()
	if not world_system:
		_update_accept_button_state()
		return

	var world_map_scenes = world_system.get("world_map_scenes")
	if world_map_scenes == null or not world_map_scenes is Array:
		_update_accept_button_state()
		return

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
							var spawn_points_container = grid.get_node_or_null("SpawnPoints")
							if spawn_points_container:
								var added_spawns = []
								for child in spawn_points_container.get_children():
									var spawn_id = child.name
									if spawn_id != "" and not spawn_id in added_spawns:
										target_spawn_option.add_item(spawn_id)
										added_spawns.append(spawn_id)
						map_instance.queue_free()
					break

	_update_accept_button_state()

## Se llama cuando cambia la selección del spawn point
func _on_target_spawn_selected(index: int) -> void:
	_update_accept_button_state()

## Actualiza el estado del botón de aceptar según la selección del spawn point
func _update_accept_button_state() -> void:
	if not accept_button or not target_spawn_option:
		return

	var selected_text = _get_option_text(target_spawn_option, "(ninguno)")
	accept_button.disabled = (selected_text == "(ninguno)")

## Se llama cuando cambia la selección del actor
func _on_actor_selected(index: int) -> void:
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
		_load_spawn_points_for_selected_map()
	else:
		target_scene_option.disabled = false
