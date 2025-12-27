@tool
extends Window

## Ventana de edición para SetFlagCommand
## Permite editar todas las propiedades export del comando

signal command_edited(command: SetFlagCommand)
signal cancelled

var command: SetFlagCommand = null

# Referencias a los controles
var flag_name_line_edit: LineEdit = null
var flag_value_check: CheckBox = null
var defer_until_warp_check: CheckBox = null

func _ready() -> void:
	title = "Editar SetFlagCommand"
	size = Vector2(500, 300)
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
	title_label.text = "Editar SetFlagCommand"
	title_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title_label)
	vbox.add_child(HSeparator.new())

	# Flag Name
	var flag_name_container = HBoxContainer.new()
	var flag_name_label = Label.new()
	flag_name_label.text = "Nombre del flag:"
	flag_name_label.custom_minimum_size.x = 150
	flag_name_container.add_child(flag_name_label)

	flag_name_line_edit = LineEdit.new()
	flag_name_line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flag_name_container.add_child(flag_name_line_edit)
	vbox.add_child(flag_name_container)

	# Flag Value
	flag_value_check = CheckBox.new()
	flag_value_check.text = "Valor del flag (activado = true)"
	vbox.add_child(flag_value_check)

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

## Carga un comando existente para editar
func load_command(cmd: SetFlagCommand) -> void:
	if not cmd:
		push_error("SetFlagCommandEditor: No se proporcionó un comando válido")
		return

	command = cmd

	# Cargar valores en los controles
	if flag_name_line_edit:
		flag_name_line_edit.text = cmd.flag_name

	if flag_value_check:
		flag_value_check.button_pressed = cmd.flag_value

	if defer_until_warp_check:
		defer_until_warp_check.button_pressed = cmd.defer_until_warp

## Aplica los valores editados al comando
func _apply_values_to_command() -> void:
	if not command:
		return

	command.flag_name = flag_name_line_edit.text if flag_name_line_edit else ""
	command.flag_value = flag_value_check.button_pressed if flag_value_check else true
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

