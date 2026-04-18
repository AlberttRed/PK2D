extends Panel

class_name ChoiceBox

## ChoiceBox - Sistema de selección de opciones para eventos
## Muestra una lista de opciones y permite al jugador navegar y seleccionar

signal choice_made(index: int)
signal choice_cancelled()

## Índice de la opción actualmente seleccionada
var selected_index: int = 0

## Array de opciones disponibles
var options: Array[String] = []

## Referencias a los nodos
@onready var options_container: VBoxContainer = $MarginContainer/OptionsContainer
@onready var cursor: Sprite2D = $Cursor

## Padding bajo la última opción (dentro del panel), además del margin_bottom del MarginContainer.
const PANEL_EXTRA_BOTTOM_MARGIN := 4.0

## Flag para evitar múltiples inputs
var _input_enabled: bool = false

## Posición base del panel (guardada al inicio para mantener la posición configurada)
var _base_offset_right: float = 0
var _base_offset_bottom: float = 0

## Si está activo, la esquina superior izquierda queda en `_fixed_top_left` (ancho/alto siguen calculándose).
var _fixed_top_left_mode: bool = false
var _fixed_top_left: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Guardar los offsets configurados en la escena
	_base_offset_right = offset_right
	_base_offset_bottom = offset_bottom
	options_container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hide()

## Ancla el panel por esquina superior izquierda (p. ej. mochila). Desactivar al volver al layout por defecto.
func set_fixed_top_left_position(enabled: bool, top_left: Vector2 = Vector2.ZERO) -> void:
	_fixed_top_left_mode = enabled
	_fixed_top_left = top_left
	if enabled:
		anchor_left = 0.0
		anchor_top = 0.0
		anchor_right = 0.0
		anchor_bottom = 0.0

## Muestra el ChoiceBox con las opciones especificadas
func show_choices(choice_options: Array[String]) -> int:
	if choice_options.is_empty():
		push_error("ChoiceBox: No se pueden mostrar opciones vacías")
		return -1

	# Limpiar opciones previas
	_clear_options()

	# Guardar opciones
	options = choice_options
	selected_index = 0

	# Crear labels para cada opción
	for i in range(options.size()):
		var label = _create_label_hgss(options[i])
		label.name = "Option" + str(i)
		options_container.add_child(label)

	_apply_panel_width_and_provisional_height()

	modulate.a = 0.0
	show()

	await get_tree().process_frame
	await get_tree().process_frame

	_fit_panel_height_to_content()
	_update_cursor_position()

	modulate.a = 1.0
	_enable_input()

	var choice = await choice_made

	# Deshabilitar input
	_disable_input()

	# Esperar un frame para asegurar que el input se consuma antes de ocultar
	# Esto evita que el mismo input que se usó para seleccionar también active
	# interacciones del mundo (como SURF) cuando el ChoiceBox se oculta
	await get_tree().process_frame

	# Ocultar después de que el input se haya consumido
	modulate.a = 1.0
	hide()

	return choice

## Crea un label con el estilo HGSS (3 capas de sombreado)
func _create_label_hgss(text: String) -> LabelHGSS:
	# Crear el label principal
	var label = LabelHGSS.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.custom_minimum_size = Vector2(0, 34)

	# Aplicar el mismo tema que el MessageBox
	var custom_theme = Theme.new()
	var font = load("res://Resources/UI/Fonts/Raw Fonts/pkmnhgss.ttf")
	var font_variation = FontVariation.new()
	font_variation.base_font = font
	font_variation.spacing_top = 0

	custom_theme.default_font = font_variation
	custom_theme.default_font_size = 26

	label.theme = custom_theme
	label.add_theme_color_override("default_color", Color(0.317647, 0.317647, 0.34902, 1))
	label.add_theme_color_override("font_shadow_color", Color(0.65098, 0.65098, 0.682353, 1))
	label.add_theme_constant_override("line_separation", 8)
	label.add_theme_constant_override("paragraph_separation", 0)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 0)

	# Crear las capas de outline (sombra)
	var outline1 = RichTextLabel.new()
	outline1.name = "Outline"
	outline1.bbcode_enabled = true
	outline1.fit_content = true
	outline1.scroll_active = false
	outline1.theme = custom_theme
	outline1.add_theme_color_override("default_color", Color(0.317647, 0.317647, 0.34902, 1))
	outline1.add_theme_color_override("font_shadow_color", Color(0.65098, 0.65098, 0.682353, 1))
	outline1.add_theme_constant_override("line_separation", 8)
	outline1.add_theme_constant_override("paragraph_separation", 0)
	outline1.add_theme_constant_override("shadow_offset_x", 0)
	outline1.add_theme_constant_override("shadow_offset_y", 2)

	var outline2 = RichTextLabel.new()
	outline2.name = "Outline2"
	outline2.bbcode_enabled = true
	outline2.fit_content = true
	outline2.scroll_active = false
	outline2.theme = custom_theme
	outline2.add_theme_color_override("default_color", Color(0.317647, 0.317647, 0.34902, 1))
	outline2.add_theme_color_override("font_shadow_color", Color(0.65098, 0.65098, 0.682353, 1))
	outline2.add_theme_constant_override("line_separation", 8)
	outline2.add_theme_constant_override("paragraph_separation", 0)
	outline2.add_theme_constant_override("shadow_offset_x", 2)
	outline2.add_theme_constant_override("shadow_offset_y", 2)

	# Agregar outlines como hijos del label principal
	label.add_child(outline1)
	label.add_child(outline2)

	# Establecer el texto (LabelHGSS lo sincroniza con los outlines)
	label.setText(text)

	return label

## Limpia las opciones del contenedor
func _clear_options() -> void:
	for child in options_container.get_children():
		child.queue_free()

func _measure_options_max_text_width() -> float:
	var max_text_width := 0.0
	var font := load("res://Resources/UI/Fonts/Raw Fonts/pkmnhgss.ttf") as Font
	for option_text in options:
		var text_size := font.get_string_size(option_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26)
		max_text_width = maxf(max_text_width, text_size.x)
	return max_text_width


func _apply_panel_width_and_provisional_height() -> void:
	var calculated_width := _measure_options_max_text_width() + 58.0
	var mc := $MarginContainer as MarginContainer
	var mt := float(mc.get_theme_constant("margin_top"))
	var mb := float(mc.get_theme_constant("margin_bottom"))
	var provisional_height := mt + mb + float(options.size()) * 44.0

	custom_minimum_size = Vector2(calculated_width, provisional_height)
	size = custom_minimum_size

	if _fixed_top_left_mode:
		offset_left = _fixed_top_left.x
		offset_top = _fixed_top_left.y
		offset_right = _fixed_top_left.x + calculated_width
		offset_bottom = _fixed_top_left.y + provisional_height
		_base_offset_right = offset_right
		_base_offset_bottom = offset_bottom
	else:
		offset_right = _base_offset_right
		offset_bottom = _base_offset_bottom
		offset_left = offset_right - calculated_width
		offset_top = offset_bottom - provisional_height


## Alto del bloque de opciones: suma de filas (no `VBox.size.y` cuando el panel es alto provisional: el VBox rellena y sobra banda blanca abajo).
func _options_stack_content_height() -> float:
	var sep := float(options_container.get_theme_constant("separation"))
	var kids := options_container.get_children()
	var sum_h := 0.0
	for child in kids:
		var ctl := child as Control
		if ctl:
			var h: float = ctl.get_combined_minimum_size().y
			if h < 1.0:
				h = ctl.size.y
			sum_h += h
	var n := kids.size()
	if n > 1:
		sum_h += sep * float(n - 1)
	return sum_h


func _fit_panel_height_to_content() -> void:
	if options_container.get_child_count() == 0:
		return
	var mc := $MarginContainer as MarginContainer
	var mt := float(mc.get_theme_constant("margin_top"))
	var mb := float(mc.get_theme_constant("margin_bottom"))
	var total_h := mt + mb + _options_stack_content_height() + PANEL_EXTRA_BOTTOM_MARGIN

	custom_minimum_size.y = total_h
	size.y = total_h

	if _fixed_top_left_mode:
		offset_left = _fixed_top_left.x
		offset_top = _fixed_top_left.y
		offset_right = _fixed_top_left.x + custom_minimum_size.x
		offset_bottom = _fixed_top_left.y + total_h
		_base_offset_right = offset_right
		_base_offset_bottom = offset_bottom
	else:
		offset_right = _base_offset_right
		offset_bottom = _base_offset_bottom
		offset_left = offset_right - custom_minimum_size.x
		offset_top = offset_bottom - total_h


func _update_cursor_position() -> void:
	if selected_index < 0 or selected_index >= options_container.get_child_count():
		return

	var row := options_container.get_child(selected_index) as Control
	var cursor_y := row.global_position.y + row.size.y * 0.5 - global_position.y + 2.0
	cursor.position = Vector2(24.0, cursor_y)

## Navega hacia arriba en las opciones
func _navigate_up() -> void:
	selected_index -= 1
	if selected_index < 0:
		selected_index = options.size() - 1
	_update_cursor_position()
	_play_cursor_sound()

## Navega hacia abajo en las opciones
func _navigate_down() -> void:
	selected_index += 1
	if selected_index >= options.size():
		selected_index = 0
	_update_cursor_position()
	_play_cursor_sound()

## Confirma la selección actual
func _confirm_selection() -> void:
	_play_select_sound()
	choice_made.emit(selected_index)

## Cancela la selección (opcional, emite -1)
func _cancel_selection() -> void:
	_play_cancel_sound()
	choice_cancelled.emit()
	choice_made.emit(-1)

## Habilita el manejo de input
func _enable_input() -> void:
	_input_enabled = true
	var dm := DisplayManager.instance
	if not dm:
		push_error("ChoiceBox: DisplayManager no disponible para gestionar input")
		return
	dm.input_up.connect(_on_input_up)
	dm.input_down.connect(_on_input_down)
	dm.input_accept.connect(_on_input_accept)
	dm.input_cancel.connect(_on_input_cancel)

## Deshabilita el manejo de input
func _disable_input() -> void:
	_input_enabled = false
	var dm := DisplayManager.instance
	if not dm:
		return
	if dm.input_up.is_connected(_on_input_up):
		dm.input_up.disconnect(_on_input_up)
	if dm.input_down.is_connected(_on_input_down):
		dm.input_down.disconnect(_on_input_down)
	if dm.input_accept.is_connected(_on_input_accept):
		dm.input_accept.disconnect(_on_input_accept)
	if dm.input_cancel.is_connected(_on_input_cancel):
		dm.input_cancel.disconnect(_on_input_cancel)

## Callbacks de input
func _on_input_up() -> void:
	if _input_enabled:
		_navigate_up()

func _on_input_down() -> void:
	if _input_enabled:
		_navigate_down()

func _on_input_accept() -> void:
	if _input_enabled:
		_confirm_selection()

func _on_input_cancel() -> void:
	if _input_enabled:
		_cancel_selection()

## Efectos de sonido (placeholder - implementar cuando haya sistema de audio)
func _play_cursor_sound() -> void:
	# TODO: Reproducir sonido de cursor
	pass

func _play_select_sound() -> void:
	# TODO: Reproducir sonido de selección
	pass

func _play_cancel_sound() -> void:
	# TODO: Reproducir sonido de cancelación
	pass
