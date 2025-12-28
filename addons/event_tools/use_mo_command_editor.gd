@tool
extends Window

## Ventana de edición para UseMOCommand
## Permite editar todas las propiedades export del comando

signal command_edited(command: UseMOCommand)
signal cancelled

var command: UseMOCommand = null
var _event_node: Node = null

# Valores originales para poder cancelar
var original_mo_type: int = 0
var original_target_path: NodePath = NodePath()
var original_activate_self_switch_on_success: String = "A"

# Referencias a los controles
var mo_type_option: OptionButton = null
var target_path_option: OptionButton = null
var activate_self_switch_edit: LineEdit = null

func _ready() -> void:
	title = "Editar UseMOCommand"
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
	title_label.text = "Editar UseMOCommand"
	title_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title_label)
	vbox.add_child(HSeparator.new())

	# MO Type
	var mo_type_container = HBoxContainer.new()
	var mo_type_label = Label.new()
	mo_type_label.text = "Tipo de MO:"
	mo_type_label.custom_minimum_size.x = 200
	mo_type_container.add_child(mo_type_label)

	mo_type_option = OptionButton.new()
	_populate_mo_types()
	mo_type_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mo_type_container.add_child(mo_type_option)
	vbox.add_child(mo_type_container)

	# Target Path
	var target_path_container = HBoxContainer.new()
	var target_path_label = Label.new()
	target_path_label.text = "Target:"
	target_path_label.custom_minimum_size.x = 200
	target_path_container.add_child(target_path_label)

	target_path_option = OptionButton.new()
	target_path_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_path_container.add_child(target_path_option)
	vbox.add_child(target_path_container)

	# Activate Self Switch
	var self_switch_container = HBoxContainer.new()
	var self_switch_label = Label.new()
	self_switch_label.text = "Self-Switch al éxito:"
	self_switch_label.custom_minimum_size.x = 200
	self_switch_container.add_child(self_switch_label)

	activate_self_switch_edit = LineEdit.new()
	activate_self_switch_edit.placeholder_text = "A"
	activate_self_switch_edit.text = "A"
	activate_self_switch_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	self_switch_container.add_child(activate_self_switch_edit)
	vbox.add_child(self_switch_container)

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

## Pobla el dropdown con los tipos de MO disponibles
func _populate_mo_types() -> void:
	if not mo_type_option:
		return

	mo_type_option.clear()

	# Añadir todos los tipos de MO del enum
	mo_type_option.add_item("CORTE")
	mo_type_option.add_item("SURF")
	mo_type_option.add_item("FUERZA")
	mo_type_option.add_item("DESTELLO")
	mo_type_option.add_item("GOLPE ROCA")
	mo_type_option.add_item("CASCADA")
	mo_type_option.add_item("BUCEO")
	mo_type_option.add_item("TREPARROCAS")
	mo_type_option.add_item("VUELO")
	mo_type_option.add_item("TORBELLINO")
	mo_type_option.add_item("DESPEJAR")
	mo_type_option.add_item("GOLPE CABEZA")

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

## Pobla el dropdown con "(evento actual)" y los nombres de los eventos del mapa
func _populate_target_path_names() -> void:
	if not target_path_option:
		return

	target_path_option.clear()

	# Añadir "(evento actual)" primero (por defecto)
	target_path_option.add_item("(evento actual)")

	# Si tenemos el event_node, obtener los eventos del mapa
	if _event_node:
		var grid = _get_current_grid()
		if grid:
			var events_container = grid.get_node_or_null("Events")
			if events_container:
				for child in events_container.get_children():
					if child is Event or (child.has_method("trigger") and child.has_method("setup_current_page")):
						if child.name != "" and child != _event_node:
							target_path_option.add_item(child.name)

## Setter para event_node
func set_event_node(value: Node) -> void:
	_event_node = value
	_populate_target_path_names()

## Carga un comando existente para editar
func load_command(cmd: UseMOCommand) -> void:
	if not cmd:
		push_error("UseMOCommandEditor: No se proporcionó un comando válido")
		return

	command = cmd

	# Guardar valores originales para poder cancelar
	original_mo_type = cmd.mo_type
	original_target_path = cmd.target_path
	original_activate_self_switch_on_success = cmd.activate_self_switch_on_success

	# Asegurar que los eventos estén poblados antes de seleccionar
	if target_path_option:
		if target_path_option.get_item_count() == 0:
			_populate_target_path_names()
		_set_target_path_selection(cmd.target_path)

	# Establecer valores en los controles
	if mo_type_option:
		mo_type_option.selected = cmd.mo_type

	if activate_self_switch_edit:
		activate_self_switch_edit.text = cmd.activate_self_switch_on_success

## Helper: Establece la selección del target_path
func _set_target_path_selection(target_path: NodePath) -> void:
	if not target_path_option:
		return

	# Si está vacío, seleccionar "(evento actual)"
	if target_path.is_empty():
		target_path_option.selected = 0
		return

	# Buscar el nombre del evento en el path
	var path_str = str(target_path)
	# Intentar obtener el nombre del nodo desde el path
	# Si el path es relativo, puede ser solo el nombre del nodo
	var node_name = path_str.get_file() if "/" in path_str else path_str

	# Buscar en el dropdown
	for i in range(target_path_option.get_item_count()):
		if target_path_option.get_item_text(i) == node_name:
			target_path_option.selected = i
			return

	# Si no se encuentra, añadirlo y seleccionarlo
	target_path_option.add_item(node_name)
	target_path_option.selected = target_path_option.get_item_count() - 1

## Aplica los valores editados al comando
func _apply_values_to_command() -> void:
	if not command:
		return

	command.mo_type = mo_type_option.selected if mo_type_option else 0

	# Obtener el target_path desde el dropdown
	if target_path_option:
		var selected_index = target_path_option.selected
		if selected_index >= 0 and selected_index < target_path_option.get_item_count():
			var selected_text = target_path_option.get_item_text(selected_index)
			# Si es "(evento actual)", usar NodePath vacío
			if selected_text == "(evento actual)":
				command.target_path = NodePath()
			else:
				# Construir el NodePath desde el nombre del evento
				# Asumimos que el evento está en el contenedor "Events"
				command.target_path = NodePath("../" + selected_text)

	if activate_self_switch_edit:
		command.activate_self_switch_on_success = activate_self_switch_edit.text.strip_edges()

## Restaura los valores originales del comando
func _restore_original_values() -> void:
	if not command:
		return

	command.mo_type = original_mo_type
	command.target_path = original_target_path
	command.activate_self_switch_on_success = original_activate_self_switch_on_success

	# Actualizar UI
	if mo_type_option:
		mo_type_option.selected = original_mo_type

	if target_path_option:
		_set_target_path_selection(original_target_path)

	if activate_self_switch_edit:
		activate_self_switch_edit.text = original_activate_self_switch_on_success

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

