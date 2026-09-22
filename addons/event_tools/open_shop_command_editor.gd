@tool
extends Window

## Editor de OpenShopCommand: elige un ShopData de res://Resources/Shops/.

signal command_edited(command: OpenShopCommand)
signal cancelled

const SHOPS_DIR := "res://Resources/Shops"

var command: OpenShopCommand = null
var _shop_option: OptionButton = null
var _shop_paths: Array[String] = []
var _original_shop: ShopData = null


func _ready() -> void:
	title = "Editar OpenShopCommand"
	size = Vector2(480, 220)
	unresizable = false
	always_on_top = false
	exclusive = true
	close_requested.connect(_on_close_requested)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 10
	vbox.offset_top = 10
	vbox.offset_right = -10
	vbox.offset_bottom = -10
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)

	var title_label := Label.new()
	title_label.text = "Editar OpenShopCommand"
	title_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title_label)
	vbox.add_child(HSeparator.new())

	var info_label := Label.new()
	info_label.text = "Abre el menú COMPRAR / VENDER / SALIR de la tienda."
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(info_label)

	var shop_row := HBoxContainer.new()
	shop_row.add_theme_constant_override("separation", 8)
	var shop_label := Label.new()
	shop_label.text = "Tienda:"
	shop_label.custom_minimum_size.x = 100
	shop_row.add_child(shop_label)

	_shop_option = OptionButton.new()
	_shop_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_row.add_child(_shop_option)
	vbox.add_child(shop_row)

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

	_populate_shops()


func load_command(cmd: OpenShopCommand) -> void:
	if not cmd:
		push_error("OpenShopCommandEditor: No se proporcionó un comando válido")
		return
	command = cmd
	_original_shop = cmd.shop_data
	_populate_shops()
	_select_shop(cmd.shop_data)


func _populate_shops() -> void:
	if _shop_option == null:
		return
	_shop_option.clear()
	_shop_paths.clear()

	_shop_option.add_item("(ninguna)")
	_shop_paths.append("")

	var dir := DirAccess.open(SHOPS_DIR)
	if dir == null:
		return

	var entries: Array[String] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			entries.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	entries.sort()

	for entry in entries:
		var path := SHOPS_DIR.path_join(entry)
		var res = load(path)
		if res == null or not (res is ShopData):
			continue
		var shop := res as ShopData
		var label: String = shop.display_name
		if label.is_empty():
			label = shop.shop_id
		if label.is_empty():
			label = entry.get_basename()
		_shop_option.add_item(label)
		_shop_paths.append(path)


func _select_shop(shop: ShopData) -> void:
	if _shop_option == null:
		return
	if shop == null:
		_shop_option.select(0)
		return

	var target_path := shop.resource_path
	for i in range(_shop_paths.size()):
		if _shop_paths[i] == target_path:
			_shop_option.select(i)
			return

	# Shop no listada (ruta externa): añadir entrada temporal.
	var label: String = shop.display_name
	if label.is_empty():
		label = shop.shop_id
	if label.is_empty():
		label = target_path.get_file() if not target_path.is_empty() else "ShopData"
	_shop_option.add_item(label)
	_shop_paths.append(target_path)
	_shop_option.select(_shop_option.item_count - 1)


func _apply_selection_to_command() -> void:
	if command == null or _shop_option == null:
		return
	var idx := _shop_option.selected
	if idx < 0 or idx >= _shop_paths.size():
		command.shop_data = null
		return
	var path := _shop_paths[idx]
	if path.is_empty():
		command.shop_data = null
		return
	var res = load(path)
	command.shop_data = res as ShopData


func _on_accept_pressed() -> void:
	_apply_selection_to_command()
	command_edited.emit(command)
	hide()


func _on_cancel_pressed() -> void:
	if command:
		command.shop_data = _original_shop
	cancelled.emit()
	hide()


func _on_close_requested() -> void:
	_on_cancel_pressed()
