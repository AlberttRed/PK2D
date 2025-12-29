@tool
extends Window

## Ventana de edición para propiedades de movimiento de EventPage
## Permite editar todas las propiedades relacionadas con el movimiento de NPCs

signal movement_edited
signal cancelled

var page: EventPage = null

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
	movement_type_option.item_selected.connect(func(idx): page.movement_type = idx if page else 0)
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

func _on_close_requested() -> void:
	cancelled.emit()
	queue_free()

