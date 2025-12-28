@tool
extends Window

## Ventana de edición para EventCondition
## Permite editar condiciones de forma jerárquica usando un Tree
## Reutilizable para EventPage.root_condition y EventBranch.condition

signal condition_edited(condition: EventCondition)
signal cancelled

var condition: EventCondition = null
var _event_node: Node = null

# Valores originales para poder cancelar
var original_condition: EventCondition = null

# Referencias a los controles
var condition_tree: Tree = null
var properties_panel: VBoxContainer = null
var add_button: Button = null
var remove_button: Button = null
var move_up_button: Button = null
var move_down_button: Button = null
var accept_button: Button = null

# Controles específicos por tipo de condición
var flag_scope_option: OptionButton = null
var flag_name_edit: LineEdit = null
var flag_value_check: CheckBox = null

var variable_name_edit: LineEdit = null
var variable_operator_option: OptionButton = null
var variable_value_edit: LineEdit = null

var group_mode_option: OptionButton = null
var group_add_button: Button = null

var not_edit_button: Button = null

func _ready() -> void:
	title = "Editar Condición"
	size = Vector2(800, 600)
	unresizable = false
	always_on_top = false
	exclusive = true
	close_requested.connect(_on_close_requested)

	var main_container = HBoxContainer.new()
	main_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_container.add_theme_constant_override("margin_left", 10)
	main_container.add_theme_constant_override("margin_top", 10)
	main_container.add_theme_constant_override("margin_right", 10)
	main_container.add_theme_constant_override("margin_bottom", 10)
	add_child(main_container)

	# Panel izquierdo: Tree de condiciones
	var left_panel = VBoxContainer.new()
	left_panel.custom_minimum_size.x = 400
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_container.add_child(left_panel)

	var title_label = Label.new()
	title_label.text = "Estructura de Condiciones"
	title_label.add_theme_font_size_override("font_size", 16)
	left_panel.add_child(title_label)

	condition_tree = Tree.new()
	condition_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	condition_tree.item_selected.connect(_on_condition_selected)
	condition_tree.item_activated.connect(_on_condition_activated)
	left_panel.add_child(condition_tree)

	# Botones de control del árbol
	var tree_controls = HBoxContainer.new()
	tree_controls.add_theme_constant_override("separation", 5)

	add_button = Button.new()
	add_button.text = "Añadir Condición"
	add_button.pressed.connect(_on_add_condition_pressed)
	tree_controls.add_child(add_button)

	remove_button = Button.new()
	remove_button.text = "Eliminar"
	remove_button.disabled = true
	remove_button.pressed.connect(_on_remove_pressed)
	tree_controls.add_child(remove_button)

	move_up_button = Button.new()
	move_up_button.text = "↑"
	move_up_button.custom_minimum_size.x = 40
	move_up_button.disabled = true
	move_up_button.pressed.connect(_on_move_up_pressed)
	tree_controls.add_child(move_up_button)

	move_down_button = Button.new()
	move_down_button.text = "↓"
	move_down_button.custom_minimum_size.x = 40
	move_down_button.disabled = true
	move_down_button.pressed.connect(_on_move_down_pressed)
	tree_controls.add_child(move_down_button)

	left_panel.add_child(tree_controls)

	# Panel derecho: Propiedades de la condición seleccionada
	var right_panel = VBoxContainer.new()
	right_panel.custom_minimum_size.x = 350
	main_container.add_child(right_panel)

	var properties_label = Label.new()
	properties_label.text = "Propiedades"
	properties_label.add_theme_font_size_override("font_size", 16)
	right_panel.add_child(properties_label)

	properties_panel = VBoxContainer.new()
	properties_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.add_child(properties_panel)

	# Botones finales
	var buttons_container = HBoxContainer.new()
	buttons_container.alignment = BoxContainer.ALIGNMENT_END
	buttons_container.add_theme_constant_override("separation", 10)
	buttons_container.add_theme_constant_override("margin_top", 10)

	accept_button = Button.new()
	accept_button.text = "Aceptar"
	accept_button.pressed.connect(_on_accept_pressed)
	buttons_container.add_child(accept_button)

	var cancel_button = Button.new()
	cancel_button.text = "Cancelar"
	cancel_button.pressed.connect(_on_cancel_pressed)
	buttons_container.add_child(cancel_button)

	right_panel.add_child(buttons_container)

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
		var count = group_cond.children.size()
		return "%s (%d condiciones)" % [mode_str, count]

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

## Construye el árbol de condiciones recursivamente
func _build_condition_tree(item: TreeItem, cond: EventCondition) -> void:
	if not cond:
		return

	var display_text = _get_condition_display_text(cond)
	item.set_text(0, display_text)
	item.set_metadata(0, {"condition": cond})

	# Si es GroupCondition, añadir hijos
	if cond is GroupCondition:
		var group_cond = cond as GroupCondition
		for child_cond in group_cond.children:
			if child_cond:
				var child_item = condition_tree.create_item(item)
				_build_condition_tree(child_item, child_cond)
		item.collapsed = false

	# Si es NotCondition, añadir hijo
	elif cond is NotCondition:
		var not_cond = cond as NotCondition
		if not_cond.child:
			var child_item = condition_tree.create_item(item)
			_build_condition_tree(child_item, not_cond.child)
		item.collapsed = false

## Refresca el árbol completo desde la condición raíz
func _refresh_condition_tree() -> void:
	condition_tree.clear()

	if not condition:
		return

	var root_item = condition_tree.create_item()
	_build_condition_tree(root_item, condition)
	root_item.select(0)

## Limpia el panel de propiedades
func _clear_properties_panel() -> void:
	for child in properties_panel.get_children():
		child.queue_free()

## Muestra las propiedades de FlagCondition
func _show_flag_properties(flag_cond: FlagCondition) -> void:
	_clear_properties_panel()

	var info_label = Label.new()
	info_label.text = "Condición: Flag"
	info_label.add_theme_font_size_override("font_size", 14)
	properties_panel.add_child(info_label)
	properties_panel.add_child(HSeparator.new())

	# Scope
	var scope_container = HBoxContainer.new()
	var scope_label = Label.new()
	scope_label.text = "Alcance:"
	scope_label.custom_minimum_size.x = 150
	scope_container.add_child(scope_label)

	flag_scope_option = OptionButton.new()
	flag_scope_option.add_item("Global")
	flag_scope_option.add_item("Self")
	flag_scope_option.selected = 0 if flag_cond.scope == FlagCondition.Scope.GLOBAL else 1
	flag_scope_option.item_selected.connect(_on_flag_scope_changed)
	flag_scope_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scope_container.add_child(flag_scope_option)
	properties_panel.add_child(scope_container)

	# Flag name
	var name_container = HBoxContainer.new()
	var name_label = Label.new()
	name_label.text = "Nombre del flag:"
	name_label.custom_minimum_size.x = 150
	name_container.add_child(name_label)

	flag_name_edit = LineEdit.new()
	flag_name_edit.text = flag_cond.flag_name
	flag_name_edit.placeholder_text = "Ej: has_pokeball"
	flag_name_edit.text_changed.connect(_on_flag_name_changed)
	flag_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_container.add_child(flag_name_edit)
	properties_panel.add_child(name_container)

	# Expected value
	flag_value_check = CheckBox.new()
	flag_value_check.text = "Valor esperado: true"
	flag_value_check.button_pressed = flag_cond.expected_value
	flag_value_check.toggled.connect(_on_flag_value_changed)
	properties_panel.add_child(flag_value_check)

## Muestra las propiedades de VariableCondition
func _show_variable_properties(var_cond: VariableCondition) -> void:
	_clear_properties_panel()

	var info_label = Label.new()
	info_label.text = "Condición: Variable"
	info_label.add_theme_font_size_override("font_size", 14)
	properties_panel.add_child(info_label)
	properties_panel.add_child(HSeparator.new())

	# Variable name
	var name_container = HBoxContainer.new()
	var name_label = Label.new()
	name_label.text = "Nombre variable:"
	name_label.custom_minimum_size.x = 150
	name_container.add_child(name_label)

	variable_name_edit = LineEdit.new()
	variable_name_edit.text = var_cond.variable_name
	variable_name_edit.placeholder_text = "Ej: player_money"
	variable_name_edit.text_changed.connect(_on_variable_name_changed)
	variable_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_container.add_child(variable_name_edit)
	properties_panel.add_child(name_container)

	# Operator
	var op_container = HBoxContainer.new()
	var op_label = Label.new()
	op_label.text = "Operador:"
	op_label.custom_minimum_size.x = 150
	op_container.add_child(op_label)

	variable_operator_option = OptionButton.new()
	variable_operator_option.add_item("==")
	variable_operator_option.add_item("!=")
	variable_operator_option.add_item(">")
	variable_operator_option.add_item(">=")
	variable_operator_option.add_item("<")
	variable_operator_option.add_item("<=")
	variable_operator_option.selected = var_cond.operator
	variable_operator_option.item_selected.connect(_on_variable_operator_changed)
	variable_operator_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	op_container.add_child(variable_operator_option)
	properties_panel.add_child(op_container)

	# Compare value
	var value_container = HBoxContainer.new()
	var value_label = Label.new()
	value_label.text = "Valor a comparar:"
	value_label.custom_minimum_size.x = 150
	value_container.add_child(value_label)

	variable_value_edit = LineEdit.new()
	variable_value_edit.text = _value_to_string(var_cond.compare_value).trim_prefix('"').trim_suffix('"')
	variable_value_edit.placeholder_text = "Ej: 100, \"texto\", true"
	variable_value_edit.text_changed.connect(_on_variable_value_changed)
	variable_value_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_container.add_child(variable_value_edit)
	properties_panel.add_child(value_container)

## Muestra las propiedades de GroupCondition
func _show_group_properties(group_cond: GroupCondition) -> void:
	_clear_properties_panel()

	var info_label = Label.new()
	info_label.text = "Condición: Grupo"
	info_label.add_theme_font_size_override("font_size", 14)
	properties_panel.add_child(info_label)
	properties_panel.add_child(HSeparator.new())

	# Mode
	var mode_container = HBoxContainer.new()
	var mode_label = Label.new()
	mode_label.text = "Modo:"
	mode_label.custom_minimum_size.x = 150
	mode_container.add_child(mode_label)

	group_mode_option = OptionButton.new()
	group_mode_option.add_item("AND (todas deben cumplirse)")
	group_mode_option.add_item("OR (al menos una)")
	group_mode_option.selected = 0 if group_cond.mode == GroupCondition.Mode.ALL else 1
	group_mode_option.item_selected.connect(_on_group_mode_changed)
	group_mode_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_container.add_child(group_mode_option)
	properties_panel.add_child(mode_container)

	# Add child button
	group_add_button = Button.new()
	group_add_button.text = "Añadir Condición al Grupo"
	group_add_button.pressed.connect(_on_group_add_child_pressed)
	properties_panel.add_child(group_add_button)

	# Info
	var count_label = Label.new()
	count_label.text = "Condiciones en el grupo: %d" % group_cond.children.size()
	properties_panel.add_child(count_label)

## Muestra las propiedades de NotCondition
func _show_not_properties(not_cond: NotCondition) -> void:
	_clear_properties_panel()

	var info_label = Label.new()
	info_label.text = "Condición: NOT"
	info_label.add_theme_font_size_override("font_size", 14)
	properties_panel.add_child(info_label)
	properties_panel.add_child(HSeparator.new())

	var desc_label = Label.new()
	desc_label.text = "Invierte el resultado de la condición hija."
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	properties_panel.add_child(desc_label)

	# Edit child button
	not_edit_button = Button.new()
	not_edit_button.text = "Editar Condición Hija"
	not_edit_button.pressed.connect(_on_not_edit_child_pressed)
	properties_panel.add_child(not_edit_button)

	# Info
	if not_cond.child:
		var child_info = Label.new()
		child_info.text = "Hija: %s" % _get_condition_display_text(not_cond.child)
		properties_panel.add_child(child_info)
	else:
		var no_child_label = Label.new()
		no_child_label.text = "(Sin condición hija)"
		properties_panel.add_child(no_child_label)

## Se llama cuando se selecciona una condición en el árbol
func _on_condition_selected() -> void:
	var selected_item = condition_tree.get_selected()
	if not selected_item:
		_clear_properties_panel()
		_update_buttons_state()
		return

	var metadata = selected_item.get_metadata(0)
	if not metadata or not metadata.has("condition"):
		_clear_properties_panel()
		_update_buttons_state()
		return

	var cond = metadata.get("condition")
	if not cond:
		_clear_properties_panel()
		_update_buttons_state()
		return

	# Mostrar propiedades según el tipo
	if cond is FlagCondition:
		_show_flag_properties(cond as FlagCondition)
	elif cond is VariableCondition:
		_show_variable_properties(cond as VariableCondition)
	elif cond is GroupCondition:
		_show_group_properties(cond as GroupCondition)
	elif cond is NotCondition:
		_show_not_properties(cond as NotCondition)
	else:
		_clear_properties_panel()

	_update_buttons_state()

## Se llama cuando se hace doble clic en una condición
func _on_condition_activated() -> void:
	# Si es NotCondition, abrir editor de la hija
	var selected_item = condition_tree.get_selected()
	if not selected_item:
		return

	var metadata = selected_item.get_metadata(0)
	if not metadata or not metadata.has("condition"):
		return

	var cond = metadata.get("condition")
	if cond is NotCondition:
		_on_not_edit_child_pressed()

## Actualiza el estado de los botones
func _update_buttons_state() -> void:
	var selected_item = condition_tree.get_selected()
	var has_selection = selected_item != null

	remove_button.disabled = not has_selection

	# Para mover arriba/abajo, solo funciona dentro de un GroupCondition
	var can_move = false
	if has_selection and selected_item:
		var parent = selected_item.get_parent()
		if parent:
			var parent_meta = parent.get_metadata(0)
			if parent_meta and parent_meta.has("condition"):
				var parent_cond = parent_meta.get("condition")
				if parent_cond is GroupCondition:
					can_move = true

	if can_move:
		var prev = selected_item.get_prev()
		var next = selected_item.get_next()
		move_up_button.disabled = prev == null
		move_down_button.disabled = next == null
	else:
		move_up_button.disabled = true
		move_down_button.disabled = true

## Se llama cuando se presiona Añadir Condición
func _on_add_condition_pressed() -> void:
	# Crear menú de selección de tipo
	var popup = PopupMenu.new()
	popup.add_item("Flag")
	popup.add_item("Variable")
	popup.add_item("Grupo (AND/OR)")
	popup.add_item("NOT")

	add_child(popup)
	popup.id_pressed.connect(func(id: int):
		_on_condition_type_selected(id)
		popup.queue_free()
	)
	popup.popup_on_parent(Rect2i(add_button.global_position + Vector2(0, add_button.size.y), Vector2(200, 100)))

## Se llama cuando se selecciona un tipo de condición en el menú
func _on_condition_type_selected(id: int) -> void:
	var new_cond: EventCondition = null

	match id:
		0:  # Flag
			new_cond = FlagCondition.new()
		1:  # Variable
			new_cond = VariableCondition.new()
		2:  # Group
			new_cond = GroupCondition.new()
		3:  # NOT
			new_cond = NotCondition.new()

	if not new_cond:
		return

	var selected_item = condition_tree.get_selected()

	# Si hay un item seleccionado y es un GroupCondition, añadir como hijo
	if selected_item:
		var metadata = selected_item.get_metadata(0)
		if metadata and metadata.has("condition"):
			var parent_cond = metadata.get("condition")
			if parent_cond is GroupCondition:
				(parent_cond as GroupCondition).children.append(new_cond)
				_refresh_condition_tree()
				_select_condition_in_tree(new_cond)
				return

	# Si no hay condición raíz, crear una nueva
	if not condition:
		condition = new_cond
		_refresh_condition_tree()
		_select_condition_in_tree(new_cond)
		return

	# Si la condición raíz no es un GroupCondition, convertirla en uno
	if not condition is GroupCondition:
		var old_cond = condition
		condition = GroupCondition.new()
		(condition as GroupCondition).children.append(old_cond)

	# Añadir a la raíz (que ahora es un GroupCondition)
	(condition as GroupCondition).children.append(new_cond)
	_refresh_condition_tree()
	_select_condition_in_tree(new_cond)

## Busca y selecciona una condición en el árbol
func _select_condition_in_tree(target_cond: EventCondition) -> void:
	var root = condition_tree.get_root()
	if not root:
		return

	_select_condition_recursive(root, target_cond)

## Busca recursivamente una condición en el árbol
func _select_condition_recursive(item: TreeItem, target_cond: EventCondition) -> bool:
	var metadata = item.get_metadata(0)
	if metadata and metadata.has("condition"):
		var cond = metadata.get("condition")
		if cond == target_cond:
			item.select(0)
			condition_tree.scroll_to_item(item)
			return true

	var child = item.get_first_child()
	while child:
		if _select_condition_recursive(child, target_cond):
			return true
		child = child.get_next()

	return false

## Se llama cuando se presiona Eliminar
func _on_remove_pressed() -> void:
	var selected_item = condition_tree.get_selected()
	if not selected_item:
		return

	var metadata = selected_item.get_metadata(0)
	if not metadata or not metadata.has("condition"):
		return

	var cond = metadata.get("condition")
	var parent_item = selected_item.get_parent()

	# Si es la raíz, eliminar la condición completa
	if not parent_item:
		condition = null
	else:
		# Eliminar del padre
		var parent_meta = parent_item.get_metadata(0)
		if parent_meta and parent_meta.has("condition"):
			var parent_cond = parent_meta.get("condition")
			if parent_cond is GroupCondition:
				var group_cond = parent_cond as GroupCondition
				group_cond.children.erase(cond)
			elif parent_cond is NotCondition:
				var not_cond = parent_cond as NotCondition
				if not_cond.child == cond:
					not_cond.child = null

	_refresh_condition_tree()
	_update_buttons_state()

## Se llama cuando se presiona ↑
func _on_move_up_pressed() -> void:
	var selected_item = condition_tree.get_selected()
	if not selected_item:
		return

	var prev = selected_item.get_prev()
	if not prev:
		return

	var parent = selected_item.get_parent()
	if not parent:
		return

	var parent_meta = parent.get_metadata(0)
	if not parent_meta or not parent_meta.has("condition"):
		return

	var parent_cond = parent_meta.get("condition")
	if not parent_cond is GroupCondition:
		return

	var group_cond = parent_cond as GroupCondition
	var selected_meta = selected_item.get_metadata(0)
	var prev_meta = prev.get_metadata(0)

	if not selected_meta or not prev_meta:
		return

	var selected_cond = selected_meta.get("condition")
	var prev_cond = prev_meta.get("condition")

	# Intercambiar en el array
	var selected_idx = group_cond.children.find(selected_cond)
	var prev_idx = group_cond.children.find(prev_cond)

	if selected_idx >= 0 and prev_idx >= 0:
		group_cond.children[selected_idx] = prev_cond
		group_cond.children[prev_idx] = selected_cond
		_refresh_condition_tree()
		_select_condition_in_tree(selected_cond)
		_update_buttons_state()

## Se llama cuando se presiona ↓
func _on_move_down_pressed() -> void:
	var selected_item = condition_tree.get_selected()
	if not selected_item:
		return

	var next = selected_item.get_next()
	if not next:
		return

	var parent = selected_item.get_parent()
	if not parent:
		return

	var parent_meta = parent.get_metadata(0)
	if not parent_meta or not parent_meta.has("condition"):
		return

	var parent_cond = parent_meta.get("condition")
	if not parent_cond is GroupCondition:
		return

	var group_cond = parent_cond as GroupCondition
	var selected_meta = selected_item.get_metadata(0)
	var next_meta = next.get_metadata(0)

	if not selected_meta or not next_meta:
		return

	var selected_cond = selected_meta.get("condition")
	var next_cond = next_meta.get("condition")

	# Intercambiar en el array
	var selected_idx = group_cond.children.find(selected_cond)
	var next_idx = group_cond.children.find(next_cond)

	if selected_idx >= 0 and next_idx >= 0:
		group_cond.children[selected_idx] = next_cond
		group_cond.children[next_idx] = selected_cond
		_refresh_condition_tree()
		_select_condition_in_tree(selected_cond)
		_update_buttons_state()

## Callbacks para FlagCondition
func _on_flag_scope_changed(index: int) -> void:
	var selected_item = condition_tree.get_selected()
	if not selected_item:
		return

	var metadata = selected_item.get_metadata(0)
	if not metadata or not metadata.has("condition"):
		return

	var cond = metadata.get("condition")
	if not cond is FlagCondition:
		return

	var flag_cond = cond as FlagCondition
	flag_cond.scope = FlagCondition.Scope.GLOBAL if index == 0 else FlagCondition.Scope.SELF
	# Solo actualizar el texto del item sin refrescar todo el árbol
	selected_item.set_text(0, _get_condition_display_text(flag_cond))

func _on_flag_name_changed(_text: String) -> void:
	var selected_item = condition_tree.get_selected()
	if not selected_item:
		return

	var metadata = selected_item.get_metadata(0)
	if not metadata or not metadata.has("condition"):
		return

	var cond = metadata.get("condition")
	if not cond is FlagCondition:
		return

	var flag_cond = cond as FlagCondition
	flag_cond.flag_name = flag_name_edit.text
	# Solo actualizar el texto del item sin refrescar todo el árbol
	selected_item.set_text(0, _get_condition_display_text(flag_cond))

func _on_flag_value_changed(pressed: bool) -> void:
	var selected_item = condition_tree.get_selected()
	if not selected_item:
		return

	var metadata = selected_item.get_metadata(0)
	if not metadata or not metadata.has("condition"):
		return

	var cond = metadata.get("condition")
	if not cond is FlagCondition:
		return

	var flag_cond = cond as FlagCondition
	flag_cond.expected_value = pressed
	flag_value_check.text = "Valor esperado: %s" % ("true" if pressed else "false")
	# Solo actualizar el texto del item sin refrescar todo el árbol
	selected_item.set_text(0, _get_condition_display_text(flag_cond))

## Callbacks para VariableCondition
func _on_variable_name_changed(_text: String) -> void:
	var selected_item = condition_tree.get_selected()
	if not selected_item:
		return

	var metadata = selected_item.get_metadata(0)
	if not metadata or not metadata.has("condition"):
		return

	var cond = metadata.get("condition")
	if not cond is VariableCondition:
		return

	var var_cond = cond as VariableCondition
	var_cond.variable_name = variable_name_edit.text
	# Solo actualizar el texto del item sin refrescar todo el árbol
	selected_item.set_text(0, _get_condition_display_text(var_cond))

func _on_variable_operator_changed(index: int) -> void:
	var selected_item = condition_tree.get_selected()
	if not selected_item:
		return

	var metadata = selected_item.get_metadata(0)
	if not metadata or not metadata.has("condition"):
		return

	var cond = metadata.get("condition")
	if not cond is VariableCondition:
		return

	var var_cond = cond as VariableCondition
	var_cond.operator = index
	# Solo actualizar el texto del item sin refrescar todo el árbol
	selected_item.set_text(0, _get_condition_display_text(var_cond))

func _on_variable_value_changed(_text: String) -> void:
	var selected_item = condition_tree.get_selected()
	if not selected_item:
		return

	var metadata = selected_item.get_metadata(0)
	if not metadata or not metadata.has("condition"):
		return

	var cond = metadata.get("condition")
	if not cond is VariableCondition:
		return

	var var_cond = cond as VariableCondition
	var_cond.compare_value = _parse_value(variable_value_edit.text)
	# Solo actualizar el texto del item sin refrescar todo el árbol
	selected_item.set_text(0, _get_condition_display_text(var_cond))

## Callbacks para GroupCondition
func _on_group_mode_changed(index: int) -> void:
	var selected_item = condition_tree.get_selected()
	if not selected_item:
		return

	var metadata = selected_item.get_metadata(0)
	if not metadata or not metadata.has("condition"):
		return

	var cond = metadata.get("condition")
	if not cond is GroupCondition:
		return

	var group_cond = cond as GroupCondition
	group_cond.mode = GroupCondition.Mode.ALL if index == 0 else GroupCondition.Mode.ANY
	# Solo actualizar el texto del item sin refrescar todo el árbol
	selected_item.set_text(0, _get_condition_display_text(group_cond))

func _on_group_add_child_pressed() -> void:
	# Abrir el menú de selección de tipo
	_on_add_condition_pressed()

## Callbacks para NotCondition
func _on_not_edit_child_pressed() -> void:
	var selected_item = condition_tree.get_selected()
	if not selected_item:
		return

	var metadata = selected_item.get_metadata(0)
	if not metadata or not metadata.has("condition"):
		return

	var cond = metadata.get("condition")
	if not cond is NotCondition:
		return

	var not_cond = cond as NotCondition

	# Si no tiene hijo, crear uno nuevo
	if not not_cond.child:
		# Abrir menú para seleccionar tipo
		# Necesitamos crear la condición y asignarla como hijo
		var popup = PopupMenu.new()
		popup.add_item("Flag")
		popup.add_item("Variable")
		popup.add_item("Grupo (AND/OR)")
		popup.add_item("NOT")

		add_child(popup)
		popup.id_pressed.connect(func(id: int):
			_on_not_child_type_selected(not_cond, id)
			popup.queue_free()
		)
		popup.popup_on_parent(Rect2i(not_edit_button.global_position + Vector2(0, not_edit_button.size.y), Vector2(200, 100)))
		return

	# Si tiene hijo, seleccionar el hijo en el árbol
	var child_item = selected_item.get_first_child()
	if child_item:
		child_item.select(0)
		condition_tree.scroll_to_item(child_item)

## Se llama cuando se selecciona un tipo para el hijo de NotCondition
func _on_not_child_type_selected(not_cond: NotCondition, id: int) -> void:
	var new_cond: EventCondition = null

	match id:
		0:  # Flag
			new_cond = FlagCondition.new()
		1:  # Variable
			new_cond = VariableCondition.new()
		2:  # Group
			new_cond = GroupCondition.new()
		3:  # NOT
			new_cond = NotCondition.new()

	if new_cond:
		not_cond.child = new_cond
		_refresh_condition_tree()
		_select_condition_in_tree(new_cond)

## Intenta parsear un string a un valor
func _parse_value(text: String) -> Variant:
	var trimmed = text.strip_edges()
	if trimmed.is_empty():
		return ""

	# Si está entre comillas, es un String
	if trimmed.begins_with('"') and trimmed.ends_with('"'):
		return trimmed.substr(1, trimmed.length() - 2)

	# Intentar como bool
	if trimmed.to_lower() == "true":
		return true
	if trimmed.to_lower() == "false":
		return false

	# Intentar como int
	if trimmed.is_valid_int():
		return trimmed.to_int()

	# Intentar como float
	if trimmed.is_valid_float():
		return trimmed.to_float()

	# Si no se puede parsear, devolver como String
	return trimmed

## Setter para event_node
func set_event_node(value: Node) -> void:
	_event_node = value

## Carga una condición para editar
func load_condition(cond: EventCondition) -> void:
	if cond:
		condition = cond.duplicate(true)
		original_condition = cond.duplicate(true)
	else:
		condition = null
		original_condition = null

	_refresh_condition_tree()
	_update_buttons_state()

## Aplica los valores editados
func _apply_values() -> void:
	# La condición ya está actualizada en memoria
	# Solo necesitamos asegurarnos de que esté duplicada correctamente
	pass

## Restaura los valores originales
func _restore_original_values() -> void:
	if original_condition:
		condition = original_condition.duplicate(true)
	else:
		condition = null

	_refresh_condition_tree()
	_update_buttons_state()

## Se llama cuando se presiona Aceptar
func _on_accept_pressed() -> void:
	_apply_values()
	condition_edited.emit(condition)
	queue_free()

## Se llama cuando se presiona Cancelar
func _on_cancel_pressed() -> void:
	_restore_original_values()
	cancelled.emit()
	queue_free()

## Se llama cuando se cierra la ventana
func _on_close_requested() -> void:
	_on_cancel_pressed()

