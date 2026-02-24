@tool
extends Window

## Ventana de edición de ItemData
## Soporta modos: Edit, Create, Duplicate

enum EditorMode {
	EDIT,      # Editar un ItemData existente
	CREATE,    # Crear un nuevo ItemData
	DUPLICATE  # Duplicar un ItemData existente
}

signal saved(item_data: ItemData, was_new: bool)
signal cancelled()

var current_item_data: ItemData = null
var editor_mode: EditorMode = EditorMode.EDIT
var original_resource_path: String = ""
var has_unsaved_changes: bool = false
var refresh_callback: Callable = Callable()

# Referencias UI - General
@onready var id_spin_box: SpinBox = $VBoxContainer/ScrollContainer/VBoxContainer/GeneralSection/IdContainer/IdSpinBox
@onready var internal_name_line_edit: LineEdit = $VBoxContainer/ScrollContainer/VBoxContainer/GeneralSection/InternalNameContainer/InternalNameLineEdit
@onready var display_name_line_edit: LineEdit = $VBoxContainer/ScrollContainer/VBoxContainer/GeneralSection/DisplayNameContainer/DisplayNameLineEdit
@onready var description_text_edit: TextEdit = $VBoxContainer/ScrollContainer/VBoxContainer/GeneralSection/DescriptionContainer/DescriptionTextEdit

# Referencias UI - Clasificación
@onready var pocket_option_button: OptionButton = $VBoxContainer/ScrollContainer/VBoxContainer/ClassificationSection/PocketContainer/PocketOptionButton
@onready var kind_option_button: OptionButton = $VBoxContainer/ScrollContainer/VBoxContainer/ClassificationSection/KindContainer/KindOptionButton

# Referencias UI - Icono
var icon_texture_button: TextureButton = null
var clear_icon_button: Button = null

# Referencias UI - Buttons
@onready var save_button: Button = $VBoxContainer/ButtonContainer/SaveButton
@onready var cancel_button: Button = $VBoxContainer/ButtonContainer/CancelButton

func _ready() -> void:
	title = "Item Editor"
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

	# Configurar OptionButtons
	_setup_pocket_option_button()
	_setup_kind_option_button()

	# Inicializar referencias de icono
	_initialize_icon_nodes()

	# Configurar icono
	if icon_texture_button:
		if not icon_texture_button.pressed.is_connected(_on_icon_texture_button_pressed):
			icon_texture_button.pressed.connect(_on_icon_texture_button_pressed)
		# Añadir menú contextual al clic derecho
		if not icon_texture_button.gui_input.is_connected(_on_icon_texture_button_gui_input):
			icon_texture_button.gui_input.connect(_on_icon_texture_button_gui_input)
	if clear_icon_button:
		if not clear_icon_button.pressed.is_connected(_on_clear_icon_button_pressed):
			clear_icon_button.pressed.connect(_on_clear_icon_button_pressed)

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
	if not pocket_option_button:
		pocket_option_button = get_node_or_null("VBoxContainer/ScrollContainer/VBoxContainer/ClassificationSection/PocketContainer/PocketOptionButton") as OptionButton
	if not kind_option_button:
		kind_option_button = get_node_or_null("VBoxContainer/ScrollContainer/VBoxContainer/ClassificationSection/KindContainer/KindOptionButton") as OptionButton
	if not icon_texture_button:
		icon_texture_button = get_node_or_null("VBoxContainer/ScrollContainer/VBoxContainer/IconSection/IconContainer/IconTextureButton") as TextureButton
	if not clear_icon_button:
		clear_icon_button = get_node_or_null("VBoxContainer/ScrollContainer/VBoxContainer/IconSection/IconContainer/ClearIconButton") as Button
		if clear_icon_button and not clear_icon_button.pressed.is_connected(_on_clear_icon_button_pressed):
			clear_icon_button.pressed.connect(_on_clear_icon_button_pressed)

## Inicializa los nodos de icono
func _initialize_icon_nodes() -> void:
	if not icon_texture_button:
		icon_texture_button = get_node_or_null("VBoxContainer/ScrollContainer/VBoxContainer/IconSection/IconContainer/IconTextureButton") as TextureButton
		if icon_texture_button and not icon_texture_button.pressed.is_connected(_on_icon_texture_button_pressed):
			icon_texture_button.pressed.connect(_on_icon_texture_button_pressed)
	if not clear_icon_button:
		clear_icon_button = get_node_or_null("VBoxContainer/ScrollContainer/VBoxContainer/IconSection/IconContainer/ClearIconButton") as Button
		if clear_icon_button and not clear_icon_button.pressed.is_connected(_on_clear_icon_button_pressed):
			clear_icon_button.pressed.connect(_on_clear_icon_button_pressed)
	if not save_button:
		save_button = get_node_or_null("VBoxContainer/ButtonContainer/SaveButton") as Button
		if save_button:
			save_button.pressed.connect(_on_save_button_pressed)
	if not cancel_button:
		cancel_button = get_node_or_null("VBoxContainer/ButtonContainer/CancelButton") as Button
		if cancel_button:
			cancel_button.pressed.connect(_on_cancel_button_pressed)

## Configura el OptionButton de Pocket
func _setup_pocket_option_button() -> void:
	if not pocket_option_button:
		return

	pocket_option_button.clear()
	# El enum Pocket empieza en 1, así que añadimos "None" como 0
	pocket_option_button.add_item("None", 0)
	pocket_option_button.add_item("Items", ItemEnums.Pocket.ITEMS)
	pocket_option_button.add_item("Medicine", ItemEnums.Pocket.MEDICINE)
	pocket_option_button.add_item("Balls", ItemEnums.Pocket.BALLS)
	pocket_option_button.add_item("TM/HM", ItemEnums.Pocket.TM_HM)
	pocket_option_button.add_item("Berries", ItemEnums.Pocket.BERRIES)
	pocket_option_button.add_item("Key Items", ItemEnums.Pocket.KEY_ITEMS)
	pocket_option_button.add_item("Machines", ItemEnums.Pocket.MACHINES)
	pocket_option_button.add_item("Battle Items", ItemEnums.Pocket.BATTLE_ITEMS)

## Configura el OptionButton de Kind
func _setup_kind_option_button() -> void:
	if not kind_option_button:
		return

	kind_option_button.clear()
	kind_option_button.add_item("Generic", ItemEnums.Kind.GENERIC)
	kind_option_button.add_item("Heal HP", ItemEnums.Kind.HEAL_HP)
	kind_option_button.add_item("Heal PP", ItemEnums.Kind.HEAL_PP)
	kind_option_button.add_item("Cure Status", ItemEnums.Kind.CURE_STATUS)
	kind_option_button.add_item("Revive", ItemEnums.Kind.REVIVE)
	kind_option_button.add_item("Poké Ball", ItemEnums.Kind.POKEBALL)
	kind_option_button.add_item("TM/HM", ItemEnums.Kind.TM_HM)
	kind_option_button.add_item("Held", ItemEnums.Kind.HELD)
	kind_option_button.add_item("Key", ItemEnums.Kind.KEY)
	kind_option_button.add_item("Evolution", ItemEnums.Kind.EVOLUTION)
	kind_option_button.add_item("Stat Boost", ItemEnums.Kind.STAT_BOOST)
	kind_option_button.add_item("Repel", ItemEnums.Kind.REPEL)
	kind_option_button.add_item("Berry", ItemEnums.Kind.BERRY)

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
	if pocket_option_button:
		pocket_option_button.item_selected.connect(func(_index): has_unsaved_changes = true)
	if kind_option_button:
		kind_option_button.item_selected.connect(func(_index): has_unsaved_changes = true)

## Abre el editor en modo Edit
func open_edit(item_data: ItemData, refresh_cb: Callable = Callable()) -> void:
	if not item_data:
		push_error("ItemEditorWindow: No se proporcionó ItemData para editar")
		return

	editor_mode = EditorMode.EDIT
	current_item_data = item_data
	original_resource_path = item_data.resource_path
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

	# Asegurarse de que los OptionButtons estén configurados
	if not pocket_option_button or pocket_option_button.get_item_count() <= 1:
		_setup_pocket_option_button()
	if not kind_option_button or kind_option_button.get_item_count() <= 1:
		_setup_kind_option_button()

	# Asegurar que los nodos de icono estén inicializados
	_initialize_icon_nodes()

	_load_item_data_to_ui(item_data)
	_update_title()

## Abre el editor en modo Create
func open_create(refresh_cb: Callable = Callable()) -> void:
	editor_mode = EditorMode.CREATE
	refresh_callback = refresh_cb
	has_unsaved_changes = false

	# Crear nuevo ItemData con valores por defecto
	var item_data_script := load("res://Scripts/Resources/Classes/ItemData.gd") as GDScript
	if not item_data_script:
		push_error("ItemEditorWindow: No se pudo cargar ItemData.gd")
		return

	current_item_data = item_data_script.new() as ItemData
	if not current_item_data:
		push_error("ItemEditorWindow: No se pudo crear instancia de ItemData")
		return

	# Valores por defecto
	current_item_data.id = _get_next_available_id()
	current_item_data.internal_name = ""
	current_item_data.display_name = ""
	current_item_data.description = ""
	current_item_data.icon = null
	current_item_data.pocket = ItemEnums.Pocket.ITEMS
	current_item_data.kind = ItemEnums.Kind.GENERIC
	current_item_data.allowed_contexts = ItemEnums.UseContext.OVERWORLD
	current_item_data.target_type = ItemEnums.TargetType.NONE
	current_item_data.is_consumable = true
	current_item_data.stack_limit = 99
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

	# Asegurarse de que los OptionButtons estén configurados
	if not pocket_option_button or pocket_option_button.get_item_count() <= 1:
		_setup_pocket_option_button()
	if not kind_option_button or kind_option_button.get_item_count() <= 1:
		_setup_kind_option_button()

	# Asegurar que los nodos de icono estén inicializados
	_initialize_icon_nodes()

	_load_item_data_to_ui(current_item_data)
	_update_title()

## Abre el editor en modo Duplicate
func open_duplicate(item_data: ItemData, refresh_cb: Callable = Callable()) -> void:
	if not item_data:
		push_error("ItemEditorWindow: No se proporcionó ItemData para duplicar")
		return

	editor_mode = EditorMode.DUPLICATE
	refresh_callback = refresh_cb
	has_unsaved_changes = false

	# Clonar el ItemData
	current_item_data = item_data.duplicate(true) as ItemData
	if not current_item_data:
		push_error("ItemEditorWindow: No se pudo duplicar ItemData")
		return

	# Asignar nuevo ID
	current_item_data.id = _get_next_available_id()
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

	# Asegurarse de que los OptionButtons estén configurados
	if not pocket_option_button or pocket_option_button.get_item_count() <= 1:
		_setup_pocket_option_button()
	if not kind_option_button or kind_option_button.get_item_count() <= 1:
		_setup_kind_option_button()

	# Asegurar que los nodos de icono estén inicializados
	_initialize_icon_nodes()

	_load_item_data_to_ui(current_item_data)
	_update_title()

## Carga los datos del ItemData a la UI
func _load_item_data_to_ui(item_data: ItemData) -> void:
	if not item_data:
		return

	# Asegurar que current_item_data esté establecido
	current_item_data = item_data

	print("[ItemEditorWindow] Cargando datos del item ID: %d" % item_data.id)

	# General
	if id_spin_box:
		id_spin_box.value = item_data.id
	if internal_name_line_edit:
		internal_name_line_edit.text = item_data.internal_name if item_data.internal_name else ""
	if display_name_line_edit:
		display_name_line_edit.text = item_data.display_name if item_data.display_name else ""
	if description_text_edit:
		description_text_edit.text = item_data.description if item_data.description else ""

	# Pocket
	if pocket_option_button:
		var pocket_index := 0
		for i in range(pocket_option_button.get_item_count()):
			if pocket_option_button.get_item_id(i) == item_data.pocket:
				pocket_index = i
				break
		pocket_option_button.selected = pocket_index

	# Kind
	if kind_option_button:
		var kind_index := 0
		for i in range(kind_option_button.get_item_count()):
			if kind_option_button.get_item_id(i) == item_data.kind:
				kind_index = i
				break
		kind_option_button.selected = kind_index

	# Icono - actualizar después de cargar todos los datos
	await get_tree().process_frame
	await get_tree().process_frame
	# Asegurar que los nodos de icono estén inicializados antes de actualizar
	_initialize_icon_nodes()
	_update_icon_display()

## Actualiza los datos del ItemData desde la UI
func _update_item_data_from_ui() -> void:
	if not current_item_data:
		return

	# General
	if id_spin_box:
		current_item_data.id = int(id_spin_box.value)
	if internal_name_line_edit:
		current_item_data.internal_name = internal_name_line_edit.text
	if display_name_line_edit:
		current_item_data.display_name = display_name_line_edit.text
	if description_text_edit:
		current_item_data.description = description_text_edit.text

	# Pocket
	if pocket_option_button:
		var selected_index = pocket_option_button.selected
		if selected_index >= 0:
			current_item_data.pocket = pocket_option_button.get_item_id(selected_index)

	# Kind
	if kind_option_button:
		var selected_index = kind_option_button.selected
		if selected_index >= 0:
			current_item_data.kind = kind_option_button.get_item_id(selected_index)

	# Icono (se actualiza cuando se selecciona uno nuevo)

## Actualiza la visualización del icono
func _update_icon_display() -> void:
	if not current_item_data:
		return

	# Asegurar que los nodos estén inicializados
	_initialize_icon_nodes()

	# Buscar y ocultar/eliminar cualquier label que contenga "sin icono"
	var icon_container = get_node_or_null("VBoxContainer/ScrollContainer/VBoxContainer/IconSection/IconContainer")
	if icon_container:
		for child in icon_container.get_children():
			if child is Label:
				var label_text = child.text.to_lower()
				if label_text.contains("sin icono") or label_text.contains("seleccionar"):
					# Ocultar o eliminar el label
					child.visible = false
					# O mejor, eliminarlo si no es el IconLabel fijo
					if child.name != "IconLabel":
						icon_container.remove_child(child)
						child.queue_free()

	if icon_texture_button:
		if current_item_data.icon and current_item_data.icon.atlas:
			# Intentar obtener la imagen del atlas
			var atlas_texture := current_item_data.icon.atlas as Texture2D
			if atlas_texture:
				# Intentar obtener la imagen del atlas
				var image: Image = null

				# Si es ImageTexture, obtener la imagen directamente
				if atlas_texture is ImageTexture:
					image = (atlas_texture as ImageTexture).get_image()
				# Si es CompressedTexture2D, intentar obtener la imagen
				elif atlas_texture is CompressedTexture2D:
					# Para CompressedTexture2D, necesitamos usar get_image() si está disponible
					if atlas_texture.has_method("get_image"):
						image = atlas_texture.get_image()
					else:
						# Si no podemos obtener la imagen, usar el AtlasTexture directamente
						icon_texture_button.texture_normal = current_item_data.icon
						icon_texture_button.texture_pressed = current_item_data.icon
						icon_texture_button.texture_hover = current_item_data.icon
						return

				if image:
					# Extraer la región del AtlasTexture
					var region := current_item_data.icon.region
					if region.size.x > 0 and region.size.y > 0:
						var sub_image := image.get_region(region)
						if sub_image:
							var texture := ImageTexture.new()
							texture.set_image(sub_image)
							icon_texture_button.texture_normal = texture
							icon_texture_button.texture_pressed = texture
							icon_texture_button.texture_hover = texture
							return

			# Si no se pudo extraer la región, usar el AtlasTexture directamente como fallback
			icon_texture_button.texture_normal = current_item_data.icon
			icon_texture_button.texture_pressed = current_item_data.icon
			icon_texture_button.texture_hover = current_item_data.icon
		else:
			icon_texture_button.texture_normal = null
			icon_texture_button.texture_pressed = null
			icon_texture_button.texture_hover = null

	# Actualizar botón de limpiar (igual que en Pokémon)
	if not clear_icon_button:
		_initialize_icon_nodes()

	if clear_icon_button:
		if current_item_data and current_item_data.icon:
			clear_icon_button.visible = true
		else:
			clear_icon_button.visible = false

## Maneja el clic en el TextureButton del icono
func _on_icon_texture_button_pressed() -> void:
	var file_dialog := EditorFileDialog.new()
	file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	file_dialog.add_filter("*.png", "PNG Images")
	file_dialog.add_filter("*.jpg", "JPG Images")
	file_dialog.add_filter("*.jpeg", "JPEG Images")
	file_dialog.add_filter("*.webp", "WebP Images")
	file_dialog.add_filter("*.bmp", "BMP Images")
	file_dialog.add_filter("*.tga", "TGA Images")
	file_dialog.add_filter("*.tres", "Resource Files")
	file_dialog.title = "Seleccionar Icono del Item"
	file_dialog.current_dir = "res://Sprites/Iconos/Items"

	# Si hay un icono seleccionado y tiene un atlas, intentar abrir en el directorio del atlas
	if current_item_data and current_item_data.icon and current_item_data.icon.atlas:
		var atlas_path: String = current_item_data.icon.atlas.resource_path
		if atlas_path != "":
			var atlas_dir := atlas_path.get_base_dir()
			file_dialog.current_dir = atlas_dir

	add_child(file_dialog)
	file_dialog.popup_centered(Vector2i(800, 600))

	file_dialog.file_selected.connect(func(path: String):
		var resource = load(path)
		if resource is AtlasTexture:
			current_item_data.icon = resource as AtlasTexture
		elif resource is Texture2D:
			# Crear un AtlasTexture básico desde Texture2D
			var atlas_texture := AtlasTexture.new()
			atlas_texture.atlas = resource as Texture2D
			atlas_texture.region = Rect2i(0, 0, resource.get_width(), resource.get_height())
			current_item_data.icon = atlas_texture
		else:
			_show_error("El recurso seleccionado no es un AtlasTexture o Texture2D válido")
			return

		_update_icon_display()
		has_unsaved_changes = true
		file_dialog.queue_free()
	)

	file_dialog.canceled.connect(func():
		file_dialog.queue_free()
	)

## Maneja el botón de limpiar icono
func _on_clear_icon_button_pressed() -> void:
	if current_item_data:
		current_item_data.icon = null
		_update_icon_display()
		has_unsaved_changes = true

## Maneja el input del TextureButton del icono (para menú contextual)
func _on_icon_texture_button_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
			# Obtener la posición del mouse usando DisplayServer
			var global_mouse_pos: Vector2 = DisplayServer.mouse_get_position()
			_show_icon_context_menu(global_mouse_pos)

## Muestra el menú contextual del icono
func _show_icon_context_menu(global_pos: Vector2) -> void:
	var popup_menu := PopupMenu.new()

	# Solo mostrar "Limpiar" si hay un icono
	if current_item_data and current_item_data.icon:
		popup_menu.add_item("Limpiar", 0)

	# Si no hay icono, mostrar "Seleccionar"
	if not current_item_data or not current_item_data.icon:
		popup_menu.add_item("Seleccionar", 1)

	# Añadir el menú como hijo del control base del editor para que se posicione correctamente
	var base_control := EditorInterface.get_base_control()
	base_control.add_child(popup_menu)

	# Convertir la posición global de la pantalla a posición relativa al control base
	# La posición global está en coordenadas de pantalla, necesitamos convertirla
	var base_rect: Rect2 = base_control.get_global_rect()
	var relative_pos: Vector2 = global_pos - base_rect.position
	popup_menu.popup(Rect2i(relative_pos, Vector2i(1, 1)))

	popup_menu.id_pressed.connect(func(id: int):
		match id:
			0:  # Limpiar
				_on_clear_icon_button_pressed()
			1:  # Seleccionar
				_on_icon_texture_button_pressed()
		popup_menu.queue_free()
	)

	popup_menu.popup_hide.connect(func():
		popup_menu.queue_free()
	)

## Actualiza el título de la ventana
func _update_title() -> void:
	match editor_mode:
		EditorMode.EDIT:
			var name_str := current_item_data.display_name if current_item_data.display_name != "" else current_item_data.internal_name
			title = "Editar Item: %s" % name_str
		EditorMode.CREATE:
			title = "Crear Nuevo Item"
		EditorMode.DUPLICATE:
			title = "Duplicar Item"

## Obtiene el siguiente ID disponible
func _get_next_available_id() -> int:
	var items_dir := "res://Resources/Data/Items"
	var dir := DirAccess.open(ProjectSettings.globalize_path(items_dir))
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
			# También soportar formato antiguo "XXX.tres"
			elif id_str.is_valid_int():
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
	if not current_item_data:
		_show_error("No hay datos de item para guardar")
		return

	# Actualizar datos desde UI primero
	_update_item_data_from_ui()

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

	saved.emit(current_item_data, was_new)
	_close_window()

## Valida los datos antes de guardar
func _validate_data() -> bool:
	if not current_item_data:
		_show_error("No hay datos de item para validar")
		return false

	# Validar ID
	if current_item_data.id <= 0:
		_show_error("El ID debe ser mayor que 0")
		return false

	# Validar nombre
	if current_item_data.display_name.is_empty() and current_item_data.internal_name.is_empty():
		_show_error("Debe proporcionar al menos un nombre (display_name o internal_name)")
		return false

	return true

## Guarda el ItemData en disco
func _save_to_disk() -> bool:
	if not current_item_data:
		return false

	var was_new := false
	var items_dir := "res://Resources/Data/Items"
	var display_name := current_item_data.display_name if current_item_data.display_name != "" else current_item_data.internal_name
	if display_name.is_empty():
		display_name = "Item_%d" % current_item_data.id

	# Determinar la ruta del archivo
	var file_path := ""
	if editor_mode == EditorMode.EDIT and original_resource_path != "":
		file_path = original_resource_path
		# Verificar si el nombre o ID cambió, en cuyo caso necesitamos renombrar
		var final_path := _get_final_file_path(items_dir, current_item_data.id, display_name)
		if final_path != original_resource_path:
			# El nombre o ID cambió, necesitamos renombrar
			file_path = final_path
			was_new = false  # No es nuevo, solo renombrado
	else:
		# Crear nuevo archivo
		file_path = _get_final_file_path(items_dir, current_item_data.id, display_name)
		was_new = true

	# Guardar el recurso
	current_item_data.resource_path = file_path
	var error := ResourceSaver.save(current_item_data, file_path)
	if error != OK:
		_show_error("Error al guardar el archivo: %s" % error_string(error))
		return false

	print("[ItemEditorWindow] Item guardado: %s" % file_path)

	# Si el archivo original existe y es diferente, eliminarlo
	if editor_mode == EditorMode.EDIT and original_resource_path != "" and original_resource_path != file_path:
		var dir := DirAccess.open(ProjectSettings.globalize_path(items_dir))
		if dir:
			var old_file_name := original_resource_path.get_file()
			if dir.file_exists(old_file_name):
				dir.remove(old_file_name)
				print("[ItemEditorWindow] Archivo antiguo eliminado: %s" % old_file_name)

	return was_new

## Obtiene la ruta final del archivo con formato "XXX - Nombre.tres"
func _get_final_file_path(base_dir: String, item_id: int, item_name: String) -> String:
	if item_name.is_empty():
		item_name = "Item_%d" % item_id
	var file_name := "%03d - %s.tres" % [item_id, item_name]
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
