extends Panel

class_name PauseMenu

## PauseMenu - Menú de pausa del Overworld estilo FireRed/LeafGreen
## Muestra las opciones principales: Pokémon, Bolsa, Pokédex, Guardar, Opciones, Salir

# Señales para cada opción del menú
signal pokedex_requested()
signal party_requested()
signal bag_requested()
signal player_requested()
signal save_requested()
signal options_requested()
signal exit_requested()
signal menu_closed()

## Índice de la opción actualmente seleccionada
var selected_index: int = 0

## Array de opciones del menú
var menu_options: Array[String] = [
	"POKéDEX",
	"POKéMON",
	"MOCHILA",
	"PLAYER",
	"GUARDAR",
	"OPCIONES",
	"SALIR"
]

## Referencias a los nodos
@onready var options_container: VBoxContainer = $MarginContainer/OptionsContainer
@onready var cursor: Sprite2D = $Cursor

## Padding bajo la última opción (dentro del panel), además del margin_bottom del MarginContainer.
const PANEL_EXTRA_BOTTOM_MARGIN := 4.0


## Flag para evitar múltiples inputs
var _input_enabled: bool = false

## Posición base del panel (guardada al inicio para mantener la posición configurada)
var _base_offset_left: float = 0
var _base_offset_top: float = 0
var _base_offset_right: float = 0

func _ready() -> void:
	# Configurar para que continúe procesando aunque el árbol esté pausado
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Guardar los offsets configurados en la escena
	# Posición fija: x:358 (offset_left = -154 desde anchor_right=1.0), y:0
	_base_offset_left = offset_left
	_base_offset_top = offset_top
	_base_offset_right = offset_right
	# Que el VBox no estire las filas hasta llenar un panel alto provisional (evita size.y enorme al medir).
	options_container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hide()

## Abre el menú de pausa
func open(initial_index: int = -1) -> void:
	if visible:
		return

	if initial_index >= 0 and initial_index < menu_options.size():
		selected_index = initial_index
	else:
		selected_index = 0

	# Limpiar opciones previas
	_clear_options()

	# Crear labels para cada opción
	for i in range(menu_options.size()):
		var label = _create_label_hgss(menu_options[i])
		label.name = "Option" + str(i)
		options_container.add_child(label)

	# Ancho + altura provisional (el RTL real suele medir más que 34px/fila tras Godot 4.x / LabelHGSS)
	_apply_panel_width_and_provisional_height()

	# Visible para que el layout de RTL/fit_content sea fiable; alpha 0 evita el flash de altura provisional.
	modulate.a = 0.0
	show()

	await get_tree().process_frame
	await get_tree().process_frame

	_fit_panel_height_to_content()
	_update_cursor_position()

	modulate.a = 1.0
	_enable_input()
	_block_player_control()

## Cierra el menú de pausa
func close() -> void:
	if not visible:
		return

	# Deshabilitar input
	_disable_input()

	modulate.a = 1.0
	# Ocultar el panel
	hide()
	# La reanudación se manejará automáticamente por DisplayManager cuando detecte que el menú está oculto

	# Desbloquear control del jugador
	_unblock_player_control()

	# Emitir señal de cierre
	menu_closed.emit()

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
	# Menús lista: menos desajuste respecto al rect del Control que spacing_top del MessageBox.
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

func _measure_menu_max_text_width() -> float:
	var max_text_width := 0.0
	var font := load("res://Resources/UI/Fonts/Raw Fonts/pkmnhgss.ttf") as Font
	var font_size := 26
	for option_text in menu_options:
		var text_size := font.get_string_size(option_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		max_text_width = maxf(max_text_width, text_size.x)
	return max_text_width


## Ancho final + altura provisional (suficiente para que el VBox pueda resolver fit_content antes de medir).
func _apply_panel_width_and_provisional_height() -> void:
	var calculated_width := _measure_menu_max_text_width() + 58.0
	var mc := $MarginContainer as MarginContainer
	var mt := float(mc.get_theme_constant("margin_top"))
	var mb := float(mc.get_theme_constant("margin_bottom"))
	# Estimación holgada por fila (tras cambios de métricas RTL / fuente).
	var provisional_row := 44.0
	var provisional_height := mt + mb + float(menu_options.size()) * provisional_row

	custom_minimum_size = Vector2(calculated_width, provisional_height)
	size = custom_minimum_size
	offset_left = -154.0
	offset_top = 0.0
	offset_right = -154.0 + calculated_width
	offset_bottom = provisional_height


## Alto del bloque de opciones: suma de filas (no `VBox.size.y`: al panel ser alto provisional el VBox estira y el hueco cuenta como margen inferior).
func _options_stack_content_height() -> float:
	var sep := float(options_container.get_theme_constant("separation"))
	var kids := options_container.get_children()
	var sum_h := 0.0
	for child in kids:
		var ctl := child as Control
		if ctl:
			# size.y puede ser el reparto estirado del VBox; el mínimo combina mejor el alto intrínseco del RTL.
			var h: float = ctl.get_combined_minimum_size().y
			if h < 1.0:
				h = ctl.size.y
			sum_h += h
	var n := kids.size()
	if n > 1:
		sum_h += sep * float(n - 1)
	return sum_h


## Ajusta la altura del panel al contenido real (márgenes + pila de filas).
func _fit_panel_height_to_content() -> void:
	if options_container.get_child_count() == 0:
		return
	var mc := $MarginContainer as MarginContainer
	var mt := float(mc.get_theme_constant("margin_top"))
	var mb := float(mc.get_theme_constant("margin_bottom"))
	var inner_h := _options_stack_content_height()
	var total_h := mt + mb + inner_h + PANEL_EXTRA_BOTTOM_MARGIN

	custom_minimum_size.y = total_h
	size.y = total_h
	offset_bottom = total_h


## Cursor en X fijo; Y al centro vertical de la fila seleccionada (coordenadas locales del Panel).
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
		selected_index = menu_options.size() - 1
	_update_cursor_position()
	_play_cursor_sound()

## Navega hacia abajo en las opciones
func _navigate_down() -> void:
	selected_index += 1
	if selected_index >= menu_options.size():
		selected_index = 0
	_update_cursor_position()
	_play_cursor_sound()

## Confirma la selección actual
func _confirm_selection() -> void:
	_play_select_sound()

	# Emitir la señal correspondiente según la opción seleccionada
	match selected_index:
		0:  # POKéDEX
			pokedex_requested.emit()
		1:  # POKéMON
			party_requested.emit()
		2:  # MOCHILA
			bag_requested.emit()
		3:  # PLAYER
			player_requested.emit()
		4:  # GUARDAR
			save_requested.emit()
		5:  # OPCIONES
			options_requested.emit()
		6:  # SALIR
			exit_requested.emit()
			close()

	# Por ahora, no cerramos el menú al seleccionar (excepto SALIR)
	# Esto permitirá implementar los submenús más adelante

## Cancela la selección (cierra el menú)
func _cancel_selection() -> void:
	_play_cancel_sound()
	close()

## Habilita el manejo de input
func _enable_input() -> void:
	_input_enabled = true
	var dm := DisplayManager.instance
	if not dm:
		push_error("PauseMenu: DisplayManager no disponible para gestionar input")
		return
	dm.input_up.connect(_on_input_up)
	dm.input_down.connect(_on_input_down)
	dm.input_accept.connect(_on_input_accept)
	dm.input_cancel.connect(_on_input_cancel)
	dm.input_start.connect(_on_input_start)

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
	if dm.input_start.is_connected(_on_input_start):
		dm.input_start.disconnect(_on_input_start)

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

func _on_input_start() -> void:
	if _input_enabled:
		_cancel_selection()

## Bloquea el control del jugador
func _block_player_control() -> void:
	var dm := DisplayManager.instance
	if dm:
		dm.player_control_blocked.emit()

## Desbloquea el control del jugador
func _unblock_player_control() -> void:
	var dm := DisplayManager.instance
	if dm:
		dm.player_control_unblocked.emit()

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
