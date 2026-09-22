@tool
extends Window

signal saved(shop_data: ShopData, was_new: bool)
signal cancelled()

enum EditorMode { EDIT, CREATE, DUPLICATE }

const SHOPS_DIR := "res://Resources/Shops"
const ItemLookup := preload("res://addons/database_editor/database_editor_item_lookup.gd")

var current_shop_data: ShopData = null
var editor_mode: int = EditorMode.EDIT
var original_resource_path: String = ""
var refresh_callback: Callable = Callable()
## Copia editable del catálogo mientras se edita.
var _working_item_ids: Array[int] = []

@onready var shop_id_line: LineEdit = $VBoxContainer/ScrollContainer/Content/GeneralSection/ShopIdContainer/ShopIdLineEdit
@onready var display_name_line: LineEdit = $VBoxContainer/ScrollContainer/Content/GeneralSection/DisplayNameContainer/DisplayNameLineEdit
@onready var catalog_list: ItemList = $VBoxContainer/ScrollContainer/Content/CatalogSection/CatalogList
@onready var add_item_button: Button = $VBoxContainer/ScrollContainer/Content/CatalogSection/CatalogButtons/AddItemButton
@onready var remove_item_button: Button = $VBoxContainer/ScrollContainer/Content/CatalogSection/CatalogButtons/RemoveItemButton
@onready var move_up_button: Button = $VBoxContainer/ScrollContainer/Content/CatalogSection/CatalogButtons/MoveUpButton
@onready var move_down_button: Button = $VBoxContainer/ScrollContainer/Content/CatalogSection/CatalogButtons/MoveDownButton
@onready var save_button: Button = $VBoxContainer/Buttons/SaveButton
@onready var cancel_button: Button = $VBoxContainer/Buttons/CancelButton


func _ready() -> void:
	title = "Shop Editor"
	unresizable = false
	always_on_top = false
	exclusive = true
	min_size = Vector2i(720, 520)
	close_requested.connect(_on_close_requested)
	save_button.pressed.connect(_on_save_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	add_item_button.pressed.connect(_on_add_item_pressed)
	remove_item_button.pressed.connect(_on_remove_item_pressed)
	move_up_button.pressed.connect(_on_move_up_pressed)
	move_down_button.pressed.connect(_on_move_down_pressed)
	catalog_list.item_selected.connect(_on_catalog_selection_changed)
	_update_catalog_buttons()


func open_edit(shop_data: ShopData, refresh_cb: Callable = Callable()) -> void:
	if not shop_data:
		return
	editor_mode = EditorMode.EDIT
	current_shop_data = shop_data
	original_resource_path = shop_data.resource_path
	refresh_callback = refresh_cb
	_load_to_ui(shop_data)
	popup_centered(Vector2i(720, 520))


func open_create(refresh_cb: Callable = Callable()) -> void:
	editor_mode = EditorMode.CREATE
	refresh_callback = refresh_cb
	current_shop_data = ShopData.new()
	current_shop_data.shop_id = "nueva_tienda"
	current_shop_data.display_name = "Nueva tienda"
	current_shop_data.item_ids = []
	original_resource_path = ""
	_load_to_ui(current_shop_data)
	popup_centered(Vector2i(720, 520))


func open_duplicate(shop_data: ShopData, refresh_cb: Callable = Callable()) -> void:
	if not shop_data:
		return
	editor_mode = EditorMode.DUPLICATE
	refresh_callback = refresh_cb
	current_shop_data = shop_data.duplicate(true) as ShopData
	current_shop_data.shop_id = "%s_copy" % str(shop_data.shop_id)
	current_shop_data.display_name = "%s Copia" % str(shop_data.display_name)
	original_resource_path = ""
	_load_to_ui(current_shop_data)
	popup_centered(Vector2i(720, 520))


func _load_to_ui(data: ShopData) -> void:
	shop_id_line.text = str(data.shop_id) if data.shop_id != null else ""
	display_name_line.text = str(data.display_name) if data.display_name != null else ""
	_working_item_ids.clear()
	for item_id in data.item_ids:
		_working_item_ids.append(int(item_id))
	_refresh_catalog_list()


func _refresh_catalog_list() -> void:
	catalog_list.clear()
	for item_id in _working_item_ids:
		catalog_list.add_item(_format_item_row(item_id))
	_update_catalog_buttons()


func _format_item_row(item_id: int) -> String:
	return ItemLookup.format_item_line(item_id)


func _on_add_item_pressed() -> void:
	ResourcePickerAPI.open_item_picker(null, func(result: ResourcePickerResult):
		if result == null:
			return
		var item_id := int(result.resource_id)
		if item_id <= 0:
			_show_warning("Selección de ítem inválida.")
			return
		if _working_item_ids.has(item_id):
			_show_warning("El ítem ya está en el catálogo.")
			return
		_working_item_ids.append(item_id)
		_refresh_catalog_list()
		catalog_list.select(_working_item_ids.size() - 1)
		_update_catalog_buttons()
	)


func _on_remove_item_pressed() -> void:
	var selected := catalog_list.get_selected_items()
	if selected.is_empty():
		return
	var index: int = selected[0]
	if index < 0 or index >= _working_item_ids.size():
		return
	_working_item_ids.remove_at(index)
	_refresh_catalog_list()


func _on_move_up_pressed() -> void:
	var selected := catalog_list.get_selected_items()
	if selected.is_empty():
		return
	var index: int = selected[0]
	if index <= 0:
		return
	var tmp: int = _working_item_ids[index - 1]
	_working_item_ids[index - 1] = _working_item_ids[index]
	_working_item_ids[index] = tmp
	_refresh_catalog_list()
	catalog_list.select(index - 1)
	_update_catalog_buttons()


func _on_move_down_pressed() -> void:
	var selected := catalog_list.get_selected_items()
	if selected.is_empty():
		return
	var index: int = selected[0]
	if index < 0 or index >= _working_item_ids.size() - 1:
		return
	var tmp: int = _working_item_ids[index + 1]
	_working_item_ids[index + 1] = _working_item_ids[index]
	_working_item_ids[index] = tmp
	_refresh_catalog_list()
	catalog_list.select(index + 1)
	_update_catalog_buttons()


func _on_catalog_selection_changed(_index: int) -> void:
	_update_catalog_buttons()


func _update_catalog_buttons() -> void:
	var selected := catalog_list.get_selected_items()
	var has_sel := not selected.is_empty()
	var index := selected[0] if has_sel else -1
	remove_item_button.disabled = not has_sel
	move_up_button.disabled = not has_sel or index <= 0
	move_down_button.disabled = not has_sel or index >= _working_item_ids.size() - 1


func _on_save_pressed() -> void:
	if current_shop_data == null:
		return

	var clean_id := shop_id_line.text.strip_edges()
	var clean_display := display_name_line.text.strip_edges()
	if clean_id.is_empty():
		_show_warning("El shop_id no puede estar vacío.")
		return
	if clean_display.is_empty():
		_show_warning("El nombre visible no puede estar vacío.")
		return

	current_shop_data.shop_id = clean_id
	current_shop_data.display_name = clean_display
	var catalog: Array[int] = []
	for item_id in _working_item_ids:
		catalog.append(int(item_id))
	current_shop_data.item_ids = catalog

	var save_path := _resolve_save_path(clean_id)
	var error := ResourceSaver.save(current_shop_data, save_path)
	if error != OK:
		_show_warning("Error al guardar ShopData: %s" % error_string(error))
		return

	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()

	if refresh_callback.is_valid():
		refresh_callback.call()
	saved.emit(current_shop_data, editor_mode != EditorMode.EDIT)
	queue_free()


func _resolve_save_path(shop_id: String) -> String:
	if editor_mode == EditorMode.EDIT and not original_resource_path.is_empty():
		return original_resource_path

	var safe := shop_id.strip_edges().to_lower().replace(" ", "_")
	safe = safe.replace("/", "-").replace("\\", "-").replace(":", "-")
	if safe.is_empty():
		safe = "shop"
	var path := "%s/%s.tres" % [SHOPS_DIR, safe]
	var i := 1
	while ResourceLoader.exists(path):
		path = "%s/%s_%d.tres" % [SHOPS_DIR, safe, i]
		i += 1
	return path


func _show_warning(message: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Aviso"
	dialog.dialog_text = message
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())


func _on_cancel_pressed() -> void:
	cancelled.emit()
	queue_free()


func _on_close_requested() -> void:
	cancelled.emit()
	queue_free()
