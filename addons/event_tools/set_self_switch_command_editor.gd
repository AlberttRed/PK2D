@tool
extends Window

## Ventana de edición para SetSelfSwitchCommand
## Permite editar todas las propiedades export del comando

signal command_edited(command: SetSelfSwitchCommand)
signal cancelled

var command: SetSelfSwitchCommand = null

# Valores originales para poder cancelar
var original_target_event_name: String = ""
var original_switch_name: String = "A"
var original_switch_value: bool = true
var original_defer_until_warp: bool = false

# Referencias a los controles
var target_event_name_line_edit: LineEdit = null
var switch_name_line_edit: LineEdit = null
var switch_value_check: CheckBox = null
var defer_until_warp_check: CheckBox = null

func _ready() -> void:
	title = "Editar SetSelfSwitchCommand"
	size = Vector2(500, 450)
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
	title_label.text = "Editar SetSelfSwitchCommand"
	title_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title_label)
	vbox.add_child(HSeparator.new())

	# Target Event Name
	var target_event_container = HBoxContainer.new()
	var target_event_label = Label.new()
	target_event_label.text = "Evento objetivo:"
	target_event_label.custom_minimum_size.x = 150
	target_event_container.add_child(target_event_label)

	target_event_name_line_edit = LineEdit.new()
	target_event_name_line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_event_name_line_edit.placeholder_text = "(vacío = evento actual)"
	target_event_container.add_child(target_event_name_line_edit)
	vbox.add_child(target_event_container)

	var target_event_hint = Label.new()
	target_event_hint.text = "Dejar vacío para usar el evento actual"
	target_event_hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	target_event_hint.add_theme_font_size_override("font_size", 11)
	vbox.add_child(target_event_hint)

	# Separador para el grupo Self Switch
	vbox.add_child(HSeparator.new())

	var self_switch_label = Label.new()
	self_switch_label.text = "Self Switch:"
	self_switch_label.add_theme_constant_override("margin_top", 10)
	vbox.add_child(self_switch_label)

	# Switch Name
	var switch_name_container = HBoxContainer.new()
	var switch_name_label = Label.new()
	switch_name_label.text = "Nombre del switch:"
	switch_name_label.custom_minimum_size.x = 150
	switch_name_container.add_child(switch_name_label)

	switch_name_line_edit = LineEdit.new()
	switch_name_line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	switch_name_container.add_child(switch_name_line_edit)
	vbox.add_child(switch_name_container)

	# Switch Value
	switch_value_check = CheckBox.new()
	switch_value_check.text = "Valor del switch (activado = true)"
	vbox.add_child(switch_value_check)

	# Defer Until Warp
	defer_until_warp_check = CheckBox.new()
	defer_until_warp_check.text = "Diferido"
	defer_until_warp_check.tooltip_text = "Si está activado, el cambio del self-switch se aplicará cuando el mapa donde se registró se des-renderice (cuando ya no sea vecino del mapa actual o al hacer un warp). Esto asegura que los cambios se apliquen fuera de pantalla."
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
func load_command(cmd: SetSelfSwitchCommand) -> void:
	if not cmd:
		push_error("SetSelfSwitchCommandEditor: No se proporcionó un comando válido")
		return

	command = cmd

	# Guardar valores originales para poder cancelar
	original_target_event_name = cmd.target_event_name
	original_switch_name = cmd.switch_name
	original_switch_value = cmd.switch_value
	original_defer_until_warp = cmd.defer_until_warp

	# Cargar valores en los controles
	if target_event_name_line_edit:
		target_event_name_line_edit.text = cmd.target_event_name

	if switch_name_line_edit:
		switch_name_line_edit.text = cmd.switch_name

	if switch_value_check:
		switch_value_check.button_pressed = cmd.switch_value

	if defer_until_warp_check:
		defer_until_warp_check.button_pressed = cmd.defer_until_warp

## Aplica los valores editados al comando
func _apply_values_to_command() -> void:
	if not command:
		return

	command.target_event_name = target_event_name_line_edit.text if target_event_name_line_edit else ""
	command.switch_name = switch_name_line_edit.text if switch_name_line_edit else "A"
	command.switch_value = switch_value_check.button_pressed if switch_value_check else true
	command.defer_until_warp = defer_until_warp_check.button_pressed if defer_until_warp_check else false

func _on_accept_pressed() -> void:
	_apply_values_to_command()
	command_edited.emit(command)
	hide()

## Restaura los valores originales del comando
func _restore_original_values() -> void:
	if not command:
		return

	command.target_event_name = original_target_event_name
	command.switch_name = original_switch_name
	command.switch_value = original_switch_value
	command.defer_until_warp = original_defer_until_warp

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

