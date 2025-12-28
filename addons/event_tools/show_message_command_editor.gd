@tool
extends Window

## Ventana de edición para ShowMessageCommand
## Permite editar todas las propiedades export del comando

signal command_edited(command: ShowMessageCommand)
signal cancelled

var command: ShowMessageCommand = null

# Valores originales para poder cancelar
var original_message: String = ""
var original_wait_input: bool = true
var original_close_at_end: bool = true
var original_wait_time: float = 0.0
var original_show_icon_at_end: bool = false
var original_frame_style: int = 0

# Referencias a los controles
var message_text_edit: TextEdit = null
var wait_input_check: CheckBox = null
var close_at_end_check: CheckBox = null
var wait_time_spin: SpinBox = null
var show_icon_at_end_check: CheckBox = null
var frame_style_option: OptionButton = null

func _ready() -> void:
	title = "Editar ShowMessageCommand"
	size = Vector2(600, 500)
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
	title_label.text = "Editar ShowMessageCommand"
	title_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title_label)
	vbox.add_child(HSeparator.new())

	# Mensaje (multiline)
	var message_label = Label.new()
	message_label.text = "Mensaje:"
	vbox.add_child(message_label)

	message_text_edit = TextEdit.new()
	message_text_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	message_text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	vbox.add_child(message_text_edit)

	# Opciones
	var options_label = Label.new()
	options_label.text = "Opciones:"
	options_label.add_theme_constant_override("margin_top", 10)
	vbox.add_child(options_label)

	# Wait Input
	wait_input_check = CheckBox.new()
	wait_input_check.text = "Esperar input del jugador"
	vbox.add_child(wait_input_check)

	# Close at End
	close_at_end_check = CheckBox.new()
	close_at_end_check.text = "Cerrar al final"
	vbox.add_child(close_at_end_check)

	# Wait Time
	var wait_time_container = HBoxContainer.new()
	var wait_time_label = Label.new()
	wait_time_label.text = "Tiempo de espera:"
	wait_time_label.custom_minimum_size.x = 150
	wait_time_container.add_child(wait_time_label)

	wait_time_spin = SpinBox.new()
	wait_time_spin.min_value = 0.0
	wait_time_spin.max_value = 999.0
	wait_time_spin.step = 0.1
	wait_time_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wait_time_container.add_child(wait_time_spin)
	vbox.add_child(wait_time_container)

	# Show Icon at End
	show_icon_at_end_check = CheckBox.new()
	show_icon_at_end_check.text = "Mostrar icono al final"
	vbox.add_child(show_icon_at_end_check)

	# Frame Style
	var frame_style_container = HBoxContainer.new()
	var frame_style_label = Label.new()
	frame_style_label.text = "Estilo de marco:"
	frame_style_label.custom_minimum_size.x = 150
	frame_style_container.add_child(frame_style_label)

	frame_style_option = OptionButton.new()
	frame_style_option.add_item("HeartGold/SoulSilver")
	frame_style_option.add_item("Cartel 1")
	frame_style_option.add_item("FireRed")
	frame_style_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame_style_container.add_child(frame_style_option)
	vbox.add_child(frame_style_container)

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
func load_command(cmd: ShowMessageCommand) -> void:
	if not cmd:
		push_error("ShowMessageCommandEditor: No se proporcionó un comando válido")
		return

	command = cmd

	# Guardar valores originales para poder cancelar
	original_message = cmd.message
	original_wait_input = cmd.wait_input
	original_close_at_end = cmd.close_at_end
	original_wait_time = cmd.wait_time
	original_show_icon_at_end = cmd.show_icon_at_end
	original_frame_style = cmd.frame_style

	# Cargar valores en los controles
	if message_text_edit:
		message_text_edit.text = cmd.message

	if wait_input_check:
		wait_input_check.button_pressed = cmd.wait_input

	if close_at_end_check:
		close_at_end_check.button_pressed = cmd.close_at_end

	if wait_time_spin:
		wait_time_spin.value = cmd.wait_time

	if show_icon_at_end_check:
		show_icon_at_end_check.button_pressed = cmd.show_icon_at_end

	if frame_style_option:
		frame_style_option.selected = cmd.frame_style

## Aplica los valores editados al comando
func _apply_values_to_command() -> void:
	if not command:
		return

	command.message = message_text_edit.text if message_text_edit else ""
	command.wait_input = wait_input_check.button_pressed if wait_input_check else true
	command.close_at_end = close_at_end_check.button_pressed if close_at_end_check else true
	command.wait_time = wait_time_spin.value if wait_time_spin else 0.0
	command.show_icon_at_end = show_icon_at_end_check.button_pressed if show_icon_at_end_check else false
	command.frame_style = frame_style_option.selected if frame_style_option else MessageBoxFrameStyle.Values.HGSS

func _on_accept_pressed() -> void:
	_apply_values_to_command()
	command_edited.emit(command)
	hide()

## Restaura los valores originales del comando
func _restore_original_values() -> void:
	if not command:
		return

	command.message = original_message
	command.wait_input = original_wait_input
	command.close_at_end = original_close_at_end
	command.wait_time = original_wait_time
	command.show_icon_at_end = original_show_icon_at_end
	command.frame_style = original_frame_style

func _on_cancel_pressed() -> void:
	# Restaurar valores originales antes de cancelar
	_restore_original_values()
	cancelled.emit()
	hide()

func _on_close_requested() -> void:
	# Restaurar valores originales antes de cerrar
	_restore_original_values()
	cancelled.emit()
	hide()

