@tool
extends Window

## Ventana de edición para SwitchCommand
## Permite editar todas las propiedades export del comando

signal command_edited(command: SwitchCommand)
signal cancelled

var command: SwitchCommand = null
var _event_node: Node = null

# Valores originales para poder cancelar
var original_variable_name: String = ""
var original_cases: Array = []
var original_default_commands: Array = []

# Referencias a los controles
var variable_name_edit: LineEdit = null
var cases_list: ItemList = null
var add_button: Button = null
var remove_button: Button = null
var move_up_button: Button = null
var move_down_button: Button = null
var edit_values_button: Button = null
var accept_button: Button = null

# Cache de cases (índice del ItemList -> SwitchCase)
var _cases_cache: Array[SwitchCase] = []

func _ready() -> void:
	title = "Editar SwitchCommand"
	size = Vector2(600, 500)
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
	title_label.text = "Editar SwitchCommand"
	title_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title_label)
	vbox.add_child(HSeparator.new())

	var info_label = Label.new()
	info_label.text = "Los casos se evalúan en orden. Se ejecuta solo el primero que coincida."
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(info_label)

	# Variable name
	var variable_container = HBoxContainer.new()
	var variable_label = Label.new()
	variable_label.text = "Variable:"
	variable_label.custom_minimum_size.x = 100
	variable_container.add_child(variable_label)

	variable_name_edit = LineEdit.new()
	variable_name_edit.placeholder_text = "Nombre de la variable"
	variable_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	variable_container.add_child(variable_name_edit)
	vbox.add_child(variable_container)

	# Lista de casos
	var list_label = Label.new()
	list_label.text = "Casos:"
	list_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(list_label)

	cases_list = ItemList.new()
	cases_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cases_list.item_selected.connect(_on_case_selected)
	cases_list.item_activated.connect(_on_case_activated)
	vbox.add_child(cases_list)

	# Controles de la lista
	var list_controls = HBoxContainer.new()
	list_controls.add_theme_constant_override("separation", 5)

	add_button = Button.new()
	add_button.text = "Añadir Caso"
	add_button.pressed.connect(_on_add_pressed)
	list_controls.add_child(add_button)

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

	edit_values_button = Button.new()
	edit_values_button.text = "Editar Valores"
	edit_values_button.disabled = true
	edit_values_button.pressed.connect(_on_edit_values_pressed)
	list_controls.add_child(edit_values_button)

	vbox.add_child(list_controls)

	# Botones finales
	var buttons_container = HBoxContainer.new()
	buttons_container.alignment = BoxContainer.ALIGNMENT_END
	buttons_container.add_theme_constant_override("separation", 10)
	buttons_container.add_theme_constant_override("margin_top", 10)

	accept_button = Button.new()
	accept_button.text = "Aceptar"
	accept_button.pressed.connect(_on_accept_pressed)
	buttons_container.add_child(accept_button)

	var cancel_button = Button.new()
	cancel_button.text = "Cancelar"
	cancel_button.pressed.connect(_on_cancel_pressed)
	buttons_container.add_child(cancel_button)

	vbox.add_child(buttons_container)

## Convierte un valor a string para mostrar
func _value_to_string(value: Variant) -> String:
	if value == null:
		return "null"
	if value is String:
		return '"%s"' % value
	return str(value)

## Obtiene el nombre descriptivo de un caso
func _get_case_display_name(switch_case: SwitchCase, index: int) -> String:
	if not switch_case:
		return "Caso %d: (null)" % (index + 1)

	var values_str = ""
	if switch_case.values.is_empty():
		values_str = "[]"
	else:
		var value_strings: Array[String] = []
		for value in switch_case.values:
			value_strings.append(_value_to_string(value))
		values_str = "[%s]" % ", ".join(value_strings)

	var command_count = switch_case.commands.size() if switch_case.commands else 0
	return "Caso %d: %s (%d comandos)" % [index + 1, values_str, command_count]

## Refresca la lista de casos desde el cache
func _refresh_cases_list() -> void:
	cases_list.clear()
	for i in range(_cases_cache.size()):
		var switch_case = _cases_cache[i]
		var display_name = _get_case_display_name(switch_case, i)
		cases_list.add_item(display_name)

## Se llama cuando se selecciona un caso
func _on_case_selected(index: int) -> void:
	_update_buttons_state()

## Se llama cuando se hace doble clic en un caso
func _on_case_activated(index: int) -> void:
	_on_edit_values_pressed()

## Actualiza el estado de los botones de control
func _update_buttons_state() -> void:
	var has_selection = cases_list.get_selected_items().size() > 0
	var selected_index = cases_list.get_selected_items()[0] if has_selection else -1
	var can_move_up = has_selection and selected_index > 0
	var can_move_down = has_selection and selected_index >= 0 and selected_index < _cases_cache.size() - 1

	remove_button.disabled = not has_selection
	move_up_button.disabled = not can_move_up
	move_down_button.disabled = not can_move_down
	edit_values_button.disabled = not has_selection

## Se llama cuando se presiona Añadir Caso
func _on_add_pressed() -> void:
	var new_case = SwitchCase.new()
	_cases_cache.append(new_case)
	_refresh_cases_list()
	# Seleccionar el nuevo caso
	cases_list.select(_cases_cache.size() - 1)
	_update_buttons_state()

## Se llama cuando se presiona Quitar
func _on_remove_pressed() -> void:
	var selected_items = cases_list.get_selected_items()
	if selected_items.is_empty():
		return

	var selected_index = selected_items[0]
	if selected_index < 0 or selected_index >= _cases_cache.size():
		return

	_cases_cache.remove_at(selected_index)
	_refresh_cases_list()
	_update_buttons_state()

## Se llama cuando se presiona ↑
func _on_move_up_pressed() -> void:
	var selected_items = cases_list.get_selected_items()
	if selected_items.is_empty():
		return

	var selected_index = selected_items[0]
	if selected_index <= 0 or selected_index >= _cases_cache.size():
		return

	# Intercambiar con el anterior
	var temp_case = _cases_cache[selected_index]
	_cases_cache[selected_index] = _cases_cache[selected_index - 1]
	_cases_cache[selected_index - 1] = temp_case

	_refresh_cases_list()
	cases_list.select(selected_index - 1)
	_update_buttons_state()

## Se llama cuando se presiona ↓
func _on_move_down_pressed() -> void:
	var selected_items = cases_list.get_selected_items()
	if selected_items.is_empty():
		return

	var selected_index = selected_items[0]
	if selected_index < 0 or selected_index >= _cases_cache.size() - 1:
		return

	# Intercambiar con el siguiente
	var temp_case = _cases_cache[selected_index]
	_cases_cache[selected_index] = _cases_cache[selected_index + 1]
	_cases_cache[selected_index + 1] = temp_case

	_refresh_cases_list()
	cases_list.select(selected_index + 1)
	_update_buttons_state()

## Se llama cuando se presiona Editar Valores
func _on_edit_values_pressed() -> void:
	var selected_items = cases_list.get_selected_items()
	if selected_items.is_empty():
		return

	var selected_index = selected_items[0]
	if selected_index < 0 or selected_index >= _cases_cache.size():
		return

	var switch_case = _cases_cache[selected_index]
	if not switch_case:
		return

	# Abrir ventana de edición de valores
	var editor_script = load("res://addons/event_tools/switch_case_values_editor.gd")
	if not editor_script:
		push_error("SwitchCommandEditor: No se encontró el script del editor de valores")
		return

	var editor_window = editor_script.new()
	if not editor_window:
		push_error("SwitchCommandEditor: No se pudo crear la instancia del editor")
		return

	add_child(editor_window)
	editor_window.load_case(switch_case)
	editor_window.values_edited.connect(func(values: Array): _on_values_edited(selected_index, values))
	editor_window.cancelled.connect(func(): editor_window.queue_free())

	editor_window.popup_centered()

## Se llama cuando se editan los valores de un caso
func _on_values_edited(case_index: int, values: Array) -> void:
	if case_index < 0 or case_index >= _cases_cache.size():
		return

	var switch_case = _cases_cache[case_index]
	if not switch_case:
		return

	# Actualizar los valores del caso
	switch_case.values = values.duplicate()

	# Refrescar la lista para mostrar los nuevos valores
	_refresh_cases_list()
	# Mantener la selección
	cases_list.select(case_index)

## Setter para event_node
func set_event_node(value: Node) -> void:
	_event_node = value

## Carga un comando existente para editar
func load_command(cmd: SwitchCommand) -> void:
	if not cmd:
		push_error("SwitchCommandEditor: No se proporcionó un comando válido")
		return

	command = cmd

	# Guardar valores originales para poder cancelar
	original_variable_name = cmd.variable_name
	original_cases = []
	for switch_case in cmd.cases:
		if switch_case:
			original_cases.append(switch_case.duplicate(true))
		else:
			original_cases.append(null)
	original_default_commands = []
	for cmd_item in cmd.default_commands:
		if cmd_item:
			original_default_commands.append(cmd_item.duplicate(true))
		else:
			original_default_commands.append(null)

	# Cargar los casos en el cache
	_cases_cache = []
	for switch_case in cmd.cases:
		if switch_case:
			_cases_cache.append(switch_case.duplicate(true))
		else:
			_cases_cache.append(null)

	# Cargar variable_name
	if variable_name_edit:
		variable_name_edit.text = cmd.variable_name

	_refresh_cases_list()
	_update_buttons_state()

## Aplica los valores editados al comando
func _apply_values_to_command() -> void:
	if not command:
		return

	# Aplicar variable_name
	if variable_name_edit:
		command.variable_name = variable_name_edit.text.strip_edges()

	# Crear un nuevo array para evitar el error de "read-only"
	var new_cases: Array[SwitchCase] = []
	for switch_case in _cases_cache:
		if switch_case:
			new_cases.append(switch_case.duplicate(true))
		else:
			new_cases.append(null)

	# Asignar el nuevo array
	command.cases = new_cases

	# Por ahora no editamos default_commands, se mantienen los originales
	# En el futuro se podría añadir un editor para default_commands

## Restaura los valores originales del comando
func _restore_original_values() -> void:
	if not command:
		return

	# Restaurar variable_name
	if variable_name_edit:
		variable_name_edit.text = original_variable_name

	# Restaurar casos originales
	_cases_cache = []
	for switch_case in original_cases:
		if switch_case:
			_cases_cache.append(switch_case.duplicate(true))
		else:
			_cases_cache.append(null)

	_refresh_cases_list()
	_update_buttons_state()

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

