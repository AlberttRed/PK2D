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
	hide()

## Abre el menú de pausa
func open() -> void:
	if visible:
		return

	selected_index = 0

	# Limpiar opciones previas
	_clear_options()

	# Crear labels para cada opción
	for i in range(menu_options.size()):
		var label = _create_label_hgss(menu_options[i])
		label.name = "Option" + str(i)
		options_container.add_child(label)

	# Ajustar tamaño del panel según número de opciones (esto también ajusta la posición)
	_adjust_panel_size()

	# Mostrar el panel
	show()
	# La pausa se manejará automáticamente por DisplayManager cuando detecte que el menú está visible

	# Posicionar cursor
	_update_cursor_position()

	# Habilitar input
	_enable_input()

	# Bloquear control del jugador
	_block_player_control()

## Cierra el menú de pausa
func close() -> void:
	if not visible:
		return

	# Deshabilitar input
	_disable_input()

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
	for option_text in menu_options:
		# Usar get_string_size para obtener el ancho real del texto
		var text_size = font.get_string_size(option_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		if text_size.x > max_text_width:
			max_text_width = text_size.x

	# Ancho total = texto más largo + márgenes (34 + 24 = 58)
	# El cursor ya está dentro del margen izquierdo, no necesita espacio extra
	var calculated_width = max_text_width + 58

	# Altura: base 28 + (34px por opción)
	var calculated_height = 28 + (menu_options.size() * 34)

	# Actualizar el tamaño del panel
	custom_minimum_size = Vector2(calculated_width, calculated_height)
	size = custom_minimum_size

	# Ajustar offsets para que crezca hacia abajo manteniendo la posición Y fija
	# Mantener la posición superior fija (y:0) y crecer hacia abajo
	# Con anchors anclados a la derecha (anchor_left=1.0, anchor_right=1.0):
	# offset_left y offset_right son relativos al borde derecho
	# Posición fija: x:358 (desde izquierda) = offset_left = -154 (desde derecha)
	# Posición fija: y:0 (desde arriba) = offset_top = 0
	offset_left = -154.0  # Posición x:358 desde la izquierda
	offset_top = 0.0      # Posición y:0 desde arriba (fija)
	offset_right = -154.0 + calculated_width  # Ancho dinámico
	offset_bottom = calculated_height   # Altura dinámica (crece hacia abajo)

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
