@tool
extends Window

## Editor para PokemonCenterHealCommand: ancla + offsets de bolas y monitor.

signal command_edited(command: PokemonCenterHealCommand)
signal cancelled

var command: PokemonCenterHealCommand = null
var _event_node: Node = null
var _machine_option: OptionButton = null
var _offset_x: SpinBox = null
var _offset_y: SpinBox = null
var _monitor_offset_x: SpinBox = null
var _monitor_offset_y: SpinBox = null

var _orig_machine: String = ""
var _orig_offset: Vector2 = Vector2(-48, -48)
var _orig_monitor_offset: Vector2 = Vector2(0, -64)

## Setter que refresca el desplegable al asignar el evento en edición.
var event_node: Node:
	get:
		return _event_node
	set(value):
		_event_node = value
		if _machine_option:
			_populate_event_names()
			if command:
				_set_option_selection(_machine_option, command.machine_event_name)


func _ready() -> void:
	title = "Editar PokemonCenterHealCommand"
	size = Vector2(480, 360)
	unresizable = false
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
	title_label.text = "PokemonCenterHealCommand"
	title_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title_label)
	vbox.add_child(HSeparator.new())

	var machine_row = HBoxContainer.new()
	var machine_label = Label.new()
	machine_label.text = "Evento ancla:"
	machine_label.custom_minimum_size.x = 150
	machine_row.add_child(machine_label)
	_machine_option = OptionButton.new()
	_machine_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	machine_row.add_child(_machine_option)
	vbox.add_child(machine_row)

	var machine_hint = Label.new()
	machine_hint.text = "Por defecto: el evento que ejecuta el comando (p. ej. EventoCP). Solo elige otro si la animación debe anclarse aparte."
	machine_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	machine_hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(machine_hint)

	var balls_hint = Label.new()
	balls_hint.text = "Offset animación de bolas (relativo al evento ancla)."
	balls_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	balls_hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(balls_hint)

	_offset_x = _add_spin(vbox, "Bolas Offset X:", -256, 256, 1, -48)
	_offset_y = _add_spin(vbox, "Bolas Offset Y:", -256, 256, 1, -48)

	var monitor_hint = Label.new()
	monitor_hint.text = "Offset animación del monitor / parpadeo (relativo al evento ancla)."
	monitor_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	monitor_hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(monitor_hint)

	_monitor_offset_x = _add_spin(vbox, "Monitor Offset X:", -256, 256, 1, 0)
	_monitor_offset_y = _add_spin(vbox, "Monitor Offset Y:", -256, 256, 1, -64)

	var buttons = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 10)
	var accept_button = Button.new()
	accept_button.text = "Aceptar"
	accept_button.pressed.connect(_on_accept_pressed)
	buttons.add_child(accept_button)
	var cancel_button = Button.new()
	cancel_button.text = "Cancelar"
	cancel_button.pressed.connect(_on_cancel_pressed)
	buttons.add_child(cancel_button)
	vbox.add_child(buttons)

	call_deferred("_populate_event_names")


func _add_spin(parent: VBoxContainer, label_text: String, min_v: float, max_v: float, step: float, value: float) -> SpinBox:
	var row = HBoxContainer.new()
	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 150
	row.add_child(label)
	var spin = SpinBox.new()
	spin.min_value = min_v
	spin.max_value = max_v
	spin.step = step
	spin.value = value
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spin)
	parent.add_child(row)
	return spin


func _get_current_grid() -> Node:
	if not _event_node:
		return null
	var parent = _event_node.get_parent()
	if parent and parent.name == "Events":
		var grid = parent.get_parent()
		if grid and grid.is_in_group("OverworldGrid"):
			return grid
	return null


func _populate_event_names() -> void:
	if not _machine_option:
		return
	var previous := ""
	if command:
		previous = command.machine_event_name
	elif _machine_option.get_item_count() > 0 and _machine_option.selected >= 0:
		var text := _machine_option.get_item_text(_machine_option.selected)
		if text != "(evento actual)":
			previous = text

	_machine_option.clear()
	_machine_option.add_item("(evento actual)")

	if _event_node:
		var grid = _get_current_grid()
		if grid:
			var events_container = grid.get_node_or_null("Events")
			if events_container:
				for child in events_container.get_children():
					if child is Event or (child.has_method("trigger") and child.has_method("setup_current_page")):
						if child.name != "" and child != _event_node:
							_machine_option.add_item(child.name)

	_set_option_selection(_machine_option, previous)


func _set_option_selection(option: OptionButton, value: String) -> void:
	if not option:
		return
	# Vacío = "(evento actual)" (índice 0)
	if value.is_empty():
		option.selected = 0
		return
	var found := false
	for i in range(option.get_item_count()):
		if option.get_item_text(i) == value:
			option.selected = i
			found = true
			break
	if not found:
		option.add_item(value)
		option.selected = option.get_item_count() - 1


func _get_selected_machine_name() -> String:
	if not _machine_option:
		return ""
	var selected_index = _machine_option.selected
	if selected_index < 0 or selected_index >= _machine_option.get_item_count():
		return ""
	var text := _machine_option.get_item_text(selected_index)
	if text == "(evento actual)":
		return ""
	return text


func load_command(cmd: PokemonCenterHealCommand) -> void:
	if not cmd:
		push_error("PokemonCenterHealCommandEditor: comando inválido")
		return
	command = cmd
	_orig_machine = cmd.machine_event_name
	_orig_offset = cmd.sprite_offset
	_orig_monitor_offset = cmd.monitor_offset
	if _machine_option:
		if _machine_option.get_item_count() == 0:
			_populate_event_names()
		_set_option_selection(_machine_option, cmd.machine_event_name)
	if _offset_x:
		_offset_x.value = cmd.sprite_offset.x
	if _offset_y:
		_offset_y.value = cmd.sprite_offset.y
	if _monitor_offset_x:
		_monitor_offset_x.value = cmd.monitor_offset.x
	if _monitor_offset_y:
		_monitor_offset_y.value = cmd.monitor_offset.y


func _apply() -> void:
	if not command:
		return
	command.machine_event_name = _get_selected_machine_name()
	command.sprite_offset = Vector2(_offset_x.value, _offset_y.value)
	command.monitor_offset = Vector2(_monitor_offset_x.value, _monitor_offset_y.value)


func _restore() -> void:
	if not command:
		return
	command.machine_event_name = _orig_machine
	command.sprite_offset = _orig_offset
	command.monitor_offset = _orig_monitor_offset
	if _machine_option:
		_set_option_selection(_machine_option, _orig_machine)


func _on_accept_pressed() -> void:
	_apply()
	command_edited.emit(command)
	hide()


func _on_cancel_pressed() -> void:
	_restore()
	cancelled.emit()
	hide()


func _on_close_requested() -> void:
	_restore()
	cancelled.emit()
	hide()
