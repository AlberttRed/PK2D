@tool
extends Window

## Ventana de edición para ShowPortraitCommand
## Permite editar todas las propiedades export del comando

signal command_edited(command: ShowPortraitCommand)
signal cancelled

var command: ShowPortraitCommand = null

# Valores originales para poder cancelar
var original_image_source: int = 0
var original_pokemon_species: int = 0
var original_texture: Texture2D = null
var original_scale_mode: int = 0
var original_frame_style: int = 0
var original_position: int = 0
var original_z_index_offset: int = 0
var original_close_mode: int = 0
var original_auto_close_time: float = 2.0

# Referencias a los controles
var image_source_option: OptionButton = null
var pokemon_species_option: OptionButton = null
var texture_button: Button = null
var texture_label: Label = null
var scale_mode_option: OptionButton = null
var frame_style_option: OptionButton = null
var position_option: OptionButton = null
var z_index_offset_spin: SpinBox = null
var close_mode_option: OptionButton = null
var auto_close_time_spin: SpinBox = null

# Contenedores para mostrar/ocultar según image_source
var pokemon_container: Control = null
var texture_container: Control = null

func _ready() -> void:
	title = "Editar ShowPortraitCommand"
	size = Vector2(500, 500)
	unresizable = false
	always_on_top = false
	exclusive = true
	close_requested.connect(_on_close_requested)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("margin_left", 10)
	vbox.add_theme_constant_override("margin_top", 10)
	vbox.add_theme_constant_override("margin_right", 10)
	vbox.add_theme_constant_override("margin_bottom", 10)
	add_child(vbox)

	var title_label = Label.new()
	title_label.text = "Editar ShowPortraitCommand"
	title_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title_label)
	vbox.add_child(HSeparator.new())

	# Image Source
	var image_source_container = HBoxContainer.new()
	var image_source_label = Label.new()
	image_source_label.text = "Fuente de imagen:"
	image_source_label.custom_minimum_size.x = 150
	image_source_container.add_child(image_source_label)

	image_source_option = OptionButton.new()
	image_source_option.add_item("Pokémon")
	image_source_option.add_item("Textura")
	image_source_option.item_selected.connect(_on_image_source_selected)
	image_source_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	image_source_container.add_child(image_source_option)
	vbox.add_child(image_source_container)

	# Pokémon Species (solo visible si image_source = POKEMON)
	pokemon_container = VBoxContainer.new()
	var pokemon_species_container = HBoxContainer.new()
	var pokemon_species_label = Label.new()
	pokemon_species_label.text = "Especie Pokémon:"
	pokemon_species_label.custom_minimum_size.x = 150
	pokemon_species_container.add_child(pokemon_species_label)

	pokemon_species_option = OptionButton.new()
	pokemon_species_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_populate_pokemon_species()
	pokemon_species_container.add_child(pokemon_species_option)
	pokemon_container.add_child(pokemon_species_container)
	vbox.add_child(pokemon_container)

	# Texture (solo visible si image_source = TEXTURE)
	texture_container = VBoxContainer.new()
	var texture_row = HBoxContainer.new()
	var texture_label_container = Label.new()
	texture_label_container.text = "Textura:"
	texture_label_container.custom_minimum_size.x = 150
	texture_row.add_child(texture_label_container)

	var texture_controls = HBoxContainer.new()
	texture_label = Label.new()
	texture_label.text = "(ninguna)"
	texture_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texture_controls.add_child(texture_label)

	texture_button = Button.new()
	texture_button.text = "Seleccionar..."
	texture_button.pressed.connect(_on_select_texture)
	texture_controls.add_child(texture_button)

	var clear_texture_button = Button.new()
	clear_texture_button.text = "Limpiar"
	clear_texture_button.pressed.connect(_on_clear_texture)
	texture_controls.add_child(clear_texture_button)

	texture_row.add_child(texture_controls)
	texture_container.add_child(texture_row)

	# Scale Mode (solo visible si image_source = TEXTURE)
	var scale_mode_container = HBoxContainer.new()
	var scale_mode_label = Label.new()
	scale_mode_label.text = "Modo de escala:"
	scale_mode_label.custom_minimum_size.x = 150
	scale_mode_container.add_child(scale_mode_label)

	scale_mode_option = OptionButton.new()
	scale_mode_option.add_item("Pixel Perfect")
	scale_mode_option.add_item("Fit Box")
	scale_mode_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scale_mode_container.add_child(scale_mode_option)
	texture_container.add_child(scale_mode_container)
	vbox.add_child(texture_container)

	# Frame Style
	var frame_style_container = HBoxContainer.new()
	var frame_style_label = Label.new()
	frame_style_label.text = "Estilo de marco:"
	frame_style_label.custom_minimum_size.x = 150
	frame_style_container.add_child(frame_style_label)

	frame_style_option = OptionButton.new()
	frame_style_option.add_item("HeartGold/SoulSilver")
	frame_style_option.add_item("Cartel 1")
	frame_style_option.add_item("FireRed")
	frame_style_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame_style_container.add_child(frame_style_option)
	vbox.add_child(frame_style_container)

	# Position
	var position_container = HBoxContainer.new()
	var position_label = Label.new()
	position_label.text = "Posición:"
	position_label.custom_minimum_size.x = 150
	position_container.add_child(position_label)

	position_option = OptionButton.new()
	position_option.add_item("Izquierda")
	position_option.add_item("Derecha")
	position_option.add_item("Centro")
	position_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	position_container.add_child(position_option)
	vbox.add_child(position_container)

	# Z Index Offset
	var z_index_container = HBoxContainer.new()
	var z_index_label = Label.new()
	z_index_label.text = "Z Index Offset:"
	z_index_label.custom_minimum_size.x = 150
	z_index_container.add_child(z_index_label)

	z_index_offset_spin = SpinBox.new()
	z_index_offset_spin.min_value = -100
	z_index_offset_spin.max_value = 100
	z_index_offset_spin.value = 0
	z_index_offset_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	z_index_container.add_child(z_index_offset_spin)
	vbox.add_child(z_index_container)

	# Close Mode
	var close_mode_container = HBoxContainer.new()
	var close_mode_label = Label.new()
	close_mode_label.text = "Modo de cierre:"
	close_mode_label.custom_minimum_size.x = 150
	close_mode_container.add_child(close_mode_label)

	close_mode_option = OptionButton.new()
	close_mode_option.add_item("Esperar input")
	close_mode_option.add_item("Cierre automático")
	close_mode_option.add_item("No cerrar")
	close_mode_option.item_selected.connect(_on_close_mode_selected)
	close_mode_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_mode_container.add_child(close_mode_option)
	vbox.add_child(close_mode_container)

	# Auto Close Time (solo visible si close_mode = AUTO_TIME)
	var auto_close_container = HBoxContainer.new()
	var auto_close_label = Label.new()
	auto_close_label.text = "Tiempo cierre (seg):"
	auto_close_label.custom_minimum_size.x = 150
	auto_close_container.add_child(auto_close_label)

	auto_close_time_spin = SpinBox.new()
	auto_close_time_spin.min_value = 0.0
	auto_close_time_spin.max_value = 60.0
	auto_close_time_spin.step = 0.1
	auto_close_time_spin.value = 2.0
	auto_close_time_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	auto_close_container.add_child(auto_close_time_spin)
	vbox.add_child(auto_close_container)

	# Botones
	var buttons_container = HBoxContainer.new()
	buttons_container.alignment = BoxContainer.ALIGNMENT_END
	buttons_container.add_theme_constant_override("separation", 10)

	var accept_button = Button.new()
	accept_button.text = "Aceptar"
	accept_button.pressed.connect(_on_accept_pressed)
	buttons_container.add_child(accept_button)

	var cancel_button = Button.new()
	cancel_button.text = "Cancelar"
	cancel_button.pressed.connect(_on_cancel_pressed)
	buttons_container.add_child(cancel_button)

	vbox.add_child(buttons_container)

## Pobla el dropdown con los Pokémon disponibles usando el enum
func _populate_pokemon_species() -> void:
	if not pokemon_species_option:
		return

	pokemon_species_option.clear()

	# Iterar sobre los valores del enum (1-151) y usar la función del enum para obtener el nombre
	for pokemon_id in range(1, 152):
		var pokemon_enum_value = pokemon_id as PokemonsEnum.Values
		var pokemon_name = PokemonsEnum.get_display_name(pokemon_enum_value)
		pokemon_species_option.add_item(pokemon_name)

## Se llama cuando cambia la selección de la fuente de imagen
func _on_image_source_selected(index: int) -> void:
	_update_image_source_ui()

## Actualiza la visibilidad de los controles según la fuente de imagen
func _update_image_source_ui() -> void:
	if not image_source_option:
		return

	var is_pokemon = (image_source_option.selected == ShowPortraitCommand.ImageSource.POKEMON)
	var is_texture = (image_source_option.selected == ShowPortraitCommand.ImageSource.TEXTURE)

	if pokemon_container:
		pokemon_container.visible = is_pokemon
	if texture_container:
		texture_container.visible = is_texture

## Se llama cuando cambia la selección del modo de cierre
func _on_close_mode_selected(index: int) -> void:
	_update_close_mode_ui()

## Actualiza la visibilidad del tiempo de cierre automático
func _update_close_mode_ui() -> void:
	if not close_mode_option:
		return

	var is_auto_time = (close_mode_option.selected == ShowPortraitCommand.CloseMode.AUTO_TIME)
	if auto_close_time_spin:
		auto_close_time_spin.editable = is_auto_time

## Abre el selector de texturas
func _on_select_texture() -> void:
	if not command:
		return

	var file_dialog = EditorFileDialog.new()
	file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	file_dialog.add_filter("*.png", "PNG Images")
	file_dialog.add_filter("*.jpg", "JPG Images")
	file_dialog.add_filter("*.jpeg", "JPEG Images")
	file_dialog.title = "Seleccionar Textura"

	file_dialog.file_selected.connect(func(path: String):
		var texture_resource = load(path) as Texture2D
		if texture_resource:
			command.texture = texture_resource
			_update_texture_display()
		file_dialog.queue_free()
	)

	file_dialog.canceled.connect(func():
		file_dialog.queue_free()
	)

	add_child(file_dialog)
	file_dialog.popup_centered_ratio(0.7)

## Limpia la textura seleccionada
func _on_clear_texture() -> void:
	if command:
		command.texture = null
		_update_texture_display()

## Actualiza la etiqueta de la textura
func _update_texture_display() -> void:
	if not texture_label:
		return

	if not command:
		texture_label.text = "(ninguna)"
		return

	# Acceder de forma segura sin cargar el recurso
	var texture = command.get("texture")
	if texture == null:
		texture_label.text = "(ninguna)"
		return

	# Intentar obtener el path sin cargar el recurso completo
	var texture_path = texture.get("resource_path") if texture != null else ""
	if texture_path and texture_path != "":
		texture_label.text = texture_path.get_file()
	else:
		texture_label.text = "(textura)"

## Carga un comando existente para editar
func load_command(cmd: ShowPortraitCommand) -> void:
	if not cmd:
		push_error("ShowPortraitCommandEditor: No se proporcionó un comando válido")
		return

	command = cmd

	# Guardar valores originales para poder cancelar
	original_image_source = cmd.image_source
	original_pokemon_species = cmd.pokemon_species
	original_texture = cmd.texture
	original_scale_mode = cmd.scale_mode
	original_frame_style = cmd.frame_style
	original_position = cmd.position
	original_z_index_offset = cmd.z_index_offset
	original_close_mode = cmd.close_mode
	original_auto_close_time = cmd.auto_close_time

	if image_source_option:
		image_source_option.selected = cmd.image_source
		_update_image_source_ui()

	if pokemon_species_option:
		# Buscar el índice del Pokémon en el dropdown
		var pokemon_index = _find_pokemon_index(cmd.pokemon_species)
		if pokemon_index >= 0:
			pokemon_species_option.selected = pokemon_index

	_update_texture_display()

	if scale_mode_option:
		scale_mode_option.selected = cmd.scale_mode

	if frame_style_option:
		frame_style_option.selected = cmd.frame_style

	if position_option:
		position_option.selected = cmd.position

	if z_index_offset_spin:
		z_index_offset_spin.value = cmd.z_index_offset

	if close_mode_option:
		close_mode_option.selected = cmd.close_mode
		_update_close_mode_ui()

	if auto_close_time_spin:
		auto_close_time_spin.value = cmd.auto_close_time

## Busca el índice de un Pokémon en el dropdown por su ID
func _find_pokemon_index(pokemon_id: int) -> int:
	if not pokemon_species_option:
		return -1

	# El índice en el dropdown corresponde directamente al ID - 1 (porque empezamos en 1, no en 0)
	# Ya que iteramos desde 1 hasta 151
	if pokemon_id >= 1 and pokemon_id <= 151:
		return pokemon_id - 1

	return -1

## Obtiene el ID del Pokémon seleccionado en el dropdown
func _get_selected_pokemon_id() -> int:
	if not pokemon_species_option:
		return PokemonsEnum.Values.BULBASAUR

	var selected_index = pokemon_species_option.selected
	if selected_index < 0 or selected_index >= pokemon_species_option.get_item_count():
		return PokemonsEnum.Values.BULBASAUR

	# El índice en el dropdown corresponde directamente al ID (índice 0 = ID 1, índice 1 = ID 2, etc.)
	# Ya que iteramos desde 1 hasta 151
	return selected_index + 1

## Aplica los valores editados al comando
func _apply_values_to_command() -> void:
	if not command:
		return

	command.image_source = image_source_option.selected if image_source_option else 0

	if image_source_option and image_source_option.selected == ShowPortraitCommand.ImageSource.POKEMON:
		command.pokemon_species = _get_selected_pokemon_id()
	elif image_source_option and image_source_option.selected == ShowPortraitCommand.ImageSource.TEXTURE:
		command.scale_mode = scale_mode_option.selected if scale_mode_option else 0

	command.frame_style = frame_style_option.selected if frame_style_option else 0
	command.position = position_option.selected if position_option else 0
	command.z_index_offset = int(z_index_offset_spin.value) if z_index_offset_spin else 0
	command.close_mode = close_mode_option.selected if close_mode_option else 0
	command.auto_close_time = auto_close_time_spin.value if auto_close_time_spin else 2.0

## Restaura los valores originales del comando
func _restore_original_values() -> void:
	if not command:
		return

	command.image_source = original_image_source
	command.pokemon_species = original_pokemon_species
	command.texture = original_texture
	command.scale_mode = original_scale_mode
	command.frame_style = original_frame_style
	command.position = original_position
	command.z_index_offset = original_z_index_offset
	command.close_mode = original_close_mode
	command.auto_close_time = original_auto_close_time

	# Actualizar la UI
	if image_source_option:
		image_source_option.selected = original_image_source
		_update_image_source_ui()

	if pokemon_species_option:
		var pokemon_index = _find_pokemon_index(original_pokemon_species)
		if pokemon_index >= 0:
			pokemon_species_option.selected = pokemon_index

	_update_texture_display()

	if scale_mode_option:
		scale_mode_option.selected = original_scale_mode

	if frame_style_option:
		frame_style_option.selected = original_frame_style

	if position_option:
		position_option.selected = original_position

	if z_index_offset_spin:
		z_index_offset_spin.value = original_z_index_offset

	if close_mode_option:
		close_mode_option.selected = original_close_mode
		_update_close_mode_ui()

	if auto_close_time_spin:
		auto_close_time_spin.value = original_auto_close_time

func _on_accept_pressed() -> void:
	_apply_values_to_command()
	command_edited.emit(command)
	hide()

func _on_cancel_pressed() -> void:
	_restore_original_values()
	cancelled.emit()
	hide()

func _on_close_requested() -> void:
	_restore_original_values()
	cancelled.emit()
	hide()

