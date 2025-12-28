@tool
extends Window

## Ventana de edición para ChoiceBranch
## Permite editar el label, close_previous_message y value_stored

signal branch_edited(branch: ChoiceBranch)
signal cancelled

var branch: ChoiceBranch = null

# Valores originales para poder cancelar
var original_label: String = ""
var original_close_previous_message: bool = true
var original_value_stored = ""

# Referencias a los controles
var label_edit: LineEdit = null
var close_message_check: CheckBox = null
var value_stored_edit: LineEdit = null
var accept_button: Button = null

func _ready() -> void:
	title = "Editar Opción"
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
	title_label.text = "Editar Opción"
	title_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title_label)
	vbox.add_child(HSeparator.new())

	# Label (texto de la opción)
	var label_container = HBoxContainer.new()
	var label_label = Label.new()
	label_label.text = "Texto de la opción:"
	label_label.custom_minimum_size.x = 150
	label_container.add_child(label_label)

	label_edit = LineEdit.new()
	label_edit.placeholder_text = "Escribe el texto de la opción"
	label_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_container.add_child(label_edit)

	vbox.add_child(label_container)

	# Close previous message
	close_message_check = CheckBox.new()
	close_message_check.text = "Cerrar mensaje después de ejecutar comandos"
	close_message_check.button_pressed = true
	vbox.add_child(close_message_check)

	# Value stored
	var value_container = HBoxContainer.new()
	var value_label = Label.new()
	value_label.text = "Valor a guardar:"
	value_label.custom_minimum_size.x = 150
	value_container.add_child(value_label)

	value_stored_edit = LineEdit.new()
	value_stored_edit.placeholder_text = "(opcional) int, float, bool, string"
	value_stored_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_container.add_child(value_stored_edit)

	vbox.add_child(value_container)

	var info_label = Label.new()
	info_label.text = "Si se especifica una variable en ShowChoicesCommand, este valor se guardará cuando se seleccione esta opción."
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(info_label)

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

## Parsea el valor de entrada a int, float, bool o string
func _parse_value(input: String) -> Variant:
	if input.is_empty():
		return ""

	# Intentar bool
	if input.to_lower() == "true":
		return true
	if input.to_lower() == "false":
		return false

	# Intentar int
	if input.is_valid_int():
		return input.to_int()

	# Intentar float
	if input.is_valid_float():
		return input.to_float()

	# Por defecto, string
	return input

## Carga una opción existente para editar
func load_branch(br: ChoiceBranch) -> void:
	if not br:
		push_error("ChoiceBranchEditor: No se proporcionó una opción válida")
		return

	branch = br

	# Guardar valores originales
	original_label = br.label
	original_close_previous_message = br.close_previous_message
	original_value_stored = br.value_stored

	# Cargar los valores en los controles
	label_edit.text = br.label
	close_message_check.button_pressed = br.close_previous_message

	# Convertir value_stored a string para mostrar
	if br.value_stored == null:
		value_stored_edit.text = ""
	elif typeof(br.value_stored) == TYPE_STRING and br.value_stored == "":
		value_stored_edit.text = ""
	else:
		value_stored_edit.text = str(br.value_stored)

## Aplica los valores editados a la opción
func _apply_values_to_branch() -> void:
	if not branch:
		return

	branch.label = label_edit.text
	branch.close_previous_message = close_message_check.button_pressed

	var parsed_value = _parse_value(value_stored_edit.text)
	if parsed_value == "":
		branch.value_stored = ""
	else:
		branch.value_stored = parsed_value

## Restaura los valores originales
func _restore_original_values() -> void:
	if not branch:
		return

	label_edit.text = original_label
	close_message_check.button_pressed = original_close_previous_message

	if original_value_stored == null:
		value_stored_edit.text = ""
	elif typeof(original_value_stored) == TYPE_STRING and original_value_stored == "":
		value_stored_edit.text = ""
	else:
		value_stored_edit.text = str(original_value_stored)

## Se llama cuando se presiona Aceptar
func _on_accept_pressed() -> void:
	_apply_values_to_branch()
	branch_edited.emit(branch)
	queue_free()

## Se llama cuando se presiona Cancelar
func _on_cancel_pressed() -> void:
	_restore_original_values()
	cancelled.emit()
	queue_free()

## Se llama cuando se cierra la ventana
func _on_close_requested() -> void:
	_on_cancel_pressed()

