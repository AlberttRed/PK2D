@tool
extends Window

## Ventana mínima para HealPartyCommand (sin parámetros configurables).

signal command_edited(command: HealPartyCommand)
signal cancelled

var command: HealPartyCommand = null


func _ready() -> void:
	title = "Editar HealPartyCommand"
	size = Vector2(420, 180)
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
	title_label.text = "Editar HealPartyCommand"
	title_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title_label)
	vbox.add_child(HSeparator.new())

	var info_label = Label.new()
	info_label.text = "Cura el party completo (HP, estado y PP).\nSin mensajes ni sonido."
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(info_label)

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


func load_command(cmd: HealPartyCommand) -> void:
	if not cmd:
		push_error("HealPartyCommandEditor: No se proporcionó un comando válido")
		return
	command = cmd


func _on_accept_pressed() -> void:
	command_edited.emit(command)
	hide()


func _on_cancel_pressed() -> void:
	cancelled.emit()
	hide()


func _on_close_requested() -> void:
	cancelled.emit()
	hide()
