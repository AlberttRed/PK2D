@tool
extends Window

## Ventana de edición para SetWeatherCommand
## Permite editar todas las propiedades export del comando

signal command_edited(command: SetWeatherCommand)
signal cancelled

var command: SetWeatherCommand = null

# Valores originales para poder cancelar
var original_weather_type: String = "none"

# Referencias a los controles
var weather_type_option: OptionButton = null
var accept_button: Button = null

func _ready() -> void:
	title = "Editar SetWeatherCommand"
	size = Vector2(400, 200)
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
	title_label.text = "Editar SetWeatherCommand"
	title_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title_label)
	vbox.add_child(HSeparator.new())

	# Weather Type
	var weather_container = HBoxContainer.new()
	var weather_label = Label.new()
	weather_label.text = "Tipo de clima:"
	weather_label.custom_minimum_size.x = 150
	weather_container.add_child(weather_label)

	weather_type_option = OptionButton.new()
	weather_type_option.add_item("Ninguno")
	weather_type_option.add_item("Lluvia")
	weather_type_option.add_item("Nieve")
	weather_type_option.add_item("Niebla")
	weather_type_option.add_item("Tormenta")
	weather_type_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weather_container.add_child(weather_type_option)
	vbox.add_child(weather_container)

	# Botones
	var buttons_container = HBoxContainer.new()
	buttons_container.alignment = BoxContainer.ALIGNMENT_END
	buttons_container.add_theme_constant_override("separation", 10)

	accept_button = Button.new()
	accept_button.text = "Aceptar"
	accept_button.pressed.connect(_on_accept_pressed)
	buttons_container.add_child(accept_button)

	var cancel_button = Button.new()
	cancel_button.text = "Cancelar"
	cancel_button.pressed.connect(_on_cancel_pressed)
	buttons_container.add_child(cancel_button)

	vbox.add_child(buttons_container)

## Carga un comando existente para editar
func load_command(cmd: SetWeatherCommand) -> void:
	if not cmd:
		push_error("SetWeatherCommandEditor: No se proporcionó un comando válido")
		return

	command = cmd

	# Guardar valores originales para poder cancelar
	original_weather_type = cmd.weather_type

	# Mapear el weather_type a índice del OptionButton
	var weather_index = _get_weather_index(cmd.weather_type)
	if weather_type_option:
		weather_type_option.selected = weather_index

## Obtiene el índice del OptionButton para un tipo de clima
func _get_weather_index(weather_type: String) -> int:
	match weather_type:
		"none":
			return 0
		"rain":
			return 1
		"snow":
			return 2
		"fog":
			return 3
		"storm":
			return 4
		_:
			return 0

## Obtiene el tipo de clima desde el índice del OptionButton
func _get_weather_type_from_index(index: int) -> String:
	match index:
		0:
			return "none"
		1:
			return "rain"
		2:
			return "snow"
		3:
			return "fog"
		4:
			return "storm"
		_:
			return "none"

## Aplica los valores editados al comando
func _apply_values_to_command() -> void:
	if not command:
		return

	if weather_type_option:
		var selected_index = weather_type_option.selected
		command.weather_type = _get_weather_type_from_index(selected_index)

## Restaura los valores originales del comando
func _restore_original_values() -> void:
	if not command:
		return

	command.weather_type = original_weather_type

	if weather_type_option:
		var weather_index = _get_weather_index(original_weather_type)
		weather_type_option.selected = weather_index

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

