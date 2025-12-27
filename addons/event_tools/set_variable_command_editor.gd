@tool
extends Window

## Ventana de edición para SetVariableCommand
## Permite editar todas las propiedades export del comando

signal command_edited(command: SetVariableCommand)
signal cancelled

var command: SetVariableCommand = null

# Referencias a los controles
var variable_name_line_edit: LineEdit = null
var variable_type_option: OptionButton = null
var value_line_edit: LineEdit = null
var value_check: CheckBox = null
var value_spin: SpinBox = null
var defer_until_warp_check: CheckBox = null

func _ready() -> void:
	title = "Editar SetVariableCommand"
	size = Vector2(500, 400)
	unresizable = false
	always_on_top = false
	exclusive = true
	close_requested.connect(_on_close_requested)

	_setup_ui()

func _setup_ui() -> void:
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 10
	vbox.offset_top = 10
	vbox.offset_right = -10
	vbox.offset_bottom = -10
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)

	# Título
	var title_label = Label.new()
	title_label.text = "Editar SetVariableCommand"
	title_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title_label)
	vbox.add_child(HSeparator.new())

	# Variable Name
	var variable_name_container = HBoxContainer.new()
	var variable_name_label = Label.new()
	variable_name_label.text = "Nombre de la variable:"
	variable_name_label.custom_minimum_size.x = 150
	variable_name_container.add_child(variable_name_label)

	variable_name_line_edit = LineEdit.new()
	variable_name_line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	variable_name_container.add_child(variable_name_line_edit)
	vbox.add_child(variable_name_container)

	# Variable Type
	var variable_type_container = HBoxContainer.new()
	var variable_type_label = Label.new()
	variable_type_label.text = "Tipo de variable:"
	variable_type_label.custom_minimum_size.x = 150
	variable_type_container.add_child(variable_type_label)

	variable_type_option = OptionButton.new()
	variable_type_option.add_item("INT")
	variable_type_option.add_item("BOOL")
	variable_type_option.add_item("STRING")
	variable_type_option.add_item("FLOAT")
	variable_type_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	variable_type_option.item_selected.connect(_on_variable_type_changed)
	variable_type_container.add_child(variable_type_option)
	vbox.add_child(variable_type_container)

	# Value (el control cambia según el tipo)
	var value_label = Label.new()
	value_label.text = "Valor:"
	vbox.add_child(value_label)

	# Contenedor para los diferentes controles de valor
	var value_container = HBoxContainer.new()

	# LineEdit para STRING
	value_line_edit = LineEdit.new()
	value_line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_line_edit.visible = false
	value_container.add_child(value_line_edit)

	# CheckBox para BOOL
	value_check = CheckBox.new()
	value_check.text = "Valor (activado = true)"
	value_check.visible = false
	value_container.add_child(value_check)

	# SpinBox para INT y FLOAT
	value_spin = SpinBox.new()
	value_spin.min_value = -999999.0
	value_spin.max_value = 999999.0
	value_spin.step = 1.0
	value_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_spin.visible = false
	value_container.add_child(value_spin)

	vbox.add_child(value_container)

	# Separador para el grupo Defer Options
	vbox.add_child(HSeparator.new())

	var defer_label = Label.new()
	defer_label.text = "Opciones de Diferimiento:"
	defer_label.add_theme_constant_override("margin_top", 10)
	vbox.add_child(defer_label)

	# Defer Until Warp
	defer_until_warp_check = CheckBox.new()
	defer_until_warp_check.text = "Diferir hasta el próximo warp"
	vbox.add_child(defer_until_warp_check)

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

## Maneja el cambio de tipo de variable
func _on_variable_type_changed(index: int) -> void:
	# Ocultar todos los controles de valor
	value_line_edit.visible = false
	value_check.visible = false
	value_spin.visible = false

	# Mostrar el control apropiado según el tipo
	match index:
		SetVariableCommand.VariableType.INT:
			value_spin.visible = true
			value_spin.step = 1.0
			value_spin.value = int(value_spin.value)
		SetVariableCommand.VariableType.BOOL:
			value_check.visible = true
		SetVariableCommand.VariableType.STRING:
			value_line_edit.visible = true
		SetVariableCommand.VariableType.FLOAT:
			value_spin.visible = true
			value_spin.step = 0.01

## Carga un comando existente para editar
func load_command(cmd: SetVariableCommand) -> void:
	if not cmd:
		push_error("SetVariableCommandEditor: No se proporcionó un comando válido")
		return

	command = cmd

	# Cargar valores en los controles
	if variable_name_line_edit:
		variable_name_line_edit.text = cmd.variable_name

	if variable_type_option:
		variable_type_option.selected = cmd.variable_type
		_on_variable_type_changed(cmd.variable_type)

	# Cargar el valor según el tipo
	if value_line_edit:
		if cmd.variable_type == SetVariableCommand.VariableType.STRING:
			value_line_edit.text = str(cmd.value)

	if value_check:
		if cmd.variable_type == SetVariableCommand.VariableType.BOOL:
			value_check.button_pressed = cmd.value

	if value_spin:
		if cmd.variable_type == SetVariableCommand.VariableType.INT:
			value_spin.value = int(cmd.value)
		elif cmd.variable_type == SetVariableCommand.VariableType.FLOAT:
			value_spin.value = float(cmd.value)

	if defer_until_warp_check:
		defer_until_warp_check.button_pressed = cmd.defer_until_warp

## Aplica los valores editados al comando
func _apply_values_to_command() -> void:
	if not command:
		return

	command.variable_name = variable_name_line_edit.text if variable_name_line_edit else ""
	command.variable_type = variable_type_option.selected if variable_type_option else SetVariableCommand.VariableType.INT

	# Obtener el valor según el tipo
	match command.variable_type:
		SetVariableCommand.VariableType.INT:
			command.value = int(value_spin.value) if value_spin else 0
		SetVariableCommand.VariableType.BOOL:
			command.value = value_check.button_pressed if value_check else false
		SetVariableCommand.VariableType.STRING:
			command.value = value_line_edit.text if value_line_edit else ""
		SetVariableCommand.VariableType.FLOAT:
			command.value = float(value_spin.value) if value_spin else 0.0

	command.defer_until_warp = defer_until_warp_check.button_pressed if defer_until_warp_check else false

func _on_accept_pressed() -> void:
	_apply_values_to_command()
	command_edited.emit(command)
	hide()

func _on_cancel_pressed() -> void:
	cancelled.emit()
	hide()

func _on_close_requested() -> void:
	cancelled.emit()
	hide()

