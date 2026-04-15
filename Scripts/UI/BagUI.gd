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
	ItemEnums.Pocket.KEY_ITEMS: preload("res://Sprites/UI/Bag/bagbg6.png"),
	ItemEnums.Pocket.MACHINES: preload("res://Sprites/UI/Bag/bagbg7.png"),
	ItemEnums.Pocket.BATTLE_ITEMS: preload("res://Sprites/UI/Bag/bagbg8.png")
}

var _controller = null
var _pockets: Array[int] = []
var _current_pocket_index: int = 0
var _selected_item_index: int = 0
var _current_items: Array = []
var _input_enabled: bool = false
var _background_stylebox: StyleBoxTexture = null

@onready var _description_label: RichTextLabel = $Descripcion
@onready var _items_container: VBoxContainer = $ItemsContainer
@onready var _item_template: HBoxContainer = $ItemsContainer/ExitTemplate
@onready var _selection_cursor: Sprite2D = $Select
@onready var _item_icon: Sprite2D = $Item_Sprite
@onready var _left_arrow: Sprite2D = $L_Arrow
@onready var _right_arrow: Sprite2D = $R_Arrow

var _pocket_label: Label = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
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
	_current_pocket_index = 0
	_selected_item_index = 0

func open() -> void:
	if _controller == null:
		push_error("BagUI: No se puede abrir sin controller. Llama setup(controller) primero.")
		return

	show()
	_refresh_current_pocket()
	_enable_input()
	_block_player_control()

func close() -> void:
	if not visible:
		return

	_disable_input()
	hide()
	_unblock_player_control()
	closed.emit()

func set_input_enabled(value: bool) -> void:
	if value:
		_enable_input()
	else:
		_disable_input()

func _refresh_current_pocket() -> void:
	if _controller == null or _pockets.is_empty():
		_current_items = [BAG_LIST_ENTRY_SCRIPT.create_exit_entry()]
		_render_background(ItemEnums.Pocket.ITEMS)
		_render_items()
		return

	var pocket := _pockets[_current_pocket_index]
	_render_background(pocket)
	_current_items = _controller.get_items_in_pocket(pocket)
	if _selected_item_index >= _current_items.size():
		_selected_item_index = max(_current_items.size() - 1, 0)
	if _selected_item_index < 0:
		_selected_item_index = 0
	_render_items()
	_render_pocket_name()
	_render_arrows()

func _render_background(pocket: int) -> void:
	if _background_stylebox == null:
		_background_stylebox = StyleBoxTexture.new()

	var bg_texture: Texture2D = _POCKET_BACKGROUNDS.get(pocket, null)
	if bg_texture == null:
		bg_texture = _POCKET_BACKGROUNDS.get(ItemEnums.Pocket.ITEMS, null)

	_background_stylebox.texture = bg_texture
	add_theme_stylebox_override("panel", _background_stylebox)

func _render_pocket_name() -> void:
	if _pocket_label == null or _controller == null or _pockets.is_empty():
		return

	var pocket := _pockets[_current_pocket_index]
	_pocket_label.text = _controller.get_pocket_name(pocket)

func _render_arrows() -> void:
	if _left_arrow:
		_left_arrow.visible = _pockets.size() > 1
	if _right_arrow:
		_right_arrow.visible = _pockets.size() > 1

func _render_items() -> void:
	for child in _items_container.get_children():
		if child == _item_template:
			continue
		child.queue_free()

	for item in _current_items:
		var row := _build_row_from_template()
		var name_label := row.get_node_or_null("Name")
		var quantity_label := row.get_node_or_null("Quantity")

		if name_label:
			if name_label.has_method("setText"):
				name_label.setText(str(item.display_name))
			else:
				name_label.text = str(item.display_name)

		var quantity_text := "" if item.is_exit else ("x%d" % int(item.quantity))
		if quantity_label:
			if quantity_label.has_method("setText"):
				quantity_label.setText(quantity_text)
			else:
				quantity_label.text = quantity_text

		_items_container.add_child(row)

	_update_selection_visuals()

func _update_selection_visuals() -> void:
	if _current_items.is_empty():
		return

	if _selection_cursor:
		_selection_cursor.visible = true
		var base_y := 36.0
		var spacing_y := 31.5
		_selection_cursor.position.y = base_y + (_selected_item_index * spacing_y)

	var selected_item = _current_items[_selected_item_index]
	_description_label.text = str(selected_item.description)
	var icon = selected_item.icon
	if _item_icon:
		_item_icon.texture = icon

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
	_current_pocket_index = (_current_pocket_index + 1) % _pockets.size()
	_selected_item_index = 0
	_refresh_current_pocket()

func _previous_pocket() -> void:
	if _pockets.is_empty():
		return
	_current_pocket_index -= 1
	if _current_pocket_index < 0:
		_current_pocket_index = _pockets.size() - 1
	_selected_item_index = 0
	_refresh_current_pocket()

func _confirm_selection() -> void:
	if _current_items.is_empty():
		return
	var selected_item = _current_items[_selected_item_index]
	if selected_item.is_exit:
		_request_back()
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
	_pocket_label = get_node_or_null("PocketLabel") as Label
	if _pocket_label != null:
		return

	_pocket_label = Label.new()
	_pocket_label.name = "PocketLabel"
	_pocket_label.position = Vector2(28, 10)
	_pocket_label.size = Vector2(140, 24)
	_pocket_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_pocket_label)

func _build_row_from_template() -> HBoxContainer:
	if _item_template:
		var duplicated = _item_template.duplicate() as HBoxContainer
		duplicated.visible = true
		return duplicated

	var fallback := HBoxContainer.new()
	fallback.custom_minimum_size = Vector2(270, 28)
	var name_label := Label.new()
	name_label.name = "Name"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fallback.add_child(name_label)
	var quantity_label := Label.new()
	quantity_label.name = "Quantity"
	quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fallback.add_child(quantity_label)
	return fallback

func _create_hgss_label(text: String, align_right: bool) -> LabelHGSS:
	var label := LabelHGSS.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.custom_minimum_size = Vector2(0, 34)
	label.align = 2 if align_right else 0

	var custom_theme := Theme.new()
	var font = load("res://Resources/UI/Fonts/Raw Fonts/pkmnhgss.ttf")
	var font_variation := FontVariation.new()
	font_variation.base_font = font
	font_variation.spacing_top = 4
	custom_theme.default_font = font_variation
	custom_theme.default_font_size = 26

	label.theme = custom_theme
	label.add_theme_color_override("default_color", Color(0.317647, 0.317647, 0.34902, 1))
	label.add_theme_color_override("font_shadow_color", Color(0.65098, 0.65098, 0.682353, 1))
	label.add_theme_constant_override("line_separation", 8)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 0)

	var outline1 := RichTextLabel.new()
	outline1.name = "Outline"
	outline1.bbcode_enabled = true
	outline1.fit_content = true
	outline1.scroll_active = false
	outline1.theme = custom_theme
	outline1.add_theme_color_override("default_color", Color(0.317647, 0.317647, 0.34902, 1))
	outline1.add_theme_color_override("font_shadow_color", Color(0.65098, 0.65098, 0.682353, 1))
	outline1.add_theme_constant_override("line_separation", 8)
	outline1.add_theme_constant_override("shadow_offset_x", 0)
	outline1.add_theme_constant_override("shadow_offset_y", 2)

	var outline2 := RichTextLabel.new()
	outline2.name = "Outline2"
	outline2.bbcode_enabled = true
	outline2.fit_content = true
	outline2.scroll_active = false
	outline2.theme = custom_theme
	outline2.add_theme_color_override("default_color", Color(0.317647, 0.317647, 0.34902, 1))
	outline2.add_theme_color_override("font_shadow_color", Color(0.65098, 0.65098, 0.682353, 1))
	outline2.add_theme_constant_override("line_separation", 8)
	outline2.add_theme_constant_override("shadow_offset_x", 2)
	outline2.add_theme_constant_override("shadow_offset_y", 2)

	label.add_child(outline1)
	label.add_child(outline2)
	label.setText(text)
	return label
