@tool
extends Window

signal command_edited(command: DialogueCommand)
signal cancelled

var command: DialogueCommand = null

# Valores originales para cancelar cambios
var original_pages: Array = []
var original_message_box_theme: int = MessageBoxFrameStyle.Values.HGSS
var original_close_at_end: bool = true
var original_show_icon: bool = false

# Cache editable
var _pages_cache: Array[DialoguePage] = []

# Controles
var pages_list: ItemList = null
var add_button: Button = null
var edit_button: Button = null
var duplicate_button: Button = null
var remove_button: Button = null
var move_up_button: Button = null
var move_down_button: Button = null
var frame_style_option: OptionButton = null
var close_at_end_check: CheckBox = null
var show_icon_check: CheckBox = null

func _ready() -> void:
	title = "Editar DialogueCommand"
	size = Vector2(760, 620)
	unresizable = false
	exclusive = true
	close_requested.connect(_on_close_requested)

	_setup_ui()

func _setup_ui() -> void:
	var root = VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 10
	root.offset_top = 10
	root.offset_right = -10
	root.offset_bottom = -10
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	var title_label = Label.new()
	title_label.text = "Editar DialogueCommand"
	title_label.add_theme_font_size_override("font_size", 18)
	root.add_child(title_label)
	root.add_child(HSeparator.new())

	var info_label = Label.new()
	info_label.text = "Cada página representa una pantalla de texto del diálogo."
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(info_label)

	var pages_label = Label.new()
	pages_label.text = "Páginas:"
	pages_label.add_theme_font_size_override("font_size", 14)
	root.add_child(pages_label)

	pages_list = ItemList.new()
	pages_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pages_list.item_selected.connect(_on_page_selected)
	pages_list.item_activated.connect(_on_page_activated)
	root.add_child(pages_list)

	var controls = HBoxContainer.new()
	controls.add_theme_constant_override("separation", 6)

	add_button = Button.new()
	add_button.text = "Añadir"
	add_button.pressed.connect(_on_add_pressed)
	controls.add_child(add_button)

	edit_button = Button.new()
	edit_button.text = "Editar"
	edit_button.disabled = true
	edit_button.pressed.connect(_on_edit_pressed)
	controls.add_child(edit_button)

	duplicate_button = Button.new()
	duplicate_button.text = "Duplicar"
	duplicate_button.disabled = true
	duplicate_button.pressed.connect(_on_duplicate_pressed)
	controls.add_child(duplicate_button)

	move_up_button = Button.new()
	move_up_button.text = "↑"
	move_up_button.custom_minimum_size.x = 40
	move_up_button.disabled = true
	move_up_button.pressed.connect(_on_move_up_pressed)
	controls.add_child(move_up_button)

	move_down_button = Button.new()
	move_down_button.text = "↓"
	move_down_button.custom_minimum_size.x = 40
	move_down_button.disabled = true
	move_down_button.pressed.connect(_on_move_down_pressed)
	controls.add_child(move_down_button)

	remove_button = Button.new()
	remove_button.text = "Quitar"
	remove_button.disabled = true
	remove_button.pressed.connect(_on_remove_pressed)
	controls.add_child(remove_button)

	root.add_child(controls)
	root.add_child(HSeparator.new())

	var frame_style_container = HBoxContainer.new()
	var frame_style_label = Label.new()
	frame_style_label.text = "Tema del MessageBox:"
	frame_style_label.custom_minimum_size.x = 190
	frame_style_container.add_child(frame_style_label)

	frame_style_option = OptionButton.new()
	frame_style_option.add_item("HeartGold/SoulSilver")
	frame_style_option.add_item("Cartel 1")
	frame_style_option.add_item("FireRed")
	frame_style_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame_style_container.add_child(frame_style_option)
	root.add_child(frame_style_container)

	close_at_end_check = CheckBox.new()
	close_at_end_check.text = "Cerrar MessageBox al terminar diálogo"
	root.add_child(close_at_end_check)

	show_icon_check = CheckBox.new()
	show_icon_check.text = "Mostrar icono de espera también en la última página"
	root.add_child(show_icon_check)

	root.add_child(HSeparator.new())

	var footer = HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override("separation", 10)

	var accept_button = Button.new()
	accept_button.text = "Aceptar"
	accept_button.pressed.connect(_on_accept_pressed)
	footer.add_child(accept_button)

	var cancel_button = Button.new()
	cancel_button.text = "Cancelar"
	cancel_button.pressed.connect(_on_cancel_pressed)
	footer.add_child(cancel_button)

	root.add_child(footer)

func load_command(cmd: DialogueCommand) -> void:
	if not cmd:
		push_error("DialogueCommandEditor: No se proporcionó un comando válido")
		return

	command = cmd

	original_message_box_theme = cmd.message_box_theme
	original_close_at_end = cmd.close_at_end
	original_show_icon = cmd.show_icon
	original_pages = []
	for page in cmd.pages:
		if page:
			original_pages.append(page.duplicate(true))
		else:
			original_pages.append(null)

	_pages_cache = []
	for page in cmd.pages:
		if page:
			_pages_cache.append(page.duplicate(true))
		else:
			_pages_cache.append(null)

	if frame_style_option:
		frame_style_option.selected = cmd.message_box_theme
	if close_at_end_check:
		close_at_end_check.button_pressed = cmd.close_at_end
	if show_icon_check:
		show_icon_check.button_pressed = cmd.show_icon

	_refresh_pages_list()
	_update_buttons_state()

func _refresh_pages_list() -> void:
	if not pages_list:
		return

	pages_list.clear()
	for i in range(_pages_cache.size()):
		pages_list.add_item(_get_page_display_name(_pages_cache[i], i))

func _get_page_display_name(page: DialoguePage, index: int) -> String:
	var text := ""
	if page != null:
		text = page.text

	var preview = text.strip_edges().replace("\n", " ")
	if preview.is_empty():
		preview = "(sin texto)"
	elif preview.length() > 72:
		preview = preview.substr(0, 72) + "..."

	return "Página %d: %s" % [index + 1, preview]

func _update_buttons_state() -> void:
	var has_selection := pages_list and pages_list.get_selected_items().size() > 0
	var selected_index := _get_selected_index()
	var can_move_up := has_selection and selected_index > 0
	var can_move_down := has_selection and selected_index >= 0 and selected_index < _pages_cache.size() - 1
	if edit_button:
		edit_button.disabled = not has_selection
	if duplicate_button:
		duplicate_button.disabled = not has_selection
	if remove_button:
		remove_button.disabled = not has_selection
	if move_up_button:
		move_up_button.disabled = not can_move_up
	if move_down_button:
		move_down_button.disabled = not can_move_down

func _get_selected_index() -> int:
	if not pages_list:
		return -1
	var selected = pages_list.get_selected_items()
	if selected.is_empty():
		return -1
	return selected[0]

func _on_page_selected(_index: int) -> void:
	_update_buttons_state()

func _on_page_activated(_index: int) -> void:
	_on_edit_pressed()

func _on_add_pressed() -> void:
	_open_page_text_dialog("Nueva página", "", func(new_text: String):
		var page := DialoguePage.new()
		page.text = new_text
		_pages_cache.append(page)
		_refresh_pages_list()
		pages_list.select(_pages_cache.size() - 1)
		_update_buttons_state()
	)

func _on_edit_pressed() -> void:
	var idx = _get_selected_index()
	if idx < 0 or idx >= _pages_cache.size():
		return

	var page = _pages_cache[idx]
	var current_text = page.text if page != null else ""

	_open_page_text_dialog("Editar página", current_text, func(new_text: String):
		if _pages_cache[idx] == null:
			_pages_cache[idx] = DialoguePage.new()
		_pages_cache[idx].text = new_text
		_refresh_pages_list()
		pages_list.select(idx)
		_update_buttons_state()
	)

func _on_duplicate_pressed() -> void:
	var idx = _get_selected_index()
	if idx < 0 or idx >= _pages_cache.size():
		return

	var source = _pages_cache[idx]
	var copy_page: DialoguePage = null
	if source:
		copy_page = source.duplicate(true)
	else:
		copy_page = DialoguePage.new()

	_pages_cache.insert(idx + 1, copy_page)
	_refresh_pages_list()
	pages_list.select(idx + 1)
	_update_buttons_state()

func _on_move_up_pressed() -> void:
	var idx = _get_selected_index()
	if idx <= 0 or idx >= _pages_cache.size():
		return

	var temp = _pages_cache[idx]
	_pages_cache[idx] = _pages_cache[idx - 1]
	_pages_cache[idx - 1] = temp

	_refresh_pages_list()
	pages_list.select(idx - 1)
	_update_buttons_state()

func _on_move_down_pressed() -> void:
	var idx = _get_selected_index()
	if idx < 0 or idx >= _pages_cache.size() - 1:
		return

	var temp = _pages_cache[idx]
	_pages_cache[idx] = _pages_cache[idx + 1]
	_pages_cache[idx + 1] = temp

	_refresh_pages_list()
	pages_list.select(idx + 1)
	_update_buttons_state()

func _on_remove_pressed() -> void:
	var idx = _get_selected_index()
	if idx < 0 or idx >= _pages_cache.size():
		return

	_pages_cache.remove_at(idx)
	_refresh_pages_list()
	if not _pages_cache.is_empty():
		pages_list.select(clamp(idx, 0, _pages_cache.size() - 1))
	_update_buttons_state()

func _open_page_text_dialog(dialog_title: String, initial_text: String, on_accept: Callable) -> void:
	var dialog = AcceptDialog.new()
	dialog.title = dialog_title
	dialog.dialog_text = "Texto de la página:"
	dialog.size = Vector2(700, 360)
	dialog.exclusive = true

	var editor = TextEdit.new()
	editor.custom_minimum_size = Vector2(0, 220)
	editor.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	editor.text = initial_text
	dialog.add_child(editor)

	add_child(dialog)

	dialog.confirmed.connect(func():
		on_accept.call(editor.text)
		dialog.queue_free()
	)
	dialog.canceled.connect(func():
		dialog.queue_free()
	)
	dialog.close_requested.connect(func():
		dialog.queue_free()
	)

	dialog.popup_centered()

func _apply_values_to_command() -> void:
	if not command:
		return

	var new_pages: Array[DialoguePage] = []
	for page in _pages_cache:
		if page:
			new_pages.append(page.duplicate(true))
		else:
			new_pages.append(null)

	command.pages = new_pages
	command.message_box_theme = frame_style_option.selected if frame_style_option else MessageBoxFrameStyle.Values.HGSS
	command.close_at_end = close_at_end_check.button_pressed if close_at_end_check else true
	command.show_icon = show_icon_check.button_pressed if show_icon_check else false

func _restore_original_values() -> void:
	if not command:
		return

	var restored_pages: Array[DialoguePage] = []
	for page in original_pages:
		if page:
			restored_pages.append(page.duplicate(true))
		else:
			restored_pages.append(null)

	command.pages = restored_pages
	command.message_box_theme = original_message_box_theme
	command.close_at_end = original_close_at_end
	command.show_icon = original_show_icon

func _on_accept_pressed() -> void:
	_apply_values_to_command()
	command_edited.emit(command)
	queue_free()

func _on_cancel_pressed() -> void:
	_restore_original_values()
	cancelled.emit()
	queue_free()

func _on_close_requested() -> void:
	_on_cancel_pressed()
