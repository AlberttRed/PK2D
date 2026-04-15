@tool
extends Window

signal saved(ability_data: AbilityData, was_new: bool)
signal cancelled()

enum EditorMode { EDIT, CREATE, DUPLICATE }

var current_ability_data: AbilityData = null
var editor_mode: int = EditorMode.EDIT
var original_resource_path: String = ""
var refresh_callback: Callable = Callable()

@onready var id_spin: SpinBox = $VBoxContainer/ScrollContainer/Content/GeneralSection/IdContainer/IdSpinBox
@onready var internal_name_line: LineEdit = $VBoxContainer/ScrollContainer/Content/GeneralSection/InternalNameContainer/InternalNameLineEdit
@onready var display_name_line: LineEdit = $VBoxContainer/ScrollContainer/Content/GeneralSection/DisplayNameContainer/DisplayNameLineEdit
@onready var description_edit: TextEdit = $VBoxContainer/ScrollContainer/Content/GeneralSection/DescriptionContainer/DescriptionTextEdit
@onready var effect_path_label: Label = $VBoxContainer/ScrollContainer/Content/GeneralSection/EffectContainer/EffectPathLabel
@onready var effect_pick_button: Button = $VBoxContainer/ScrollContainer/Content/GeneralSection/EffectContainer/EffectPickButton
@onready var effect_clear_button: Button = $VBoxContainer/ScrollContainer/Content/GeneralSection/EffectContainer/EffectClearButton

@onready var save_button: Button = $VBoxContainer/Buttons/SaveButton
@onready var cancel_button: Button = $VBoxContainer/Buttons/CancelButton

func _ready() -> void:
	title = "Ability Editor"
	unresizable = false
	always_on_top = false
	exclusive = true
	min_size = Vector2i(720, 520)
	close_requested.connect(_on_close_requested)
	save_button.pressed.connect(_on_save_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	effect_pick_button.pressed.connect(_on_effect_pick_pressed)
	effect_clear_button.pressed.connect(_on_effect_clear_pressed)

func open_edit(ability_data: AbilityData, refresh_cb: Callable = Callable()) -> void:
	if not ability_data:
		return
	editor_mode = EditorMode.EDIT
	current_ability_data = ability_data
	original_resource_path = ability_data.resource_path
	refresh_callback = refresh_cb
	_load_to_ui(ability_data)
	popup_centered(Vector2i(720, 520))

func open_create(refresh_cb: Callable = Callable()) -> void:
	editor_mode = EditorMode.CREATE
	refresh_callback = refresh_cb
	current_ability_data = AbilityData.new()
	current_ability_data.id = _get_next_available_id()
	current_ability_data.internal_name = "new_ability"
	current_ability_data.display_name = "Nueva Habilidad"
	current_ability_data.description = ""
	original_resource_path = ""
	_load_to_ui(current_ability_data)
	popup_centered(Vector2i(720, 520))

func open_duplicate(ability_data: AbilityData, refresh_cb: Callable = Callable()) -> void:
	if not ability_data:
		return
	editor_mode = EditorMode.DUPLICATE
	refresh_callback = refresh_cb
	current_ability_data = ability_data.duplicate(true) as AbilityData
	current_ability_data.id = _get_next_available_id()
	current_ability_data.display_name = "%s Copia" % current_ability_data.display_name
	current_ability_data.internal_name = "%s_copy" % current_ability_data.internal_name
	original_resource_path = ""
	_load_to_ui(current_ability_data)
	popup_centered(Vector2i(720, 520))

func _load_to_ui(data: AbilityData) -> void:
	id_spin.value = int(data.get("id")) if data.get("id") != null else 0
	internal_name_line.text = str(data.get("internal_name")) if data.get("internal_name") != null else ""
	display_name_line.text = str(data.get("display_name")) if data.get("display_name") != null else ""
	description_edit.text = str(data.get("description")) if data.get("description") != null else ""
	_refresh_effect_label()

func _on_save_pressed() -> void:
	if current_ability_data == null:
		return

	var clean_internal := internal_name_line.text.strip_edges()
	var clean_display := display_name_line.text.strip_edges()
	if clean_internal.is_empty():
		_show_warning("El nombre interno no puede estar vacío.")
		return
	if clean_display.is_empty():
		_show_warning("El nombre visible no puede estar vacío.")
		return

	current_ability_data.id = int(id_spin.value)
	current_ability_data.internal_name = clean_internal.to_lower()
	current_ability_data.display_name = clean_display
	current_ability_data.description = description_edit.text.strip_edges()

	var save_path := _resolve_save_path()
	var error := ResourceSaver.save(current_ability_data, save_path)
	if error != OK:
		_show_warning("Error al guardar AbilityData: %s" % error_string(error))
		return

	if refresh_callback.is_valid():
		refresh_callback.call()
	saved.emit(current_ability_data, editor_mode != EditorMode.EDIT)
	queue_free()

func _resolve_save_path() -> String:
	if editor_mode == EditorMode.EDIT and not original_resource_path.is_empty():
		return original_resource_path

	var base_name := "%03d-%s" % [int(id_spin.value), current_ability_data.internal_name.strip_edges().to_upper().replace("_", "-")]
	if base_name.ends_with("-"):
		base_name = "%03d-ABILITY" % int(id_spin.value)
	var path := "res://Resources/Data/Abilities/%s.tres" % base_name
	var i := 1
	while ResourceLoader.exists(path):
		path = "res://Resources/Data/Abilities/%s_%d.tres" % [base_name, i]
		i += 1
	return path

func _get_next_available_id() -> int:
	var max_id := 0
	var dir := DirAccess.open(ProjectSettings.globalize_path("res://Resources/Data/Abilities"))
	if dir == null:
		dir = DirAccess.open("res://Resources/Data/Abilities")
	if dir == null:
		return 1
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var path := "res://Resources/Data/Abilities/" + file_name
			var res := load(path) as AbilityData
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

func _on_effect_pick_pressed() -> void:
	var file_dialog := EditorFileDialog.new()
	file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	file_dialog.add_filter("*.gd ; GDScript")
	add_child(file_dialog)
	file_dialog.file_selected.connect(func(path: String):
		var script_res := load(path)
		if script_res is Script:
			current_ability_data.effect_resource = script_res
			_refresh_effect_label()
		else:
			_show_warning("Selecciona un script .gd válido.")
		file_dialog.queue_free()
	)
	file_dialog.canceled.connect(func(): file_dialog.queue_free())
	file_dialog.popup_centered_ratio(0.75)

func _on_effect_clear_pressed() -> void:
	if current_ability_data:
		current_ability_data.effect_resource = null
		_refresh_effect_label()

func _refresh_effect_label() -> void:
	if current_ability_data == null or current_ability_data.effect_resource == null:
		effect_path_label.text = "(Sin script)"
		return
	var path := str(current_ability_data.effect_resource.resource_path)
	effect_path_label.text = path if not path.is_empty() else "(Script embebido)"

func _on_cancel_pressed() -> void:
	cancelled.emit()
	queue_free()

func _on_close_requested() -> void:
	cancelled.emit()
	queue_free()
