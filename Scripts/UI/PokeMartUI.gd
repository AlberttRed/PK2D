extends Panel
class_name PokeMartUI

## UI de tienda — compra (#834). Venta → BagUI (`open_bag_for_sell`).
## Menú raíz Comprar/Vender/Salir → #836 (OpenShopCommand).

signal closed()
signal back_requested()

const BAG_LIST_ENTRY_SCRIPT = preload("res://Scripts/UI/BagListEntry.gd")

## Filas visibles aproximadas (row 34px); se ajustará al probar.
const _LIST_VISIBLE_ROWS: int = 6
const _ARROW_ANIM_FPS: float = 18.0
const _MART_QTY_CAP: int = 99

var _shop: ShopData = null
var _current_items: Array = []
var _selected_item_index: int = 0
var _input_enabled: bool = false
var _in_transaction: bool = false
var _list_scroll_top: int = 0
var _selection_cursor_base_y: float = 0.0
var _items_container_base_offset_top: float = 14.0
var _item_icon_back_texture: Texture2D = null
var _arrow_anim_time: float = 0.0

@onready var _money_data = $Dinero/Data
@onready var _mochila_panel: Control = $Mochila
@onready var _bag_count_data = $Mochila/MarginContainer/StatsList/ItemCount/Data
@onready var _description_label: RichTextLabel = $Descripcion
@onready var _items_viewport: Control = $ItemsViewport
@onready var _items_container: VBoxContainer = $ItemsViewport/ItemsContainer
@onready var _item_template: HBoxContainer = $ItemsViewport/ItemsContainer/ExitTemplate
@onready var _selection_cursor: Sprite2D = $Select
@onready var _item_icon: Sprite2D = $Item_Sprite
@onready var _up_arrow: Sprite2D = $U_Arrow
@onready var _down_arrow: Sprite2D = $D_Arrow


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	hide()
	if _mochila_panel:
		_mochila_panel.visible = true
	var llevas: Control = get_node_or_null("Llevas") as Control
	if llevas:
		llevas.visible = false
	if _items_container:
		_items_container_base_offset_top = _items_container.offset_top
	if _selection_cursor:
		_selection_cursor_base_y = _selection_cursor.position.y
	if _item_icon:
		_item_icon_back_texture = _item_icon.texture
	if _item_template and _items_container and _item_template.get_parent() == _items_container:
		_items_container.remove_child(_item_template)
		add_child(_item_template)
	if _item_template:
		_item_template.visible = false
	_update_list_scroll_arrows(0, 0)
	_apply_viewport_clip_height()


func _apply_viewport_clip_height() -> void:
	if _items_viewport == null:
		return
	var spacing := _get_list_row_spacing()
	var h := _items_container_base_offset_top + spacing * float(_LIST_VISIBLE_ROWS)
	_items_viewport.offset_bottom = _items_viewport.offset_top + h
	_items_viewport.clip_contents = true
	_items_viewport.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW


func open(shop: ShopData) -> void:
	if shop == null:
		push_error("PokeMartUI: open() requiere un ShopData.")
		return
	_shop = shop
	_selected_item_index = 0
	_list_scroll_top = 0
	_in_transaction = false
	if _mochila_panel:
		_mochila_panel.visible = true
	show()
	_arrow_anim_time = 0.0
	set_process(true)
	_apply_viewport_clip_height()
	_refresh_money()
	_rebuild_list()
	_enable_input()
	_block_player_control()


func close(keep_visible: bool = false) -> void:
	if not visible:
		_disable_input()
		return
	_disable_input()
	_in_transaction = false
	_set_browse_details_visible(true)
	set_process(false)
	_reset_arrow_frames()
	_update_list_scroll_arrows(0, 0)
	if _mochila_panel:
		_mochila_panel.visible = true
	if not keep_visible:
		hide()
	_unblock_player_control()
	closed.emit()


func set_input_enabled(value: bool) -> void:
	if value:
		_enable_input()
	else:
		_disable_input()


func refresh() -> void:
	if not visible or _shop == null:
		return
	_refresh_money()
	_rebuild_list()


func _rebuild_list() -> void:
	_current_items.clear()
	_rebuild_buy_list()
	_current_items.append(_create_exit_entry())
	if _selected_item_index >= _current_items.size():
		_selected_item_index = maxi(_current_items.size() - 1, 0)
	_render_items()


func _rebuild_buy_list() -> void:
	if _shop == null:
		return
	for item_id_any in _shop.item_ids:
		var item_id := int(item_id_any)
		if item_id <= 0:
			continue
		var item_data: ItemData = DatabaseService.get_item_by_id(item_id)
		if item_data == null or not item_data.is_buyable():
			continue
		_current_items.append(BAG_LIST_ENTRY_SCRIPT.create_item_entry(
			item_id,
			int(item_data.buy_price),
			item_data.get_display_name(),
			str(item_data.description),
			item_data.icon,
			false
		))


func _create_exit_entry():
	var entry = BAG_LIST_ENTRY_SCRIPT.create_exit_entry()
	entry.display_name = "SALIR"
	entry.description = "Salir de la tienda."
	return entry


func _render_items() -> void:
	if _items_viewport:
		_items_viewport.visible = false

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
		var name_label := row.get_node_or_null("Name")
		var quantity_label := row.get_node_or_null("Quantity")

		if name_label:
			if name_label.has_method("setText"):
				name_label.setText(str(item.display_name))
			else:
				name_label.text = str(item.display_name)

		var price_text := "" if item.is_exit else _format_price(int(item.quantity))
		if quantity_label:
			if item.is_exit:
				quantity_label.visible = false
				if quantity_label.has_method("setText"):
					quantity_label.setText(" ")
				else:
					quantity_label.text = " "
			else:
				quantity_label.visible = true
				if quantity_label.has_method("setText"):
					quantity_label.setText(price_text)
				else:
					quantity_label.text = price_text

		_items_container.add_child(row)

	for child in _items_container.get_children():
		_sync_row_labels(child)

	_update_selection_visuals()
	call_deferred("_show_items_viewport")


func _show_items_viewport() -> void:
	for child in _items_container.get_children():
		_sync_row_labels(child)
	if _items_viewport:
		_items_viewport.visible = true


func _clear_row_labels(row: Node) -> void:
	for label_name in ["Name", "Quantity"]:
		var label: Node = row.get_node_or_null(label_name)
		if label != null and label.has_method("setText"):
			label.setText("")


func _sync_row_labels(row: Node) -> void:
	for label_name in ["Name", "Quantity"]:
		var label: Node = row.get_node_or_null(label_name)
		if label != null and label.has_method("_sync_outline_visual_immediate"):
			label._sync_outline_visual_immediate()


func _get_list_row_spacing() -> float:
	var row_height := 34.0
	if _item_template:
		row_height = float(_item_template.custom_minimum_size.y)
	var separation := float(_items_container.get_theme_constant("separation", "VBoxContainer"))
	return row_height + separation


func _compute_list_scroll_top(item_count: int, selected_index: int) -> int:
	if item_count <= 0 or item_count <= _LIST_VISIBLE_ROWS:
		_list_scroll_top = 0
		return 0
	var max_scroll_top: int = max(item_count - _LIST_VISIBLE_ROWS, 0)
	if selected_index < _list_scroll_top:
		_list_scroll_top = selected_index
	elif selected_index >= _list_scroll_top + _LIST_VISIBLE_ROWS:
		_list_scroll_top = selected_index - _LIST_VISIBLE_ROWS + 1
	_list_scroll_top = clampi(_list_scroll_top, 0, max_scroll_top)
	return _list_scroll_top


func _reset_list_scroll() -> void:
	_list_scroll_top = 0
	if _items_container:
		_items_container.offset_top = _items_container_base_offset_top


func _apply_list_scroll(scroll_top: int, spacing_y: float) -> void:
	if _items_container:
		_items_container.offset_top = _items_container_base_offset_top - (float(scroll_top) * spacing_y)


func _update_selection_visuals() -> void:
	if _current_items.is_empty():
		if _selection_cursor:
			_selection_cursor.visible = false
		_reset_list_scroll()
		_update_list_scroll_arrows(0, 0)
		_refresh_bag_count_for_selection()
		_set_description("")
		_set_item_icon(null)
		return

	if _selection_cursor:
		_selection_cursor.visible = true
		var spacing_y := _get_list_row_spacing()
		var scroll_top := _compute_list_scroll_top(_current_items.size(), _selected_item_index)
		_update_list_scroll_arrows(scroll_top, _current_items.size())
		_apply_list_scroll(scroll_top, spacing_y)
		var cursor_row := _selected_item_index - scroll_top
		_selection_cursor.position.y = _selection_cursor_base_y + (float(cursor_row) * spacing_y)

	var selected = _current_items[_selected_item_index]
	_set_description(str(selected.description))
	if selected.is_exit:
		_set_item_icon(null)
	else:
		_set_item_icon(selected.icon)
	_refresh_bag_count_for_selection()


func _refresh_money() -> void:
	var amount := 0
	if GameStateService != null:
		amount = int(GameStateService.get_money())
	_set_label_text(_money_data, _format_money(amount))


func _refresh_bag_count_for_selection() -> void:
	var qty_text := "0"
	if not _current_items.is_empty():
		var selected = _current_items[_selected_item_index]
		if selected.is_exit:
			qty_text = ""
		else:
			qty_text = str(_bag_qty(int(selected.item_id)))
	_set_label_text(_bag_count_data, qty_text)


func _bag_qty(item_id: int) -> int:
	if item_id <= 0 or GameStateService == null:
		return 0
	var bag = GameStateService.get_bag()
	if bag == null:
		return 0
	return int(bag.get_quantity(item_id))


func _set_description(text: String) -> void:
	if _description_label == null:
		return
	if _description_label.has_method("setText"):
		_description_label.setText(text)
	else:
		_description_label.text = text


func _set_item_icon(icon: Texture2D) -> void:
	if _item_icon == null:
		return
	if icon != null:
		_item_icon.texture = icon
	else:
		_item_icon.texture = _item_icon_back_texture


func _set_label_text(label, text: String) -> void:
	if label == null:
		return
	if label.has_method("setText"):
		label.setText(text)
	else:
		label.text = text


func _format_money(amount: int) -> String:
	return "$%s" % _format_thousands(amount)


func _format_price(price: int) -> String:
	return "$%s" % _format_thousands(price)


func _format_thousands(amount: int) -> String:
	var negative := amount < 0
	var n := absi(amount)
	var s := str(n)
	var out := ""
	var i := 0
	for c_i in range(s.length() - 1, -1, -1):
		if i > 0 and i % 3 == 0:
			out = "," + out
		out = s[c_i] + out
		i += 1
	if negative:
		out = "-" + out
	return out


func _navigate_up() -> void:
	if _current_items.is_empty() or _in_transaction:
		return
	var prev := _selected_item_index
	_selected_item_index -= 1
	if _selected_item_index < 0:
		_selected_item_index = _current_items.size() - 1
	if _selected_item_index != prev:
		_play_cursor_sound()
	_update_selection_visuals()


func _navigate_down() -> void:
	if _current_items.is_empty() or _in_transaction:
		return
	var prev := _selected_item_index
	_selected_item_index += 1
	if _selected_item_index >= _current_items.size():
		_selected_item_index = 0
	if _selected_item_index != prev:
		_play_cursor_sound()
	_update_selection_visuals()


func _confirm_selection() -> void:
	if _current_items.is_empty() or _in_transaction:
		return
	var selected = _current_items[_selected_item_index]
	if selected.is_exit:
		_request_back()
		return
	_play_select_sound()
	await _begin_buy(selected)


func _set_browse_details_visible(visible_details: bool) -> void:
	if _description_label:
		_description_label.visible = visible_details
	if _item_icon:
		_item_icon.visible = visible_details


func _begin_buy(entry) -> void:
	if _shop == null or entry == null:
		return
	var item_id := int(entry.item_id)
	var item_data: ItemData = DatabaseService.get_item_by_id(item_id)
	if item_data == null or not item_data.is_buyable():
		return

	_in_transaction = true
	_disable_input()

	var unit_price := int(item_data.buy_price)
	var max_qty := _max_buy_qty(item_id, unit_price, item_data)
	if max_qty <= 0:
		var reason := _buy_blocked_reason(item_id, unit_price, item_data)
		_set_browse_details_visible(false)
		await _show_mart_message(reason, true)
		_finish_transaction()
		return

	_refresh_bag_count_for_selection()
	_set_browse_details_visible(false)

	var prompt := "¿%s? Buena elección\n¿Cuántas unidades quieres?" % str(entry.display_name)
	var qty := await DisplayManager.prompt_quantity(
		max_qty, prompt, unit_price, MessageBoxFrameStyle.Values.FIRERED
	)
	if not visible:
		_in_transaction = false
		return
	if qty <= 0:
		_finish_transaction()
		return

	var total := unit_price * qty
	var item_name := str(entry.display_name)
	var confirm := "%s... Y quieres %d, ¿no?\nTe costará %s." % [item_name, qty, _format_money(total)]
	var accepted := await _confirm_yes_no(confirm)
	if not visible:
		_in_transaction = false
		return
	if not accepted:
		_finish_transaction()
		return

	if not _shop.buy(item_id, qty):
		await _show_mart_message("No se pudo completar la compra.", true)
		_finish_transaction()
		return

	_refresh_money()
	await _show_mart_message("¡Aquí tienes!\nMuchas gracias.", true)
	if visible:
		_rebuild_list()
	_finish_transaction()


func _finish_transaction() -> void:
	_in_transaction = false
	_set_browse_details_visible(true)
	if visible:
		_refresh_money()
		_refresh_bag_count_for_selection()
		_update_selection_visuals()
		_enable_input()


func _max_buy_qty(item_id: int, unit_price: int, item_data: ItemData) -> int:
	if unit_price <= 0 or item_data == null:
		return 0
	var money := 0
	if GameStateService != null:
		money = int(GameStateService.get_money())
	var affordable := money / unit_price
	if affordable <= 0:
		return 0

	var room := _MART_QTY_CAP
	var stack_limit := int(item_data.stack_limit)
	if stack_limit > 0:
		room = maxi(stack_limit - _bag_qty(item_id), 0)
	return clampi(mini(affordable, room), 0, _MART_QTY_CAP)


func _buy_blocked_reason(item_id: int, unit_price: int, item_data: ItemData) -> String:
	var money := 0
	if GameStateService != null:
		money = int(GameStateService.get_money())
	if unit_price > 0 and money < unit_price:
		return "No tienes suficiente dinero."
	var stack_limit := int(item_data.stack_limit) if item_data != null else 0
	if stack_limit > 0 and _bag_qty(item_id) >= stack_limit:
		return "No hay más espacio en la MOCHILA."
	return "No puedes comprar eso ahora."


func _confirm_yes_no(prompt: String) -> bool:
	var options: Array[String] = ["SÍ", "NO"]
	await DisplayManager.show_message(prompt, {
		"waitInput": false,
		"closeAtEnd": false,
		"showIconAtEnd": false,
		"fullWidth": true,
		"frameStyle": MessageBoxFrameStyle.Values.FIRERED,
		"typingMode": MessageBox.TypingMode.INSTANT,
	})
	DisplayManager.hide_message_wait_indicator()
	var choice: int = await DisplayManager.show_choices_corner(
		options,
		ChoiceBox.ChoiceAnchor.BOTTOM_RIGHT
	)
	DisplayManager.close_message()
	return choice == 0


func _show_mart_message(text: String, wait_input: bool) -> void:
	await DisplayManager.show_message(text, {
		"waitInput": wait_input,
		"closeAtEnd": true,
		"showIconAtEnd": false,
		"playConfirmSound": wait_input,
		"fullWidth": true,
		"frameStyle": MessageBoxFrameStyle.Values.FIRERED,
		"typingMode": MessageBox.TypingMode.TYPING,
	})


func _request_back() -> void:
	if _in_transaction:
		return
	_play_cancel_sound()
	back_requested.emit()
	close()


func _process(delta: float) -> void:
	if not visible:
		return
	_arrow_anim_time += delta
	var frame_count := _get_arrow_frame_count()
	var period := 1.0 / max(_ARROW_ANIM_FPS, 0.001)
	var frame := int(floor(_arrow_anim_time / period)) % frame_count
	if _up_arrow and _up_arrow.visible:
		_up_arrow.frame = frame
	if _down_arrow and _down_arrow.visible:
		_down_arrow.frame = frame


func _get_arrow_frame_count() -> int:
	if _up_arrow:
		return max(_up_arrow.hframes * _up_arrow.vframes, 1)
	if _down_arrow:
		return max(_down_arrow.hframes * _down_arrow.vframes, 1)
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
	var max_scroll_top: int = max(item_count - _LIST_VISIBLE_ROWS, 0)
	_up_arrow.visible = scroll_top > 0
	_down_arrow.visible = scroll_top < max_scroll_top
	if not _up_arrow.visible:
		_up_arrow.frame = 0
	if not _down_arrow.visible:
		_down_arrow.frame = 0


func _enable_input() -> void:
	var dm := DisplayManager.instance
	if dm == null:
		push_warning("PokeMartUI: DisplayManager no disponible; input desactivado.")
		return
	_disconnect_display_manager_input(dm)
	_input_enabled = true
	dm.input_up.connect(_on_input_up)
	dm.input_down.connect(_on_input_down)
	dm.input_accept.connect(_on_input_accept)
	dm.input_cancel.connect(_on_input_cancel)
	dm.input_start.connect(_on_input_start)


func _disable_input() -> void:
	_input_enabled = false
	var dm := DisplayManager.instance
	if dm == null:
		return
	_disconnect_display_manager_input(dm)


func _disconnect_display_manager_input(dm: DisplayManager) -> void:
	if dm.input_up.is_connected(_on_input_up):
		dm.input_up.disconnect(_on_input_up)
	if dm.input_down.is_connected(_on_input_down):
		dm.input_down.disconnect(_on_input_down)
	if dm.input_accept.is_connected(_on_input_accept):
		dm.input_accept.disconnect(_on_input_accept)
	if dm.input_cancel.is_connected(_on_input_cancel):
		dm.input_cancel.disconnect(_on_input_cancel)
	if dm.input_start.is_connected(_on_input_start):
		dm.input_start.disconnect(_on_input_start)


func _on_input_up() -> void:
	if _input_enabled:
		_navigate_up()


func _on_input_down() -> void:
	if _input_enabled:
		_navigate_down()


func _on_input_accept() -> void:
	if _input_enabled:
		_confirm_selection()


func _on_input_cancel() -> void:
	if _input_enabled:
		_request_back()


func _on_input_start() -> void:
	if _input_enabled:
		_request_back()


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
