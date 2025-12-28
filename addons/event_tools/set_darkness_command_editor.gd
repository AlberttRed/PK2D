@tool
extends Window

## Ventana de edición para SetDarknessCommand
## Permite editar todas las propiedades export del comando

signal command_edited(command: SetDarknessCommand)
signal cancelled

var command: SetDarknessCommand = null

# Valores originales para poder cancelar
var original_darkness: float = 0.0
var original_transition_time: float = 0.3

# Referencias a los controles
var darkness_spin: SpinBox = null
var transition_time_spin: SpinBox = null

func _ready() -> void:
	title = "Editar SetDarknessCommand"
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
	title_label.text = "Editar SetDarknessCommand"
	title_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title_label)
	vbox.add_child(HSeparator.new())

	# Darkness
	var darkness_container = HBoxContainer.new()
	var darkness_label = Label.new()
	darkness_label.text = "Oscuridad:"
	darkness_label.custom_minimum_size.x = 150
	darkness_container.add_child(darkness_label)

	darkness_spin = SpinBox.new()
	darkness_spin.min_value = 0.0
	darkness_spin.max_value = 1.0
	darkness_spin.step = 0.01
	darkness_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	darkness_container.add_child(darkness_spin)
	vbox.add_child(darkness_container)

	# Transition Time
	var transition_container = HBoxContainer.new()
	var transition_label = Label.new()
	transition_label.text = "Tiempo transición:"
	transition_label.custom_minimum_size.x = 150
	transition_container.add_child(transition_label)

	transition_time_spin = SpinBox.new()
	transition_time_spin.min_value = 0.0
	transition_time_spin.max_value = 5.0
	transition_time_spin.step = 0.05
	transition_time_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	transition_container.add_child(transition_time_spin)
	vbox.add_child(transition_container)

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
func load_command(cmd: SetDarknessCommand) -> void:
	if not cmd:
		push_error("SetDarknessCommandEditor: No se proporcionó un comando válido")
		return

	command = cmd

	# Guardar valores originales para poder cancelar
	original_darkness = cmd.darkness
	original_transition_time = cmd.transition_time

	if darkness_spin:
		darkness_spin.value = cmd.darkness

	if transition_time_spin:
		transition_time_spin.value = cmd.transition_time

## Aplica los valores editados al comando
func _apply_values_to_command() -> void:
	if not command:
		return

	command.darkness = darkness_spin.value if darkness_spin else 0.0
	command.transition_time = transition_time_spin.value if transition_time_spin else 0.3

## Restaura los valores originales del comando
func _restore_original_values() -> void:
	if not command:
		return

	command.darkness = original_darkness
	command.transition_time = original_transition_time

	if darkness_spin:
		darkness_spin.value = original_darkness

	if transition_time_spin:
		transition_time_spin.value = original_transition_time

func _on_accept_pressed() -> void:
	_apply_values_to_command()
	command_edited.emit(command)
	hide()

func _on_cancel_pressed() -> void:
	_restore_original_values()
	cancelled.emit()
	hide()

func _on_close_requested() -> void:
	_restore_original_values()
	cancelled.emit()
	hide()

