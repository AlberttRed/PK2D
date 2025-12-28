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

func _setup_for_event() -> void:
	if not _validate_event_node():
		return

	title = "Event Editor - " + event_node.name
	_clear_tabs()

	# Guardar copia de seguridad de todas las páginas antes de editar
	_save_event_backup()
	has_unsaved_changes = false  # Inicializar bandera de cambios

	_create_page_tabs()
	# Añadir botón Guardar en la interfaz
	_add_save_button()
	popup_centered()

func _clear_tabs() -> void:
	if not tab_container:
		return
	for child in tab_container.get_children():
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

	# Guardar referencias a los controles
	page_controls[page_index] = {
		"execution_option": execution_option,
		"trigger_option": trigger_option,
		"blocks_player_check": blocks_player_check,
		"through_check": through_check,
		"conditions_button": conditions_button
	}

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

	if page.commands.is_empty():
		root.set_text(0, "Página - (Sin comandos)")
		return

	root.set_text(0, "Página")
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
		item.set_text(0, str(i + 1) + ". " + command_name)
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

func _add_nested_commands_to_tree(parent_item: TreeItem, command: EventCommand, page_index: int = -1, move_info: Dictionary = {}, in_move_mode: bool = false) -> void:
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

			if in_move_mode:
				_apply_move_mode_style(branch_item, move_info, page_index)

			_add_nested_commands_from_array(branch_item, branch.commands, page_index, move_info, in_move_mode)

	elif command is ShowChoicesCommand:
		var choices_cmd = command as ShowChoicesCommand
		for branch_idx in range(choices_cmd.branches.size()):
			var branch = choices_cmd.branches[branch_idx]
			var branch_item = parent_item.get_tree().create_item(parent_item)
			branch_item.set_text(0, "  └─ Choice: \"" + branch.label + "\"")
			branch_item.set_metadata(0, {"type": "choice_branch", "branch": branch, "parent_command": command})

			if in_move_mode:
				_apply_move_mode_style(branch_item, move_info, page_index)

			_add_nested_commands_from_array(branch_item, branch.commands, page_index, move_info, in_move_mode)

	elif command is SwitchCommand:
		var switch_cmd = command as SwitchCommand
		for case_idx in range(switch_cmd.cases.size()):
			var case = switch_cmd.cases[case_idx]
			var case_item = parent_item.get_tree().create_item(parent_item)
			case_item.set_text(0, "  └─ Case: " + str(case.values))
			case_item.set_metadata(0, {"type": "switch_case", "case": case, "parent_command": command})

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
			cmd_item.set_text(0, "    └─ " + _get_command_name_safe(nested_cmd))
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
								cond_cmd.branches[branch_index].commands.append(command_to_move_obj)
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
								choices_cmd.branches[branch_index].commands.append(command_to_move_obj)
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
								switch_cmd.cases[case_index].commands.append(command_to_move_obj)
					elif destination_type == "default_commands" and cmd is SwitchCommand:
						var switch_cmd = cmd as SwitchCommand
						switch_cmd.default_commands.append(command_to_move_obj)

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
		if destination_type in ["branch", "choice_branch", "switch_case", "default_commands"]:
			var parent_command = destination_metadata.get("parent_command")
			if parent_command:
				# Encontrar el índice del comando padre en la página original
				if original_page:
					for i in range(original_page.commands.size()):
						if original_page.commands[i] == parent_command:
							parent_cmd_index = i
							break

		# Remover del nivel principal
		editable_page.commands.remove_at(command_index)

		# Ajustar el índice del destino si el comando removido estaba antes o en el mismo índice
		if parent_cmd_index >= 0 and command_index < parent_cmd_index:
			# Si removimos un comando antes del destino, el índice del destino se reduce en 1
			parent_cmd_index -= 1

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
								cond_cmd.branches[branch_index].commands.append(command_to_move_obj)
								success = true
					else:
						push_error("Event Editor: No se encontró branch en destination_metadata")
				else:
					push_error("Event Editor: El comando en el índice no es ConditionalCommand")
			else:
				push_error("Event Editor: parent_cmd_index inválido o fuera de rango: ", parent_cmd_index, " (array size: ", editable_page.commands.size(), ")")
		elif destination_type == "choice_branch":
			# parent_cmd_index ya fue calculado arriba
			print("Event Editor: parent_cmd_index encontrado: ", parent_cmd_index)

			if parent_cmd_index >= 0 and parent_cmd_index < editable_page.commands.size():
				var cmd = editable_page.commands[parent_cmd_index]
				if cmd is ShowChoicesCommand:
					var choices_cmd = cmd as ShowChoicesCommand
					# Encontrar el branch por su posición (índice)
					var branch_index = -1
					var original_branch = destination_metadata.get("branch")
					if original_branch:
						# Buscar el índice del branch original en el comando original
						var parent_command = destination_metadata.get("parent_command")
						if parent_command:
							var original_choices_cmd = parent_command as ShowChoicesCommand
							for i in range(original_choices_cmd.branches.size()):
								if original_choices_cmd.branches[i] == original_branch:
									branch_index = i
									break
							print("Event Editor: branch_index encontrado: ", branch_index, " (branches size: ", choices_cmd.branches.size(), ")")
							# Usar el branch correspondiente en el comando duplicado
							if branch_index >= 0 and branch_index < choices_cmd.branches.size():
								choices_cmd.branches[branch_index].commands.append(command_to_move_obj)
								success = true
								print("Event Editor: Comando añadido exitosamente al choice_branch")
							else:
								push_error("Event Editor: branch_index inválido o fuera de rango")
						else:
							push_error("Event Editor: No se encontró parent_command en destination_metadata")
					else:
						push_error("Event Editor: No se encontró branch en destination_metadata")
				else:
					push_error("Event Editor: El comando en el índice no es ShowChoicesCommand")
			else:
				push_error("Event Editor: parent_cmd_index inválido o fuera de rango: ", parent_cmd_index, " (array size: ", editable_page.commands.size(), ")")
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
								switch_cmd.cases[case_index].commands.append(command_to_move_obj)
								success = true
		elif destination_type == "default_commands":
			# parent_cmd_index ya fue calculado arriba
			if parent_cmd_index >= 0 and parent_cmd_index < editable_page.commands.size():
				var cmd = editable_page.commands[parent_cmd_index]
				if cmd is SwitchCommand:
					var switch_cmd = cmd as SwitchCommand
					switch_cmd.default_commands.append(command_to_move_obj)
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
					cond_cmd.branches[0].commands.append(command_to_move_obj)
					success = true
				elif parent_cmd is ShowChoicesCommand:
					var choices_cmd = parent_cmd as ShowChoicesCommand
					if choices_cmd.branches.is_empty():
						var new_branch = ChoiceBranch.new()
						new_branch.label = "Opción"
						choices_cmd.branches.append(new_branch)
					choices_cmd.branches[0].commands.append(command_to_move_obj)
					success = true
				elif parent_cmd is SwitchCommand:
					var switch_cmd = parent_cmd as SwitchCommand
					if switch_cmd.cases.is_empty():
						switch_cmd.cases.append(SwitchCase.new())
					switch_cmd.cases[0].commands.append(command_to_move_obj)
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

		# Encontrar el índice del comando padre en la página original
		var parent_cmd_index = -1
		if original_page:
			for i in range(original_page.commands.size()):
				if original_page.commands[i] == parent_command_ref:
					parent_cmd_index = i
					break

		if parent_cmd_index < 0:
			push_error("Event Editor: No se encontró el comando padre en la página original")
			return false

		# Obtener el índice del nested_command (guardado cuando se presionó "Mover")
		var nested_command_index = move_info.get("nested_command_index", -1)

		if nested_command_index < 0:
			push_error("Event Editor: No se encontró nested_command_index en move_info")
			return false

		# Usar el mismo índice en la página duplicada
		var parent_cmd_duplicated = editable_page.commands[parent_cmd_index]
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
								cond_cmd.branches[dest_branch_index].commands.append(nested_command)
								success = true
		elif destination_type == "choice_branch":
			var parent_command = destination_metadata.get("parent_command")
			print("Event Editor: parent_command encontrado: ", parent_command != null)
			if parent_command:
				# Encontrar el índice del comando padre en la página original
				var dest_parent_cmd_index = -1
				if original_page:
					for i in range(original_page.commands.size()):
						if original_page.commands[i] == parent_command:
							dest_parent_cmd_index = i
							break

				print("Event Editor: Moviendo nested_command a choice_branch, dest_parent_cmd_index: ", dest_parent_cmd_index)

				# Usar el mismo índice en la página duplicada
				if dest_parent_cmd_index >= 0 and dest_parent_cmd_index < editable_page.commands.size():
					var cmd = editable_page.commands[dest_parent_cmd_index]
					if cmd is ShowChoicesCommand:
						var choices_cmd = cmd as ShowChoicesCommand
						# Encontrar el branch por su posición (índice)
						var dest_branch_index = -1
						var original_branch = destination_metadata.get("branch")
						if original_branch:
							# Buscar el índice del branch original en el comando original
							var original_choices_cmd = parent_command as ShowChoicesCommand
							for i in range(original_choices_cmd.branches.size()):
								if original_choices_cmd.branches[i] == original_branch:
									dest_branch_index = i
									break
							print("Event Editor: dest_branch_index encontrado: ", dest_branch_index, " (branches size: ", choices_cmd.branches.size(), ")")
							# Usar el branch correspondiente en el comando duplicado
							if dest_branch_index >= 0 and dest_branch_index < choices_cmd.branches.size():
								choices_cmd.branches[dest_branch_index].commands.append(nested_command)
								success = true
								print("Event Editor: nested_command añadido exitosamente al choice_branch[", dest_branch_index, "]")
							else:
								push_error("Event Editor: dest_branch_index inválido o fuera de rango: ", dest_branch_index, " (branches size: ", choices_cmd.branches.size(), ")")
						else:
							push_error("Event Editor: No se encontró branch en destination_metadata")
					else:
						push_error("Event Editor: El comando en el índice no es ShowChoicesCommand")
				else:
					push_error("Event Editor: dest_parent_cmd_index inválido o fuera de rango: ", dest_parent_cmd_index, " (array size: ", editable_page.commands.size(), ")")
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
								switch_cmd.cases[dest_case_index].commands.append(nested_command)
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
						switch_cmd.default_commands.append(nested_command)
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

	# Encontrar el índice del comando padre en la página original
	var parent_cmd_index = -1
	if source_page:
		for i in range(source_page.commands.size()):
			if source_page.commands[i] == parent_command_ref:
				parent_cmd_index = i
				break

	if parent_cmd_index < 0:
		push_error("Event Editor: No se encontró el comando padre en la página original")
		return false

	# Obtener el índice del nested_command (guardado cuando se presionó "Mover")
	var nested_command_index = move_info.get("nested_command_index", -1)

	if nested_command_index < 0:
		push_error("Event Editor: No se encontró nested_command_index en move_info")
		return false

	# Usar el mismo índice en la página duplicada
	var parent_cmd_duplicated = editable_page.commands[parent_cmd_index]
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

func _on_conditions_button_pressed(page_index: int) -> void:
	print("Event Editor: Gestionar condiciones para página ", page_index + 1)
	# TODO: Abrir editor de condiciones

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

	if selected_item:
		var metadata = selected_item.get_metadata(0)
		if metadata and metadata.has("type"):
			var item_type = metadata.type
			can_edit_delete = item_type in ["command", "nested_command", "branch", "choice_branch", "switch_case", "default_commands"]
			can_move = item_type in ["command", "nested_command"]
			can_duplicate = item_type in ["command", "nested_command"]

			# Determinar si se puede mover
			can_move_up = _can_move_item_up(selected_item, page_index)
			can_move_down = _can_move_item_down(selected_item, page_index)

	_update_buttons_state(page_index, can_edit_delete, can_move_up, can_move_down, can_move, can_duplicate)

func _on_command_deselected(page_index: int) -> void:
	if not move_mode_active.get(page_index, false):
		_update_buttons_state(page_index, false, false, false, false)

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
		_update_buttons_state(page_index, false, false, false)

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
	var metadata = selected_item.get_metadata(0) if selected_item else null
	var item_type = metadata.type if metadata and metadata.has("type") else ""

	var can_add = item_type in ["", "page_root"]
	var can_edit = item_type in ["command", "nested_command", "branch", "choice_branch", "switch_case", "default_commands"]
	var can_delete = can_edit
	var can_move = item_type in ["command", "nested_command"]
	var can_duplicate = item_type in ["command", "nested_command"]

	var context_menu = PopupMenu.new()
	if can_add:
		context_menu.add_item("Añadir Comando", 0)
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

	var item_type = metadata.type
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
	if item_type not in ["command", "nested_command"]:
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
	var selected_item = commands_tree.get_selected()
	if not selected_item:
		return false

	var parent_item = selected_item.get_parent()
	if not parent_item:
		return false

	var parent_metadata = parent_item.get_metadata(0)
	if not parent_metadata or not parent_metadata.has("type"):
		return false

	var main_command_item = _get_main_command_item_from_tree(parent_item, commands_tree)
	if not main_command_item:
		return false

	var cmd_meta = main_command_item.get_metadata(0)
	var main_command = page.commands[cmd_meta.index]
	var parent_type = parent_metadata.type

	# Encontrar el índice del comando anidado
	var nested_command_index = _find_item_index_in_tree(selected_item, parent_item, "nested_command")
	if nested_command_index < 0:
		return false

	# Encontrar el índice del branch/case
	var indices = _get_branch_or_case_index(parent_item, parent_type)
	var branch_index = indices.branch_index
	var case_index = indices.case_index

	# Obtener el array de comandos y eliminar el comando
	var commands_array = _get_commands_array_from_branch_case(main_command, parent_type, branch_index, case_index)
	if commands_array.is_empty() or nested_command_index >= commands_array.size():
		return false

	commands_array.remove_at(nested_command_index)
	return _set_commands_array_to_branch_case(main_command, parent_type, branch_index, case_index, commands_array)

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
		var new_branches: Array[EventBranch] = []
		for b in main_command.branches:
			if b != branch_to_remove:
				new_branches.append(b)
		main_command.branches = new_branches
		return true
	elif metadata.type == "choice_branch" and main_command is ShowChoicesCommand:
		var new_branches: Array[ChoiceBranch] = []
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
		var new_cases: Array[SwitchCase] = []
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
	var commands_array = null
	var item_index = -1

	if item_type == "nested_command":
		# El item está en un array de comandos anidados
		var branch_meta = parent_item.get_metadata(0)
		if not branch_meta:
			return false

		# IMPORTANTE: Necesitamos obtener el branch/case del comando duplicado, no del metadata
		# porque el metadata apunta al branch original

		if branch_meta.type == "branch" and branch_meta.has("branch") and main_command is ConditionalCommand:
			# Es un branch de ConditionalCommand
			var original_branch = branch_meta.branch
			var cond_cmd = main_command as ConditionalCommand
			# Encontrar el branch correspondiente en el comando duplicado
			var branch_index = -1
			for i in range(cond_cmd.branches.size()):
				# Comparar por referencia (deberían ser el mismo objeto después de duplicate)
				if cond_cmd.branches[i] == original_branch:
					branch_index = i
					break

			if branch_index >= 0:
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

		if commands_array:
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
			commands_array = main_command.branches
			item_index = branch_index
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
			commands_array = main_command.branches
			item_index = branch_index
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
			commands_array = main_command.cases
			item_index = case_index
		else:
			return false

	if not commands_array or item_index < 0:
		return false

	var new_index = item_index + direction
	if new_index < 0 or new_index >= commands_array.size():
		return false

	# Intercambiar los items
	var temp = commands_array[item_index]
	commands_array[item_index] = commands_array[new_index]
	commands_array[new_index] = temp

	return true

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
			var command_type = command_types[selected_items[0]] + "Command"
			dialog.queue_free()
			# Esperar a que el diálogo se cierre antes de crear el comando
			call_deferred("_create_command_of_type", page_index, command_type)
	)

	command_list.item_selected.connect(func(idx): add_button.disabled = false)
	command_list.item_activated.connect(func(idx):
		var command_type = command_types[idx] + "Command"
		dialog.queue_free()
		# Esperar a que el diálogo se cierre antes de crear el comando
		call_deferred("_create_command_of_type", page_index, command_type)
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
	_mark_as_changed()

	var commands_tree = _get_commands_tree_for_page(page_index)
	if commands_tree:
		_update_commands_tree(commands_tree, editable_page, page_index)
		var root = commands_tree.get_root()
		if root:
			var children = root.get_children()
			if children:
				commands_tree.set_selected(children[-1], 0)

	print("Event Editor: Comando ", command_type_name, " añadido")

	# Obtener el índice del comando recién añadido (es el último)
	var command_index = editable_page.commands.size() - 1

	# Si es un comando con editor, abrir el editor automáticamente
	# Pasar true para indicar que es un comando nuevo y el índice
	if new_command is ShowMessageCommand:
		_open_show_message_editor(new_command, page_index, true, command_index)
	elif new_command is SetFlagCommand:
		_open_set_flag_editor(new_command, page_index, true, command_index)
	elif new_command is SetVariableCommand:
		_open_set_variable_editor(new_command, page_index, true, command_index)
	elif new_command is SetSelfSwitchCommand:
		_open_set_self_switch_editor(new_command, page_index, true, command_index)
	elif new_command is StartBattleEventCommand:
		_open_start_battle_event_editor(new_command, page_index, true, command_index)
	elif new_command is WarpCommand:
		_open_warp_editor(new_command, page_index, true, command_index)
	elif new_command is WaitCommand:
		_open_wait_editor(new_command, page_index, true, command_index)
	elif new_command is FadeCommand:
		_open_fade_editor(new_command, page_index, true, command_index)
	elif new_command is SetWeatherCommand:
		_open_set_weather_editor(new_command, page_index, true, command_index)
	elif new_command is SetDarknessCommand:
		_open_set_darkness_editor(new_command, page_index, true, command_index)
	elif new_command is SetFlashlightCommand:
		_open_set_flashlight_editor(new_command, page_index, true, command_index)
	elif new_command is SetEventThroughCommand:
		_open_set_event_through_editor(new_command, page_index, true, command_index)
	elif new_command is SetActorVisibilityCommand:
		_open_set_actor_visibility_editor(new_command, page_index, true, command_index)
	elif new_command is ShowPortraitCommand:
		_open_show_portrait_editor(new_command, page_index, true, command_index)
	elif new_command is FollowActorCommand:
		_open_follow_actor_editor(new_command, page_index, true, command_index)
	elif new_command is UseMOCommand:
		_open_use_mo_editor(new_command, page_index, true, command_index)
	elif new_command is PlayAnimationCommand:
		_open_play_animation_editor(new_command, page_index, true, command_index)
	elif new_command is MoveNPCCommand:
		_open_move_npc_editor(new_command, page_index, true, command_index)

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

# === UTILIDADES ===
func _update_buttons_state(page_index: int, has_selection: bool, can_move_up: bool = false, can_move_down: bool = false, can_move: bool = false, can_duplicate: bool = false) -> void:
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

		buttons.add.disabled = has_selection
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
	event_node.pages = restored_pages

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
	has_unsaved_changes = false  # Resetear bandera después de guardar
	await get_tree().process_frame
	queue_free()

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

func _on_save_button_pressed() -> void:
	_refresh_inspector()
	has_unsaved_changes = false  # Resetear bandera después de guardar
	await get_tree().process_frame
	queue_free()
