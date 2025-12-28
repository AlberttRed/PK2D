@tool
extends Window

## Ventana de edición para ShowChoicesCommand
## Permite editar todas las propiedades export del comando

signal command_edited(command: ShowChoicesCommand)
signal cancelled

var command: ShowChoicesCommand = null
var _event_node: Node = null

# Valores originales para poder cancelar
var original_branches: Array = []
var original_message: String = ""
var original_store_result_in: String = ""

# Referencias a los controles
var message_edit: TextEdit = null
var branches_list: ItemList = null
var add_button: Button = null
var remove_button: Button = null
var move_up_button: Button = null
var move_down_button: Button = null
var edit_branch_button: Button = null
var store_result_edit: LineEdit = null
var accept_button: Button = null

# Cache de branches (índice del ItemList -> ChoiceBranch)
var _branches_cache: Array[ChoiceBranch] = []

func _ready() -> void:
	title = "Editar ShowChoicesCommand"
	size = Vector2(700, 600)
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
	title_label.text = "Editar ShowChoicesCommand"
	title_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title_label)
	vbox.add_child(HSeparator.new())

	var info_label = Label.new()
	info_label.text = "Muestra un mensaje y opciones al jugador. Se ejecutan los comandos de la opción seleccionada."
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(info_label)

	# Mensaje
	var message_label = Label.new()
	message_label.text = "Mensaje:"
	message_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(message_label)

	message_edit = TextEdit.new()
	message_edit.custom_minimum_size.y = 80
	message_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	vbox.add_child(message_edit)

	# Lista de opciones
	var list_label = Label.new()
	list_label.text = "Opciones:"
	list_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(list_label)

	branches_list = ItemList.new()
	branches_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	branches_list.item_selected.connect(_on_branch_selected)
	branches_list.item_activated.connect(_on_branch_activated)
	vbox.add_child(branches_list)

	# Controles de la lista
	var list_controls = HBoxContainer.new()
	list_controls.add_theme_constant_override("separation", 5)

	add_button = Button.new()
	add_button.text = "Añadir Opción"
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

	edit_branch_button = Button.new()
	edit_branch_button.text = "Editar Opción"
	edit_branch_button.disabled = true
	edit_branch_button.pressed.connect(_on_edit_branch_pressed)
	list_controls.add_child(edit_branch_button)

	vbox.add_child(list_controls)

	# Variable para guardar resultado
	var store_result_container = HBoxContainer.new()
	var store_result_label = Label.new()
	store_result_label.text = "Guardar resultado en variable:"
	store_result_label.custom_minimum_size.x = 200
	store_result_container.add_child(store_result_label)

	store_result_edit = LineEdit.new()
	store_result_edit.placeholder_text = "(opcional)"
	store_result_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	store_result_container.add_child(store_result_edit)

	vbox.add_child(store_result_container)

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

## Obtiene el nombre descriptivo de una opción
func _get_branch_display_name(branch: ChoiceBranch, index: int) -> String:
	if not branch:
		return "Opción %d: (null)" % (index + 1)

	var label_text = branch.label if branch.label != "" else "(sin texto)"
	var command_count = branch.commands.size() if branch.commands else 0
	return "Opción %d: \"%s\" (%d comandos)" % [index + 1, label_text, command_count]

## Refresca la lista de opciones desde el cache
func _refresh_branches_list() -> void:
	branches_list.clear()
	for i in range(_branches_cache.size()):
		var branch = _branches_cache[i]
		var display_name = _get_branch_display_name(branch, i)
		branches_list.add_item(display_name)

## Se llama cuando se selecciona una opción
func _on_branch_selected(index: int) -> void:
	_update_buttons_state()

## Se llama cuando se hace doble clic en una opción
func _on_branch_activated(index: int) -> void:
	_on_edit_branch_pressed()

## Actualiza el estado de los botones de control
func _update_buttons_state() -> void:
	var has_selection = branches_list.get_selected_items().size() > 0
	var selected_index = branches_list.get_selected_items()[0] if has_selection else -1
	var can_move_up = has_selection and selected_index > 0
	var can_move_down = has_selection and selected_index >= 0 and selected_index < _branches_cache.size() - 1

	remove_button.disabled = not has_selection
	move_up_button.disabled = not can_move_up
	move_down_button.disabled = not can_move_down
	edit_branch_button.disabled = not has_selection

## Se llama cuando se presiona Añadir Opción
func _on_add_pressed() -> void:
	var new_branch = ChoiceBranch.new()
	new_branch.label = "Nueva opción"
	_branches_cache.append(new_branch)
	_refresh_branches_list()
	# Seleccionar la nueva opción
	branches_list.select(_branches_cache.size() - 1)
	_update_buttons_state()

## Se llama cuando se presiona Quitar
func _on_remove_pressed() -> void:
	var selected_items = branches_list.get_selected_items()
	if selected_items.is_empty():
		return

	var selected_index = selected_items[0]
	if selected_index < 0 or selected_index >= _branches_cache.size():
		return

	_branches_cache.remove_at(selected_index)
	_refresh_branches_list()
	_update_buttons_state()

## Se llama cuando se presiona ↑
func _on_move_up_pressed() -> void:
	var selected_items = branches_list.get_selected_items()
	if selected_items.is_empty():
		return

	var selected_index = selected_items[0]
	if selected_index <= 0 or selected_index >= _branches_cache.size():
		return

	# Intercambiar con el anterior
	var temp_branch = _branches_cache[selected_index]
	_branches_cache[selected_index] = _branches_cache[selected_index - 1]
	_branches_cache[selected_index - 1] = temp_branch

	_refresh_branches_list()
	branches_list.select(selected_index - 1)
	_update_buttons_state()

## Se llama cuando se presiona ↓
func _on_move_down_pressed() -> void:
	var selected_items = branches_list.get_selected_items()
	if selected_items.is_empty():
		return

	var selected_index = selected_items[0]
	if selected_index < 0 or selected_index >= _branches_cache.size() - 1:
		return

	# Intercambiar con el siguiente
	var temp_branch = _branches_cache[selected_index]
	_branches_cache[selected_index] = _branches_cache[selected_index + 1]
	_branches_cache[selected_index + 1] = temp_branch

	_refresh_branches_list()
	branches_list.select(selected_index + 1)
	_update_buttons_state()

## Se llama cuando se presiona Editar Opción
func _on_edit_branch_pressed() -> void:
	var selected_items = branches_list.get_selected_items()
	if selected_items.is_empty():
		return

	var selected_index = selected_items[0]
	if selected_index < 0 or selected_index >= _branches_cache.size():
		return

	var branch = _branches_cache[selected_index]
	if not branch:
		return

	# Abrir ventana de edición de opción
	var editor_script = load("res://addons/event_tools/choice_branch_editor.gd")
	if not editor_script:
		push_error("ShowChoicesCommandEditor: No se encontró el script del editor de opciones")
		return

	var editor_window = editor_script.new()
	if not editor_window:
		push_error("ShowChoicesCommandEditor: No se pudo crear la instancia del editor")
		return

	add_child(editor_window)
	editor_window.load_branch(branch)
	editor_window.branch_edited.connect(func(edited_branch: ChoiceBranch): _on_branch_edited(selected_index, edited_branch))
	editor_window.cancelled.connect(func(): editor_window.queue_free())

	editor_window.popup_centered()

## Se llama cuando se edita una opción
func _on_branch_edited(branch_index: int, edited_branch: ChoiceBranch) -> void:
	if branch_index < 0 or branch_index >= _branches_cache.size():
		return

	# Actualizar la opción en el cache
	_branches_cache[branch_index] = edited_branch.duplicate(true)

	# Refrescar la lista para mostrar el cambio
	_refresh_branches_list()
	# Mantener la selección
	branches_list.select(branch_index)

## Setter para event_node
func set_event_node(value: Node) -> void:
	_event_node = value

## Carga un comando existente para editar
func load_command(cmd: ShowChoicesCommand) -> void:
	if not cmd:
		push_error("ShowChoicesCommandEditor: No se proporcionó un comando válido")
		return

	command = cmd

	# Guardar valores originales para poder cancelar
	original_message = cmd.message
	original_store_result_in = cmd.store_result_in
	original_branches = []
	for branch in cmd.branches:
		if branch:
			original_branches.append(branch.duplicate(true))
		else:
			original_branches.append(null)

	# Cargar los valores en los controles
	message_edit.text = cmd.message
	store_result_edit.text = cmd.store_result_in

	# Cargar las opciones en el cache
	_branches_cache = []
	for branch in cmd.branches:
		if branch:
			_branches_cache.append(branch.duplicate(true))
		else:
			_branches_cache.append(null)

	_refresh_branches_list()
	_update_buttons_state()

## Aplica los valores editados al comando
func _apply_values_to_command() -> void:
	if not command:
		return

	command.message = message_edit.text
	command.store_result_in = store_result_edit.text

	# Crear un nuevo array para evitar el error de "read-only"
	var new_branches: Array[ChoiceBranch] = []
	for branch in _branches_cache:
		if branch:
			new_branches.append(branch.duplicate(true))
		else:
			new_branches.append(null)

	# Asignar el nuevo array
	command.branches = new_branches

## Restaura los valores originales del comando
func _restore_original_values() -> void:
	if not command:
		return

	message_edit.text = original_message
	store_result_edit.text = original_store_result_in

	# Restaurar opciones originales
	_branches_cache = []
	for branch in original_branches:
		if branch:
			_branches_cache.append(branch.duplicate(true))
		else:
			_branches_cache.append(null)

	_refresh_branches_list()
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

