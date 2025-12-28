@tool
extends Window

## Ventana de edición para FollowActorCommand
## Permite editar todas las propiedades export del comando

signal command_edited(command: FollowActorCommand)
signal cancelled

var command: FollowActorCommand = null
var _event_node: Node = null

# Valores originales para poder cancelar
var original_follower_actor_name: String = ""
var original_leader_actor_name: String = "Player"
var original_action: int = 0
var original_distance_tiles: int = 1
var original_copy_facing: bool = true
var original_copy_run_state: bool = true
var original_catchup_policy: int = 0

# Referencias a los controles
var follower_actor_option: OptionButton = null
var leader_actor_option: OptionButton = null
var action_option: OptionButton = null
var distance_tiles_spin: SpinBox = null
var copy_facing_check: CheckBox = null
var copy_run_state_check: CheckBox = null
var catchup_policy_option: OptionButton = null
var accept_button: Button = null

# Contenedor para opciones solo visibles cuando action = START
var start_options_container: Control = null

func _ready() -> void:
	title = "Editar FollowActorCommand"
	size = Vector2(500, 400)
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
	title_label.text = "Editar FollowActorCommand"
	title_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title_label)
	vbox.add_child(HSeparator.new())

	# Follower Actor
	var follower_container = HBoxContainer.new()
	var follower_label = Label.new()
	follower_label.text = "Actor seguidor:"
	follower_label.custom_minimum_size.x = 150
	follower_container.add_child(follower_label)

	follower_actor_option = OptionButton.new()
	follower_actor_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	follower_actor_option.item_selected.connect(_on_actor_selection_changed)
	follower_container.add_child(follower_actor_option)
	vbox.add_child(follower_container)

	# Leader Actor
	var leader_container = HBoxContainer.new()
	var leader_label = Label.new()
	leader_label.text = "Actor líder:"
	leader_label.custom_minimum_size.x = 150
	leader_container.add_child(leader_label)

	leader_actor_option = OptionButton.new()
	leader_actor_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	leader_actor_option.item_selected.connect(_on_actor_selection_changed)
	leader_container.add_child(leader_actor_option)
	vbox.add_child(leader_container)

	# Action
	var action_container = HBoxContainer.new()
	var action_label = Label.new()
	action_label.text = "Acción:"
	action_label.custom_minimum_size.x = 150
	action_container.add_child(action_label)

	action_option = OptionButton.new()
	action_option.add_item("Iniciar seguimiento")
	action_option.add_item("Detener seguimiento")
	action_option.item_selected.connect(_on_action_selected)
	action_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_container.add_child(action_option)
	vbox.add_child(action_container)

	# Contenedor para opciones solo visibles cuando action = START
	start_options_container = VBoxContainer.new()
	vbox.add_child(start_options_container)

	# Distance Tiles
	var distance_container = HBoxContainer.new()
	var distance_label = Label.new()
	distance_label.text = "Distancia (tiles):"
	distance_label.custom_minimum_size.x = 150
	distance_container.add_child(distance_label)

	distance_tiles_spin = SpinBox.new()
	distance_tiles_spin.min_value = 1
	distance_tiles_spin.max_value = 10
	distance_tiles_spin.value = 1
	distance_tiles_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	distance_container.add_child(distance_tiles_spin)
	start_options_container.add_child(distance_container)

	# Copy Facing
	var copy_facing_container = HBoxContainer.new()
	var copy_facing_label = Label.new()
	copy_facing_label.text = "Copiar dirección:"
	copy_facing_label.custom_minimum_size.x = 150
	copy_facing_container.add_child(copy_facing_label)

	copy_facing_check = CheckBox.new()
	copy_facing_check.button_pressed = true
	copy_facing_container.add_child(copy_facing_check)
	start_options_container.add_child(copy_facing_container)

	# Copy Run State
	var copy_run_container = HBoxContainer.new()
	var copy_run_label = Label.new()
	copy_run_label.text = "Copiar estado correr:"
	copy_run_label.custom_minimum_size.x = 150
	copy_run_container.add_child(copy_run_label)

	copy_run_state_check = CheckBox.new()
	copy_run_state_check.button_pressed = true
	copy_run_container.add_child(copy_run_state_check)
	start_options_container.add_child(copy_run_container)

	# Catchup Policy
	var catchup_container = HBoxContainer.new()
	var catchup_label = Label.new()
	catchup_label.text = "Política recuperación:"
	catchup_label.custom_minimum_size.x = 150
	catchup_container.add_child(catchup_label)

	catchup_policy_option = OptionButton.new()
	catchup_policy_option.add_item("Teletransportar")
	catchup_policy_option.add_item("Esperar")
	catchup_policy_option.add_item("Teletransportar si lejos")
	catchup_policy_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	catchup_container.add_child(catchup_policy_option)
	start_options_container.add_child(catchup_container)

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

## Pobla los dropdowns con los nombres de actores disponibles
func _populate_actor_names() -> void:
	if not follower_actor_option or not leader_actor_option:
		return

	follower_actor_option.clear()
	leader_actor_option.clear()

	# Añadir opciones comunes a ambos dropdowns
	follower_actor_option.add_item("(evento actual)")
	leader_actor_option.add_item("(evento actual)")

	follower_actor_option.add_item("Player")
	leader_actor_option.add_item("Player")

	# Si tenemos el event_node, obtener los NPCs/Trainers del mapa
	if _event_node:
		var grid = _get_current_grid()
		if grid:
			var events_container = grid.get_node_or_null("Events")
			if events_container:
				for child in events_container.get_children():
					# Solo incluir NPCs/Trainers (que tienen movimiento)
					if child is NPC:
						if child.name != "" and child != _event_node:
							follower_actor_option.add_item(child.name)
							leader_actor_option.add_item(child.name)

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

## Setter para event_node que también pobla los nombres
func set_event_node(value: Node) -> void:
	_event_node = value
	_populate_actor_names()
	_update_accept_button_state()

## Se llama cuando cambia la selección de actor (follower o leader)
func _on_actor_selection_changed(index: int) -> void:
	_update_accept_button_state()

## Actualiza el estado del botón Aceptar según la validación
func _update_accept_button_state() -> void:
	if not accept_button or not follower_actor_option or not leader_actor_option:
		return

	var follower_text = _get_option_text(follower_actor_option)
	var leader_text = _get_option_text(leader_actor_option)

	# Deshabilitar si ambos tienen la misma selección (y no es "(evento actual)")
	var same_selection = (follower_text == leader_text) and (follower_text != "(evento actual)")
	accept_button.disabled = same_selection

## Se llama cuando cambia la selección de acción
func _on_action_selected(index: int) -> void:
	_update_action_ui()

## Actualiza la visibilidad de los controles según la acción
func _update_action_ui() -> void:
	if not action_option or not start_options_container:
		return

	var is_start = (action_option.selected == 0)  # 0 = START
	start_options_container.visible = is_start

## Carga un comando existente para editar
func load_command(cmd: FollowActorCommand) -> void:
	if not cmd:
		push_error("FollowActorCommandEditor: No se proporcionó un comando válido")
		return

	command = cmd

	# Guardar valores originales para poder cancelar
	original_follower_actor_name = cmd.follower_actor_name
	original_leader_actor_name = cmd.leader_actor_name
	original_action = cmd.action
	original_distance_tiles = cmd.distance_tiles
	original_copy_facing = cmd.copy_facing
	original_copy_run_state = cmd.copy_run_state
	original_catchup_policy = cmd.catchup_policy

	# Asegurar que los dropdowns estén poblados
	if follower_actor_option.get_item_count() == 0:
		_populate_actor_names()

	# Establecer valores en los controles
	_set_option_selection(follower_actor_option, cmd.follower_actor_name, "(evento actual)")
	_set_option_selection(leader_actor_option, cmd.leader_actor_name, "(evento actual)")

	if action_option:
		action_option.selected = cmd.action
		_update_action_ui()

	if distance_tiles_spin:
		distance_tiles_spin.value = cmd.distance_tiles

	if copy_facing_check:
		copy_facing_check.button_pressed = cmd.copy_facing

	if copy_run_state_check:
		copy_run_state_check.button_pressed = cmd.copy_run_state

	if catchup_policy_option:
		catchup_policy_option.selected = cmd.catchup_policy

	# Actualizar estado del botón Aceptar después de cargar
	call_deferred("_update_accept_button_state")

## Helper para establecer la selección de un OptionButton
func _set_option_selection(option: OptionButton, value: String, default: String = "") -> void:
	if not option:
		return

	for i in range(option.get_item_count()):
		var item_text = option.get_item_text(i)
		if item_text == value or (value == "" and item_text == default):
			option.selected = i
			return

	# Si no se encuentra, seleccionar el default o el primero
	if default != "":
		for i in range(option.get_item_count()):
			if option.get_item_text(i) == default:
				option.selected = i
				return

	if option.get_item_count() > 0:
		option.selected = 0

## Obtiene el texto seleccionado de un OptionButton
func _get_option_text(option: OptionButton) -> String:
	if not option or option.selected < 0:
		return ""
	return option.get_item_text(option.selected)

## Aplica los valores editados al comando
func _apply_values_to_command() -> void:
	if not command:
		return

	var follower_text = _get_option_text(follower_actor_option)
	command.follower_actor_name = "" if follower_text == "(evento actual)" else follower_text

	command.leader_actor_name = _get_option_text(leader_actor_option)
	command.action = action_option.selected if action_option else 0
	command.distance_tiles = int(distance_tiles_spin.value) if distance_tiles_spin else 1
	command.copy_facing = copy_facing_check.button_pressed if copy_facing_check else true
	command.copy_run_state = copy_run_state_check.button_pressed if copy_run_state_check else true
	command.catchup_policy = catchup_policy_option.selected if catchup_policy_option else 0

## Restaura los valores originales del comando
func _restore_original_values() -> void:
	if not command:
		return

	command.follower_actor_name = original_follower_actor_name
	command.leader_actor_name = original_leader_actor_name
	command.action = original_action
	command.distance_tiles = original_distance_tiles
	command.copy_facing = original_copy_facing
	command.copy_run_state = original_copy_run_state
	command.catchup_policy = original_catchup_policy

	# Actualizar UI
	_set_option_selection(follower_actor_option, original_follower_actor_name, "(evento actual)")
	_set_option_selection(leader_actor_option, original_leader_actor_name, "(evento actual)")

	if action_option:
		action_option.selected = original_action
		_update_action_ui()

	if distance_tiles_spin:
		distance_tiles_spin.value = original_distance_tiles

	if copy_facing_check:
		copy_facing_check.button_pressed = original_copy_facing

	if copy_run_state_check:
		copy_run_state_check.button_pressed = original_copy_run_state

	if catchup_policy_option:
		catchup_policy_option.selected = original_catchup_policy

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

