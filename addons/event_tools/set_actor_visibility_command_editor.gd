@tool
extends Window

## Ventana de edición para SetActorVisibilityCommand
## Permite editar todas las propiedades export del comando

signal command_edited(command: SetActorVisibilityCommand)
signal cancelled

var command: SetActorVisibilityCommand = null
var _event_node: Node = null  # Referencia al evento para obtener otros eventos del mapa

## Setter para event_node que actualiza el dropdown cuando se asigna
var event_node: Node:
	get:
		return _event_node
	set(value):
		_event_node = value
		if target_event_option:
			_populate_event_names()
			if command:
				_set_option_selection(target_event_option, command.target_event_name, 0)

# Valores originales para poder cancelar
var original_target_type: int = 0
var original_target_event_name: String = ""
var original_visible: bool = true

# Referencias a los controles
var target_type_option: OptionButton = null
var target_event_option: OptionButton = null
var visible_check: CheckBox = null

func _ready() -> void:
	title = "Editar SetActorVisibilityCommand"
	size = Vector2(450, 250)
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
	title_label.text = "Editar SetActorVisibilityCommand"
	title_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title_label)
	vbox.add_child(HSeparator.new())

	# Target Type
	var target_type_container = HBoxContainer.new()
	var target_type_label = Label.new()
	target_type_label.text = "Tipo de objetivo:"
	target_type_label.custom_minimum_size.x = 150
	target_type_container.add_child(target_type_label)

	target_type_option = OptionButton.new()
	target_type_option.add_item("Evento")
	target_type_option.add_item("Jugador")
	target_type_option.item_selected.connect(_on_target_type_selected)
	target_type_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_type_container.add_child(target_type_option)
	vbox.add_child(target_type_container)

	# Target Event (Dropdown) - Solo visible si target_type = Event
	var target_event_container = HBoxContainer.new()
	var target_event_label = Label.new()
	target_event_label.text = "Evento objetivo:"
	target_event_label.custom_minimum_size.x = 150
	target_event_container.add_child(target_event_label)

	target_event_option = OptionButton.new()
	target_event_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_event_container.add_child(target_event_option)
	vbox.add_child(target_event_container)

	# Poblar el dropdown después de añadirlo (se actualizará cuando se asigne event_node)
	call_deferred("_populate_event_names")

	# Visible
	visible_check = CheckBox.new()
	visible_check.text = "Visible"
	visible_check.button_pressed = true
	vbox.add_child(visible_check)

	# Botones
	var buttons_container = HBoxContainer.new()
	buttons_container.alignment = BoxContainer.ALIGNMENT_END
	buttons_container.add_theme_constant_override("separation", 10)

	var accept_button = Button.new()
	accept_button.text = "Aceptar"
	accept_button.pressed.connect(_on_accept_pressed)
	buttons_container.add_child(accept_button)

	var cancel_button = Button.new()
	cancel_button.text = "Cancelar"
	cancel_button.pressed.connect(_on_cancel_pressed)
	buttons_container.add_child(cancel_button)

	vbox.add_child(buttons_container)

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

## Pobla el dropdown con "(evento actual)" y los nombres de los eventos del mapa
func _populate_event_names() -> void:
	if not target_event_option:
		return

	target_event_option.clear()

	# Añadir "(evento actual)" primero (vacío)
	target_event_option.add_item("(evento actual)")

	# Si tenemos el event_node, obtener los eventos del mapa
	if _event_node:
		var grid = _get_current_grid()
		if grid:
			var events_container = grid.get_node_or_null("Events")
			if events_container:
				for child in events_container.get_children():
					if child is Event or (child.has_method("trigger") and child.has_method("setup_current_page")):
						if child.name != "" and child != _event_node:
							target_event_option.add_item(child.name)

## Se llama cuando cambia la selección del tipo de objetivo
func _on_target_type_selected(index: int) -> void:
	_update_target_event_visibility()

## Actualiza la visibilidad del dropdown de eventos según el tipo de objetivo
func _update_target_event_visibility() -> void:
	if not target_type_option or not target_event_option:
		return

	var selected_index = target_type_option.selected
	# Si es "Evento" (índice 0), mostrar el dropdown de eventos
	# Si es "Jugador" (índice 1), ocultarlo
	target_event_option.visible = (selected_index == 0)

## Carga un comando existente para editar
func load_command(cmd: SetActorVisibilityCommand) -> void:
	if not cmd:
		push_error("SetActorVisibilityCommandEditor: No se proporcionó un comando válido")
		return

	command = cmd

	# Guardar valores originales para poder cancelar
	original_target_type = cmd.target_type
	original_target_event_name = cmd.target_event_name
	original_visible = cmd.visible

	if target_type_option:
		target_type_option.selected = cmd.target_type
		_update_target_event_visibility()

	# Asegurar que los eventos estén poblados antes de seleccionar
	if target_event_option:
		if target_event_option.get_item_count() == 0:
			_populate_event_names()
		_set_option_selection(target_event_option, cmd.target_event_name, 0)

	if visible_check:
		visible_check.button_pressed = cmd.visible

## Aplica los valores editados al comando
func _apply_values_to_command() -> void:
	if not command:
		return

	command.target_type = target_type_option.selected if target_type_option else 0

	# Obtener el nombre del evento desde el dropdown (solo si target_type = Event)
	var target_event_name = ""
	if target_type_option and target_type_option.selected == 0:  # Event
		if target_event_option:
			var selected_index = target_event_option.selected
			if selected_index >= 0 and selected_index < target_event_option.get_item_count():
				var selected_text = target_event_option.get_item_text(selected_index)
				# Si no es "(evento actual)", usar el texto seleccionado
				if selected_text != "(evento actual)":
					target_event_name = selected_text

	command.target_event_name = target_event_name
	command.visible = visible_check.button_pressed if visible_check else true

## Restaura los valores originales del comando
func _restore_original_values() -> void:
	if not command:
		return

	command.target_type = original_target_type
	command.target_event_name = original_target_event_name
	command.visible = original_visible

	if target_type_option:
		target_type_option.selected = original_target_type
		_update_target_event_visibility()

	if target_event_option:
		_set_option_selection(target_event_option, original_target_event_name, 0)

	if visible_check:
		visible_check.button_pressed = original_visible

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

