@tool
extends Window

## Ventana de edición para MoveNPCCommand
## Permite editar todas las propiedades export del comando

signal command_edited(command: MoveNPCCommand)
signal cancelled

var command: MoveNPCCommand = null
var _event_node: Node = null

# Valores originales para poder cancelar
var original_target_name: String = ""
var original_path: Array = []
var original_wait_until_finished: bool = true

# Referencias a los controles
var target_option: OptionButton = null
var actions_list: ItemList = null
var wait_check: CheckBox = null
var accept_button: Button = null
var remove_button: Button = null
var move_up_button: Button = null
var move_down_button: Button = null

# Cache de acciones añadidas (índice del ItemList -> DirectionEnum.Type)
var _actions_cache: Array[int] = []

# Target guardado para restaurar después de poblar la lista
var _pending_target_selection: String = ""

func _ready() -> void:
	title = "Editar MoveNPCCommand"
	size = Vector2(700, 600)
	unresizable = false
	always_on_top = false
	exclusive = true
	close_requested.connect(_on_close_requested)

	var main_container = HBoxContainer.new()
	main_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_container.add_theme_constant_override("margin_left", 10)
	main_container.add_theme_constant_override("margin_top", 10)
	main_container.add_theme_constant_override("margin_right", 10)
	main_container.add_theme_constant_override("margin_bottom", 10)
	add_child(main_container)

	# Panel izquierdo con botones de acciones
	var left_panel = VBoxContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_container.add_child(left_panel)

	var title_label = Label.new()
	title_label.text = "Editar MoveNPCCommand"
	title_label.add_theme_font_size_override("font_size", 18)
	left_panel.add_child(title_label)
	left_panel.add_child(HSeparator.new())

	# ScrollContainer para los botones si hay muchos
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.add_child(scroll)

	var buttons_container = VBoxContainer.new()
	scroll.add_child(buttons_container)

	# Categoría: Movimientos
	var movement_label = Label.new()
	movement_label.text = "Movimientos:"
	movement_label.add_theme_font_size_override("font_size", 14)
	buttons_container.add_child(movement_label)

	var movement_grid = _create_button_grid([
		{"text": "↑ Arriba", "action": DirectionEnum.Type.UP},
		{"text": "↓ Abajo", "action": DirectionEnum.Type.DOWN},
		{"text": "← Izquierda", "action": DirectionEnum.Type.LEFT},
		{"text": "→ Derecha", "action": DirectionEnum.Type.RIGHT}
	])
	buttons_container.add_child(movement_grid)

	# Categoría: Giros con animación
	var turn_label = Label.new()
	turn_label.text = "Giros con animación:"
	turn_label.add_theme_font_size_override("font_size", 14)
	buttons_container.add_child(turn_label)

	var turn_grid = _create_button_grid([
		{"text": "↺↑ Girar Arriba", "action": DirectionEnum.Type.TURN_UP},
		{"text": "↺↓ Girar Abajo", "action": DirectionEnum.Type.TURN_DOWN},
		{"text": "↺← Girar Izquierda", "action": DirectionEnum.Type.TURN_LEFT},
		{"text": "↺→ Girar Derecha", "action": DirectionEnum.Type.TURN_RIGHT}
	], 3)
	buttons_container.add_child(turn_grid)

	# Categoría: Mirar (sin movimiento)
	var look_label = Label.new()
	look_label.text = "Mirar (sin movimiento):"
	look_label.add_theme_font_size_override("font_size", 14)
	buttons_container.add_child(look_label)

	var look_grid = _create_button_grid([
		{"text": "👁↑ Mirar Arriba", "action": DirectionEnum.Type.LOOK_UP},
		{"text": "👁↓ Mirar Abajo", "action": DirectionEnum.Type.LOOK_DOWN},
		{"text": "👁← Mirar Izquierda", "action": DirectionEnum.Type.LOOK_LEFT},
		{"text": "👁→ Mirar Derecha", "action": DirectionEnum.Type.LOOK_RIGHT},
		{"text": "👁👤 Mirar Jugador", "action": DirectionEnum.Type.LOOK_PLAYER}
	], 3)
	buttons_container.add_child(look_grid)

	# Categoría: Esperas
	var wait_label = Label.new()
	wait_label.text = "Esperas:"
	wait_label.add_theme_font_size_override("font_size", 14)
	buttons_container.add_child(wait_label)

	var wait_grid = _create_button_grid([
		{"text": "⏱ 0.25s", "action": DirectionEnum.Type.WAIT_025},
		{"text": "⏱ 0.5s", "action": DirectionEnum.Type.WAIT_050},
		{"text": "⏱ 1.0s", "action": DirectionEnum.Type.WAIT_100}
	])
	buttons_container.add_child(wait_grid)

	# Categoría: Velocidades
	var speed_label = Label.new()
	speed_label.text = "Velocidades:"
	speed_label.add_theme_font_size_override("font_size", 14)
	buttons_container.add_child(speed_label)

	var speed_grid = _create_button_grid([
		{"text": "🐌 Slowest", "action": DirectionEnum.Type.SPEED_SLOWEST},
		{"text": "🐢 Slower", "action": DirectionEnum.Type.SPEED_SLOWER},
		{"text": "🚶 Normal", "action": DirectionEnum.Type.SPEED_NORMAL},
		{"text": "🏃 Faster", "action": DirectionEnum.Type.SPEED_FASTER},
		{"text": "⚡ Fastest", "action": DirectionEnum.Type.SPEED_FASTEST}
	])
	buttons_container.add_child(speed_grid)

	# Categoría: Animaciones
	var anim_label = Label.new()
	anim_label.text = "Animaciones:"
	anim_label.add_theme_font_size_override("font_size", 14)
	buttons_container.add_child(anim_label)

	var anim_grid = _create_button_grid([
		{"text": "⚠ Exclamación", "action": DirectionEnum.Type.EXCLAMATION_ANIM}
	])
	buttons_container.add_child(anim_grid)

	# Panel derecho con ItemList (más estrecho)
	var right_panel = VBoxContainer.new()
	right_panel.custom_minimum_size.x = 250
	right_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	main_container.add_child(right_panel)

	var list_label = Label.new()
	list_label.text = "Secuencia de acciones:"
	list_label.add_theme_font_size_override("font_size", 14)
	right_panel.add_child(list_label)

	actions_list = ItemList.new()
	actions_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	actions_list.item_selected.connect(_on_action_selected)
	right_panel.add_child(actions_list)

	# Controles de la lista
	var list_controls = HBoxContainer.new()
	list_controls.add_theme_constant_override("separation", 5)

	remove_button = Button.new()
	remove_button.text = "Quitar"
	remove_button.disabled = true
	remove_button.pressed.connect(_on_remove_pressed)
	list_controls.add_child(remove_button)

	move_up_button = Button.new()
	move_up_button.text = "↑"
	move_up_button.custom_minimum_size.x = 40
	move_up_button.disabled = true
	move_up_button.pressed.connect(_on_move_up_pressed)
	list_controls.add_child(move_up_button)

	move_down_button = Button.new()
	move_down_button.text = "↓"
	move_down_button.custom_minimum_size.x = 40
	move_down_button.disabled = true
	move_down_button.pressed.connect(_on_move_down_pressed)
	list_controls.add_child(move_down_button)

	right_panel.add_child(list_controls)

	# Controles adicionales
	var controls_container = VBoxContainer.new()
	right_panel.add_child(controls_container)

	# Target
	var target_container = HBoxContainer.new()
	var target_label = Label.new()
	target_label.text = "Target:"
	target_label.custom_minimum_size.x = 100
	target_container.add_child(target_label)

	target_option = OptionButton.new()
	target_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_container.add_child(target_option)
	controls_container.add_child(target_container)

	# Wait until finished
	wait_check = CheckBox.new()
	wait_check.text = "Esperar hasta que termine"
	wait_check.button_pressed = true
	controls_container.add_child(wait_check)

	# Botones finales
	var buttons_container_final = HBoxContainer.new()
	buttons_container_final.alignment = BoxContainer.ALIGNMENT_END
	buttons_container_final.add_theme_constant_override("separation", 10)
	buttons_container_final.add_theme_constant_override("margin_top", 10)

	accept_button = Button.new()
	accept_button.text = "Aceptar"
	accept_button.pressed.connect(_on_accept_pressed)
	buttons_container_final.add_child(accept_button)

	var cancel_button = Button.new()
	cancel_button.text = "Cancelar"
	cancel_button.pressed.connect(_on_cancel_pressed)
	buttons_container_final.add_child(cancel_button)

	right_panel.add_child(buttons_container_final)

	# Poblar eventos después de añadir los controles
	call_deferred("_populate_target_names")

## Crea un grid de botones
func _create_button_grid(buttons_data: Array, columns: int = 4) -> GridContainer:
	var grid = GridContainer.new()
	grid.columns = columns
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)

	for button_data in buttons_data:
		var button = Button.new()
		button.text = str(button_data.get("text", ""))
		var action_value: int = int(button_data.get("action", DirectionEnum.Type.UP))
		button.set_meta("action_id", action_value)
		button.pressed.connect(Callable(self, "_on_action_button_pressed_from_button").bind(button))
		grid.add_child(button)

	return grid

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

## Pobla el dropdown con Player y los NPCs/Trainers del mapa
func _populate_target_names() -> void:
	if not target_option:
		return

	target_option.clear()

	# Primero añadir "Player" como primera opción
	target_option.add_item("Player")

	# Si tenemos el event_node, obtener los NPCs/Trainers del mapa
	if _event_node:
		var grid = _get_current_grid()
		if grid:
			var events_container = grid.get_node_or_null("Events")
			if events_container:
				for child in events_container.get_children():
					# Solo incluir NPCs y Trainers (no eventos normales)
					if child is NPC or child is Trainer:
						if child.name != "":
							target_option.add_item(child.name)

	# Restaurar selección pendiente si existe
	if not _pending_target_selection.is_empty():
		_set_target_selection(_pending_target_selection)

## Obtiene el nombre descriptivo de una acción
func _get_action_display_name(action: int) -> String:
	match action:
		DirectionEnum.Type.UP: return "Mover Arriba"
		DirectionEnum.Type.DOWN: return "Mover Abajo"
		DirectionEnum.Type.LEFT: return "Mover Izquierda"
		DirectionEnum.Type.RIGHT: return "Mover Derecha"
		DirectionEnum.Type.LOOK_UP: return "Mirar Arriba"
		DirectionEnum.Type.LOOK_DOWN: return "Mirar Abajo"
		DirectionEnum.Type.LOOK_LEFT: return "Mirar Izquierda"
		DirectionEnum.Type.LOOK_RIGHT: return "Mirar Derecha"
		DirectionEnum.Type.LOOK_PLAYER: return "Mirar Jugador"
		DirectionEnum.Type.TURN_UP: return "Girar Arriba"
		DirectionEnum.Type.TURN_DOWN: return "Girar Abajo"
		DirectionEnum.Type.TURN_LEFT: return "Girar Izquierda"
		DirectionEnum.Type.TURN_RIGHT: return "Girar Derecha"
		DirectionEnum.Type.WAIT_025: return "Esperar 0.25s"
		DirectionEnum.Type.WAIT_050: return "Esperar 0.5s"
		DirectionEnum.Type.WAIT_100: return "Esperar 1.0s"
		DirectionEnum.Type.SPEED_SLOWEST: return "Velocidad: Slowest"
		DirectionEnum.Type.SPEED_SLOWER: return "Velocidad: Slower"
		DirectionEnum.Type.SPEED_NORMAL: return "Velocidad: Normal"
		DirectionEnum.Type.SPEED_FASTER: return "Velocidad: Faster"
		DirectionEnum.Type.SPEED_FASTEST: return "Velocidad: Fastest"
		DirectionEnum.Type.EXCLAMATION_ANIM: return "Animación: Exclamación"
		_: return "Acción desconocida"

## Se llama cuando se presiona un botón de acción
func _on_action_button_pressed(action: int) -> void:
	_actions_cache.append(action)
	# Usar _refresh_actions_list para que muestre el número de orden correctamente
	_refresh_actions_list()
	# Seleccionar el último item añadido
	actions_list.select(_actions_cache.size() - 1)
	_update_buttons_state()
	_update_accept_button_state()

func _on_action_button_pressed_from_button(button: Button) -> void:
	if button == null:
		return
	var action_value: int = int(button.get_meta("action_id", DirectionEnum.Type.UP))
	_on_action_button_pressed(action_value)

## Se llama cuando se selecciona una acción en la lista
func _on_action_selected(index: int) -> void:
	_update_buttons_state()

## Actualiza el estado de los botones de control
func _update_buttons_state() -> void:
	var has_selection = actions_list.get_selected_items().size() > 0
	var selected_index = actions_list.get_selected_items()[0] if has_selection else -1
	var can_move_up = has_selection and selected_index > 0
	var can_move_down = has_selection and selected_index >= 0 and selected_index < _actions_cache.size() - 1

	remove_button.disabled = not has_selection
	move_up_button.disabled = not can_move_up
	move_down_button.disabled = not can_move_down

## Actualiza el estado del botón Aceptar
func _update_accept_button_state() -> void:
	if not accept_button:
		return

	# Deshabilitar si no hay acciones
	accept_button.disabled = _actions_cache.is_empty()

## Se llama cuando se presiona Quitar
func _on_remove_pressed() -> void:
	var selected_items = actions_list.get_selected_items()
	if selected_items.is_empty():
		return

	var selected_index = selected_items[0]
	if selected_index < 0 or selected_index >= _actions_cache.size():
		return

	_actions_cache.remove_at(selected_index)
	# Refrescar la lista para actualizar los números de orden
	_refresh_actions_list()
	_update_buttons_state()
	_update_accept_button_state()

## Se llama cuando se presiona ↑
func _on_move_up_pressed() -> void:
	var selected_items = actions_list.get_selected_items()
	if selected_items.is_empty():
		return

	var selected_index = selected_items[0]
	if selected_index <= 0 or selected_index >= _actions_cache.size():
		return

	# Intercambiar con el anterior
	var temp_action = _actions_cache[selected_index]
	_actions_cache[selected_index] = _actions_cache[selected_index - 1]
	_actions_cache[selected_index - 1] = temp_action

	# Actualizar la lista
	_refresh_actions_list()
	actions_list.select(selected_index - 1)
	_update_buttons_state()

## Se llama cuando se presiona ↓
func _on_move_down_pressed() -> void:
	var selected_items = actions_list.get_selected_items()
	if selected_items.is_empty():
		return

	var selected_index = selected_items[0]
	if selected_index < 0 or selected_index >= _actions_cache.size() - 1:
		return

	# Intercambiar con el siguiente
	var temp_action = _actions_cache[selected_index]
	_actions_cache[selected_index] = _actions_cache[selected_index + 1]
	_actions_cache[selected_index + 1] = temp_action

	# Actualizar la lista
	_refresh_actions_list()
	actions_list.select(selected_index + 1)
	_update_buttons_state()

## Refresca la lista de acciones desde el cache
func _refresh_actions_list() -> void:
	actions_list.clear()
	for i in range(_actions_cache.size()):
		var action = _actions_cache[i]
		var display_name = _get_action_display_name(action)
		# Añadir el número de orden antes del nombre
		actions_list.add_item("%d. %s" % [i + 1, display_name])

## Setter para event_node
func set_event_node(value: Node) -> void:
	_event_node = value
	_populate_target_names()

## Carga un comando existente para editar
func load_command(cmd: MoveNPCCommand) -> void:
	if not cmd:
		push_error("MoveNPCCommandEditor: No se proporcionó un comando válido")
		return

	command = cmd

	# Guardar valores originales para poder cancelar
	original_target_name = cmd.target_name
	original_path = cmd.path.duplicate()
	original_wait_until_finished = cmd.wait_until_finished

	# Cargar el path en el cache y la lista
	_actions_cache = cmd.path.duplicate()
	_refresh_actions_list()

	# Guardar el target para restaurar después de poblar la lista
	_pending_target_selection = cmd.target_name

	# Asegurar que los eventos estén poblados y seleccionar el target
	if target_option:
		if target_option.get_item_count() == 0:
			_populate_target_names()
		else:
			_set_target_selection(cmd.target_name)

	# Actualizar wait_check
	if wait_check:
		wait_check.button_pressed = cmd.wait_until_finished

	_update_buttons_state()
	_update_accept_button_state()

## Helper: Establece la selección del target
func _set_target_selection(target_name: String) -> void:
	if not target_option:
		return

	# Si está vacío, seleccionar "Player" (primera opción) por defecto
	if target_name.is_empty():
		if target_option.get_item_count() > 0:
			target_option.selected = 0  # "Player" es la primera opción
		return

	# Buscar el target en el dropdown (puede ser "Player" o un NPC/Trainer)
	for i in range(target_option.get_item_count()):
		if target_option.get_item_text(i) == target_name:
			target_option.selected = i
			return

	# Si no se encuentra, seleccionar "Player" por defecto
	if target_option.get_item_count() > 0:
		target_option.selected = 0

## Aplica los valores editados al comando
func _apply_values_to_command() -> void:
	if not command:
		return

	# Obtener el nombre del target desde el dropdown
	var target_name = ""
	if target_option:
		var selected_index = target_option.selected
		if selected_index >= 0 and selected_index < target_option.get_item_count():
			var selected_text = target_option.get_item_text(selected_index)
			# "Player" se guarda como "Player", no como vacío
			# Los NPCs/Trainers se guardan con su nombre
			target_name = selected_text

	command.target_name = target_name

	# Aplicar el path desde el cache
	command.path = _actions_cache.duplicate()

	# Wait until finished
	if wait_check:
		command.wait_until_finished = wait_check.button_pressed

## Restaura los valores originales del comando
func _restore_original_values() -> void:
	if not command:
		return

	command.target_name = original_target_name
	command.path = original_path.duplicate()
	command.wait_until_finished = original_wait_until_finished

	# Restaurar UI
	_actions_cache = original_path.duplicate()
	_refresh_actions_list()
	_pending_target_selection = original_target_name
	_set_target_selection(original_target_name)
	if wait_check:
		wait_check.button_pressed = original_wait_until_finished

	_update_buttons_state()
	_update_accept_button_state()

## Se llama cuando se presiona Aceptar
func _on_accept_pressed() -> void:
	_apply_values_to_command()
	command_edited.emit(command)
	queue_free()

## Se llama cuando se presiona Cancelar
func _on_cancel_pressed() -> void:
	_restore_original_values()
	cancelled.emit()
	queue_free()

## Se llama cuando se cierra la ventana
func _on_close_requested() -> void:
	_on_cancel_pressed()

