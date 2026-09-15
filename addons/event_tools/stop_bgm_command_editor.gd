@tool
extends Window

## Ventana de edición para StopBGMCommand

signal command_edited(command: StopBGMCommand)
signal cancelled

var command: StopBGMCommand = null
var original_fade_out: float = 0.5
var fade_spinbox: SpinBox = null


func _ready() -> void:
	title = "Editar StopBGMCommand"
	size = Vector2(420, 200)
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
	title_label.text = "Editar StopBGMCommand"
	title_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title_label)
	vbox.add_child(HSeparator.new())

	var fade_container = HBoxContainer.new()
	var fade_label = Label.new()
	fade_label.text = "Fade out (s):"
	fade_label.custom_minimum_size.x = 150
	fade_container.add_child(fade_label)

	fade_spinbox = SpinBox.new()
	fade_spinbox.min_value = 0.0
	fade_spinbox.max_value = 30.0
	fade_spinbox.step = 0.1
	fade_spinbox.value = 0.5
	fade_spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fade_container.add_child(fade_spinbox)
	vbox.add_child(fade_container)

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


func load_command(cmd: StopBGMCommand) -> void:
	if not cmd:
		push_error("StopBGMCommandEditor: No se proporcionó un comando válido")
		return
	command = cmd
	original_fade_out = cmd.fade_out
	if fade_spinbox:
		fade_spinbox.value = cmd.fade_out


func _apply_values_to_command() -> void:
	if not command:
		return
	command.fade_out = fade_spinbox.value if fade_spinbox else 0.5


func _restore_original_values() -> void:
	if not command:
		return
	command.fade_out = original_fade_out


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
