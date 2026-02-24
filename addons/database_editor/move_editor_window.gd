@tool
extends Window

## Ventana de edición de MoveData
## Soporta modos: Edit, Create, Duplicate

enum EditorMode {
	EDIT,      # Editar un MoveData existente
	CREATE,    # Crear un nuevo MoveData
	DUPLICATE  # Duplicar un MoveData existente
}

signal saved(move_data: MoveData, was_new: bool)
signal cancelled()

var current_move_data: MoveData = null
var editor_mode: EditorMode = EditorMode.EDIT
var original_resource_path: String = ""
var has_unsaved_changes: bool = false
var refresh_callback: Callable = Callable()

# Cache de tipos disponibles
var available_types: Array[TypeData] = []
var types_loaded: bool = false

# Referencias UI - General
@onready var id_spin_box: SpinBox = $VBoxContainer/ScrollContainer/VBoxContainer/GeneralSection/IdContainer/IdSpinBox
@onready var internal_name_line_edit: LineEdit = $VBoxContainer/ScrollContainer/VBoxContainer/GeneralSection/InternalNameContainer/InternalNameLineEdit
@onready var display_name_line_edit: LineEdit = $VBoxContainer/ScrollContainer/VBoxContainer/GeneralSection/DisplayNameContainer/DisplayNameLineEdit
@onready var description_text_edit: TextEdit = $VBoxContainer/ScrollContainer/VBoxContainer/GeneralSection/DescriptionContainer/DescriptionTextEdit

# Referencias UI - Tipo y Categoría
@onready var type_option_button: OptionButton = $VBoxContainer/ScrollContainer/VBoxContainer/TypeSection/TypeContainer/TypeOptionButton
@onready var damage_class_option_button: OptionButton = $VBoxContainer/ScrollContainer/VBoxContainer/TypeSection/DamageClassContainer/DamageClassOptionButton

# Referencias UI - Estadísticas
@onready var power_spin_box: SpinBox = $VBoxContainer/ScrollContainer/VBoxContainer/StatsSection/PowerContainer/PowerSpinBox
@onready var accuracy_spin_box: SpinBox = $VBoxContainer/ScrollContainer/VBoxContainer/StatsSection/AccuracyContainer/AccuracySpinBox
@onready var pp_spin_box: SpinBox = $VBoxContainer/ScrollContainer/VBoxContainer/StatsSection/PpContainer/PpSpinBox

# Referencias UI - Buttons
@onready var save_button: Button = $VBoxContainer/ButtonContainer/SaveButton
@onready var cancel_button: Button = $VBoxContainer/ButtonContainer/CancelButton

func _ready() -> void:
	title = "Move Editor"
	unresizable = false
	always_on_top = false
	exclusive = true  # Hace que la ventana sea modal
	min_size = Vector2i(700, 600)

	# Conectar señal de cierre
	close_requested.connect(_on_close_requested)

	# Conectar botones
	if save_button:
		save_button.pressed.connect(_on_save_button_pressed)
	if cancel_button:
		cancel_button.pressed.connect(_on_cancel_button_pressed)

	# Cargar tipos disponibles
	_load_types()

	# Configurar damage_class OptionButton
	if damage_class_option_button:
		damage_class_option_button.clear()
		damage_class_option_button.add_item("None", 0)
		damage_class_option_button.add_item("Estado", 1)
		damage_class_option_button.add_item("Físico", 2)
		damage_class_option_button.add_item("Especial", 3)

	# Conectar cambios en campos para detectar modificaciones
	_connect_field_signals()

## Inicializa los nodos @onready si no se han inicializado automáticamente
func _initialize_nodes() -> void:
	if not id_spin_box:
		id_spin_box = get_node_or_null("VBoxContainer/ScrollContainer/VBoxContainer/GeneralSection/IdContainer/IdSpinBox") as SpinBox
	if not internal_name_line_edit:
		internal_name_line_edit = get_node_or_null("VBoxContainer/ScrollContainer/VBoxContainer/GeneralSection/InternalNameContainer/InternalNameLineEdit") as LineEdit
	if not display_name_line_edit:
		display_name_line_edit = get_node_or_null("VBoxContainer/ScrollContainer/VBoxContainer/GeneralSection/DisplayNameContainer/DisplayNameLineEdit") as LineEdit
	if not description_text_edit:
		description_text_edit = get_node_or_null("VBoxContainer/ScrollContainer/VBoxContainer/GeneralSection/DescriptionContainer/DescriptionTextEdit") as TextEdit
	if not type_option_button:
		type_option_button = get_node_or_null("VBoxContainer/ScrollContainer/VBoxContainer/TypeSection/TypeContainer/TypeOptionButton") as OptionButton
	if not damage_class_option_button:
		damage_class_option_button = get_node_or_null("VBoxContainer/ScrollContainer/VBoxContainer/TypeSection/DamageClassContainer/DamageClassOptionButton") as OptionButton
	if not power_spin_box:
		power_spin_box = get_node_or_null("VBoxContainer/ScrollContainer/VBoxContainer/StatsSection/PowerContainer/PowerSpinBox") as SpinBox
	if not accuracy_spin_box:
		accuracy_spin_box = get_node_or_null("VBoxContainer/ScrollContainer/VBoxContainer/StatsSection/AccuracyContainer/AccuracySpinBox") as SpinBox
	if not pp_spin_box:
		pp_spin_box = get_node_or_null("VBoxContainer/ScrollContainer/VBoxContainer/StatsSection/PpContainer/PpSpinBox") as SpinBox
	if not save_button:
		save_button = get_node_or_null("VBoxContainer/ButtonContainer/SaveButton") as Button
		if save_button:
			save_button.pressed.connect(_on_save_button_pressed)
	if not cancel_button:
		cancel_button = get_node_or_null("VBoxContainer/ButtonContainer/CancelButton") as Button
		if cancel_button:
			cancel_button.pressed.connect(_on_cancel_button_pressed)

## Conecta las señales de los campos para detectar cambios
func _connect_field_signals() -> void:
	if id_spin_box:
		id_spin_box.value_changed.connect(func(_value): has_unsaved_changes = true)
	if internal_name_line_edit:
		internal_name_line_edit.text_changed.connect(func(_text): has_unsaved_changes = true)
	if display_name_line_edit:
		display_name_line_edit.text_changed.connect(func(_text): has_unsaved_changes = true)
	if description_text_edit:
		description_text_edit.text_changed.connect(func(): has_unsaved_changes = true)
	if type_option_button:
		type_option_button.item_selected.connect(func(_index): has_unsaved_changes = true)
	if damage_class_option_button:
		damage_class_option_button.item_selected.connect(func(_index): has_unsaved_changes = true)
	if power_spin_box:
		power_spin_box.value_changed.connect(func(_value): has_unsaved_changes = true)
	if accuracy_spin_box:
		accuracy_spin_box.value_changed.connect(func(_value): has_unsaved_changes = true)
	if pp_spin_box:
		pp_spin_box.value_changed.connect(func(_value): has_unsaved_changes = true)

## Carga los tipos disponibles desde archivos (igual que en PokemonEditorWindow)
func _load_types() -> void:
	if types_loaded:
		return

	available_types.clear()
	var types_dir := "res://Resources/Data/Types"

	# Cargar tipos del 01 al 18 (igual que en PokemonEditorWindow)
	for i in range(1, 19):
		var path := "%s/%02d.tres" % [types_dir, i]
		if ResourceLoader.exists(path):
			var type_data = load(path) as TypeData
			if type_data:
				available_types.append(type_data)

	types_loaded = true
	_populate_type_option_button()

## Pobla el OptionButton de tipos
func _populate_type_option_button() -> void:
	if not type_option_button:
		return

	type_option_button.clear()
	type_option_button.add_item("None", 0)

	for type_data in available_types:
		var display_name := type_data.Name if type_data.Name != "" else type_data.internal_name
		type_option_button.add_item(display_name, type_data.id)

## Abre el editor en modo Edit
func open_edit(move_data: MoveData, refresh_cb: Callable = Callable()) -> void:
	if not move_data:
		push_error("MoveEditorWindow: No se proporcionó MoveData para editar")
		return

	editor_mode = EditorMode.EDIT
	current_move_data = move_data
	original_resource_path = move_data.resource_path
	refresh_callback = refresh_cb
	has_unsaved_changes = false

	# Mostrar la ventana primero para que los nodos estén disponibles
	popup_centered(Vector2i(700, 600))

	# Esperar a que _ready() se ejecute y los nodos estén listos
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	# Forzar inicialización de @onready si no se han inicializado
	if not id_spin_box:
		_initialize_nodes()
		await get_tree().process_frame

	# Asegurarse de que los tipos estén cargados antes de cargar los datos
	if not types_loaded:
		_load_types()
	if not type_option_button or type_option_button.get_item_count() <= 1:
		_populate_type_option_button()

	_load_move_data_to_ui(move_data)
	_update_title()

## Abre el editor en modo Create
func open_create(refresh_cb: Callable = Callable()) -> void:
	editor_mode = EditorMode.CREATE
	refresh_callback = refresh_cb
	has_unsaved_changes = false

	# Crear nuevo MoveData con valores por defecto
	var move_data_script := load("res://Scripts/Resources/Classes/MoveData.gd") as GDScript
	if not move_data_script:
		push_error("MoveEditorWindow: No se pudo cargar MoveData.gd")
		return

	current_move_data = move_data_script.new() as MoveData
	if not current_move_data:
		push_error("MoveEditorWindow: No se pudo crear instancia de MoveData")
		return

	# Valores por defecto
	current_move_data.id = _get_next_available_id()
	current_move_data.internal_name = ""
	current_move_data.Name = ""
	current_move_data.description = ""
	current_move_data.type = null
	current_move_data.power = 0
	current_move_data.accuracy = 0
	current_move_data.pp = 0
	current_move_data.damage_class_id = 0
	original_resource_path = ""

	# Mostrar la ventana primero para que los nodos estén disponibles
	popup_centered(Vector2i(700, 600))

	# Esperar a que _ready() se ejecute y los nodos estén listos
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	# Forzar inicialización de @onready si no se han inicializado
	if not id_spin_box:
		_initialize_nodes()
		await get_tree().process_frame

	# Asegurarse de que los tipos estén cargados antes de cargar los datos
	if not types_loaded:
		_load_types()
	if not type_option_button or type_option_button.get_item_count() <= 1:
		_populate_type_option_button()

	_load_move_data_to_ui(current_move_data)
	_update_title()

## Abre el editor en modo Duplicate
func open_duplicate(move_data: MoveData, refresh_cb: Callable = Callable()) -> void:
	if not move_data:
		push_error("MoveEditorWindow: No se proporcionó MoveData para duplicar")
		return

	editor_mode = EditorMode.DUPLICATE
	refresh_callback = refresh_cb
	has_unsaved_changes = false

	# Clonar el MoveData
	current_move_data = move_data.duplicate(true) as MoveData
	if not current_move_data:
		push_error("MoveEditorWindow: No se pudo duplicar MoveData")
		return

	# Asignar nuevo ID
	current_move_data.id = _get_next_available_id()
	original_resource_path = ""

	# Mostrar la ventana primero para que los nodos estén disponibles
	popup_centered(Vector2i(700, 600))

	# Esperar a que _ready() se ejecute y los nodos estén listos
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	# Forzar inicialización de @onready si no se han inicializado
	if not id_spin_box:
		_initialize_nodes()
		await get_tree().process_frame

	# Asegurarse de que los tipos estén cargados antes de cargar los datos
	if not types_loaded:
		_load_types()
	if not type_option_button or type_option_button.get_item_count() <= 1:
		_populate_type_option_button()

	_load_move_data_to_ui(current_move_data)
	_update_title()

## Carga los datos del MoveData a la UI
func _load_move_data_to_ui(move_data: MoveData) -> void:
	if not move_data:
		return

	print("[MoveEditorWindow] Cargando datos del movimiento ID: %d" % move_data.id)

	# General
	if id_spin_box:
		id_spin_box.value = move_data.id
	if internal_name_line_edit:
		internal_name_line_edit.text = move_data.internal_name if move_data.internal_name else ""
	if display_name_line_edit:
		display_name_line_edit.text = move_data.Name if move_data.Name else ""
	if description_text_edit:
		description_text_edit.text = move_data.description if move_data.description else ""

	# Tipo - usar type_id directamente (optimización)
	if type_option_button:
		var type_index := 0
		var type_id: int = move_data.type_id

		# Compatibilidad: si type_id es 0 pero existe type (Resource), extraer el ID
		if type_id == 0 and move_data.type != null:
			var type_resource = move_data.type as Resource
			if type_resource:
				var id_value = type_resource.get("id")
				if id_value != null:
					type_id = int(id_value)
					# Migrar automáticamente: guardar type_id y limpiar type
					move_data.type_id = type_id
					move_data.type = null

		if type_id > 0:
			for i in range(type_option_button.get_item_count()):
				if type_option_button.get_item_id(i) == type_id:
					type_index = i
					break
		type_option_button.selected = type_index

	# Damage Class
	if damage_class_option_button:
		damage_class_option_button.selected = move_data.damage_class_id

	# Estadísticas
	if power_spin_box:
		power_spin_box.value = move_data.power
	if accuracy_spin_box:
		accuracy_spin_box.value = move_data.accuracy
	if pp_spin_box:
		pp_spin_box.value = move_data.pp

## Actualiza los datos del MoveData desde la UI
func _update_move_data_from_ui() -> void:
	if not current_move_data:
		return

	# General
	if id_spin_box:
		current_move_data.id = int(id_spin_box.value)
	if internal_name_line_edit:
		current_move_data.internal_name = internal_name_line_edit.text
	if display_name_line_edit:
		current_move_data.Name = display_name_line_edit.text
	if description_text_edit:
		current_move_data.description = description_text_edit.text

	# Tipo - usar type_id directamente (optimización)
	if type_option_button:
		var selected_index = type_option_button.selected
		if selected_index > 0:
			var type_id = type_option_button.get_item_id(selected_index)
			current_move_data.type_id = type_id
			# Limpiar referencia antigua si existe
			current_move_data.type = null
		else:
			current_move_data.type_id = 0
			# Limpiar referencia antigua si existe
			current_move_data.type = null

	# Damage Class
	if damage_class_option_button:
		current_move_data.damage_class_id = damage_class_option_button.selected

	# Estadísticas
	if power_spin_box:
		current_move_data.power = int(power_spin_box.value)
	if accuracy_spin_box:
		current_move_data.accuracy = int(accuracy_spin_box.value)
	if pp_spin_box:
		current_move_data.pp = int(pp_spin_box.value)

## Actualiza el título de la ventana
func _update_title() -> void:
	match editor_mode:
		EditorMode.EDIT:
			var name_str := current_move_data.Name if current_move_data.Name != "" else current_move_data.internal_name
			title = "Editar Movimiento: %s" % name_str
		EditorMode.CREATE:
			title = "Crear Nuevo Movimiento"
		EditorMode.DUPLICATE:
			title = "Duplicar Movimiento"

## Obtiene el siguiente ID disponible
func _get_next_available_id() -> int:
	var moves_dir := "res://Resources/Data/Moves"
	var dir := DirAccess.open(ProjectSettings.globalize_path(moves_dir))
	if not dir:
		return 1

	var max_id := 0
	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if file_name.ends_with(".tres"):
			var file_base := file_name.get_basename()
			var parts := file_base.split(" - ", false, 1)
			var id_str := parts[0].strip_edges()

			if id_str.is_valid_int():
				var id := int(id_str)
				if id > max_id:
					max_id = id

		file_name = dir.get_next()

	dir.list_dir_end()

	return max_id + 1

## Maneja el botón Guardar
func _on_save_button_pressed() -> void:
	_save_with_validation()

## Maneja el botón Cancelar
func _on_cancel_button_pressed() -> void:
	_try_close()

## Maneja la solicitud de cierre de la ventana
func _on_close_requested() -> void:
	_try_close()

## Intenta cerrar la ventana, mostrando confirmación si hay cambios sin guardar
func _try_close() -> void:
	if has_unsaved_changes:
		_try_close_with_confirmation()
	else:
		_close_window()

## Intenta cerrar con confirmación
func _try_close_with_confirmation() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "¿Descartar los cambios sin guardar?"
	dialog.ok_button_text = "Descartar"
	dialog.cancel_button_text = "Cancelar"
	dialog.title = "Confirmar Cierre"

	add_child(dialog)
	dialog.popup_centered()

	dialog.confirmed.connect(func():
		_close_window()
		dialog.queue_free()
	)

	dialog.canceled.connect(func():
		dialog.queue_free()
	)

## Cierra la ventana
func _close_window() -> void:
	hide()
	queue_free()
	cancelled.emit()

## Guarda con validación
func _save_with_validation() -> void:
	if not current_move_data:
		_show_error("No hay datos de movimiento para guardar")
		return

	# Actualizar datos desde UI primero
	_update_move_data_from_ui()

	# Validar datos mínimos
	if not _validate_data():
		return

	# Guardar en disco
	var was_new := _save_to_disk()
	has_unsaved_changes = false
	_refresh_filesystem()

	# Refrescar lista si hay callback
	if refresh_callback.is_valid():
		refresh_callback.call()

	saved.emit(current_move_data, was_new)
	_close_window()

## Valida los datos antes de guardar
func _validate_data() -> bool:
	if not current_move_data:
		_show_error("No hay datos de movimiento para validar")
		return false

	# Validar ID
	if current_move_data.id <= 0:
		_show_error("El ID debe ser mayor que 0")
		return false

	# Validar nombre
	if current_move_data.Name.is_empty() and current_move_data.internal_name.is_empty():
		_show_error("Debe proporcionar al menos un nombre (Name o internal_name)")
		return false

	return true

## Guarda el MoveData en disco
func _save_to_disk() -> bool:
	if not current_move_data:
		return false

	var was_new := false
	var moves_dir := "res://Resources/Data/Moves"
	var display_name := current_move_data.Name if current_move_data.Name != "" else current_move_data.internal_name
	if display_name.is_empty():
		display_name = "Move_%d" % current_move_data.id

	# Determinar la ruta del archivo
	var file_path := ""
	if editor_mode == EditorMode.EDIT and original_resource_path != "":
		file_path = original_resource_path
		# Verificar si el nombre o ID cambió, en cuyo caso necesitamos renombrar
		var final_path := _get_final_file_path(moves_dir, current_move_data.id, display_name)
		if final_path != original_resource_path:
			# El nombre o ID cambió, necesitamos renombrar
			file_path = final_path
			was_new = false  # No es nuevo, solo renombrado
	else:
		# Crear nuevo archivo
		file_path = _get_final_file_path(moves_dir, current_move_data.id, display_name)
		was_new = true

	# Guardar el recurso
	current_move_data.resource_path = file_path
	var error := ResourceSaver.save(current_move_data, file_path)
	if error != OK:
		_show_error("Error al guardar el archivo: %s" % error_string(error))
		return false

	print("[MoveEditorWindow] Movimiento guardado: %s" % file_path)

	# Si el archivo original existe y es diferente, eliminarlo
	if editor_mode == EditorMode.EDIT and original_resource_path != "" and original_resource_path != file_path:
		var dir := DirAccess.open(ProjectSettings.globalize_path(moves_dir))
		if dir:
			var old_file_name := original_resource_path.get_file()
			if dir.file_exists(old_file_name):
				dir.remove(old_file_name)
				print("[MoveEditorWindow] Archivo antiguo eliminado: %s" % old_file_name)

	return was_new

## Obtiene la ruta final del archivo con formato "XXX - Nombre.tres"
func _get_final_file_path(base_dir: String, move_id: int, move_name: String) -> String:
	if move_name.is_empty():
		move_name = "Move_%d" % move_id
	var file_name := "%03d - %s.tres" % [move_id, move_name]
	return base_dir + "/" + file_name

## Refresca el sistema de archivos de Godot
func _refresh_filesystem() -> void:
	var filesystem = EditorInterface.get_resource_filesystem()
	if filesystem:
		filesystem.scan()

## Muestra un diálogo de error
func _show_error(message: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.dialog_text = message
	dialog.title = "Error"
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())

