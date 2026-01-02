@tool
extends Window

## Ventana de edición para propiedades de movimiento de EventPage
## Permite editar todas las propiedades relacionadas con el movimiento de NPCs

signal movement_edited
signal cancelled

var page: EventPage = null
var event_node: Event = null  # Evento que se está editando

# Referencias a los controles
var scroll_container: ScrollContainer = null
var main_container: VBoxContainer = null
var accept_button: Button = null

# Referencias a controles específicos para actualizar valores
var movement_type_option: OptionButton = null
var orientation_option: OptionButton = null
var initial_dir_option: OptionButton = null
var speed_option: OptionButton = null
var preserve_check: CheckBox = null
var min_spin_random: SpinBox = null
var max_spin_random: SpinBox = null
var delay_spin_look: SpinBox = null
var min_spin_turning: SpinBox = null
var max_spin_turning: SpinBox = null
var enabled_check_awareness: CheckBox = null
var chance_spin: SpinBox = null
var multiplier_spin: SpinBox = null
var distance_spin: SpinBox = null
var valid_tiles_label: Label = null
var valid_tiles_button: Button = null
var clear_tiles_button: Button = null

func _ready() -> void:
	title = "Gestionar Movimiento"
	size = Vector2(750, 800)
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

	scroll_container = ScrollContainer.new()
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_vbox.add_child(scroll_container)

	main_container = VBoxContainer.new()
	main_container.add_theme_constant_override("separation", 10)
	scroll_container.add_child(main_container)

	# Crear secciones de propiedades
	_create_movement_section()
	_create_random_movement_section()
	_create_path_movement_section()
	_create_look_pattern_section()
	_create_random_turning_section()
	_create_player_awareness_section()

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

func _create_movement_section() -> void:
	var section = _create_section("Movement (NPC)")

	# Fila 1: Movement Type y Orientation Behavior
	var row1 = HBoxContainer.new()
	row1.add_theme_constant_override("separation", 10)

	var movement_type_label = Label.new()
	movement_type_label.text = "Tipo de Movimiento:"
	movement_type_label.custom_minimum_size.x = 180
	row1.add_child(movement_type_label)

	movement_type_option = OptionButton.new()
	movement_type_option.add_item("None", 0)
	movement_type_option.add_item("Random", 1)
	movement_type_option.add_item("Path", 2)
	movement_type_option.add_item("RandomTurning", 3)
	movement_type_option.add_item("LookPattern", 4)
	movement_type_option.add_item("RandomVertical", 5)
	movement_type_option.add_item("RandomHorizontal", 6)
	movement_type_option.item_selected.connect(_on_movement_type_changed)
	movement_type_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_child(movement_type_option)

	var orientation_label = Label.new()
	orientation_label.text = "Orientación:"
	orientation_label.custom_minimum_size.x = 120
	row1.add_child(orientation_label)

	orientation_option = OptionButton.new()
	orientation_option.add_item("Face Player", 0)
	orientation_option.add_item("Fixed", 1)
	orientation_option.add_item("Face and Restore", 2)
	orientation_option.item_selected.connect(func(idx): page.orientation_behavior = idx if page else 0)
	orientation_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_child(orientation_option)

	section.add_child(row1)

	# Fila 2: Initial Direction y Movement Speed
	var row2 = HBoxContainer.new()
	row2.add_theme_constant_override("separation", 10)

	var initial_dir_label = Label.new()
	initial_dir_label.text = "Dirección Inicial:"
	initial_dir_label.custom_minimum_size.x = 180
	row2.add_child(initial_dir_label)

	initial_dir_option = OptionButton.new()
	initial_dir_option.add_item("Up", 0)
	initial_dir_option.add_item("Down", 1)
	initial_dir_option.add_item("Left", 2)
	initial_dir_option.add_item("Right", 3)
	initial_dir_option.item_selected.connect(func(idx): page.initial_direction = idx if page else 1)
	initial_dir_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_child(initial_dir_option)

	var speed_label = Label.new()
	speed_label.text = "Velocidad:"
	speed_label.custom_minimum_size.x = 120
	row2.add_child(speed_label)

	speed_option = OptionButton.new()
	speed_option.add_item("Slowest", 0)
	speed_option.add_item("Slower", 1)
	speed_option.add_item("Normal", 2)
	speed_option.add_item("Faster", 3)
	speed_option.add_item("Fastest", 4)
	speed_option.item_selected.connect(func(idx): page.movement_speed = idx if page else 2)
	speed_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_child(speed_option)

	section.add_child(row2)

	# Preserve Direction
	preserve_check = CheckBox.new()
	preserve_check.text = "Preservar Dirección al Cambiar de Página"
	preserve_check.toggled.connect(func(pressed): page.preserve_direction_on_sprite_match = pressed if page else false)
	section.add_child(preserve_check)

func _create_random_movement_section() -> void:
	var section = _create_section("Random Movement (NPC)")

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	# Random Move Interval Min
	var min_label = Label.new()
	min_label.text = "Intervalo Mínimo (seg):"
	min_label.custom_minimum_size.x = 180
	row.add_child(min_label)

	min_spin_random = SpinBox.new()
	min_spin_random.min_value = 0.1
	min_spin_random.max_value = 60.0
	min_spin_random.step = 0.1
	min_spin_random.value_changed.connect(func(val): page.random_move_interval_min = val if page else 2.0)
	min_spin_random.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(min_spin_random)

	# Random Move Interval Max
	var max_label = Label.new()
	max_label.text = "Intervalo Máximo (seg):"
	max_label.custom_minimum_size.x = 180
	row.add_child(max_label)

	max_spin_random = SpinBox.new()
	max_spin_random.min_value = 0.1
	max_spin_random.max_value = 60.0
	max_spin_random.step = 0.1
	max_spin_random.value_changed.connect(func(val): page.random_move_interval_max = val if page else 5.0)
	max_spin_random.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(max_spin_random)

	section.add_child(row)

	# Celdas válidas para movimiento aleatorio
	var tiles_row = HBoxContainer.new()
	tiles_row.add_theme_constant_override("separation", 10)

	var tiles_label = Label.new()
	tiles_label.text = "Celdas Válidas:"
	tiles_label.custom_minimum_size.x = 180
	tiles_row.add_child(tiles_label)

	valid_tiles_button = Button.new()
	valid_tiles_button.text = "Seleccionar Celdas"
	valid_tiles_button.pressed.connect(_on_select_valid_tiles_pressed)
	valid_tiles_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tiles_row.add_child(valid_tiles_button)

	clear_tiles_button = Button.new()
	clear_tiles_button.text = "Limpiar"
	clear_tiles_button.pressed.connect(_on_clear_valid_tiles_pressed)
	tiles_row.add_child(clear_tiles_button)

	section.add_child(tiles_row)

	# Label para mostrar las celdas seleccionadas
	valid_tiles_label = Label.new()
	valid_tiles_label.text = "Ninguna celda seleccionada"
	valid_tiles_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	valid_tiles_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.7))
	section.add_child(valid_tiles_label)

func _create_path_movement_section() -> void:
	var section = _create_section("Path Movement (NPC)")

	var info_label = Label.new()
	info_label.text = "Nota: La edición de rutas de movimiento se gestiona desde el sistema de movimiento del NPC."
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	section.add_child(info_label)

func _create_look_pattern_section() -> void:
	var section = _create_section("Look Pattern (NPC)")

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	# Look Pattern Delay
	var delay_label = Label.new()
	delay_label.text = "Tiempo de Mirada (seg):"
	delay_label.custom_minimum_size.x = 180
	row.add_child(delay_label)

	delay_spin_look = SpinBox.new()
	delay_spin_look.min_value = 0.1
	delay_spin_look.max_value = 60.0
	delay_spin_look.step = 0.1
	delay_spin_look.value_changed.connect(func(val): page.look_pattern_delay = val if page else 2.0)
	delay_spin_look.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(delay_spin_look)

	section.add_child(row)

	var info_label = Label.new()
	info_label.text = "Nota: Las direcciones de mirada se gestionan desde el sistema de movimiento del NPC."
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	section.add_child(info_label)

func _create_random_turning_section() -> void:
	var section = _create_section("Random Turning (NPC)")

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	# Random Turning Interval Min
	var min_label = Label.new()
	min_label.text = "Intervalo Mínimo (seg):"
	min_label.custom_minimum_size.x = 180
	row.add_child(min_label)

	min_spin_turning = SpinBox.new()
	min_spin_turning.min_value = 0.1
	min_spin_turning.max_value = 60.0
	min_spin_turning.step = 0.1
	min_spin_turning.value_changed.connect(func(val): page.random_turning_interval_min = val if page else 2.0)
	min_spin_turning.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(min_spin_turning)

	# Random Turning Interval Max
	var max_label = Label.new()
	max_label.text = "Intervalo Máximo (seg):"
	max_label.custom_minimum_size.x = 180
	row.add_child(max_label)

	max_spin_turning = SpinBox.new()
	max_spin_turning.min_value = 0.1
	max_spin_turning.max_value = 60.0
	max_spin_turning.step = 0.1
	max_spin_turning.value_changed.connect(func(val): page.random_turning_interval_max = val if page else 5.0)
	max_spin_turning.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(max_spin_turning)

	section.add_child(row)

func _create_player_awareness_section() -> void:
	var section = _create_section("Player Awareness (NPC)")

	# Awareness Enabled
	enabled_check_awareness = CheckBox.new()
	enabled_check_awareness.text = "Awareness Habilitado"
	enabled_check_awareness.toggled.connect(func(pressed): page.awareness_enabled = pressed if page else false)
	section.add_child(enabled_check_awareness)

	# Fila 1: Awareness Chance y Running Multiplier
	var row1 = HBoxContainer.new()
	row1.add_theme_constant_override("separation", 10)

	var chance_label = Label.new()
	chance_label.text = "Probabilidad Base (0.0-1.0):"
	chance_label.custom_minimum_size.x = 180
	row1.add_child(chance_label)

	chance_spin = SpinBox.new()
	chance_spin.min_value = 0.0
	chance_spin.max_value = 1.0
	chance_spin.step = 0.01
	chance_spin.value_changed.connect(func(val): page.awareness_chance = val if page else 0.3)
	chance_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_child(chance_spin)

	var multiplier_label = Label.new()
	multiplier_label.text = "Multiplicador al Correr:"
	multiplier_label.custom_minimum_size.x = 180
	row1.add_child(multiplier_label)

	multiplier_spin = SpinBox.new()
	multiplier_spin.min_value = 0.0
	multiplier_spin.max_value = 10.0
	multiplier_spin.step = 0.1
	multiplier_spin.value_changed.connect(func(val): page.awareness_running_multiplier = val if page else 2.0)
	multiplier_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_child(multiplier_spin)

	section.add_child(row1)

	# Fila 2: Detection Distance
	var row2 = HBoxContainer.new()
	row2.add_theme_constant_override("separation", 10)

	var distance_label = Label.new()
	distance_label.text = "Distancia de Detección (tiles):"
	distance_label.custom_minimum_size.x = 180
	row2.add_child(distance_label)

	distance_spin = SpinBox.new()
	distance_spin.min_value = 0.0
	distance_spin.max_value = 20.0
	distance_spin.step = 0.1
	distance_spin.value_changed.connect(func(val): page.awareness_detection_distance = val if page else 3.0)
	distance_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_child(distance_spin)

	section.add_child(row2)

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

func load_page(p: EventPage) -> void:
	page = p
	_update_controls()

func _on_accept_pressed() -> void:
	# Forzar notificación de cambios en el Resource para que se guarde correctamente
	if page and page.has_method("property_list_changed_notify"):
		page.property_list_changed_notify()
	movement_edited.emit()
	queue_free()

func _on_cancel_pressed() -> void:
	cancelled.emit()
	queue_free()

func _update_controls() -> void:
	if not page:
		return

	# Actualizar Movement section
	if movement_type_option:
		movement_type_option.selected = page.movement_type
	if orientation_option:
		orientation_option.selected = page.orientation_behavior
	if initial_dir_option:
		initial_dir_option.selected = page.initial_direction
	if speed_option:
		speed_option.selected = page.movement_speed
	if preserve_check:
		preserve_check.button_pressed = page.preserve_direction_on_sprite_match

	# Actualizar Random Movement
	if min_spin_random:
		min_spin_random.value = page.random_move_interval_min
	if max_spin_random:
		max_spin_random.value = page.random_move_interval_max

	# Actualizar Look Pattern
	if delay_spin_look:
		delay_spin_look.value = page.look_pattern_delay

	# Actualizar Random Turning
	if min_spin_turning:
		min_spin_turning.value = page.random_turning_interval_min
	if max_spin_turning:
		max_spin_turning.value = page.random_turning_interval_max

	# Actualizar Player Awareness
	if enabled_check_awareness:
		enabled_check_awareness.button_pressed = page.awareness_enabled
	if chance_spin:
		chance_spin.value = page.awareness_chance
	if multiplier_spin:
		multiplier_spin.value = page.awareness_running_multiplier
	if distance_spin:
		distance_spin.value = page.awareness_detection_distance

	# Actualizar Celdas Válidas
	_update_valid_tiles_label()

## Variable para guardar el tipo de movimiento anterior (para revertir si se cancela)
var _previous_movement_type: int = -1

func _on_movement_type_changed(new_idx: int) -> void:
	if not page:
		return

	var old_type = page.movement_type
	var has_valid_tiles = page.random_movement_valid_tiles.size() > 0

	# Tipos que usan celdas válidas: RANDOM (1), RANDOM_VERTICAL (5), RANDOM_HORIZONTAL (6)
	var old_uses_tiles = old_type in [1, 5, 6]
	var new_uses_tiles = new_idx in [1, 5, 6]

	# Si cambiamos entre tipos que usan celdas y hay celdas seleccionadas, avisar
	if has_valid_tiles and old_uses_tiles and (not new_uses_tiles or old_type != new_idx):
		_previous_movement_type = old_type
		_show_clear_tiles_confirmation(new_idx)
	else:
		# Cambio directo sin confirmación
		page.movement_type = new_idx


func _show_clear_tiles_confirmation(new_type: int) -> void:
	var dialog = ConfirmationDialog.new()
	dialog.title = "Cambio de tipo de movimiento"
	dialog.dialog_text = "Hay celdas válidas seleccionadas.\nAl cambiar el tipo de movimiento se limpiarán las celdas."
	dialog.ok_button_text = "Aceptar"
	dialog.cancel_button_text = "Cancelar"

	add_child(dialog)

	dialog.confirmed.connect(func():
		# Limpiar celdas y cambiar tipo
		page.random_movement_valid_tiles.clear()
		page.movement_type = new_type
		_update_valid_tiles_label()
		dialog.queue_free()
	)

	dialog.canceled.connect(func():
		# Revertir el OptionButton al valor anterior
		if movement_type_option and _previous_movement_type >= 0:
			movement_type_option.selected = _previous_movement_type
		dialog.queue_free()
	)

	dialog.popup_centered()


func _on_close_requested() -> void:
	cancelled.emit()
	queue_free()

func _on_select_valid_tiles_pressed() -> void:
	if not page:
		return

	# Usar EditorInterface directamente (disponible como singleton en el editor)
	var ed_interface = EditorInterface

	# Obtener la escena editada
	var edited_scene_root = ed_interface.get_edited_scene_root()
	if not edited_scene_root:
		push_error("Movement Editor: No hay escena editada")
		return

	# Buscar OverworldGrid en la escena
	var overworld_grid = edited_scene_root.find_child("OverworldGrid", true, false)
	if not overworld_grid or not overworld_grid is OverworldGrid:
		push_error("Movement Editor: No se encontró OverworldGrid en la escena")
		return

	# Cargar y crear la ventana de vista del mapa (modo múltiple)
	var selector_script = load("res://addons/event_tools/position_selector_window.gd")
	if not selector_script:
		push_error("Movement Editor: No se encontró el script de la ventana de vista del mapa")
		return

	var selector_window = selector_script.new()
	# Añadir como hijo del editor para que sea modal
	add_child(selector_window)

	# Configurar la ventana en modo múltiple, pasando el evento que se está editando
	await selector_window.setup(overworld_grid, edited_scene_root, event_node)
	selector_window.set_multiple_selection_mode(true)

	# Configurar restricción de celdas según el tipo de movimiento
	# Obtener la posición del evento en coordenadas de tile
	var event_tile_pos = Vector2i.ZERO
	if event_node and overworld_grid:
		# Buscar un TileMapLayer para convertir coordenadas
		var tile_layer: TileMapLayer = null
		for child in overworld_grid.get_children():
			if child is TileMapLayer:
				tile_layer = child
				break

		if tile_layer:
			var local_pos = tile_layer.to_local(event_node.global_position)
			event_tile_pos = tile_layer.local_to_map(local_pos)

	selector_window.set_movement_restriction(page.movement_type, event_tile_pos)

	# Cargar celdas válidas existentes si las hay
	if page.random_movement_valid_tiles.size() > 0:
		selector_window.set_selected_tiles(page.random_movement_valid_tiles)

	# Conectar señal para guardar las celdas seleccionadas
	selector_window.tiles_selected.connect(func(tiles: Array[Vector2i]):
		page.random_movement_valid_tiles = tiles
		_update_valid_tiles_label()
		selector_window.queue_free()
	)
	# Conectar señal de cancelación
	selector_window.cancelled.connect(func(): selector_window.queue_free())

	# Mostrar la ventana de forma modal
	selector_window.popup_centered()

func _on_clear_valid_tiles_pressed() -> void:
	if not page:
		return
	page.random_movement_valid_tiles.clear()
	_update_valid_tiles_label()

func _update_valid_tiles_label() -> void:
	if not valid_tiles_label or not page:
		return

	var tiles = page.random_movement_valid_tiles
	if tiles.is_empty():
		valid_tiles_label.text = "Ninguna celda seleccionada (el NPC puede moverse a cualquier celda válida)"
		if clear_tiles_button:
			clear_tiles_button.visible = false
	else:
		var tiles_text = "Celdas válidas (%d): " % tiles.size()
		var tiles_list: Array[String] = []
		for tile in tiles:
			tiles_list.append("(%d, %d)" % [tile.x, tile.y])
		tiles_text += ", ".join(tiles_list)
		valid_tiles_label.text = tiles_text
		if clear_tiles_button:
			clear_tiles_button.visible = true

