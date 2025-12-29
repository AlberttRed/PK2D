@tool
extends Window

## Ventana de edición para propiedades de sprite de EventPage
## Permite editar todas las propiedades relacionadas con la visualización del sprite

signal sprite_edited
signal cancelled

var page: EventPage = null
var event_node: Node = null  # Referencia al nodo Event para detectar si es NPC/Trainer

# Referencias a los controles
var scroll_container: ScrollContainer = null
var main_container: VBoxContainer = null
var accept_button: Button = null

# Referencias a controles específicos
var actor_style_button: Button = null
var actor_style_label: Label = null
var sprite_frames_button: Button = null
var sprite_frames_label: Label = null
var sprite_texture_button: Button = null
var sprite_texture_label: Label = null
var is_spritesheet_check: CheckBox = null
var frame_size_x_spin: SpinBox = null
var frame_size_y_spin: SpinBox = null
var sprite_offset_x_spin: SpinBox = null
var sprite_offset_y_spin: SpinBox = null
var has_water_reflection_check: CheckBox = null

# Vista previa
var preview_container: VBoxContainer = null
var preview_label: Label = null
var preview_texture_rect: TextureRect = null

# Controles de navegación de frames
var animation_dropdown: OptionButton = null
var prev_frame_button: Button = null
var next_frame_button: Button = null
var frame_label: Label = null
var current_animation: String = ""
var current_frame_index: int = 0
var current_sprite_frames: SpriteFrames = null

var current_selection_type: String = ""  # "actor_style", "sprite_frames", "sprite_texture"
var is_loading: bool = false  # Flag para evitar actualizar la página mientras se cargan los valores
var created_sprite_frames: SpriteFrames = null  # Referencia al SpriteFrames creado para abrirlo en el Inspector

func _ready() -> void:
	title = "Gestionar Sprite"
	size = Vector2(1000, 700)  # Ventana más ancha
	unresizable = false
	always_on_top = false
	exclusive = true
	close_requested.connect(_on_close_requested)

	var outer_vbox = VBoxContainer.new()
	outer_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer_vbox.add_theme_constant_override("margin_left", 10)
	outer_vbox.add_theme_constant_override("margin_top", 10)
	outer_vbox.add_theme_constant_override("margin_right", 10)
	outer_vbox.add_theme_constant_override("margin_bottom", 10)
	add_child(outer_vbox)

	# Contenedor principal con split horizontal
	var main_split = HSplitContainer.new()
	main_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Establecer el offset del split para mantener el tamaño del panel derecho
	# Ventana 1000px - márgenes 20px = 980px
	# Panel izquierdo ~730px (ampliado 20px), panel derecho ~250px
	main_split.split_offset = 730
	outer_vbox.add_child(main_split)

	# Panel izquierdo: configuración
	scroll_container = ScrollContainer.new()
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_split.add_child(scroll_container)

	main_container = VBoxContainer.new()
	main_container.add_theme_constant_override("separation", 10)
	main_container.custom_minimum_size.x = 700  # Ancho mínimo ampliado 20px
	scroll_container.add_child(main_container)

	# Panel derecho: vista previa (envuelto en MarginContainer para controlar padding)
	var preview_margin = MarginContainer.new()
	preview_margin.add_theme_constant_override("margin_right", 50)  # Padding derecho ampliado
	main_split.add_child(preview_margin)

	_create_preview_panel()
	preview_margin.add_child(preview_container)

	# Crear secciones de propiedades (en orden de prioridad)
	_create_actor_style_section()
	_create_sprite_texture_section()  # Prioridad 2
	_create_sprite_frames_section()  # Prioridad 3
	_create_water_reflection_section()

	# Botones finales
	var buttons_container = HBoxContainer.new()
	buttons_container.alignment = BoxContainer.ALIGNMENT_END
	buttons_container.add_theme_constant_override("separation", 10)
	buttons_container.add_theme_constant_override("margin_top", 10)

	accept_button = Button.new()
	accept_button.text = "Aceptar"
	accept_button.pressed.connect(_on_accept_pressed)
	buttons_container.add_child(accept_button)

	var cancel_button = Button.new()
	cancel_button.text = "Cancelar"
	cancel_button.pressed.connect(_on_cancel_pressed)
	buttons_container.add_child(cancel_button)

	outer_vbox.add_child(buttons_container)

func _create_preview_panel() -> void:
	preview_container = VBoxContainer.new()
	preview_container.custom_minimum_size.x = 170  # Ancho mínimo ampliado 20px
	preview_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # Expandir para que el centrado funcione
	preview_container.add_theme_constant_override("separation", 10)

	preview_label = Label.new()
	preview_label.text = "Vista Previa"
	preview_label.add_theme_font_size_override("font_size", 14)
	preview_label.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0))
	preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_container.add_child(preview_label)

	preview_container.add_child(HSeparator.new())

	# Contenedor para centrar el panel de vista previa
	var preview_center_wrapper = HBoxContainer.new()
	preview_center_wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_center_wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_center_wrapper.alignment = BoxContainer.ALIGNMENT_CENTER
	preview_container.add_child(preview_center_wrapper)

	# Panel para la vista previa con fondo (tamaño fijo)
	var preview_panel = PanelContainer.new()
	preview_panel.custom_minimum_size = Vector2(200, 200)  # Tamaño fijo
	preview_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	preview_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	preview_panel.add_theme_stylebox_override("panel", StyleBoxFlat.new())
	var stylebox = preview_panel.get_theme_stylebox("panel")
	if stylebox:
		stylebox.bg_color = Color(0.1, 0.1, 0.1)
	preview_center_wrapper.add_child(preview_panel)

	# TextureRect centrado para la vista previa con tamaño fijo
	var center_container = CenterContainer.new()
	center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	preview_panel.add_child(center_container)

	preview_texture_rect = TextureRect.new()
	preview_texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	preview_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_texture_rect.custom_minimum_size = Vector2(150, 150)  # Tamaño fijo
	preview_texture_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	preview_texture_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	center_container.add_child(preview_texture_rect)

	# Contenedor para controles de navegación (justo debajo del recuadro)
	var preview_controls_container = VBoxContainer.new()
	preview_controls_container.name = "PreviewControlsContainer"
	preview_controls_container.add_theme_constant_override("separation", 5)
	preview_controls_container.add_theme_constant_override("margin_top", 10)
	preview_container.add_child(preview_controls_container)

	# Espaciador para empujar los controles hacia arriba
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_container.add_child(spacer)

	# Dropdown para seleccionar animación
	var animation_label = Label.new()
	animation_label.text = "Animación:"
	animation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_controls_container.add_child(animation_label)

	animation_dropdown = OptionButton.new()
	animation_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	animation_dropdown.item_selected.connect(_on_animation_selected)
	preview_controls_container.add_child(animation_dropdown)

	# Botones de navegación de frames
	var frame_nav_container = HBoxContainer.new()
	frame_nav_container.alignment = BoxContainer.ALIGNMENT_CENTER
	frame_nav_container.add_theme_constant_override("separation", 10)
	preview_controls_container.add_child(frame_nav_container)

	prev_frame_button = Button.new()
	prev_frame_button.text = "<"
	prev_frame_button.custom_minimum_size = Vector2(40, 30)
	prev_frame_button.pressed.connect(_on_prev_frame)
	frame_nav_container.add_child(prev_frame_button)

	frame_label = Label.new()
	frame_label.text = "Frame: 0"
	frame_label.name = "FrameLabel"
	frame_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	frame_label.custom_minimum_size.x = 80
	frame_nav_container.add_child(frame_label)

	next_frame_button = Button.new()
	next_frame_button.text = ">"
	next_frame_button.custom_minimum_size = Vector2(40, 30)
	next_frame_button.pressed.connect(_on_next_frame)
	frame_nav_container.add_child(next_frame_button)

func _create_actor_style_section() -> void:
	var section = _create_section("Actor Style (Prioridad 1)")

	var info_label = Label.new()
	info_label.text = "Si se asigna un ActorStyle, tiene la máxima prioridad y se usará en lugar de cualquier otro sprite."
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.7))
	section.add_child(info_label)

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	actor_style_button = Button.new()
	actor_style_button.text = "Seleccionar ActorStyle"
	actor_style_button.pressed.connect(func(): _open_file_dialog("actor_style", "*.tres"))
	actor_style_button.pressed.connect(_update_preview)
	row.add_child(actor_style_button)

	var clear_button = Button.new()
	clear_button.text = "Limpiar"
	clear_button.pressed.connect(_on_clear_actor_style)
	clear_button.pressed.connect(_update_preview)
	row.add_child(clear_button)

	section.add_child(row)

	actor_style_label = Label.new()
	actor_style_label.text = "Ninguno"
	actor_style_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	section.add_child(actor_style_label)

func _create_sprite_frames_section() -> void:
	var section = _create_section("Sprite Frames (Prioridad 3)")

	var info_label = Label.new()
	info_label.text = "SpriteFrames manual para casos personalizados. Se usa si no hay ActorStyle ni SpriteTexture configurado como spritesheet."
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.7))
	section.add_child(info_label)

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	sprite_frames_button = Button.new()
	sprite_frames_button.text = "Seleccionar SpriteFrames"
	sprite_frames_button.pressed.connect(func(): _open_file_dialog("sprite_frames", "*.tres"))
	sprite_frames_button.pressed.connect(_update_preview)
	row.add_child(sprite_frames_button)

	var create_button = Button.new()
	create_button.text = "Crear"
	create_button.pressed.connect(_on_create_sprite_frames)
	row.add_child(create_button)

	var clear_button = Button.new()
	clear_button.text = "Limpiar"
	clear_button.pressed.connect(_on_clear_sprite_frames)
	clear_button.pressed.connect(_update_preview)
	row.add_child(clear_button)

	section.add_child(row)

	sprite_frames_label = Label.new()
	sprite_frames_label.text = "Ninguno"
	sprite_frames_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	section.add_child(sprite_frames_label)

func _create_sprite_texture_section() -> void:
	var section = _create_section("Sprite Texture (Prioridad 2)")

	var info_label = Label.new()
	info_label.text = "Textura del sprite. Si 'Es Spritesheet' está activado, genera animaciones automáticamente desde un spritesheet 4x4. Si no, se usa como imagen simple estática."
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.7))
	section.add_child(info_label)

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	sprite_texture_button = Button.new()
	sprite_texture_button.text = "Seleccionar Textura"
	sprite_texture_button.pressed.connect(func(): _open_file_dialog("sprite_texture", "*.png,*.jpg,*.jpeg,*.webp"))
	sprite_texture_button.pressed.connect(_update_preview)
	row.add_child(sprite_texture_button)

	var clear_button = Button.new()
	clear_button.text = "Limpiar"
	clear_button.pressed.connect(_on_clear_sprite_texture)
	clear_button.pressed.connect(_update_preview)
	row.add_child(clear_button)

	section.add_child(row)

	sprite_texture_label = Label.new()
	sprite_texture_label.text = "Ninguno"
	sprite_texture_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	section.add_child(sprite_texture_label)

	# Checkbox para is_spritesheet
	is_spritesheet_check = CheckBox.new()
	is_spritesheet_check.text = "Es Spritesheet (genera animaciones automáticamente)"
	is_spritesheet_check.toggled.connect(_on_is_spritesheet_toggled)
	is_spritesheet_check.toggled.connect(func(_pressed): _update_preview())
	section.add_child(is_spritesheet_check)

	# Frame size (visible cuando hay una textura asignada)
	var frame_size_container = HBoxContainer.new()
	frame_size_container.add_theme_constant_override("separation", 10)
	frame_size_container.visible = false
	frame_size_container.set_meta("frame_size_container", true)

	var frame_size_label = Label.new()
	frame_size_label.text = "Tamaño de Frame:"
	frame_size_label.custom_minimum_size.x = 150
	frame_size_container.add_child(frame_size_label)

	var x_label = Label.new()
	x_label.text = "X:"
	frame_size_container.add_child(x_label)

	frame_size_x_spin = SpinBox.new()
	frame_size_x_spin.min_value = 1
	frame_size_x_spin.max_value = 512
	frame_size_x_spin.step = 1
	frame_size_x_spin.value_changed.connect(_on_frame_size_changed)
	frame_size_x_spin.value_changed.connect(func(_value): _update_preview())
	frame_size_x_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame_size_container.add_child(frame_size_x_spin)

	var y_label = Label.new()
	y_label.text = "Y:"
	frame_size_container.add_child(y_label)

	frame_size_y_spin = SpinBox.new()
	frame_size_y_spin.min_value = 1
	frame_size_y_spin.max_value = 512
	frame_size_y_spin.step = 1
	frame_size_y_spin.value_changed.connect(_on_frame_size_changed)
	frame_size_y_spin.value_changed.connect(func(_value): _update_preview())
	frame_size_y_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame_size_container.add_child(frame_size_y_spin)

	section.add_child(frame_size_container)

	# Sprite offset (visible cuando hay una textura asignada)
	var sprite_offset_container = HBoxContainer.new()
	sprite_offset_container.add_theme_constant_override("separation", 10)
	sprite_offset_container.visible = false
	sprite_offset_container.set_meta("sprite_offset_container", true)

	var sprite_offset_label = Label.new()
	sprite_offset_label.text = "Offset del Sprite:"
	sprite_offset_label.custom_minimum_size.x = 150
	sprite_offset_container.add_child(sprite_offset_label)

	var offset_x_label = Label.new()
	offset_x_label.text = "X:"
	sprite_offset_container.add_child(offset_x_label)

	sprite_offset_x_spin = SpinBox.new()
	sprite_offset_x_spin.min_value = -256
	sprite_offset_x_spin.max_value = 256
	sprite_offset_x_spin.step = 1
	sprite_offset_x_spin.value_changed.connect(_on_sprite_offset_changed)
	sprite_offset_x_spin.value_changed.connect(func(_value): _update_preview())
	sprite_offset_x_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sprite_offset_container.add_child(sprite_offset_x_spin)

	var offset_y_label = Label.new()
	offset_y_label.text = "Y:"
	sprite_offset_container.add_child(offset_y_label)

	sprite_offset_y_spin = SpinBox.new()
	sprite_offset_y_spin.min_value = -256
	sprite_offset_y_spin.max_value = 256
	sprite_offset_y_spin.step = 1
	sprite_offset_y_spin.value_changed.connect(_on_sprite_offset_changed)
	sprite_offset_y_spin.value_changed.connect(func(_value): _update_preview())
	sprite_offset_y_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sprite_offset_container.add_child(sprite_offset_y_spin)

	section.add_child(sprite_offset_container)

func _create_water_reflection_section() -> void:
	var section = _create_section("Efectos")

	has_water_reflection_check = CheckBox.new()
	has_water_reflection_check.text = "Mostrar Reflejo en el Agua"
	has_water_reflection_check.toggled.connect(func(pressed): page.has_water_reflection = pressed if page else false)
	section.add_child(has_water_reflection_check)

func _create_section(title: String) -> VBoxContainer:
	var section = VBoxContainer.new()
	section.add_theme_constant_override("separation", 5)

	var title_label = Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0))
	section.add_child(title_label)

	section.add_child(HSeparator.new())

	main_container.add_child(section)
	return section

func _open_file_dialog(selection_type: String, filter: String) -> void:
	current_selection_type = selection_type

	var file_dialog = EditorFileDialog.new()
	file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	file_dialog.add_filter(filter)
	file_dialog.title = "Seleccionar " + selection_type.replace("_", " ").capitalize()

	# Conectar la señal de selección de archivo
	file_dialog.file_selected.connect(func(path: String):
		_on_file_selected(path)
		file_dialog.queue_free()
	)

	# Conectar la señal de cancelación
	file_dialog.canceled.connect(func():
		file_dialog.queue_free()
	)

	# Añadir el diálogo a la escena y mostrarlo
	add_child(file_dialog)
	file_dialog.popup_centered_ratio(0.7)

func _on_file_selected(path: String) -> void:
	if not page:
		return

	match current_selection_type:
		"actor_style":
			page.actor_style = load(path) as ActorStyle
			_update_actor_style_label()
		"sprite_frames":
			page.sprite_frames = load(path) as SpriteFrames
			_update_sprite_frames_label()
		"sprite_texture":
			page.sprite_texture = load(path) as Texture2D
			_update_sprite_texture_label()
			_update_frame_size_visibility()

	_update_preview()

func _on_clear_actor_style() -> void:
	if page:
		page.actor_style = null
		_update_actor_style_label()

func _on_clear_sprite_frames() -> void:
	if page:
		page.sprite_frames = null
		_update_sprite_frames_label()

func _on_clear_sprite_texture() -> void:
	if page:
		page.sprite_texture = null
		page.is_spritesheet = false  # También limpiar is_spritesheet
		_update_sprite_texture_label()
		# Actualizar el checkbox de is_spritesheet
		if is_spritesheet_check:
			is_spritesheet_check.button_pressed = false
		# Actualizar visibilidad de frame_size (ocultar cuando no hay textura)
		_update_frame_size_visibility()

func _update_actor_style_label() -> void:
	if actor_style_label:
		if page and page.actor_style:
			var resource_path = page.actor_style.resource_path
			actor_style_label.text = "ActorStyle: " + resource_path
		else:
			actor_style_label.text = "Ninguno"

func _update_sprite_frames_label() -> void:
	if sprite_frames_label:
		if page and page.sprite_frames:
			var resource_path = page.sprite_frames.resource_path
			sprite_frames_label.text = "SpriteFrames: " + resource_path
		else:
			sprite_frames_label.text = "Ninguno"

func _update_sprite_texture_label() -> void:
	if sprite_texture_label:
		if page and page.sprite_texture:
			var resource_path = page.sprite_texture.resource_path
			sprite_texture_label.text = "Textura: " + resource_path
		else:
			sprite_texture_label.text = "Ninguno"

## Verifica si el evento es un NPC o Trainer
func _is_npc_or_trainer() -> bool:
	if not event_node:
		return false

	var script = event_node.get_script()
	if script:
		var script_path = script.resource_path
		if script_path.ends_with("NPC.gd") or script_path.ends_with("Trainer.gd"):
			return true

	# También verificar por método (NPC tiene get_movement_type)
	if event_node.has_method("get_movement_type"):
		return true

	return false

func _on_is_spritesheet_toggled(pressed: bool) -> void:
	if page:
		page.is_spritesheet = pressed
	_update_frame_size_visibility()

## Actualiza la visibilidad del contenedor de frame_size
func _update_frame_size_visibility() -> void:
	# Buscar el contenedor de frame size en todas las secciones
	var has_texture = page and page.sprite_texture != null
	for child in main_container.get_children():
		if child is VBoxContainer:
			for subchild in child.get_children():
				if subchild.has_meta("frame_size_container"):
					# Mostrar frame size si hay una textura asignada (no solo si es spritesheet)
					subchild.visible = has_texture
				elif subchild.has_meta("sprite_offset_container"):
					# Mostrar sprite offset si hay una textura asignada
					subchild.visible = has_texture

func _on_frame_size_changed(value: float) -> void:
	if not page or is_loading:
		return

	var new_size = Vector2(
		frame_size_x_spin.value if frame_size_x_spin else page.frame_size.x,
		frame_size_y_spin.value if frame_size_y_spin else page.frame_size.y
	)
	page.frame_size = new_size

func _on_sprite_offset_changed(value: float) -> void:
	if not page or is_loading:
		return

	var new_offset = Vector2(
		sprite_offset_x_spin.value if sprite_offset_x_spin else page.sprite_offset.x,
		sprite_offset_y_spin.value if sprite_offset_y_spin else page.sprite_offset.y
	)
	page.sprite_offset = new_offset
	# Marcar que el offset ha sido configurado explícitamente por el usuario
	page.sprite_offset_configured = true

func load_page(p: EventPage, event: Node = null) -> void:
	page = p
	event_node = event
	# Limpiar referencia al SpriteFrames creado al cargar una nueva página
	created_sprite_frames = null
	is_loading = true
	_update_controls()
	is_loading = false

func _update_controls() -> void:
	if not page:
		return

	# Actualizar labels
	_update_actor_style_label()
	_update_sprite_frames_label()
	_update_sprite_texture_label()

	# Actualizar visibilidad de frame_size (mostrar si hay textura)
	_update_frame_size_visibility()

	# Actualizar is_spritesheet
	if is_spritesheet_check:
		is_spritesheet_check.button_pressed = page.is_spritesheet
		_on_is_spritesheet_toggled(page.is_spritesheet)

	# Actualizar frame_size (usar flag is_loading para evitar actualizaciones durante la carga)
	if frame_size_x_spin:
		frame_size_x_spin.value = page.frame_size.x

	if frame_size_y_spin:
		frame_size_y_spin.value = page.frame_size.y

	# Actualizar sprite_offset
	# Para NPCs/Trainers, mostrar (0, -8) por defecto si la página tiene (0, 0) y no está configurado
	# Para eventos normales, mostrar el valor de la página directamente
	var offset = page.sprite_offset

	# Si es NPC/Trainer y el offset es (0, 0) y no está configurado, mostrar (0, -8) en el editor
	if _is_npc_or_trainer() and offset == Vector2(0, 0) and not page.sprite_offset_configured:
		offset = Vector2(0, -8)

	if sprite_offset_x_spin:
		sprite_offset_x_spin.value = offset.x

	if sprite_offset_y_spin:
		sprite_offset_y_spin.value = offset.y

	# Actualizar has_water_reflection
	if has_water_reflection_check:
		has_water_reflection_check.button_pressed = page.has_water_reflection

	# Actualizar vista previa
	_update_preview()

	# Cargar frame inicial seleccionado (solo para eventos normales, después de actualizar la vista previa)
	if not _is_npc_or_trainer() and current_sprite_frames:
		# Si hay una animación guardada y existe, usarla
		if not page.initial_animation.is_empty() and current_sprite_frames.has_animation(page.initial_animation):
			current_animation = page.initial_animation
			current_frame_index = max(0, page.initial_frame)  # Asegurar que sea >= 0
		else:
			# Si no hay configuración guardada o no existe la animación, usar "idle" frame 0 por defecto
			if current_sprite_frames.has_animation("idle"):
				current_animation = "idle"
				current_frame_index = 0
			else:
				# Si no hay "idle", usar la primera animación disponible
				var anim_names = current_sprite_frames.get_animation_names()
				if anim_names.size() > 0:
					current_animation = anim_names[0]
					current_frame_index = 0

		# Actualizar el dropdown de animaciones para reflejar la selección
		_update_animation_dropdown()
		_show_current_frame()

func _on_create_sprite_frames() -> void:
	if not page:
		return

	# Crear un nuevo recurso SpriteFrames (embebido, sin guardar como archivo)
	var new_sprite_frames = SpriteFrames.new()

	# Guardar referencia para abrirlo en el Inspector al cerrar
	created_sprite_frames = new_sprite_frames

	# Asignarlo directamente a la página (se guardará como recurso embebido en la escena)
	page.sprite_frames = new_sprite_frames

	# Notificar cambios para refrescar el Inspector
	if page.has_method("property_list_changed_notify"):
		page.property_list_changed_notify()

	# Actualizar la UI
	_update_sprite_frames_label()
	_update_preview()

	# Mostrar un mensaje informativo al usuario
	var info_dialog = AcceptDialog.new()
	info_dialog.title = "SpriteFrames Creado"
	info_dialog.dialog_text = "Se ha creado un nuevo SpriteFrames y se ha asignado a la página.\n\nAl cerrar esta ventana, se abrirá automáticamente en el Inspector para editarlo."
	add_child(info_dialog)
	info_dialog.popup_centered(Vector2i(400, 150))

func _on_accept_pressed() -> void:
	# Guardar el frame seleccionado en la página (solo para eventos normales, no NPCs)
	if page and not _is_npc_or_trainer():
		if current_sprite_frames and not current_animation.is_empty():
			page.initial_animation = current_animation
			page.initial_frame = current_frame_index
		else:
			# Si no hay frames, establecer valores por defecto
			page.initial_animation = "idle"
			page.initial_frame = 0

	sprite_edited.emit()

	# Si se creó un SpriteFrames, abrirlo en el Inspector al cerrar
	var sprite_frames_to_open = created_sprite_frames
	var event_to_select = event_node
	created_sprite_frames = null  # Limpiar la referencia antes de cerrar

	if sprite_frames_to_open and event_to_select:
		_open_sprite_frames_in_inspector(sprite_frames_to_open, event_to_select)

	queue_free()

func _open_sprite_frames_in_inspector(sprite_frames: SpriteFrames, event_node_ref: Node) -> void:
	if not sprite_frames or not event_node_ref:
		return

	# Usar call_deferred para asegurar que se ejecute después de que la ventana se cierre
	call_deferred("_inspect_sprite_frames_deferred", sprite_frames, event_node_ref)

func _inspect_sprite_frames_deferred(sprite_frames: SpriteFrames, event_node_ref: Node) -> void:
	if not sprite_frames or not is_instance_valid(sprite_frames):
		return

	if not event_node_ref or not is_instance_valid(event_node_ref):
		return

	# Seleccionar el nodo Event en el SceneTree
	var selection = EditorInterface.get_selection()
	if selection:
		selection.clear()
		selection.add_node(event_node_ref)

	# Esperar un frame para que la selección se procese
	await Engine.get_main_loop().process_frame

	# Abrir el recurso SpriteFrames en el Inspector
	EditorInterface.inspect_object(sprite_frames)

func _on_cancel_pressed() -> void:
	cancelled.emit()
	queue_free()

func _on_close_requested() -> void:
	cancelled.emit()
	queue_free()

func _update_preview() -> void:
	if not page or not preview_texture_rect:
		return

	# Obtener los SpriteFrames según la prioridad
	current_sprite_frames = _get_current_sprite_frames()

	if current_sprite_frames:
		# Actualizar el dropdown de animaciones
		_update_animation_dropdown()

		# Mostrar el frame actual
		_show_current_frame()
	else:
		# Si no hay SpriteFrames, mostrar la textura directamente
		var preview_texture: Texture2D = null
		if page.sprite_texture and not page.is_spritesheet:
			preview_texture = page.sprite_texture

		if preview_texture:
			preview_texture_rect.texture = preview_texture
			preview_texture_rect.visible = true
		else:
			preview_texture_rect.texture = null
			preview_texture_rect.visible = false

		# Ocultar controles si no hay SpriteFrames
		_set_controls_visible(false)

func _get_current_sprite_frames() -> SpriteFrames:
	if not page:
		return null

	# Prioridad 1: ActorStyle
	if page.actor_style:
		var frames: SpriteFrames = null
		if page.actor_style.walk_frames:
			frames = page.actor_style.walk_frames
		elif page.actor_style.run_frames:
			frames = page.actor_style.run_frames
		elif page.actor_style.bike_frames:
			frames = page.actor_style.bike_frames
		return frames

	# Prioridad 2: SpriteTexture con is_spritesheet
	if page.sprite_texture and page.is_spritesheet:
		return SpriteFramesGenerator.generate_from_4x4_spritesheet(
			page.sprite_texture,
			page.frame_size
		)

	# Prioridad 3: SpriteFrames manual
	if page.sprite_frames:
		return page.sprite_frames

	return null

func _update_animation_dropdown() -> void:
	if not animation_dropdown or not current_sprite_frames:
		return

	animation_dropdown.clear()
	var anim_names = current_sprite_frames.get_animation_names()

	# Filtrar animaciones vacías (como "default" que Godot crea automáticamente)
	var valid_animations = []
	for anim_name in anim_names:
		var frame_count = current_sprite_frames.get_frame_count(anim_name)
		if frame_count > 0:
			valid_animations.append(anim_name)

	if valid_animations.size() == 0:
		_set_controls_visible(false)
		return

	_set_controls_visible(true)

	# Guardar la animación actual antes de limpiar
	var previous_animation = current_animation

	# Limpiar y añadir animaciones válidas
	for anim_name in valid_animations:
		animation_dropdown.add_item(anim_name)

	# Seleccionar la animación actual si existe, sino la primera válida
	# Si current_animation ya está establecido (por ejemplo, desde initial_animation), mantenerlo
	if not current_animation.is_empty() and current_animation in valid_animations:
		# Mantener la animación actual si está en las válidas
		var selected_index = valid_animations.find(current_animation)
		if selected_index >= 0:
			animation_dropdown.selected = selected_index
		else:
			# Si no está en válidas, usar la primera
			current_animation = valid_animations[0]
			current_frame_index = 0
			animation_dropdown.selected = 0
	elif previous_animation.is_empty() or not previous_animation in valid_animations:
		# Si no hay animación actual, usar la primera válida
		current_animation = valid_animations[0]
		current_frame_index = 0
		animation_dropdown.selected = 0
	else:
		current_animation = previous_animation
		var selected_index = valid_animations.find(current_animation)
		if selected_index >= 0:
			animation_dropdown.selected = selected_index
		else:
			animation_dropdown.selected = 0
			current_animation = valid_animations[0]
			current_frame_index = 0

func _show_current_frame() -> void:
	if not preview_texture_rect:
		return

	if not current_sprite_frames:
		preview_texture_rect.texture = null
		preview_texture_rect.visible = false
		return

	if current_animation.is_empty() or not current_sprite_frames.has_animation(current_animation):
		preview_texture_rect.texture = null
		preview_texture_rect.visible = false
		return

	var frame_count = current_sprite_frames.get_frame_count(current_animation)
	if frame_count == 0:
		preview_texture_rect.texture = null
		preview_texture_rect.visible = false
		return

	# Asegurar que el índice esté en rango
	current_frame_index = clamp(current_frame_index, 0, frame_count - 1)

	var preview_texture = current_sprite_frames.get_frame_texture(current_animation, current_frame_index)
	if preview_texture:
		preview_texture_rect.texture = preview_texture
		preview_texture_rect.visible = true

		# Actualizar el label del frame (usar índice base 0 para mostrar)
		if frame_label:
			# Mostrar frame actual y total (0-indexed)
			if frame_count > 0:
				frame_label.text = "Frame: %d/%d" % [current_frame_index, frame_count - 1]
			else:
				frame_label.text = "Frame: 0"

		# Actualizar estado de los botones
		if prev_frame_button:
			prev_frame_button.disabled = (current_frame_index == 0)
		if next_frame_button:
			next_frame_button.disabled = (current_frame_index >= frame_count - 1)
	else:
		preview_texture_rect.texture = null
		preview_texture_rect.visible = false

func _set_controls_visible(visible: bool) -> void:
	if animation_dropdown:
		animation_dropdown.visible = visible
	if prev_frame_button:
		prev_frame_button.visible = visible
	if next_frame_button:
		next_frame_button.visible = visible
	if frame_label:
		frame_label.visible = visible
	# El label de animación está en el contenedor, buscar por tipo
	var controls_container = preview_container.get_node_or_null("PreviewControlsContainer")
	if controls_container:
		for child in controls_container.get_children():
			if child is Label and child.text == "Animación:":
				child.visible = visible
				break

func _on_animation_selected(index: int) -> void:
	if not current_sprite_frames or not animation_dropdown:
		return

	# Obtener las animaciones válidas (filtradas) del dropdown
	var valid_animations = []
	var all_anim_names = current_sprite_frames.get_animation_names()
	for anim_name in all_anim_names:
		var frame_count = current_sprite_frames.get_frame_count(anim_name)
		if frame_count > 0:
			valid_animations.append(anim_name)

	# Usar el índice del dropdown que corresponde a las animaciones válidas
	if index >= 0 and index < valid_animations.size():
		current_animation = valid_animations[index]
		current_frame_index = 0
		_show_current_frame()

func _on_prev_frame() -> void:
	if not current_sprite_frames or current_animation.is_empty():
		return

	if current_frame_index > 0:
		current_frame_index -= 1
		_show_current_frame()

func _on_next_frame() -> void:
	if not current_sprite_frames or current_animation.is_empty():
		return

	var frame_count = current_sprite_frames.get_frame_count(current_animation)
	if current_frame_index < frame_count - 1:
		current_frame_index += 1
		_show_current_frame()

