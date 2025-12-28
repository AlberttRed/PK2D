@tool
extends Window

## Ventana de edición para SetEventThroughCommand
## Permite editar todas las propiedades export del comando

signal command_edited(command: SetEventThroughCommand)
signal cancelled

var command: SetEventThroughCommand = null
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
var original_target_event_name: String = ""
var original_through: bool = true

# Referencias a los controles
var target_event_option: OptionButton = null
var through_check: CheckBox = null

func _ready() -> void:
	title = "Editar SetEventThroughCommand"
	size = Vector2(450, 200)
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
	title_label.text = "Editar SetEventThroughCommand"
	title_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title_label)
	vbox.add_child(HSeparator.new())

	# Target Event (Dropdown)
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

	# Through
	through_check = CheckBox.new()
	through_check.text = "Puede pasar a través (through = true)"
	through_check.button_pressed = true
	vbox.add_child(through_check)

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

## Carga un comando existente para editar
func load_command(cmd: SetEventThroughCommand) -> void:
	if not cmd:
		push_error("SetEventThroughCommandEditor: No se proporcionó un comando válido")
		return

	command = cmd

	# Guardar valores originales para poder cancelar
	original_target_event_name = cmd.target_event_name
	original_through = cmd.through

	# Asegurar que los eventos estén poblados antes de seleccionar
	if target_event_option:
		if target_event_option.get_item_count() == 0:
			_populate_event_names()
		_set_option_selection(target_event_option, cmd.target_event_name, 0)

	if through_check:
		through_check.button_pressed = cmd.through

## Aplica los valores editados al comando
func _apply_values_to_command() -> void:
	if not command:
		return

	# Obtener el nombre del evento desde el dropdown
	var target_event_name = ""
	if target_event_option:
		var selected_index = target_event_option.selected
		if selected_index >= 0 and selected_index < target_event_option.get_item_count():
			var selected_text = target_event_option.get_item_text(selected_index)
			# Si no es "(evento actual)", usar el texto seleccionado
			if selected_text != "(evento actual)":
				target_event_name = selected_text

	command.target_event_name = target_event_name
	command.through = through_check.button_pressed if through_check else true

## Restaura los valores originales del comando
func _restore_original_values() -> void:
	if not command:
		return

	command.target_event_name = original_target_event_name
	command.through = original_through

	if target_event_option:
		_set_option_selection(target_event_option, original_target_event_name, 0)

	if through_check:
		through_check.button_pressed = original_through

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

