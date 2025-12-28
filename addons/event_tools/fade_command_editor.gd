@tool
extends Window

## Ventana de edición para FadeCommand
## Permite editar todas las propiedades export del comando

signal command_edited(command: FadeCommand)
signal cancelled

var command: FadeCommand = null

# Valores originales para poder cancelar
var original_mode: int = 0
var original_duration: float = 1.0
var original_wait_for_completion: bool = true

# Referencias a los controles
var mode_option: OptionButton = null
var duration_spinbox: SpinBox = null
var wait_for_completion_check: CheckBox = null

func _ready() -> void:
	title = "Editar FadeCommand"
	size = Vector2(400, 250)
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
	title_label.text = "Editar FadeCommand"
	title_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title_label)
	vbox.add_child(HSeparator.new())

	# Mode
	var mode_container = HBoxContainer.new()
	var mode_label = Label.new()
	mode_label.text = "Modo:"
	mode_label.custom_minimum_size.x = 150
	mode_container.add_child(mode_label)

	mode_option = OptionButton.new()
	mode_option.add_item("Fade In")
	mode_option.add_item("Fade Out")
	mode_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_container.add_child(mode_option)
	vbox.add_child(mode_container)

	# Duration
	var duration_container = HBoxContainer.new()
	var duration_label = Label.new()
	duration_label.text = "Duración (segundos):"
	duration_label.custom_minimum_size.x = 150
	duration_container.add_child(duration_label)

	duration_spinbox = SpinBox.new()
	duration_spinbox.min_value = 0.0
	duration_spinbox.max_value = 999.0
	duration_spinbox.step = 0.1
	duration_spinbox.value = 1.0
	duration_spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	duration_container.add_child(duration_spinbox)
	vbox.add_child(duration_container)

	# Wait for Completion
	var wait_for_completion_check = CheckBox.new()
	wait_for_completion_check.text = "Esperar a que termine el fade"
	wait_for_completion_check.button_pressed = true
	vbox.add_child(wait_for_completion_check)
	self.wait_for_completion_check = wait_for_completion_check

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
func load_command(cmd: FadeCommand) -> void:
	if not cmd:
		push_error("FadeCommandEditor: No se proporcionó un comando válido")
		return

	command = cmd

	# Guardar valores originales para poder cancelar
	original_mode = cmd.mode
	original_duration = cmd.duration
	original_wait_for_completion = cmd.wait_for_completion

	# Cargar valores en los controles
	if mode_option:
		mode_option.selected = cmd.mode

	if duration_spinbox:
		duration_spinbox.value = cmd.duration

	if wait_for_completion_check:
		wait_for_completion_check.button_pressed = cmd.wait_for_completion

## Aplica los valores editados al comando
func _apply_values_to_command() -> void:
	if not command:
		return

	command.mode = mode_option.selected if mode_option else 0
	command.duration = duration_spinbox.value if duration_spinbox else 1.0
	command.wait_for_completion = wait_for_completion_check.button_pressed if wait_for_completion_check else true

## Restaura los valores originales del comando
func _restore_original_values() -> void:
	if not command:
		return

	command.mode = original_mode
	command.duration = original_duration
	command.wait_for_completion = original_wait_for_completion

func _on_accept_pressed() -> void:
	_apply_values_to_command()
	command_edited.emit(command)
	hide()

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

