extends Panel

class_name ChoiceBox

## ChoiceBox - Sistema de selección de opciones para eventos
## Muestra una lista de opciones y permite al jugador navegar y seleccionar

## Cómo se calcula la posición del panel al medir texto (viewport base diseño 512×384).
## SCENE_DEFAULT = mismo comportamiento que opciones desde evento / MessageBox (`_base_offset_*`).
enum ChoiceAnchor {
	SCENE_DEFAULT,
	TOP_LEFT,
	TOP_RIGHT,
	BOTTOM_LEFT,
	BOTTOM_RIGHT,
	PARTY_MENU,
	BAG_TOP_LEFT,
}

signal choice_made(index: int)
signal choice_cancelled()
signal selection_changed(index: int)

## Índice de la opción actualmente seleccionada
var selected_index: int = 0

## Array de opciones disponibles
var options: Array[String] = []

## Referencias a los nodos
@onready var options_container: VBoxContainer = $MarginContainer/OptionsContainer
@onready var cursor: Sprite2D = $Cursor

## Padding bajo la última opción (dentro del panel), además del margin_bottom del MarginContainer.
const PANEL_EXTRA_BOTTOM_MARGIN := 4.0

## Viewport de diseño HGSS sobre el que están calibrados los inset de ChoiceBox.tscn.
const DESIGN_VIEWPORT := Vector2(512.0, 384.0)
## Menú party: borde inferior del panel respecto al viewport (diseño 384px alto), escalado.
## Con ~12px el panel de 4 opciones quedaba con top ≈196; con 4px el borde superior cae ≈204 (viewport base).
const PARTY_MENU_BOTTOM_INSET := 4.0
## En `Scenes/UI/GUI.tscn` el ChoiceBox tiene offset_right = 0 (pegado al borde derecho del viewport), no el inset de ChoiceBox.tscn.
const CORNER_INSET_RIGHT := 4.0
const CORNER_INSET_BOTTOM := 4.0
const CORNER_INSET_LEFT := 0.0
const CORNER_INSET_TOP := 14.0

## Flag para evitar múltiples inputs
var _input_enabled: bool = false

## Posición base del panel (guardada al inicio para mantener la posición configurada)
var _base_offset_right: float = 0
var _base_offset_bottom: float = 0

var _anchor: ChoiceAnchor = ChoiceAnchor.SCENE_DEFAULT
## PARTY_MENU
var _party_right_edge_x: float = 0.0
var _party_bottom_y: float = 0.0
## BAG_TOP_LEFT
var _bag_top_left: Vector2 = Vector2.ZERO

## Sesión bolsa/diálogo: UI montada antes del mensaje; se revela en `MessageBox.onTextVisibleReady`.
var _coordinated_choice_session: bool = false
var _next_initial_index: int = 0

func _ready() -> void:
	# Guardar los offsets configurados en la escena
	_base_offset_right = offset_right
	_base_offset_bottom = offset_bottom
	options_container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hide()


func _scale_xy() -> Vector2:
	var vp := get_viewport().get_visible_rect().size
	return Vector2(vp.x / DESIGN_VIEWPORT.x, vp.y / DESIGN_VIEWPORT.y)


func _pin_to_canvas_origin_anchors() -> void:
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 0.0
	anchor_bottom = 0.0


## Menú party: borde derecho según diseño (no depender de position/size antes de medir filas).
func enter_party_menu_layout() -> void:
	_anchor = ChoiceAnchor.PARTY_MENU
	_pin_to_canvas_origin_anchors()
	var s := _scale_xy()
	var vp := get_viewport().get_visible_rect().size
	_party_bottom_y = vp.y - PARTY_MENU_BOTTOM_INSET * s.y
	_party_right_edge_x = vp.x


func exit_party_menu_layout() -> void:
	_anchor = ChoiceAnchor.SCENE_DEFAULT


func enter_bag_top_left_layout(top_left: Vector2) -> void:
	_anchor = ChoiceAnchor.BAG_TOP_LEFT
	_bag_top_left = top_left
	_pin_to_canvas_origin_anchors()


func exit_bag_top_left_layout() -> void:
	_anchor = ChoiceAnchor.SCENE_DEFAULT


## Esquinas genéricas del viewport (el panel crece hacia el interior desde la esquina elegida).
func set_corner_anchor(preset: ChoiceAnchor) -> void:
	if preset == ChoiceAnchor.SCENE_DEFAULT:
		clear_corner_anchor()
		return
	if preset == ChoiceAnchor.PARTY_MENU or preset == ChoiceAnchor.BAG_TOP_LEFT:
		push_warning("ChoiceBox.set_corner_anchor: usar enter_party_menu_layout() o enter_bag_top_left_layout().")
		return
	_anchor = preset
	_pin_to_canvas_origin_anchors()


func clear_corner_anchor() -> void:
	_anchor = ChoiceAnchor.SCENE_DEFAULT


## Compatibilidad: mochila usa esquina superior izquierda fija.
func set_fixed_top_left_position(enabled: bool, top_left: Vector2 = Vector2.ZERO) -> void:
	if enabled:
		enter_bag_top_left_layout(top_left)
	else:
		exit_bag_top_left_layout()


func _apply_sized_panel_layout(panel_width: float, panel_height: float) -> void:
	var vp := get_viewport().get_visible_rect().size
	var s := _scale_xy()
	match _anchor:
		ChoiceAnchor.SCENE_DEFAULT:
			offset_right = _base_offset_right
			offset_bottom = _base_offset_bottom
			offset_left = offset_right - panel_width
			offset_top = offset_bottom - panel_height
		ChoiceAnchor.PARTY_MENU:
			offset_bottom = _party_bottom_y
			offset_top = _party_bottom_y - panel_height
			offset_right = _party_right_edge_x
			offset_left = _party_right_edge_x - panel_width
		ChoiceAnchor.BAG_TOP_LEFT:
			offset_left = _bag_top_left.x
			offset_right = _bag_top_left.x + panel_width
			offset_top = _bag_top_left.y
			offset_bottom = _bag_top_left.y + panel_height
		ChoiceAnchor.TOP_LEFT:
			var ml := CORNER_INSET_LEFT * s.x
			var mt := CORNER_INSET_TOP * s.y
			offset_left = ml
			offset_right = ml + panel_width
			offset_top = mt
			offset_bottom = mt + panel_height
		ChoiceAnchor.TOP_RIGHT:
			var mr := CORNER_INSET_RIGHT * s.x
			var mt := CORNER_INSET_TOP * s.y
			offset_right = vp.x - mr
			offset_left = offset_right - panel_width
			offset_top = mt
			offset_bottom = mt + panel_height
		ChoiceAnchor.BOTTOM_LEFT:
			var ml := CORNER_INSET_LEFT * s.x
			var mb := CORNER_INSET_BOTTOM * s.y
			offset_left = ml
			offset_right = ml + panel_width
			offset_bottom = vp.y - mb
			offset_top = offset_bottom - panel_height
		ChoiceAnchor.BOTTOM_RIGHT:
			var mr := CORNER_INSET_RIGHT * s.x
			var mb := CORNER_INSET_BOTTOM * s.y
			offset_right = vp.x - mr
			offset_left = offset_right - panel_width
			offset_bottom = vp.y - mb
			offset_top = offset_bottom - panel_height
	_base_offset_right = offset_right
	_base_offset_bottom = offset_bottom

## Muestra el ChoiceBox con las opciones especificadas
func show_choices(choice_options: Array[String]) -> int:
	if not _setup_choice_rows(choice_options):
		push_error("ChoiceBox: No se pueden mostrar opciones vacías")
		return -1

	modulate.a = 0.0
	show()

	await get_tree().process_frame
	await get_tree().process_frame

	_fit_panel_height_to_content()
	_update_cursor_position()

	modulate.a = 1.0
	_enable_input()

	return await _complete_choice_session()


## Monta filas y tamaño provisional; invisible hasta el callback del MessageBox (misma aparición que el texto).
func begin_coordinated_choice(choice_options: Array[String]) -> void:
	if not _setup_choice_rows(choice_options):
		push_error("ChoiceBox: begin_coordinated_choice con opciones vacías")
		return
	_coordinated_choice_session = true
	modulate.a = 0.0
	show()


## Llamar desde `show_custom(..., { "onTextVisibleReady": ... })` cuando el texto ya es visible.
func reveal_when_coordinated_message_visible() -> void:
	if not _coordinated_choice_session:
		return
	_fit_panel_height_to_content()
	_update_cursor_position()
	modulate.a = 1.0
	_enable_input()


func await_coordinated_choice_result() -> int:
	if not _coordinated_choice_session:
		return -1
	var idx := await _complete_choice_session()
	_coordinated_choice_session = false
	return idx


func _setup_choice_rows(choice_options: Array[String]) -> bool:
	if choice_options.is_empty():
		return false
	_clear_options()
	options = choice_options
	selected_index = clampi(_next_initial_index, 0, options.size() - 1)
	_next_initial_index = 0
	for i in range(options.size()):
		var row := _create_label_hgss(options[i])
		row.name = "Option" + str(i)
		options_container.add_child(row)
	_apply_panel_width_and_provisional_height()
	selection_changed.emit(selected_index)
	return true


func set_next_initial_index(index: int) -> void:
	_next_initial_index = maxi(index, 0)


func _complete_choice_session() -> int:
	var choice = await choice_made
	_disable_input()
	await get_tree().process_frame
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

	_apply_sized_panel_layout(calculated_width, provisional_height)


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

	_apply_sized_panel_layout(custom_minimum_size.x, total_h)


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
	selection_changed.emit(selected_index)
	_play_cursor_sound()

## Navega hacia abajo en las opciones
func _navigate_down() -> void:
	selected_index += 1
	if selected_index >= options.size():
		selected_index = 0
	_update_cursor_position()
	selection_changed.emit(selected_index)
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
	if not _input_enabled or not visible:
		return
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
