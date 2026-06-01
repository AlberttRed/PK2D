extends Panel
class_name BagUI

signal use_requested(item_id: int)
signal back_requested()
signal closed()

const BAG_CONTROLLER_SCRIPT = preload("res://Scripts/UI/BagController.gd")
const BAG_LIST_ENTRY_SCRIPT = preload("res://Scripts/UI/BagListEntry.gd")
const _POCKET_BACKGROUNDS: Dictionary = {
	ItemEnums.Pocket.ITEMS: preload("res://Sprites/UI/Bag/bagbg1.png"),
	ItemEnums.Pocket.MEDICINE: preload("res://Sprites/UI/Bag/bagbg2.png"),
	ItemEnums.Pocket.BALLS: preload("res://Sprites/UI/Bag/bagbg3.png"),
	ItemEnums.Pocket.TM_HM: preload("res://Sprites/UI/Bag/bagbg4.png"),
	ItemEnums.Pocket.BERRIES: preload("res://Sprites/UI/Bag/bagbg5.png"),
	ItemEnums.Pocket.MACHINES: preload("res://Sprites/UI/Bag/bagbg6.png"),
	ItemEnums.Pocket.BATTLE_ITEMS: preload("res://Sprites/UI/Bag/bagbg7.png"),
	ItemEnums.Pocket.KEY_ITEMS: preload("res://Sprites/UI/Bag/bagbg8.png")
}
const _POCKET_BAG_SPRITES: Dictionary = {
	ItemEnums.Pocket.ITEMS: preload("res://Sprites/UI/Bag/bag1.PNG"),
	ItemEnums.Pocket.MEDICINE: preload("res://Sprites/UI/Bag/bag2.PNG"),
	ItemEnums.Pocket.BALLS: preload("res://Sprites/UI/Bag/bag3.PNG"),
	ItemEnums.Pocket.TM_HM: preload("res://Sprites/UI/Bag/bag4.PNG"),
	ItemEnums.Pocket.BERRIES: preload("res://Sprites/UI/Bag/bag5.PNG"),
	ItemEnums.Pocket.MACHINES: preload("res://Sprites/UI/Bag/bag6.PNG"),
	ItemEnums.Pocket.BATTLE_ITEMS: preload("res://Sprites/UI/Bag/bag7.PNG"),
	ItemEnums.Pocket.KEY_ITEMS: preload("res://Sprites/UI/Bag/bag8.PNG")
}
## Filas visibles en la ventana de lista (comportamiento HGSS: el cursor llega a la 7.ª y luego hace scroll la lista).
const _LIST_VISIBLE_ROWS: int = 7
## Índice (0-based) de la última fila visible donde el cursor puede “pararse” antes de empezar a scrollear.
const _LIST_CURSOR_ANCHOR_INDEX: int = _LIST_VISIBLE_ROWS - 1
## Recorrido vertical del indicador de lista (track del slider), en coordenadas de escena.
const _SLIDER_Y_MAX: float = 199.0
const _ARROW_ANIM_FPS: float = 18.0
var _controller = null
var _pockets: Array[int] = []
var _current_pocket_index: int = 0
var _selected_item_index: int = 0
var _current_items: Array = []
var _input_enabled: bool = false
var _background_stylebox: StyleBoxTexture = null

@onready var _description_label: RichTextLabel = $Descripcion
@onready var _items_container: VBoxContainer = $ItemsViewport/ItemsContainer
@onready var _item_template: HBoxContainer = $ItemsViewport/ItemsContainer/ExitTemplate
@onready var _selection_cursor: Sprite2D = $Select
@onready var _slider: Sprite2D = $Slider
@onready var _item_icon: Sprite2D = $Item_Sprite
@onready var _bag_sprite: Sprite2D = $Mochila_Sprite
@onready var _up_arrow: Sprite2D = $U_Arrow
@onready var _down_arrow: Sprite2D = $D_Arrow
@onready var _left_arrow: Sprite2D = $L_Arrow
@onready var _right_arrow: Sprite2D = $R_Arrow

var _pocket_label = null
var _selection_cursor_base_y: float = 0.0
var _items_container_base_pos: Vector2 = Vector2.ZERO
var _slider_base_x: float = 0.0
var _slider_y_min: float = 83.0
var _arrow_anim_time: float = 0.0
## Textura por defecto del panel de objeto (definida en escena, normalmente `itemBack.png`).
var _item_icon_back_texture: Texture2D = null
## Índice seleccionado recordado por bolsillo (clave = ItemEnums.Pocket). -1 = aún no visitado.
var _pocket_list_index_by_pocket: Dictionary = {}
## Última posición de la mochila (bolsillo + cursor por bolsillo) entre aperturas en la misma sesión.
static var _session_navigation: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	hide()
	if _items_container:
		_items_container_base_pos = _items_container.position
	if _selection_cursor:
		_selection_cursor_base_y = _selection_cursor.position.y
	if _slider:
		_slider_base_x = _slider.position.x
		_slider_y_min = _slider.position.y
	if _item_icon:
		_item_icon_back_texture = _item_icon.texture
	if _item_template:
		_item_template.visible = false
	_background_stylebox = StyleBoxTexture.new()
	_ensure_pocket_label()

func setup(controller) -> void:
	if controller != null and not (controller is BAG_CONTROLLER_SCRIPT):
		push_error("BagUI: setup(controller) requiere una instancia de BagController.")
		return
	_controller = controller
	_pockets = _controller.get_pockets() if _controller else []


func get_navigation_state() -> Dictionary:
	return {
		"pocket_index": _current_pocket_index,
		"selected_item_index": _selected_item_index,
		"pocket_list_index_by_pocket": _pocket_list_index_by_pocket.duplicate(true),
	}


func restore_navigation_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	var pocket_count := _pockets.size()
	var pocket_index := int(state.get("pocket_index", _current_pocket_index))
	if pocket_count > 0:
		_current_pocket_index = clampi(pocket_index, 0, pocket_count - 1)
	else:
		_current_pocket_index = 0
	_selected_item_index = maxi(0, int(state.get("selected_item_index", 0)))
	var remembered = state.get("pocket_list_index_by_pocket", {})
	_pocket_list_index_by_pocket = remembered.duplicate(true) if remembered is Dictionary else {}


func _apply_session_navigation() -> void:
	if _session_navigation.is_empty():
		_current_pocket_index = 0
		_selected_item_index = 0
		_pocket_list_index_by_pocket.clear()
		return
	restore_navigation_state(_session_navigation)


func _persist_session_navigation() -> void:
	_track_current_pocket_selection()
	_session_navigation = get_navigation_state()

func open() -> void:
	if _controller == null:
		push_error("BagUI: No se puede abrir sin controller. Llama setup(controller) primero.")
		return

	show()
	_arrow_anim_time = 0.0
	set_process(true)
	_apply_session_navigation()
	_refresh_current_pocket()
	_enable_input()
	_block_player_control()

func close() -> void:
	if not visible:
		return

	_persist_session_navigation()
	_disable_input()
	set_process(false)
	_reset_arrow_frames()
	hide()
	_unblock_player_control()
	closed.emit()

func set_input_enabled(value: bool) -> void:
	if value:
		_enable_input()
	else:
		_disable_input()


## Tras mutar el Bag (p. ej. consumir ítem); sin señales globales.
func refresh_from_controller() -> void:
	if _controller == null or not visible:
		return
	_track_current_pocket_selection()
	_refresh_current_pocket()


func _refresh_current_pocket() -> void:
	if _controller == null or _pockets.is_empty():
		_current_items = [BAG_LIST_ENTRY_SCRIPT.create_exit_entry()]
		_render_background(ItemEnums.Pocket.ITEMS)
		_render_bag_sprite(ItemEnums.Pocket.ITEMS)
		_restore_selection_for_current_pocket()
		_render_items()
		return

	var pocket := _pockets[_current_pocket_index]
	_render_background(pocket)
	_render_bag_sprite(pocket)
	_current_items = _controller.get_items_in_pocket(pocket)
	_restore_selection_for_current_pocket()
	_render_items()
	_render_pocket_name()
	_render_arrows()

func _restore_selection_for_current_pocket() -> void:
	if _pockets.is_empty():
		_selected_item_index = 0
		return
	var pocket_key := _pockets[_current_pocket_index]
	var remembered: Variant = _pocket_list_index_by_pocket.get(pocket_key, -1)
	if remembered is int and int(remembered) >= 0:
		_selected_item_index = int(remembered)
	if _current_items.is_empty():
		_selected_item_index = 0
		return
	if _selected_item_index >= _current_items.size():
		_selected_item_index = max(_current_items.size() - 1, 0)
	if _selected_item_index < 0:
		_selected_item_index = 0

func _remember_selection_for_pocket(pocket_key: int) -> void:
	_pocket_list_index_by_pocket[pocket_key] = _selected_item_index

func _track_current_pocket_selection() -> void:
	if _pockets.is_empty():
		return
	var pocket_key := _pockets[_current_pocket_index]
	_pocket_list_index_by_pocket[pocket_key] = _selected_item_index

func _render_background(pocket: int) -> void:
	if _background_stylebox == null:
		_background_stylebox = StyleBoxTexture.new()

	var bg_texture: Texture2D = _POCKET_BACKGROUNDS.get(pocket, null)
	if bg_texture == null:
		bg_texture = _POCKET_BACKGROUNDS.get(ItemEnums.Pocket.ITEMS, null)

	_background_stylebox.texture = bg_texture
	add_theme_stylebox_override("panel", _background_stylebox)

func _render_bag_sprite(pocket: int) -> void:
	if _bag_sprite == null:
		return

	var sprite_texture: Texture2D = _POCKET_BAG_SPRITES.get(pocket, null)
	if sprite_texture == null:
		sprite_texture = _POCKET_BAG_SPRITES.get(ItemEnums.Pocket.ITEMS, null)

	_bag_sprite.texture = sprite_texture

func _render_pocket_name() -> void:
	if _pocket_label == null or _controller == null or _pockets.is_empty():
		return

	var pocket := _pockets[_current_pocket_index]
	var pocket_text: String = _controller.get_pocket_name(pocket)
	if _pocket_label.has_method("setText"):
		_pocket_label.setText(pocket_text)
	else:
		_pocket_label.text = pocket_text

func _render_arrows() -> void:
	if _left_arrow:
		_left_arrow.visible = _pockets.size() > 1
	if _right_arrow:
		_right_arrow.visible = _pockets.size() > 1
	if _pockets.size() <= 1:
		_reset_arrow_frames()
		_update_list_scroll_arrows(0, 0)

func _process(delta: float) -> void:
	if not visible:
		return
	_arrow_anim_time += delta
	var frame_count := _get_arrow_frame_count()
	var period := 1.0 / max(_ARROW_ANIM_FPS, 0.001)
	var frame := int(floor(_arrow_anim_time / period)) % frame_count
	if _left_arrow and _left_arrow.visible:
		_left_arrow.frame = frame
	if _right_arrow and _right_arrow.visible:
		_right_arrow.frame = frame
	if _up_arrow and _up_arrow.visible:
		_up_arrow.frame = frame
	if _down_arrow and _down_arrow.visible:
		_down_arrow.frame = frame

func _get_arrow_frame_count() -> int:
	if _left_arrow:
		return max(_left_arrow.hframes * _left_arrow.vframes, 1)
	if _up_arrow:
		return max(_up_arrow.hframes * _up_arrow.vframes, 1)
	if _down_arrow:
		return max(_down_arrow.hframes * _down_arrow.vframes, 1)
	if _right_arrow:
		return max(_right_arrow.hframes * _right_arrow.vframes, 1)
	return 8

func _reset_arrow_frames() -> void:
	if _left_arrow:
		_left_arrow.frame = 0
	if _right_arrow:
		_right_arrow.frame = 0
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

func _render_items() -> void:
	for child in _items_container.get_children():
		if child == _item_template:
			continue
		child.queue_free()
	_items_container.position = _items_container_base_pos

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

		var quantity_text := "" if item.is_exit else ("x %d" % int(item.quantity))
		if quantity_label:
			if quantity_label.has_method("setText"):
				quantity_label.setText(quantity_text)
			else:
				quantity_label.text = quantity_text

		_items_container.add_child(row)

	_update_selection_visuals()

func _get_list_row_spacing() -> float:
	var row_height := 32.0
	if _item_template:
		row_height = float(_item_template.custom_minimum_size.y)
	var separation := float(_items_container.get_theme_constant("separation", "VBoxContainer"))
	return row_height + separation

func _compute_list_scroll_top(item_count: int, selected_index: int) -> int:
	if item_count <= 0:
		return 0
	if item_count <= _LIST_VISIBLE_ROWS:
		return 0
	var max_scroll_top: int = max(item_count - _LIST_VISIBLE_ROWS, 0)
	var desired_top: int = selected_index - _LIST_CURSOR_ANCHOR_INDEX
	return clampi(desired_top, 0, max_scroll_top)

func _update_selection_visuals() -> void:
	if _current_items.is_empty():
		if _selection_cursor:
			_selection_cursor.visible = false
		if _items_container:
			_items_container.position = _items_container_base_pos
		if _slider:
			_slider.position = Vector2(_slider_base_x, _slider_y_min)
		_update_list_scroll_arrows(0, 0)
		return

	if _selection_cursor:
		_selection_cursor.visible = true
		var spacing_y := _get_list_row_spacing()
		var scroll_top := _compute_list_scroll_top(_current_items.size(), _selected_item_index)
		_update_list_scroll_arrows(scroll_top, _current_items.size())
		_items_container.position = Vector2(
			_items_container_base_pos.x,
			_items_container_base_pos.y - (float(scroll_top) * spacing_y)
		)
		var cursor_row := mini(_selected_item_index, _LIST_CURSOR_ANCHOR_INDEX)
		_selection_cursor.position.y = _selection_cursor_base_y + (float(cursor_row) * spacing_y)

	if _slider:
		var n := _current_items.size()
		var slider_y := _slider_y_min
		if n > 1:
			var max_index := n - 1
			var t := float(_selected_item_index) / float(max_index)
			slider_y = lerpf(_slider_y_min, _SLIDER_Y_MAX, t)
		_slider.position = Vector2(_slider_base_x, slider_y)

	var selected_item = _current_items[_selected_item_index]
	if _description_label.has_method("setText"):
		_description_label.setText(str(selected_item.description))
	else:
		_description_label.text = str(selected_item.description)
	if _item_icon:
		if selected_item.is_exit:
			_item_icon.texture = _item_icon_back_texture
		else:
			var icon = selected_item.icon
			_item_icon.texture = icon if icon != null else _item_icon_back_texture
	_track_current_pocket_selection()

func _navigate_up() -> void:
	if _current_items.is_empty():
		return
	_selected_item_index -= 1
	if _selected_item_index < 0:
		_selected_item_index = _current_items.size() - 1
	_update_selection_visuals()

func _navigate_down() -> void:
	if _current_items.is_empty():
		return
	_selected_item_index += 1
	if _selected_item_index >= _current_items.size():
		_selected_item_index = 0
	_update_selection_visuals()

func _next_pocket() -> void:
	if _pockets.is_empty():
		return
	var prev_pocket := _pockets[_current_pocket_index]
	_remember_selection_for_pocket(prev_pocket)
	_current_pocket_index = (_current_pocket_index + 1) % _pockets.size()
	_refresh_current_pocket()

func _previous_pocket() -> void:
	if _pockets.is_empty():
		return
	var prev_pocket := _pockets[_current_pocket_index]
	_remember_selection_for_pocket(prev_pocket)
	_current_pocket_index -= 1
	if _current_pocket_index < 0:
		_current_pocket_index = _pockets.size() - 1
	_refresh_current_pocket()

func _confirm_selection() -> void:
	if _current_items.is_empty():
		return
	var selected_item = _current_items[_selected_item_index]
	if selected_item.is_exit:
		_request_back()
		return
	if not selected_item.is_usable_overworld:
		return
	use_requested.emit(int(selected_item.item_id))

func _request_back() -> void:
	back_requested.emit()

func _enable_input() -> void:
	if _input_enabled:
		return
	_input_enabled = true

	var dm := DisplayManager.instance
	if not dm:
		push_error("BagUI: DisplayManager no disponible para gestionar input.")
		return

	dm.input_up.connect(_on_input_up)
	dm.input_down.connect(_on_input_down)
	dm.input_left.connect(_on_input_left)
	dm.input_right.connect(_on_input_right)
	dm.input_accept.connect(_on_input_accept)
	dm.input_cancel.connect(_on_input_cancel)
	dm.input_start.connect(_on_input_start)

func _disable_input() -> void:
	if not _input_enabled:
		return
	_input_enabled = false

	var dm := DisplayManager.instance
	if not dm:
		return

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
	if dm.input_start.is_connected(_on_input_start):
		dm.input_start.disconnect(_on_input_start)

func _on_input_up() -> void:
	if _input_enabled:
		_navigate_up()

func _on_input_down() -> void:
	if _input_enabled:
		_navigate_down()

func _on_input_left() -> void:
	if _input_enabled:
		_previous_pocket()

func _on_input_right() -> void:
	if _input_enabled:
		_next_pocket()

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
	var dm := DisplayManager.instance
	if dm:
		dm.player_control_unblocked.emit()

func _ensure_pocket_label() -> void:
	_pocket_label = get_node_or_null("PocketLabel")
	if _pocket_label == null:
		push_warning("BagUI: Falta el nodo 'PocketLabel' en la escena BAG.tscn.")
