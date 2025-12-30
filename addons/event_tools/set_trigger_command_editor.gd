@tool
extends Window

## Ventana de edición para SetTriggerCommand
## Permite editar todas las propiedades export del comando

signal command_edited(command: SetTriggerCommand)
signal cancelled

var command: SetTriggerCommand = null
var _event_node: Node = null  # Referencia al evento para obtener otros eventos del mapa

## Setter para event_node que actualiza el dropdown cuando se asigna
var event_node: Node:
	get:
		return _event_node
	set(value):
		_event_node = value
		if target_event_option:
			_populate_event_names()
			if command:
				_set_option_selection(target_event_option, command.target_event_name, 0)

# Valores originales para poder cancelar
var original_target_event_name: String = ""
var original_page_index: int = 0
var original_trigger: EventTrigger = null

# Referencias a los controles
var target_event_option: OptionButton = null
var page_index_spin: SpinBox = null
var trigger_option: OptionButton = null

# Constantes para triggers (igual que en event_editor_popup.gd)
const TRIGGER_CONFIGS = {
	0: {"class": "Ninguno", "display": "Ninguno"},
	1: {"class": "ActionTrigger", "display": "Action"},
	2: {"class": "TouchTrigger", "display": "Touch"},
	3: {"class": "CollisionTrigger", "display": "Collision"},
	4: {"class": "AutorunTrigger", "display": "Autorun"}
}

const TRIGGER_CLASS_TO_INDEX = {
	"ActionTrigger": 1,
	"TouchTrigger": 2,
	"CollisionTrigger": 3,
	"AutorunTrigger": 4
}

func _ready() -> void:
	title = "Editar SetTriggerCommand"
	size = Vector2(450, 300)
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
	title_label.text = "Editar SetTriggerCommand"
	title_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title_label)
	vbox.add_child(HSeparator.new())

	# Target Event (Dropdown)
	var target_event_container = HBoxContainer.new()
	var target_event_label = Label.new()
	target_event_label.text = "Evento objetivo:"
	target_event_label.custom_minimum_size.x = 150
	target_event_container.add_child(target_event_label)

	target_event_option = OptionButton.new()
	target_event_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_event_option.item_selected.connect(_on_target_event_changed)
	target_event_container.add_child(target_event_option)
	vbox.add_child(target_event_container)

	# Poblar el dropdown después de añadirlo (se actualizará cuando se asigne event_node)
	call_deferred("_populate_event_names")

	# Page Index
	var page_index_container = HBoxContainer.new()
	var page_index_label = Label.new()
	page_index_label.text = "Página:"
	page_index_label.custom_minimum_size.x = 150
	page_index_container.add_child(page_index_label)

	page_index_spin = SpinBox.new()
	page_index_spin.min_value = 1  # Mostrar base 1 (1, 2, 3...)
	page_index_spin.max_value = 1  # Se actualizará cuando se seleccione un evento
	page_index_spin.value = 1
	page_index_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_index_container.add_child(page_index_spin)
	vbox.add_child(page_index_container)

	# Trigger
	var trigger_container = HBoxContainer.new()
	var trigger_label = Label.new()
	trigger_label.text = "Trigger:"
	trigger_label.custom_minimum_size.x = 150
	trigger_container.add_child(trigger_label)

	trigger_option = OptionButton.new()
	trigger_option.name = "TriggerOption"
	for i in range(5):
		trigger_option.add_item(TRIGGER_CONFIGS[i].display, i)
	trigger_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trigger_container.add_child(trigger_option)
	vbox.add_child(trigger_container)

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

## Helper: Obtiene el OverworldGrid del mapa actual
func _get_current_grid() -> Node:
	if not _event_node:
		return null
	var parent = _event_node.get_parent()
	if parent and parent.name == "Events":
		var grid = parent.get_parent()
		if grid and grid.is_in_group("OverworldGrid"):
			return grid
	return null

## Helper: Busca y selecciona un item en un OptionButton, añadiéndolo si no existe
func _set_option_selection(option: OptionButton, value: String, default_index: int = 0) -> void:
	if not option:
		return

	var selected_index = default_index
	if value != "":
		var found = false
		for i in range(option.get_item_count()):
			if option.get_item_text(i) == value:
				selected_index = i
				found = true
				break
		if not found:
			option.add_item(value)
			selected_index = option.get_item_count() - 1

	option.selected = selected_index

## Pobla el dropdown con "(evento actual)" y los nombres de los eventos del mapa
func _populate_event_names() -> void:
	if not target_event_option:
		return

	target_event_option.clear()

	# Añadir "(evento actual)" primero (vacío)
	target_event_option.add_item("(evento actual)")

	# Si tenemos el event_node, obtener los eventos del mapa
	if _event_node:
		var grid = _get_current_grid()
		if grid:
			var events_container = grid.get_node_or_null("Events")
			if events_container:
				for child in events_container.get_children():
					if child is Event or (child.has_method("trigger") and child.has_method("setup_current_page")):
						if child.name != "" and child != _event_node:
							target_event_option.add_item(child.name)

	# Actualizar el límite de páginas según el evento seleccionado
	call_deferred("_update_page_index_limits")

## Se llama cuando cambia la selección del evento objetivo
func _on_target_event_changed(_index: int) -> void:
	_update_page_index_limits()

## Actualiza los límites del SpinBox de página según el evento seleccionado
func _update_page_index_limits() -> void:
	if not page_index_spin or not target_event_option:
		return

	var target_event = _get_selected_event()
	var max_pages = 1

	if target_event:
		# Obtener el número de páginas del evento
		if "pages" in target_event:
			max_pages = max(1, target_event.pages.size())
		elif target_event.has_method("get_pages"):
			var pages = target_event.get_pages()
			if pages:
				max_pages = max(1, pages.size())

	# Actualizar el max_value del SpinBox
	page_index_spin.max_value = max_pages

	# Asegurar que el valor actual esté dentro del rango
	if page_index_spin.value > max_pages:
		page_index_spin.value = max_pages
	if page_index_spin.value < 1:
		page_index_spin.value = 1

## Obtiene el evento seleccionado en el dropdown
func _get_selected_event() -> Node:
	if not target_event_option:
		return null

	var selected_index = target_event_option.selected
	if selected_index < 0 or selected_index >= target_event_option.get_item_count():
		return null

	var selected_text = target_event_option.get_item_text(selected_index)

	# Si es "(evento actual)", usar el event_node
	if selected_text == "(evento actual)":
		return _event_node

	# Buscar el evento por nombre
	if _event_node:
		var grid = _get_current_grid()
		if grid:
			var events_container = grid.get_node_or_null("Events")
			if events_container:
				for child in events_container.get_children():
					if child is Event or (child.has_method("trigger") and child.has_method("setup_current_page")):
						if child.name == selected_text:
							return child

	return null

## Obtiene el índice del trigger actual
func _get_trigger_index(trigger: EventTrigger) -> int:
	if not trigger:
		return 0
	var script = trigger.get_script()
	if not script:
		return 0
	var trigger_class = script.get_global_name()
	return TRIGGER_CLASS_TO_INDEX.get(trigger_class, 0)

## Carga un comando existente para editar
func load_command(cmd: SetTriggerCommand) -> void:
	if not cmd:
		push_error("SetTriggerCommandEditor: No se proporcionó un comando válido")
		return

	command = cmd

	# Guardar valores originales para poder cancelar
	original_target_event_name = cmd.target_event_name
	original_page_index = cmd.page_index
	original_trigger = cmd.trigger.duplicate(true) if cmd.trigger else null

	# Asegurar que los eventos estén poblados antes de seleccionar
	if target_event_option:
		if target_event_option.get_item_count() == 0:
			_populate_event_names()
		_set_option_selection(target_event_option, cmd.target_event_name, 0)

	if page_index_spin:
		# Convertir de base 0 (interno) a base 1 (mostrado)
		page_index_spin.value = cmd.page_index + 1
		# Actualizar límites después de establecer el valor
		call_deferred("_update_page_index_limits")

	if trigger_option:
		trigger_option.selected = _get_trigger_index(cmd.trigger)

## Aplica los valores editados al comando
func _apply_values_to_command() -> void:
	if not command:
		return

	# Obtener el nombre del evento desde el dropdown
	var target_event_name = ""
	if target_event_option:
		var selected_index = target_event_option.selected
		if selected_index >= 0 and selected_index < target_event_option.get_item_count():
			var selected_text = target_event_option.get_item_text(selected_index)
			# Si no es "(evento actual)", usar el texto seleccionado
			if selected_text != "(evento actual)":
				target_event_name = selected_text

	command.target_event_name = target_event_name
	# Convertir de base 1 (mostrado) a base 0 (interno)
	command.page_index = int(page_index_spin.value) - 1 if page_index_spin else 0

	# Aplicar el trigger según la selección
	var trigger_index = trigger_option.selected if trigger_option else 0
	var config = TRIGGER_CONFIGS.get(trigger_index, TRIGGER_CONFIGS[0])
	var trigger_class = config.class

	if trigger_class == "Ninguno":
		command.trigger = null
	else:
		var script_path = "res://Scripts/Events/Triggers/" + trigger_class + ".gd"
		var script = load(script_path)
		if script:
			var trigger_resource = script.new()
			if trigger_resource is EventTrigger:
				command.trigger = trigger_resource as EventTrigger
			else:
				push_error("SetTriggerCommandEditor: El script " + trigger_class + " no es un EventTrigger válido")
				command.trigger = null
		else:
			push_error("SetTriggerCommandEditor: No se encontró el script para " + trigger_class)
			command.trigger = null

## Restaura los valores originales del comando
func _restore_original_values() -> void:
	if not command:
		return

	command.target_event_name = original_target_event_name
	command.page_index = original_page_index
	command.trigger = original_trigger.duplicate(true) if original_trigger else null

	if target_event_option:
		_set_option_selection(target_event_option, original_target_event_name, 0)

	if page_index_spin:
		# Convertir de base 0 (interno) a base 1 (mostrado)
		page_index_spin.value = original_page_index + 1
		call_deferred("_update_page_index_limits")

	if trigger_option:
		trigger_option.selected = _get_trigger_index(original_trigger)

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

