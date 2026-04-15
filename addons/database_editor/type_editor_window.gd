@tool
extends Window

signal saved(type_data: TypeData, was_new: bool)
signal cancelled()

enum EditorMode { EDIT, CREATE, DUPLICATE }

var current_type_data: TypeData = null
var editor_mode: int = EditorMode.EDIT
var original_resource_path: String = ""
var refresh_callback: Callable = Callable()
var available_types: Array[TypeData] = []

var ineffective_ids: Array[int] = []
var no_effect_to_ids: Array[int] = []
var no_effect_from_ids: Array[int] = []
var resistance_ids: Array[int] = []
var super_effective_ids: Array[int] = []
var weakness_ids: Array[int] = []

@onready var id_spin: SpinBox = $VBoxContainer/ScrollContainer/Content/GeneralSection/IdContainer/IdSpinBox
@onready var internal_name_line: LineEdit = $VBoxContainer/ScrollContainer/Content/GeneralSection/InternalNameContainer/InternalNameLineEdit
@onready var display_name_line: LineEdit = $VBoxContainer/ScrollContainer/Content/GeneralSection/DisplayNameContainer/DisplayNameLineEdit
@onready var panel_move_spin: SpinBox = $VBoxContainer/ScrollContainer/Content/GeneralSection/PanelMoveContainer/PanelMoveSpinBox

@onready var ineffective_list: ItemList = $VBoxContainer/ScrollContainer/Content/ArraysSection/IneffectiveSection/IneffectiveRow/IneffectiveList
@onready var ineffective_add_button: Button = $VBoxContainer/ScrollContainer/Content/ArraysSection/IneffectiveSection/IneffectiveRow/Buttons/AddButton
@onready var ineffective_remove_button: Button = $VBoxContainer/ScrollContainer/Content/ArraysSection/IneffectiveSection/IneffectiveRow/Buttons/RemoveButton

@onready var no_effect_to_list: ItemList = $VBoxContainer/ScrollContainer/Content/ArraysSection/NoEffectToSection/NoEffectToRow/NoEffectToList
@onready var no_effect_to_add_button: Button = $VBoxContainer/ScrollContainer/Content/ArraysSection/NoEffectToSection/NoEffectToRow/Buttons/AddButton
@onready var no_effect_to_remove_button: Button = $VBoxContainer/ScrollContainer/Content/ArraysSection/NoEffectToSection/NoEffectToRow/Buttons/RemoveButton

@onready var no_effect_from_list: ItemList = $VBoxContainer/ScrollContainer/Content/ArraysSection/NoEffectFromSection/NoEffectFromRow/NoEffectFromList
@onready var no_effect_from_add_button: Button = $VBoxContainer/ScrollContainer/Content/ArraysSection/NoEffectFromSection/NoEffectFromRow/Buttons/AddButton
@onready var no_effect_from_remove_button: Button = $VBoxContainer/ScrollContainer/Content/ArraysSection/NoEffectFromSection/NoEffectFromRow/Buttons/RemoveButton

@onready var resistance_list: ItemList = $VBoxContainer/ScrollContainer/Content/ArraysSection/ResistanceSection/ResistanceRow/ResistanceList
@onready var resistance_add_button: Button = $VBoxContainer/ScrollContainer/Content/ArraysSection/ResistanceSection/ResistanceRow/Buttons/AddButton
@onready var resistance_remove_button: Button = $VBoxContainer/ScrollContainer/Content/ArraysSection/ResistanceSection/ResistanceRow/Buttons/RemoveButton

@onready var super_effective_list: ItemList = $VBoxContainer/ScrollContainer/Content/ArraysSection/SuperEffectiveSection/SuperEffectiveRow/SuperEffectiveList
@onready var super_effective_add_button: Button = $VBoxContainer/ScrollContainer/Content/ArraysSection/SuperEffectiveSection/SuperEffectiveRow/Buttons/AddButton
@onready var super_effective_remove_button: Button = $VBoxContainer/ScrollContainer/Content/ArraysSection/SuperEffectiveSection/SuperEffectiveRow/Buttons/RemoveButton

@onready var weakness_list: ItemList = $VBoxContainer/ScrollContainer/Content/ArraysSection/WeaknessSection/WeaknessRow/WeaknessList
@onready var weakness_add_button: Button = $VBoxContainer/ScrollContainer/Content/ArraysSection/WeaknessSection/WeaknessRow/Buttons/AddButton
@onready var weakness_remove_button: Button = $VBoxContainer/ScrollContainer/Content/ArraysSection/WeaknessSection/WeaknessRow/Buttons/RemoveButton

@onready var save_button: Button = $VBoxContainer/Buttons/SaveButton
@onready var cancel_button: Button = $VBoxContainer/Buttons/CancelButton

func _ready() -> void:
	title = "Type Editor"
	unresizable = false
	always_on_top = false
	exclusive = true
	min_size = Vector2i(760, 700)
	close_requested.connect(_on_close_requested)
	save_button.pressed.connect(_on_save_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	_load_available_types()
	_connect_relation_buttons()

func open_edit(type_data: TypeData, refresh_cb: Callable = Callable()) -> void:
	if not type_data:
		return
	editor_mode = EditorMode.EDIT
	current_type_data = type_data
	original_resource_path = type_data.resource_path
	refresh_callback = refresh_cb
	_load_to_ui(type_data)
	popup_centered(Vector2i(760, 700))

func open_create(refresh_cb: Callable = Callable()) -> void:
	editor_mode = EditorMode.CREATE
	refresh_callback = refresh_cb
	current_type_data = TypeData.new()
	current_type_data.id = _get_next_available_id()
	current_type_data.internal_name = "new_type"
	current_type_data.Name = "Nuevo Tipo"
	current_type_data.panelMove_y = 0
	original_resource_path = ""
	_load_to_ui(current_type_data)
	popup_centered(Vector2i(760, 700))

func open_duplicate(type_data: TypeData, refresh_cb: Callable = Callable()) -> void:
	if not type_data:
		return
	editor_mode = EditorMode.DUPLICATE
	refresh_callback = refresh_cb
	current_type_data = type_data.duplicate(true) as TypeData
	current_type_data.id = _get_next_available_id()
	current_type_data.Name = "%s Copia" % current_type_data.Name
	current_type_data.internal_name = "%s_copy" % current_type_data.internal_name
	original_resource_path = ""
	_load_to_ui(current_type_data)
	popup_centered(Vector2i(760, 700))

func _load_to_ui(data: TypeData) -> void:
	id_spin.value = int(data.get("id")) if data.get("id") != null else 0
	internal_name_line.text = str(data.get("internal_name")) if data.get("internal_name") != null else ""
	display_name_line.text = str(data.get("Name")) if data.get("Name") != null else ""
	panel_move_spin.value = int(data.get("panelMove_y")) if data.get("panelMove_y") != null else 0

	var ineffective_val: Variant = data.get("ineffective")
	var no_effect_to_val: Variant = data.get("no_effect_to")
	var no_effect_from_val: Variant = data.get("no_effect_from")
	var resistance_val: Variant = data.get("resistance")
	var super_effective_val: Variant = data.get("super_effective")
	var weakness_val: Variant = data.get("weakness")

	ineffective_ids = (ineffective_val as Array).duplicate() if ineffective_val is Array else []
	no_effect_to_ids = (no_effect_to_val as Array).duplicate() if no_effect_to_val is Array else []
	no_effect_from_ids = (no_effect_from_val as Array).duplicate() if no_effect_from_val is Array else []
	resistance_ids = (resistance_val as Array).duplicate() if resistance_val is Array else []
	super_effective_ids = (super_effective_val as Array).duplicate() if super_effective_val is Array else []
	weakness_ids = (weakness_val as Array).duplicate() if weakness_val is Array else []
	_refresh_all_relation_lists()

func _on_save_pressed() -> void:
	if current_type_data == null:
		return
	if display_name_line.text.strip_edges().is_empty():
		_show_warning("El nombre visible no puede estar vacío.")
		return

	current_type_data.id = int(id_spin.value)
	current_type_data.internal_name = internal_name_line.text.strip_edges()
	current_type_data.Name = display_name_line.text.strip_edges()
	current_type_data.panelMove_y = int(panel_move_spin.value)
	current_type_data.ineffective = ineffective_ids.duplicate()
	current_type_data.no_effect_to = no_effect_to_ids.duplicate()
	current_type_data.no_effect_from = no_effect_from_ids.duplicate()
	current_type_data.resistance = resistance_ids.duplicate()
	current_type_data.super_effective = super_effective_ids.duplicate()
	current_type_data.weakness = weakness_ids.duplicate()

	var save_path := _resolve_save_path()
	var error := ResourceSaver.save(current_type_data, save_path)
	if error != OK:
		_show_warning("Error al guardar TypeData: %s" % error_string(error))
		return

	if refresh_callback.is_valid():
		refresh_callback.call()
	saved.emit(current_type_data, editor_mode != EditorMode.EDIT)
	queue_free()

func _resolve_save_path() -> String:
	if editor_mode == EditorMode.EDIT and not original_resource_path.is_empty():
		return original_resource_path

	var base_name := "%02d" % int(id_spin.value)
	var path := "res://Resources/Data/Types/%s.tres" % base_name
	var i := 1
	while ResourceLoader.exists(path):
		path = "res://Resources/Data/Types/%s_%d.tres" % [base_name, i]
		i += 1
	return path

func _get_next_available_id() -> int:
	var max_id := 0
	var dir := DirAccess.open(ProjectSettings.globalize_path("res://Resources/Data/Types"))
	if dir == null:
		dir = DirAccess.open("res://Resources/Data/Types")
	if dir == null:
		return 1
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var path := "res://Resources/Data/Types/" + file_name
			var res := load(path) as TypeData
			if res:
				max_id = maxi(max_id, res.id)
		file_name = dir.get_next()
	dir.list_dir_end()
	return max_id + 1

func _load_available_types() -> void:
	available_types.clear()
	var dir := DirAccess.open(ProjectSettings.globalize_path("res://Resources/Data/Types"))
	if dir == null:
		dir = DirAccess.open("res://Resources/Data/Types")
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var path := "res://Resources/Data/Types/" + file_name
			var res := load(path) as TypeData
			if res:
				available_types.append(res)
		file_name = dir.get_next()
	dir.list_dir_end()
	available_types.sort_custom(func(a, b): return a.id < b.id)

func _connect_relation_buttons() -> void:
	ineffective_add_button.pressed.connect(func(): _add_relation_to(ineffective_ids, ineffective_list))
	no_effect_to_add_button.pressed.connect(func(): _add_relation_to(no_effect_to_ids, no_effect_to_list))
	no_effect_from_add_button.pressed.connect(func(): _add_relation_to(no_effect_from_ids, no_effect_from_list))
	resistance_add_button.pressed.connect(func(): _add_relation_to(resistance_ids, resistance_list))
	super_effective_add_button.pressed.connect(func(): _add_relation_to(super_effective_ids, super_effective_list))
	weakness_add_button.pressed.connect(func(): _add_relation_to(weakness_ids, weakness_list))

	ineffective_remove_button.pressed.connect(func(): _remove_relation_from(ineffective_ids, ineffective_list))
	no_effect_to_remove_button.pressed.connect(func(): _remove_relation_from(no_effect_to_ids, no_effect_to_list))
	no_effect_from_remove_button.pressed.connect(func(): _remove_relation_from(no_effect_from_ids, no_effect_from_list))
	resistance_remove_button.pressed.connect(func(): _remove_relation_from(resistance_ids, resistance_list))
	super_effective_remove_button.pressed.connect(func(): _remove_relation_from(super_effective_ids, super_effective_list))
	weakness_remove_button.pressed.connect(func(): _remove_relation_from(weakness_ids, weakness_list))

func _add_relation_to(target_ids: Array[int], target_list: ItemList) -> void:
	var selector := ConfirmationDialog.new()
	selector.title = "Añadir tipo"
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for t in available_types:
		if current_type_data and t.id == current_type_data.id:
			continue
		option.add_item("%02d - %s" % [t.id, t.Name], t.id)
	var container := VBoxContainer.new()
	container.add_child(option)
	selector.add_child(container)
	add_child(selector)
	selector.popup_centered(Vector2i(360, 120))
	selector.confirmed.connect(func():
		var id := option.get_selected_id()
		if id > 0 and not target_ids.has(id):
			target_ids.append(id)
			target_ids.sort()
			_refresh_relation_list(target_list, target_ids)
		selector.queue_free()
	)
	selector.canceled.connect(func(): selector.queue_free())

func _remove_relation_from(target_ids: Array[int], target_list: ItemList) -> void:
	var selected := target_list.get_selected_items()
	if selected.is_empty():
		return
	var idx: int = selected[0]
	if idx < 0 or idx >= target_ids.size():
		return
	target_ids.remove_at(idx)
	_refresh_relation_list(target_list, target_ids)

func _refresh_all_relation_lists() -> void:
	_refresh_relation_list(ineffective_list, ineffective_ids)
	_refresh_relation_list(no_effect_to_list, no_effect_to_ids)
	_refresh_relation_list(no_effect_from_list, no_effect_from_ids)
	_refresh_relation_list(resistance_list, resistance_ids)
	_refresh_relation_list(super_effective_list, super_effective_ids)
	_refresh_relation_list(weakness_list, weakness_ids)

func _refresh_relation_list(target_list: ItemList, ids: Array[int]) -> void:
	target_list.clear()
	for id in ids:
		target_list.add_item(_get_type_name(id))

func _get_type_name(type_id: int) -> String:
	for t in available_types:
		if t.id == type_id:
			return t.Name if t.Name != "" else t.internal_name
	return "Tipo %d" % type_id

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
