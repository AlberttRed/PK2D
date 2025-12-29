@tool
extends Window

## Ventana de edición para propiedades de Trainer de EventPage
## Permite editar las propiedades relacionadas con la detección de trainers

signal trainer_edited
signal cancelled

var page: EventPage = null

# Referencias a los controles
var scroll_container: ScrollContainer = null
var main_container: VBoxContainer = null
var accept_button: Button = null

# Referencias a controles específicos para actualizar valores
var enable_detection_check: CheckBox = null
var detection_range_spin: SpinBox = null

func _ready() -> void:
	title = "Gestionar Trainer"
	size = Vector2(500, 200)
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

	# Crear sección de propiedades
	_create_trainer_section()

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

func _create_trainer_section() -> void:
	var section = _create_section("Trainer Detection")

	# Enable Trainer Detection
	enable_detection_check = CheckBox.new()
	enable_detection_check.text = "Habilitar Detección de Trainer"
	enable_detection_check.toggled.connect(func(pressed): page.enable_trainer_detection = pressed if page else false)
	section.add_child(enable_detection_check)

	# Detection Range
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var range_label = Label.new()
	range_label.text = "Rango de Detección (tiles):"
	range_label.custom_minimum_size.x = 200
	row.add_child(range_label)

	detection_range_spin = SpinBox.new()
	detection_range_spin.min_value = 1
	detection_range_spin.max_value = 10
	detection_range_spin.step = 1
	detection_range_spin.value_changed.connect(func(val): page.detection_range = int(val) if page else 5)
	detection_range_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(detection_range_spin)

	section.add_child(row)

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

func _update_controls() -> void:
	if not page:
		return

	# Actualizar Trainer Detection
	if enable_detection_check:
		enable_detection_check.button_pressed = page.enable_trainer_detection
	if detection_range_spin:
		detection_range_spin.value = page.detection_range

func _on_accept_pressed() -> void:
	trainer_edited.emit()
	queue_free()

func _on_cancel_pressed() -> void:
	cancelled.emit()
	queue_free()

func _on_close_requested() -> void:
	cancelled.emit()
	queue_free()

