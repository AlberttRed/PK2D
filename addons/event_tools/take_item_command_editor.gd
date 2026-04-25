@tool
extends Window

signal command_edited(command)
signal cancelled

const ITEMS_DIR := "res://Resources/Data/Items"

var command = null

var original_item_id: int = 0
var original_quantity: int = 1

var item_option: OptionButton = null
var item_picker_button: Button = null
var quantity_spin: SpinBox = null
var _item_ids_by_option_index: Array[int] = []

func _ready() -> void:
	title = "Editar TakeItemCommand"
	size = Vector2(560, 240)
	unresizable = false
	always_on_top = false
	exclusive = true
	close_requested.connect(_on_close_requested)
	_setup_ui()

func _setup_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 10
	vbox.offset_top = 10
	vbox.offset_right = -10
	vbox.offset_bottom = -10
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)

	var title_label := Label.new()
	title_label.text = "Editar TakeItemCommand"
	title_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title_label)
	vbox.add_child(HSeparator.new())

	var item_row := HBoxContainer.new()
	var item_label := Label.new()
	item_label.text = "Ítem a quitar:"
	item_label.custom_minimum_size.x = 140
	item_row.add_child(item_label)
	item_option = OptionButton.new()
	item_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_row.add_child(item_option)
	item_picker_button = Button.new()
	item_picker_button.text = "Picker..."
	item_picker_button.pressed.connect(_on_item_picker_pressed)
	item_row.add_child(item_picker_button)
	vbox.add_child(item_row)

	var qty_row := HBoxContainer.new()
	var qty_label := Label.new()
	qty_label.text = "Cantidad:"
	qty_label.custom_minimum_size.x = 140
	qty_row.add_child(qty_label)
	quantity_spin = SpinBox.new()
	quantity_spin.min_value = 1
	quantity_spin.max_value = 999
	quantity_spin.step = 1
	quantity_spin.value = 1
	quantity_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	qty_row.add_child(quantity_spin)
	vbox.add_child(qty_row)

	var info_label := Label.new()
	info_label.text = "Si pides más de lo que hay, quitará el máximo disponible."
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(info_label)

	vbox.add_spacer(false)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 10)

	var accept_button := Button.new()
	accept_button.text = "Aceptar"
	accept_button.pressed.connect(_on_accept_pressed)
	buttons.add_child(accept_button)

	var cancel_button := Button.new()
	cancel_button.text = "Cancelar"
	cancel_button.pressed.connect(_on_cancel_pressed)
	buttons.add_child(cancel_button)
	vbox.add_child(buttons)

	_reload_items()

func load_command(cmd) -> void:
	if not cmd:
		push_error("TakeItemCommandEditor: No se proporcionó un comando válido")
		return

	command = cmd
	original_item_id = int(cmd.item_id)
	original_quantity = int(cmd.quantity)

	_reload_items()
	_select_item_id(original_item_id)
	if quantity_spin:
		quantity_spin.value = maxi(1, original_quantity)

func _reload_items() -> void:
	if not item_option:
		return
	item_option.clear()
	_item_ids_by_option_index.clear()

	var entries := _collect_item_entries()
	if entries.is_empty():
		item_option.add_item("(Sin ítems disponibles)")
		_item_ids_by_option_index.append(0)
		item_option.disabled = true
		return

	item_option.disabled = false
	for entry in entries:
		var item_label := "%03d - %s" % [entry.id, entry.name]
		item_option.add_item(item_label)
		_item_ids_by_option_index.append(entry.id)

func _collect_item_entries() -> Array:
	var out: Array = []
	var dir := DirAccess.open(ProjectSettings.globalize_path(ITEMS_DIR))
	if dir == null:
		return out

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if dir.current_is_dir() or not file_name.ends_with(".tres"):
			file_name = dir.get_next()
			continue

		var file_base := file_name.get_basename()
		var parts := file_base.split(" - ", false, 1)
		if parts.is_empty():
			file_name = dir.get_next()
			continue

		var id_str := str(parts[0]).strip_edges()
		if not id_str.is_valid_int():
			file_name = dir.get_next()
			continue

		var item_id := int(id_str)
		if item_id <= 0:
			file_name = dir.get_next()
			continue

		var display_name := ""
		if parts.size() > 1:
			display_name = str(parts[1]).strip_edges()
		if display_name.is_empty():
			display_name = "Item #%d" % item_id

		out.append({
			"id": item_id,
			"name": display_name,
		})
		file_name = dir.get_next()
	dir.list_dir_end()

	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.id) < int(b.id)
	)
	return out

func _select_item_id(target_item_id: int) -> void:
	if not item_option:
		return
	var target := target_item_id
	if target <= 0 and not _item_ids_by_option_index.is_empty():
		target = int(_item_ids_by_option_index[0])
	for i in range(_item_ids_by_option_index.size()):
		if int(_item_ids_by_option_index[i]) == target:
			item_option.selected = i
			return
	if item_option.get_item_count() > 0:
		item_option.selected = 0

func _apply_values_to_command() -> void:
	if not command:
		return
	var selected_idx := item_option.selected if item_option else -1
	var selected_item_id := 0
	if selected_idx >= 0 and selected_idx < _item_ids_by_option_index.size():
		selected_item_id = int(_item_ids_by_option_index[selected_idx])
	command.item_id = selected_item_id
	command.quantity = int(quantity_spin.value) if quantity_spin else 1

func _restore_original_values() -> void:
	if not command:
		return
	command.item_id = original_item_id
	command.quantity = original_quantity

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

func _on_item_picker_pressed() -> void:
	if not Engine.is_editor_hint():
		return
	var initial_item_id := 0
	if item_option and item_option.selected >= 0 and item_option.selected < _item_ids_by_option_index.size():
		initial_item_id = int(_item_ids_by_option_index[item_option.selected])
	var picker_window = ResourcePickerAPI.open_item_picker(
		initial_item_id,
		_on_item_picker_selected,
		_on_item_picker_cancelled
	)
	if picker_window == null:
		push_warning("TakeItemCommandEditor: No se pudo abrir el selector de ítems.")

func _on_item_picker_selected(result) -> void:
	if result == null:
		return
	var picked_item_id := int(result.resource_id)
	if picked_item_id <= 0 and result.resource != null:
		picked_item_id = int(result.resource.get("id"))
	if picked_item_id <= 0:
		push_warning("TakeItemCommandEditor: No se pudo obtener el ID del ítem seleccionado.")
		return
	_select_item_id(picked_item_id)

func _on_item_picker_cancelled() -> void:
	pass
