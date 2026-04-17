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

	# Ajustar tamaño del panel según número de opciones
	_adjust_panel_size()

	# Mostrar el panel
	show()

	# Posicionar cursor
	_update_cursor_position()

	# Habilitar input
	_enable_input()

	# Esperar a que el jugador seleccione
	var choice = await choice_made

	# Deshabilitar input
	_disable_input()

	# Esperar un frame para asegurar que el input se consuma antes de ocultar
	# Esto evita que el mismo input que se usó para seleccionar también active
	# interacciones del mundo (como SURF) cuando el ChoiceBox se oculta
	await get_tree().process_frame

	# Ocultar después de que el input se haya consumido
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
	font_variation.spacing_top = 4

	custom_theme.default_font = font_variation
	custom_theme.default_font_size = 26

	label.theme = custom_theme
	label.add_theme_color_override("default_color", Color(0.317647, 0.317647, 0.34902, 1))
	label.add_theme_color_override("font_shadow_color", Color(0.65098, 0.65098, 0.682353, 1))
	label.add_theme_constant_override("line_separation", 8)
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

## Ajusta el tamaño del panel según el número de opciones
func _adjust_panel_size() -> void:
	# Calcular el ancho real del texto más largo usando la fuente
	var max_text_width = 0

	# Cargar la fuente para medir el texto real
	var font = load("res://Resources/UI/Fonts/Raw Fonts/pkmnhgss.ttf")
	var font_size = 26

	# Calcular el ancho real del texto más largo
	for option_text in options:
		# Usar get_string_size para obtener el ancho real del texto
		var text_size = font.get_string_size(option_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		if text_size.x > max_text_width:
			max_text_width = text_size.x

	# Ancho total = texto más largo + márgenes (34 + 24 = 58)
	# El cursor ya está dentro del margen izquierdo, no necesita espacio extra
	var calculated_width = max_text_width + 58

	# Altura: base 28 + (34px por opción)
	var calculated_height = 28 + (options.size() * 34)

	# Actualizar el tamaño del panel
	custom_minimum_size = Vector2(calculated_width, calculated_height)
	size = custom_minimum_size

	if _fixed_top_left_mode:
		offset_left = _fixed_top_left.x
		offset_top = _fixed_top_left.y
		offset_right = _fixed_top_left.x + calculated_width
		offset_bottom = _fixed_top_left.y + calculated_height
		_base_offset_right = offset_right
		_base_offset_bottom = offset_bottom
	else:
		# Ajustar offsets para que crezca hacia arriba y hacia la izquierda
		# Mantener fijos los valores configurados en la escena
		offset_right = _base_offset_right
		offset_bottom = _base_offset_bottom
		offset_left = offset_right - calculated_width
		offset_top = offset_bottom - calculated_height

	# Forzar actualización del layout
	await get_tree().process_frame

## Actualiza la posición del cursor según la opción seleccionada
func _update_cursor_position() -> void:
	if options_container.get_child_count() == 0:
		return

	# Cursor siempre en X=24 (fijo desde el borde izquierdo)
	# Y = 30 (base) + 34 * índice de la opción (altura de cada opción)
	var cursor_x = 24
	var cursor_y = 30 + (selected_index * 34)
	cursor.position = Vector2(cursor_x, cursor_y)

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
