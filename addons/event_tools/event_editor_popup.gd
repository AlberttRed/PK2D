@tool
extends Window

## Ventana de edición de eventos
## Muestra las páginas del evento en pestañas

var event_node: Node = null
var tab_container: TabContainer = null
var page_buttons: Dictionary = {}  # page_index -> {add: Button, edit: Button, delete: Button}
var page_controls: Dictionary = {}  # page_index -> {execution_option: OptionButton, trigger_option: OptionButton, blocks_player_check: CheckBox, through_check: CheckBox, conditions_button: Button}
var editor_interface: EditorInterface = null
var current_command_editor: Window = null  # Referencia a la ventana de edición actual

# Copia de seguridad del evento original para poder cancelar
var original_event_backup: Array[EventPage] = []
var has_unsaved_changes: bool = false  # Bandera para detectar si hay cambios sin guardar

# Estado del modo mover
var move_mode_active: Dictionary = {}  # page_index -> bool
var command_to_move: Dictionary = {}  # page_index -> {type: String, metadata: Dictionary, item: TreeItem, nested_command_index: int}
var move_source_page_index: int = -1  # Página de origen cuando se está moviendo entre páginas
var move_backup: Dictionary = {}  # Guarda copias de seguridad de las páginas antes de mover

# Constantes para triggers
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
	unresizable = false
	always_on_top = false
	exclusive = true
	close_requested.connect(_on_close_requested)
	tab_container = $VBoxContainer/TabContainer

	# Conectar señal de cambio de tab
	if tab_container:
		tab_container.tab_changed.connect(_on_tab_changed)

	if has_meta("pending_event_node"):
		event_node = get_meta("pending_event_node")
		remove_meta("pending_event_node")

	if has_meta("editor_interface"):
		editor_interface = get_meta("editor_interface")
		remove_meta("editor_interface")

	if event_node:
		_setup_for_event()

func _unhandled_input(event: InputEvent) -> void:
	# Manejar ESC para cerrar la ventana
	if not is_node_ready() or not is_inside_tree():
		return

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			# Verificar que no hay un diálogo abierto que deba manejar el ESC primero
			var has_open_dialog = false
			for child in get_children():
				if child is AcceptDialog and child.visible:
					has_open_dialog = true
					break

			if not has_open_dialog:
				_on_close_requested()
				get_viewport().set_input_as_handled()

func _setup_for_event() -> void:
	if not _validate_event_node():
		return

	title = "Event Editor - " + event_node.name
	_clear_tabs()

	# Limpiar páginas null al abrir el editor
	_clean_null_pages_on_open()

	# Duplicar páginas si son Resources compartidos para evitar modificar la escena original
	_duplicate_event_pages()

	# Guardar copia de seguridad de todas las páginas antes de editar
	_save_event_backup()
	has_unsaved_changes = false  # Inicializar bandera de cambios

	_create_page_tabs()
	# Añadir botón para crear nuevas páginas
	_add_new_page_button()
	# Añadir botón Guardar en la interfaz
	_add_save_button()
	popup_centered()

func _clear_tabs() -> void:
	if not tab_container:
		return
	# Eliminar los hijos de forma inmediata para evitar problemas con los índices
	var children = tab_container.get_children()
	for child in children:
		tab_container.remove_child(child)
		child.queue_free()
	page_buttons.clear()
	page_controls.clear()

func _create_page_tabs() -> void:
	if not _validate_event_node() or not tab_container:
		return

	if not "pages" in event_node:
		push_error("Event Editor: El nodo Event no tiene el array 'pages'")
		return

	var pages = event_node.pages
	if pages.is_empty():
		var empty_tab = Control.new()
		empty_tab.name = "EmptyPage"
		tab_container.add_child(empty_tab)
		tab_container.set_tab_title(0, "Sin páginas")
		return

	for i in range(pages.size()):
		var page = pages[i]
		if page:  # Solo crear pestaña si la página no es null
			_create_page_tab(i, page)
		else:
			push_warning("Event Editor: La página %d es null, se omitirá" % i)

	# Actualizar estado de los botones después de crear las pestañas
	_update_page_management_buttons_state()

func _create_page_tab(page_index: int, page: EventPage) -> void:
	# Validar que la página no sea null
	if not page:
		push_warning("Event Editor: La página %d es null, no se puede crear la pestaña" % page_index)
		return

	var main_split = HSplitContainer.new()
	main_split.name = "Page" + str(page_index)

	var left_panel = _create_left_panel(page_index, page)
	var right_panel = _create_right_panel(page_index, page)

	if left_panel:
		main_split.add_child(left_panel)
	if right_panel:
		main_split.add_child(right_panel)
	tab_container.add_child(main_split)
	tab_container.set_tab_title(page_index, "Página " + str(page_index + 1))

func _create_left_panel(page_index: int, page: EventPage) -> VBoxContainer:
	var left_panel = VBoxContainer.new()

	# Validar que la página no sea null
	if not page:
		var error_label = Label.new()
		error_label.text = "Error: La página es null"
		error_label.add_theme_color_override("font_color", Color.RED)
		left_panel.add_child(error_label)
		return left_panel

	var title_label = Label.new()
	title_label.text = "Configuración de Página"
	title_label.add_theme_font_size_override("font_size", 16)
	left_panel.add_child(title_label)
	left_panel.add_child(HSeparator.new())

	# Execution Mode
	var execution_label = Label.new()
	execution_label.text = "Modo de Ejecución:"
	left_panel.add_child(execution_label)

	var execution_option = OptionButton.new()
	execution_option.add_item("En Cola (QUEUED)", EventPage.ExecutionMode.QUEUED)
	execution_option.add_item("Paralelo (PARALLEL)", EventPage.ExecutionMode.PARALLEL)
	execution_option.selected = page.execution_mode
	execution_option.item_selected.connect(func(idx): _on_execution_mode_changed(page_index, idx))
	left_panel.add_child(execution_option)

	left_panel.add_child(_create_spacer(10))

	# Trigger
	var trigger_label = Label.new()
	trigger_label.text = "Trigger:"
	left_panel.add_child(trigger_label)

	var trigger_option = OptionButton.new()
	trigger_option.name = "TriggerOption"
	for i in range(5):
		trigger_option.add_item(TRIGGER_CONFIGS[i].display, i)

	var current_index = _get_trigger_index(page.trigger)
	trigger_option.selected = current_index
	trigger_option.item_selected.connect(func(idx): _on_trigger_changed(page_index, idx))
	left_panel.add_child(trigger_option)

	left_panel.add_child(_create_spacer(10))

	# Blocks Player
	var blocks_player_check = CheckBox.new()
	blocks_player_check.text = "Bloquea al Jugador"
	blocks_player_check.button_pressed = page.blocks_player
	blocks_player_check.toggled.connect(func(pressed): _on_blocks_player_changed(page_index, pressed))
	left_panel.add_child(blocks_player_check)

	# Through
	var through_check = CheckBox.new()
	through_check.text = "Atraviesa"
	through_check.button_pressed = page.through
	through_check.toggled.connect(func(pressed): _on_through_changed(page_index, pressed))
	left_panel.add_child(through_check)

	# Spacer para empujar el botón hacia abajo
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.add_child(spacer)

	# Botón de cambiar nombre
	var change_name_button = Button.new()
	change_name_button.text = "Cambiar Nombre"
	change_name_button.pressed.connect(func(): _on_change_name_button_pressed(page_index))
	left_panel.add_child(change_name_button)

	# Botón de condiciones
	var conditions_button = Button.new()
	conditions_button.text = "Gestionar Condiciones"
	conditions_button.pressed.connect(func(): _on_conditions_button_pressed(page_index))
	left_panel.add_child(conditions_button)

	# Botón de sprite
	var sprite_button = Button.new()
	sprite_button.text = "Gestionar Sprite"
	sprite_button.pressed.connect(func(): _on_sprite_button_pressed(page_index))
	left_panel.add_child(sprite_button)

	# Label y botón de posición
	var position_label = Label.new()
	position_label.text = "Posición: "
	left_panel.add_child(position_label)

	# Contenedor horizontal para el valor y el botón de borrar
	var position_hbox = HBoxContainer.new()
	position_hbox.name = "PositionHBox"

	var position_value_label = Label.new()
	position_value_label.name = "PositionValueLabel"
	# Inicializar con texto por defecto, se actualizará después
	position_value_label.text = "No definida (usa posición del evento)"
	position_value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	position_hbox.add_child(position_value_label)

	# Botón de borrar posición (se mostrará/ocultará según si hay posición)
	var clear_position_button = Button.new()
	clear_position_button.name = "ClearPositionButton"
	clear_position_button.text = "Borrar"
	clear_position_button.visible = false  # Oculto por defecto
	clear_position_button.pressed.connect(func(): _on_clear_position_button_pressed(page_index))
	position_hbox.add_child(clear_position_button)

	left_panel.add_child(position_hbox)

	# Verificar inmediatamente si hay posición y ocultar el botón si no la hay
	# Usar la misma lógica que _get_position_text para ser consistente
	var pos = page.get("page_position")
	var has_position = false
	if pos != null and pos is Vector2i:
		if pos.x >= 0 and pos.y >= 0:
			has_position = true

	# SIEMPRE ocultar el botón inicialmente, solo mostrarlo si hay posición
	clear_position_button.visible = false
	if has_position:
		clear_position_button.visible = true

	# Actualizar después de que el nodo esté en el árbol (por si acaso)
	call_deferred("_update_position_label", page_index)

	# Botón de cambiar posición
	var map_view_button = Button.new()
	map_view_button.text = "Cambiar Posición"
	map_view_button.pressed.connect(func(): _on_map_view_button_pressed(page_index))
	left_panel.add_child(map_view_button)

	# Botón de movimiento (solo para NPCs y Trainers)
	if _is_npc_or_trainer():
		var movement_button = Button.new()
		movement_button.text = "Gestionar Movimiento"
		movement_button.pressed.connect(func(): _on_movement_button_pressed(page_index))
		left_panel.add_child(movement_button)

		# Botón de trainer (solo para Trainers, pero como Trainer hereda de NPC, aparece para ambos)
		# Aunque técnicamente solo funciona para Trainers
		var trainer_button = Button.new()
		trainer_button.text = "Gestionar Trainer"
		trainer_button.pressed.connect(func(): _on_trainer_button_pressed(page_index))
		left_panel.add_child(trainer_button)

		# Guardar referencias a los controles
		page_controls[page_index] = {
			"execution_option": execution_option,
			"trigger_option": trigger_option,
			"blocks_player_check": blocks_player_check,
			"through_check": through_check,
			"conditions_button": conditions_button,
			"change_name_button": change_name_button,
			"sprite_button": sprite_button,
			"movement_button": movement_button,
			"trainer_button": trainer_button
		}
	else:
		# Guardar referencias a los controles
		page_controls[page_index] = {
			"execution_option": execution_option,
			"trigger_option": trigger_option,
			"blocks_player_check": blocks_player_check,
			"through_check": through_check,
			"conditions_button": conditions_button,
			"change_name_button": change_name_button,
			"sprite_button": sprite_button
		}

	return left_panel

func _create_right_panel(page_index: int, page: EventPage) -> VBoxContainer:
	var right_panel = VBoxContainer.new()

	# Validar que la página no sea null
	if not page:
		var error_label = Label.new()
		error_label.text = "Error: La página es null"
		error_label.add_theme_color_override("font_color", Color.RED)
		right_panel.add_child(error_label)
		return right_panel

	var commands_title = Label.new()
	commands_title.text = "Comandos"
	commands_title.add_theme_font_size_override("font_size", 16)
	right_panel.add_child(commands_title)
	right_panel.add_child(HSeparator.new())

	var buttons_container = HBoxContainer.new()
	var add_button = Button.new()
	add_button.text = "Añadir"
	add_button.pressed.connect(func(): _on_add_command_pressed(page_index))

	var edit_button = Button.new()
	edit_button.text = "Editar"
	edit_button.disabled = true
	edit_button.pressed.connect(func(): _on_edit_command_pressed(page_index))

	var delete_button = Button.new()
	delete_button.text = "Eliminar"
	delete_button.disabled = true
	delete_button.pressed.connect(func(): _on_delete_command_pressed(page_index))

	var move_up_button = Button.new()
	move_up_button.text = "↑"
	move_up_button.disabled = true
	move_up_button.pressed.connect(func(): _on_move_command_up_pressed(page_index))

	var move_down_button = Button.new()
	move_down_button.text = "↓"
	move_down_button.disabled = true
	move_down_button.pressed.connect(func(): _on_move_command_down_pressed(page_index))

	var move_button = Button.new()
	move_button.text = "Mover"
	move_button.disabled = true
	move_button.pressed.connect(func(): _on_move_command_pressed(page_index))

	var duplicate_button = Button.new()
	duplicate_button.text = "Duplicar"
	duplicate_button.disabled = true
	duplicate_button.pressed.connect(func(): _on_duplicate_command_pressed(page_index))

	var accept_move_button = Button.new()
	accept_move_button.text = "Aceptar"
	accept_move_button.disabled = true
	accept_move_button.visible = false
	accept_move_button.pressed.connect(func(): _on_accept_move_pressed(page_index))

	var cancel_move_button = Button.new()
	cancel_move_button.text = "Cancelar"
	cancel_move_button.visible = false
	cancel_move_button.pressed.connect(func(): _on_cancel_move_pressed(page_index))

	buttons_container.add_child(add_button)
	buttons_container.add_child(edit_button)
	buttons_container.add_child(delete_button)
	buttons_container.add_child(duplicate_button)
	buttons_container.add_child(HSeparator.new())
	buttons_container.add_child(move_up_button)
	buttons_container.add_child(move_down_button)
	buttons_container.add_child(HSeparator.new())
	buttons_container.add_child(move_button)
	buttons_container.add_child(accept_move_button)
	buttons_container.add_child(cancel_move_button)
	right_panel.add_child(buttons_container)

	page_buttons[page_index] = {
		"add": add_button,
		"edit": edit_button,
		"delete": delete_button,
		"duplicate": duplicate_button,
		"move_up": move_up_button,
		"move_down": move_down_button,
		"move": move_button,
		"accept_move": accept_move_button,
		"cancel_move": cancel_move_button
	}

	move_mode_active[page_index] = false

	var commands_container = PanelContainer.new()
	commands_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	commands_container.mouse_filter = Control.MOUSE_FILTER_STOP

	var commands_tree = Tree.new()
	commands_tree.name = "CommandsTree"
	commands_tree.select_mode = Tree.SELECT_SINGLE
	commands_tree.columns = 1  # Una sola columna con nombre y detalle
	commands_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	commands_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	commands_tree.item_selected.connect(func(): _on_command_selected(page_index))
	commands_tree.nothing_selected.connect(func(): _on_command_deselected(page_index))
	commands_tree.item_activated.connect(func(): _on_edit_command_pressed(page_index))
	commands_tree.gui_input.connect(func(event): _on_commands_tree_gui_input(page_index, event))
	_update_commands_tree(commands_tree, page, page_index)
	commands_container.add_child(commands_tree)

	right_panel.add_child(commands_container)
	return right_panel

func _create_spacer(height: int) -> Control:
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer

# === HELPERS DE VALIDACIÓN ===
func _is_npc_or_trainer() -> bool:
	if not event_node:
		return false
	# Verificar si es NPC o Trainer usando el script
	var script = event_node.get_script()
	if script:
		var script_class = script.get_global_name()
		if script_class == "NPC" or script_class == "Trainer":
			return true
		# También verificar por nombre de archivo del script
		var script_path = script.resource_path
		if script_path:
			if "NPC.gd" in script_path or "Trainer.gd" in script_path:
				return true
	# Verificar usando is_instance_of (más robusto, pero puede fallar si las clases no están cargadas)
	if event_node.has_method("get_movement_type"):
		# NPC tiene este método, así que es una forma indirecta de verificar
		return true
	return false

func _validate_event_node() -> bool:
	return event_node != null and tab_container != null

func _get_page(page_index: int) -> EventPage:
	if not _validate_event_node() or page_index >= event_node.pages.size():
		return null
	return event_node.pages[page_index]

func _get_trigger_index(trigger: EventTrigger) -> int:
	if not trigger:
		return 0
	var script = trigger.get_script()
	if not script:
		return 0
	var trigger_class = script.get_global_name()
	return TRIGGER_CLASS_TO_INDEX.get(trigger_class, 0)

func _get_trigger_display_name(trigger_class: String) -> String:
	if trigger_class.ends_with("Trigger"):
		return trigger_class.replace("Trigger", "")
	return trigger_class

# === MANEJO DE TRIGGERS ===
func _on_trigger_changed(page_index: int, selected_index: int) -> void:
	var page = _get_page(page_index)
	if not page:
		return

	var old_trigger_name = _get_trigger_class_name(page.trigger)
	var config = TRIGGER_CONFIGS.get(selected_index, TRIGGER_CONFIGS[0])
	var new_trigger_class = config.class

	if old_trigger_name == "Ninguno" and new_trigger_class != "Ninguno":
		_apply_trigger_change(page_index, new_trigger_class)
		return

	if old_trigger_name != new_trigger_class:
		var old_display = _get_trigger_display_name(old_trigger_name)
		_show_trigger_change_confirmation(page_index, old_display, config.display, new_trigger_class)
	else:
		_restore_trigger_selection(page_index)

func _get_trigger_class_name(trigger: EventTrigger) -> String:
	if not trigger:
		return "Ninguno"
	var script = trigger.get_script()
	if script:
		return script.get_global_name()
	return "Ninguno"

func _show_trigger_change_confirmation(page_index: int, old_display: String, new_display: String, new_class: String) -> void:
	var dialog = _create_confirmation_dialog(
		"Confirmar cambio de trigger",
		"¿Estás seguro de que quieres cambiar el trigger de '" + old_display + "' a '" + new_display + "'?",
		func(): _apply_trigger_change(page_index, new_class),
		func(): _restore_trigger_selection(page_index)
	)
	dialog.popup_centered()

func _apply_trigger_change(page_index: int, trigger_class: String) -> void:
	var page = _get_page(page_index)
	if not page:
		return

	var editable_page = page.duplicate(true) as EventPage
	if not editable_page:
		push_error("Event Editor: No se pudo duplicar la página")
		return

	var new_trigger: EventTrigger = null
	if trigger_class != "Ninguno":
		var script_path = "res://Scripts/Events/Triggers/" + trigger_class + ".gd"
		var script = load(script_path)
		if script:
			var trigger_resource = script.new()
			if trigger_resource is EventTrigger:
				new_trigger = trigger_resource as EventTrigger
			else:
				push_error("Event Editor: El script " + trigger_class + " no es un EventTrigger válido")
				return
		else:
			push_error("Event Editor: No se encontró el script para " + trigger_class)
			return

	editable_page.trigger = new_trigger
	event_node.pages[page_index] = editable_page
	_mark_as_changed()
	print("Event Editor: Trigger cambiado a ", _get_trigger_display_name(trigger_class))

func _restore_trigger_selection(page_index: int) -> void:
	var page = _get_page(page_index)
	if not page:
		return

	var tab = tab_container.get_child(page_index) if page_index < tab_container.get_child_count() else null
	if not tab:
		return

	var trigger_option = _find_child_by_name(tab, "TriggerOption", OptionButton)
	if trigger_option:
		trigger_option.selected = _get_trigger_index(page.trigger)

func _find_child_by_name(node: Node, name: String, node_type: Variant = null) -> Node:
	if node.name == name:
		if node_type == null:
			return node
		# Verificar tipos específicos usando comparación directa de clases
		if node_type == Tree:
			if node is Tree:
				return node
		elif node_type == OptionButton:
			if node is OptionButton:
				return node

	for child in node.get_children():
		var result = _find_child_by_name(child, name, node_type)
		if result:
			return result
	return null

# === ACTUALIZACIÓN DEL ÁRBOL DE COMANDOS ===
func _update_commands_tree(commands_tree: Tree, page: EventPage, page_index: int = -1, override_move_info: Dictionary = {}) -> void:
	if not commands_tree:
		return

	commands_tree.clear()
	var root = commands_tree.create_item()

	if not page:
		root.set_text(0, "Página - (Sin página)")
		return

	# Construir el texto de la página con nombre y condiciones
	var page_text = "Página"
	if page.page_name and not page.page_name.is_empty():
		page_text += " '" + page.page_name + "'"
	if page.commands.is_empty():
		page_text += " - (Sin comandos)"

	# Añadir condiciones
	if page.root_condition:
		var condition_text = _get_condition_display_text(page.root_condition)
		page_text += " - " + condition_text
	else:
		page_text += " - (Sin condiciones)"

	root.set_text(0, page_text)
	# Si hay override_move_info, usar ese (para modo mover entre páginas)
	# Si no, usar el move_info de la página actual
	var in_move_mode = false
	var move_info = {}
	if not override_move_info.is_empty():
		move_info = override_move_info
		in_move_mode = true
	elif page_index >= 0:
		in_move_mode = move_mode_active.get(page_index, false)
		move_info = command_to_move.get(page_index, {})

	# Aplicar estilo de modo mover a la raíz si está activo
	if in_move_mode:
		_apply_move_mode_style(root, move_info, page_index)

	for i in range(page.commands.size()):
		var command = page.commands[i]
		if not command:
			var item = commands_tree.create_item(root)
			item.set_text(0, str(i + 1) + ". (null)")
			continue

		var command_name = _get_command_name_safe(command)
		var item = commands_tree.create_item(root)

		# Construir el texto con nombre y detalle con separador claro
		var item_text = str(i + 1) + ". " + command_name
		var detail_text = _get_command_detail_text(command)
		if detail_text != "":
			item_text += "  ▸  " + detail_text  # Separador más distintivo

		item.set_text(0, item_text)

		# Añadir tooltip para ShowMessageCommand con el mensaje completo
		if command is ShowMessageCommand:
			var msg_cmd = command as ShowMessageCommand
			if not msg_cmd.message.is_empty():
				item.set_tooltip_text(0, msg_cmd.message)

		# Añadir tooltip para MoveNPCCommand con todas las acciones
		if command is MoveNPCCommand:
			var move_cmd = command as MoveNPCCommand
			if not move_cmd.path.is_empty():
				var all_actions: Array[String] = []
				for dir_enum in move_cmd.path:
					var action_str = _direction_enum_to_string(dir_enum)
					if action_str != "":
						all_actions.append(action_str)
				if not all_actions.is_empty():
					item.set_tooltip_text(0, ", ".join(all_actions))

		item.set_metadata(0, {"type": "command", "index": i, "command": command})

		# Aplicar estilo de modo mover (usar page_index actual, no el origen)
		if in_move_mode:
			_apply_move_mode_style(item, move_info, page_index)

		_add_nested_commands_to_tree(item, command, page_index, move_info, in_move_mode)

func _get_command_name_safe(command: EventCommand) -> String:
	if not command:
		return "Unknown"
	var script = command.get_script()
	if not script:
		return "Unknown"
	var command_name = script.get_global_name()
	if command_name.is_empty():
		var script_path = script.resource_path
		if script_path:
			command_name = script_path.get_file().get_basename()
	if command_name.ends_with("Command"):
		command_name = command_name.replace("Command", "")
	return command_name

## Obtiene el texto de detalle para mostrar en la segunda columna del árbol
func _get_command_detail_text(command: EventCommand) -> String:
	if not command:
		return ""

	# ShowMessageCommand: mostrar solo la primera línea del mensaje
	if command is ShowMessageCommand:
		var msg_cmd = command as ShowMessageCommand
		var message_text = msg_cmd.message
		if message_text.is_empty():
			return ""
		# Obtener solo la primera línea (hasta el primer salto de línea)
		var first_line_end = message_text.find("\n")
		if first_line_end >= 0:
			return message_text.substr(0, first_line_end)
		return message_text

	# SetFlagCommand: mostrar flag y valor
	if command is SetFlagCommand:
		var flag_cmd = command as SetFlagCommand
		var value_str = "true" if flag_cmd.flag_value else "false"
		return "'%s' = %s" % [flag_cmd.flag_name, value_str]

	# SetVariableCommand: mostrar variable y valor
	if command is SetVariableCommand:
		var var_cmd = command as SetVariableCommand
		var value_str = _value_to_string(var_cmd.value)
		return "'%s' = %s" % [var_cmd.variable_name, value_str]

	# SetSelfSwitchCommand: mostrar switch y valor
	if command is SetSelfSwitchCommand:
		var switch_cmd = command as SetSelfSwitchCommand
		var value_str = "true" if switch_cmd.switch_value else "false"
		return "Switch '%s' = %s" % [switch_cmd.switch_name, value_str]

	# ShowChoicesCommand: mostrar el mensaje (primera línea)
	if command is ShowChoicesCommand:
		var choices_cmd = command as ShowChoicesCommand
		var message_text = choices_cmd.message
		if message_text.is_empty():
			return ""
		# Obtener solo la primera línea (hasta el primer salto de línea)
		var first_line_end = message_text.find("\n")
		if first_line_end >= 0:
			return message_text.substr(0, first_line_end)
		return message_text

	# MoveNPCCommand: mostrar target y las acciones del path
	if command is MoveNPCCommand:
		var move_cmd = command as MoveNPCCommand

		# Añadir el nombre del target
		var target_str = move_cmd.target_name
		if target_str.is_empty():
			target_str = "(self)"

		var result = target_str

		if move_cmd.path.is_empty():
			return result + " - (Sin acciones)"

		# Convertir las direcciones a texto abreviado
		var actions: Array[String] = []
		for dir_enum in move_cmd.path:
			var action_str = _direction_enum_to_string(dir_enum)
			if action_str != "":
				actions.append(action_str)

		if actions.is_empty():
			return result + " - (Sin acciones)"

		# Limitar a 10 acciones para no hacer el texto muy largo
		var display_actions = actions.slice(0, 10)
		result += " - " + ", ".join(display_actions)
		if actions.size() > 10:
			result += " ... (+%d más)" % (actions.size() - 10)

		return result

	# SetEventThroughCommand: mostrar target y through
	if command is SetEventThroughCommand:
		var through_cmd = command as SetEventThroughCommand
		var target_str = through_cmd.target_event_name
		if target_str.is_empty():
			target_str = "(self)"
		var through_str = "true" if through_cmd.through else "false"
		return "%s: %s" % [target_str, through_str]

	# SetTriggerCommand: mostrar target, página y trigger
	if command is SetTriggerCommand:
		var trigger_cmd = command as SetTriggerCommand
		var target_str = trigger_cmd.target_event_name
		if target_str.is_empty():
			target_str = "(self)"
		var trigger_str = "Ninguno"
		if trigger_cmd.trigger:
			var script = trigger_cmd.trigger.get_script()
			if script:
				var trigger_class = script.get_global_name()
				if trigger_class == "ActionTrigger":
					trigger_str = "Action"
				elif trigger_class == "TouchTrigger":
					trigger_str = "Touch"
				elif trigger_class == "CollisionTrigger":
					trigger_str = "Collision"
				elif trigger_class == "AutorunTrigger":
					trigger_str = "Autorun"
		# Mostrar página en base 1 (1, 2, 3...) aunque internamente sea base 0
		return "%s, página %d, %s" % [target_str, trigger_cmd.page_index + 1, trigger_str]

	# SetActorVisibilityCommand: mostrar target y visible
	if command is SetActorVisibilityCommand:
		var vis_cmd = command as SetActorVisibilityCommand
		var target_str = ""
		if vis_cmd.target_type == 0:  # Event
			target_str = vis_cmd.target_event_name
			if target_str.is_empty():
				target_str = "(self)"
		else:  # Player
			target_str = "Player"
		var visible_str = "true" if vis_cmd.visible else "false"
		return "%s: %s" % [target_str, visible_str]

	# WaitCommand: mostrar tiempo de espera
	if command is WaitCommand:
		var wait_cmd = command as WaitCommand
		return "%.2fs" % wait_cmd.duration

	# WarpCommand: mostrar actor y mapa destino
	if command is WarpCommand:
		var warp_cmd = command as WarpCommand
		var actor_str = warp_cmd.actor_name
		if actor_str.is_empty():
			actor_str = "(self)"
		var map_str = warp_cmd.target_scene
		if map_str.is_empty():
			map_str = "(mismo mapa)"
		return "%s → %s" % [actor_str, map_str]

	# FollowActorCommand: mostrar follower, leader y start/stop
	if command is FollowActorCommand:
		var follow_cmd = command as FollowActorCommand
		var follower_str = follow_cmd.follower_actor_name
		if follower_str.is_empty():
			follower_str = "(self)"
		var leader_str = follow_cmd.leader_actor_name
		if leader_str.is_empty():
			leader_str = "(sin leader)"
		var action_str = "START" if follow_cmd.action == 0 else "STOP"
		return "%s → %s (%s)" % [follower_str, leader_str, action_str]

	# FadeCommand: mostrar IN/OUT y tiempo
	if command is FadeCommand:
		var fade_cmd = command as FadeCommand
		var fade_type_str = "IN" if fade_cmd.mode == FadeCommand.FadeMode.IN else "OUT"
		return "%s (%.2fs)" % [fade_type_str, fade_cmd.duration]

	# PlayAnimationCommand: mostrar target y nombre de animación
	if command is PlayAnimationCommand:
		var anim_cmd = command as PlayAnimationCommand
		var target_str = anim_cmd.target_name
		if target_str.is_empty():
			target_str = "(self)"
		var anim_str = anim_cmd.animation_name
		if anim_str.is_empty():
			anim_str = "(sin animación)"
		return "%s: %s" % [target_str, anim_str]

	# ShowPortraitCommand: mostrar tipo (Pokémon/Textura) y nombre
	if command is ShowPortraitCommand:
		var portrait_cmd = command as ShowPortraitCommand
		var type_str = ""
		var name_str = ""

		if portrait_cmd.image_source == ShowPortraitCommand.ImageSource.POKEMON:
			type_str = "Pokémon"
			# Obtener el nombre del Pokémon desde PokemonsEnum
			name_str = PokemonsEnum.get_display_name(portrait_cmd.pokemon_species)
			if name_str.is_empty():
				name_str = "Especie %d" % portrait_cmd.pokemon_species
		elif portrait_cmd.image_source == ShowPortraitCommand.ImageSource.TEXTURE:
			type_str = "Textura"
			if portrait_cmd.texture:
				# Obtener el nombre del archivo desde la ruta del recurso
				var resource_path = portrait_cmd.texture.resource_path
				if resource_path:
					name_str = resource_path.get_file()
				else:
					name_str = "(textura sin ruta)"
			else:
				name_str = "(sin textura)"
		else:
			return "(sin configuración)"

		return "%s: %s" % [type_str, name_str]

	return ""

## Obtiene el texto descriptivo de una condición
func _get_condition_display_text(cond: EventCondition) -> String:
	if not cond:
		return "(null)"

	if cond is FlagCondition:
		var flag_cond = cond as FlagCondition
		var scope_str = "Global" if flag_cond.scope == FlagCondition.Scope.GLOBAL else "Self"
		var value_str = "true" if flag_cond.expected_value else "false"
		return "Flag (%s): '%s' = %s" % [scope_str, flag_cond.flag_name, value_str]

	if cond is VariableCondition:
		var var_cond = cond as VariableCondition
		var op_str = _get_operator_string(var_cond.operator)
		var value_str = _value_to_string(var_cond.compare_value)
		return "Variable: '%s' %s %s" % [var_cond.variable_name, op_str, value_str]

	if cond is GroupCondition:
		var group_cond = cond as GroupCondition
		var mode_str = "AND" if group_cond.mode == GroupCondition.Mode.ALL else "OR"
		var child_texts: Array[String] = []
		for child_cond in group_cond.children:
			if child_cond:
				child_texts.append(_get_condition_display_text(child_cond))
		if child_texts.is_empty():
			return "%s (vacío)" % mode_str
		return "%s (%s)" % [mode_str, ", ".join(child_texts)]

	if cond is NotCondition:
		return "NOT (...)"

	return "Condición desconocida"

## Convierte un operador a string
func _get_operator_string(op: int) -> String:
	match op:
		VariableCondition.Operator.EQUAL: return "=="
		VariableCondition.Operator.NOT_EQUAL: return "!="
		VariableCondition.Operator.GREATER: return ">"
		VariableCondition.Operator.GREATER_EQUAL: return ">="
		VariableCondition.Operator.LESS: return "<"
		VariableCondition.Operator.LESS_EQUAL: return "<="
		_: return "?"

## Convierte un valor a string
func _value_to_string(value: Variant) -> String:
	if value == null:
		return "null"
	if value is String:
		return '"%s"' % value
	if value is bool:
		return "true" if value else "false"
	return str(value)

## Convierte un DirectionEnum.Type a string abreviado
func _direction_enum_to_string(dir_enum: int) -> String:
	match dir_enum:
		DirectionEnum.Type.UP: return "↑"
		DirectionEnum.Type.DOWN: return "↓"
		DirectionEnum.Type.LEFT: return "←"
		DirectionEnum.Type.RIGHT: return "→"
		DirectionEnum.Type.WAIT_025: return "W0.25"
		DirectionEnum.Type.WAIT_050: return "W0.5"
		DirectionEnum.Type.WAIT_100: return "W1.0"
		DirectionEnum.Type.LOOK_UP: return "L↑"
		DirectionEnum.Type.LOOK_DOWN: return "L↓"
		DirectionEnum.Type.LOOK_LEFT: return "L←"
		DirectionEnum.Type.LOOK_RIGHT: return "L→"
		DirectionEnum.Type.LOOK_PLAYER: return "LPlayer"
		DirectionEnum.Type.TURN_UP: return "T↑"
		DirectionEnum.Type.TURN_DOWN: return "T↓"
		DirectionEnum.Type.TURN_LEFT: return "T←"
		DirectionEnum.Type.TURN_RIGHT: return "T→"
		DirectionEnum.Type.SPEED_NORMAL: return "SN"
		DirectionEnum.Type.SPEED_FASTER: return "SF"
		DirectionEnum.Type.SPEED_FASTEST: return "SF+"
		DirectionEnum.Type.SPEED_SLOWER: return "SS"
		DirectionEnum.Type.SPEED_SLOWEST: return "SS-"
		DirectionEnum.Type.EXCLAMATION_ANIM: return "!"
		_: return "?"

func _add_nested_commands_to_tree(parent_item: TreeItem, command: EventCommand, page_index: int = -1, move_info: Dictionary = {}, in_move_mode: bool = false) -> void:
	if command is ConditionalCommand:
		var cond_cmd = command as ConditionalCommand
		for branch_idx in range(cond_cmd.branches.size()):
			var branch = cond_cmd.branches[branch_idx]
			var branch_item = parent_item.get_tree().create_item(parent_item)
			var condition_text = "ELSE"
			if branch.condition:
				condition_text = _get_condition_display_text(branch.condition)
			branch_item.set_text(0, "  └─ Branch " + str(branch_idx) + " (" + condition_text + ")")
			branch_item.set_metadata(0, {"type": "branch", "branch": branch, "parent_command": command, "branch_index": branch_idx})

			if in_move_mode:
				_apply_move_mode_style(branch_item, move_info, page_index)

			_add_nested_commands_from_array(branch_item, branch.commands, page_index, move_info, in_move_mode)

	elif command is ShowChoicesCommand:
		var choices_cmd = command as ShowChoicesCommand
		for branch_idx in range(choices_cmd.branches.size()):
			var branch = choices_cmd.branches[branch_idx]
			var branch_item = parent_item.get_tree().create_item(parent_item)
			branch_item.set_text(0, "  └─ Choice: \"" + branch.label + "\"")
			branch_item.set_metadata(0, {"type": "choice_branch", "branch": branch, "parent_command": command, "branch_index": branch_idx})

			if in_move_mode:
				_apply_move_mode_style(branch_item, move_info, page_index)

			_add_nested_commands_from_array(branch_item, branch.commands, page_index, move_info, in_move_mode)

	elif command is SwitchCommand:
		var switch_cmd = command as SwitchCommand
		for case_idx in range(switch_cmd.cases.size()):
			var case = switch_cmd.cases[case_idx]
			var case_item = parent_item.get_tree().create_item(parent_item)
			case_item.set_text(0, "  └─ Case: " + str(case.values))
			case_item.set_metadata(0, {"type": "switch_case", "case": case, "parent_command": command, "case_index": case_idx})

			if in_move_mode:
				_apply_move_mode_style(case_item, move_info, page_index)

			_add_nested_commands_from_array(case_item, case.commands, page_index, move_info, in_move_mode)

		if switch_cmd.default_commands.size() > 0:
			var default_item = parent_item.get_tree().create_item(parent_item)
			default_item.set_text(0, "  └─ Default")
			default_item.set_metadata(0, {"type": "default_commands", "parent_command": command})

			if in_move_mode:
				_apply_move_mode_style(default_item, move_info, page_index)

			_add_nested_commands_from_array(default_item, switch_cmd.default_commands, page_index, move_info, in_move_mode)

func _add_nested_commands_from_array(parent_item: TreeItem, commands: Array, page_index: int = -1, move_info: Dictionary = {}, in_move_mode: bool = false) -> void:
	for cmd_idx in range(commands.size()):
		var nested_cmd = commands[cmd_idx]
		if nested_cmd:
			var cmd_item = parent_item.get_tree().create_item(parent_item)

			# Construir el texto con nombre y detalle con separador claro
			var nested_text = "    └─ " + _get_command_name_safe(nested_cmd)
			var detail_text = _get_command_detail_text(nested_cmd)
			if detail_text != "":
				nested_text += "  ▸  " + detail_text  # Separador más distintivo

			cmd_item.set_text(0, nested_text)

			# Añadir tooltip para ShowMessageCommand con el mensaje completo
			if nested_cmd is ShowMessageCommand:
				var msg_cmd = nested_cmd as ShowMessageCommand
				if not msg_cmd.message.is_empty():
					cmd_item.set_tooltip_text(0, msg_cmd.message)

			# Añadir tooltip para MoveNPCCommand con todas las acciones
			if nested_cmd is MoveNPCCommand:
				var move_cmd = nested_cmd as MoveNPCCommand
				if not move_cmd.path.is_empty():
					var all_actions: Array[String] = []
					for dir_enum in move_cmd.path:
						var action_str = _direction_enum_to_string(dir_enum)
						if action_str != "":
							all_actions.append(action_str)
					if not all_actions.is_empty():
						cmd_item.set_tooltip_text(0, ", ".join(all_actions))

			cmd_item.set_metadata(0, {"type": "nested_command", "command": nested_cmd, "parent_branch": parent_item.get_metadata(0)})

			if in_move_mode:
				_apply_move_mode_style(cmd_item, move_info, page_index)

			_add_nested_commands_to_tree(cmd_item, nested_cmd, page_index, move_info, in_move_mode)

# === FUNCIONES DE MODO MOVER ===
func _apply_move_mode_style(item: TreeItem, move_info: Dictionary, page_index: int) -> void:
	if not move_info.has("type"):
		return

	var item_metadata = item.get_metadata(0)
	var move_type = move_info.type

	# Si es la raíz (no tiene metadata o es el root)
	var is_root = false
	if not item_metadata or not item_metadata.has("type"):
		# Verificar si es el root del árbol
		var tree = item.get_tree()
		if tree:
			var root = tree.get_root()
			if root == item:
				is_root = true
				# Verificar si estamos moviendo entre páginas diferentes
				var source_page_index = move_source_page_index if move_source_page_index >= 0 else page_index
				var is_cross_page = (move_source_page_index >= 0 and page_index != source_page_index)

				# La raíz es válida si:
				# 1. Se mueve un nested_command (misma página o entre páginas)
				# 2. Se mueve un command entre páginas diferentes
				if move_type == "nested_command" or (move_type == "command" and is_cross_page):
					# La raíz es válida
					item.set_selectable(0, true)
					item.set_custom_color(0, Color(0.2, 0.8, 0.2, 1.0))  # Verde
					return
				else:
					# Para command en la misma página, la raíz no es válida directamente
					item.set_selectable(0, false)
					item.set_custom_color(0, Color(0.5, 0.5, 0.5, 0.3))
					return

	if not item_metadata or not item_metadata.has("type"):
		return

	var item_type = item_metadata.type

	# Determinar si este item es un destino válido
	var is_valid_destination = item_type in ["branch", "choice_branch", "switch_case", "default_commands"]

	# Si es command, NO es válido cuando se mueve un nested_command (solo la raíz es válida)
	if item_type == "command":
		if move_type == "nested_command":
			# Los comandos de primer nivel NO son válidos, solo la raíz
			is_valid_destination = false
		else:
			# Si el comando a mover es un command principal, el padre es válido
			var move_metadata = move_info.get("metadata", {})
			if move_metadata.has("index"):
				var move_index = move_metadata.index
				var item_index = item_metadata.get("index", -1)
				# El comando de arriba (índice - 1) es válido si puede tener hijos
				if item_index == move_index - 1:
					var page = _get_page(page_index)
					if page and item_index >= 0 and item_index < page.commands.size():
						var parent_cmd = page.commands[item_index]
						if parent_cmd is ConditionalCommand or parent_cmd is ShowChoicesCommand or parent_cmd is SwitchCommand:
							is_valid_destination = true

	# Si es el comando a mover, deshabilitarlo y atenuarlo
	var is_moving_item = false
	if move_type == "command" and item_type == "command":
		var move_metadata = move_info.get("metadata", {})
		if move_metadata.has("index") and item_metadata.has("index"):
			if move_metadata.index == item_metadata.index:
				is_moving_item = true
	elif move_type == "nested_command" and item_type == "nested_command":
		var move_metadata = move_info.get("metadata", {})
		var move_cmd = move_metadata.get("command")
		var item_cmd = item_metadata.get("command")
		if move_cmd == item_cmd:
			is_moving_item = true

	if is_moving_item:
		# Deshabilitar y atenuar el item que se está moviendo
		item.set_selectable(0, false)
		item.set_custom_color(0, Color(0.5, 0.5, 0.5, 0.5))
	elif is_valid_destination:
		# Resaltar destinos válidos
		item.set_selectable(0, true)
		item.set_custom_color(0, Color(0.2, 0.8, 0.2, 1.0))  # Verde para destinos válidos
	else:
		# Deshabilitar y atenuar items no válidos
		item.set_selectable(0, false)
		item.set_custom_color(0, Color(0.5, 0.5, 0.5, 0.3))

func _move_command_to_destination(source_page_index: int, dest_page_index: int, destination_metadata: Dictionary, destination_item: TreeItem) -> bool:
	# Si es la misma página, usar la lógica normal
	if source_page_index == dest_page_index:
		return _move_command_to_destination_same_page(source_page_index, destination_metadata, destination_item)

	# Mover entre páginas diferentes
	var source_page = _get_page(source_page_index)
	var dest_page = _get_page(dest_page_index)

	if not source_page or not dest_page:
		push_error("Event Editor: No se encontró la página de origen o destino")
		return false

	var move_info = command_to_move.get(source_page_index, {})
	if not move_info.has("type"):
		push_error("Event Editor: No hay información del comando a mover")
		return false

	# Guardar backup antes de modificar
	move_backup[source_page_index] = source_page.duplicate(true) as EventPage
	move_backup[dest_page_index] = dest_page.duplicate(true) as EventPage

	var editable_source_page = source_page.duplicate(true) as EventPage
	var editable_dest_page = dest_page.duplicate(true) as EventPage

	if not editable_source_page or not editable_dest_page:
		push_error("Event Editor: No se pudo duplicar la página")
		_restore_from_backup([source_page_index, dest_page_index])
		return false

	# Remover el comando de la página origen y añadirlo a la página destino
	var move_type = move_info.type
	var move_metadata = move_info.get("metadata", {})

	if move_type == "command":
		# Mover comando principal entre páginas
		var command_index = move_metadata.get("index", -1)
		if command_index < 0 or command_index >= editable_source_page.commands.size():
			push_error("Event Editor: Índice de comando inválido")
			_restore_from_backup([source_page_index, dest_page_index])
			return false

		# IMPORTANTE: Guardar el comando ANTES de removerlo
		var command_to_move_obj = editable_source_page.commands[command_index]

		# Remover del origen usando set para evitar problemas con arrays read-only
		var new_source_commands: Array[EventCommand] = []
		for i in range(editable_source_page.commands.size()):
			if i != command_index:
				new_source_commands.append(editable_source_page.commands[i])
		editable_source_page.set("commands", new_source_commands)

		# Añadir al destino según el tipo
		var destination_type = destination_metadata.type
		var added_successfully = false

		if destination_type == "command":
			var dest_index = destination_metadata.get("index", -1)
			var new_dest_commands: Array[EventCommand] = []
			for cmd in editable_dest_page.commands:
				new_dest_commands.append(cmd)

			if dest_index >= 0 and dest_index < new_dest_commands.size():
				new_dest_commands.insert(dest_index + 1, command_to_move_obj)
			else:
				new_dest_commands.append(command_to_move_obj)

			editable_dest_page.set("commands", new_dest_commands)
			added_successfully = true
		elif destination_type in ["branch", "choice_branch", "switch_case", "default_commands"]:
			# Añadir al final del branch/case
			var parent_command = destination_metadata.get("parent_command")
			if parent_command:
				var parent_cmd_index = -1
				for i in range(dest_page.commands.size()):
					if dest_page.commands[i] == parent_command:
						parent_cmd_index = i
						break

				if parent_cmd_index >= 0 and parent_cmd_index < editable_dest_page.commands.size():
					var cmd = editable_dest_page.commands[parent_cmd_index]
					if destination_type == "branch" and cmd is ConditionalCommand:
						var cond_cmd = cmd as ConditionalCommand
						var original_branch = destination_metadata.get("branch")
						if original_branch:
							var original_cond_cmd = parent_command as ConditionalCommand
							var branch_index = -1
							for i in range(original_cond_cmd.branches.size()):
								if original_cond_cmd.branches[i] == original_branch:
									branch_index = i
									break
							if branch_index >= 0 and branch_index < cond_cmd.branches.size():
								_add_command_to_branch_case(cmd, "branch", branch_index, -1, command_to_move_obj)
					elif destination_type == "choice_branch" and cmd is ShowChoicesCommand:
						var choices_cmd = cmd as ShowChoicesCommand
						var original_branch = destination_metadata.get("branch")
						if original_branch:
							var original_choices_cmd = parent_command as ShowChoicesCommand
							var branch_index = -1
							for i in range(original_choices_cmd.branches.size()):
								if original_choices_cmd.branches[i] == original_branch:
									branch_index = i
									break
							if branch_index >= 0 and branch_index < choices_cmd.branches.size():
								_add_command_to_branch_case(cmd, "choice_branch", branch_index, -1, command_to_move_obj)
					elif destination_type == "switch_case" and cmd is SwitchCommand:
						var switch_cmd = cmd as SwitchCommand
						var original_case = destination_metadata.get("case")
						if original_case:
							var original_switch_cmd = parent_command as SwitchCommand
							var case_index = -1
							for i in range(original_switch_cmd.cases.size()):
								if original_switch_cmd.cases[i] == original_case:
									case_index = i
									break
							if case_index >= 0 and case_index < switch_cmd.cases.size():
								_add_command_to_branch_case(cmd, "switch_case", -1, case_index, command_to_move_obj)
					elif destination_type == "default_commands" and cmd is SwitchCommand:
						var switch_cmd = cmd as SwitchCommand
						_add_command_to_branch_case(cmd, "default_commands", -1, -1, command_to_move_obj)

		# Guardar cambios
		event_node.pages[source_page_index] = editable_source_page
		event_node.pages[dest_page_index] = editable_dest_page

		# Actualizar árboles
		var source_tree = _get_commands_tree_for_page(source_page_index)
		var dest_tree = _get_commands_tree_for_page(dest_page_index)
		if source_tree:
			_update_commands_tree(source_tree, editable_source_page, source_page_index)
		if dest_tree:
			_update_commands_tree(dest_tree, editable_dest_page, dest_page_index)

		_refresh_inspector()
		# Limpiar backup después de éxito
		move_backup.erase(source_page_index)
		move_backup.erase(dest_page_index)
		return true

	elif move_type == "nested_command":
		# Mover nested_command entre páginas
		# Similar a la lógica de _move_command_to_destination pero entre páginas
		push_error("Event Editor: Mover nested_command entre páginas aún no implementado")
		return false

	return false

func _move_command_to_destination_same_page(page_index: int, destination_metadata: Dictionary, destination_item: TreeItem) -> bool:
	var original_page = _get_page(page_index)
	if not original_page:
		push_error("Event Editor: No se encontró la página")
		return false

	var move_info = command_to_move.get(page_index, {})
	if not move_info.has("type"):
		push_error("Event Editor: No hay información del comando a mover")
		return false

	# Guardar backup antes de modificar
	move_backup[page_index] = original_page.duplicate(true) as EventPage

	var editable_page = original_page.duplicate(true) as EventPage
	if not editable_page:
		push_error("Event Editor: No se pudo duplicar la página")
		_restore_from_backup([page_index])
		return false

	var move_type = move_info.type
	var move_metadata = move_info.get("metadata", {})
	var destination_type = destination_metadata.type

	print("Event Editor: Moviendo ", move_type, " a destino tipo: ", destination_type)

	var success = false

	if move_type == "command":
		# Mover comando principal
		var command_index = move_metadata.get("index", -1)
		if command_index < 0 or command_index >= editable_page.commands.size():
			return false

		var command_to_move_obj = editable_page.commands[command_index]

		# IMPORTANTE: Encontrar el índice del destino ANTES de remover el comando
		# porque los índices pueden cambiar después de remover
		var parent_cmd_index = -1
		var parent_cmd_location = null
		if destination_type in ["branch", "choice_branch", "switch_case", "default_commands"]:
			var parent_command = destination_metadata.get("parent_command")
			if parent_command:
				# Buscar recursivamente el comando padre en la página original
				if original_page:
					parent_cmd_location = _find_command_location_in_page(original_page, parent_command)
					if parent_cmd_location.found:
						if parent_cmd_location.is_root:
							parent_cmd_index = parent_cmd_location.root_index
						else:
							# El comando está anidado, usar el root_index para encontrar el comando principal
							parent_cmd_index = parent_cmd_location.root_index

		# Remover del nivel principal
		editable_page.commands.remove_at(command_index)

		# Ajustar el índice del destino si el comando removido estaba antes o en el mismo índice
		if parent_cmd_index >= 0 and command_index < parent_cmd_index:
			# Si removimos un comando antes del destino, el índice del destino se reduce en 1
			parent_cmd_index -= 1
			# Actualizar también el root_index en parent_cmd_location si está en el nivel raíz
			if parent_cmd_location and parent_cmd_location.is_root:
				parent_cmd_location.root_index = parent_cmd_index
			# Actualizar también el root_index en el path si existe
			elif parent_cmd_location and parent_cmd_location.has("path"):
				var path = parent_cmd_location.get("path", [])
				if path.size() > 0 and path[0].has("type") and path[0].type == "root":
					path[0].index = parent_cmd_index
					parent_cmd_location.root_index = parent_cmd_index

		# Añadir al destino
		# Necesitamos encontrar el branch/case correspondiente en la página duplicada
		# Usamos el índice del comando padre para encontrar el comando correcto
		if destination_type == "branch":
			# parent_cmd_index ya fue calculado arriba
			if parent_cmd_index >= 0 and parent_cmd_index < editable_page.commands.size():
				var cmd = editable_page.commands[parent_cmd_index]
				if cmd is ConditionalCommand:
					var cond_cmd = cmd as ConditionalCommand
					# Encontrar el branch por su posición (índice)
					var branch_index = -1
					var original_branch = destination_metadata.get("branch")
					if original_branch:
						var parent_command = destination_metadata.get("parent_command")
						if parent_command:
							# Buscar el índice del branch original en el comando original
							var original_cond_cmd = parent_command as ConditionalCommand
							for i in range(original_cond_cmd.branches.size()):
								if original_cond_cmd.branches[i] == original_branch:
									branch_index = i
									break
							# Usar el branch correspondiente en el comando duplicado
							if branch_index >= 0 and branch_index < cond_cmd.branches.size():
								if _add_command_to_branch_case(cmd, "branch", branch_index, -1, command_to_move_obj):
									success = true
					else:
						push_error("Event Editor: No se encontró branch en destination_metadata")
				else:
					push_error("Event Editor: El comando en el índice no es ConditionalCommand")
			else:
				push_error("Event Editor: parent_cmd_index inválido o fuera de rango: ", parent_cmd_index, " (array size: ", editable_page.commands.size(), ")")
		elif destination_type == "choice_branch":
			# parent_cmd_index y parent_cmd_location ya fueron calculados arriba
			if parent_cmd_location and parent_cmd_location.found:
				# Si el comando está en el nivel raíz, usar directamente el índice ajustado
				if parent_cmd_location.is_root and parent_cmd_index >= 0 and parent_cmd_index < editable_page.commands.size():
					var choices_cmd = editable_page.commands[parent_cmd_index]
					if choices_cmd is ShowChoicesCommand:
						# El branch_index viene del destination_metadata
						var original_branch = destination_metadata.get("branch")
						var branch_index = -1
						if original_branch:
							# Buscar el índice del branch en el comando original
							var parent_command = destination_metadata.get("parent_command")
							if parent_command is ShowChoicesCommand:
								var original_choices_cmd = parent_command as ShowChoicesCommand
								for i in range(original_choices_cmd.branches.size()):
									if original_choices_cmd.branches[i] == original_branch:
										branch_index = i
										break
						if branch_index >= 0 and branch_index < choices_cmd.branches.size():
							if _add_command_to_branch_case(choices_cmd, "choice_branch", branch_index, -1, command_to_move_obj):
								success = true
						else:
							push_error("Event Editor: branch_index inválido o fuera de rango: ", branch_index)
					else:
						push_error("Event Editor: El comando en el índice no es ShowChoicesCommand")
				else:
					# El comando está anidado, usar _get_nested_command_from_location
					# Asegurarse de que el root_index en el path esté actualizado
					if parent_cmd_location.has("path"):
						var path = parent_cmd_location.get("path", [])
						if path.size() > 0 and path[0].has("type") and path[0].type == "root":
							path[0].index = parent_cmd_index
							parent_cmd_location.root_index = parent_cmd_index

					var choices_cmd = _get_nested_command_from_location(editable_page, parent_cmd_location)
					if choices_cmd is ShowChoicesCommand:
						# El branch_index viene del destination_metadata, no del parent_cmd_location
						var original_branch = destination_metadata.get("branch")
						var branch_index = -1
						if original_branch:
							# Buscar el índice del branch en el comando original
							var parent_command = destination_metadata.get("parent_command")
							if parent_command is ShowChoicesCommand:
								var original_choices_cmd = parent_command as ShowChoicesCommand
								for i in range(original_choices_cmd.branches.size()):
									if original_choices_cmd.branches[i] == original_branch:
										branch_index = i
										break
						if branch_index >= 0 and branch_index < choices_cmd.branches.size():
							if _add_command_to_branch_case(choices_cmd, "choice_branch", branch_index, -1, command_to_move_obj):
								success = true
						else:
							push_error("Event Editor: branch_index inválido o fuera de rango: ", branch_index)
					else:
						push_error("Event Editor: No se encontró ShowChoicesCommand en la ubicación especificada")
			else:
				push_error("Event Editor: No se encontró parent_command en la página")
		elif destination_type == "switch_case":
			# parent_cmd_index ya fue calculado arriba
			if parent_cmd_index >= 0 and parent_cmd_index < editable_page.commands.size():
				var cmd = editable_page.commands[parent_cmd_index]
				if cmd is SwitchCommand:
					var switch_cmd = cmd as SwitchCommand
					# Encontrar el case por su posición (índice)
					var case_index = -1
					var original_case = destination_metadata.get("case")
					if original_case:
						var parent_command = destination_metadata.get("parent_command")
						if parent_command:
							# Buscar el índice del case original en el comando original
							var original_switch_cmd = parent_command as SwitchCommand
							for i in range(original_switch_cmd.cases.size()):
								if original_switch_cmd.cases[i] == original_case:
									case_index = i
									break
							# Usar el case correspondiente en el comando duplicado
							if case_index >= 0 and case_index < switch_cmd.cases.size():
								if _add_command_to_branch_case(cmd, "switch_case", -1, case_index, command_to_move_obj):
									success = true
		elif destination_type == "default_commands":
			# parent_cmd_index ya fue calculado arriba
			if parent_cmd_index >= 0 and parent_cmd_index < editable_page.commands.size():
				var cmd = editable_page.commands[parent_cmd_index]
				if cmd is SwitchCommand:
					var switch_cmd = cmd as SwitchCommand
					if _add_command_to_branch_case(cmd, "default_commands", -1, -1, command_to_move_obj):
						success = true
		elif destination_type == "command":
			# Mover como hijo del comando (al primer branch/case)
			var dest_index = destination_metadata.get("index", -1)
			if dest_index >= 0 and dest_index < editable_page.commands.size():
				var parent_cmd = editable_page.commands[dest_index]
				if parent_cmd is ConditionalCommand:
					var cond_cmd = parent_cmd as ConditionalCommand
					if cond_cmd.branches.is_empty():
						cond_cmd.branches.append(EventBranch.new())
					if _add_command_to_branch_case(parent_cmd, "branch", 0, -1, command_to_move_obj):
						success = true
				elif parent_cmd is ShowChoicesCommand:
					var choices_cmd = parent_cmd as ShowChoicesCommand
					if choices_cmd.branches.is_empty():
						var new_branch = ChoiceBranch.new()
						new_branch.label = "Opción"
						choices_cmd.branches.append(new_branch)
					if _add_command_to_branch_case(parent_cmd, "choice_branch", 0, -1, command_to_move_obj):
						success = true
				elif parent_cmd is SwitchCommand:
					var switch_cmd = parent_cmd as SwitchCommand
					if switch_cmd.cases.is_empty():
						switch_cmd.cases.append(SwitchCase.new())
					if _add_command_to_branch_case(parent_cmd, "switch_case", -1, 0, command_to_move_obj):
						success = true

	elif move_type == "nested_command":
		# Mover nested_command
		# Necesitamos encontrar el comando por su posición en lugar de por referencia
		# porque después de duplicate, las referencias no coinciden
		var nested_command = null
		var removed = false

		# Obtener información de posición del metadata
		var parent_branch_meta = move_metadata.get("parent_branch")
		if not parent_branch_meta:
			push_error("Event Editor: No se encontró parent_branch en metadata")
			return false

		var parent_command_ref = parent_branch_meta.get("parent_command")
		if not parent_command_ref:
			push_error("Event Editor: No se encontró parent_command en parent_branch")
			return false

		# Buscar recursivamente el comando padre en la página original
		var parent_location = _find_command_location_in_page(original_page, parent_command_ref)
		if not parent_location.found:
			push_error("Event Editor: No se encontró el comando padre en la página original")
			return false

		# Obtener el índice del nested_command (guardado cuando se presionó "Mover")
		var nested_command_index = move_info.get("nested_command_index", -1)

		if nested_command_index < 0:
			push_error("Event Editor: No se encontró nested_command_index en move_info")
			return false

		# Obtener el comando padre en la página duplicada usando la ubicación
		var parent_cmd_duplicated = _get_nested_command_from_location(editable_page, parent_location)
		if not parent_cmd_duplicated:
			push_error("Event Editor: No se pudo obtener el comando padre en la página duplicada")
			return false
		var branch_type = parent_branch_meta.get("type", "")

		# Encontrar el branch/case correcto
		var branch_index = -1
		if branch_type == "branch" and parent_cmd_duplicated is ConditionalCommand:
			var cond_cmd = parent_cmd_duplicated as ConditionalCommand
			# Encontrar el índice del branch original
			var original_branch = parent_branch_meta.get("branch")
			if original_branch:
				var original_cond_cmd = parent_command_ref as ConditionalCommand
				for i in range(original_cond_cmd.branches.size()):
					if original_cond_cmd.branches[i] == original_branch:
						branch_index = i
						break
			if branch_index >= 0 and branch_index < cond_cmd.branches.size():
				if nested_command_index < cond_cmd.branches[branch_index].commands.size():
					nested_command = cond_cmd.branches[branch_index].commands[nested_command_index]
					cond_cmd.branches[branch_index].commands.remove_at(nested_command_index)
					removed = true
		elif branch_type == "choice_branch" and parent_cmd_duplicated is ShowChoicesCommand:
			var choices_cmd = parent_cmd_duplicated as ShowChoicesCommand
			# Encontrar el índice del branch original
			var original_branch = parent_branch_meta.get("branch")
			if original_branch:
				var original_choices_cmd = parent_command_ref as ShowChoicesCommand
				for i in range(original_choices_cmd.branches.size()):
					if original_choices_cmd.branches[i] == original_branch:
						branch_index = i
						break
			if branch_index >= 0 and branch_index < choices_cmd.branches.size():
				if nested_command_index < choices_cmd.branches[branch_index].commands.size():
					nested_command = choices_cmd.branches[branch_index].commands[nested_command_index]
					choices_cmd.branches[branch_index].commands.remove_at(nested_command_index)
					removed = true
		elif branch_type == "switch_case" and parent_cmd_duplicated is SwitchCommand:
			var switch_cmd = parent_cmd_duplicated as SwitchCommand
			# Encontrar el índice del case original
			var original_case = parent_branch_meta.get("case")
			if original_case:
				var original_switch_cmd = parent_command_ref as SwitchCommand
				for i in range(original_switch_cmd.cases.size()):
					if original_switch_cmd.cases[i] == original_case:
						branch_index = i
						break
			if branch_index >= 0 and branch_index < switch_cmd.cases.size():
				if nested_command_index < switch_cmd.cases[branch_index].commands.size():
					nested_command = switch_cmd.cases[branch_index].commands[nested_command_index]
					switch_cmd.cases[branch_index].commands.remove_at(nested_command_index)
					removed = true
		elif branch_type == "default_commands" and parent_cmd_duplicated is SwitchCommand:
			var switch_cmd = parent_cmd_duplicated as SwitchCommand
			if nested_command_index < switch_cmd.default_commands.size():
				nested_command = switch_cmd.default_commands[nested_command_index]
				switch_cmd.default_commands.remove_at(nested_command_index)
				removed = true

		if not removed or not nested_command:
			push_error("Event Editor: No se encontró el nested_command para remover")
			return false

		# Añadir al destino
		# Necesitamos encontrar el branch/case correspondiente en la página duplicada
		# Usamos el índice del comando padre para encontrar el comando correcto
		if destination_type == "branch":
			var parent_command = destination_metadata.get("parent_command")
			if parent_command:
				# Encontrar el índice del comando padre en la página original
				var dest_parent_cmd_index = -1
				if original_page:
					for i in range(original_page.commands.size()):
						if original_page.commands[i] == parent_command:
							dest_parent_cmd_index = i
							break

				# Usar el mismo índice en la página duplicada
				if dest_parent_cmd_index >= 0 and dest_parent_cmd_index < editable_page.commands.size():
					var cmd = editable_page.commands[dest_parent_cmd_index]
					if cmd is ConditionalCommand:
						var cond_cmd = cmd as ConditionalCommand
						# Encontrar el branch por su posición (índice)
						var dest_branch_index = -1
						var original_branch = destination_metadata.get("branch")
						if original_branch:
							# Buscar el índice del branch original en el comando original
							var original_cond_cmd = parent_command as ConditionalCommand
							for i in range(original_cond_cmd.branches.size()):
								if original_cond_cmd.branches[i] == original_branch:
									dest_branch_index = i
									break
							# Usar el branch correspondiente en el comando duplicado
							if dest_branch_index >= 0 and dest_branch_index < cond_cmd.branches.size():
								if _add_command_to_branch_case(cmd, "branch", dest_branch_index, -1, nested_command):
									success = true
		elif destination_type == "choice_branch":
			var parent_command = destination_metadata.get("parent_command")
			if parent_command:
				# Buscar recursivamente el comando en la página original
				if original_page:
					var location = _find_command_location_in_page(original_page, parent_command)
					if location.found:
						# Obtener el comando ShowChoicesCommand en la página duplicada
						var choices_cmd = _get_nested_command_from_location(editable_page, location)
						if choices_cmd is ShowChoicesCommand:
							# El branch_index viene del destination_metadata, no del location
							var original_branch = destination_metadata.get("branch")
							var dest_branch_index = -1
							if original_branch:
								# Buscar el índice del branch en el comando original
								if parent_command is ShowChoicesCommand:
									var original_choices_cmd = parent_command as ShowChoicesCommand
									for i in range(original_choices_cmd.branches.size()):
										if original_choices_cmd.branches[i] == original_branch:
											dest_branch_index = i
											break
							if dest_branch_index >= 0 and dest_branch_index < choices_cmd.branches.size():
								if _add_command_to_branch_case(choices_cmd, "choice_branch", dest_branch_index, -1, nested_command):
									success = true
							else:
								push_error("Event Editor: dest_branch_index inválido o fuera de rango: ", dest_branch_index, " (branches size: ", choices_cmd.branches.size(), ")")
						else:
							push_error("Event Editor: No se encontró ShowChoicesCommand en la ubicación especificada")
					else:
						push_error("Event Editor: No se encontró parent_command en la página original")
			else:
				push_error("Event Editor: No se encontró parent_command en destination_metadata")
		elif destination_type == "switch_case":
			var parent_command = destination_metadata.get("parent_command")
			if parent_command:
				# Encontrar el índice del comando padre en la página original
				var dest_parent_cmd_index = -1
				if original_page:
					for i in range(original_page.commands.size()):
						if original_page.commands[i] == parent_command:
							dest_parent_cmd_index = i
							break

				# Usar el mismo índice en la página duplicada
				if dest_parent_cmd_index >= 0 and dest_parent_cmd_index < editable_page.commands.size():
					var cmd = editable_page.commands[dest_parent_cmd_index]
					if cmd is SwitchCommand:
						var switch_cmd = cmd as SwitchCommand
						# Encontrar el case por su posición (índice)
						var dest_case_index = -1
						var original_case = destination_metadata.get("case")
						if original_case:
							# Buscar el índice del case original en el comando original
							var original_switch_cmd = parent_command as SwitchCommand
							for i in range(original_switch_cmd.cases.size()):
								if original_switch_cmd.cases[i] == original_case:
									dest_case_index = i
									break
							# Usar el case correspondiente en el comando duplicado
							if dest_case_index >= 0 and dest_case_index < switch_cmd.cases.size():
								if _add_command_to_branch_case(cmd, "switch_case", -1, dest_case_index, nested_command):
									success = true
					else:
						push_error("Event Editor: El comando en el índice no es SwitchCommand")
				else:
					push_error("Event Editor: dest_parent_cmd_index inválido o fuera de rango: ", dest_parent_cmd_index, " (array size: ", editable_page.commands.size(), ")")
			else:
				push_error("Event Editor: No se encontró parent_command en destination_metadata")
		elif destination_type == "default_commands":
			var parent_command = destination_metadata.get("parent_command")
			if parent_command:
				# Encontrar el índice del comando padre en la página original
				var dest_parent_cmd_index = -1
				if original_page:
					for i in range(original_page.commands.size()):
						if original_page.commands[i] == parent_command:
							dest_parent_cmd_index = i
							break

				# Usar el mismo índice en la página duplicada
				if dest_parent_cmd_index >= 0 and dest_parent_cmd_index < editable_page.commands.size():
					var cmd = editable_page.commands[dest_parent_cmd_index]
					if cmd is SwitchCommand:
						var switch_cmd = cmd as SwitchCommand
						if _add_command_to_branch_case(cmd, "default_commands", -1, -1, nested_command):
							success = true
					else:
						push_error("Event Editor: El comando en el índice no es SwitchCommand")
				else:
					push_error("Event Editor: dest_parent_cmd_index inválido o fuera de rango: ", dest_parent_cmd_index, " (array size: ", editable_page.commands.size(), ")")
			else:
				push_error("Event Editor: No se encontró parent_command en destination_metadata")
		elif destination_type == "command":
			# Mover al nivel principal (después del comando padre)
			var dest_index = destination_metadata.get("index", -1)
			if dest_index >= 0:
				editable_page.commands.insert(dest_index + 1, nested_command)
				success = true

	if success:
		event_node.pages[page_index] = editable_page
		_mark_as_changed()
		var commands_tree = _get_commands_tree_for_page(page_index)
		if commands_tree:
			_update_commands_tree(commands_tree, editable_page, page_index)
			_refresh_inspector()
		print("Event Editor: Movimiento completado exitosamente")
		# Limpiar backup después de éxito
		move_backup.erase(page_index)
	else:
		push_error("Event Editor: No se pudo completar el movimiento. Se restauró el estado anterior.")
		_restore_from_backup([page_index])

	return success

func _move_nested_to_root(dest_page_index: int, source_page_index: int = -1) -> bool:
	# Si source_page_index no se proporciona, asumir que es la misma página
	if source_page_index < 0:
		source_page_index = dest_page_index

	# Mover un nested_command al primer nivel (al final de la lista de comandos)
	var source_page = _get_page(source_page_index)
	var dest_page = _get_page(dest_page_index)

	if not source_page or not dest_page:
		return false

	var move_info = command_to_move.get(source_page_index, {})
	if not move_info.has("type") or move_info.type != "nested_command":
		return false

	# Guardar backup antes de modificar
	move_backup[source_page_index] = source_page.duplicate(true) as EventPage
	if source_page_index != dest_page_index:
		move_backup[dest_page_index] = dest_page.duplicate(true) as EventPage

	# Si es la misma página, usar la lógica normal
	var editable_page = null
	if source_page_index == dest_page_index:
		editable_page = source_page.duplicate(true) as EventPage
		if not editable_page:
			push_error("Event Editor: No se pudo duplicar la página")
			_restore_from_backup([source_page_index])
			return false
	else:
		# Entre páginas diferentes, solo remover de origen
		editable_page = source_page.duplicate(true) as EventPage
		if not editable_page:
			push_error("Event Editor: No se pudo duplicar la página de origen")
			_restore_from_backup([source_page_index, dest_page_index])
			return false

	var move_metadata = move_info.get("metadata", {})
	var nested_command = null
	var removed = false

	# Obtener información de posición del metadata
	var parent_branch_meta = move_metadata.get("parent_branch")
	if not parent_branch_meta:
		push_error("Event Editor: No se encontró parent_branch en metadata")
		return false

	var parent_command_ref = parent_branch_meta.get("parent_command")
	if not parent_command_ref:
		push_error("Event Editor: No se encontró parent_command en parent_branch")
		return false

	# Buscar recursivamente el comando padre en la página original
	var parent_location = _find_command_location_in_page(source_page, parent_command_ref)
	if not parent_location.found:
		push_error("Event Editor: No se encontró el comando padre en la página original")
		return false

	# Obtener el índice del nested_command (guardado cuando se presionó "Mover")
	var nested_command_index = move_info.get("nested_command_index", -1)

	if nested_command_index < 0:
		push_error("Event Editor: No se encontró nested_command_index en move_info")
		return false

	# Obtener el comando padre en la página duplicada usando la ubicación
	var parent_cmd_duplicated = _get_nested_command_from_location(editable_page, parent_location)
	if not parent_cmd_duplicated:
		push_error("Event Editor: No se pudo obtener el comando padre en la página duplicada")
		return false
	var branch_type = parent_branch_meta.get("type", "")

	# Encontrar el branch/case correcto y remover el comando
	var branch_index = -1
	if branch_type == "branch" and parent_cmd_duplicated is ConditionalCommand:
		var cond_cmd = parent_cmd_duplicated as ConditionalCommand
		# Encontrar el índice del branch original
		var original_branch = parent_branch_meta.get("branch")
		if original_branch:
			var original_cond_cmd = parent_command_ref as ConditionalCommand
			for i in range(original_cond_cmd.branches.size()):
				if original_cond_cmd.branches[i] == original_branch:
					branch_index = i
					break
		if branch_index >= 0 and branch_index < cond_cmd.branches.size():
			if nested_command_index < cond_cmd.branches[branch_index].commands.size():
				nested_command = cond_cmd.branches[branch_index].commands[nested_command_index]
				cond_cmd.branches[branch_index].commands.remove_at(nested_command_index)
				removed = true
	elif branch_type == "choice_branch" and parent_cmd_duplicated is ShowChoicesCommand:
		var choices_cmd = parent_cmd_duplicated as ShowChoicesCommand
		# Encontrar el índice del branch original
		var original_branch = parent_branch_meta.get("branch")
		if original_branch:
			var original_choices_cmd = parent_command_ref as ShowChoicesCommand
			for i in range(original_choices_cmd.branches.size()):
				if original_choices_cmd.branches[i] == original_branch:
					branch_index = i
					break
		if branch_index >= 0 and branch_index < choices_cmd.branches.size():
			if nested_command_index < choices_cmd.branches[branch_index].commands.size():
				nested_command = choices_cmd.branches[branch_index].commands[nested_command_index]
				choices_cmd.branches[branch_index].commands.remove_at(nested_command_index)
				removed = true
	elif branch_type == "switch_case" and parent_cmd_duplicated is SwitchCommand:
		var switch_cmd = parent_cmd_duplicated as SwitchCommand
		# Encontrar el índice del case original
		var original_case = parent_branch_meta.get("case")
		if original_case:
			var original_switch_cmd = parent_command_ref as SwitchCommand
			for i in range(original_switch_cmd.cases.size()):
				if original_switch_cmd.cases[i] == original_case:
					branch_index = i
					break
		if branch_index >= 0 and branch_index < switch_cmd.cases.size():
			if nested_command_index < switch_cmd.cases[branch_index].commands.size():
				nested_command = switch_cmd.cases[branch_index].commands[nested_command_index]
				switch_cmd.cases[branch_index].commands.remove_at(nested_command_index)
				removed = true
	elif branch_type == "default_commands" and parent_cmd_duplicated is SwitchCommand:
		var switch_cmd = parent_cmd_duplicated as SwitchCommand
		if nested_command_index < switch_cmd.default_commands.size():
			nested_command = switch_cmd.default_commands[nested_command_index]
			switch_cmd.default_commands.remove_at(nested_command_index)
			removed = true

	if not removed or not nested_command:
		push_error("Event Editor: No se encontró el nested_command para remover (branch_index: ", branch_index, ", nested_command_index: ", nested_command_index, ")")
		if source_page_index == dest_page_index:
			_restore_from_backup([source_page_index])
		else:
			_restore_from_backup([source_page_index, dest_page_index])
		return false

	# Añadir al final de la lista de comandos principales
	if source_page_index == dest_page_index:
		# Misma página - usar set para evitar problemas con arrays read-only
		var new_commands: Array[EventCommand] = []
		for cmd in editable_page.commands:
			new_commands.append(cmd)
		new_commands.append(nested_command)
		editable_page.set("commands", new_commands)
		event_node.pages[dest_page_index] = editable_page
		_mark_as_changed()
		var commands_tree = _get_commands_tree_for_page(dest_page_index)
		if commands_tree:
			_update_commands_tree(commands_tree, editable_page, dest_page_index)
		_refresh_inspector()
		# Limpiar backup después de éxito
		move_backup.erase(source_page_index)
		return true
	else:
		# Entre páginas diferentes
		var dest_editable_page = dest_page.duplicate(true) as EventPage
		if not dest_editable_page:
			push_error("Event Editor: No se pudo duplicar la página de destino")
			_restore_from_backup([source_page_index, dest_page_index])
			return false

		# Remover de origen
		event_node.pages[source_page_index] = editable_page
		_mark_as_changed()

		# Añadir a destino usando set para evitar problemas con arrays read-only
		var new_dest_commands: Array[EventCommand] = []
		for cmd in dest_editable_page.commands:
			new_dest_commands.append(cmd)
		new_dest_commands.append(nested_command)
		dest_editable_page.set("commands", new_dest_commands)
		event_node.pages[dest_page_index] = dest_editable_page

		# Actualizar árboles
		var source_tree = _get_commands_tree_for_page(source_page_index)
		var dest_tree = _get_commands_tree_for_page(dest_page_index)
		if source_tree:
			_update_commands_tree(source_tree, editable_page, source_page_index)
		if dest_tree:
			_update_commands_tree(dest_tree, dest_editable_page, dest_page_index)

		_refresh_inspector()
		# Limpiar backup después de éxito
		move_backup.erase(source_page_index)
		move_backup.erase(dest_page_index)
		return true

func _restore_from_backup(page_indices: Array) -> void:
	# Restaurar páginas desde el backup
	for page_idx in page_indices:
		if move_backup.has(page_idx):
			event_node.pages[page_idx] = move_backup[page_idx].duplicate(true) as EventPage
			var commands_tree = _get_commands_tree_for_page(page_idx)
			var page = _get_page(page_idx)
			if commands_tree and page:
				_update_commands_tree(commands_tree, page, page_idx)
			move_backup.erase(page_idx)
	_refresh_inspector()

func _update_buttons_after_move(page_index: int) -> void:
	# Actualizar botones después de mover (asegurarse de que salgan del modo mover)
	var commands_tree = _get_commands_tree_for_page(page_index)
	if commands_tree:
		var selected_item = commands_tree.get_selected()
		if selected_item:
			_on_command_selected(page_index)
		else:
			_update_buttons_state(page_index, false, false, false, false)

func _move_command_to_root(dest_page_index: int, source_page_index: int) -> bool:
	# Mover un command al primer nivel (al final de la lista de comandos) entre páginas
	var source_page = _get_page(source_page_index)
	var dest_page = _get_page(dest_page_index)

	if not source_page or not dest_page:
		return false

	var move_info = command_to_move.get(source_page_index, {})
	if not move_info.has("type") or move_info.type != "command":
		return false

	var editable_source_page = source_page.duplicate(true) as EventPage
	var editable_dest_page = dest_page.duplicate(true) as EventPage

	if not editable_source_page or not editable_dest_page:
		push_error("Event Editor: No se pudo duplicar la página")
		return false

	# Guardar backup antes de modificar
	move_backup[source_page_index] = source_page.duplicate(true) as EventPage
	move_backup[dest_page_index] = dest_page.duplicate(true) as EventPage

	var move_metadata = move_info.get("metadata", {})
	var command_index = move_metadata.get("index", -1)

	if command_index < 0 or command_index >= editable_source_page.commands.size():
		push_error("Event Editor: Índice de comando inválido")
		_restore_from_backup([source_page_index, dest_page_index])
		return false

	# Remover el comando de la página origen usando set para evitar problemas con arrays read-only
	var command_to_move_obj = editable_source_page.commands[command_index]
	var new_source_commands: Array[EventCommand] = []
	for i in range(editable_source_page.commands.size()):
		if i != command_index:
			new_source_commands.append(editable_source_page.commands[i])
	editable_source_page.set("commands", new_source_commands)

	# Añadir al final de la lista de comandos principales de la página destino usando set
	var new_dest_commands: Array[EventCommand] = []
	for cmd in editable_dest_page.commands:
		new_dest_commands.append(cmd)
	new_dest_commands.append(command_to_move_obj)
	editable_dest_page.set("commands", new_dest_commands)

	# Guardar cambios
	event_node.pages[source_page_index] = editable_source_page
	event_node.pages[dest_page_index] = editable_dest_page
	_mark_as_changed()

	# Actualizar árboles
	var source_tree = _get_commands_tree_for_page(source_page_index)
	var dest_tree = _get_commands_tree_for_page(dest_page_index)
	if source_tree:
		_update_commands_tree(source_tree, editable_source_page, source_page_index)
	if dest_tree:
		_update_commands_tree(dest_tree, editable_dest_page, dest_page_index)

	_refresh_inspector()
	return true

# === CALLBACKS DE CAMBIOS ===
func _on_execution_mode_changed(page_index: int, selected_index: int) -> void:
	var page = _get_page(page_index)
	if page:
		page.execution_mode = selected_index
		_mark_as_changed()

func _on_blocks_player_changed(page_index: int, pressed: bool) -> void:
	var page = _get_page(page_index)
	if page:
		page.blocks_player = pressed
		_mark_as_changed()

func _on_through_changed(page_index: int, pressed: bool) -> void:
	var page = _get_page(page_index)
	if page:
		page.through = pressed
		_mark_as_changed()

func _on_page_name_changed(page_index: int, new_name: String) -> void:
	var page = _get_page(page_index)
	if not page:
		return

	# Actualizar el nombre de la página
	page.page_name = new_name

	# Marcar como cambiado y refrescar el árbol
	_mark_as_changed()
	var commands_tree = _get_commands_tree_for_page(page_index)
	if commands_tree:
		_update_commands_tree(commands_tree, page, page_index)

func _on_change_name_button_pressed(page_index: int) -> void:
	var page = _get_page(page_index)
	if not page:
		push_error("Event Editor: No se pudo obtener la página " + str(page_index))
		return

	# Crear diálogo para cambiar el nombre
	var dialog = AcceptDialog.new()
	dialog.title = "Cambiar Nombre de Página"
	dialog.size = Vector2(400, 150)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.add_theme_constant_override("margin_left", 10)
	vbox.add_theme_constant_override("margin_top", 10)
	vbox.add_theme_constant_override("margin_right", 10)
	vbox.add_theme_constant_override("margin_bottom", 10)

	var label = Label.new()
	label.text = "Nombre de la página:"
	vbox.add_child(label)

	var name_edit = LineEdit.new()
	name_edit.text = page.page_name if page.page_name else ""
	name_edit.placeholder_text = "Página"
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(name_edit)

	var info_label = Label.new()
	info_label.text = "(Dejar vacío para usar 'Página' por defecto)"
	info_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(info_label)

	dialog.add_child(vbox)

	# Botones
	var ok_button = dialog.get_ok_button()
	ok_button.text = "Aceptar"
	ok_button.pressed.connect(func():
		var new_name = name_edit.text.strip_edges()
		_on_page_name_changed(page_index, new_name)
		dialog.queue_free()
	)

	var cancel_button = dialog.add_button("Cancelar", true, "cancel")
	cancel_button.pressed.connect(func(): dialog.queue_free())

	add_child(dialog)
	dialog.exclusive = true
	dialog.popup_centered()

	# Hacer foco en el LineEdit
	name_edit.grab_focus()
	name_edit.select_all()

func _on_movement_button_pressed(page_index: int) -> void:
	var page = _get_page(page_index)
	if not page:
		push_error("Event Editor: No se pudo obtener la página " + str(page_index))
		return

	# Abrir ventana de edición de movimiento
	var editor_script = load("res://addons/event_tools/movement_editor.gd")
	if not editor_script:
		push_error("Event Editor: No se encontró el script del editor de movimiento")
		return

	var editor_window = editor_script.new()
	if not editor_window:
		push_error("Event Editor: No se pudo crear la instancia del editor")
		return

	add_child(editor_window)
	editor_window.load_page(page)
	editor_window.movement_edited.connect(func(): _on_page_movement_edited(page_index))
	editor_window.cancelled.connect(func(): editor_window.queue_free())

	editor_window.popup_centered()

func _on_sprite_button_pressed(page_index: int) -> void:
	var page = _get_page(page_index)
	if not page:
		push_error("Event Editor: No se pudo obtener la página " + str(page_index))
		return

	# Abrir ventana de edición de sprite
	var editor_script = load("res://addons/event_tools/sprite_editor.gd")
	if not editor_script:
		push_error("Event Editor: No se encontró el script del editor de sprite")
		return

	var editor_window = editor_script.new()
	if not editor_window:
		push_error("Event Editor: No se pudo crear la instancia del editor")
		return

	add_child(editor_window)
	editor_window.load_page(page)
	editor_window.sprite_edited.connect(func(): _on_page_sprite_edited(page_index))
	editor_window.cancelled.connect(func(): editor_window.queue_free())

	editor_window.popup_centered()

func _on_map_view_button_pressed(page_index: int) -> void:
	# Usar EditorInterface directamente (disponible como singleton en el editor)
	# Si editor_interface está disponible, usarlo; si no, usar EditorInterface directamente
	var ed_interface = editor_interface if editor_interface else EditorInterface

	# Obtener la escena editada
	var edited_scene_root = ed_interface.get_edited_scene_root()
	if not edited_scene_root:
		push_error("Event Editor: No hay escena editada")
		return

	# Buscar OverworldGrid en la escena
	var overworld_grid = edited_scene_root.find_child("OverworldGrid", true, false)
	if not overworld_grid or not overworld_grid is OverworldGrid:
		push_error("Event Editor: No se encontró OverworldGrid en la escena")
		return

	# Cargar y crear la ventana de vista del mapa
	var selector_script = load("res://addons/event_tools/position_selector_window.gd")
	if not selector_script:
		push_error("Event Editor: No se encontró el script de la ventana de vista del mapa")
		return

	var selector_window = selector_script.new()
	ed_interface.get_base_control().add_child(selector_window)

	# Configurar la ventana
	selector_window.setup(overworld_grid, edited_scene_root)

	# Conectar señal para guardar la posición seleccionada
	selector_window.cell_selected.connect(func(cell_pos: Vector2i): _on_position_selected(page_index, cell_pos))

	# Si la página ya tiene una posición, mostrarla en el selector
	var page = _get_page(page_index)
	if page:
		var pos = page.get("page_position")
		if pos == null or not pos is Vector2i:
			pos = Vector2i(-1, -1)

		if pos.x >= 0 and pos.y >= 0:
			# Convertir de coordenadas ajustadas a coordenadas reales del TileMapLayer
			# La posición guardada está en coordenadas ajustadas (0,0 es esquina superior izquierda)
			# Necesitamos convertirla a las coordenadas reales del TileMapLayer
			var used_rect = selector_window.reference_tile_layer.get_used_rect() if selector_window.reference_tile_layer else null
			if used_rect and (used_rect.position.x < 0 or used_rect.position.y < 0):
				# Ajustar de vuelta a coordenadas reales
				var real_cell_pos = pos + used_rect.position
				selector_window.selected_cell = real_cell_pos
			else:
				selector_window.selected_cell = pos
			selector_window._update_selected_cell_rect()

	selector_window.popup_centered()

func _get_position_text(page: EventPage) -> String:
	if not page:
		return "No definida (usa posición del evento)"

	# Intentar acceso directo primero (funciona si la página ya está duplicada)
	var pos: Vector2i = Vector2i(-1, -1)

	# Intentar acceso directo primero
	pos = page.page_position
	print("Event Editor: _get_position_text - acceso directo: (%d, %d)" % [pos.x, pos.y])

	# Si el acceso directo falla o retorna valores inválidos, intentar con get()
	if pos.x < 0 or pos.y < 0:
		var pos_value = page.get("page_position")
		print("Event Editor: _get_position_text - get() retornó: ", pos_value)
		if pos_value != null and pos_value is Vector2i:
			pos = pos_value as Vector2i
			print("Event Editor: _get_position_text - después de get(): (%d, %d)" % [pos.x, pos.y])

	if pos.x < 0 or pos.y < 0:
		print("Event Editor: _get_position_text - retornando 'No definida' porque pos es (%d, %d)" % [pos.x, pos.y])
		return "No definida (usa posición del evento)"

	print("Event Editor: _get_position_text - retornando posición: (%d, %d)" % [pos.x, pos.y])
	return "(%d, %d)" % [pos.x, pos.y]

func _update_position_label(page_index: int) -> void:
	var page = _get_page(page_index)
	if not page:
		print("Event Editor: _update_position_label - No se pudo obtener la página ", page_index)
		return

	print("Event Editor: _update_position_label - Actualizando label para página ", page_index)
	var page_pos = page.page_position
	print("Event Editor: _update_position_label - Posición de la página: (%d, %d)" % [page_pos.x, page_pos.y])

	# Buscar el label de posición en el panel izquierdo
	var tab = tab_container.get_child(page_index) if tab_container and page_index < tab_container.get_child_count() else null
	if not tab:
		print("Event Editor: _update_position_label - No se encontró el tab para página ", page_index)
		return

	var left_panel = tab.get_child(0) if tab.get_child_count() > 0 else null
	if not left_panel:
		print("Event Editor: _update_position_label - No se encontró el left_panel")
		return

	# El PositionValueLabel está dentro del PositionHBox
	var position_hbox = left_panel.get_node_or_null("PositionHBox")
	var position_value_label = null
	if position_hbox:
		position_value_label = position_hbox.get_node_or_null("PositionValueLabel")

	if position_value_label:
		var position_text = _get_position_text(page)
		print("Event Editor: _update_position_label - Texto obtenido: ", position_text)
		position_value_label.text = position_text
	else:
		print("Event Editor: _update_position_label - No se encontró PositionValueLabel (hbox existe: ", position_hbox != null, ")")

	# Mostrar/ocultar el botón de borrar según si hay posición asignada
	# (position_hbox ya se declaró arriba)
	if not position_hbox:
		return

	var clear_button = position_hbox.get_node_or_null("ClearPositionButton")
	if not clear_button:
		return

	# Verificar si hay posición asignada usando la misma lógica que _get_position_text
	var pos = page.get("page_position")
	var has_position = false
	if pos != null and pos is Vector2i:
		if pos.x >= 0 and pos.y >= 0:
			has_position = true

	# Forzar que el botón esté oculto si no hay posición
	# Esto es crítico para evitar que se muestre cuando no debería
	if not has_position:
		clear_button.visible = false
	else:
		clear_button.visible = true

func _on_position_selected(page_index: int, cell_pos: Vector2i) -> void:
	var page = _get_page(page_index)
	if not page:
		push_error("Event Editor: No se pudo obtener la página " + str(page_index))
		return

	# Asignar directamente como se hace con otras propiedades (blocks_player, through, etc.)
	page.page_position = cell_pos

	has_unsaved_changes = true

	# Esperar un frame para asegurar que la asignación se haya completado
	await get_tree().process_frame

	# Actualizar el label de posición
	_update_position_label(page_index)

	# Verificar que se guardó correctamente
	var saved_pos = page.page_position
	print("Event Editor: Posición guardada para página %d: (%d, %d), verificada: (%d, %d)" % [page_index, cell_pos.x, cell_pos.y, saved_pos.x, saved_pos.y])

func _on_clear_position_button_pressed(page_index: int) -> void:
	var page = _get_page(page_index)
	if not page:
		push_error("Event Editor: No se pudo obtener la página " + str(page_index))
		return

	# Borrar la posición estableciéndola a (-1, -1)
	page.page_position = Vector2i(-1, -1)

	has_unsaved_changes = true

	# Actualizar el label de posición
	_update_position_label(page_index)

	print("Event Editor: Posición borrada para página %d" % page_index)

func _on_trainer_button_pressed(page_index: int) -> void:
	var page = _get_page(page_index)
	if not page:
		push_error("Event Editor: No se pudo obtener la página " + str(page_index))
		return

	# Abrir ventana de edición de trainer
	var editor_script = load("res://addons/event_tools/trainer_editor.gd")
	if not editor_script:
		push_error("Event Editor: No se encontró el script del editor de trainer")
		return

	var editor_window = editor_script.new()
	if not editor_window:
		push_error("Event Editor: No se pudo crear la instancia del editor")
		return

	add_child(editor_window)
	editor_window.load_page(page)
	editor_window.trainer_edited.connect(func(): _on_page_trainer_edited(page_index))
	editor_window.cancelled.connect(func(): editor_window.queue_free())

	editor_window.popup_centered()

func _on_conditions_button_pressed(page_index: int) -> void:
	var page = _get_page(page_index)
	if not page:
		push_error("Event Editor: No se pudo obtener la página " + str(page_index))
		return

	# Abrir ventana de edición de condiciones
	var editor_script = load("res://addons/event_tools/condition_editor.gd")
	if not editor_script:
		push_error("Event Editor: No se encontró el script del editor de condiciones")
		return

	var editor_window = editor_script.new()
	if not editor_window:
		push_error("Event Editor: No se pudo crear la instancia del editor")
		return

	add_child(editor_window)
	editor_window.set_event_node(event_node)
	editor_window.load_condition(page.root_condition)
	editor_window.condition_edited.connect(func(cond: EventCondition): _on_page_condition_edited(page_index, cond))
	editor_window.cancelled.connect(func(): editor_window.queue_free())

	editor_window.popup_centered()

# === GESTIÓN DE COMANDOS ===
func _on_command_selected(page_index: int) -> void:
	var commands_tree = _get_commands_tree_for_page(page_index)
	if not commands_tree:
		return

	var selected_item = commands_tree.get_selected()

	# Verificar si estamos en modo mover (usando move_source_page_index para detectar entre páginas)
	var source_page = move_source_page_index if move_source_page_index >= 0 else page_index
	var in_move_mode = move_mode_active.get(source_page, false) or (move_source_page_index >= 0 and page_index != source_page)

	if selected_item and in_move_mode:
		# En modo mover, verificar si es la raíz o un destino válido
		var root = commands_tree.get_root()
		var is_root = (root == selected_item)
		var is_valid_destination = is_root

		if not is_root:
			var metadata = selected_item.get_metadata(0)
			if metadata and metadata.has("type"):
				var item_type = metadata.type
				# Verificar si es un destino válido
				is_valid_destination = item_type in ["branch", "choice_branch", "switch_case", "default_commands", "command"]

				# Si es command, solo válido si se mueve un command (no nested_command)
				if item_type == "command":
					var move_info = command_to_move.get(source_page, {})
					if move_info.get("type", "") == "nested_command":
						is_valid_destination = false

		# Actualizar botones en modo mover (mantener aceptar/cancelar)
		var buttons = page_buttons.get(page_index, {})
		if buttons.has("accept_move") and buttons.has("cancel_move"):
			buttons.add.visible = false
			buttons.edit.visible = false
			buttons.delete.visible = false
			buttons.move_up.visible = false
			buttons.move_down.visible = false
			buttons.move.visible = false
			buttons.accept_move.visible = true
			buttons.cancel_move.visible = true
			buttons.accept_move.disabled = not is_valid_destination

		if not is_valid_destination:
			# No deseleccionar, solo deshabilitar aceptar
			return

		return

	# Modo normal (no mover)
	var can_edit_delete = false
	var can_move_up = false
	var can_move_down = false
	var can_move = false
	var can_duplicate = false
	var can_add = false

	if selected_item:
		# Verificar si es la raíz del árbol
		var root = commands_tree.get_root()
		var is_root = (root == selected_item)

		if is_root:
			# Si es la raíz (página), se puede editar (abrir editor de condiciones)
			can_edit_delete = true
			can_add = true
		else:
			var metadata = selected_item.get_metadata(0)
			if metadata and metadata.has("type"):
				var item_type = metadata.type
				can_edit_delete = item_type in ["command", "nested_command", "branch", "choice_branch", "switch_case", "default_commands"]
				can_move = item_type in ["command", "nested_command"]
				can_duplicate = item_type in ["command", "nested_command", "branch", "choice_branch", "switch_case"]
				# Permitir añadir comandos a branches/cases, o añadir branches/cases a ConditionalCommand/SwitchCommand/ShowChoicesCommand
				can_add = item_type in ["branch", "choice_branch", "switch_case", "default_commands"]
				# También permitir añadir si es un ConditionalCommand, SwitchCommand o ShowChoicesCommand
				if item_type == "command" and metadata.has("index"):
					var page = _get_page(page_index)
					if page:
						var cmd = page.commands[metadata.index]
						if cmd is ConditionalCommand or cmd is SwitchCommand or cmd is ShowChoicesCommand:
							can_add = true

				# Determinar si se puede mover
				can_move_up = _can_move_item_up(selected_item, page_index)
				can_move_down = _can_move_item_down(selected_item, page_index)
			else:
				# Si no tiene metadata o no tiene type, puede ser la raíz
				can_add = true
	else:
		# Si no hay selección, se puede añadir al nivel raíz
		can_add = true

	_update_buttons_state(page_index, can_edit_delete, can_move_up, can_move_down, can_move, can_duplicate, can_add)

func _on_command_deselected(page_index: int) -> void:
	if not move_mode_active.get(page_index, false):
		# Cuando no hay selección, se puede añadir al nivel raíz
		_update_buttons_state(page_index, false, false, false, false, false, true)

func _on_commands_tree_gui_input(page_index: int, event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
			call_deferred("_handle_right_click_on_tree", page_index, mouse_event.position)

func _handle_right_click_on_tree(page_index: int, local_position: Vector2) -> void:
	var commands_tree = _get_commands_tree_for_page(page_index)
	if not commands_tree:
		return

	var clicked_item = commands_tree.get_item_at_position(local_position)
	var global_pos = DisplayServer.mouse_get_position()

	if clicked_item:
		commands_tree.set_selected(clicked_item, 0)
	else:
		commands_tree.deselect_all()
		# Cuando se hace click en zona vacía, se puede añadir al nivel raíz
		_update_buttons_state(page_index, false, false, false, false, false, true)

	_show_commands_context_menu(page_index, global_pos)

func _show_commands_context_menu(page_index: int, global_position: Vector2) -> void:
	# No mostrar menú contextual si el modo mover está activo
	if move_mode_active.get(page_index, false):
		return

	var page = _get_page(page_index)
	if not page:
		return

	var commands_tree = _get_commands_tree_for_page(page_index)
	if not commands_tree:
		return

	var selected_item = commands_tree.get_selected()

	# Verificar si es la raíz del árbol
	var root = commands_tree.get_root()
	var is_root = (selected_item == root)

	var metadata = selected_item.get_metadata(0) if selected_item else null
	var item_type = metadata.type if metadata and metadata.has("type") else ""

	# Permitir añadir comandos a la raíz, page_root, o a branches/cases
	var can_add = item_type in ["", "page_root", "branch", "choice_branch", "switch_case", "default_commands"]
	# También permitir añadir si es un ConditionalCommand, SwitchCommand o ShowChoicesCommand
	if item_type == "command" and metadata and metadata.has("index"):
		if metadata.index >= 0 and metadata.index < page.commands.size():
			var cmd = page.commands[metadata.index]
			if cmd is ConditionalCommand or cmd is SwitchCommand or cmd is ShowChoicesCommand:
				can_add = true

	# Si es la raíz, se puede editar (abrir editor de condiciones)
	var can_edit = false
	if is_root:
		can_edit = true
	else:
		can_edit = item_type in ["command", "nested_command", "branch", "choice_branch", "switch_case", "default_commands"]

	var can_delete = can_edit and not is_root  # No se puede eliminar la raíz
	var can_move = item_type in ["command", "nested_command"]
	var can_duplicate = item_type in ["command", "nested_command", "branch", "choice_branch", "switch_case"]

	var context_menu = PopupMenu.new()
	if can_add:
		# Determinar el texto según el tipo de item seleccionado
		var add_text = "Añadir Comando"
		if item_type == "command" and metadata and metadata.has("index"):
			if metadata.index >= 0 and metadata.index < page.commands.size():
				var cmd = page.commands[metadata.index]
				if cmd is ConditionalCommand:
					add_text = "Añadir Branch"
				elif cmd is SwitchCommand:
					add_text = "Añadir Case"
				elif cmd is ShowChoicesCommand:
					add_text = "Añadir Opción"
		context_menu.add_item(add_text, 0)
	if can_edit:
		context_menu.add_item("Editar", 1)
	if can_delete:
		context_menu.add_item("Eliminar", 2)
	if can_duplicate:
		context_menu.add_item("Duplicar", 3)
	if can_move:
		context_menu.add_item("Mover", 4)

	add_child(context_menu)
	context_menu.id_pressed.connect(func(id): _on_context_menu_item_selected(page_index, id, selected_item); context_menu.queue_free())
	context_menu.popup_hide.connect(func(): context_menu.queue_free())
	context_menu.popup(Rect2(global_position, Vector2.ZERO))

func _on_context_menu_item_selected(page_index: int, menu_id: int, selected_item: TreeItem) -> void:
	match menu_id:
		0: _on_add_command_pressed(page_index)
		1: _on_edit_command_pressed(page_index)
		2: _on_delete_command_pressed(page_index)
		3: _on_duplicate_command_pressed(page_index)
		4: _on_move_command_pressed(page_index)

func _on_add_command_pressed(page_index: int) -> void:
	if not _get_page(page_index):
		return

	# Obtener el item seleccionado para saber si hay que añadir a un branch/case
	var commands_tree = _get_commands_tree_for_page(page_index)
	var selected_item = commands_tree.get_selected() if commands_tree else null
	var destination_metadata = {}

	if selected_item:
		var metadata = selected_item.get_metadata(0)
		if metadata:
			destination_metadata = metadata

			# Si se selecciona un ConditionalCommand, SwitchCommand o ShowChoicesCommand, añadir directamente el branch/case/choice
			if metadata.type == "command" and metadata.has("index"):
				var page = _get_page(page_index)
				if page and metadata.index >= 0 and metadata.index < page.commands.size():
					var cmd = page.commands[metadata.index]
					if cmd is ConditionalCommand:
						_add_branch_to_conditional(page_index, cmd, metadata.index)
						return
					elif cmd is SwitchCommand:
						_add_case_to_switch(page_index, cmd, metadata.index)
						return
					elif cmd is ShowChoicesCommand:
						_add_choice_to_show_choices(page_index, cmd, metadata.index)
						return

	_show_add_command_dialog(page_index, destination_metadata)

func _on_edit_command_pressed(page_index: int) -> void:
	var page = _get_page(page_index)
	if not page:
		return

	var commands_tree = _get_commands_tree_for_page(page_index)
	var selected_item = commands_tree.get_selected() if commands_tree else null
	if not selected_item:
		print("Event Editor: No hay comando seleccionado para editar")
		return

	# Verificar si es la raíz del árbol (página)
	var root = commands_tree.get_root()
	var is_root = (root == selected_item)

	if is_root:
		# Si es la raíz, abrir el editor de condiciones (igual que el botón "Gestionar Condiciones")
		_on_conditions_button_pressed(page_index)
		return

	var metadata = selected_item.get_metadata(0)
	if not metadata or not metadata.has("type"):
		print("Event Editor: Item seleccionado no es un comando")
		return

	var item_type = metadata.type

	# Si es una rama (branch), abrir directamente el editor de condiciones
	if item_type == "branch":
		var branch = metadata.get("branch")
		var parent_command = metadata.get("parent_command")
		if branch and parent_command is ConditionalCommand:
			_open_condition_editor_for_branch(branch, parent_command, page_index)
		return

	# Si es una opción (choice_branch), abrir directamente el editor de opciones
	if item_type == "choice_branch":
		var branch = metadata.get("branch")
		var parent_command = metadata.get("parent_command")
		if branch and parent_command is ShowChoicesCommand:
			_open_choice_branch_editor(branch, parent_command, page_index)
		return

	# Si es un switch_case, abrir directamente el editor de valores
	if item_type == "switch_case":
		var switch_case = metadata.get("case")
		var parent_command = metadata.get("parent_command")
		if switch_case and parent_command is SwitchCommand:
			_open_switch_case_values_editor(switch_case, parent_command, page_index)
		return

	# Si no es un comando normal, no se puede editar desde aquí
	if item_type not in ["command", "nested_command"]:
		print("Event Editor: El item seleccionado no es un comando editable")
		return

	# Obtener el comando desde el metadata
	var command = null
	if item_type == "command":
		command = metadata.get("command")
	elif item_type == "nested_command":
		command = metadata.get("command")

	if not command:
		print("Event Editor: No se pudo obtener el comando desde el metadata")
		return

	# Abrir editor específico según el tipo de comando
	# Al editar, no es un comando nuevo
	if command is ShowMessageCommand:
		_open_show_message_editor(command, page_index, false, -1)
	elif command is SetFlagCommand:
		_open_set_flag_editor(command, page_index, false, -1)
	elif command is SetVariableCommand:
		_open_set_variable_editor(command, page_index, false, -1)
	elif command is SetSelfSwitchCommand:
		_open_set_self_switch_editor(command, page_index, false, -1)
	elif command is StartBattleEventCommand:
		_open_start_battle_event_editor(command, page_index, false, -1)
	elif command is WarpCommand:
		_open_warp_editor(command, page_index, false, -1)
	elif command is WaitCommand:
		_open_wait_editor(command, page_index, false, -1)
	elif command is FadeCommand:
		_open_fade_editor(command, page_index, false, -1)
	elif command is SetWeatherCommand:
		_open_set_weather_editor(command, page_index, false, -1)
	elif command is SetDarknessCommand:
		_open_set_darkness_editor(command, page_index, false, -1)
	elif command is SetFlashlightCommand:
		_open_set_flashlight_editor(command, page_index, false, -1)
	elif command is SetEventThroughCommand:
		_open_set_event_through_editor(command, page_index, false, -1)
	elif command is SetActorVisibilityCommand:
		_open_set_actor_visibility_editor(command, page_index, false, -1)
	elif command is ShowPortraitCommand:
		_open_show_portrait_editor(command, page_index, false, -1)
	elif command is FollowActorCommand:
		_open_follow_actor_editor(command, page_index, false, -1)
	elif command is UseMOCommand:
		_open_use_mo_editor(command, page_index, false, -1)
	elif command is PlayAnimationCommand:
		_open_play_animation_editor(command, page_index, false, -1)
	elif command is MoveNPCCommand:
		_open_move_npc_editor(command, page_index, false, -1)
	elif command is SetTriggerCommand:
		_open_set_trigger_editor(command, page_index, false, -1)
	elif command is ConditionalCommand:
		_open_conditional_editor(command, page_index, false, -1)
	elif command is SwitchCommand:
		_open_switch_editor(command, page_index, false, -1)
	elif command is ShowChoicesCommand:
		_open_show_choices_editor(command, page_index, false, -1)
	else:
		print("Event Editor: Editor no implementado para ", command.get_script().get_global_name() if command.get_script() else "Unknown")

func _on_delete_command_pressed(page_index: int) -> void:
	_show_delete_confirmation_dialog(page_index)

func _on_duplicate_command_pressed(page_index: int) -> void:
	_duplicate_command(page_index)

func _duplicate_command(page_index: int) -> void:
	var page = _get_page(page_index)
	if not page:
		return

	var commands_tree = _get_commands_tree_for_page(page_index)
	var selected_item = commands_tree.get_selected() if commands_tree else null
	if not selected_item:
		return

	var metadata = selected_item.get_metadata(0)
	if not metadata or not metadata.has("type"):
		return

	var item_type = metadata.type
	if item_type not in ["command", "nested_command", "branch", "choice_branch", "switch_case"]:
		return

	var editable_page = page.duplicate(true) as EventPage
	if not editable_page:
		push_error("Event Editor: No se pudo duplicar la página")
		return

	var success = false
	var new_item_index = -1
	var parent_item = null  # Para usar en la selección después de duplicar

	if item_type == "command":
		# Duplicar comando principal
		var command_index = metadata.get("index", -1)
		if command_index >= 0 and command_index < editable_page.commands.size():
			var command_to_duplicate = editable_page.commands[command_index]
			var duplicated_command = command_to_duplicate.duplicate(true) as EventCommand

			# Insertar justo después del comando original
			var new_commands: Array[EventCommand] = []
			for i in range(editable_page.commands.size()):
				new_commands.append(editable_page.commands[i])
				if i == command_index:
					new_commands.append(duplicated_command)

			editable_page.set("commands", new_commands)
			event_node.pages[page_index] = editable_page
			_mark_as_changed()
			new_item_index = command_index + 1
			success = true

	elif item_type == "nested_command":
		# Duplicar nested_command
		parent_item = selected_item.get_parent()
		if not parent_item:
			return

		var parent_metadata = parent_item.get_metadata(0)
		if not parent_metadata or not parent_metadata.has("type"):
			return

		var main_command_item = _get_main_command_item_from_tree(parent_item, commands_tree)
		if not main_command_item:
			return

		var cmd_meta = main_command_item.get_metadata(0)
		var main_command = editable_page.commands[cmd_meta.index]
		var parent_type = parent_metadata.type

		# Encontrar el índice del nested_command en el árbol
		var nested_command_index = _find_item_index_in_tree(selected_item, parent_item, "nested_command")
		if nested_command_index < 0:
			return

		# Encontrar el índice del branch/case
		var indices = _get_branch_or_case_index(parent_item, parent_type)
		var branch_index = indices.branch_index
		var case_index = indices.case_index

		# Obtener el array de comandos y duplicar
		var commands_array = _get_commands_array_from_branch_case(main_command, parent_type, branch_index, case_index)
		if commands_array.is_empty() or nested_command_index >= commands_array.size():
			return

		var command_to_duplicate = commands_array[nested_command_index]
		var duplicated_command = command_to_duplicate.duplicate(true) as EventCommand
		commands_array.insert(nested_command_index + 1, duplicated_command)

		if _set_commands_array_to_branch_case(main_command, parent_type, branch_index, case_index, commands_array):
			success = true
			new_item_index = nested_command_index + 1

	elif item_type in ["branch", "choice_branch", "switch_case"]:
		# Duplicar branch/case
		parent_item = selected_item.get_parent()
		if not parent_item:
			return

		var main_command_item = _get_main_command_item_from_tree(parent_item, commands_tree)
		if not main_command_item:
			return

		var cmd_meta = main_command_item.get_metadata(0)
		var main_command = editable_page.commands[cmd_meta.index]

		if item_type == "branch" and main_command is ConditionalCommand:
			# Duplicar EventBranch
			var cond_cmd = main_command as ConditionalCommand
			var branch_index = metadata.get("branch_index", -1)
			if branch_index >= 0 and branch_index < cond_cmd.branches.size():
				var branch_to_duplicate = cond_cmd.branches[branch_index]
				var duplicated_branch = branch_to_duplicate.duplicate(true) as EventBranch
				if not duplicated_branch:
					push_error("Event Editor: No se pudo duplicar el EventBranch")
					return

				# Asegurarse de que el array de comandos esté correctamente duplicado
				var new_commands_array: Array[EventCommand] = []
				for cmd in duplicated_branch.commands:
					if cmd is EventCommand:
						new_commands_array.append(cmd as EventCommand)
				duplicated_branch.commands = new_commands_array

				# Crear un nuevo array con el branch duplicado insertado después del original
				var new_branches: Array[EventBranch] = []
				for i in range(cond_cmd.branches.size()):
					new_branches.append(cond_cmd.branches[i])
					if i == branch_index:
						new_branches.append(duplicated_branch)

				cond_cmd.branches = new_branches
				success = true
				new_item_index = branch_index + 1

		elif item_type == "choice_branch" and main_command is ShowChoicesCommand:
			# Duplicar ChoiceBranch
			var choices_cmd = main_command as ShowChoicesCommand
			var branch_index = metadata.get("branch_index", -1)
			if branch_index >= 0 and branch_index < choices_cmd.branches.size():
				var branch_to_duplicate = choices_cmd.branches[branch_index]
				var duplicated_branch = branch_to_duplicate.duplicate(true) as ChoiceBranch
				if not duplicated_branch:
					push_error("Event Editor: No se pudo duplicar el ChoiceBranch")
					return

				# Asegurarse de que el array de comandos esté correctamente duplicado
				var new_commands_array: Array[EventCommand] = []
				for cmd in duplicated_branch.commands:
					if cmd is EventCommand:
						new_commands_array.append(cmd as EventCommand)
				duplicated_branch.commands = new_commands_array

				# Crear un nuevo array con el branch duplicado insertado después del original
				var new_branches: Array[ChoiceBranch] = []
				for i in range(choices_cmd.branches.size()):
					new_branches.append(choices_cmd.branches[i])
					if i == branch_index:
						new_branches.append(duplicated_branch)

				choices_cmd.branches = new_branches
				success = true
				new_item_index = branch_index + 1

		elif item_type == "switch_case" and main_command is SwitchCommand:
			# Duplicar SwitchCase
			var switch_cmd = main_command as SwitchCommand
			var case_index = metadata.get("case_index", -1)
			if case_index >= 0 and case_index < switch_cmd.cases.size():
				var case_to_duplicate = switch_cmd.cases[case_index]

				# Duplicar el case con deep copy
				var duplicated_case = case_to_duplicate.duplicate(true) as SwitchCase
				if not duplicated_case:
					push_error("Event Editor: No se pudo duplicar el SwitchCase")
					return

				# Asegurarse de que el array de comandos esté correctamente duplicado
				# Crear un nuevo array tipado para los comandos
				var new_commands_array: Array[EventCommand] = []
				for cmd in duplicated_case.commands:
					if cmd is EventCommand:
						new_commands_array.append(cmd as EventCommand)
				duplicated_case.commands = new_commands_array

				# Crear un nuevo array con el case duplicado insertado después del original
				var new_cases: Array[SwitchCase] = []
				for i in range(switch_cmd.cases.size()):
					new_cases.append(switch_cmd.cases[i])
					if i == case_index:
						new_cases.append(duplicated_case)

				switch_cmd.cases = new_cases
				success = true
				new_item_index = case_index + 1

	if success:
		event_node.pages[page_index] = editable_page
		_mark_as_changed()
		# Actualizar árbol y seleccionar el comando duplicado
		if commands_tree:
			_update_commands_tree(commands_tree, editable_page, page_index)

			# Seleccionar el comando duplicado
			if item_type == "command":
				var root = commands_tree.get_root()
				if root:
					var children = root.get_children()
					if new_item_index >= 0 and new_item_index < children.size():
						commands_tree.set_selected(children[new_item_index], 0)
			elif item_type == "nested_command":
				# Buscar el item duplicado en el árbol
				var parent_item_after = parent_item
				if parent_item_after:
					var current = parent_item_after.get_first_child()
					var count = 0
					while current:
						if count == new_item_index:
							commands_tree.set_selected(current, 0)
							break
						var current_meta = current.get_metadata(0)
						if current_meta and current_meta.type == "nested_command":
							count += 1
						current = current.get_next()
			elif item_type in ["branch", "choice_branch", "switch_case"]:
				# Buscar el branch/case duplicado en el árbol
				# Usar call_deferred para evitar problemas de referencias
				call_deferred("_select_duplicated_branch_case", commands_tree, item_type, new_item_index)

		_refresh_inspector()
	else:
		push_error("Event Editor: No se pudo duplicar el comando")

func _on_move_command_up_pressed(page_index: int) -> void:
	_move_command(page_index, -1)

func _on_move_command_down_pressed(page_index: int) -> void:
	_move_command(page_index, 1)

func _on_move_command_pressed(page_index: int) -> void:
	var commands_tree = _get_commands_tree_for_page(page_index)
	var selected_item = commands_tree.get_selected() if commands_tree else null
	if not selected_item:
		return

	var metadata = selected_item.get_metadata(0)
	if not metadata or not metadata.has("type"):
		return

	var item_type = metadata.type
	if item_type not in ["command", "nested_command"]:
		return

	# Guardar información del comando a mover
	var move_data = {
		"type": item_type,
		"metadata": metadata.duplicate(true),
		"item": selected_item
	}

	# Si es un nested_command, calcular y guardar su índice dentro del branch/case
	if item_type == "nested_command":
		var nested_command_index = -1
		var parent_item = selected_item.get_parent()
		if parent_item:
			var current = parent_item.get_first_child()
			var count = 0
			while current:
				if current == selected_item:
					nested_command_index = count
					break
				var current_meta = current.get_metadata(0)
				if current_meta and current_meta.type == "nested_command":
					count += 1
				current = current.get_next()

		if nested_command_index >= 0:
			move_data["nested_command_index"] = nested_command_index
		else:
			push_error("Event Editor: No se pudo determinar el índice del nested_command al guardar")
			return

	command_to_move[page_index] = move_data

	# Entrar en modo mover
	_enter_move_mode(page_index)

func _on_accept_move_pressed(page_index: int) -> void:
	# page_index es la página donde está el destino seleccionado
	var dest_page_index = page_index
	var source_page_index = move_source_page_index

	if source_page_index < 0:
		push_error("Event Editor: No se encontró la página de origen")
		return

	var commands_tree = _get_commands_tree_for_page(dest_page_index)
	var selected_item = commands_tree.get_selected() if commands_tree else null
	if not selected_item:
		print("Event Editor: No hay item seleccionado")
		return

	# Verificar si es la raíz
	var root = commands_tree.get_root() if commands_tree else null
	if root == selected_item:
		# Si es la raíz, mover al primer nivel
		var move_info = command_to_move.get(source_page_index, {})
		var move_type = move_info.get("type", "")
		var is_cross_page = (source_page_index != dest_page_index)

		if move_type == "nested_command":
			# Mover nested_command a la raíz (primer nivel)
			print("Event Editor: Moviendo nested_command a la raíz (primer nivel)")
			var success = _move_nested_to_root(dest_page_index, source_page_index)
			if success:
				_exit_move_mode(source_page_index)
				_refresh_inspector()
				call_deferred("_update_buttons_after_move", dest_page_index)
			else:
				push_error("Event Editor: No se pudo mover nested_command a la raíz")
			return
		elif move_type == "command" and is_cross_page:
			# Mover command a la raíz entre páginas diferentes
			print("Event Editor: Moviendo command a la raíz (primer nivel) entre páginas")
			var success = _move_command_to_root(dest_page_index, source_page_index)
			if success:
				_exit_move_mode(source_page_index)
				_refresh_inspector()
				call_deferred("_update_buttons_after_move", dest_page_index)
			else:
				push_error("Event Editor: No se pudo mover command a la raíz")
			return
		else:
			print("Event Editor: La raíz solo es válida para nested_command o command entre páginas")
			return

	var destination_metadata = selected_item.get_metadata(0)
	if not destination_metadata or not destination_metadata.has("type"):
		print("Event Editor: No se encontró metadata o type en el item seleccionado")
		return

	var destination_type = destination_metadata.type
	print("Event Editor: Destino tipo: ", destination_type, " en página ", dest_page_index + 1)

	# Verificar que el destino es válido
	if destination_type not in ["branch", "choice_branch", "switch_case", "default_commands", "command"]:
		print("Event Editor: Tipo de destino no válido: ", destination_type)
		return

	# Si es command, NO es válido cuando se mueve un nested_command (solo la raíz es válida)
	var move_info = command_to_move.get(source_page_index, {})
	if destination_type == "command" and move_info.get("type", "") == "nested_command":
		print("Event Editor: command no es válido para nested_command, solo la raíz")
		return

	# Mover el comando (puede ser entre páginas)
	print("Event Editor: Llamando _move_command_to_destination")
	var success = _move_command_to_destination(source_page_index, dest_page_index, destination_metadata, selected_item)

	if success:
		print("Event Editor: Movimiento exitoso, saliendo del modo mover")
		_exit_move_mode(source_page_index)
		_refresh_inspector()

		# Asegurarse de actualizar los botones de la página destino
		call_deferred("_update_buttons_after_move", dest_page_index)
	else:
		push_error("Event Editor: El movimiento falló. Se restauró el estado anterior.")

func _on_cancel_move_pressed(page_index: int) -> void:
	_exit_move_mode(page_index)

func _enter_move_mode(page_index: int) -> void:
	move_mode_active[page_index] = true
	move_source_page_index = page_index

	# Guardar el move_info de la página origen para aplicar a todas las páginas
	var move_info = command_to_move.get(page_index, {})

	# Actualizar TODAS las páginas con el estilo de modo mover
	for i in range(event_node.pages.size()):
		var commands_tree = _get_commands_tree_for_page(i)
		var page = _get_page(i)
		if commands_tree and page:
			# Usar el move_info de la página origen para todas las páginas
			_update_commands_tree(commands_tree, page, i, move_info)

	# Deshabilitar controles del panel izquierdo en todas las páginas
	for i in range(event_node.pages.size()):
		_set_left_panel_controls_enabled(i, false)

	# Actualizar botones de la página actual
	var commands_tree_after = _get_commands_tree_for_page(page_index)
	var selected_item = commands_tree_after.get_selected() if commands_tree_after else null
	if selected_item:
		_on_command_selected(page_index)
	else:
		_update_buttons_state(page_index, false, false, false, false)

func _exit_move_mode(page_index: int) -> void:
	# Salir del modo mover de todas las páginas
	for i in range(event_node.pages.size()):
		move_mode_active[i] = false

	command_to_move.clear()
	move_source_page_index = -1
	move_backup.clear()  # Limpiar backups

	# Actualizar TODAS las páginas sin el estilo de modo mover
	for i in range(event_node.pages.size()):
		var commands_tree = _get_commands_tree_for_page(i)
		var page = _get_page(i)
		if commands_tree and page:
			_update_commands_tree(commands_tree, page, i)

	# Habilitar controles del panel izquierdo en todas las páginas
	for i in range(event_node.pages.size()):
		_set_left_panel_controls_enabled(i, true)

	# Actualizar botones de todas las páginas
	for i in range(event_node.pages.size()):
		_update_buttons_state(i, false, false, false, false)

func _set_left_panel_controls_enabled(page_index: int, enabled: bool) -> void:
	var controls = page_controls.get(page_index, {})
	if controls.is_empty():
		return

	if controls.has("execution_option"):
		controls.execution_option.disabled = not enabled
	if controls.has("trigger_option"):
		controls.trigger_option.disabled = not enabled
	if controls.has("blocks_player_check"):
		controls.blocks_player_check.disabled = not enabled
	if controls.has("through_check"):
		controls.through_check.disabled = not enabled
	if controls.has("conditions_button"):
		controls.conditions_button.disabled = not enabled

func _show_delete_confirmation_dialog(page_index: int) -> void:
	var commands_tree = _get_commands_tree_for_page(page_index)
	var selected_item = commands_tree.get_selected() if commands_tree else null
	if not selected_item:
		return

	var metadata = selected_item.get_metadata(0)
	if not metadata or not metadata.has("type"):
		return

	var item_names = {
		"command": "comando principal",
		"nested_command": "comando anidado",
		"branch": "branch condicional",
		"choice_branch": "opción de elección",
		"switch_case": "caso del switch",
		"default_commands": "caso por defecto"
	}
	var item_name = item_names.get(metadata.type, "item")

	var dialog = _create_confirmation_dialog(
		"Confirmar eliminación",
		"¿Estás seguro de que quieres eliminar este " + item_name + "?",
		func(): _do_delete_item(page_index)
	)
	dialog.popup_centered()

func _create_confirmation_dialog(title: String, text: String, on_confirm: Callable, on_cancel: Callable = Callable()) -> AcceptDialog:
	var dialog = AcceptDialog.new()
	dialog.title = title
	dialog.dialog_text = text

	var ok_button = dialog.get_ok_button()
	ok_button.hide()

	var custom_ok_button = dialog.add_button("Aceptar", false, "ok")
	var cancel_button = dialog.add_button("Cancelar", true, "cancel")

	dialog.custom_action.connect(func(action: String):
		if action == "ok":
			on_confirm.call()
			dialog.queue_free()
		elif action == "cancel":
			if on_cancel.is_valid():
				on_cancel.call()
			dialog.queue_free()
	)

	add_child(dialog)
	return dialog

func _do_delete_item(page_index: int) -> void:
	var page = _get_page(page_index)
	if not page:
		return

	var editable_page = page.duplicate(true) as EventPage
	if not editable_page:
		push_error("Event Editor: No se pudo duplicar la página")
		return

	var commands_tree = _get_commands_tree_for_page(page_index)
	var selected_item = commands_tree.get_selected() if commands_tree else null
	if not selected_item:
		return

	var metadata = selected_item.get_metadata(0)
	if not metadata or not metadata.has("type"):
		return

	var success = false
	match metadata.type:
		"command":
			success = _delete_main_command(editable_page, metadata.index)
		"nested_command":
			success = _delete_nested_command(editable_page, metadata, commands_tree)
		"branch", "choice_branch":
			success = _delete_branch(editable_page, metadata, commands_tree)
		"switch_case":
			success = _delete_switch_case(editable_page, metadata, commands_tree)
		"default_commands":
			success = _delete_default_commands(editable_page, metadata, commands_tree)

	if success:
		event_node.pages[page_index] = editable_page
		_mark_as_changed()
		_update_commands_tree(commands_tree, editable_page, page_index)
		_update_buttons_state(page_index, false, false, false)

func _delete_main_command(page: EventPage, command_index: int) -> bool:
	if command_index >= page.commands.size():
		return false
	var new_commands: Array[EventCommand] = []
	for i in range(page.commands.size()):
		if i != command_index:
			new_commands.append(page.commands[i])
	page.set("commands", new_commands)
	return true

func _delete_nested_command(page: EventPage, metadata: Dictionary, commands_tree: Tree) -> bool:
	# Obtener el parent_branch del metadata del comando anidado
	var parent_branch_meta = metadata.get("parent_branch")
	if not parent_branch_meta:
		push_error("Event Editor: No se encontró parent_branch en el metadata del comando anidado")
		return false

	var parent_command_ref = parent_branch_meta.get("parent_command")
	if not parent_command_ref:
		push_error("Event Editor: No se encontró parent_command en parent_branch")
		return false

	# Buscar recursivamente el comando principal en la página
	var location = _find_command_location_in_page(page, parent_command_ref)
	if not location.found:
		push_error("Event Editor: No se encontró el comando principal en la página (parent_command type: ", parent_command_ref.get_script(), ")")
		return false

	# Obtener el comando principal usando la ubicación
	var main_command = _get_nested_command_from_location(page, location)
	if not main_command:
		push_error("Event Editor: No se pudo obtener el comando principal desde la ubicación (is_root: ", location.is_root, ", root_index: ", location.root_index, ")")
		return false

	var parent_type = parent_branch_meta.get("type", "")
	var original_branch = parent_branch_meta.get("branch")
	var original_case = parent_branch_meta.get("case")

	# Encontrar el índice del branch/case
	var branch_index = -1
	var case_index = -1

	if parent_type == "choice_branch" and main_command is ShowChoicesCommand:
		var choices_cmd = main_command as ShowChoicesCommand
		# Primero intentar usar el branch_index del metadata si está disponible
		var metadata_branch_index = parent_branch_meta.get("branch_index", -1)
		if metadata_branch_index >= 0 and metadata_branch_index < choices_cmd.branches.size():
			branch_index = metadata_branch_index
		elif original_branch:
			# Si no hay índice, comparar por label
			for i in range(choices_cmd.branches.size()):
				if choices_cmd.branches[i].label == original_branch.label:
					branch_index = i
					break

		if branch_index < 0:
			push_error("Event Editor: No se pudo encontrar el branch_index (metadata_branch_index: ", metadata_branch_index, ", branches size: ", choices_cmd.branches.size(), ")")
			return false
	elif parent_type == "branch" and main_command is ConditionalCommand:
		var cond_cmd = main_command as ConditionalCommand
		if original_branch:
			# Comparar por condición en lugar de referencia
			for i in range(cond_cmd.branches.size()):
				var branch = cond_cmd.branches[i]
				var orig_branch = original_branch
				# Comparar condiciones si existen
				if (branch.condition == null and orig_branch.condition == null) or \
				   (branch.condition != null and orig_branch.condition != null and \
				    branch.condition.type == orig_branch.condition.type):
					branch_index = i
					break
	elif parent_type == "switch_case" and main_command is SwitchCommand:
		var switch_cmd = main_command as SwitchCommand
		if original_case:
			for i in range(switch_cmd.cases.size()):
				var switch_case = switch_cmd.cases[i]
				var orig_case = original_case
				# Comparar valores si existen
				if switch_case.values.size() == orig_case.values.size():
					var values_match = true
					for j in range(switch_case.values.size()):
						if switch_case.values[j] != orig_case.values[j]:
							values_match = false
							break
					if values_match:
						case_index = i
						break

	# Obtener el comando anidado del metadata
	var nested_cmd = metadata.get("command")
	if not nested_cmd:
		push_error("Event Editor: No se encontró el comando anidado en el metadata")
		return false

	# Validar que tenemos un branch_index o case_index válido antes de continuar
	if parent_type == "choice_branch" and branch_index < 0:
		push_error("Event Editor: branch_index inválido para choice_branch (branch_index: ", branch_index, ")")
		return false
	elif parent_type == "branch" and branch_index < 0:
		push_error("Event Editor: branch_index inválido para branch (branch_index: ", branch_index, ")")
		return false
	elif parent_type == "switch_case" and case_index < 0:
		push_error("Event Editor: case_index inválido para switch_case (case_index: ", case_index, ")")
		return false

	# Obtener el array de comandos y encontrar el índice del comando
	var commands_array = _get_commands_array_from_branch_case(main_command, parent_type, branch_index, case_index)
	if commands_array.is_empty():
		push_error("Event Editor: El array de comandos está vacío (branch_index: ", branch_index, ", case_index: ", case_index, ", parent_type: ", parent_type, ")")
		return false

	# Buscar el comando en el array
	# Primero intentar comparar por referencia (funciona si no se duplicó)
	var nested_command_index = -1
	for i in range(commands_array.size()):
		if commands_array[i] == nested_cmd:
			nested_command_index = i
			break

	# Si no se encontró por referencia, buscar por propiedades (útil después de duplicar)
	if nested_command_index < 0:
		for i in range(commands_array.size()):
			var array_cmd = commands_array[i]
			if _commands_match_by_properties(array_cmd, nested_cmd):
				nested_command_index = i
				break

	if nested_command_index < 0:
		# Intentar una última vez usando el índice del comando en el metadata si está disponible
		# Esto es útil cuando el comando está en una posición conocida
		var cmd_index_in_parent = -1
		# Buscar el índice contando en el árbol (fallback)
		if commands_tree:
			var selected_item = commands_tree.get_selected()
			if selected_item:
				var parent_item = selected_item.get_parent()
				if parent_item:
					var current = parent_item.get_first_child()
					var count = 0
					while current:
						if current == selected_item:
							cmd_index_in_parent = count
							break
						var current_meta = current.get_metadata(0)
						if current_meta and current_meta.type == "nested_command":
							count += 1
						current = current.get_next()

					if cmd_index_in_parent >= 0 and cmd_index_in_parent < commands_array.size():
						nested_command_index = cmd_index_in_parent

		if nested_command_index < 0:
			push_error("Event Editor: No se encontró el comando anidado en el array (array size: ", commands_array.size(), ", cmd_index_in_parent: ", cmd_index_in_parent, ")")
			push_error("Event Editor: nested_cmd type: ", nested_cmd.get_script(), ", array[0] type: ", commands_array[0].get_script() if commands_array.size() > 0 else "empty")
			return false

	# Eliminar el comando
	commands_array.remove_at(nested_command_index)
	return _set_commands_array_to_branch_case(main_command, parent_type, branch_index, case_index, commands_array)

func _delete_branch(page: EventPage, metadata: Dictionary, commands_tree: Tree) -> bool:
	var parent_command_ref = metadata.get("parent_command")
	if not parent_command_ref:
		return false

	# Buscar recursivamente el comando principal en la página
	var location = _find_command_location_in_page(page, parent_command_ref)
	if not location.found:
		return false

	# Obtener el comando principal usando la ubicación
	var main_command = _get_nested_command_from_location(page, location)
	if not main_command:
		return false

	var branch_index = metadata.get("branch_index", -1)
	if branch_index < 0:
		return false

	if metadata.type == "branch" and main_command is ConditionalCommand:
		var cond_cmd = main_command as ConditionalCommand
		if branch_index >= 0 and branch_index < cond_cmd.branches.size():
			# Crear un nuevo array sin el branch a eliminar
			var new_branches: Array[EventBranch] = []
			for i in range(cond_cmd.branches.size()):
				if i != branch_index:
					new_branches.append(cond_cmd.branches[i])
			cond_cmd.branches = new_branches
			return true
	elif metadata.type == "choice_branch" and main_command is ShowChoicesCommand:
		var choices_cmd = main_command as ShowChoicesCommand
		if branch_index >= 0 and branch_index < choices_cmd.branches.size():
			# Crear un nuevo array sin el branch a eliminar
			var new_branches: Array[ChoiceBranch] = []
			for i in range(choices_cmd.branches.size()):
				if i != branch_index:
					new_branches.append(choices_cmd.branches[i])
			choices_cmd.branches = new_branches
			return true

	return false

func _delete_switch_case(page: EventPage, metadata: Dictionary, commands_tree: Tree) -> bool:
	var parent_item = commands_tree.get_selected().get_parent()
	if not parent_item:
		return false

	var parent_metadata = parent_item.get_metadata(0)
	if not parent_metadata or parent_metadata.type != "command":
		return false

	var main_command = page.commands[parent_metadata.index]
	if not (main_command is SwitchCommand):
		return false

	if metadata.type == "switch_case":
		var case_index = metadata.get("case_index", -1)
		if case_index < 0:
			return false

		var switch_cmd = main_command as SwitchCommand
		if case_index >= 0 and case_index < switch_cmd.cases.size():
			# Crear un nuevo array sin el case a eliminar
			var new_cases: Array[SwitchCase] = []
			for i in range(switch_cmd.cases.size()):
				if i != case_index:
					new_cases.append(switch_cmd.cases[i])
			switch_cmd.cases = new_cases
			return true

	return false

func _delete_default_commands(page: EventPage, metadata: Dictionary, commands_tree: Tree) -> bool:
	var parent_item = commands_tree.get_selected().get_parent()
	if not parent_item:
		return false

	var parent_metadata = parent_item.get_metadata(0)
	if not parent_metadata or parent_metadata.type != "command":
		return false

	var main_command = page.commands[parent_metadata.index]
	if main_command is SwitchCommand:
		main_command.default_commands = []
		return true

	return false

# === MOVIMIENTO DE COMANDOS ===
func _can_move_item_up(item: TreeItem, page_index: int) -> bool:
	if not item:
		return false

	var metadata = item.get_metadata(0)
	if not metadata or not metadata.has("type"):
		return false

	var item_type = metadata.type

	# Para comandos principales
	if item_type == "command":
		if not metadata.has("index"):
			return false
		var page = _get_page(page_index)
		if not page:
			return false
		return metadata.index > 0

	# Para nodos hijos (nested commands, branches, etc.)
	if item_type in ["nested_command", "branch", "choice_branch", "switch_case"]:
		var parent_item = item.get_parent()
		if not parent_item:
			return false

		# Obtener el índice del item entre sus hermanos
		var parent = item.get_parent()
		var siblings = []
		var current = parent.get_first_child()
		while current:
			siblings.append(current)
			current = current.get_next()

		var item_index = siblings.find(item)
		return item_index > 0

	return false

func _can_move_item_down(item: TreeItem, page_index: int) -> bool:
	if not item:
		return false

	var metadata = item.get_metadata(0)
	if not metadata or not metadata.has("type"):
		return false

	var item_type = metadata.type

	# Para comandos principales
	if item_type == "command":
		if not metadata.has("index"):
			return false
		var page = _get_page(page_index)
		if not page:
			return false
		return metadata.index < page.commands.size() - 1

	# Para nodos hijos (nested commands, branches, etc.)
	if item_type in ["nested_command", "branch", "choice_branch", "switch_case"]:
		var parent_item = item.get_parent()
		if not parent_item:
			return false

		# Obtener el índice del item entre sus hermanos
		var parent = item.get_parent()
		var siblings = []
		var current = parent.get_first_child()
		while current:
			siblings.append(current)
			current = current.get_next()

		var item_index = siblings.find(item)
		return item_index < siblings.size() - 1

	return false

func _move_command(page_index: int, direction: int) -> void:
	# direction: -1 para arriba, 1 para abajo
	var page = _get_page(page_index)
	if not page:
		return

	var commands_tree = _get_commands_tree_for_page(page_index)
	var selected_item = commands_tree.get_selected() if commands_tree else null
	if not selected_item:
		return

	var metadata = selected_item.get_metadata(0)
	if not metadata or not metadata.has("type"):
		return

	var item_type = metadata.type

	# Crear una copia editable de la página
	var editable_page = page.duplicate(true) as EventPage
	if not editable_page:
		push_error("Event Editor: No se pudo duplicar la página")
		return

	var success = false

	# Mover comando principal
	if item_type == "command":
		success = _move_main_command(editable_page, metadata.index, direction)
	# Mover nodo hijo dentro de su padre
	elif item_type in ["nested_command", "branch", "choice_branch", "switch_case"]:
		success = _move_nested_item(editable_page, metadata, commands_tree, direction)

	if success:
		# Guardar información para reseleccionar después de actualizar el árbol
		var reselect_info = {
			"type": item_type,
			"direction": direction
		}

		# Guardar índices según el tipo
		if item_type == "command":
			reselect_info["old_index"] = metadata.index
			reselect_info["new_index"] = metadata.index + direction
		else:
			# Para nodos hijos, guardar información del padre y el índice relativo
			var parent_item = commands_tree.get_selected().get_parent()
			if parent_item:
				var parent_metadata = parent_item.get_metadata(0)
				if parent_metadata and parent_metadata.has("type"):
					# Buscar el comando principal que contiene este item
					var main_command_item = parent_item
					while main_command_item and main_command_item != commands_tree.get_root():
						var cmd_meta = main_command_item.get_metadata(0)
						if cmd_meta and cmd_meta.has("type") and cmd_meta.type == "command":
							reselect_info["parent_command_index"] = cmd_meta.index
							break
						main_command_item = main_command_item.get_parent()

					# Calcular índice relativo entre hermanos
					var parent = commands_tree.get_selected().get_parent()
					var siblings = []
					var current = parent.get_first_child()
					var current_index = 0
					var target_index = -1
					while current:
						if current == commands_tree.get_selected():
							target_index = current_index
						siblings.append(current)
						current = current.get_next()
						current_index += 1

					if target_index >= 0:
						reselect_info["old_sibling_index"] = target_index
						reselect_info["new_sibling_index"] = target_index + direction
						reselect_info["parent_type"] = parent_metadata.type

					# Para nested_command, también guardar el índice del branch/case padre
					if item_type == "nested_command":
						# El parent_item es el branch/case que contiene el nested_command
						var branch_parent = parent_item
						var branch_parent_meta = branch_parent.get_metadata(0)
						if branch_parent_meta:
							# Encontrar el índice del branch/case dentro del comando principal
							var command_item = branch_parent.get_parent()
							if command_item:
								var branch_index = -1
								var branch_current = command_item.get_first_child()
								var branch_count = 0
								while branch_current:
									if branch_current == branch_parent:
										branch_index = branch_count
										break
									var branch_current_meta = branch_current.get_metadata(0)
									if branch_current_meta and branch_current_meta.type == branch_parent_meta.type:
										branch_count += 1
									branch_current = branch_current.get_next()

								if branch_index >= 0:
									reselect_info["parent_branch_index"] = branch_index
									reselect_info["parent_branch_type"] = branch_parent_meta.type

		event_node.pages[page_index] = editable_page
		_mark_as_changed()
		_update_commands_tree(commands_tree, editable_page, page_index)

		# Reseleccionar el item movido
		call_deferred("_reselect_moved_item", page_index, reselect_info)

func _move_main_command(page: EventPage, command_index: int, direction: int) -> bool:
	var new_index = command_index + direction

	# Validar que el nuevo índice sea válido
	if new_index < 0 or new_index >= page.commands.size():
		return false

	# Intercambiar los comandos (el comando y todos sus hijos se mueven juntos)
	var temp_command = page.commands[command_index]
	page.commands[command_index] = page.commands[new_index]
	page.commands[new_index] = temp_command

	return true

func _move_nested_item(page: EventPage, metadata: Dictionary, commands_tree: Tree, direction: int) -> bool:
	var item_type = metadata.type

	# Encontrar el comando padre
	var parent_item = commands_tree.get_selected().get_parent()
	if not parent_item:
		return false

	var parent_metadata = parent_item.get_metadata(0)
	if not parent_metadata or not parent_metadata.has("type"):
		return false

	# Buscar el comando principal que contiene este item
	var main_command_item = parent_item
	while main_command_item and main_command_item != commands_tree.get_root():
		var cmd_meta = main_command_item.get_metadata(0)
		if cmd_meta and cmd_meta.has("type") and cmd_meta.type == "command":
			break
		main_command_item = main_command_item.get_parent()

	if not main_command_item:
		return false

	var cmd_meta = main_command_item.get_metadata(0)
	var main_command = page.commands[cmd_meta.index]

	# Obtener el array de comandos donde está el item
	var commands_array: Array = []
	var item_index = -1

	if item_type == "nested_command":
		# El item está en un array de comandos anidados
		var branch_meta = parent_item.get_metadata(0)
		if not branch_meta:
			return false

		# IMPORTANTE: Necesitamos obtener el branch/case del comando duplicado, no del metadata
		# porque el metadata apunta al branch original

		if branch_meta.type == "branch" and main_command is ConditionalCommand:
			# Es un branch de ConditionalCommand
			# IMPORTANTE: Usar el índice del branch guardado en el metadata
			var cond_cmd = main_command as ConditionalCommand
			var branch_index = branch_meta.get("branch_index", -1)

			# Si no hay branch_index en el metadata, intentar encontrarlo contando en el árbol
			if branch_index < 0:
				var command_item = parent_item.get_parent()
				if command_item:
					var current = command_item.get_first_child()
					var count = 0
					while current:
						if current == parent_item:
							branch_index = count
							break
						var current_meta = current.get_metadata(0)
						if current_meta and current_meta.type == "branch":
							count += 1
						current = current.get_next()

			if branch_index >= 0 and branch_index < cond_cmd.branches.size():
				commands_array = cond_cmd.branches[branch_index].commands
			else:
				return false

		elif branch_meta.type == "choice_branch" and branch_meta.has("branch") and main_command is ShowChoicesCommand:
			# Es un branch de ShowChoicesCommand
			# IMPORTANTE: Necesitamos obtener el branch del comando duplicado por su posición en el árbol
			var choices_cmd = main_command as ShowChoicesCommand
			# Encontrar el índice del branch contando cuántos choice_branch hay antes del actual
			var branch_index = -1
			var command_item = parent_item.get_parent()
			if command_item:
				var current = command_item.get_first_child()
				var count = 0
				while current:
					if current == parent_item:
						branch_index = count
						break
					var current_meta = current.get_metadata(0)
					if current_meta and current_meta.type == "choice_branch":
						count += 1
					current = current.get_next()

			if branch_index >= 0 and branch_index < choices_cmd.branches.size():
				commands_array = choices_cmd.branches[branch_index].commands
			else:
				return false

		elif branch_meta.type == "switch_case" and branch_meta.has("case") and main_command is SwitchCommand:
			# Es un case de SwitchCommand
			# IMPORTANTE: Necesitamos obtener el case del comando duplicado por su posición en el árbol
			var switch_cmd = main_command as SwitchCommand
			# Encontrar el índice del case contando cuántos switch_case hay antes del actual
			var case_index = -1
			var command_item = parent_item.get_parent()
			if command_item:
				var current = command_item.get_first_child()
				var count = 0
				while current:
					if current == parent_item:
						case_index = count
						break
					var current_meta = current.get_metadata(0)
					if current_meta and current_meta.type == "switch_case":
						count += 1
					current = current.get_next()

			if case_index >= 0 and case_index < switch_cmd.cases.size():
				commands_array = switch_cmd.cases[case_index].commands
			else:
				return false

		elif branch_meta.type == "default_commands" and main_command is SwitchCommand:
			# Es el default de SwitchCommand
			commands_array = main_command.default_commands
		else:
			return false

		if not commands_array.is_empty():
			# Encontrar el índice del comando por su posición en el árbol
			# en lugar de por referencia, porque después de duplicate() son nuevas instancias
			var selected_item = commands_tree.get_selected()
			if selected_item:
				# Contar cuántos nested_command hay antes del actual dentro del mismo padre
				var current = parent_item.get_first_child()
				var count = 0
				while current:
					if current == selected_item:
						item_index = count
						break
					var current_meta = current.get_metadata(0)
					if current_meta and current_meta.type == "nested_command":
						count += 1
					current = current.get_next()

			# Validar que el índice sea válido
			if item_index < 0 or item_index >= commands_array.size():
				return false
		else:
			return false

	elif item_type == "branch" and main_command is ConditionalCommand:
		# Encontrar el branch por su posición en el árbol
		var branch_index = -1
		var command_item = parent_item
		if command_item:
			var current = command_item.get_first_child()
			var count = 0
			while current:
				if current == commands_tree.get_selected():
					branch_index = count
					break
				var current_meta = current.get_metadata(0)
				if current_meta and current_meta.type == "branch":
					count += 1
				current = current.get_next()

		if branch_index >= 0 and branch_index < main_command.branches.size():
			var new_index = branch_index + direction
			if new_index < 0 or new_index >= main_command.branches.size():
				return false
			# Intercambiar branches directamente
			var cond_cmd = main_command as ConditionalCommand
			var temp_branch = cond_cmd.branches[branch_index]
			cond_cmd.branches[branch_index] = cond_cmd.branches[new_index]
			cond_cmd.branches[new_index] = temp_branch
			return true
		else:
			return false

	elif item_type == "choice_branch" and main_command is ShowChoicesCommand:
		# Encontrar el choice_branch por su posición en el árbol
		var branch_index = -1
		var command_item = parent_item
		if command_item:
			var current = command_item.get_first_child()
			var count = 0
			while current:
				if current == commands_tree.get_selected():
					branch_index = count
					break
				var current_meta = current.get_metadata(0)
				if current_meta and current_meta.type == "choice_branch":
					count += 1
				current = current.get_next()

		if branch_index >= 0 and branch_index < main_command.branches.size():
			var new_index = branch_index + direction
			if new_index < 0 or new_index >= main_command.branches.size():
				return false
			# Intercambiar branches directamente
			var choices_cmd = main_command as ShowChoicesCommand
			var temp_branch = choices_cmd.branches[branch_index]
			choices_cmd.branches[branch_index] = choices_cmd.branches[new_index]
			choices_cmd.branches[new_index] = temp_branch
			return true
		else:
			return false

	elif item_type == "switch_case" and main_command is SwitchCommand:
		# Encontrar el switch_case por su posición en el árbol
		var case_index = -1
		var command_item = parent_item
		if command_item:
			var current = command_item.get_first_child()
			var count = 0
			while current:
				if current == commands_tree.get_selected():
					case_index = count
					break
				var current_meta = current.get_metadata(0)
				if current_meta and current_meta.type == "switch_case":
					count += 1
				current = current.get_next()

		if case_index >= 0 and case_index < main_command.cases.size():
			var new_index = case_index + direction
			if new_index < 0 or new_index >= main_command.cases.size():
				return false
			# Intercambiar cases directamente
			var switch_cmd = main_command as SwitchCommand
			var temp_case = switch_cmd.cases[case_index]
			switch_cmd.cases[case_index] = switch_cmd.cases[new_index]
			switch_cmd.cases[new_index] = temp_case
			return true
		else:
			return false

	# Para nested_commands, continuar con la lógica existente
	if commands_array.is_empty() or item_index < 0:
		return false

	var new_index = item_index + direction
	if new_index < 0 or new_index >= commands_array.size():
		return false

	# Para nested_commands, crear un nuevo array para evitar el error de "read-only"
	var new_commands_array: Array[EventCommand] = []
	for i in range(commands_array.size()):
		var cmd_raw: Variant = null
		if i == item_index:
			cmd_raw = commands_array[new_index]
		elif i == new_index:
			cmd_raw = commands_array[item_index]
		else:
			cmd_raw = commands_array[i]

		# Verificar que sea un EventCommand válido antes de añadirlo
		if cmd_raw != null and cmd_raw is EventCommand:
			var cmd = cmd_raw as EventCommand
			if cmd:
				new_commands_array.append(cmd)
			else:
				push_error("Event Editor: No se pudo hacer cast a EventCommand en posición %d" % i)
				return false
		else:
			if cmd_raw == null:
				push_error("Event Editor: Comando null encontrado en posición %d" % i)
			else:
				push_error("Event Editor: Comando no es EventCommand en posición %d: %s" % [i, str(cmd_raw)])
			return false

	# Verificar que el nuevo array tenga el mismo tamaño que el original
	if new_commands_array.size() != commands_array.size():
		push_error("Event Editor: El nuevo array no tiene el mismo tamaño que el original (%d vs %d)" % [new_commands_array.size(), commands_array.size()])
		return false

	# Asignar el nuevo array de vuelta al branch/case
	var branch_meta = parent_item.get_metadata(0)
	if not branch_meta:
		return false

	var parent_type = branch_meta.get("type", "")
	var branch_index = branch_meta.get("branch_index", -1)
	var case_index = branch_meta.get("case_index", -1)

	return _set_commands_array_to_branch_case(main_command, parent_type, branch_index, case_index, new_commands_array)

func _reselect_moved_item(page_index: int, reselect_info: Dictionary) -> void:
	var commands_tree = _get_commands_tree_for_page(page_index)
	if not commands_tree:
		return

	var item_type = reselect_info.get("type", "")

	if item_type == "command":
		# Reseleccionar comando principal
		var new_index = reselect_info.get("new_index", -1)
		if new_index < 0:
			return

		var root = commands_tree.get_root()
		if root:
			var children = root.get_children()
			if new_index >= 0 and new_index < children.size():
				commands_tree.set_selected(children[new_index], 0)
	else:
		# Para nodos hijos, encontrar el item por su posición relativa
		var parent_command_index = reselect_info.get("parent_command_index", -1)
		var new_sibling_index = reselect_info.get("new_sibling_index", -1)
		var parent_type = reselect_info.get("parent_type", "")

		if parent_command_index < 0 or new_sibling_index < 0:
			return

		# Encontrar el comando padre
		var root = commands_tree.get_root()
		if not root:
			return

		var children = root.get_children()
		if parent_command_index >= children.size():
			return

		var parent_command_item = children[parent_command_index]
		if not parent_command_item:
			return

		# Buscar el contenedor padre del item movido
		var target_parent = null

		if item_type == "nested_command":
			# Para nested_command, necesitamos encontrar el branch/case correcto
			var parent_branch_index = reselect_info.get("parent_branch_index", -1)
			var parent_branch_type = reselect_info.get("parent_branch_type", "")

			if parent_branch_index >= 0 and parent_branch_type != "":
				# Encontrar el branch/case por su índice específico
				var branch_or_case = parent_command_item.get_first_child()
				var count = 0
				while branch_or_case:
					var branch_meta = branch_or_case.get_metadata(0)
					if branch_meta and branch_meta.type == parent_branch_type:
						if count == parent_branch_index:
							target_parent = branch_or_case
							break
						count += 1
					branch_or_case = branch_or_case.get_next()
			else:
				# Fallback: buscar el primer branch/case del tipo correcto
				if parent_type == "branch" or parent_type == "choice_branch" or parent_type == "switch_case" or parent_type == "default_commands":
					var branch_or_case = parent_command_item.get_first_child()
					while branch_or_case:
						var branch_meta = branch_or_case.get_metadata(0)
						if branch_meta and branch_meta.type == parent_type:
							target_parent = branch_or_case
							break
						branch_or_case = branch_or_case.get_next()
		elif item_type in ["branch", "choice_branch", "switch_case"]:
			# El padre es directamente el comando principal
			target_parent = parent_command_item

		if target_parent:
			# Obtener todos los hijos del contenedor que coinciden con el tipo
			var siblings = []
			var current = target_parent.get_first_child()
			while current:
				var current_meta = current.get_metadata(0)
				if current_meta and current_meta.type == item_type:
					siblings.append(current)
				current = current.get_next()

			if new_sibling_index >= 0 and new_sibling_index < siblings.size():
				commands_tree.set_selected(siblings[new_sibling_index], 0)

# === DIÁLOGO DE AÑADIR COMANDO ===
func _show_add_command_dialog(page_index: int, destination_metadata: Dictionary = {}) -> void:
	var command_types = [
		"ShowMessage", "SetFlag", "SetVariable", "SetSelfSwitch",
		"StartBattleEvent", "Warp", "ShowChoices", "Conditional",
		"Switch", "Wait", "Fade", "SetWeather", "SetDarkness",
		"SetFlashlight", "BlockPlayer", "UnblockPlayer", "SetEventThrough",
		"MoveNPC", "PlayAnimation", "SetActorVisibility", "ShowPortrait",
		"ClosePortrait", "FollowActor", "UseMO", "SetTrigger"
	]

	var dialog = Window.new()
	dialog.title = "Añadir Comando"
	dialog.size = Vector2(400, 500)
	dialog.unresizable = true
	dialog.close_requested.connect(func(): dialog.hide())

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 10
	vbox.offset_top = 10
	vbox.offset_right = -10
	vbox.offset_bottom = -10
	vbox.add_theme_constant_override("separation", 10)

	var title_label = Label.new()
	title_label.text = "Añadir Comando"
	title_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title_label)
	vbox.add_child(HSeparator.new())

	var label = Label.new()
	label.text = "Selecciona el tipo de comando:"
	vbox.add_child(label)

	var command_list = ItemList.new()
	command_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for cmd_type in command_types:
		command_list.add_item(cmd_type)
	vbox.add_child(command_list)

	var buttons_container = HBoxContainer.new()
	buttons_container.alignment = BoxContainer.ALIGNMENT_END

	var add_button = Button.new()
	add_button.text = "Añadir"
	add_button.disabled = true
	add_button.pressed.connect(func():
		var selected_items = command_list.get_selected_items()
		if selected_items.size() > 0:
			var command_type = command_types[selected_items[0]] + "Command"
			dialog.queue_free()
			# Esperar a que el diálogo se cierre antes de crear el comando
			call_deferred("_create_command_of_type", page_index, command_type, destination_metadata)
		)

	command_list.item_selected.connect(func(idx): add_button.disabled = false)
	command_list.item_activated.connect(func(idx):
		var command_type = command_types[idx] + "Command"
		dialog.queue_free()
		# Esperar a que el diálogo se cierre antes de crear el comando
		call_deferred("_create_command_of_type", page_index, command_type, destination_metadata)
	)

	buttons_container.add_child(add_button)

	var cancel_button = Button.new()
	cancel_button.text = "Cancelar"
	cancel_button.pressed.connect(func(): dialog.queue_free())
	buttons_container.add_child(cancel_button)

	vbox.add_child(buttons_container)
	dialog.add_child(vbox)
	add_child(dialog)
	dialog.exclusive = true
	dialog.popup_centered()

func _create_command_of_type(page_index: int, command_type_name: String, destination_metadata: Dictionary = {}) -> void:
	var page = _get_page(page_index)
	if not page:
		return

	var editable_page = page.duplicate(true) as EventPage
	if not editable_page:
		push_error("Event Editor: No se pudo duplicar la página")
		return

	var script_path = "res://Scripts/Events/Commands/" + command_type_name + ".gd"
	var script = load(script_path)
	if not script:
		push_error("Event Editor: No se encontró el script para " + command_type_name)
		return

	var new_command = Resource.new()
	new_command.set_script(script)

	# Si hay un destino (branch/case), añadir el comando ahí
	if destination_metadata and destination_metadata.has("type"):
		var dest_type = destination_metadata.get("type")

		if dest_type == "branch":
			var branch_index = destination_metadata.get("branch_index", -1)
			var parent_command = destination_metadata.get("parent_command")
			if branch_index >= 0 and parent_command is ConditionalCommand:
				# Encontrar el comando en la página duplicada por su índice
				var cmd_index = -1
				var original_page = _get_page(page_index)
				if original_page:
					for i in range(original_page.commands.size()):
						if original_page.commands[i] == parent_command:
							cmd_index = i
							break

				if cmd_index >= 0 and cmd_index < editable_page.commands.size():
					var cmd = editable_page.commands[cmd_index]
					if cmd is ConditionalCommand:
						var cond_cmd = cmd as ConditionalCommand
						if branch_index >= 0 and branch_index < cond_cmd.branches.size():
							var branch = cond_cmd.branches[branch_index]
							# Crear un nuevo array para evitar el error de "read-only"
							var new_commands_array: Array[EventCommand] = []
							for existing_cmd in branch.commands:
								new_commands_array.append(existing_cmd)
							new_commands_array.append(new_command)
							branch.commands = new_commands_array
							event_node.pages[page_index] = editable_page
							_mark_as_changed()
							_refresh_commands_tree_and_select_new(page_index, editable_page, new_command)
							return

		elif dest_type == "choice_branch":
			var branch_index = destination_metadata.get("branch_index", -1)
			var parent_command = destination_metadata.get("parent_command")
			var original_branch = destination_metadata.get("branch")
			if branch_index >= 0 and parent_command is ShowChoicesCommand:
				# Buscar recursivamente el comando en la página original
				var original_page = _get_page(page_index)
				if original_page:
					var location = _find_command_location_in_page(original_page, parent_command)
					if location.found:
						# Obtener el comando ShowChoicesCommand en la página duplicada
						var choices_cmd = _get_nested_command_from_location(editable_page, location)
						if choices_cmd is ShowChoicesCommand:
							# Verificar que el branch_index es válido
							if branch_index >= 0 and branch_index < choices_cmd.branches.size():
								# Verificar que el branch corresponde al original usando el label
								# Esto es importante cuando hay múltiples ShowChoicesCommand anidados
								var target_branch_index = branch_index
								if original_branch:
									# Buscar el branch correcto por su label en caso de que los índices no coincidan
									for i in range(choices_cmd.branches.size()):
										if choices_cmd.branches[i].label == original_branch.label:
											target_branch_index = i
											break

								var branch = choices_cmd.branches[target_branch_index]
								# Crear un nuevo array para evitar el error de "read-only"
								var new_commands_array: Array[EventCommand] = []
								for existing_cmd in branch.commands:
									new_commands_array.append(existing_cmd)
								new_commands_array.append(new_command)
								branch.commands = new_commands_array
								event_node.pages[page_index] = editable_page
								_mark_as_changed()
								_refresh_commands_tree_and_select_new(page_index, editable_page, new_command)
								return
							else:
								push_error("Event Editor: branch_index inválido: ", branch_index, " (branches size: ", choices_cmd.branches.size(), ")")
						else:
							push_error("Event Editor: No se encontró ShowChoicesCommand en la ubicación especificada")
					else:
						push_error("Event Editor: No se encontró parent_command en la página original")

		elif dest_type == "switch_case":
			var case_index = destination_metadata.get("case_index", -1)
			var parent_command = destination_metadata.get("parent_command")
			if case_index >= 0 and parent_command is SwitchCommand:
				# Encontrar el comando en la página duplicada por su índice
				var cmd_index = -1
				var original_page = _get_page(page_index)
				if original_page:
					for i in range(original_page.commands.size()):
						if original_page.commands[i] == parent_command:
							cmd_index = i
							break

				if cmd_index >= 0 and cmd_index < editable_page.commands.size():
					var cmd = editable_page.commands[cmd_index]
					if cmd is SwitchCommand:
						var switch_cmd = cmd as SwitchCommand
						if case_index >= 0 and case_index < switch_cmd.cases.size():
							var switch_case = switch_cmd.cases[case_index]
							# Crear un nuevo array para evitar el error de "read-only"
							var new_commands_array: Array[EventCommand] = []
							for existing_cmd in switch_case.commands:
								new_commands_array.append(existing_cmd)
							new_commands_array.append(new_command)
							switch_case.commands = new_commands_array
							event_node.pages[page_index] = editable_page
							_mark_as_changed()
							_refresh_commands_tree_and_select_new(page_index, editable_page, new_command)
							return

		elif dest_type == "default_commands":
			var parent_command = destination_metadata.get("parent_command")
			if parent_command is SwitchCommand:
				# Encontrar el comando en la página duplicada
				var cmd_index = -1
				for i in range(editable_page.commands.size()):
					if editable_page.commands[i] == parent_command:
						cmd_index = i
						break

				if cmd_index >= 0 and cmd_index < editable_page.commands.size():
					var cmd = editable_page.commands[cmd_index]
					if cmd is SwitchCommand:
						var switch_cmd = cmd as SwitchCommand
						# Crear un nuevo array para evitar el error de "read-only"
						var new_commands_array: Array[EventCommand] = []
						for existing_cmd in switch_cmd.default_commands:
							new_commands_array.append(existing_cmd)
						new_commands_array.append(new_command)
						switch_cmd.default_commands = new_commands_array
						event_node.pages[page_index] = editable_page
						_mark_as_changed()
						_refresh_commands_tree_and_select_new(page_index, editable_page, new_command)
						return

	# Si no hay destino o no se pudo añadir al destino, añadir al nivel raíz
	var new_commands_array: Array[EventCommand] = []
	for cmd in editable_page.commands:
		new_commands_array.append(cmd)
	new_commands_array.append(new_command)

	editable_page.set("commands", new_commands_array)
	event_node.pages[page_index] = editable_page
	_mark_as_changed()
	_refresh_commands_tree_and_select_new(page_index, editable_page, new_command)

	print("Event Editor: Comando ", command_type_name, " añadido")

## Refresca el árbol de comandos y selecciona el nuevo comando añadido
func _refresh_commands_tree_and_select_new(page_index: int, page: EventPage, new_command: EventCommand) -> void:
	var commands_tree = _get_commands_tree_for_page(page_index)
	if not commands_tree:
		return

	_update_commands_tree(commands_tree, page, page_index)

	# Buscar y seleccionar el nuevo comando en el árbol, y abrir el editor
	# Pasar is_new_command = true para que se pueda cancelar
	call_deferred("_select_and_open_command_editor", commands_tree, new_command, page_index, true)

## Selecciona un comando en el árbol recursivamente
func _select_command_in_tree(tree: Tree, target_command: EventCommand) -> void:
	if not tree or not target_command:
		return

	var root = tree.get_root()
	if not root:
		return

	_select_command_recursive(tree, root, target_command)

## Selecciona un comando en el árbol y abre su editor
## Si is_new_command es true, se pasa como comando nuevo para que se pueda cancelar
func _select_and_open_command_editor(tree: Tree, target_command: EventCommand, page_index: int, is_new_command: bool = false) -> void:
	if not tree or not target_command:
		return

	var root = tree.get_root()
	if not root:
		return

	var selected_item = _find_command_item_recursive(tree, root, target_command)
	if selected_item:
		tree.set_selected(selected_item, 0)

		# Si es un comando nuevo, abrir el editor directamente con is_new_command = true
		if is_new_command:
			var page = _get_page(page_index)
			if page:
				# Buscar el índice del comando en la página
				var command_index = -1
				for i in range(page.commands.size()):
					if page.commands[i] == target_command:
						command_index = i
						break

				# Abrir el editor específico según el tipo de comando
				if target_command is ShowMessageCommand:
					_open_show_message_editor(target_command, page_index, true, command_index)
				elif target_command is SetFlagCommand:
					_open_set_flag_editor(target_command, page_index, true, command_index)
				elif target_command is SetVariableCommand:
					_open_set_variable_editor(target_command, page_index, true, command_index)
				elif target_command is SetSelfSwitchCommand:
					_open_set_self_switch_editor(target_command, page_index, true, command_index)
				elif target_command is StartBattleEventCommand:
					_open_start_battle_event_editor(target_command, page_index, true, command_index)
				elif target_command is WarpCommand:
					_open_warp_editor(target_command, page_index, true, command_index)
				elif target_command is WaitCommand:
					_open_wait_editor(target_command, page_index, true, command_index)
				elif target_command is FadeCommand:
					_open_fade_editor(target_command, page_index, true, command_index)
				elif target_command is SetWeatherCommand:
					_open_set_weather_editor(target_command, page_index, true, command_index)
				elif target_command is SetDarknessCommand:
					_open_set_darkness_editor(target_command, page_index, true, command_index)
				elif target_command is SetFlashlightCommand:
					_open_set_flashlight_editor(target_command, page_index, true, command_index)
				elif target_command is SetEventThroughCommand:
					_open_set_event_through_editor(target_command, page_index, true, command_index)
				elif target_command is SetActorVisibilityCommand:
					_open_set_actor_visibility_editor(target_command, page_index, true, command_index)
				elif target_command is ShowPortraitCommand:
					_open_show_portrait_editor(target_command, page_index, true, command_index)
				elif target_command is FollowActorCommand:
					_open_follow_actor_editor(target_command, page_index, true, command_index)
				elif target_command is UseMOCommand:
					_open_use_mo_editor(target_command, page_index, true, command_index)
				elif target_command is PlayAnimationCommand:
					_open_play_animation_editor(target_command, page_index, true, command_index)
				elif target_command is MoveNPCCommand:
					_open_move_npc_editor(target_command, page_index, true, command_index)
				elif target_command is SetTriggerCommand:
					_open_set_trigger_editor(target_command, page_index, true, command_index)
				elif target_command is ConditionalCommand:
					_open_conditional_editor(target_command, page_index, true, command_index)
				elif target_command is SwitchCommand:
					_open_switch_editor(target_command, page_index, true, command_index)
				elif target_command is ShowChoicesCommand:
					_open_show_choices_editor(target_command, page_index, true, command_index)
		else:
			# Abrir el editor del comando (modo edición normal)
			_on_edit_command_pressed(page_index)

## Busca recursivamente un comando en el árbol y devuelve el TreeItem
func _find_command_item_recursive(tree: Tree, item: TreeItem, target_command: EventCommand) -> TreeItem:
	if not item or not tree:
		return null

	var metadata = item.get_metadata(0)
	if metadata and metadata.has("command"):
		if metadata.get("command") == target_command:
			return item

	# Buscar en los hijos
	var child = item.get_first_child()
	while child:
		var found = _find_command_item_recursive(tree, child, target_command)
		if found:
			return found
		child = child.get_next()

	return null

## Busca recursivamente un comando en el árbol y lo selecciona
func _select_command_recursive(tree: Tree, item: TreeItem, target_command: EventCommand) -> bool:
	if not item or not tree:
		return false

	var metadata = item.get_metadata(0)
	if metadata and metadata.has("command"):
		if metadata.get("command") == target_command:
			tree.set_selected(item, 0)
			return true

	# Buscar en los hijos
	var child = item.get_first_child()
	while child:
		if _select_command_recursive(tree, child, target_command):
			return true
		child = child.get_next()

	return false

## Selecciona el último branch y abre el editor de condiciones
func _select_and_open_branch_editor(commands_tree: Tree, cmd_index: int, item_type: String, branch: EventBranch, conditional_cmd: ConditionalCommand, page_index: int) -> void:
	if not commands_tree:
		return

	var main_command_item = commands_tree.get_root()
	if not main_command_item:
		return

	var current = main_command_item.get_first_child()
	while current:
		var cmd_meta = current.get_metadata(0)
		if cmd_meta and cmd_meta.type == "command" and cmd_meta.index == cmd_index:
			# Encontrar el último branch
			var last_item = null
			var child = current.get_first_child()
			while child:
				var child_meta = child.get_metadata(0)
				if child_meta and child_meta.type == item_type:
					last_item = child
				child = child.get_next()

			if last_item:
				commands_tree.set_selected(last_item, 0)
				# Abrir el editor de condiciones
				_open_condition_editor_for_branch(branch, conditional_cmd, page_index)
			break
		current = current.get_next()

## Selecciona el último case y abre el editor de valores
func _select_and_open_case_editor(commands_tree: Tree, cmd_index: int, item_type: String, switch_case: SwitchCase, switch_cmd: SwitchCommand, page_index: int) -> void:
	if not commands_tree:
		return

	var main_command_item = commands_tree.get_root()
	if not main_command_item:
		return

	var current = main_command_item.get_first_child()
	while current:
		var cmd_meta = current.get_metadata(0)
		if cmd_meta and cmd_meta.type == "command" and cmd_meta.index == cmd_index:
			# Encontrar el último case
			var last_item = null
			var child = current.get_first_child()
			while child:
				var child_meta = child.get_metadata(0)
				if child_meta and child_meta.type == item_type:
					last_item = child
				child = child.get_next()

			if last_item:
				commands_tree.set_selected(last_item, 0)
				# Abrir el editor de valores
				_open_switch_case_values_editor(switch_case, switch_cmd, page_index)
			break
		current = current.get_next()

## Selecciona el último choice branch y abre el editor
func _select_and_open_choice_editor(commands_tree: Tree, cmd_index: int, item_type: String, branch: ChoiceBranch, show_choices_cmd: ShowChoicesCommand, page_index: int) -> void:
	if not commands_tree:
		return

	var main_command_item = commands_tree.get_root()
	if not main_command_item:
		return

	var current = main_command_item.get_first_child()
	while current:
		var cmd_meta = current.get_metadata(0)
		if cmd_meta and cmd_meta.type == "command" and cmd_meta.index == cmd_index:
			# Encontrar el último choice branch
			var last_item = null
			var child = current.get_first_child()
			while child:
				var child_meta = child.get_metadata(0)
				if child_meta and child_meta.type == item_type:
					last_item = child
				child = child.get_next()

			if last_item:
				commands_tree.set_selected(last_item, 0)
				# Abrir el editor de choice branch
				_open_choice_branch_editor(branch, show_choices_cmd, page_index)
			break
		current = current.get_next()

# === FUNCIONES AUXILIARES ===
## Encuentra el índice de un TreeItem dentro de su padre, contando solo items del tipo especificado
func _find_item_index_in_tree(item: TreeItem, parent: TreeItem, item_type: String) -> int:
	if not item or not parent:
		return -1

	var current = parent.get_first_child()
	var count = 0
	while current:
		if current == item:
			return count
		var current_meta = current.get_metadata(0)
		if current_meta and current_meta.type == item_type:
			count += 1
		current = current.get_next()
	return -1

## Obtiene el comando principal (TreeItem con type="command") desde un TreeItem hijo
func _get_main_command_item_from_tree(item: TreeItem, commands_tree: Tree) -> TreeItem:
	if not item or not commands_tree:
		return null

	var current = item
	while current and current != commands_tree.get_root():
		var cmd_meta = current.get_metadata(0)
		if cmd_meta and cmd_meta.has("type") and cmd_meta.type == "command":
			return current
		current = current.get_parent()
	return null

## Obtiene el índice del branch/case desde un parent_item
func _get_branch_or_case_index(parent_item: TreeItem, parent_type: String) -> Dictionary:
	var result = {"branch_index": -1, "case_index": -1}
	if not parent_item:
		return result

	var command_item = parent_item.get_parent()
	if not command_item:
		return result

	var current = command_item.get_first_child()
	var count = 0
	while current:
		if current == parent_item:
			if parent_type == "branch":
				result.branch_index = count
			elif parent_type == "choice_branch":
				result.branch_index = count
			elif parent_type == "switch_case":
				result.case_index = count
			break
		var current_meta = current.get_metadata(0)
		if current_meta and current_meta.type == parent_type:
			count += 1
		current = current.get_next()
	return result

## Busca recursivamente un comando en toda la estructura de la página
## Retorna un Dictionary con información sobre la ubicación del comando:
## {"found": bool, "is_root": bool, "root_index": int, "parent_command": EventCommand, "parent_type": String, "branch_index": int, "case_index": int, "path": Array}
## path es un array de {"type": String, "index": int} que describe la ruta desde la raíz hasta el comando
func _find_command_location_in_page(page: EventPage, target_command: EventCommand) -> Dictionary:
	var result = {
		"found": false,
		"is_root": false,
		"root_index": -1,
		"parent_command": null,
		"parent_type": "",
		"branch_index": -1,
		"case_index": -1
	}

	if not page or not target_command:
		return result

	# Buscar en el nivel raíz primero (comparar por referencia)
	for i in range(page.commands.size()):
		if page.commands[i] == target_command:
			result.found = true
			result.is_root = true
			result.root_index = i
			result.path = [{"type": "root", "index": i}]
			return result

	# Si no se encontró por referencia, buscar por propiedades (útil después de duplicar)
	for i in range(page.commands.size()):
		if _commands_match_by_properties(page.commands[i], target_command):
			result.found = true
			result.is_root = true
			result.root_index = i
			result.path = [{"type": "root", "index": i}]
			return result

	# Buscar recursivamente en branches/cases (comparar por referencia primero)
	for i in range(page.commands.size()):
		var cmd = page.commands[i]
		var nested_result = _find_command_in_nested_structure(cmd, target_command, cmd, [{"type": "root", "index": i}])
		if nested_result.found:
			result = nested_result
			result.root_index = i
			return result

	# Si no se encontró por referencia, buscar recursivamente por propiedades
	for i in range(page.commands.size()):
		var cmd = page.commands[i]
		# Buscar recursivamente comparando por propiedades
		var nested_result = _find_command_in_nested_structure_by_properties(cmd, target_command, cmd, [{"type": "root", "index": i}])
		if nested_result.found:
			result = nested_result
			result.root_index = i
			return result

	return result

## Busca recursivamente un comando en la estructura anidada de un comando
## path es la ruta acumulada desde la raíz hasta este punto
func _find_command_in_nested_structure(main_command: EventCommand, target_command: EventCommand, parent_command: EventCommand, path: Array = []) -> Dictionary:
	var result = {
		"found": false,
		"is_root": false,
		"root_index": -1,
		"parent_command": parent_command,
		"parent_type": "",
		"branch_index": -1,
		"case_index": -1,
		"path": []
	}

	if not main_command or not target_command:
		return result

	# Buscar en branches de ConditionalCommand
	if main_command is ConditionalCommand:
		var cond_cmd = main_command as ConditionalCommand
		for branch_idx in range(cond_cmd.branches.size()):
			var branch = cond_cmd.branches[branch_idx]
			for nested_cmd in branch.commands:
				var new_path = path.duplicate()
				new_path.append({"type": "branch", "index": branch_idx, "command_index": branch.commands.find(nested_cmd)})
				if nested_cmd == target_command:
					result.found = true
					result.parent_type = "branch"
					result.branch_index = branch_idx
					result.parent_command = main_command
					result.path = new_path
					return result
				# Buscar recursivamente en comandos anidados
				var deeper_result = _find_command_in_nested_structure(nested_cmd, target_command, nested_cmd, new_path)
				if deeper_result.found:
					# Si encontramos el comando más profundo, actualizar el parent_command
					deeper_result.parent_command = nested_cmd
					return deeper_result

	# Buscar en branches de ShowChoicesCommand
	elif main_command is ShowChoicesCommand:
		var choices_cmd = main_command as ShowChoicesCommand
		for branch_idx in range(choices_cmd.branches.size()):
			var branch = choices_cmd.branches[branch_idx]
			for nested_cmd in branch.commands:
				var new_path = path.duplicate()
				new_path.append({"type": "choice_branch", "index": branch_idx, "command_index": branch.commands.find(nested_cmd)})
				if nested_cmd == target_command:
					result.found = true
					result.parent_type = "choice_branch"
					result.branch_index = branch_idx
					result.parent_command = main_command
					result.path = new_path
					return result
				# Buscar recursivamente en comandos anidados
				var deeper_result = _find_command_in_nested_structure(nested_cmd, target_command, nested_cmd, new_path)
				if deeper_result.found:
					# Si encontramos el comando más profundo, actualizar el parent_command
					deeper_result.parent_command = nested_cmd
					return deeper_result

	# Buscar en cases de SwitchCommand
	elif main_command is SwitchCommand:
		var switch_cmd = main_command as SwitchCommand
		for case_idx in range(switch_cmd.cases.size()):
			var switch_case = switch_cmd.cases[case_idx]
			for nested_cmd in switch_case.commands:
				var new_path = path.duplicate()
				new_path.append({"type": "switch_case", "index": case_idx, "command_index": switch_case.commands.find(nested_cmd)})
				if nested_cmd == target_command:
					result.found = true
					result.parent_type = "switch_case"
					result.case_index = case_idx
					result.parent_command = main_command
					result.path = new_path
					return result
				# Buscar recursivamente en comandos anidados
				var deeper_result = _find_command_in_nested_structure(nested_cmd, target_command, nested_cmd, new_path)
				if deeper_result.found:
					# Si encontramos el comando más profundo, actualizar el parent_command
					deeper_result.parent_command = nested_cmd
					return deeper_result

		# Buscar en default_commands
		for nested_cmd in switch_cmd.default_commands:
			var new_path = path.duplicate()
			new_path.append({"type": "default_commands", "index": -1, "command_index": switch_cmd.default_commands.find(nested_cmd)})
			if nested_cmd == target_command:
				result.found = true
				result.parent_type = "default_commands"
				result.parent_command = main_command
				result.path = new_path
				return result
			# Buscar recursivamente en comandos anidados
			var deeper_result = _find_command_in_nested_structure(nested_cmd, target_command, nested_cmd, new_path)
			if deeper_result.found:
				# Si encontramos el comando más profundo, actualizar el parent_command
				deeper_result.parent_command = nested_cmd
				return deeper_result

	return result

## Busca recursivamente un comando en la estructura anidada comparando por propiedades
func _find_command_in_nested_structure_by_properties(main_command: EventCommand, target_command: EventCommand, parent_command: EventCommand, path: Array = []) -> Dictionary:
	var result = {
		"found": false,
		"is_root": false,
		"root_index": -1,
		"parent_command": parent_command,
		"parent_type": "",
		"branch_index": -1,
		"case_index": -1,
		"path": []
	}

	if not main_command or not target_command:
		return result

	# Buscar en branches de ConditionalCommand
	if main_command is ConditionalCommand:
		var cond_cmd = main_command as ConditionalCommand
		for branch_idx in range(cond_cmd.branches.size()):
			var branch = cond_cmd.branches[branch_idx]
			for nested_cmd in branch.commands:
				var new_path = path.duplicate()
				new_path.append({"type": "branch", "index": branch_idx, "command_index": branch.commands.find(nested_cmd)})
				if _commands_match_by_properties(nested_cmd, target_command):
					result.found = true
					result.parent_type = "branch"
					result.branch_index = branch_idx
					result.parent_command = main_command
					result.path = new_path
					return result
				# Buscar recursivamente en comandos anidados
				var deeper_result = _find_command_in_nested_structure_by_properties(nested_cmd, target_command, nested_cmd, new_path)
				if deeper_result.found:
					deeper_result.parent_command = nested_cmd
					return deeper_result

	# Buscar en branches de ShowChoicesCommand
	elif main_command is ShowChoicesCommand:
		var choices_cmd = main_command as ShowChoicesCommand
		for branch_idx in range(choices_cmd.branches.size()):
			var branch = choices_cmd.branches[branch_idx]
			for nested_cmd in branch.commands:
				var new_path = path.duplicate()
				new_path.append({"type": "choice_branch", "index": branch_idx, "command_index": branch.commands.find(nested_cmd)})
				if _commands_match_by_properties(nested_cmd, target_command):
					result.found = true
					result.parent_type = "choice_branch"
					result.branch_index = branch_idx
					result.parent_command = main_command
					result.path = new_path
					return result
				# Buscar recursivamente en comandos anidados
				var deeper_result = _find_command_in_nested_structure_by_properties(nested_cmd, target_command, nested_cmd, new_path)
				if deeper_result.found:
					deeper_result.parent_command = nested_cmd
					return deeper_result

	# Buscar en cases de SwitchCommand
	elif main_command is SwitchCommand:
		var switch_cmd = main_command as SwitchCommand
		for case_idx in range(switch_cmd.cases.size()):
			var switch_case = switch_cmd.cases[case_idx]
			for nested_cmd in switch_case.commands:
				var new_path = path.duplicate()
				new_path.append({"type": "switch_case", "index": case_idx, "command_index": switch_case.commands.find(nested_cmd)})
				if _commands_match_by_properties(nested_cmd, target_command):
					result.found = true
					result.parent_type = "switch_case"
					result.case_index = case_idx
					result.parent_command = main_command
					result.path = new_path
					return result
				# Buscar recursivamente en comandos anidados
				var deeper_result = _find_command_in_nested_structure_by_properties(nested_cmd, target_command, nested_cmd, new_path)
				if deeper_result.found:
					deeper_result.parent_command = nested_cmd
					return deeper_result

		# Buscar en default_commands
		for nested_cmd in switch_cmd.default_commands:
			var new_path = path.duplicate()
			new_path.append({"type": "default_commands", "index": -1, "command_index": switch_cmd.default_commands.find(nested_cmd)})
			if _commands_match_by_properties(nested_cmd, target_command):
				result.found = true
				result.parent_type = "default_commands"
				result.parent_command = main_command
				result.path = new_path
				return result
			# Buscar recursivamente en comandos anidados
			var deeper_result = _find_command_in_nested_structure_by_properties(nested_cmd, target_command, nested_cmd, new_path)
			if deeper_result.found:
				deeper_result.parent_command = nested_cmd
				return deeper_result

	return result

## Obtiene un comando anidado usando la información de ubicación
## Navega usando la ruta (path) guardada en location para encontrar el comando exacto
func _get_nested_command_from_location(page: EventPage, location: Dictionary) -> EventCommand:
	if not page or not location or not location.found:
		return null

	# Si está en el nivel raíz, retornar directamente
	if location.is_root:
		if location.root_index >= 0 and location.root_index < page.commands.size():
			return page.commands[location.root_index]
		return null

	# Si está anidado, navegar usando la ruta (path) guardada en location
	var path = location.get("path", [])
	if path.is_empty():
		# Fallback: usar el método anterior si no hay path
		return _get_nested_command_from_location_fallback(page, location)

	# Navegar por la ruta
	var current_cmd = null
	if path.size() > 0 and path[0].type == "root":
		var root_idx = path[0].index
		if root_idx >= 0 and root_idx < page.commands.size():
			current_cmd = page.commands[root_idx]
		else:
			return null
	else:
		return null

	# Navegar por el resto de la ruta
	for i in range(1, path.size()):
		var step = path[i]
		if not current_cmd:
			return null

		if step.type == "choice_branch" and current_cmd is ShowChoicesCommand:
			var choices_cmd = current_cmd as ShowChoicesCommand
			var branch_idx = step.index
			if branch_idx >= 0 and branch_idx < choices_cmd.branches.size():
				var branch = choices_cmd.branches[branch_idx]
				var cmd_idx = step.get("command_index", -1)
				if cmd_idx >= 0 and cmd_idx < branch.commands.size():
					current_cmd = branch.commands[cmd_idx]
				else:
					# Si no hay command_index, el comando buscado es el ShowChoicesCommand mismo
					return choices_cmd
			else:
				return null
		elif step.type == "branch" and current_cmd is ConditionalCommand:
			var cond_cmd = current_cmd as ConditionalCommand
			var branch_idx = step.index
			if branch_idx >= 0 and branch_idx < cond_cmd.branches.size():
				var branch = cond_cmd.branches[branch_idx]
				var cmd_idx = step.get("command_index", -1)
				if cmd_idx >= 0 and cmd_idx < branch.commands.size():
					current_cmd = branch.commands[cmd_idx]
				else:
					return cond_cmd
			else:
				return null
		elif step.type == "switch_case" and current_cmd is SwitchCommand:
			var switch_cmd = current_cmd as SwitchCommand
			var case_idx = step.index
			if case_idx >= 0 and case_idx < switch_cmd.cases.size():
				var switch_case = switch_cmd.cases[case_idx]
				var cmd_idx = step.get("command_index", -1)
				if cmd_idx >= 0 and cmd_idx < switch_case.commands.size():
					current_cmd = switch_case.commands[cmd_idx]
				else:
					return switch_cmd
			else:
				return null

	return current_cmd

## Método fallback para obtener comando cuando no hay path disponible
func _get_nested_command_from_location_fallback(page: EventPage, location: Dictionary) -> EventCommand:
	if location.root_index >= 0 and location.root_index < page.commands.size():
		var root_cmd = page.commands[location.root_index]
		var original_parent = location.get("parent_command")

		if not original_parent:
			return null

		# Si el parent_command es el mismo que el root_cmd, retornarlo directamente
		if location.parent_type == "choice_branch" and root_cmd is ShowChoicesCommand:
			var choices_cmd = root_cmd as ShowChoicesCommand
			if original_parent is ShowChoicesCommand:
				var orig_sc = original_parent as ShowChoicesCommand
				if choices_cmd.message == orig_sc.message and choices_cmd.branches.size() == orig_sc.branches.size():
					var labels_match = true
					for i in range(min(choices_cmd.branches.size(), orig_sc.branches.size())):
						if choices_cmd.branches[i].label != orig_sc.branches[i].label:
							labels_match = false
							break
					if labels_match:
						return choices_cmd

		# Buscar recursivamente
		return _find_command_by_navigation(root_cmd, original_parent, location)

	return null

## Busca un comando navegando recursivamente por la estructura usando comparación de propiedades
func _find_command_by_navigation(root_cmd: EventCommand, target_command: EventCommand, location: Dictionary) -> EventCommand:
	if not root_cmd or not target_command:
		return null

	# Comparar el root_cmd con el target_command
	if _commands_match_by_properties(root_cmd, target_command):
		return root_cmd

	# Buscar recursivamente en la estructura anidada
	if root_cmd is ConditionalCommand:
		var cond_cmd = root_cmd as ConditionalCommand
		for branch in cond_cmd.branches:
			for nested_cmd in branch.commands:
				if _commands_match_by_properties(nested_cmd, target_command):
					return nested_cmd
				# Buscar recursivamente
				var deeper = _find_command_by_navigation(nested_cmd, target_command, location)
				if deeper:
					return deeper
	elif root_cmd is ShowChoicesCommand:
		var choices_cmd = root_cmd as ShowChoicesCommand
		for branch in choices_cmd.branches:
			for nested_cmd in branch.commands:
				if _commands_match_by_properties(nested_cmd, target_command):
					return nested_cmd
				# Buscar recursivamente
				var deeper = _find_command_by_navigation(nested_cmd, target_command, location)
				if deeper:
					return deeper
	elif root_cmd is SwitchCommand:
		var switch_cmd = root_cmd as SwitchCommand
		for switch_case in switch_cmd.cases:
			for nested_cmd in switch_case.commands:
				if _commands_match_by_properties(nested_cmd, target_command):
					return nested_cmd
				# Buscar recursivamente
				var deeper = _find_command_by_navigation(nested_cmd, target_command, location)
				if deeper:
					return deeper
		for nested_cmd in switch_cmd.default_commands:
			if _commands_match_by_properties(nested_cmd, target_command):
				return nested_cmd
			# Buscar recursivamente
			var deeper = _find_command_by_navigation(nested_cmd, target_command, location)
			if deeper:
				return deeper

	return null

## Compara dos comandos por propiedades en lugar de referencia
func _commands_match_by_properties(cmd1: EventCommand, cmd2: EventCommand) -> bool:
	if not cmd1 or not cmd2:
		return false

	# Comparar por tipo de clase
	if cmd1.get_script() != cmd2.get_script():
		return false

	# Para ShowChoicesCommand, comparar por propiedades clave
	if cmd1 is ShowChoicesCommand and cmd2 is ShowChoicesCommand:
		var sc1 = cmd1 as ShowChoicesCommand
		var sc2 = cmd2 as ShowChoicesCommand
		if sc1.message != sc2.message or sc1.branches.size() != sc2.branches.size():
			return false
		# Comparar labels de branches
		for i in range(sc1.branches.size()):
			if sc1.branches[i].label != sc2.branches[i].label:
				return false
		return true

	# Para ShowMessageCommand, comparar por mensaje
	if cmd1 is ShowMessageCommand and cmd2 is ShowMessageCommand:
		var sm1 = cmd1 as ShowMessageCommand
		var sm2 = cmd2 as ShowMessageCommand
		return sm1.message == sm2.message

	# Para otros comandos del mismo tipo, considerarlos iguales si están en la misma posición
	# Esto es una aproximación - en la práctica, si dos comandos del mismo tipo están en la misma posición,
	# probablemente son el mismo comando
	return true

## Busca recursivamente un comando dentro de una estructura anidada
func _find_command_recursive_in_structure(root_cmd: EventCommand, target_command: EventCommand) -> EventCommand:
	if not root_cmd or not target_command:
		return null

	# Si el comando buscado es el mismo que el root, retornarlo
	if root_cmd == target_command:
		return root_cmd

	# Buscar recursivamente en la estructura anidada
	if root_cmd is ConditionalCommand:
		var cond_cmd = root_cmd as ConditionalCommand
		for branch in cond_cmd.branches:
			for nested_cmd in branch.commands:
				if nested_cmd == target_command:
					return nested_cmd
				# Buscar recursivamente en comandos anidados
				var deeper_result = _find_command_recursive_in_structure(nested_cmd, target_command)
				if deeper_result:
					return deeper_result
	elif root_cmd is ShowChoicesCommand:
		var choices_cmd = root_cmd as ShowChoicesCommand
		# Si el comando buscado es este mismo ShowChoicesCommand
		if choices_cmd == target_command:
			return choices_cmd
		# Buscar en los branches
		for branch in choices_cmd.branches:
			for nested_cmd in branch.commands:
				if nested_cmd == target_command:
					return nested_cmd
				# Buscar recursivamente en comandos anidados
				var deeper_result = _find_command_recursive_in_structure(nested_cmd, target_command)
				if deeper_result:
					return deeper_result
	elif root_cmd is SwitchCommand:
		var switch_cmd = root_cmd as SwitchCommand
		# Si el comando buscado es este mismo SwitchCommand
		if switch_cmd == target_command:
			return switch_cmd
		# Buscar en los cases
		for switch_case in switch_cmd.cases:
			for nested_cmd in switch_case.commands:
				if nested_cmd == target_command:
					return nested_cmd
				# Buscar recursivamente en comandos anidados
				var deeper_result = _find_command_recursive_in_structure(nested_cmd, target_command)
				if deeper_result:
					return deeper_result
		# Buscar en default_commands
		for nested_cmd in switch_cmd.default_commands:
			if nested_cmd == target_command:
				return nested_cmd
			# Buscar recursivamente en comandos anidados
			var deeper_result = _find_command_recursive_in_structure(nested_cmd, target_command)
			if deeper_result:
				return deeper_result

	return null

## Obtiene el array de comandos de un branch/case según el tipo y los índices
func _get_commands_array_from_branch_case(main_command: EventCommand, parent_type: String, branch_index: int, case_index: int) -> Array:
	if parent_type == "branch" and main_command is ConditionalCommand:
		var cond_cmd = main_command as ConditionalCommand
		if branch_index >= 0 and branch_index < cond_cmd.branches.size():
			return cond_cmd.branches[branch_index].commands
	elif parent_type == "choice_branch" and main_command is ShowChoicesCommand:
		var choices_cmd = main_command as ShowChoicesCommand
		if branch_index >= 0 and branch_index < choices_cmd.branches.size():
			return choices_cmd.branches[branch_index].commands
	elif parent_type == "switch_case" and main_command is SwitchCommand:
		var switch_cmd = main_command as SwitchCommand
		if case_index >= 0 and case_index < switch_cmd.cases.size():
			return switch_cmd.cases[case_index].commands
	elif parent_type == "default_commands" and main_command is SwitchCommand:
		var switch_cmd = main_command as SwitchCommand
		return switch_cmd.default_commands
	return []

## Añade un comando a un branch/case de forma segura (crea nuevo array si es necesario)
func _add_command_to_branch_case(main_command: EventCommand, parent_type: String, branch_index: int, case_index: int, command: EventCommand) -> bool:
	if not command:
		return false

	var commands_array: Array[EventCommand] = []
	if parent_type == "branch" and main_command is ConditionalCommand:
		var cond_cmd = main_command as ConditionalCommand
		if branch_index >= 0 and branch_index < cond_cmd.branches.size():
			var branch = cond_cmd.branches[branch_index]
			# Crear un nuevo array para evitar el error de "read-only"
			for existing_cmd in branch.commands:
				if existing_cmd is EventCommand:
					commands_array.append(existing_cmd as EventCommand)
			if command is EventCommand:
				commands_array.append(command as EventCommand)
			branch.commands = commands_array
			return true
	elif parent_type == "choice_branch" and main_command is ShowChoicesCommand:
		var choices_cmd = main_command as ShowChoicesCommand
		if branch_index >= 0 and branch_index < choices_cmd.branches.size():
			var branch = choices_cmd.branches[branch_index]
			# Crear un nuevo array para evitar el error de "read-only"
			for existing_cmd in branch.commands:
				if existing_cmd is EventCommand:
					commands_array.append(existing_cmd as EventCommand)
			if command is EventCommand:
				commands_array.append(command as EventCommand)
			branch.commands = commands_array
			return true
	elif parent_type == "switch_case" and main_command is SwitchCommand:
		var switch_cmd = main_command as SwitchCommand
		if case_index >= 0 and case_index < switch_cmd.cases.size():
			var switch_case = switch_cmd.cases[case_index]
			# Crear un nuevo array para evitar el error de "read-only"
			for existing_cmd in switch_case.commands:
				if existing_cmd is EventCommand:
					commands_array.append(existing_cmd as EventCommand)
			if command is EventCommand:
				commands_array.append(command as EventCommand)
			switch_case.commands = commands_array
			return true
	elif parent_type == "default_commands" and main_command is SwitchCommand:
		var switch_cmd = main_command as SwitchCommand
		# Crear un nuevo array para evitar el error de "read-only"
		for existing_cmd in switch_cmd.default_commands:
			if existing_cmd is EventCommand:
				commands_array.append(existing_cmd as EventCommand)
		if command is EventCommand:
			commands_array.append(command as EventCommand)
		switch_cmd.default_commands = commands_array
		return true
	return false

## Modifica el array de comandos de un branch/case según el tipo y los índices
func _set_commands_array_to_branch_case(main_command: EventCommand, parent_type: String, branch_index: int, case_index: int, commands: Array) -> bool:
	if parent_type == "branch" and main_command is ConditionalCommand:
		var cond_cmd = main_command as ConditionalCommand
		if branch_index >= 0 and branch_index < cond_cmd.branches.size():
			cond_cmd.branches[branch_index].commands = commands
			return true
	elif parent_type == "choice_branch" and main_command is ShowChoicesCommand:
		var choices_cmd = main_command as ShowChoicesCommand
		if branch_index >= 0 and branch_index < choices_cmd.branches.size():
			choices_cmd.branches[branch_index].commands = commands
			return true
	elif parent_type == "switch_case" and main_command is SwitchCommand:
		var switch_cmd = main_command as SwitchCommand
		if case_index >= 0 and case_index < switch_cmd.cases.size():
			switch_cmd.cases[case_index].commands = commands
			return true
	elif parent_type == "default_commands" and main_command is SwitchCommand:
		var switch_cmd = main_command as SwitchCommand
		switch_cmd.default_commands = commands
		return true
	return false

## Selecciona un branch/case duplicado en el árbol
func _select_duplicated_branch_case(commands_tree: Tree, item_type: String, item_index: int) -> void:
	if not commands_tree:
		return

	var selected_item = commands_tree.get_selected()
	if not selected_item:
		return

	var parent_item = selected_item.get_parent()
	if not parent_item:
		return

	var main_command_item = _get_main_command_item_from_tree(parent_item, commands_tree)
	if not main_command_item:
		return

	var current = main_command_item.get_first_child()
	var count = 0
	while current:
		var current_meta = current.get_metadata(0)
		if current_meta and current_meta.type == item_type:
			if count == item_index:
				commands_tree.set_selected(current, 0)
				break
			count += 1
		current = current.get_next()

## Añade un EventBranch a un ConditionalCommand
func _add_branch_to_conditional(page_index: int, conditional_cmd: ConditionalCommand, cmd_index: int) -> void:
	var page = _get_page(page_index)
	if not page:
		return

	var editable_page = page.duplicate(true) as EventPage
	if not editable_page:
		push_error("Event Editor: No se pudo duplicar la página")
		return

	var cmd = editable_page.commands[cmd_index]
	if cmd is ConditionalCommand:
		var cond_cmd = cmd as ConditionalCommand
		var new_branch = EventBranch.new()

		# Crear un nuevo array con el branch añadido
		var new_branches: Array[EventBranch] = []
		for existing_branch in cond_cmd.branches:
			new_branches.append(existing_branch)
		new_branches.append(new_branch)
		cond_cmd.branches = new_branches

		event_node.pages[page_index] = editable_page
		_mark_as_changed()

		# Actualizar árbol y seleccionar el nuevo branch
		var commands_tree = _get_commands_tree_for_page(page_index)
		if commands_tree:
			_update_commands_tree(commands_tree, editable_page, page_index)
			# Seleccionar el nuevo branch y abrir el editor de condiciones
			call_deferred("_select_and_open_branch_editor", commands_tree, cmd_index, "branch", new_branch, cond_cmd, page_index)

		_refresh_inspector()

## Añade un SwitchCase a un SwitchCommand
func _add_case_to_switch(page_index: int, switch_cmd: SwitchCommand, cmd_index: int) -> void:
	var page = _get_page(page_index)
	if not page:
		return

	var editable_page = page.duplicate(true) as EventPage
	if not editable_page:
		push_error("Event Editor: No se pudo duplicar la página")
		return

	var cmd = editable_page.commands[cmd_index]
	if cmd is SwitchCommand:
		var switch_command = cmd as SwitchCommand
		var new_case = SwitchCase.new()

		# Crear un nuevo array con el case añadido
		var new_cases: Array[SwitchCase] = []
		for existing_case in switch_command.cases:
			new_cases.append(existing_case)
		new_cases.append(new_case)
		switch_command.cases = new_cases

		event_node.pages[page_index] = editable_page
		_mark_as_changed()

		# Actualizar árbol y seleccionar el nuevo case
		var commands_tree = _get_commands_tree_for_page(page_index)
		if commands_tree:
			_update_commands_tree(commands_tree, editable_page, page_index)
			# Seleccionar el nuevo case y abrir el editor de valores
			call_deferred("_select_and_open_case_editor", commands_tree, cmd_index, "switch_case", new_case, switch_command, page_index)

		_refresh_inspector()

## Añade un ChoiceBranch a un ShowChoicesCommand
func _add_choice_to_show_choices(page_index: int, choices_cmd: ShowChoicesCommand, cmd_index: int) -> void:
	var page = _get_page(page_index)
	if not page:
		return

	var editable_page = page.duplicate(true) as EventPage
	if not editable_page:
		push_error("Event Editor: No se pudo duplicar la página")
		return

	var cmd = editable_page.commands[cmd_index]
	if cmd is ShowChoicesCommand:
		var show_choices_cmd = cmd as ShowChoicesCommand
		var new_branch = ChoiceBranch.new()
		new_branch.label = "Opción " + str(show_choices_cmd.branches.size() + 1)

		# Crear un nuevo array con el branch añadido
		var new_branches: Array[ChoiceBranch] = []
		for existing_branch in show_choices_cmd.branches:
			new_branches.append(existing_branch)
		new_branches.append(new_branch)
		show_choices_cmd.branches = new_branches

		event_node.pages[page_index] = editable_page
		_mark_as_changed()

		# Actualizar árbol y seleccionar el nuevo branch
		var commands_tree = _get_commands_tree_for_page(page_index)
		if commands_tree:
			_update_commands_tree(commands_tree, editable_page, page_index)
			# Seleccionar el nuevo branch y abrir el editor de choice branch
			call_deferred("_select_and_open_choice_editor", commands_tree, cmd_index, "choice_branch", new_branch, show_choices_cmd, page_index)

		_refresh_inspector()

## Selecciona el último branch/case de un comando
func _select_last_branch_case(commands_tree: Tree, cmd_index: int, item_type: String) -> void:
	if not commands_tree:
		return

	var main_command_item = commands_tree.get_root()
	if not main_command_item:
		return

	var current = main_command_item.get_first_child()
	while current:
		var cmd_meta = current.get_metadata(0)
		if cmd_meta and cmd_meta.type == "command" and cmd_meta.index == cmd_index:
			# Encontrar el último item del tipo especificado
			var last_item = null
			var child = current.get_first_child()
			while child:
				var child_meta = child.get_metadata(0)
				if child_meta and child_meta.type == item_type:
					last_item = child
				child = child.get_next()

			if last_item:
				commands_tree.set_selected(last_item, 0)
			break
		current = current.get_next()

# === UTILIDADES ===
func _update_buttons_state(page_index: int, has_selection: bool, can_move_up: bool = false, can_move_down: bool = false, can_move: bool = false, can_duplicate: bool = false, can_add: bool = false) -> void:
	if not page_index in page_buttons:
		return

	var buttons = page_buttons[page_index]
	var in_move_mode = move_mode_active.get(page_index, false)

	if in_move_mode:
		# En modo mover, mostrar solo aceptar/cancelar
		buttons.add.visible = false
		buttons.edit.visible = false
		buttons.delete.visible = false
		if buttons.has("duplicate"):
			buttons.duplicate.visible = false
		buttons.move_up.visible = false
		buttons.move_down.visible = false
		buttons.move.visible = false
		buttons.accept_move.visible = true
		buttons.cancel_move.visible = true

		# Habilitar aceptar solo si hay un destino seleccionado
		var commands_tree = _get_commands_tree_for_page(page_index)
		var selected_item = commands_tree.get_selected() if commands_tree else null
		var can_accept = false
		if selected_item:
			# Verificar si es la raíz
			var root = commands_tree.get_root() if commands_tree else null
			if root == selected_item:
				# La raíz es válida solo si se mueve un nested_command
				var move_info = command_to_move.get(page_index, {})
				if move_info.has("type") and move_info.type == "nested_command":
					can_accept = true
			else:
				var metadata = selected_item.get_metadata(0)
				if metadata and metadata.has("type"):
					var item_type = metadata.type
					# Destinos válidos: branch, choice_branch, switch_case, default_commands
					can_accept = item_type in ["branch", "choice_branch", "switch_case", "default_commands"]
					# Si es un comando principal y el comando a mover es command (no nested), también es válido
					if item_type == "command":
						var move_info = command_to_move.get(page_index, {})
						if move_info.has("type") and move_info.type == "command":
							# Verificar que el comando puede tener hijos
							var page = _get_page(page_index)
							if page:
								var cmd_index = metadata.get("index", -1)
								if cmd_index >= 0 and cmd_index < page.commands.size():
									var cmd = page.commands[cmd_index]
									if cmd is ConditionalCommand or cmd is ShowChoicesCommand or cmd is SwitchCommand:
										can_accept = true

		buttons.accept_move.disabled = not can_accept
	else:
		# Modo normal
		buttons.add.visible = true
		buttons.edit.visible = true
		buttons.delete.visible = true
		if buttons.has("duplicate"):
			buttons.duplicate.visible = true
		buttons.move_up.visible = true
		buttons.move_down.visible = true
		buttons.move.visible = true
		buttons.accept_move.visible = false
		buttons.cancel_move.visible = false

		buttons.add.disabled = not can_add
		buttons.edit.disabled = not has_selection
		buttons.delete.disabled = not has_selection
		if buttons.has("duplicate"):
			buttons.duplicate.disabled = not can_duplicate
		buttons.move_up.disabled = not can_move_up
		buttons.move_down.disabled = not can_move_down
		buttons.move.disabled = not can_move

func _get_commands_tree_for_page(page_index: int) -> Tree:
	if not tab_container or page_index >= tab_container.get_child_count():
		return null
	return _find_child_by_name(tab_container.get_child(page_index), "CommandsTree", Tree)

func _on_tab_changed(tab_index: int) -> void:
	# Actualizar el estado de los botones de gestión de páginas cuando se cambia de tab
	_update_page_management_buttons_state()

	# Actualizar el label de posición cuando se cambia de tab
	_update_position_label(tab_index)

	# Cuando se cambia de tab, actualizar el estado del modo mover si está activo
	if move_source_page_index >= 0:
		# Estamos en modo mover, actualizar la página actual
		var page = _get_page(tab_index)
		if page:
			var commands_tree = _get_commands_tree_for_page(tab_index)
			if commands_tree:
				# Usar el move_info de la página origen
				var move_info = command_to_move.get(move_source_page_index, {})
				_update_commands_tree(commands_tree, page, tab_index, move_info)

		# Actualizar botones para mostrar aceptar/cancelar
		var commands_tree_after = _get_commands_tree_for_page(tab_index)
		var selected_item = commands_tree_after.get_selected() if commands_tree_after else null
		if selected_item:
			_on_command_selected(tab_index)
		else:
			# No hay selección, pero estamos en modo mover, mostrar botones aceptar/cancelar
			var buttons = page_buttons.get(tab_index, {})
			if buttons.has("accept_move") and buttons.has("cancel_move"):
				buttons.add.visible = false
				buttons.edit.visible = false
				buttons.delete.visible = false
				buttons.move_up.visible = false
				buttons.move_down.visible = false
				buttons.move.visible = false
				buttons.accept_move.visible = true
				buttons.cancel_move.visible = true
				buttons.accept_move.disabled = true  # Sin selección, no se puede aceptar

func _on_close_requested() -> void:
	# Mostrar diálogo de confirmación antes de cancelar
	_show_cancel_confirmation_dialog()

func _refresh_inspector() -> void:
	if not editor_interface or not event_node:
		return

	if event_node.has_method("property_list_changed_notify"):
		event_node.property_list_changed_notify()

	for page in event_node.pages:
		if page and page.has_method("property_list_changed_notify"):
			page.property_list_changed_notify()

	var selection = editor_interface.get_selection()
	if selection and event_node in selection.get_selected_nodes():
		call_deferred("_reselect_node_for_refresh", event_node)

# === EDITORES DE COMANDOS ESPECÍFICOS ===
## Abre el editor para ShowMessageCommand
## is_new_command: true si es un comando nuevo que se está añadiendo, false si se está editando
## command_index: índice del comando en la página (solo relevante si is_new_command es true)
func _open_show_message_editor(command: ShowMessageCommand, page_index: int, is_new_command: bool = false, command_index: int = -1) -> void:
	if not command:
		push_error("Event Editor: No se proporcionó un ShowMessageCommand válido")
		return

	# Cerrar cualquier ventana de edición existente
	if current_command_editor and is_instance_valid(current_command_editor):
		current_command_editor.queue_free()
		current_command_editor = null

	# Esperar un frame para asegurar que la ventana anterior se haya cerrado
	await get_tree().process_frame

	# Cargar el script del editor
	var editor_script = load("res://addons/event_tools/show_message_command_editor.gd")
	if not editor_script:
		push_error("Event Editor: No se encontró el script del editor de ShowMessageCommand")
		return

	# Crear instancia de la ventana usando el script
	var editor_window = editor_script.new()
	if not editor_window:
		push_error("Event Editor: No se pudo crear la instancia del editor")
		return

	add_child(editor_window)
	current_command_editor = editor_window

	# Cargar el comando en el editor
	editor_window.load_command(command)

	# Conectar señales
	editor_window.command_edited.connect(func(cmd: ShowMessageCommand): _on_show_message_command_edited(cmd, page_index))

	# Si es un comando nuevo y se cancela, eliminarlo
	if is_new_command:
		editor_window.cancelled.connect(func():
			_on_new_command_cancelled(page_index, command_index)
			current_command_editor = null
			editor_window.queue_free()
		)
	else:
		editor_window.cancelled.connect(func():
			current_command_editor = null
			editor_window.queue_free()
		)

	# Mostrar la ventana
	editor_window.popup_centered()

## Callback cuando se edita un ShowMessageCommand
func _on_show_message_command_edited(command: ShowMessageCommand, page_index: int) -> void:
	if not command:
		return

	# El comando ya está modificado (se modifica por referencia)
	# Solo necesitamos actualizar el árbol y refrescar el inspector
	_mark_as_changed()
	var page = _get_page(page_index)
	if page:
		var commands_tree = _get_commands_tree_for_page(page_index)
		if commands_tree:
			_update_commands_tree(commands_tree, page, page_index)
			# Deseleccionar el comando y actualizar botones
			commands_tree.deselect_all()
			_update_buttons_state(page_index, false, false, false, false, false)

	_refresh_inspector()

## Abre el editor para SetFlagCommand
## is_new_command: true si es un comando nuevo que se está añadiendo, false si se está editando
## command_index: índice del comando en la página (solo relevante si is_new_command es true)
func _open_set_flag_editor(command: SetFlagCommand, page_index: int, is_new_command: bool = false, command_index: int = -1) -> void:
	if not command:
		push_error("Event Editor: No se proporcionó un SetFlagCommand válido")
		return

	# Cerrar cualquier ventana de edición existente
	if current_command_editor and is_instance_valid(current_command_editor):
		current_command_editor.queue_free()
		current_command_editor = null

	# Esperar un frame para asegurar que la ventana anterior se haya cerrado
	await get_tree().process_frame

	# Cargar el script del editor
	var editor_script = load("res://addons/event_tools/set_flag_command_editor.gd")
	if not editor_script:
		push_error("Event Editor: No se encontró el script del editor de SetFlagCommand")
		return

	# Crear instancia de la ventana usando el script
	var editor_window = editor_script.new()
	if not editor_window:
		push_error("Event Editor: No se pudo crear la instancia del editor")
		return

	add_child(editor_window)
	current_command_editor = editor_window

	# Cargar el comando en el editor
	editor_window.load_command(command)

	# Conectar señales
	editor_window.command_edited.connect(func(cmd: SetFlagCommand): _on_set_flag_command_edited(cmd, page_index))

	# Si es un comando nuevo y se cancela, eliminarlo
	if is_new_command:
		editor_window.cancelled.connect(func():
			_on_new_command_cancelled(page_index, command_index)
			current_command_editor = null
			editor_window.queue_free()
		)
	else:
		editor_window.cancelled.connect(func():
			current_command_editor = null
			editor_window.queue_free()
		)

	# Mostrar la ventana
	editor_window.popup_centered()

## Callback cuando se edita un SetFlagCommand
func _on_set_flag_command_edited(command: SetFlagCommand, page_index: int) -> void:
	if not command:
		return

	# El comando ya está modificado (se modifica por referencia)
	# Solo necesitamos actualizar el árbol y refrescar el inspector
	_mark_as_changed()
	var page = _get_page(page_index)
	if page:
		var commands_tree = _get_commands_tree_for_page(page_index)
		if commands_tree:
			_update_commands_tree(commands_tree, page, page_index)
			# Deseleccionar el comando y actualizar botones
			commands_tree.deselect_all()
			_update_buttons_state(page_index, false, false, false, false, false)

	_refresh_inspector()

## Abre el editor para SetVariableCommand
## is_new_command: true si es un comando nuevo que se está añadiendo, false si se está editando
## command_index: índice del comando en la página (solo relevante si is_new_command es true)
func _open_set_variable_editor(command: SetVariableCommand, page_index: int, is_new_command: bool = false, command_index: int = -1) -> void:
	if not command:
		push_error("Event Editor: No se proporcionó un SetVariableCommand válido")
		return

	# Cerrar cualquier ventana de edición existente
	if current_command_editor and is_instance_valid(current_command_editor):
		current_command_editor.queue_free()
		current_command_editor = null

	# Esperar un frame para asegurar que la ventana anterior se haya cerrado
	await get_tree().process_frame

	# Cargar el script del editor
	var editor_script = load("res://addons/event_tools/set_variable_command_editor.gd")
	if not editor_script:
		push_error("Event Editor: No se encontró el script del editor de SetVariableCommand")
		return

	# Crear instancia de la ventana usando el script
	var editor_window = editor_script.new()
	if not editor_window:
		push_error("Event Editor: No se pudo crear la instancia del editor")
		return

	add_child(editor_window)
	current_command_editor = editor_window

	# Cargar el comando en el editor
	editor_window.load_command(command)

	# Conectar señales
	editor_window.command_edited.connect(func(cmd: SetVariableCommand): _on_set_variable_command_edited(cmd, page_index))

	# Si es un comando nuevo y se cancela, eliminarlo
	if is_new_command:
		editor_window.cancelled.connect(func():
			_on_new_command_cancelled(page_index, command_index)
			current_command_editor = null
			editor_window.queue_free()
		)
	else:
		editor_window.cancelled.connect(func():
			current_command_editor = null
			editor_window.queue_free()
		)

	# Mostrar la ventana
	editor_window.popup_centered()

## Callback cuando se edita un SetVariableCommand
func _on_set_variable_command_edited(command: SetVariableCommand, page_index: int) -> void:
	if not command:
		return

	# El comando ya está modificado (se modifica por referencia)
	# Solo necesitamos actualizar el árbol y refrescar el inspector
	_mark_as_changed()
	var page = _get_page(page_index)
	if page:
		var commands_tree = _get_commands_tree_for_page(page_index)
		if commands_tree:
			_update_commands_tree(commands_tree, page, page_index)
			# Deseleccionar el comando y actualizar botones
			commands_tree.deselect_all()
			_update_buttons_state(page_index, false, false, false, false, false)

	_refresh_inspector()

## Abre el editor para SetSelfSwitchCommand
## is_new_command: true si es un comando nuevo que se está añadiendo, false si se está editando
## command_index: índice del comando en la página (solo relevante si is_new_command es true)
func _open_set_self_switch_editor(command: SetSelfSwitchCommand, page_index: int, is_new_command: bool = false, command_index: int = -1) -> void:
	if not command:
		push_error("Event Editor: No se proporcionó un SetSelfSwitchCommand válido")
		return

	# Cerrar cualquier ventana de edición existente
	if current_command_editor and is_instance_valid(current_command_editor):
		current_command_editor.queue_free()
		current_command_editor = null

	# Esperar un frame para asegurar que la ventana anterior se haya cerrado
	await get_tree().process_frame

	# Cargar el script del editor
	var editor_script = load("res://addons/event_tools/set_self_switch_command_editor.gd")
	if not editor_script:
		push_error("Event Editor: No se encontró el script del editor de SetSelfSwitchCommand")
		return

	# Crear instancia de la ventana usando el script
	var editor_window = editor_script.new()
	if not editor_window:
		push_error("Event Editor: No se pudo crear la instancia del editor")
		return

	add_child(editor_window)
	current_command_editor = editor_window

	# Cargar el comando en el editor
	editor_window.load_command(command)

	# Conectar señales
	editor_window.command_edited.connect(func(cmd: SetSelfSwitchCommand): _on_set_self_switch_command_edited(cmd, page_index))

	# Si es un comando nuevo y se cancela, eliminarlo
	if is_new_command:
		editor_window.cancelled.connect(func():
			_on_new_command_cancelled(page_index, command_index)
			current_command_editor = null
			editor_window.queue_free()
		)
	else:
		editor_window.cancelled.connect(func():
			current_command_editor = null
			editor_window.queue_free()
		)

	# Mostrar la ventana
	editor_window.popup_centered()

## Callback cuando se edita un SetSelfSwitchCommand
func _on_set_self_switch_command_edited(command: SetSelfSwitchCommand, page_index: int) -> void:
	if not command:
		return

	# El comando ya está modificado (se modifica por referencia)
	# Solo necesitamos actualizar el árbol y refrescar el inspector
	_mark_as_changed()
	var page = _get_page(page_index)
	if page:
		var commands_tree = _get_commands_tree_for_page(page_index)
		if commands_tree:
			_update_commands_tree(commands_tree, page, page_index)
			# Deseleccionar el comando y actualizar botones
			commands_tree.deselect_all()
			_update_buttons_state(page_index, false, false, false, false, false)

	_refresh_inspector()

## Abre el editor para StartBattleEventCommand
## is_new_command: true si es un comando nuevo que se está añadiendo, false si se está editando
## command_index: índice del comando en la página (solo relevante si is_new_command es true)
func _open_start_battle_event_editor(command: StartBattleEventCommand, page_index: int, is_new_command: bool = false, command_index: int = -1) -> void:
	if not command:
		push_error("Event Editor: No se proporcionó un StartBattleEventCommand válido")
		return

	# Cerrar cualquier ventana de edición existente
	if current_command_editor and is_instance_valid(current_command_editor):
		current_command_editor.queue_free()
		current_command_editor = null

	# Esperar un frame para asegurar que la ventana anterior se haya cerrado
	await get_tree().process_frame

	# Cargar el script del editor
	var editor_script = load("res://addons/event_tools/start_battle_event_command_editor.gd")
	if not editor_script:
		push_error("Event Editor: No se encontró el script del editor de StartBattleEventCommand")
		return

	# Crear instancia de la ventana usando el script
	var editor_window = editor_script.new()
	if not editor_window:
		push_error("Event Editor: No se pudo crear la instancia del editor")
		return

	add_child(editor_window)
	current_command_editor = editor_window

	# Cargar el comando en el editor
	editor_window.load_command(command)

	# Conectar señales
	editor_window.command_edited.connect(func(cmd: StartBattleEventCommand): _on_start_battle_event_command_edited(cmd, page_index))

	# Si es un comando nuevo y se cancela, eliminarlo
	if is_new_command:
		editor_window.cancelled.connect(func():
			_on_new_command_cancelled(page_index, command_index)
			current_command_editor = null
			editor_window.queue_free()
		)
	else:
		editor_window.cancelled.connect(func():
			current_command_editor = null
			editor_window.queue_free()
		)

	# Mostrar la ventana
	editor_window.popup_centered()

## Callback cuando se edita un StartBattleEventCommand
func _on_start_battle_event_command_edited(command: StartBattleEventCommand, page_index: int) -> void:
	if not command:
		return

	# El comando ya está modificado (se modifica por referencia)
	# Solo necesitamos actualizar el árbol y refrescar el inspector
	_mark_as_changed()
	var page = _get_page(page_index)
	if page:
		var commands_tree = _get_commands_tree_for_page(page_index)
		if commands_tree:
			_update_commands_tree(commands_tree, page, page_index)
			# Deseleccionar el comando y actualizar botones
			commands_tree.deselect_all()
			_update_buttons_state(page_index, false, false, false, false, false)

	_refresh_inspector()

## Abre el editor para WarpCommand
## is_new_command: true si es un comando nuevo que se está añadiendo, false si se está editando
## command_index: índice del comando en la página (solo relevante si is_new_command es true)
func _open_warp_editor(command: WarpCommand, page_index: int, is_new_command: bool = false, command_index: int = -1) -> void:
	if not command:
		push_error("Event Editor: No se proporcionó un WarpCommand válido")
		return

	# Cerrar cualquier ventana de edición existente
	if current_command_editor and is_instance_valid(current_command_editor):
		current_command_editor.queue_free()
		current_command_editor = null

	# Esperar un frame para asegurar que la ventana anterior se haya cerrado
	await get_tree().process_frame

	# Cargar el script del editor
	var editor_script = load("res://addons/event_tools/warp_command_editor.gd")
	if not editor_script:
		push_error("Event Editor: No se encontró el script del editor de WarpCommand")
		return

	# Crear instancia de la ventana usando el script
	var editor_window = editor_script.new()
	if not editor_window:
		push_error("Event Editor: No se pudo crear la instancia del editor")
		return

	add_child(editor_window)
	current_command_editor = editor_window

	# Pasar la referencia al event_node para que pueda obtener los eventos del mapa
	editor_window.event_node = event_node

	# Cargar el comando en el editor
	editor_window.load_command(command)

	# Conectar señales
	editor_window.command_edited.connect(func(cmd: WarpCommand): _on_warp_command_edited(cmd, page_index))

	# Si es un comando nuevo y se cancela, eliminarlo
	if is_new_command:
		editor_window.cancelled.connect(func():
			_on_new_command_cancelled(page_index, command_index)
			current_command_editor = null
			editor_window.queue_free()
		)
	else:
		editor_window.cancelled.connect(func():
			current_command_editor = null
			editor_window.queue_free()
		)

	# Mostrar la ventana
	editor_window.popup_centered()

## Callback cuando se edita un WarpCommand
func _on_warp_command_edited(command: WarpCommand, page_index: int) -> void:
	if not command:
		return

	# El comando ya está modificado (se modifica por referencia)
	# Solo necesitamos actualizar el árbol y refrescar el inspector
	_mark_as_changed()
	var page = _get_page(page_index)
	if page:
		var commands_tree = _get_commands_tree_for_page(page_index)
		if commands_tree:
			_update_commands_tree(commands_tree, page, page_index)
			# Deseleccionar el comando y actualizar botones
			commands_tree.deselect_all()
			_update_buttons_state(page_index, false, false, false, false, false)

	_refresh_inspector()
	current_command_editor = null

## Abre el editor para WaitCommand
## is_new_command: true si es un comando nuevo que se está añadiendo, false si se está editando
## command_index: índice del comando en la página (solo relevante si is_new_command es true)
func _open_wait_editor(command: WaitCommand, page_index: int, is_new_command: bool = false, command_index: int = -1) -> void:
	if not command:
		push_error("Event Editor: No se proporcionó un WaitCommand válido")
		return

	# Cerrar cualquier ventana de edición existente
	if current_command_editor and is_instance_valid(current_command_editor):
		current_command_editor.queue_free()
		current_command_editor = null

	# Esperar un frame para asegurar que la ventana anterior se haya cerrado
	await get_tree().process_frame

	# Cargar el script del editor
	var editor_script = load("res://addons/event_tools/wait_command_editor.gd")
	if not editor_script:
		push_error("Event Editor: No se encontró el script del editor de WaitCommand")
		return

	# Crear instancia de la ventana usando el script
	var editor_window = editor_script.new()
	if not editor_window:
		push_error("Event Editor: No se pudo crear la instancia del editor")
		return

	add_child(editor_window)
	current_command_editor = editor_window

	# Cargar el comando en el editor
	editor_window.load_command(command)

	# Conectar señales
	editor_window.command_edited.connect(func(cmd: WaitCommand): _on_wait_command_edited(cmd, page_index))

	# Si es un comando nuevo y se cancela, eliminarlo
	if is_new_command:
		editor_window.cancelled.connect(func():
			_on_new_command_cancelled(page_index, command_index)
			current_command_editor = null
			editor_window.queue_free()
		)
	else:
		editor_window.cancelled.connect(func():
			current_command_editor = null
			editor_window.queue_free()
		)

	# Mostrar la ventana
	editor_window.popup_centered()

## Callback cuando se edita un WaitCommand
func _on_wait_command_edited(command: WaitCommand, page_index: int) -> void:
	if not command:
		return

	# El comando ya está modificado (se modifica por referencia)
	# Solo necesitamos actualizar el árbol y refrescar el inspector
	_mark_as_changed()
	var page = _get_page(page_index)
	if page:
		var commands_tree = _get_commands_tree_for_page(page_index)
		if commands_tree:
			_update_commands_tree(commands_tree, page, page_index)
			# Deseleccionar el comando y actualizar botones
			commands_tree.deselect_all()
			_update_buttons_state(page_index, false, false, false, false, false)

	_refresh_inspector()
	current_command_editor = null

## Abre el editor para FadeCommand
## is_new_command: true si es un comando nuevo que se está añadiendo, false si se está editando
## command_index: índice del comando en la página (solo relevante si is_new_command es true)
func _open_fade_editor(command: FadeCommand, page_index: int, is_new_command: bool = false, command_index: int = -1) -> void:
	if not command:
		push_error("Event Editor: No se proporcionó un FadeCommand válido")
		return

	# Cerrar cualquier ventana de edición existente
	if current_command_editor and is_instance_valid(current_command_editor):
		current_command_editor.queue_free()
		current_command_editor = null

	# Esperar un frame para asegurar que la ventana anterior se haya cerrado
	await get_tree().process_frame

	# Cargar el script del editor
	var editor_script = load("res://addons/event_tools/fade_command_editor.gd")
	if not editor_script:
		push_error("Event Editor: No se encontró el script del editor de FadeCommand")
		return

	# Crear instancia de la ventana usando el script
	var editor_window = editor_script.new()
	if not editor_window:
		push_error("Event Editor: No se pudo crear la instancia del editor")
		return

	add_child(editor_window)
	current_command_editor = editor_window

	# Cargar el comando en el editor
	editor_window.load_command(command)

	# Conectar señales
	editor_window.command_edited.connect(func(cmd: FadeCommand): _on_fade_command_edited(cmd, page_index))

	# Si es un comando nuevo y se cancela, eliminarlo
	if is_new_command:
		editor_window.cancelled.connect(func():
			_on_new_command_cancelled(page_index, command_index)
			current_command_editor = null
			editor_window.queue_free()
		)
	else:
		editor_window.cancelled.connect(func():
			current_command_editor = null
			editor_window.queue_free()
		)

	# Mostrar la ventana
	editor_window.popup_centered()

## Callback cuando se edita un FadeCommand
func _on_fade_command_edited(command: FadeCommand, page_index: int) -> void:
	if not command:
		return

	# El comando ya está modificado (se modifica por referencia)
	# Solo necesitamos actualizar el árbol y refrescar el inspector
	_mark_as_changed()
	var page = _get_page(page_index)
	if page:
		var commands_tree = _get_commands_tree_for_page(page_index)
		if commands_tree:
			_update_commands_tree(commands_tree, page, page_index)
			# Deseleccionar el comando y actualizar botones
			commands_tree.deselect_all()
			_update_buttons_state(page_index, false, false, false, false, false)

	_refresh_inspector()
	current_command_editor = null

## Abre el editor para SetWeatherCommand
func _open_set_weather_editor(command: SetWeatherCommand, page_index: int, is_new_command: bool = false, command_index: int = -1) -> void:
	if not command:
		push_error("Event Editor: No se proporcionó un SetWeatherCommand válido")
		return

	if current_command_editor and is_instance_valid(current_command_editor):
		current_command_editor.queue_free()
		current_command_editor = null

	await get_tree().process_frame

	var editor_script = load("res://addons/event_tools/set_weather_command_editor.gd")
	if not editor_script:
		push_error("Event Editor: No se encontró el script del editor de SetWeatherCommand")
		return

	var editor_window = editor_script.new()
	if not editor_window:
		push_error("Event Editor: No se pudo crear la instancia del editor")
		return

	add_child(editor_window)
	current_command_editor = editor_window
	editor_window.load_command(command)
	editor_window.command_edited.connect(func(cmd: SetWeatherCommand): _on_set_weather_command_edited(cmd, page_index))

	if is_new_command:
		editor_window.cancelled.connect(func():
			_on_new_command_cancelled(page_index, command_index)
			current_command_editor = null
			editor_window.queue_free()
		)
	else:
		editor_window.cancelled.connect(func():
			current_command_editor = null
			editor_window.queue_free()
		)

	editor_window.popup_centered()

func _on_set_weather_command_edited(command: SetWeatherCommand, page_index: int) -> void:
	if not command:
		return
	_mark_as_changed()
	var page = _get_page(page_index)
	if page:
		var commands_tree = _get_commands_tree_for_page(page_index)
		if commands_tree:
			_update_commands_tree(commands_tree, page, page_index)
			commands_tree.deselect_all()
			_update_buttons_state(page_index, false, false, false, false, false)
	_refresh_inspector()

## Abre el editor para SetDarknessCommand
func _open_set_darkness_editor(command: SetDarknessCommand, page_index: int, is_new_command: bool = false, command_index: int = -1) -> void:
	if not command:
		push_error("Event Editor: No se proporcionó un SetDarknessCommand válido")
		return

	if current_command_editor and is_instance_valid(current_command_editor):
		current_command_editor.queue_free()
		current_command_editor = null

	await get_tree().process_frame

	var editor_script = load("res://addons/event_tools/set_darkness_command_editor.gd")
	if not editor_script:
		push_error("Event Editor: No se encontró el script del editor de SetDarknessCommand")
		return

	var editor_window = editor_script.new()
	if not editor_window:
		push_error("Event Editor: No se pudo crear la instancia del editor")
		return

	add_child(editor_window)
	current_command_editor = editor_window
	editor_window.load_command(command)
	editor_window.command_edited.connect(func(cmd: SetDarknessCommand): _on_set_darkness_command_edited(cmd, page_index))

	if is_new_command:
		editor_window.cancelled.connect(func():
			_on_new_command_cancelled(page_index, command_index)
			current_command_editor = null
			editor_window.queue_free()
		)
	else:
		editor_window.cancelled.connect(func():
			current_command_editor = null
			editor_window.queue_free()
		)

	editor_window.popup_centered()

func _on_set_darkness_command_edited(command: SetDarknessCommand, page_index: int) -> void:
	if not command:
		return
	_mark_as_changed()
	var page = _get_page(page_index)
	if page:
		var commands_tree = _get_commands_tree_for_page(page_index)
		if commands_tree:
			_update_commands_tree(commands_tree, page, page_index)
			commands_tree.deselect_all()
			_update_buttons_state(page_index, false, false, false, false, false)
	_refresh_inspector()

## Abre el editor para SetFlashlightCommand
func _open_set_flashlight_editor(command: SetFlashlightCommand, page_index: int, is_new_command: bool = false, command_index: int = -1) -> void:
	if not command:
		push_error("Event Editor: No se proporcionó un SetFlashlightCommand válido")
		return

	if current_command_editor and is_instance_valid(current_command_editor):
		current_command_editor.queue_free()
		current_command_editor = null

	await get_tree().process_frame

	var editor_script = load("res://addons/event_tools/set_flashlight_command_editor.gd")
	if not editor_script:
		push_error("Event Editor: No se encontró el script del editor de SetFlashlightCommand")
		return

	var editor_window = editor_script.new()
	if not editor_window:
		push_error("Event Editor: No se pudo crear la instancia del editor")
		return

	add_child(editor_window)
	current_command_editor = editor_window
	editor_window.load_command(command)
	editor_window.command_edited.connect(func(cmd: SetFlashlightCommand): _on_set_flashlight_command_edited(cmd, page_index))

	if is_new_command:
		editor_window.cancelled.connect(func():
			_on_new_command_cancelled(page_index, command_index)
			current_command_editor = null
			editor_window.queue_free()
		)
	else:
		editor_window.cancelled.connect(func():
			current_command_editor = null
			editor_window.queue_free()
		)

	editor_window.popup_centered()

func _on_set_flashlight_command_edited(command: SetFlashlightCommand, page_index: int) -> void:
	if not command:
		return
	_mark_as_changed()
	var page = _get_page(page_index)
	if page:
		var commands_tree = _get_commands_tree_for_page(page_index)
		if commands_tree:
			_update_commands_tree(commands_tree, page, page_index)
			commands_tree.deselect_all()
			_update_buttons_state(page_index, false, false, false, false, false)
	_refresh_inspector()

## Abre el editor para SetEventThroughCommand
func _open_set_event_through_editor(command: SetEventThroughCommand, page_index: int, is_new_command: bool = false, command_index: int = -1) -> void:
	if not command:
		push_error("Event Editor: No se proporcionó un SetEventThroughCommand válido")
		return

	if current_command_editor and is_instance_valid(current_command_editor):
		current_command_editor.queue_free()
		current_command_editor = null

	await get_tree().process_frame

	var editor_script = load("res://addons/event_tools/set_event_through_command_editor.gd")
	if not editor_script:
		push_error("Event Editor: No se encontró el script del editor de SetEventThroughCommand")
		return

	var editor_window = editor_script.new()
	if not editor_window:
		push_error("Event Editor: No se pudo crear la instancia del editor")
		return

	add_child(editor_window)
	current_command_editor = editor_window
	editor_window.event_node = event_node
	editor_window.load_command(command)
	editor_window.command_edited.connect(func(cmd: SetEventThroughCommand): _on_set_event_through_command_edited(cmd, page_index))

	if is_new_command:
		editor_window.cancelled.connect(func():
			_on_new_command_cancelled(page_index, command_index)
			current_command_editor = null
			editor_window.queue_free()
		)
	else:
		editor_window.cancelled.connect(func():
			current_command_editor = null
			editor_window.queue_free()
		)

	editor_window.popup_centered()

func _on_set_event_through_command_edited(command: SetEventThroughCommand, page_index: int) -> void:
	if not command:
		return
	_mark_as_changed()
	var page = _get_page(page_index)
	if page:
		var commands_tree = _get_commands_tree_for_page(page_index)
		if commands_tree:
			_update_commands_tree(commands_tree, page, page_index)
			commands_tree.deselect_all()
			_update_buttons_state(page_index, false, false, false, false, false)
	_refresh_inspector()

## Abre el editor para SetActorVisibilityCommand
func _open_set_actor_visibility_editor(command: SetActorVisibilityCommand, page_index: int, is_new_command: bool = false, command_index: int = -1) -> void:
	if not command:
		push_error("Event Editor: No se proporcionó un SetActorVisibilityCommand válido")
		return

	if current_command_editor and is_instance_valid(current_command_editor):
		current_command_editor.queue_free()
		current_command_editor = null

	await get_tree().process_frame

	var editor_script = load("res://addons/event_tools/set_actor_visibility_command_editor.gd")
	if not editor_script:
		push_error("Event Editor: No se encontró el script del editor de SetActorVisibilityCommand")
		return

	var editor_window = editor_script.new()
	if not editor_window:
		push_error("Event Editor: No se pudo crear la instancia del editor")
		return

	add_child(editor_window)
	current_command_editor = editor_window
	editor_window.event_node = event_node
	editor_window.load_command(command)
	editor_window.command_edited.connect(func(cmd: SetActorVisibilityCommand): _on_set_actor_visibility_command_edited(cmd, page_index))

	if is_new_command:
		editor_window.cancelled.connect(func():
			_on_new_command_cancelled(page_index, command_index)
			current_command_editor = null
			editor_window.queue_free()
		)
	else:
		editor_window.cancelled.connect(func():
			current_command_editor = null
			editor_window.queue_free()
		)

	editor_window.popup_centered()

func _on_set_actor_visibility_command_edited(command: SetActorVisibilityCommand, page_index: int) -> void:
	if not command:
		return
	_mark_as_changed()
	var page = _get_page(page_index)
	if page:
		var commands_tree = _get_commands_tree_for_page(page_index)
		if commands_tree:
			_update_commands_tree(commands_tree, page, page_index)
			commands_tree.deselect_all()
			_update_buttons_state(page_index, false, false, false, false, false)
	_refresh_inspector()

## Abre el editor para SetTriggerCommand
## is_new_command: true si es un comando nuevo que se está añadiendo, false si se está editando
## command_index: índice del comando en la página (solo relevante si is_new_command es true)
func _open_set_trigger_editor(command: SetTriggerCommand, page_index: int, is_new_command: bool = false, command_index: int = -1) -> void:
	if not command:
		push_error("Event Editor: No se proporcionó un SetTriggerCommand válido")
		return

	if current_command_editor and is_instance_valid(current_command_editor):
		current_command_editor.queue_free()
		current_command_editor = null

	await get_tree().process_frame

	var editor_script = load("res://addons/event_tools/set_trigger_command_editor.gd")
	if not editor_script:
		push_error("Event Editor: No se encontró el script del editor de SetTriggerCommand")
		return

	var editor_window = editor_script.new()
	if not editor_window:
		push_error("Event Editor: No se pudo crear la instancia del editor")
		return

	add_child(editor_window)
	current_command_editor = editor_window
	editor_window.event_node = event_node
	editor_window.load_command(command)
	editor_window.command_edited.connect(func(cmd: SetTriggerCommand): _on_set_trigger_command_edited(cmd, page_index))

	if is_new_command:
		editor_window.cancelled.connect(func():
			_on_new_command_cancelled(page_index, command_index)
			current_command_editor = null
			editor_window.queue_free()
		)
	else:
		editor_window.cancelled.connect(func():
			current_command_editor = null
			editor_window.queue_free()
		)

	editor_window.popup_centered()

## Callback cuando se edita un SetTriggerCommand
func _on_set_trigger_command_edited(command: SetTriggerCommand, page_index: int) -> void:
	if not command:
		return

	# El comando ya está modificado (se modifica por referencia)
	# Solo necesitamos actualizar el árbol y refrescar el inspector
	_mark_as_changed()
	var page = _get_page(page_index)
	if page:
		var commands_tree = _get_commands_tree_for_page(page_index)
		if commands_tree:
			_update_commands_tree(commands_tree, page, page_index)
			# Deseleccionar el comando y actualizar botones
			commands_tree.deselect_all()
			_update_buttons_state(page_index, false, false, false, false, false)

	_refresh_inspector()

## Abre el editor para ShowPortraitCommand
func _open_show_portrait_editor(command: ShowPortraitCommand, page_index: int, is_new_command: bool = false, command_index: int = -1) -> void:
	if not command:
		push_error("Event Editor: No se proporcionó un ShowPortraitCommand válido")
		return

	if current_command_editor and is_instance_valid(current_command_editor):
		current_command_editor.queue_free()
		current_command_editor = null

	await get_tree().process_frame

	var editor_script = load("res://addons/event_tools/show_portrait_command_editor.gd")
	if not editor_script:
		push_error("Event Editor: No se encontró el script del editor de ShowPortraitCommand")
		return

	var editor_window = editor_script.new()
	if not editor_window:
		push_error("Event Editor: No se pudo crear la instancia del editor")
		return

	add_child(editor_window)
	current_command_editor = editor_window
	editor_window.load_command(command)
	editor_window.command_edited.connect(func(cmd: ShowPortraitCommand): _on_show_portrait_command_edited(cmd, page_index))

	if is_new_command:
		editor_window.cancelled.connect(func():
			_on_new_command_cancelled(page_index, command_index)
			current_command_editor = null
			editor_window.queue_free()
		)
	else:
		editor_window.cancelled.connect(func():
			current_command_editor = null
			editor_window.queue_free()
		)

	editor_window.popup_centered()

func _on_show_portrait_command_edited(command: ShowPortraitCommand, page_index: int) -> void:
	if not command:
		return
	_mark_as_changed()
	var page = _get_page(page_index)
	if page:
		var commands_tree = _get_commands_tree_for_page(page_index)
		if commands_tree:
			_update_commands_tree(commands_tree, page, page_index)
			commands_tree.deselect_all()
			_update_buttons_state(page_index, false, false, false, false, false)
	_refresh_inspector()

## Abre el editor para FollowActorCommand
func _open_follow_actor_editor(command: FollowActorCommand, page_index: int, is_new_command: bool = false, command_index: int = -1) -> void:
	if not command:
		push_error("Event Editor: No se proporcionó un FollowActorCommand válido")
		return

	if current_command_editor and is_instance_valid(current_command_editor):
		current_command_editor.queue_free()
		current_command_editor = null

	await get_tree().process_frame

	var editor_script = load("res://addons/event_tools/follow_actor_command_editor.gd")
	if not editor_script:
		push_error("Event Editor: No se encontró el script del editor de FollowActorCommand")
		return

	var editor_window = editor_script.new()
	if not editor_window:
		push_error("Event Editor: No se pudo crear la instancia del editor")
		return

	add_child(editor_window)
	current_command_editor = editor_window
	editor_window.set_event_node(event_node)
	editor_window.load_command(command)
	editor_window.command_edited.connect(func(cmd: FollowActorCommand): _on_follow_actor_command_edited(cmd, page_index))

	if is_new_command:
		editor_window.cancelled.connect(func():
			_on_new_command_cancelled(page_index, command_index)
			current_command_editor = null
			editor_window.queue_free()
		)
	else:
		editor_window.cancelled.connect(func():
			current_command_editor = null
			editor_window.queue_free()
		)

	editor_window.popup_centered()

func _on_follow_actor_command_edited(command: FollowActorCommand, page_index: int) -> void:
	if not command:
		return
	_mark_as_changed()
	var page = _get_page(page_index)
	if page:
		var commands_tree = _get_commands_tree_for_page(page_index)
		if commands_tree:
			_update_commands_tree(commands_tree, page, page_index)
			commands_tree.deselect_all()
			_update_buttons_state(page_index, false, false, false, false, false)
	_refresh_inspector()

## Abre el editor para UseMOCommand
func _open_use_mo_editor(command: UseMOCommand, page_index: int, is_new_command: bool = false, command_index: int = -1) -> void:
	if not command:
		push_error("Event Editor: No se proporcionó un UseMOCommand válido")
		return

	if current_command_editor and is_instance_valid(current_command_editor):
		current_command_editor.queue_free()
		current_command_editor = null

	await get_tree().process_frame

	var editor_script = load("res://addons/event_tools/use_mo_command_editor.gd")
	if not editor_script:
		push_error("Event Editor: No se encontró el script del editor de UseMOCommand")
		return

	var editor_window = editor_script.new()
	if not editor_window:
		push_error("Event Editor: No se pudo crear la instancia del editor")
		return

	add_child(editor_window)
	current_command_editor = editor_window
	editor_window.set_event_node(event_node)
	editor_window.load_command(command)
	editor_window.command_edited.connect(func(cmd: UseMOCommand): _on_use_mo_command_edited(cmd, page_index))

	if is_new_command:
		editor_window.cancelled.connect(func():
			_on_new_command_cancelled(page_index, command_index)
			current_command_editor = null
			editor_window.queue_free()
		)
	else:
		editor_window.cancelled.connect(func():
			current_command_editor = null
			editor_window.queue_free()
		)

	editor_window.popup_centered()

func _on_use_mo_command_edited(command: UseMOCommand, page_index: int) -> void:
	if not command:
		return
	_mark_as_changed()
	var page = _get_page(page_index)
	if page:
		var commands_tree = _get_commands_tree_for_page(page_index)
		if commands_tree:
			_update_commands_tree(commands_tree, page, page_index)
			commands_tree.deselect_all()
			_update_buttons_state(page_index, false, false, false, false, false)
	_refresh_inspector()

## Abre el editor para PlayAnimationCommand
func _open_play_animation_editor(command: PlayAnimationCommand, page_index: int, is_new_command: bool = false, command_index: int = -1) -> void:
	if not command:
		push_error("Event Editor: No se proporcionó un PlayAnimationCommand válido")
		return

	if current_command_editor and is_instance_valid(current_command_editor):
		current_command_editor.queue_free()
		current_command_editor = null

	await get_tree().process_frame

	var editor_script = load("res://addons/event_tools/play_animation_command_editor.gd")
	if not editor_script:
		push_error("Event Editor: No se encontró el script del editor de PlayAnimationCommand")
		return

	var editor_window = editor_script.new()
	if not editor_window:
		push_error("Event Editor: No se pudo crear la instancia del editor")
		return

	add_child(editor_window)
	current_command_editor = editor_window
	editor_window.set_event_node(event_node)
	editor_window.load_command(command)
	editor_window.command_edited.connect(func(cmd: PlayAnimationCommand): _on_play_animation_command_edited(cmd, page_index))

	if is_new_command:
		editor_window.cancelled.connect(func():
			_on_new_command_cancelled(page_index, command_index)
			current_command_editor = null
			editor_window.queue_free()
		)
	else:
		editor_window.cancelled.connect(func():
			current_command_editor = null
			editor_window.queue_free()
		)

	editor_window.popup_centered()

func _on_play_animation_command_edited(command: PlayAnimationCommand, page_index: int) -> void:
	if not command:
		return
	_mark_as_changed()
	var page = _get_page(page_index)
	if page:
		var commands_tree = _get_commands_tree_for_page(page_index)
		if commands_tree:
			_update_commands_tree(commands_tree, page, page_index)
			commands_tree.deselect_all()
			_update_buttons_state(page_index, false, false, false, false, false)
	_refresh_inspector()

## Abre el editor para MoveNPCCommand
func _open_move_npc_editor(command: MoveNPCCommand, page_index: int, is_new_command: bool = false, command_index: int = -1) -> void:
	if not command:
		push_error("Event Editor: No se proporcionó un MoveNPCCommand válido")
		return

	if current_command_editor and is_instance_valid(current_command_editor):
		current_command_editor.queue_free()
		current_command_editor = null

	await get_tree().process_frame

	var editor_script = load("res://addons/event_tools/move_npc_command_editor.gd")
	if not editor_script:
		push_error("Event Editor: No se encontró el script del editor de MoveNPCCommand")
		return

	var editor_window = editor_script.new()
	if not editor_window:
		push_error("Event Editor: No se pudo crear la instancia del editor")
		return

	add_child(editor_window)
	current_command_editor = editor_window
	editor_window.set_event_node(event_node)
	editor_window.load_command(command)
	editor_window.command_edited.connect(func(cmd: MoveNPCCommand): _on_move_npc_command_edited(cmd, page_index))

	if is_new_command:
		editor_window.cancelled.connect(func():
			_on_new_command_cancelled(page_index, command_index)
			current_command_editor = null
			editor_window.queue_free()
		)
	else:
		editor_window.cancelled.connect(func():
			current_command_editor = null
			editor_window.queue_free()
		)

	editor_window.popup_centered()

func _on_move_npc_command_edited(command: MoveNPCCommand, page_index: int) -> void:
	if not command:
		return
	_mark_as_changed()
	var page = _get_page(page_index)
	if page:
		var commands_tree = _get_commands_tree_for_page(page_index)
		if commands_tree:
			_update_commands_tree(commands_tree, page, page_index)
			commands_tree.deselect_all()
			_update_buttons_state(page_index, false, false, false, false, false)
	_refresh_inspector()

## Abre el editor para ConditionalCommand
func _open_conditional_editor(command: ConditionalCommand, page_index: int, is_new_command: bool = false, command_index: int = -1) -> void:
	if not command:
		push_error("Event Editor: No se proporcionó un ConditionalCommand válido")
		return

	if current_command_editor and is_instance_valid(current_command_editor):
		current_command_editor.queue_free()
		current_command_editor = null

	await get_tree().process_frame

	var editor_script = load("res://addons/event_tools/conditional_command_editor.gd")
	if not editor_script:
		push_error("Event Editor: No se encontró el script del editor de ConditionalCommand")
		return

	var editor_window = editor_script.new()
	if not editor_window:
		push_error("Event Editor: No se pudo crear la instancia del editor")
		return

	add_child(editor_window)
	current_command_editor = editor_window
	editor_window.set_event_node(event_node)
	editor_window.load_command(command)
	editor_window.command_edited.connect(func(cmd: ConditionalCommand): _on_conditional_command_edited(cmd, page_index))

	if is_new_command:
		editor_window.cancelled.connect(func():
			_on_new_command_cancelled(page_index, command_index)
			current_command_editor = null
			editor_window.queue_free()
		)
	else:
		editor_window.cancelled.connect(func():
			current_command_editor = null
			editor_window.queue_free()
		)

	editor_window.popup_centered()

func _on_conditional_command_edited(command: ConditionalCommand, page_index: int) -> void:
	if not command:
		return
	_mark_as_changed()
	var page = _get_page(page_index)
	if page:
		var commands_tree = _get_commands_tree_for_page(page_index)
		if commands_tree:
			_update_commands_tree(commands_tree, page, page_index)
			commands_tree.deselect_all()
			_update_buttons_state(page_index, false, false, false, false, false)
	_refresh_inspector()

## Abre el editor para SwitchCommand
func _open_switch_editor(command: SwitchCommand, page_index: int, is_new_command: bool = false, command_index: int = -1) -> void:
	if not command:
		push_error("Event Editor: No se proporcionó un SwitchCommand válido")
		return

	if current_command_editor and is_instance_valid(current_command_editor):
		current_command_editor.queue_free()
		current_command_editor = null

	await get_tree().process_frame

	var editor_script = load("res://addons/event_tools/switch_command_editor.gd")
	if not editor_script:
		push_error("Event Editor: No se encontró el script del editor de SwitchCommand")
		return

	var editor_window = editor_script.new()
	if not editor_window:
		push_error("Event Editor: No se pudo crear la instancia del editor")
		return

	add_child(editor_window)
	current_command_editor = editor_window
	editor_window.set_event_node(event_node)
	editor_window.load_command(command)
	editor_window.command_edited.connect(func(cmd: SwitchCommand): _on_switch_command_edited(cmd, page_index))

	if is_new_command:
		editor_window.cancelled.connect(func():
			_on_new_command_cancelled(page_index, command_index)
			current_command_editor = null
			editor_window.queue_free()
		)
	else:
		editor_window.cancelled.connect(func():
			current_command_editor = null
			editor_window.queue_free()
		)

	editor_window.popup_centered()

func _on_switch_command_edited(command: SwitchCommand, page_index: int) -> void:
	if not command:
		return
	_mark_as_changed()
	var page = _get_page(page_index)
	if page:
		var commands_tree = _get_commands_tree_for_page(page_index)
		if commands_tree:
			_update_commands_tree(commands_tree, page, page_index)
			commands_tree.deselect_all()
			_update_buttons_state(page_index, false, false, false, false, false)
	_refresh_inspector()

## Abre el editor para ShowChoicesCommand
func _open_show_choices_editor(command: ShowChoicesCommand, page_index: int, is_new_command: bool = false, command_index: int = -1) -> void:
	if not command:
		push_error("Event Editor: No se proporcionó un ShowChoicesCommand válido")
		return

	if current_command_editor and is_instance_valid(current_command_editor):
		current_command_editor.queue_free()
		current_command_editor = null

	await get_tree().process_frame

	var editor_script = load("res://addons/event_tools/show_choices_command_editor.gd")
	if not editor_script:
		push_error("Event Editor: No se encontró el script del editor de ShowChoicesCommand")
		return

	var editor_window = editor_script.new()
	if not editor_window:
		push_error("Event Editor: No se pudo crear la instancia del editor")
		return

	add_child(editor_window)
	current_command_editor = editor_window
	editor_window.set_event_node(event_node)
	editor_window.load_command(command)
	editor_window.command_edited.connect(func(cmd: ShowChoicesCommand): _on_show_choices_command_edited(cmd, page_index))

	if is_new_command:
		editor_window.cancelled.connect(func():
			_on_new_command_cancelled(page_index, command_index)
			current_command_editor = null
			editor_window.queue_free()
		)
	else:
		editor_window.cancelled.connect(func():
			current_command_editor = null
			editor_window.queue_free()
		)

	editor_window.popup_centered()

func _on_show_choices_command_edited(command: ShowChoicesCommand, page_index: int) -> void:
	if not command:
		return
	_mark_as_changed()
	var page = _get_page(page_index)
	if page:
		var commands_tree = _get_commands_tree_for_page(page_index)
		if commands_tree:
			_update_commands_tree(commands_tree, page, page_index)
			commands_tree.deselect_all()
			_update_buttons_state(page_index, false, false, false, false, false)
	_refresh_inspector()

## Abre el editor de valores de un SwitchCase directamente desde el editor principal
func _open_switch_case_values_editor(switch_case: SwitchCase, switch_command: SwitchCommand, page_index: int) -> void:
	if not switch_case or not switch_command:
		push_error("Event Editor: No se proporcionó un SwitchCase o SwitchCommand válido")
		return

	# Encontrar el índice del caso en el comando
	var case_index = -1
	for i in range(switch_command.cases.size()):
		if switch_command.cases[i] == switch_case:
			case_index = i
			break

	if case_index < 0:
		push_error("Event Editor: No se pudo encontrar el caso en el comando")
		return

	# Abrir ventana de edición de valores
	var editor_script = load("res://addons/event_tools/switch_case_values_editor.gd")
	if not editor_script:
		push_error("Event Editor: No se encontró el script del editor de valores")
		return

	var editor_window = editor_script.new()
	if not editor_window:
		push_error("Event Editor: No se pudo crear la instancia del editor")
		return

	add_child(editor_window)
	editor_window.load_case(switch_case)
	editor_window.values_edited.connect(func(values: Array): _on_switch_case_values_edited(switch_command, case_index, values, page_index))
	editor_window.cancelled.connect(func(): editor_window.queue_free())

	editor_window.popup_centered()

## Abre el editor de opciones para una rama del ShowChoicesCommand
func _open_choice_branch_editor(branch: ChoiceBranch, show_choices_command: ShowChoicesCommand, page_index: int) -> void:
	if not branch or not show_choices_command:
		push_error("Event Editor: No se proporcionó un ChoiceBranch o ShowChoicesCommand válido")
		return

	# Encontrar el índice de la opción en el comando
	var branch_index = -1
	for i in range(show_choices_command.branches.size()):
		if show_choices_command.branches[i] == branch:
			branch_index = i
			break

	if branch_index < 0:
		push_error("Event Editor: No se pudo encontrar la opción en el comando")
		return

	# Abrir ventana de edición de opciones
	var editor_script = load("res://addons/event_tools/choice_branch_editor.gd")
	if not editor_script:
		push_error("Event Editor: No se encontró el script del editor de opciones")
		return

	var editor_window = editor_script.new()
	if not editor_window:
		push_error("Event Editor: No se pudo crear la instancia del editor")
		return

	add_child(editor_window)
	editor_window.load_branch(branch)
	editor_window.branch_edited.connect(func(edited_branch: ChoiceBranch): _on_choice_branch_edited(show_choices_command, branch_index, edited_branch, page_index))
	editor_window.cancelled.connect(func(): editor_window.queue_free())

	editor_window.popup_centered()

## Se llama cuando se edita una opción desde el editor principal
func _on_choice_branch_edited(show_choices_command: ShowChoicesCommand, branch_index: int, edited_branch: ChoiceBranch, page_index: int) -> void:
	if not show_choices_command or branch_index < 0 or branch_index >= show_choices_command.branches.size():
		return

	var branch = show_choices_command.branches[branch_index]
	if not branch:
		return

	# Actualizar la opción
	branch.label = edited_branch.label
	branch.close_previous_message = edited_branch.close_previous_message
	branch.value_stored = edited_branch.value_stored

	# Marcar como cambiado y refrescar
	_mark_as_changed()
	var page = _get_page(page_index)
	if page:
		var commands_tree = _get_commands_tree_for_page(page_index)
		if commands_tree:
			_update_commands_tree(commands_tree, page, page_index)

## Abre el editor de condiciones para una rama del ConditionalCommand
func _open_condition_editor_for_branch(branch: EventBranch, conditional_command: ConditionalCommand, page_index: int) -> void:
	if not branch or not conditional_command:
		push_error("Event Editor: No se proporcionó un EventBranch o ConditionalCommand válido")
		return

	# Encontrar el índice de la rama en el comando
	var branch_index = -1
	for i in range(conditional_command.branches.size()):
		if conditional_command.branches[i] == branch:
			branch_index = i
			break

	if branch_index < 0:
		push_error("Event Editor: No se pudo encontrar la rama en el comando")
		return

	# Abrir ventana de edición de condiciones
	var editor_script = load("res://addons/event_tools/condition_editor.gd")
	if not editor_script:
		push_error("Event Editor: No se encontró el script del editor de condiciones")
		return

	var editor_window = editor_script.new()
	if not editor_window:
		push_error("Event Editor: No se pudo crear la instancia del editor")
		return

	add_child(editor_window)
	editor_window.set_event_node(event_node)
	editor_window.load_condition(branch.condition)
	editor_window.condition_edited.connect(func(cond: EventCondition): _on_branch_condition_edited(conditional_command, branch_index, cond, page_index))
	editor_window.cancelled.connect(func(): editor_window.queue_free())

	editor_window.popup_centered()

## Se llama cuando se edita la condición de una rama desde el editor principal
func _on_branch_condition_edited(conditional_command: ConditionalCommand, branch_index: int, new_condition: EventCondition, page_index: int) -> void:
	if not conditional_command or branch_index < 0 or branch_index >= conditional_command.branches.size():
		return

	var branch = conditional_command.branches[branch_index]
	if not branch:
		return

	# Actualizar la condición de la rama
	if new_condition:
		branch.condition = new_condition.duplicate(true)
	else:
		branch.condition = null

	# Marcar como cambiado y refrescar
	_mark_as_changed()
	var page = _get_page(page_index)
	if page:
		var commands_tree = _get_commands_tree_for_page(page_index)
		if commands_tree:
			_update_commands_tree(commands_tree, page, page_index)

## Se llama cuando se edita la condición de una página desde el editor principal
func _on_page_condition_edited(page_index: int, new_condition: EventCondition) -> void:
	var page = _get_page(page_index)
	if not page:
		return

	# Actualizar la condición de la página
	if new_condition:
		page.root_condition = new_condition.duplicate(true)
	else:
		page.root_condition = null

	# Marcar como cambiado y refrescar el árbol
	_mark_as_changed()
	var commands_tree = _get_commands_tree_for_page(page_index)
	if commands_tree:
		_update_commands_tree(commands_tree, page, page_index)

## Se llama cuando se edita el movimiento de una página desde el editor principal
func _on_page_movement_edited(page_index: int) -> void:
	var page = _get_page(page_index)
	if not page:
		return

	# Marcar como cambiado (el editor ya actualizó la página directamente)
	_mark_as_changed()

	# Refrescar el inspector para que muestre los cambios
	_refresh_inspector()

## Se llama cuando se edita el sprite de una página desde el editor principal
func _on_page_sprite_edited(page_index: int) -> void:
	var page = _get_page(page_index)
	if not page:
		return

	# Marcar como cambiado (el editor ya actualizó la página directamente)
	_mark_as_changed()

	# Refrescar el inspector para que muestre los cambios
	_refresh_inspector()

func _on_page_trainer_edited(page_index: int) -> void:
	var page = _get_page(page_index)
	if not page:
		return

	# Marcar como cambiado (el editor ya actualizó la página directamente)
	_mark_as_changed()

## Se llama cuando se editan los valores de un SwitchCase desde el editor principal
func _on_switch_case_values_edited(switch_command: SwitchCommand, case_index: int, values: Array, page_index: int) -> void:
	if not switch_command or case_index < 0 or case_index >= switch_command.cases.size():
		return

	var switch_case = switch_command.cases[case_index]
	if not switch_case:
		return

	# Actualizar los valores del caso
	switch_case.values = values.duplicate()

	# Marcar como cambiado y refrescar
	_mark_as_changed()
	var page = _get_page(page_index)
	if page:
		var commands_tree = _get_commands_tree_for_page(page_index)
		if commands_tree:
			_update_commands_tree(commands_tree, page, page_index)
	_refresh_inspector()

## Callback cuando se cancela la edición de un comando nuevo
## Elimina el comando de la página
func _on_new_command_cancelled(page_index: int, command_index: int) -> void:
	if command_index < 0:
		return

	var page = _get_page(page_index)
	if not page:
		return

	# Crear una copia editable de la página
	var editable_page = page.duplicate(true) as EventPage
	if not editable_page:
		push_error("Event Editor: No se pudo duplicar la página")
		return

	# Verificar que el índice es válido
	if command_index >= editable_page.commands.size():
		return

	# Eliminar el comando en el índice especificado
	var new_commands: Array[EventCommand] = []
	for i in range(editable_page.commands.size()):
		if i != command_index:
			new_commands.append(editable_page.commands[i])

	editable_page.set("commands", new_commands)
	event_node.pages[page_index] = editable_page

	# Actualizar el árbol
	var commands_tree = _get_commands_tree_for_page(page_index)
	if commands_tree:
		_update_commands_tree(commands_tree, editable_page, page_index)
		# Deseleccionar cualquier comando seleccionado
		commands_tree.deselect_all()

	# Actualizar el estado de los botones (desactivarlos)
	_update_buttons_state(page_index, false, false, false, false, false)

	_refresh_inspector()
	print("Event Editor: Comando nuevo cancelado y eliminado")

func _reselect_node_for_refresh(node: Node) -> void:
	if not node or not is_instance_valid(node) or not editor_interface:
		return

	var selection = editor_interface.get_selection()
	if not selection:
		return

	if node in selection.get_selected_nodes():
		selection.remove_node(node)
		await get_tree().process_frame
		selection.add_node(node)

## Duplica las páginas del evento para que cada instancia tenga sus propias copias
## Esto evita que los cambios se propaguen a la escena origen
## Solo duplica si las páginas son Resources compartidos (tienen resource_path)
func _duplicate_event_pages() -> void:
	if not event_node or not "pages" in event_node:
		return

	var duplicated_pages: Array[EventPage] = []
	for page in event_node.pages:
		if page:
			# Solo duplicar si la página es un Resource compartido (tiene resource_path)
			# Si ya es local a la escena, no necesita duplicarse
			if page.resource_path != "":
				var duplicated_page = page.duplicate(true) as EventPage
				# Marcar como local a la escena para que no se guarde como archivo separado
				duplicated_page.take_over_path("")
				duplicated_pages.append(duplicated_page)
			else:
				# Ya es local, usar directamente
				duplicated_pages.append(page)
		else:
			duplicated_pages.append(null)

	# Actualizar el array de páginas con las duplicadas
	# En el editor, los placeholders no permiten asignar arrays tipados directamente
	# Así que actualizamos elemento por elemento
	if duplicated_pages.size() != event_node.pages.size():
		# Si el tamaño es diferente, necesitamos usar set() o modificar el array
		# Primero, limpiar el array existente
		while event_node.pages.size() > 0:
			event_node.pages.pop_back()
		# Luego añadir las nuevas páginas
		for page in duplicated_pages:
			event_node.pages.append(page)
	else:
		# Si el tamaño es igual, actualizar elemento por elemento
		for i in range(duplicated_pages.size()):
			event_node.pages[i] = duplicated_pages[i]

## Guarda una copia de seguridad del evento original
func _save_event_backup() -> void:
	if not event_node:
		return

	# Verificar que el evento tiene la propiedad pages
	if not "pages" in event_node:
		return

	original_event_backup.clear()

	# Hacer una copia profunda de todas las páginas
	for page in event_node.pages:
		if page:
			# Duplicar la página con todos sus recursos anidados
			var page_copy = page.duplicate(true) as EventPage
			original_event_backup.append(page_copy)
		else:
			original_event_backup.append(null)

## Restaura el evento desde la copia de seguridad
func _restore_event_from_backup() -> void:
	if not event_node:
		return

	# Verificar que el evento tiene la propiedad pages
	if not "pages" in event_node:
		return

	if original_event_backup.is_empty():
		return

	# Restaurar todas las páginas desde la copia
	var restored_pages: Array[EventPage] = []
	for page_copy in original_event_backup:
		if page_copy:
			# Duplicar la copia para evitar referencias compartidas
			var restored_page = page_copy.duplicate(true) as EventPage
			restored_pages.append(restored_page)
		else:
			restored_pages.append(null)

	# Aplicar las páginas restauradas
	# En el editor, los placeholders no permiten asignar arrays tipados directamente
	# Así que actualizamos elemento por elemento
	if restored_pages.size() != event_node.pages.size():
		# Si el tamaño es diferente, necesitamos modificar el array
		# Primero, limpiar el array existente
		while event_node.pages.size() > 0:
			event_node.pages.pop_back()
		# Luego añadir las nuevas páginas
		for page in restored_pages:
			event_node.pages.append(page)
	else:
		# Si el tamaño es igual, actualizar elemento por elemento
		for i in range(restored_pages.size()):
			event_node.pages[i] = restored_pages[i]

	# Actualizar el árbol de comandos en todas las pestañas
	for i in range(restored_pages.size()):
		var commands_tree = _get_commands_tree_for_page(i)
		if commands_tree:
			_update_commands_tree(commands_tree, restored_pages[i], i)

	_refresh_inspector()
	print("Event Editor: Evento restaurado desde la copia de seguridad")

## Marca que ha habido cambios en el evento
func _mark_as_changed() -> void:
	has_unsaved_changes = true

## Verifica si hay cambios sin guardar
func _has_changes() -> bool:
	return has_unsaved_changes

## Muestra un diálogo de confirmación antes de cancelar
func _show_cancel_confirmation_dialog() -> void:
	# Solo mostrar el diálogo si hay cambios
	if not _has_changes():
		queue_free()
		return

	var dialog = AcceptDialog.new()
	dialog.title = "Cerrar Editor"
	dialog.dialog_text = "¿Qué deseas hacer con los cambios realizados?"

	# Ocultar el botón OK por defecto
	dialog.get_ok_button().visible = false

	# Añadir botones personalizados
	var save_button = dialog.add_button("Guardar cambios", true, "save")
	var discard_button = dialog.add_button("Descartar cambios", false, "discard")
	var cancel_button = dialog.add_button("Cancelar", false, "cancel")

	add_child(dialog)

	# Conectar señales
	dialog.confirmed.connect(func():
		# Si se presiona el botón por defecto (no debería pasar)
		dialog.queue_free()
	)

	dialog.custom_action.connect(func(action: String):
		match action:
			"save":
				_on_save_and_close()
			"discard":
				_on_discard_confirmed()
			"cancel":
				# No hacer nada, mantener el editor abierto
				pass
		dialog.queue_free()
	)

	dialog.close_requested.connect(func():
		# Si se cierra el diálogo sin elegir, no hacer nada (mantener el editor abierto)
		dialog.queue_free()
	)

	dialog.popup_centered()

func _on_discard_confirmed() -> void:
	# Restaurar el evento desde la copia de seguridad
	_restore_event_from_backup()
	has_unsaved_changes = false  # Resetear bandera después de descartar
	_refresh_inspector()
	await get_tree().process_frame
	queue_free()

func _on_save_and_close() -> void:
	# Guardar cambios y cerrar (igual que el botón Guardar)
	_refresh_inspector()

	# Limpiar páginas null del array antes de guardar
	_clean_null_pages()

	has_unsaved_changes = false  # Resetear bandera después de guardar

	# Registrar la escena en la lista de escenas modificadas
	_register_modified_scene()

	await get_tree().process_frame
	queue_free()

## Añade un botón "Añadir Página" justo antes del TabContainer
func _add_new_page_button() -> void:
	# Buscar el VBoxContainer principal
	var vbox = $VBoxContainer
	if not vbox:
		return

	# Verificar si el botón ya existe (para evitar duplicados)
	for child in vbox.get_children():
		if child is HBoxContainer:
			# Verificar si contiene el botón "Añadir Página"
			for button in child.get_children():
				if button is Button and button.text == "+ Añadir Página":
					return  # Ya existe, no crear otro

	# Buscar el TabContainer
	var tab_container_node = vbox.get_node_or_null("TabContainer")
	if not tab_container_node:
		return

	# Crear un HBoxContainer para el botón en la parte superior
	var buttons_container = HBoxContainer.new()
	buttons_container.name = "AddPageButtonContainer"
	buttons_container.add_theme_constant_override("separation", 10)
	buttons_container.add_theme_constant_override("margin_bottom", 5)

	# Botón para cambiar el nombre del nodo Event
	var change_name_button = Button.new()
	change_name_button.text = "Cambiar Nombre"
	change_name_button.pressed.connect(_on_change_event_name_button_pressed)
	buttons_container.add_child(change_name_button)

	# Separador
	buttons_container.add_child(HSeparator.new())

	var add_page_button = Button.new()
	add_page_button.text = "+ Añadir Página"
	add_page_button.pressed.connect(_on_add_page_button_pressed)
	buttons_container.add_child(add_page_button)

	var duplicate_page_button = Button.new()
	duplicate_page_button.text = "Duplicar Página"
	duplicate_page_button.pressed.connect(_on_duplicate_page_button_pressed)
	buttons_container.add_child(duplicate_page_button)

	var delete_page_button = Button.new()
	delete_page_button.text = "Eliminar Página"
	delete_page_button.pressed.connect(_on_delete_page_button_pressed)
	buttons_container.add_child(delete_page_button)

	# Separador
	buttons_container.add_child(HSeparator.new())

	# Botones para mover páginas
	var move_left_button = Button.new()
	move_left_button.text = "← Mover Izquierda"
	move_left_button.pressed.connect(_on_move_page_left_pressed)
	buttons_container.add_child(move_left_button)

	var move_right_button = Button.new()
	move_right_button.text = "Mover Derecha →"
	move_right_button.pressed.connect(_on_move_page_right_pressed)
	buttons_container.add_child(move_right_button)

	# Guardar referencias a los botones para poder habilitarlos/deshabilitarlos
	if not has_meta("page_management_buttons"):
		set_meta("page_management_buttons", {
			"add": add_page_button,
			"duplicate": duplicate_page_button,
			"delete": delete_page_button,
			"move_left": move_left_button,
			"move_right": move_right_button
		})

	# Añadir un spacer para empujar los botones a la izquierda
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons_container.add_child(spacer)

	# Actualizar estado inicial de los botones
	_update_page_management_buttons_state()

	# Insertar el contenedor de botones justo antes del TabContainer
	var tab_index = tab_container_node.get_index()
	vbox.add_child(buttons_container)
	vbox.move_child(buttons_container, tab_index)

## Añade un botón "Guardar" en la interfaz
func _add_save_button() -> void:
	# Buscar el VBoxContainer principal
	var vbox = $VBoxContainer
	if not vbox:
		return

	# Crear un HBoxContainer para los botones en la parte inferior
	var buttons_container = HBoxContainer.new()
	buttons_container.alignment = BoxContainer.ALIGNMENT_END
	buttons_container.add_theme_constant_override("separation", 10)
	buttons_container.add_theme_constant_override("margin_top", 10)

	var save_button = Button.new()
	save_button.text = "Guardar y Cerrar"
	save_button.pressed.connect(_on_save_button_pressed)
	buttons_container.add_child(save_button)

	vbox.add_child(buttons_container)

## Se llama cuando se presiona el botón "Cambiar Nombre"
func _on_change_event_name_button_pressed() -> void:
	if not _validate_event_node():
		return

	# Crear un diálogo para cambiar el nombre
	var dialog = AcceptDialog.new()
	dialog.title = "Cambiar Nombre del Evento"
	dialog.dialog_text = "Introduce el nuevo nombre:"

	# Crear un LineEdit para el nombre
	var name_input = LineEdit.new()
	name_input.text = event_node.name
	name_input.placeholder_text = "Nombre del evento"
	name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_input.custom_minimum_size = Vector2(300, 0)

	# Crear un Label de error (inicialmente oculto)
	var error_label = Label.new()
	error_label.name = "ErrorLabel"
	error_label.text = ""
	error_label.add_theme_color_override("font_color", Color.RED)
	error_label.visible = false
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	error_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	error_label.custom_minimum_size = Vector2(0, 0)
	error_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Limitar el ancho máximo para evitar que el diálogo se expanda demasiado
	error_label.max_lines_visible = 3

	# Crear un VBoxContainer para el contenido
	var content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.custom_minimum_size = Vector2(350, 0)
	content.add_child(Label.new())
	content.get_child(0).text = "Nombre del evento:"
	content.add_child(name_input)
	content.add_child(error_label)

	# Añadir el contenido al diálogo
	dialog.add_child(content)
	add_child(dialog)

	# Conectar señales
	dialog.confirmed.connect(func(): _on_name_dialog_confirmed(dialog, name_input, error_label))
	dialog.canceled.connect(func(): dialog.queue_free())

	# Mostrar el diálogo
	dialog.popup_centered(Vector2(400, 150))

	# Enfocar el LineEdit cuando se muestre el diálogo
	await get_tree().process_frame
	name_input.grab_focus()
	name_input.select_all()

## Muestra un diálogo de error (usado con call_deferred para evitar conflictos con ventanas modales)
func _show_error_dialog(message: String) -> void:
	var error_dialog = AcceptDialog.new()
	error_dialog.title = "Error"
	error_dialog.dialog_text = message
	add_child(error_dialog)
	error_dialog.popup_centered(Vector2(400, 100))
	error_dialog.confirmed.connect(func(): error_dialog.queue_free())

## Verifica si ya existe un evento/NPC/Trainer con el nombre especificado en el mapa
func _event_name_exists_in_map(name: String, exclude_node: Node = null) -> bool:
	if not event_node:
		return false

	# Buscar el nodo padre "Events"
	var events_node = event_node.get_parent()
	if not events_node or events_node.name != "Events":
		return false

	# Buscar todos los hijos del nodo Events
	for child in events_node.get_children():
		# Excluir el nodo que estamos modificando
		if exclude_node and child == exclude_node:
			continue

		# Verificar si el nombre coincide
		if child.name == name:
			return true

	return false

## Se llama cuando se confirma el diálogo de cambiar nombre
func _on_name_dialog_confirmed(dialog: AcceptDialog, name_input: LineEdit, error_label: Label) -> void:
	var new_name = name_input.text.strip_edges()

	# Ocultar el error anterior
	error_label.visible = false
	error_label.text = ""

	if new_name.is_empty():
		# Mostrar error si el nombre está vacío (sin cerrar el diálogo de nombre)
		error_label.text = "El nombre no puede estar vacío."
		error_label.visible = true
		# No cerrar el diálogo de nombre, dejar que el usuario corrija
		return

	if new_name == event_node.name:
		# Si el nombre no cambió, solo cerrar el diálogo
		dialog.queue_free()
		return

	# Verificar si ya existe un evento con ese nombre
	if _event_name_exists_in_map(new_name, event_node):
		# Mostrar el error (sin cerrar el diálogo de nombre)
		error_label.text = "Ya existe un evento/NPC/Trainer con el nombre '" + new_name + "' en el mapa."
		error_label.visible = true
		# No cerrar el diálogo de nombre, dejar que el usuario corrija
		return

	# Cambiar el nombre del nodo
	event_node.name = new_name

	# Actualizar el título de la ventana
	title = "Event Editor - " + event_node.name

	# Marcar la escena como modificada
	if editor_interface:
		editor_interface.mark_scene_as_unsaved()

	# Cerrar el diálogo
	dialog.queue_free()

## Se llama cuando se presiona el botón "Añadir Página"
func _on_add_page_button_pressed() -> void:
	if not _validate_event_node():
		return

	# Crear una nueva página con valores por defecto
	var new_page = EventPage.new()
	new_page.execution_mode = EventPage.ExecutionMode.QUEUED
	new_page.blocks_player = true
	new_page.through = false
	# commands ya está inicializado como Array[EventCommand]() por defecto
	new_page.root_condition = null
	# Por defecto, crear un ActionTrigger (puede cambiarse a null si se desea)
	var action_trigger_script = load("res://Scripts/Events/Triggers/ActionTrigger.gd")
	if action_trigger_script:
		var default_trigger = action_trigger_script.new()
		if default_trigger is ActionTrigger:
			new_page.trigger = default_trigger as ActionTrigger
		else:
			new_page.trigger = null
	else:
		new_page.trigger = null

	# Añadir la nueva página al array de páginas del evento
	event_node.pages.append(new_page)

	# Marcar como cambiado
	_mark_as_changed()

	# Refrescar las pestañas
	_clear_tabs()
	# Esperar un frame para asegurar que los nodos se eliminen completamente
	await get_tree().process_frame
	_create_page_tabs()

	# Cambiar a la nueva pestaña (la última)
	var new_page_index = event_node.pages.size() - 1
	if tab_container:
		tab_container.current_tab = new_page_index

	# Actualizar estado de los botones
	_update_page_management_buttons_state()

## Se llama cuando se presiona el botón "Duplicar Página"
func _on_duplicate_page_button_pressed() -> void:
	if not _validate_event_node():
		return

	var current_tab = tab_container.current_tab if tab_container else -1
	if current_tab < 0 or current_tab >= event_node.pages.size():
		return

	# Obtener la página actual
	var page_to_duplicate = event_node.pages[current_tab]
	if not page_to_duplicate:
		return

	# Duplicar la página
	var duplicated_page = page_to_duplicate.duplicate(true) as EventPage
	if not duplicated_page:
		push_error("Event Editor: No se pudo duplicar la página")
		return

	# Añadir la página duplicada después de la página actual
	event_node.pages.insert(current_tab + 1, duplicated_page)

	# Marcar como cambiado
	_mark_as_changed()

	# Refrescar las pestañas
	_clear_tabs()
	# Esperar un frame para asegurar que los nodos se eliminen completamente
	await get_tree().process_frame
	_create_page_tabs()

	# Cambiar a la nueva pestaña duplicada
	if tab_container:
		tab_container.current_tab = current_tab + 1

	# Actualizar estado de los botones
	_update_page_management_buttons_state()

## Se llama cuando se presiona el botón "Eliminar Página"
func _on_delete_page_button_pressed() -> void:
	if not _validate_event_node():
		return

	var current_tab = tab_container.current_tab if tab_container else -1
	if current_tab < 0 or current_tab >= event_node.pages.size():
		return

	# Verificar que no sea la última página (debe quedar al menos una)
	if event_node.pages.size() <= 1:
		_show_message_dialog("No se puede eliminar la última página. El evento debe tener al menos una página.")
		return

	# Mostrar diálogo de confirmación
	var page_number = current_tab + 1
	_show_delete_page_confirmation_dialog(page_number, current_tab)

## Muestra un diálogo de confirmación para eliminar una página
func _show_delete_page_confirmation_dialog(page_number: int, page_index: int) -> void:
	var dialog = AcceptDialog.new()
	dialog.title = "Confirmar Eliminación"
	dialog.dialog_text = "¿Estás seguro de que quieres eliminar la página %d?" % page_number

	var ok_button = dialog.get_ok_button()
	ok_button.hide()

	var delete_button = dialog.add_button("Eliminar", false, "ok")
	var cancel_button = dialog.add_button("Cancelar", true, "cancel")

	dialog.custom_action.connect(func(action: String):
		if action == "ok":
			_perform_delete_page(page_index)
		dialog.queue_free()
	)

	add_child(dialog)
	dialog.exclusive = true
	dialog.popup_centered()

## Realiza la eliminación de la página
func _perform_delete_page(page_index: int) -> void:
	if page_index < 0 or page_index >= event_node.pages.size():
		return

	# Eliminar la página
	event_node.pages.remove_at(page_index)

	# Marcar como cambiado
	_mark_as_changed()

	# Refrescar las pestañas
	_clear_tabs()
	# Esperar un frame para asegurar que los nodos se eliminen completamente
	await get_tree().process_frame
	_create_page_tabs()

	# Ajustar el tab actual si es necesario
	if tab_container:
		if tab_container.get_tab_count() > 0:
			# Si eliminamos la última página, cambiar a la anterior
			if page_index >= tab_container.get_tab_count():
				tab_container.current_tab = tab_container.get_tab_count() - 1
			else:
				tab_container.current_tab = page_index
		else:
			tab_container.current_tab = 0

	# Actualizar estado de los botones
	_update_page_management_buttons_state()

## Actualiza el estado de los botones de gestión de páginas
func _update_page_management_buttons_state() -> void:
	if not has_meta("page_management_buttons"):
		return

	var buttons = get_meta("page_management_buttons")
	var has_pages = event_node and event_node.pages.size() > 0
	var current_tab = tab_container.current_tab if tab_container else -1
	var total_pages = event_node.pages.size() if event_node else 0

	# El botón de añadir siempre está habilitado
	if buttons.has("add"):
		buttons.add.disabled = false

	# Los botones de duplicar y eliminar solo están habilitados si hay páginas
	if buttons.has("duplicate"):
		buttons.duplicate.disabled = not has_pages
	if buttons.has("delete"):
		buttons.delete.disabled = not has_pages

	# Los botones de mover: izquierda deshabilitado si es la primera, derecha si es la última
	if buttons.has("move_left"):
		buttons.move_left.disabled = not has_pages or current_tab <= 0
	if buttons.has("move_right"):
		buttons.move_right.disabled = not has_pages or current_tab < 0 or current_tab >= total_pages - 1

## Se llama cuando se presiona el botón "Mover Izquierda"
func _on_move_page_left_pressed() -> void:
	if not _validate_event_node():
		return

	var current_tab = tab_container.current_tab if tab_container else -1
	if current_tab <= 0 or current_tab >= event_node.pages.size():
		return

	# Intercambiar la página actual con la anterior
	var temp_page = event_node.pages[current_tab]
	event_node.pages[current_tab] = event_node.pages[current_tab - 1]
	event_node.pages[current_tab - 1] = temp_page

	# Marcar como cambiado
	_mark_as_changed()

	# Refrescar las pestañas
	_clear_tabs()
	# Esperar un frame para asegurar que los nodos se eliminen completamente
	await get_tree().process_frame
	_create_page_tabs()

	# Cambiar a la nueva posición (una posición a la izquierda)
	if tab_container:
		tab_container.current_tab = current_tab - 1

	# Actualizar estado de los botones
	_update_page_management_buttons_state()

## Se llama cuando se presiona el botón "Mover Derecha"
func _on_move_page_right_pressed() -> void:
	if not _validate_event_node():
		return

	var current_tab = tab_container.current_tab if tab_container else -1
	if current_tab < 0 or current_tab >= event_node.pages.size() - 1:
		return

	# Intercambiar la página actual con la siguiente
	var temp_page = event_node.pages[current_tab]
	event_node.pages[current_tab] = event_node.pages[current_tab + 1]
	event_node.pages[current_tab + 1] = temp_page

	# Marcar como cambiado
	_mark_as_changed()

	# Refrescar las pestañas
	_clear_tabs()
	# Esperar un frame para asegurar que los nodos se eliminen completamente
	await get_tree().process_frame
	_create_page_tabs()

	# Cambiar a la nueva posición (una posición a la derecha)
	if tab_container:
		tab_container.current_tab = current_tab + 1

	# Actualizar estado de los botones
	_update_page_management_buttons_state()

## Muestra un mensaje de diálogo simple
func _show_message_dialog(message: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.title = "Información"
	dialog.dialog_text = message
	dialog.ok_button_text = "Aceptar"
	dialog.confirmed.connect(func(): dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())

	add_child(dialog)
	dialog.exclusive = true
	dialog.popup_centered()

func _on_save_button_pressed() -> void:
	_refresh_inspector()

	# Limpiar páginas null del array antes de guardar
	_clean_null_pages()

	has_unsaved_changes = false  # Resetear bandera después de guardar

	# Registrar la escena en la lista de escenas modificadas
	_register_modified_scene()

	await get_tree().process_frame
	queue_free()

## Limpia las páginas null del array al abrir el editor (sin await)
func _clean_null_pages_on_open() -> void:
	if not event_node or not "pages" in event_node:
		return

	var cleaned_pages: Array[EventPage] = []
	for page in event_node.pages:
		if page:  # Solo añadir páginas que no sean null
			cleaned_pages.append(page)

	# Si se eliminaron páginas null, actualizar el array
	# En el editor, los placeholders no permiten asignar arrays tipados directamente
	# Así que actualizamos elemento por elemento
	if cleaned_pages.size() != event_node.pages.size():
		# Primero, limpiar el array existente
		while event_node.pages.size() > 0:
			event_node.pages.pop_back()
		# Luego añadir las nuevas páginas
		for page in cleaned_pages:
			event_node.pages.append(page)
		_mark_as_changed()

## Limpia las páginas null del array antes de guardar
func _clean_null_pages() -> void:
	if not event_node or not "pages" in event_node:
		return

	var cleaned_pages: Array[EventPage] = []
	for page in event_node.pages:
		if page:  # Solo añadir páginas que no sean null
			cleaned_pages.append(page)

	# Si se eliminaron páginas null, actualizar el array
	# En el editor, los placeholders no permiten asignar arrays tipados directamente
	# Así que actualizamos elemento por elemento
	if cleaned_pages.size() != event_node.pages.size():
		# Primero, limpiar el array existente
		while event_node.pages.size() > 0:
			event_node.pages.pop_back()
		# Luego añadir las nuevas páginas
		for page in cleaned_pages:
			event_node.pages.append(page)
		_mark_as_changed()

## Marca la escena actual como pendiente de guardar
func _register_modified_scene() -> void:
	# EditorInterface es un singleton, accesible directamente
	var edited_scene_root = EditorInterface.get_edited_scene_root()
	if not edited_scene_root or edited_scene_root.scene_file_path == "":
		return

	# Marcar la escena como no guardada usando EditorInterface
	# Esto mostrará el asterisco (*) en la pestaña de la escena
	# El método no toma argumentos, marca la escena actualmente abierta
	EditorInterface.mark_scene_as_unsaved()
	print("Event Tools: Escena marcada como no guardada: %s" % edited_scene_root.scene_file_path)

