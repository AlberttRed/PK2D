@tool
extends Window

## Ventana de edición de eventos
## Muestra las páginas del evento en pestañas

var event_node: Node = null
var tab_container: TabContainer = null
var page_buttons: Dictionary = {}  # page_index -> {add: Button, edit: Button, delete: Button}
var editor_interface: EditorInterface = null

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

	if has_meta("pending_event_node"):
		event_node = get_meta("pending_event_node")
		remove_meta("pending_event_node")

	if has_meta("editor_interface"):
		editor_interface = get_meta("editor_interface")
		remove_meta("editor_interface")

	if event_node:
		_setup_for_event()

func _setup_for_event() -> void:
	if not _validate_event_node():
		return

	title = "Event Editor - " + event_node.name
	_clear_tabs()
	_create_page_tabs()
	popup_centered()

func _clear_tabs() -> void:
	if not tab_container:
		return
	for child in tab_container.get_children():
		child.queue_free()
	page_buttons.clear()

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
		_create_page_tab(i, pages[i])

func _create_page_tab(page_index: int, page: EventPage) -> void:
	var main_split = HSplitContainer.new()
	main_split.name = "Page" + str(page_index)

	var left_panel = _create_left_panel(page_index, page)
	var right_panel = _create_right_panel(page_index, page)

	main_split.add_child(left_panel)
	main_split.add_child(right_panel)
	tab_container.add_child(main_split)
	tab_container.set_tab_title(page_index, "Página " + str(page_index + 1))

func _create_left_panel(page_index: int, page: EventPage) -> VBoxContainer:
	var left_panel = VBoxContainer.new()

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

	# Botón de condiciones
	var conditions_button = Button.new()
	conditions_button.text = "Gestionar Condiciones"
	conditions_button.pressed.connect(func(): _on_conditions_button_pressed(page_index))
	left_panel.add_child(conditions_button)

	return left_panel

func _create_right_panel(page_index: int, page: EventPage) -> VBoxContainer:
	var right_panel = VBoxContainer.new()

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

	buttons_container.add_child(add_button)
	buttons_container.add_child(edit_button)
	buttons_container.add_child(delete_button)
	right_panel.add_child(buttons_container)

	page_buttons[page_index] = {"add": add_button, "edit": edit_button, "delete": delete_button}

	var commands_container = PanelContainer.new()
	commands_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	commands_container.mouse_filter = Control.MOUSE_FILTER_STOP

	var commands_tree = Tree.new()
	commands_tree.name = "CommandsTree"
	commands_tree.select_mode = Tree.SELECT_SINGLE
	commands_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	commands_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	commands_tree.item_selected.connect(func(): _on_command_selected(page_index))
	commands_tree.nothing_selected.connect(func(): _on_command_deselected(page_index))
	commands_tree.item_activated.connect(func(): _on_edit_command_pressed(page_index))
	commands_tree.gui_input.connect(func(event): _on_commands_tree_gui_input(page_index, event))
	_update_commands_tree(commands_tree, page)
	commands_container.add_child(commands_tree)

	right_panel.add_child(commands_container)
	return right_panel

func _create_spacer(height: int) -> Control:
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer

# === HELPERS DE VALIDACIÓN ===
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
func _update_commands_tree(commands_tree: Tree, page: EventPage) -> void:
	if not commands_tree:
		return

	commands_tree.clear()
	var root = commands_tree.create_item()

	if not page:
		root.set_text(0, "Página - (Sin página)")
		return

	if page.commands.is_empty():
		root.set_text(0, "Página - (Sin comandos)")
		return

	root.set_text(0, "Página")
	for i in range(page.commands.size()):
		var command = page.commands[i]
		if not command:
			var item = commands_tree.create_item(root)
			item.set_text(0, str(i + 1) + ". (null)")
			continue

		var command_name = _get_command_name_safe(command)
		var item = commands_tree.create_item(root)
		item.set_text(0, str(i + 1) + ". " + command_name)
		item.set_metadata(0, {"type": "command", "index": i, "command": command})
		_add_nested_commands_to_tree(item, command)

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

func _add_nested_commands_to_tree(parent_item: TreeItem, command: EventCommand) -> void:
	if command is ConditionalCommand:
		var cond_cmd = command as ConditionalCommand
		for branch_idx in range(cond_cmd.branches.size()):
			var branch = cond_cmd.branches[branch_idx]
			var branch_item = parent_item.get_tree().create_item(parent_item)
			var condition_text = "ELSE"
			if branch.condition:
				condition_text = _get_command_name_safe(branch.condition)
			branch_item.set_text(0, "  └─ Branch " + str(branch_idx) + " (" + condition_text + ")")
			branch_item.set_metadata(0, {"type": "branch", "branch": branch, "parent_command": command})
			_add_nested_commands_from_array(branch_item, branch.commands)

	elif command is ShowChoicesCommand:
		var choices_cmd = command as ShowChoicesCommand
		for branch_idx in range(choices_cmd.branches.size()):
			var branch = choices_cmd.branches[branch_idx]
			var branch_item = parent_item.get_tree().create_item(parent_item)
			branch_item.set_text(0, "  └─ Choice: \"" + branch.label + "\"")
			branch_item.set_metadata(0, {"type": "choice_branch", "branch": branch, "parent_command": command})
			_add_nested_commands_from_array(branch_item, branch.commands)

	elif command is SwitchCommand:
		var switch_cmd = command as SwitchCommand
		for case_idx in range(switch_cmd.cases.size()):
			var case = switch_cmd.cases[case_idx]
			var case_item = parent_item.get_tree().create_item(parent_item)
			case_item.set_text(0, "  └─ Case: " + str(case.values))
			case_item.set_metadata(0, {"type": "switch_case", "case": case, "parent_command": command})
			_add_nested_commands_from_array(case_item, case.commands)

		if switch_cmd.default_commands.size() > 0:
			var default_item = parent_item.get_tree().create_item(parent_item)
			default_item.set_text(0, "  └─ Default")
			default_item.set_metadata(0, {"type": "default_commands", "parent_command": command})
			_add_nested_commands_from_array(default_item, switch_cmd.default_commands)

func _add_nested_commands_from_array(parent_item: TreeItem, commands: Array) -> void:
	for cmd_idx in range(commands.size()):
		var nested_cmd = commands[cmd_idx]
		if nested_cmd:
			var cmd_item = parent_item.get_tree().create_item(parent_item)
			cmd_item.set_text(0, "    └─ " + _get_command_name_safe(nested_cmd))
			cmd_item.set_metadata(0, {"type": "nested_command", "command": nested_cmd, "parent_branch": parent_item.get_metadata(0)})
			_add_nested_commands_to_tree(cmd_item, nested_cmd)

# === CALLBACKS DE CAMBIOS ===
func _on_execution_mode_changed(page_index: int, selected_index: int) -> void:
	var page = _get_page(page_index)
	if page:
		page.execution_mode = selected_index

func _on_blocks_player_changed(page_index: int, pressed: bool) -> void:
	var page = _get_page(page_index)
	if page:
		page.blocks_player = pressed

func _on_through_changed(page_index: int, pressed: bool) -> void:
	var page = _get_page(page_index)
	if page:
		page.through = pressed

func _on_conditions_button_pressed(page_index: int) -> void:
	print("Event Editor: Gestionar condiciones para página ", page_index + 1)
	# TODO: Abrir editor de condiciones

# === GESTIÓN DE COMANDOS ===
func _on_command_selected(page_index: int) -> void:
	var commands_tree = _get_commands_tree_for_page(page_index)
	if not commands_tree:
		return

	var selected_item = commands_tree.get_selected()
	var can_edit_delete = false

	if selected_item:
		var metadata = selected_item.get_metadata(0)
		if metadata and metadata.has("type"):
			var item_type = metadata.type
			can_edit_delete = item_type in ["command", "nested_command", "branch", "choice_branch", "switch_case", "default_commands"]

	_update_buttons_state(page_index, can_edit_delete)

func _on_command_deselected(page_index: int) -> void:
	_update_buttons_state(page_index, false)

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
		_update_buttons_state(page_index, false)

	_show_commands_context_menu(page_index, global_pos)

func _show_commands_context_menu(page_index: int, global_position: Vector2) -> void:
	var page = _get_page(page_index)
	if not page:
		return

	var commands_tree = _get_commands_tree_for_page(page_index)
	if not commands_tree:
		return

	var selected_item = commands_tree.get_selected()
	var metadata = selected_item.get_metadata(0) if selected_item else null
	var item_type = metadata.type if metadata and metadata.has("type") else ""

	var can_add = item_type in ["", "page_root"]
	var can_edit = item_type in ["command", "nested_command", "branch", "choice_branch", "switch_case", "default_commands"]
	var can_delete = can_edit

	var context_menu = PopupMenu.new()
	if can_add:
		context_menu.add_item("Añadir Comando", 0)
	if can_edit:
		context_menu.add_item("Editar", 1)
	if can_delete:
		context_menu.add_item("Eliminar", 2)

	add_child(context_menu)
	context_menu.id_pressed.connect(func(id): _on_context_menu_item_selected(page_index, id, selected_item); context_menu.queue_free())
	context_menu.popup_hide.connect(func(): context_menu.queue_free())
	context_menu.popup(Rect2(global_position, Vector2.ZERO))

func _on_context_menu_item_selected(page_index: int, menu_id: int, selected_item: TreeItem) -> void:
	match menu_id:
		0: _on_add_command_pressed(page_index)
		1: _on_edit_command_pressed(page_index)
		2: _on_delete_command_pressed(page_index)

func _on_add_command_pressed(page_index: int) -> void:
	if not _get_page(page_index):
		return
	_show_add_command_dialog(page_index)

func _on_edit_command_pressed(page_index: int) -> void:
	var page = _get_page(page_index)
	if not page:
		return

	var commands_tree = _get_commands_tree_for_page(page_index)
	var selected_item = commands_tree.get_selected() if commands_tree else null
	if not selected_item:
		print("Event Editor: No hay comando seleccionado para editar")
		return

	var metadata = selected_item.get_metadata(0)
	if not metadata or not metadata.has("type"):
		print("Event Editor: Item seleccionado no es un comando")
		return

	print("Event Editor: Editar ", metadata.type)
	# TODO: Abrir editor de item

func _on_delete_command_pressed(page_index: int) -> void:
	_show_delete_confirmation_dialog(page_index)

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
		_update_commands_tree(commands_tree, editable_page)
		_update_buttons_state(page_index, false)

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
	var parent_item = commands_tree.get_selected().get_parent()
	if not parent_item:
		return false

	var parent_metadata = parent_item.get_metadata(0)
	if not parent_metadata or not parent_metadata.has("type"):
		return false

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
	var command_to_remove = metadata.command

	var parent_type = parent_metadata.type
	var commands_array = null

	if parent_type == "branch" and main_command is ConditionalCommand:
		commands_array = parent_metadata.branch.commands
	elif parent_type == "choice_branch" and main_command is ShowChoicesCommand:
		commands_array = parent_metadata.branch.commands
	elif parent_type == "switch_case" and main_command is SwitchCommand:
		commands_array = parent_metadata.case.commands
	elif parent_type == "default_commands" and main_command is SwitchCommand:
		commands_array = main_command.default_commands

	if commands_array:
		var new_commands = []
		for cmd in commands_array:
			if cmd != command_to_remove:
				new_commands.append(cmd)
		commands_array = new_commands
		return true

	return false

func _delete_branch(page: EventPage, metadata: Dictionary, commands_tree: Tree) -> bool:
	var parent_item = commands_tree.get_selected().get_parent()
	if not parent_item:
		return false

	var parent_metadata = parent_item.get_metadata(0)
	if not parent_metadata or parent_metadata.type != "command":
		return false

	var main_command = page.commands[parent_metadata.index]
	var branch_to_remove = metadata.branch

	if metadata.type == "branch" and main_command is ConditionalCommand:
		var new_branches = []
		for b in main_command.branches:
			if b != branch_to_remove:
				new_branches.append(b)
		main_command.branches = new_branches
		return true
	elif metadata.type == "choice_branch" and main_command is ShowChoicesCommand:
		var new_branches = []
		for b in main_command.branches:
			if b != branch_to_remove:
				new_branches.append(b)
		main_command.branches = new_branches
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
		var case_to_remove = metadata.case
		var new_cases = []
		for c in main_command.cases:
			if c != case_to_remove:
				new_cases.append(c)
		main_command.cases = new_cases
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

# === DIÁLOGO DE AÑADIR COMANDO ===
func _show_add_command_dialog(page_index: int) -> void:
	var command_types = [
		"ShowMessage", "SetFlag", "SetVariable", "SetSelfSwitch",
		"StartBattleEvent", "Warp", "ShowChoices", "Conditional",
		"Switch", "Wait", "Fade", "SetWeather", "SetDarkness",
		"SetFlashlight", "BlockPlayer", "UnblockPlayer", "SetEventThrough",
		"MoveNPC", "PlayAnimation", "SetActorVisibility", "ShowPortrait",
		"ClosePortrait", "FollowActor", "UseMO"
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
			_create_command_of_type(page_index, command_types[selected_items[0]] + "Command")
			dialog.queue_free()
	)

	command_list.item_selected.connect(func(idx): add_button.disabled = false)
	command_list.item_activated.connect(func(idx):
		_create_command_of_type(page_index, command_types[idx] + "Command")
		dialog.queue_free()
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

func _create_command_of_type(page_index: int, command_type_name: String) -> void:
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

	var new_commands_array: Array[EventCommand] = []
	for cmd in editable_page.commands:
		new_commands_array.append(cmd)
	new_commands_array.append(new_command)

	editable_page.set("commands", new_commands_array)
	event_node.pages[page_index] = editable_page

	var commands_tree = _get_commands_tree_for_page(page_index)
	if commands_tree:
		_update_commands_tree(commands_tree, editable_page)
		var root = commands_tree.get_root()
		if root:
			var children = root.get_children()
			if children:
				commands_tree.set_selected(children[-1], 0)

	print("Event Editor: Comando ", command_type_name, " añadido")

# === UTILIDADES ===
func _update_buttons_state(page_index: int, has_selection: bool) -> void:
	if not page_index in page_buttons:
		return

	var buttons = page_buttons[page_index]
	buttons.add.disabled = has_selection
	buttons.edit.disabled = not has_selection
	buttons.delete.disabled = not has_selection

func _get_commands_tree_for_page(page_index: int) -> Tree:
	if not tab_container or page_index >= tab_container.get_child_count():
		return null
	return _find_child_by_name(tab_container.get_child(page_index), "CommandsTree", Tree)

func _on_close_requested() -> void:
	_refresh_inspector()
	await get_tree().process_frame
	queue_free()

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
