extends Panel
class_name PCItemsUI

## UI depósito de ítems del PC (#831). Lista estilo Bag; la fila activa la marca el cursor.

signal closed()

const BAG_LIST_ENTRY_SCRIPT = preload("res://Scripts/UI/BagListEntry.gd")
const ITEM_BACK_TEXTURE: Texture2D = preload("res://Sprites/UI/Bag/itemBack.png")

enum Mode {
	WITHDRAW = 0, ## SACAR: lista del depósito PC
	DEPOSIT = 1, ## OBJETO: lista de la mochila para depositar
}

## Filas visibles en el viewport (el clip se calcula en código).
## 32px: mismo spacing visual que acordamos.
const _LIST_VISIBLE_ROWS: int = 7
const _ROW_HEIGHT: float = 32.0
const _ARROW_ANIM_FPS: float = 18.0

var _mode: Mode = Mode.WITHDRAW
var _current_items: Array = []
var _selected_item_index: int = 0
var _input_enabled: bool = false
var _list_scroll_top: int = 0
var _selection_cursor_base_y: float = 0.0
var _items_container_base_offset_top: float = 14.0
var _item_icon_back_texture: Texture2D = null
var _in_action_menu: bool = false
var _arrow_anim_time: float = 0.0

@onready var _description_label: Label = $Descripcion
@onready var _items_viewport: Control = $ItemsViewport
@onready var _items_container: VBoxContainer = $ItemsViewport/ItemsContainer
@onready var _item_template: HBoxContainer = $ItemsViewport/ItemsContainer/ExitTemplate
@onready var _cursor: Sprite2D = $Cursor
@onready var _item_icon: Sprite2D = $Item_Sprite
@onready var _sacar_label: Label = $Sacar
@onready var _objeto_label: Label = $Objeto
@onready var _up_arrow: Sprite2D = $U_Arrow
@onready var _down_arrow: Sprite2D = $D_Arrow


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	hide()
	if _items_container:
		_items_container_base_offset_top = _items_container.offset_top
	if _cursor:
		_selection_cursor_base_y = _cursor.position.y
	if _item_icon:
		_item_icon_back_texture = ITEM_BACK_TEXTURE
		_item_icon.texture = null
		_item_icon.hide()
	if _item_template and _items_container and _item_template.get_parent() == _items_container:
		_items_container.remove_child(_item_template)
		add_child(_item_template)
	if _item_template:
		_item_template.visible = false
	_update_list_scroll_arrows(0, 0)
	_apply_viewport_clip_height()


## Altura del viewport = padding superior del container + 7 filas (sin hueco para la 8ª).
func _apply_viewport_clip_height() -> void:
	if _items_viewport == null:
		return
	var spacing := _get_list_row_spacing()
	var h := _items_container_base_offset_top + spacing * float(_LIST_VISIBLE_ROWS)
	_items_viewport.offset_bottom = _items_viewport.offset_top + h
	_items_viewport.clip_contents = true


func open(mode: Mode = Mode.WITHDRAW) -> void:
	_mode = mode
	show()
	_arrow_anim_time = 0.0
	set_process(true)
	_selected_item_index = 0
	_list_scroll_top = 0
	_apply_viewport_clip_height()
	_refresh_list()
	_refresh_mode_labels()
	_enable_input()
	_block_player_control()


func close() -> void:
	if not visible:
		_disable_input()
		return
	_disable_input()
	_in_action_menu = false
	set_process(false)
	_reset_arrow_frames()
	_update_list_scroll_arrows(0, 0)
	# No hide aquí: DisplayManager funde a negro con la UI aún montada.
	closed.emit()


func set_input_enabled(value: bool) -> void:
	if value:
		_enable_input()
	else:
		_disable_input()


func refresh() -> void:
	if not visible:
		return
	_refresh_list()


func _refresh_mode_labels() -> void:
	_set_mode_label_active(_sacar_label, _mode == Mode.WITHDRAW)
	_set_mode_label_active(_objeto_label, _mode == Mode.DEPOSIT)


func _set_mode_label_active(label: Label, active: bool) -> void:
	if label == null or label.label_settings == null:
		return
	var settings := label.label_settings.duplicate() as LabelSettings
	settings.font_color = Color(1, 1, 1, 1) if active else Color(0.55, 0.55, 0.55, 1)
	label.label_settings = settings


func _refresh_list() -> void:
	_current_items.clear()
	if _mode == Mode.DEPOSIT:
		_build_deposit_list()
	else:
		_build_pc_storage_list()
	if _selected_item_index >= _current_items.size():
		_selected_item_index = maxi(_current_items.size() - 1, 0)
	if _selected_item_index < 0:
		_selected_item_index = 0
	_render_items()


func _build_pc_storage_list() -> void:
	var storage = null
	if GameStateService != null:
		storage = GameStateService.get_pc_item_storage()
	if storage != null:
		for entry in storage.get_entries():
			if entry == null:
				continue
			_current_items.append(_make_list_entry(int(entry.item_id), int(entry.quantity)))
	_current_items.append(_make_exit_entry())


func _build_withdraw_list() -> void:
	_build_pc_storage_list()


func _build_deposit_list() -> void:
	var bag: Bag = null
	if GameStateService != null:
		bag = GameStateService.get_bag()
	if bag != null:
		for pocket_entry in bag.to_serializable_data():
			if pocket_entry == null or not (pocket_entry is Dictionary):
				continue
			var item_id := int(pocket_entry.get("item_id", 0))
			var quantity := int(pocket_entry.get("quantity", 0))
			if item_id <= 0 or quantity <= 0:
				continue
			# Los objetos clave no se depositan en el PC.
			if DatabaseService != null:
				var data: ItemData = DatabaseService.get_item_by_id(item_id)
				if data != null and int(data.pocket) == int(ItemEnums.Pocket.KEY_ITEMS):
					continue
			_current_items.append(_make_list_entry(item_id, quantity))
	_current_items.append(_make_exit_entry())


func _make_exit_entry() -> BagListEntry:
	var entry := BAG_LIST_ENTRY_SCRIPT.create_exit_entry()
	entry.display_name = "SALIR"
	entry.description = "Volver al menú del PC."
	return entry


func _make_list_entry(item_id: int, quantity: int) -> BagListEntry:
	var display_name := "???"
	var description := ""
	var icon: Texture2D = null
	if DatabaseService != null:
		var data: ItemData = DatabaseService.get_item_by_id(item_id)
		if data != null:
			display_name = data.get_display_name()
			description = str(data.description)
			icon = data.icon
	return BAG_LIST_ENTRY_SCRIPT.create_item_entry(
		item_id, quantity, display_name, description, icon, true
	)


func _render_items() -> void:
	if _items_container == null:
		return

	for child in _items_container.get_children():
		_clear_row_labels(child)
		child.visible = false
		_items_container.remove_child(child)
		child.queue_free()
	_reset_list_scroll()

	for item in _current_items:
		if _item_template == null:
			continue
		var row := _item_template.duplicate() as HBoxContainer
		row.visible = true
		row.custom_minimum_size = Vector2(row.custom_minimum_size.x, _ROW_HEIGHT)
		_items_container.add_child(row)
		_apply_row_item_texts(row, item)

	_update_selection_visuals()
	if _items_viewport:
		_items_viewport.visible = true


func _apply_row_item_texts(row: Node, item) -> void:
	var name_label := row.get_node_or_null("Name") as Label
	var quantity_label := row.get_node_or_null("Quantity") as Label
	if name_label != null:
		name_label.text = str(item.display_name)
	if quantity_label != null:
		quantity_label.text = "" if item.is_exit else ("x %d" % int(item.quantity))


func _clear_row_labels(row: Node) -> void:
	for label_name in ["Name", "Quantity"]:
		var label := row.get_node_or_null(label_name) as Label
		if label != null:
			label.text = ""

func _get_list_row_spacing() -> float:
	var row_height := _ROW_HEIGHT
	if _item_template:
		row_height = float(_item_template.custom_minimum_size.y)
	var separation := 0.0
	if _items_container:
		separation = float(_items_container.get_theme_constant("separation", "VBoxContainer"))
	return row_height + separation


func _process(delta: float) -> void:
	if not visible:
		return
	_arrow_anim_time += delta
	var frame_count := _get_arrow_frame_count()
	var period := 1.0 / maxf(_ARROW_ANIM_FPS, 0.001)
	var frame := int(floor(_arrow_anim_time / period)) % frame_count
	if _up_arrow and _up_arrow.visible:
		_up_arrow.frame = frame
	if _down_arrow and _down_arrow.visible:
		_down_arrow.frame = frame


func _get_arrow_frame_count() -> int:
	if _up_arrow:
		return maxi(_up_arrow.hframes * _up_arrow.vframes, 1)
	if _down_arrow:
		return maxi(_down_arrow.hframes * _down_arrow.vframes, 1)
	return 8


func _reset_arrow_frames() -> void:
	if _up_arrow:
		_up_arrow.frame = 0
	if _down_arrow:
		_down_arrow.frame = 0


func _update_list_scroll_arrows(scroll_top: int, item_count: int) -> void:
	if _up_arrow == null or _down_arrow == null:
		return
	if item_count <= _LIST_VISIBLE_ROWS:
		_up_arrow.visible = false
		_down_arrow.visible = false
		return
	var max_scroll_top: int = maxi(item_count - _LIST_VISIBLE_ROWS, 0)
	_up_arrow.visible = scroll_top > 0
	_down_arrow.visible = scroll_top < max_scroll_top
	if not _up_arrow.visible:
		_up_arrow.frame = 0
	if not _down_arrow.visible:
		_down_arrow.frame = 0


func _reset_list_scroll() -> void:
	_list_scroll_top = 0
	if _items_container:
		_items_container.offset_top = _items_container_base_offset_top


func _apply_list_scroll(scroll_top: int, spacing_y: float) -> void:
	if _items_container:
		_items_container.offset_top = _items_container_base_offset_top - (float(scroll_top) * spacing_y)
	_update_row_visibility_for_scroll(scroll_top)


## Oculta el dibujo de filas fuera de ventana sin quitarlas del VBox (visible=false reflowea).
func _update_row_visibility_for_scroll(scroll_top: int) -> void:
	if _items_container == null:
		return
	var rows := _items_container.get_children()
	var last_visible := scroll_top + _LIST_VISIBLE_ROWS - 1
	for i in range(rows.size()):
		var row: Node = rows[i]
		if row is CanvasItem:
			var on_screen := i >= scroll_top and i <= last_visible
			(row as CanvasItem).modulate = Color(1, 1, 1, 1) if on_screen else Color(1, 1, 1, 0)


func _compute_list_scroll_top(item_count: int, selected_index: int) -> int:
	if item_count <= 0 or item_count <= _LIST_VISIBLE_ROWS:
		_list_scroll_top = 0
		return 0
	var max_scroll_top: int = maxi(item_count - _LIST_VISIBLE_ROWS, 0)
	if selected_index < _list_scroll_top:
		_list_scroll_top = selected_index
	elif selected_index >= _list_scroll_top + _LIST_VISIBLE_ROWS:
		_list_scroll_top = selected_index - _LIST_VISIBLE_ROWS + 1
	_list_scroll_top = clampi(_list_scroll_top, 0, max_scroll_top)
	return _list_scroll_top


func _update_selection_visuals() -> void:
	if _current_items.is_empty():
		if _cursor:
			_cursor.visible = false
		_reset_list_scroll()
		_update_row_visibility_for_scroll(0)
		_update_list_scroll_arrows(0, 0)
		_set_description("")
		if _item_icon:
			_item_icon.texture = null
			_item_icon.hide()
		return

	if _cursor:
		_cursor.visible = true
		var spacing_y := _get_list_row_spacing()
		var scroll_top := _compute_list_scroll_top(_current_items.size(), _selected_item_index)
		_update_list_scroll_arrows(scroll_top, _current_items.size())
		_apply_list_scroll(scroll_top, spacing_y)
		var cursor_row := _selected_item_index - scroll_top
		_cursor.position.y = _selection_cursor_base_y + (float(cursor_row) * spacing_y)

	var selected_item = _current_items[_selected_item_index]
	_set_description(str(selected_item.description))
	if _item_icon:
		if selected_item.is_exit:
			# No mostrar itemBack (símbolo ⏎ / “A”) en SALIR.
			_item_icon.texture = null
			_item_icon.hide()
		else:
			_item_icon.show()
			var icon = selected_item.icon
			_item_icon.texture = icon if icon != null else _item_icon_back_texture


func _set_description(text: String) -> void:
	if _description_label == null:
		return
	_description_label.text = text


func _navigate_up() -> void:
	if _current_items.is_empty():
		return
	var prev := _selected_item_index
	_selected_item_index -= 1
	if _selected_item_index < 0:
		_selected_item_index = _current_items.size() - 1
	if _selected_item_index != prev:
		_play_cursor_sound()
	_update_selection_visuals()


func _navigate_down() -> void:
	if _current_items.is_empty():
		return
	var prev := _selected_item_index
	_selected_item_index += 1
	if _selected_item_index >= _current_items.size():
		_selected_item_index = 0
	if _selected_item_index != prev:
		_play_cursor_sound()
	_update_selection_visuals()


func _switch_mode(_next: Mode) -> void:
	# No hay cambio de lista en esta UI: solo depósito PC.
	return


func _confirm_selection() -> void:
	if _current_items.is_empty() or _in_action_menu:
		return
	var selected_item = _current_items[_selected_item_index]
	if selected_item.is_exit:
		_play_cancel_sound()
		close()
		return
	_play_select_sound()
	await _open_item_action_menu(selected_item)


func _open_item_action_menu(entry: BagListEntry) -> void:
	_in_action_menu = true
	_disable_input()

	var item_name := str(entry.display_name)
	var options: Array[String]
	if _mode == Mode.WITHDRAW:
		options = ["SACAR", "DAR", "SALIR"]
	else:
		options = ["DEJAR", "SALIR"]

	# Mensaje más ancho: reserva = inset derecho del ChoiceBox + ancho del panel (+ gap común).
	DisplayManager.set_pc_items_message_side_reserve(
		DisplayManager.estimate_choice_panel_width(options) + 4.0
	)
	var select_msg: String = DisplayManager.pick_message_line_break(
		"Has seleccionado %s." % item_name,
		"Has seleccionado\n%s." % item_name
	)
	await DisplayManager.show_message(select_msg, {
		"waitInput": false,
		"closeAtEnd": false,
		"showIconAtEnd": false,
		"frameStyle": MessageBoxFrameStyle.Values.FIRERED,
		"typingMode": MessageBox.TypingMode.INSTANT,
	})
	DisplayManager.hide_message_wait_indicator()

	var choice: int = await DisplayManager.show_choices_corner(
		options,
		ChoiceBox.ChoiceAnchor.BOTTOM_RIGHT
	)
	DisplayManager.close_message()

	if not visible:
		_in_action_menu = false
		return

	if _mode == Mode.WITHDRAW:
		match choice:
			0:
				await _do_withdraw(entry)
			1:
				await _do_give(entry)
			_:
				pass
	else:
		match choice:
			0:
				await _do_deposit(entry)
			_:
				pass

	_in_action_menu = false
	if visible:
		_refresh_list()
		_enable_input()


func _do_withdraw(entry: BagListEntry) -> void:
	if GameStateService == null:
		return
	var storage = GameStateService.get_pc_item_storage()
	var bag: Bag = GameStateService.get_bag()
	if storage == null or bag == null:
		return
	var max_qty := maxi(int(entry.quantity), 1)
	var qty := await DisplayManager.prompt_quantity(max_qty, "¿Cuántos quieres sacar?")
	if qty <= 0:
		return
	var moved: int = int(storage.withdraw_to_bag(bag, int(entry.item_id), qty))
	if moved <= 0:
		await DisplayManager.show_message("La MOCHILA está llena.", {
			"waitInput": true,
			"closeAtEnd": true,
			"showIconAtEnd": false,
			"playConfirmSound": true,
			"fullWidth": true,
			"frameStyle": MessageBoxFrameStyle.Values.FIRERED,
			"typingMode": MessageBox.TypingMode.INSTANT,
		})
		return
	await DisplayManager.show_message("Sacaste %d %s." % [moved, entry.display_name], {
		"waitInput": true,
		"closeAtEnd": true,
		"showIconAtEnd": false,
		"playOpenSound": false,
		"playConfirmSound": true,
		"fullWidth": true,
		"frameStyle": MessageBoxFrameStyle.Values.FIRERED,
		"typingMode": MessageBox.TypingMode.INSTANT,
	})


func _do_deposit(entry: BagListEntry) -> void:
	if GameStateService == null:
		return
	var storage = GameStateService.get_pc_item_storage()
	var bag: Bag = GameStateService.get_bag()
	if storage == null or bag == null:
		return
	var max_qty := maxi(int(entry.quantity), 1)
	var qty := await DisplayManager.prompt_quantity(max_qty, "¿Qué cantidad?")
	if qty <= 0:
		return
	var moved: int = int(storage.deposit_from_bag(bag, int(entry.item_id), qty))
	if moved <= 0:
		await DisplayManager.show_message("No se pudo guardar el objeto.", {
			"waitInput": true,
			"closeAtEnd": true,
			"showIconAtEnd": false,
			"playConfirmSound": true,
			"frameStyle": MessageBoxFrameStyle.Values.FIRERED,
			"typingMode": MessageBox.TypingMode.INSTANT,
		})
		return
	await DisplayManager.show_message("Has dejado %d." % moved, {
		"waitInput": true,
		"closeAtEnd": true,
		"showIconAtEnd": false,
		"playOpenSound": false,
		"playConfirmSound": true,
		"frameStyle": MessageBoxFrameStyle.Values.FIRERED,
		"typingMode": MessageBox.TypingMode.INSTANT,
	})


func _do_give(entry: BagListEntry) -> void:
	if entry == null or GameStateService == null:
		return
	var storage = GameStateService.get_pc_item_storage()
	if storage == null or storage.get_quantity(entry.item_id) <= 0:
		return

	var slot: int = await DisplayManager.pick_party_slot_for_give_held()
	if not visible or slot < 0:
		return

	var party: Party = GameStateService.get_party()
	if party == null:
		await DisplayManager.close_party_give_held()
		return
	var mon: Pokemon = party.get_pokemon(slot)
	if mon == null:
		await DisplayManager.close_party_give_held()
		return

	var item_id: int = entry.item_id
	var mon_name := mon.get_display_name()
	var given_name := str(entry.display_name)
	var msg_cfg_wait := {
		"waitInput": true,
		"closeAtEnd": true,
		"showIconAtEnd": false,
		"playOpenSound": false,
		"playConfirmSound": true,
		"frameStyle": MessageBoxFrameStyle.Values.FIRERED,
		"typingMode": MessageBox.TypingMode.INSTANT,
		"fullWidth": true,
		"expandHeight": true,
	}

	# Ya lleva objeto → primero aviso a ancho completo; luego pregunta + SI/NO.
	if mon.held_item_id > 0:
		var held_name := _item_display_name(mon.held_item_id)
		await DisplayManager.show_message(
			"¡%s ya lleva una unidad de %s!" % [mon_name, held_name],
			{
				"waitInput": true,
				"closeAtEnd": true,
				"showIconAtEnd": false,
				"playOpenSound": false,
				"playConfirmSound": true,
				"frameStyle": MessageBoxFrameStyle.Values.FIRERED,
				"typingMode": MessageBox.TypingMode.INSTANT,
				"fullWidth": true,
				"expandHeight": true,
			}
		)
		if not visible:
			await DisplayManager.close_party_give_held()
			return

		var swap_options: Array[String] = ["SI", "NO"]
		DisplayManager.set_pc_items_message_side_reserve(
			DisplayManager.estimate_choice_panel_width(swap_options) + 4.0
		)
		await DisplayManager.show_message("¿Quieres cambiar un objeto por otro?", {
			"waitInput": false,
			"closeAtEnd": false,
			"showIconAtEnd": false,
			"playOpenSound": false,
			"frameStyle": MessageBoxFrameStyle.Values.FIRERED,
			"typingMode": MessageBox.TypingMode.INSTANT,
		})
		DisplayManager.hide_message_wait_indicator()
		if not visible:
			DisplayManager.clear_pc_items_message_side_reserve()
			await DisplayManager.close_party_give_held()
			return

		var dm := DisplayManager.instance
		if dm != null and dm.choice_box != null:
			dm.choice_box.set_next_initial_index(1)  # NO
		var choice: int = await DisplayManager.show_choices_corner(
			swap_options,
			ChoiceBox.ChoiceAnchor.BOTTOM_RIGHT
		)
		DisplayManager.close_message()
		DisplayManager.clear_pc_items_message_side_reserve()
		if not visible or choice != 0:
			await DisplayManager.close_party_give_held()
			return

		var removed: int = storage.remove_item(item_id, 1)
		if removed < 1:
			await DisplayManager.show_message("No hay ese objeto.", msg_cfg_wait)
			await DisplayManager.close_party_give_held()
			return

		var bag: Bag = GameStateService.get_bag()
		var old_id: int = mon.held_item_id
		var old_name := held_name
		if bag != null:
			bag.add_item(old_id, 1)
		mon.held_item_id = item_id
		DisplayManager.refresh_party_slots_display()

		await DisplayManager.show_message(
			"¡Se ha sustituido %s por %s!" % [old_name, given_name],
			msg_cfg_wait
		)
		await DisplayManager.close_party_give_held()
		return

	# Sin objeto: dar directamente.
	var removed_empty: int = storage.remove_item(item_id, 1)
	if removed_empty < 1:
		await DisplayManager.show_message("No hay ese objeto.", msg_cfg_wait)
		await DisplayManager.close_party_give_held()
		return

	mon.held_item_id = item_id
	DisplayManager.refresh_party_slots_display()
	await DisplayManager.show_message(
		"¡%s lleva ahora %s!" % [mon_name, given_name],
		msg_cfg_wait
	)
	await DisplayManager.close_party_give_held()


func _item_display_name(item_id: int) -> String:
	if item_id <= 0 or DatabaseService == null:
		return "???"
	var data: ItemData = DatabaseService.get_item_by_id(item_id)
	if data == null:
		return "???"
	return data.get_display_name()


func _enable_input() -> void:
	var dm := DisplayManager.instance
	if dm == null:
		return
	_disconnect_display_manager_input(dm)
	_input_enabled = true
	_connect_display_manager_input()


func _disable_input() -> void:
	_input_enabled = false
	var dm := DisplayManager.instance
	if dm == null:
		return
	_disconnect_display_manager_input(dm)


func _connect_display_manager_input() -> void:
	var dm := DisplayManager.instance
	if dm == null:
		return
	if not dm.input_up.is_connected(_on_input_up):
		dm.input_up.connect(_on_input_up)
	if not dm.input_down.is_connected(_on_input_down):
		dm.input_down.connect(_on_input_down)
	if not dm.input_left.is_connected(_on_input_left):
		dm.input_left.connect(_on_input_left)
	if not dm.input_right.is_connected(_on_input_right):
		dm.input_right.connect(_on_input_right)
	if not dm.input_accept.is_connected(_on_input_accept):
		dm.input_accept.connect(_on_input_accept)
	if not dm.input_cancel.is_connected(_on_input_cancel):
		dm.input_cancel.connect(_on_input_cancel)


func _disconnect_display_manager_input(dm: DisplayManager) -> void:
	if dm.input_up.is_connected(_on_input_up):
		dm.input_up.disconnect(_on_input_up)
	if dm.input_down.is_connected(_on_input_down):
		dm.input_down.disconnect(_on_input_down)
	if dm.input_left.is_connected(_on_input_left):
		dm.input_left.disconnect(_on_input_left)
	if dm.input_right.is_connected(_on_input_right):
		dm.input_right.disconnect(_on_input_right)
	if dm.input_accept.is_connected(_on_input_accept):
		dm.input_accept.disconnect(_on_input_accept)
	if dm.input_cancel.is_connected(_on_input_cancel):
		dm.input_cancel.disconnect(_on_input_cancel)


func _on_input_up() -> void:
	if _input_enabled and not _in_action_menu:
		_navigate_up()


func _on_input_down() -> void:
	if _input_enabled and not _in_action_menu:
		_navigate_down()


func _on_input_left() -> void:
	pass


func _on_input_right() -> void:
	pass


func _on_input_accept() -> void:
	if _input_enabled and not _in_action_menu:
		_confirm_selection()


func _on_input_cancel() -> void:
	if _input_enabled and not _in_action_menu:
		_play_cancel_sound()
		close()


func _block_player_control() -> void:
	var dm := DisplayManager.instance
	if dm:
		dm.player_control_blocked.emit()


func _unblock_player_control() -> void:
	if DisplayManager.is_battle_active():
		return
	var dm := DisplayManager.instance
	if dm:
		dm.player_control_unblocked.emit()


func _play_cursor_sound() -> void:
	AudioManager.play_ui_cursor()


func _play_select_sound() -> void:
	AudioManager.play_ui_select()


func _play_cancel_sound() -> void:
	AudioManager.play_ui_cancel()
