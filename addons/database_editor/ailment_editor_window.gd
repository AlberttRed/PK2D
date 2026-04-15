@tool
extends Window

signal saved(ailment_data: AilmentData, was_new: bool)
signal cancelled()

enum EditorMode { EDIT, CREATE, DUPLICATE }

var current_ailment_data: AilmentData = null
var editor_mode: int = EditorMode.EDIT
var original_resource_path: String = ""
var refresh_callback: Callable = Callable()

@onready var id_spin: SpinBox = $VBoxContainer/ScrollContainer/Content/GeneralSection/IdContainer/IdSpinBox
@onready var internal_name_line: LineEdit = $VBoxContainer/ScrollContainer/Content/GeneralSection/InternalNameContainer/InternalNameLineEdit
@onready var display_name_line: LineEdit = $VBoxContainer/ScrollContainer/Content/GeneralSection/DisplayNameContainer/DisplayNameLineEdit
@onready var description_edit: TextEdit = $VBoxContainer/ScrollContainer/Content/GeneralSection/DescriptionContainer/DescriptionTextEdit
@onready var persistent_check: CheckBox = $VBoxContainer/ScrollContainer/Content/GeneralSection/PersistentContainer/PersistentCheckBox
@onready var icon_path_label: Label = $VBoxContainer/ScrollContainer/Content/GeneralSection/IconContainer/IconPathLabel
@onready var icon_pick_button: Button = $VBoxContainer/ScrollContainer/Content/GeneralSection/IconContainer/IconPickButton
@onready var icon_clear_button: Button = $VBoxContainer/ScrollContainer/Content/GeneralSection/IconContainer/IconClearButton
@onready var effect_path_label: Label = $VBoxContainer/ScrollContainer/Content/GeneralSection/EffectContainer/EffectPathLabel
@onready var effect_pick_button: Button = $VBoxContainer/ScrollContainer/Content/GeneralSection/EffectContainer/EffectPickButton
@onready var effect_clear_button: Button = $VBoxContainer/ScrollContainer/Content/GeneralSection/EffectContainer/EffectClearButton

@onready var save_button: Button = $VBoxContainer/Buttons/SaveButton
@onready var cancel_button: Button = $VBoxContainer/Buttons/CancelButton

func _ready() -> void:
	title = "Ailment Editor"
	unresizable = false
	always_on_top = false
	exclusive = true
	min_size = Vector2i(720, 520)
	close_requested.connect(_on_close_requested)
	save_button.pressed.connect(_on_save_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	icon_pick_button.pressed.connect(_on_icon_pick_pressed)
	icon_clear_button.pressed.connect(_on_icon_clear_pressed)
	effect_pick_button.pressed.connect(_on_effect_pick_pressed)
	effect_clear_button.pressed.connect(_on_effect_clear_pressed)

func open_edit(ailment_data: AilmentData, refresh_cb: Callable = Callable()) -> void:
	if not ailment_data:
		return
	editor_mode = EditorMode.EDIT
	current_ailment_data = ailment_data
	original_resource_path = ailment_data.resource_path
	refresh_callback = refresh_cb
	_load_to_ui(ailment_data)
	popup_centered(Vector2i(720, 520))

func open_create(refresh_cb: Callable = Callable()) -> void:
	editor_mode = EditorMode.CREATE
	refresh_callback = refresh_cb
	current_ailment_data = AilmentData.new()
	current_ailment_data.id = _get_next_available_id()
	current_ailment_data.internal_name = "new_ailment"
	current_ailment_data.display_name = "Nuevo Ailment"
	current_ailment_data.description = ""
	current_ailment_data.is_persistent = true
	original_resource_path = ""
	_load_to_ui(current_ailment_data)
	popup_centered(Vector2i(720, 520))

func open_duplicate(ailment_data: AilmentData, refresh_cb: Callable = Callable()) -> void:
	if not ailment_data:
		return
	editor_mode = EditorMode.DUPLICATE
	refresh_callback = refresh_cb
	current_ailment_data = ailment_data.duplicate(true) as AilmentData
	current_ailment_data.id = _get_next_available_id()
	current_ailment_data.display_name = "%s Copia" % current_ailment_data.display_name
	current_ailment_data.internal_name = "%s_copy" % current_ailment_data.internal_name
	original_resource_path = ""
	_load_to_ui(current_ailment_data)
	popup_centered(Vector2i(720, 520))

func _load_to_ui(data: AilmentData) -> void:
	id_spin.value = int(data.get("id")) if data.get("id") != null else 0
	internal_name_line.text = str(data.get("internal_name")) if data.get("internal_name") != null else ""
	display_name_line.text = str(data.get("display_name")) if data.get("display_name") != null else ""
	description_edit.text = str(data.get("description")) if data.get("description") != null else ""
	persistent_check.button_pressed = bool(data.get("is_persistent")) if data.get("is_persistent") != null else true
	_refresh_resource_labels()

func _on_save_pressed() -> void:
	if current_ailment_data == null:
		return

	var clean_internal := internal_name_line.text.strip_edges()
	var clean_display := display_name_line.text.strip_edges()
	if clean_internal.is_empty():
		_show_warning("El nombre interno no puede estar vacío.")
		return
	if clean_display.is_empty():
		_show_warning("El nombre visible no puede estar vacío.")
		return

	current_ailment_data.id = int(id_spin.value)
	current_ailment_data.internal_name = clean_internal.to_lower()
	current_ailment_data.display_name = clean_display
	current_ailment_data.description = description_edit.text.strip_edges()
	current_ailment_data.is_persistent = persistent_check.button_pressed

	var save_path := _resolve_save_path()
	var error := ResourceSaver.save(current_ailment_data, save_path)
	if error != OK:
		_show_warning("Error al guardar AilmentData: %s" % error_string(error))
		return

	if refresh_callback.is_valid():
		refresh_callback.call()
	saved.emit(current_ailment_data, editor_mode != EditorMode.EDIT)
	queue_free()

func _resolve_save_path() -> String:
	if editor_mode == EditorMode.EDIT and not original_resource_path.is_empty():
		return original_resource_path

	var base_name := current_ailment_data.internal_name.strip_edges().to_upper().replace("_", "-")
	if base_name.is_empty():
		base_name = "AILMENT"
	var path := "res://Resources/Data/Ailments/%s.tres" % base_name
	var i := 1
	while ResourceLoader.exists(path):
		path = "res://Resources/Data/Ailments/%s_%d.tres" % [base_name, i]
		i += 1
	return path

func _get_next_available_id() -> int:
	var max_id := 0
	var dir := DirAccess.open(ProjectSettings.globalize_path("res://Resources/Data/Ailments"))
	if dir == null:
		dir = DirAccess.open("res://Resources/Data/Ailments")
	if dir == null:
		return 1
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var path := "res://Resources/Data/Ailments/" + file_name
			var res := load(path) as AilmentData
			if res:
				max_id = maxi(max_id, int(res.id))
		file_name = dir.get_next()
	dir.list_dir_end()
	return max_id + 1

func _show_warning(message: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Aviso"
	dialog.dialog_text = message
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())

func _on_icon_pick_pressed() -> void:
	_pick_resource(["*.png ; PNG", "*.jpg ; JPG", "*.webp ; WEBP", "*.tres ; Resources", "*.res ; Resources"], func(res: Resource):
		if res is Texture2D:
			current_ailment_data.icon = res
			_refresh_resource_labels()
		else:
			_show_warning("Selecciona una textura válida para el icono.")
	)

func _on_icon_clear_pressed() -> void:
	if current_ailment_data:
		current_ailment_data.icon = null
		_refresh_resource_labels()

func _on_effect_pick_pressed() -> void:
	_pick_resource(["*.gd ; GDScript", "*.tres ; Resources", "*.res ; Resources"], func(res: Resource):
		if res is Script:
			current_ailment_data.effect = res
			_refresh_resource_labels()
		else:
			_show_warning("Selecciona un script válido para effect.")
	)

func _on_effect_clear_pressed() -> void:
	if current_ailment_data:
		current_ailment_data.effect = null
		_refresh_resource_labels()

func _pick_resource(filters: Array[String], on_selected: Callable) -> void:
	var file_dialog := EditorFileDialog.new()
	file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	for filter_text in filters:
		file_dialog.add_filter(filter_text)
	add_child(file_dialog)
	file_dialog.file_selected.connect(func(path: String):
		var res := load(path)
		if res == null:
			_show_warning("No se pudo cargar el recurso seleccionado.")
		else:
			on_selected.call(res)
		file_dialog.queue_free()
	)
	file_dialog.canceled.connect(func(): file_dialog.queue_free())
	file_dialog.popup_centered_ratio(0.75)

func _refresh_resource_labels() -> void:
	if current_ailment_data == null:
		icon_path_label.text = "(Sin icono)"
		effect_path_label.text = "(Sin effect)"
		return
	icon_path_label.text = _resource_label(current_ailment_data.icon, "(Sin icono)")
	effect_path_label.text = _resource_label(current_ailment_data.effect, "(Sin effect)")

func _resource_label(res: Resource, empty_text: String) -> String:
	if res == null:
		return empty_text
	var path := str(res.resource_path)
	if path.is_empty():
		return "(Recurso embebido)"
	return path

func _on_cancel_pressed() -> void:
	cancelled.emit()
	queue_free()

func _on_close_requested() -> void:
	cancelled.emit()
	queue_free()
