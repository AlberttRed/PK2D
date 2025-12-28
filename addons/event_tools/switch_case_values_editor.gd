@tool
extends Window

## Ventana de edición para los valores de un SwitchCase
## Permite editar el array de values de un SwitchCase

signal values_edited(values: Array)
signal cancelled

var switch_case: SwitchCase = null

# Valores originales para poder cancelar
var original_values: Array = []

# Referencias a los controles
var values_list: ItemList = null
var value_edit: LineEdit = null
var add_button: Button = null
var remove_button: Button = null
var move_up_button: Button = null
var move_down_button: Button = null
var accept_button: Button = null

# Cache de valores (índice del ItemList -> Variant)
var _values_cache: Array = []

func _ready() -> void:
	title = "Editar Valores del Caso"
	size = Vector2(400, 400)
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
	title_label.text = "Editar Valores del Caso"
	title_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title_label)
	vbox.add_child(HSeparator.new())

	var info_label = Label.new()
	info_label.text = "Introduce valores que activarán este caso. Pueden ser números, texto, booleanos, etc."
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(info_label)

	# Campo para añadir valores
	var add_container = HBoxContainer.new()
	var add_label = Label.new()
	add_label.text = "Nuevo valor:"
	add_label.custom_minimum_size.x = 100
	add_container.add_child(add_label)

	value_edit = LineEdit.new()
	value_edit.placeholder_text = "Ej: 1, \"texto\", true, 3.14"
	value_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_edit.text_submitted.connect(_on_value_submitted)
	add_container.add_child(value_edit)

	add_button = Button.new()
	add_button.text = "Añadir"
	add_button.pressed.connect(_on_add_pressed)
	add_container.add_child(add_button)

	vbox.add_child(add_container)

	# Lista de valores
	var list_label = Label.new()
	list_label.text = "Valores:"
	list_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(list_label)

	values_list = ItemList.new()
	values_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	values_list.item_selected.connect(_on_value_selected)
	vbox.add_child(values_list)

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
	if value is bool:
		return "true" if value else "false"
	return str(value)

## Intenta parsear un string a un valor
func _parse_value(text: String) -> Variant:
	var trimmed = text.strip_edges()
	if trimmed.is_empty():
		return null

	# Si está entre comillas, es un String
	if trimmed.begins_with('"') and trimmed.ends_with('"'):
		return trimmed.substr(1, trimmed.length() - 2)

	# Intentar como bool
	if trimmed.to_lower() == "true":
		return true
	if trimmed.to_lower() == "false":
		return false

	# Intentar como int
	if trimmed.is_valid_int():
		return trimmed.to_int()

	# Intentar como float
	if trimmed.is_valid_float():
		return trimmed.to_float()

	# Si no se puede parsear, devolver como String
	return trimmed

## Refresca la lista de valores desde el cache
func _refresh_values_list() -> void:
	values_list.clear()
	for i in range(_values_cache.size()):
		var value = _values_cache[i]
		var display_name = "%d. %s" % [i + 1, _value_to_string(value)]
		values_list.add_item(display_name)

## Se llama cuando se selecciona un valor
func _on_value_selected(index: int) -> void:
	_update_buttons_state()

## Actualiza el estado de los botones de control
func _update_buttons_state() -> void:
	var has_selection = values_list.get_selected_items().size() > 0
	var selected_index = values_list.get_selected_items()[0] if has_selection else -1
	var can_move_up = has_selection and selected_index > 0
	var can_move_down = has_selection and selected_index >= 0 and selected_index < _values_cache.size() - 1

	remove_button.disabled = not has_selection
	move_up_button.disabled = not can_move_up
	move_down_button.disabled = not can_move_down

## Se llama cuando se presiona Enter en el LineEdit o el botón Añadir
func _on_value_submitted(_text: String) -> void:
	_on_add_pressed()

## Se llama cuando se presiona Añadir
func _on_add_pressed() -> void:
	var text = value_edit.text.strip_edges()
	if text.is_empty():
		return

	var value = _parse_value(text)
	_values_cache.append(value)
	_refresh_values_list()

	# Limpiar el campo y seleccionar el nuevo valor
	value_edit.text = ""
	values_list.select(_values_cache.size() - 1)
	_update_buttons_state()
	value_edit.grab_focus()

## Se llama cuando se presiona Quitar
func _on_remove_pressed() -> void:
	var selected_items = values_list.get_selected_items()
	if selected_items.is_empty():
		return

	var selected_index = selected_items[0]
	if selected_index < 0 or selected_index >= _values_cache.size():
		return

	_values_cache.remove_at(selected_index)
	_refresh_values_list()
	_update_buttons_state()

## Se llama cuando se presiona ↑
func _on_move_up_pressed() -> void:
	var selected_items = values_list.get_selected_items()
	if selected_items.is_empty():
		return

	var selected_index = selected_items[0]
	if selected_index <= 0 or selected_index >= _values_cache.size():
		return

	# Intercambiar con el anterior
	var temp_value = _values_cache[selected_index]
	_values_cache[selected_index] = _values_cache[selected_index - 1]
	_values_cache[selected_index - 1] = temp_value

	_refresh_values_list()
	values_list.select(selected_index - 1)
	_update_buttons_state()

## Se llama cuando se presiona ↓
func _on_move_down_pressed() -> void:
	var selected_items = values_list.get_selected_items()
	if selected_items.is_empty():
		return

	var selected_index = selected_items[0]
	if selected_index < 0 or selected_index >= _values_cache.size() - 1:
		return

	# Intercambiar con el siguiente
	var temp_value = _values_cache[selected_index]
	_values_cache[selected_index] = _values_cache[selected_index + 1]
	_values_cache[selected_index + 1] = temp_value

	_refresh_values_list()
	values_list.select(selected_index + 1)
	_update_buttons_state()

## Carga un SwitchCase para editar
func load_case(case: SwitchCase) -> void:
	if not case:
		push_error("SwitchCaseValuesEditor: No se proporcionó un SwitchCase válido")
		return

	switch_case = case

	# Guardar valores originales para poder cancelar
	original_values = case.values.duplicate()

	# Cargar los valores en el cache
	_values_cache = case.values.duplicate()

	_refresh_values_list()
	_update_buttons_state()

## Aplica los valores editados al caso
func _apply_values_to_case() -> void:
	if not switch_case:
		return

	# Crear un nuevo array para evitar el error de "read-only"
	switch_case.values = _values_cache.duplicate()

## Restaura los valores originales del caso
func _restore_original_values() -> void:
	if not switch_case:
		return

	# Restaurar valores originales
	_values_cache = original_values.duplicate()

	_refresh_values_list()
	_update_buttons_state()

## Se llama cuando se presiona Aceptar
func _on_accept_pressed() -> void:
	_apply_values_to_case()
	values_edited.emit(_values_cache.duplicate())
	queue_free()

## Se llama cuando se presiona Cancelar
func _on_cancel_pressed() -> void:
	_restore_original_values()
	cancelled.emit()
	queue_free()

## Se llama cuando se cierra la ventana
func _on_close_requested() -> void:
	_on_cancel_pressed()

