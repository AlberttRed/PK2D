@tool
extends Window

## Ventana de edición para WaitCommand
## Permite editar todas las propiedades export del comando

signal command_edited(command: WaitCommand)
signal cancelled

var command: WaitCommand = null

# Valores originales para poder cancelar
var original_duration: float = 1.0

# Referencias a los controles
var duration_spinbox: SpinBox = null

func _ready() -> void:
	title = "Editar WaitCommand"
	size = Vector2(400, 200)
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
	title_label.text = "Editar WaitCommand"
	title_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title_label)
	vbox.add_child(HSeparator.new())

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
func load_command(cmd: WaitCommand) -> void:
	if not cmd:
		push_error("WaitCommandEditor: No se proporcionó un comando válido")
		return

	command = cmd

	# Guardar valores originales para poder cancelar
	original_duration = cmd.duration

	# Cargar valores en los controles
	if duration_spinbox:
		duration_spinbox.value = cmd.duration

## Aplica los valores editados al comando
func _apply_values_to_command() -> void:
	if not command:
		return

	command.duration = duration_spinbox.value if duration_spinbox else 1.0

## Restaura los valores originales del comando
func _restore_original_values() -> void:
	if not command:
		return

	command.duration = original_duration

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

