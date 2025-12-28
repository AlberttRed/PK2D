@tool
extends Window

## Ventana de edición para SetFlashlightCommand
## Permite editar todas las propiedades export del comando

signal command_edited(command: SetFlashlightCommand)
signal cancelled

var command: SetFlashlightCommand = null

# Valores originales para poder cancelar
var original_enabled: bool = true
var original_radius: float = 0.35
var original_softness: float = 0.25
var original_apply_center: bool = false
var original_center: Vector2 = Vector2(0.5, 0.5)

# Referencias a los controles
var enabled_check: CheckBox = null
var radius_spin: SpinBox = null
var softness_spin: SpinBox = null
var apply_center_check: CheckBox = null
var center_x_spin: SpinBox = null
var center_y_spin: SpinBox = null

func _ready() -> void:
	title = "Editar SetFlashlightCommand"
	size = Vector2(450, 350)
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
	title_label.text = "Editar SetFlashlightCommand"
	title_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title_label)
	vbox.add_child(HSeparator.new())

	# Enabled
	var enabled_container = HBoxContainer.new()
	enabled_check = CheckBox.new()
	enabled_check.text = "Habilitado"
	enabled_check.button_pressed = true
	enabled_container.add_child(enabled_check)
	vbox.add_child(enabled_container)

	# Radius
	var radius_container = HBoxContainer.new()
	var radius_label = Label.new()
	radius_label.text = "Radio:"
	radius_label.custom_minimum_size.x = 150
	radius_container.add_child(radius_label)

	radius_spin = SpinBox.new()
	radius_spin.min_value = 0.05
	radius_spin.max_value = 1.0
	radius_spin.step = 0.01
	radius_spin.value = 0.35
	radius_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	radius_container.add_child(radius_spin)
	vbox.add_child(radius_container)

	# Softness
	var softness_container = HBoxContainer.new()
	var softness_label = Label.new()
	softness_label.text = "Suavidad:"
	softness_label.custom_minimum_size.x = 150
	softness_container.add_child(softness_label)

	softness_spin = SpinBox.new()
	softness_spin.min_value = 0.01
	softness_spin.max_value = 0.5
	softness_spin.step = 0.01
	softness_spin.value = 0.25
	softness_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	softness_container.add_child(softness_spin)
	vbox.add_child(softness_container)

	# Apply Center
	var apply_center_container = HBoxContainer.new()
	apply_center_check = CheckBox.new()
	apply_center_check.text = "Aplicar centro personalizado"
	apply_center_check.toggled.connect(_on_apply_center_toggled)
	apply_center_container.add_child(apply_center_check)
	vbox.add_child(apply_center_container)

	# Center X
	var center_x_container = HBoxContainer.new()
	var center_x_label = Label.new()
	center_x_label.text = "Centro X:"
	center_x_label.custom_minimum_size.x = 150
	center_x_container.add_child(center_x_label)

	center_x_spin = SpinBox.new()
	center_x_spin.min_value = 0.0
	center_x_spin.max_value = 1.0
	center_x_spin.step = 0.01
	center_x_spin.value = 0.5
	center_x_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_x_spin.editable = false
	center_x_container.add_child(center_x_spin)
	vbox.add_child(center_x_container)

	# Center Y
	var center_y_container = HBoxContainer.new()
	var center_y_label = Label.new()
	center_y_label.text = "Centro Y:"
	center_y_label.custom_minimum_size.x = 150
	center_y_container.add_child(center_y_label)

	center_y_spin = SpinBox.new()
	center_y_spin.min_value = 0.0
	center_y_spin.max_value = 1.0
	center_y_spin.step = 0.01
	center_y_spin.value = 0.5
	center_y_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_y_spin.editable = false
	center_y_container.add_child(center_y_spin)
	vbox.add_child(center_y_container)

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
func load_command(cmd: SetFlashlightCommand) -> void:
	if not cmd:
		push_error("SetFlashlightCommandEditor: No se proporcionó un comando válido")
		return

	command = cmd

	# Guardar valores originales para poder cancelar
	original_enabled = cmd.enabled
	original_radius = cmd.radius
	original_softness = cmd.softness
	original_apply_center = cmd.apply_center
	original_center = cmd.center

	if enabled_check:
		enabled_check.button_pressed = cmd.enabled

	if radius_spin:
		radius_spin.value = cmd.radius

	if softness_spin:
		softness_spin.value = cmd.softness

	if apply_center_check:
		apply_center_check.button_pressed = cmd.apply_center
		_on_apply_center_toggled(cmd.apply_center)

	if center_x_spin:
		center_x_spin.value = cmd.center.x

	if center_y_spin:
		center_y_spin.value = cmd.center.y

## Se llama cuando cambia el estado de "Aplicar centro"
func _on_apply_center_toggled(pressed: bool) -> void:
	if center_x_spin:
		center_x_spin.editable = pressed
	if center_y_spin:
		center_y_spin.editable = pressed

## Aplica los valores editados al comando
func _apply_values_to_command() -> void:
	if not command:
		return

	command.enabled = enabled_check.button_pressed if enabled_check else true
	command.radius = radius_spin.value if radius_spin else 0.35
	command.softness = softness_spin.value if softness_spin else 0.25
	command.apply_center = apply_center_check.button_pressed if apply_center_check else false
	command.center = Vector2(
		center_x_spin.value if center_x_spin else 0.5,
		center_y_spin.value if center_y_spin else 0.5
	)

## Restaura los valores originales del comando
func _restore_original_values() -> void:
	if not command:
		return

	command.enabled = original_enabled
	command.radius = original_radius
	command.softness = original_softness
	command.apply_center = original_apply_center
	command.center = original_center

	if enabled_check:
		enabled_check.button_pressed = original_enabled

	if radius_spin:
		radius_spin.value = original_radius

	if softness_spin:
		softness_spin.value = original_softness

	if apply_center_check:
		apply_center_check.button_pressed = original_apply_center
		_on_apply_center_toggled(original_apply_center)

	if center_x_spin:
		center_x_spin.value = original_center.x

	if center_y_spin:
		center_y_spin.value = original_center.y

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

