extends Panel

class_name MessageBox

## Cómo revelar el texto al mostrar un mensaje (ver `typingMode` en `show_custom`).
enum TypingMode {
	TYPING,
	INSTANT,
}

signal resume
signal finsihedTyping
signal finishedMessage
signal finishedAllText
signal finished

enum {YES, NO}

@onready var label: Label = $ScrollContainer/Container/Body
@onready var scroll:ScrollContainer = $ScrollContainer
@onready var container: Control = $ScrollContainer/Container
@onready var wait_indicator: Sprite2D = $next  ## El indicador de espera (flecha)
@onready var animation_player: AnimationPlayer = $AnimationPlayer2  ## El AnimationPlayer para el indicador

signal line_displayed

var typingSpeed:float = 5
var _stop:bool = false
## Paginación HGSS (2 líneas visibles).
var actualLine: int = 0
var nextLineStop: int = 2
var lastLine: int = 0
## Mapa char_index → línea 1-based (rebuild al cambiar texto/ancho).
var _char_line_1based: PackedInt32Array = PackedInt32Array()
var _line_map_width: float = -1.0

var messageTextList: Array[String] = []
var actualMessageIndex: int = 0
var waitTime:float = 0.0
var waitInput:bool = true
var closeAtEnd:bool = true
var showIconAtEnd:bool = false  ## Si true, muestra el icono "next" al final aunque no haya más mensajes (batalla)
@export var play_open_sound_on_show: bool = true
## Si true, al confirmar un mensaje con closeAtEnd suena el accept (por defecto no).
var play_confirm_sound_on_close: bool = false
var _is_processing_message: bool = false  ## Flag para evitar race conditions
var _is_scrolling: bool = false  ## Flag para indicar si se está haciendo scroll
var _current_theme: MessageBoxTheme = null  ## Tema actualmente aplicado
var _typing_mode: TypingMode = TypingMode.TYPING
## Tras `writeText()` (texto ya visible: instant o último carácter). p. ej. revelar ChoiceBox a la par.
var _on_text_visible_ready: Callable = Callable()
## Si true, el panel crece en altura para mostrar todas las líneas (sin paginar a 2).
var _expand_height: bool = false
var _height_layout_saved: bool = false
var _saved_panel_min_size: Vector2 = Vector2.ZERO
var _saved_panel_size: Vector2 = Vector2.ZERO
var _saved_scroll_offset_bottom: float = 79.0
var _saved_panel_offset_top: float = 0.0
var _saved_panel_offset_bottom: float = 0.0
var _saved_grow_vertical: int = Control.GROW_DIRECTION_BEGIN
var _saved_panel_bottom_edge: float = -1.0
var _bag_dialog_text_layout_saved: bool = false
var _bag_dialog_saved_scroll: Dictionary = {}
var _bag_dialog_saved_rtl_states: Array[Dictionary] = []
var _bag_saved_container_min_size: Vector2 = Vector2.ZERO
## Valores iniciales del ScrollContainer de la escena (para restaurar márgenes cuando un tema usa −1).
var _scene_scroll_defaults: Dictionary = {}
var typing:bool:
	get:
		return label.visible_ratio > 0 and is_physics_processing()# $AnimationPlayer.is_playing() and $AnimationPlayer.current_animation == "Typing"

var messageHasFinished:bool:
	get:
		if label == null:
			return true
		var vc := label.visible_characters
		return vc < 0 or vc >= label.get_total_character_count()

var isLastMessage:bool:
	get:
		return messageTextList.is_empty() or actualMessageIndex == messageTextList.size()

# Called when the node entzers the scene tree for the first time.
func _ready():
	setText("")
	if wait_indicator:
		wait_indicator.visible = false
	if scroll != null:
		_scene_scroll_defaults = {
			"left": scroll.offset_left,
			"right": scroll.offset_right,
			"top": scroll.offset_top,
			"bottom": scroll.offset_bottom,
		}

#func _physics_process(delta: float) -> void:
	#if label.visible_ratio < 1:
		#label.visible_ratio += 0.1 * (label.get_total_character_count()/100.0) * delta
	#else:
		#set_physics_process(false)
		#finsihedTyping.emit()
func setText(_text):
	label.text = _strip_bbcode(str(_text))
	_rebuild_char_line_map()


func _strip_bbcode(s: String) -> String:
	var t := s.replace("[br]", "\n")
	for tag in ["[left]", "[center]", "[right]", "[/left]", "[/center]", "[/right]"]:
		t = t.replace(tag, "")
	return t


func _reset_line_state() -> void:
	lastLine = 0
	actualLine = 0
	nextLineStop = 2


func _set_visible_characters(value: int) -> void:
	if label == null:
		return
	label.visible_characters = value
	if value < 0:
		actualLine = maxi(1, label.get_line_count())
		line_displayed.emit()
		lastLine = actualLine
		return
	var total := label.get_total_character_count()
	if total <= 0:
		actualLine = 0
		return
	# Equivalente a get_character_line(vc)+1 / get_character_line(vc+1)+1
	actualLine = _line_at_char_index(value)
	var peek_line := _line_at_char_index(value + 1)
	if peek_line <= 0:
		peek_line = actualLine
	if messageHasFinished or peek_line != actualLine:
		line_displayed.emit()
		lastLine = actualLine


func _label_text_width() -> float:
	if label == null:
		return 433.0
	var width := label.size.x
	if width < 8.0:
		width = label.custom_minimum_size.x
	if width < 8.0 and scroll != null:
		width = scroll.offset_right - scroll.offset_left
	if width < 8.0:
		width = 433.0
	return width


func _label_font_and_size() -> Array:
	var font: Font = null
	var font_size := 26
	if label and label.label_settings:
		font = label.label_settings.font
		font_size = label.label_settings.font_size
	if font == null and label:
		font = label.get_theme_default_font()
	return [font, font_size]


## Reconstruye el mapa de líneas con TextParagraph (mismo wrap que Label).
func _rebuild_char_line_map() -> void:
	_char_line_1based = PackedInt32Array()
	_line_map_width = -1.0
	if label == null:
		return
	var full := label.text
	if full.is_empty():
		return
	var width := _label_text_width()
	var fs: Array = _label_font_and_size()
	var font: Font = fs[0]
	var font_size: int = int(fs[1])
	if font == null:
		# Fallback: solo saltos duros.
		var line := 1
		_char_line_1based.resize(full.length())
		for i in range(full.length()):
			_char_line_1based[i] = line
			if full[i] == "\n":
				line += 1
		_line_map_width = width
		return

	var paragraph := TextParagraph.new()
	paragraph.break_flags = (
		TextServer.BREAK_MANDATORY
		| TextServer.BREAK_WORD_BOUND
		| TextServer.BREAK_ADAPTIVE
	)
	paragraph.add_string(full, font, font_size)
	paragraph.width = width
	var line_count := paragraph.get_line_count()
	_char_line_1based.resize(full.length())
	for i in range(full.length()):
		_char_line_1based[i] = 1
	for line_i in range(line_count):
		var rng: Vector2i = paragraph.get_line_range(line_i)
		var from_i: int = clampi(rng.x, 0, full.length())
		var to_i: int = clampi(rng.y, 0, full.length())
		for c in range(from_i, to_i):
			_char_line_1based[c] = line_i + 1
	# Caracteres tras el último rango (p. ej. '\n' final): heredar última línea.
	var last_line := maxi(1, line_count)
	for c in range(full.length()):
		if _char_line_1based[c] <= 0:
			_char_line_1based[c] = last_line
	_line_map_width = width


func _ensure_char_line_map() -> void:
	if label == null:
		return
	var width := _label_text_width()
	if _char_line_1based.is_empty() or absf(width - _line_map_width) > 0.5:
		_rebuild_char_line_map()


## Equivalente a RichTextLabel.get_character_line(index) + 1.
func _line_at_char_index(char_index: int) -> int:
	if label == null or char_index < 0:
		return 0
	_ensure_char_line_map()
	if _char_line_1based.is_empty():
		return 0
	if char_index >= _char_line_1based.size():
		# Past end: misma línea que el último carácter (como next_line==0 → actualLine).
		return int(_char_line_1based[_char_line_1based.size() - 1])
	return int(_char_line_1based[char_index])


func _label_line_height() -> float:
	if label == null:
		return 32.0
	var h := float(label.get_line_height())
	if h > 1.0:
		return h
	return 32.0


func _label_content_height() -> float:
	if label == null:
		return 0.0
	var lc := maxi(1, label.get_line_count())
	return float(lc) * _label_line_height()

## Sustituye el texto visible de golpe (sin typing ni wait). Útil para ayudas de menú.
func set_help_text_instant(text: String) -> void:
	hide_wait_indicator()
	setText(text)
	if label:
		_set_visible_characters(-1)
	if not visible:
		show()
	_adjust_container_size()

## Para la animación Idle (fuerza visible=true) y oculta el indicador.
func hide_wait_indicator() -> void:
	if animation_player and animation_player.is_playing():
		animation_player.stop()
	if wait_indicator:
		wait_indicator.visible = false
		wait_indicator.hide()
	elif has_node("next"):
		$next.hide()

func show_custom(text: String, config := {}):
	waitInput = config.get("waitInput", true)
	closeAtEnd = config.get("closeAtEnd", true)
	waitTime = config.get("waitTime", 0.0)
	showIconAtEnd = config.get("showIconAtEnd", false)
	_expand_height = bool(config.get("expandHeight", false))

	var tm: Variant = config.get("typingMode", TypingMode.TYPING)
	if tm is TypingMode:
		_typing_mode = tm
	elif tm is int:
		_typing_mode = clampi(tm, 0, TypingMode.INSTANT) as TypingMode
	elif tm is String:
		match String(tm).strip_edges().to_lower():
			"instant":
				_typing_mode = TypingMode.INSTANT
			_:
				_typing_mode = TypingMode.TYPING
	else:
		_typing_mode = TypingMode.TYPING

	# Solo aplicar tema si viene en config: si no, se conserva el marco definido en la escena (p. ej. batalla).
	if "frameStyle" in config:
		var frame_style_val: Variant = config["frameStyle"]
		if frame_style_val is int:
			set_frame_style(frame_style_val as MessageBoxFrameStyle.Values)
		elif frame_style_val is MessageBoxFrameStyle.Values:
			set_frame_style(frame_style_val)

	var cb: Variant = config.get("onTextVisibleReady", Callable())
	_on_text_visible_ready = cb if cb is Callable else Callable()

	var prev_open_sound := play_open_sound_on_show
	if "playOpenSound" in config:
		play_open_sound_on_show = bool(config["playOpenSound"])
	elif "play_open_sound" in config:
		play_open_sound_on_show = bool(config["play_open_sound"])

	var prev_confirm_sound := play_confirm_sound_on_close
	if "playConfirmSound" in config:
		play_confirm_sound_on_close = bool(config["playConfirmSound"])
	elif "play_confirm_sound" in config:
		play_confirm_sound_on_close = bool(config["play_confirm_sound"])
	else:
		play_confirm_sound_on_close = false

	await showMessage(text)

	play_open_sound_on_show = prev_open_sound
	play_confirm_sound_on_close = prev_confirm_sound
	_on_text_visible_ready = Callable()

func show_input(text: String, show_icon_at_end: bool = false):
	await show_custom(text, {
		"waitInput": true,
		"closeAtEnd": false,
		"waitTime": 0.0,
		"showIconAtEnd": show_icon_at_end
	})

func show_wait(text: String, wait_time: float):
	await show_custom(text, {
		"waitInput": false,
		"closeAtEnd": true,
		"waitTime": wait_time,
		"showIconAtEnd": false
	})

##	Muestra un mensaje sin cerrar el messagebox, útil para mantener el texto visible durante animaciones
func show_display(text: String, wait_time: float):
	await show_custom(text, {
		"waitInput": false,
		"closeAtEnd": false,
		"waitTime": wait_time,
		"showIconAtEnd": false
	})

func show_no_close(text: String, show_icon_at_end: bool = false):
	await show_custom(text, {
		"waitInput": true,
		"closeAtEnd": false,
		"waitTime": 0.0,
		"showIconAtEnd": show_icon_at_end
	})

## Aplica un tema completo al MessageBox
## @param messagebox_theme: El MessageBoxTheme a aplicar
func apply_theme(messagebox_theme: MessageBoxTheme) -> void:
	if not messagebox_theme:
		push_error("MessageBox: No se puede aplicar un tema nulo")
		return

	# Guardar el tema actual
	_current_theme = messagebox_theme

	# Aplicar el StyleBox al panel
	if messagebox_theme.frame_stylebox:
		add_theme_stylebox_override("panel", messagebox_theme.frame_stylebox)

	_apply_scroll_margins_from_theme(messagebox_theme)

	# Actualizar el WaitIndicator
	_update_wait_indicator(messagebox_theme)


func _apply_scroll_margins_from_theme(messagebox_theme: MessageBoxTheme) -> void:
	if scroll == null or messagebox_theme == null:
		return
	if _scene_scroll_defaults.is_empty():
		_scene_scroll_defaults = {
			"left": scroll.offset_left,
			"right": scroll.offset_right,
			"top": scroll.offset_top,
			"bottom": scroll.offset_bottom,
		}
	var dl: float = messagebox_theme.content_margin_left
	var dr: float = messagebox_theme.content_margin_right
	var dt: float = messagebox_theme.content_margin_top
	var db: float = messagebox_theme.content_margin_bottom
	if dl < 0.0:
		dl = float(_scene_scroll_defaults.get("left", 32.0))
	if dr < 0.0:
		dr = float(_scene_scroll_defaults.get("right", 465.0))
	if dt < 0.0:
		dt = float(_scene_scroll_defaults.get("top", 16.0))
	if db < 0.0:
		db = float(_scene_scroll_defaults.get("bottom", 79.0))
	scroll.offset_left = dl
	scroll.offset_right = dr
	scroll.offset_top = dt
	scroll.offset_bottom = db
	fit_scroll_width_to_panel()


## Si el panel es más estrecho que el MSG a pantalla completa, ajusta offset_right del scroll.
func fit_scroll_width_to_panel() -> void:
	if scroll == null:
		return
	var panel_w: float = size.x
	if panel_w < 8.0:
		panel_w = custom_minimum_size.x
	if panel_w < 8.0:
		return
	var left_m: float = scroll.offset_left
	var scene_right: float = float(_scene_scroll_defaults.get("right", 465.0)) if not _scene_scroll_defaults.is_empty() else 465.0
	# En escena 512px, offset_right=465 → inset ~47 (hueco para marco/indicador a pantalla completa).
	var full_right_inset: float = maxf(16.0, 512.0 - scene_right)
	# En paneles estrechos (PC/caja) ese inset deja poco texto útil y fuerza wraps prematuros.
	var right_inset: float = full_right_inset
	if panel_w < 480.0:
		right_inset = maxf(left_m, 16.0)
	var max_right: float = panel_w - right_inset
	if max_right <= left_m + 8.0:
		max_right = panel_w - 16.0
	scroll.offset_right = max_right
	_sync_text_container_width_to_scroll()


## Ancho útil del Label según offsets actuales del ScrollContainer (tema o escena).
func _sync_text_container_width_to_scroll() -> void:
	if _bag_dialog_text_layout_saved:
		_bag_apply_inner_text_width()
		return
	if scroll == null or container == null or label == null:
		return
	var inner_w: float = maxf(1.0, scroll.offset_right - scroll.offset_left)
	container.custom_minimum_size.x = inner_w
	label.offset_left = 0.0
	label.offset_right = inner_w
	label.custom_minimum_size.x = inner_w
	label.queue_redraw()
	_rebuild_char_line_map()

## Actualiza el WaitIndicator según el tema
## @param messagebox_theme: El MessageBoxTheme con la configuración del indicador
## NOTA: Este método solo CONFIGURA el wait indicator, no controla su visibilidad.
## La visibilidad se controla en pauseText() y _finishedMessage() según waitInput y showIconAtEnd
func _update_wait_indicator(messagebox_theme: MessageBoxTheme) -> void:
	if not wait_indicator:
		return

	# Aplicar textura si está definida (si no hay textura, el wait indicator no se mostrará)
	if messagebox_theme.wait_indicator_texture:
		wait_indicator.texture = messagebox_theme.wait_indicator_texture

		# Configurar posicionamiento según el modo
		match messagebox_theme.wait_indicator_mode:
			MessageBoxTheme.WaitIndicatorMode.BOTTOM_RIGHT:
				# Posición fija en esquina inferior derecha
				wait_indicator.position = Vector2(491, 69) + messagebox_theme.wait_indicator_offset

			MessageBoxTheme.WaitIndicatorMode.INLINE_END_OF_TEXT:
				# Posición al final del texto visible (dentro del área de texto)
				# Calcular posición basada en el texto visible
				_update_wait_indicator_inline(messagebox_theme)

		# Aplicar velocidad de animación al AnimationPlayer2
		if animation_player:
			animation_player.speed_scale = messagebox_theme.wait_indicator_blink_speed

## Actualiza la posición del WaitIndicator en modo INLINE_END_OF_TEXT
## @param messagebox_theme: El MessageBoxTheme con la configuración
func _update_wait_indicator_inline(messagebox_theme: MessageBoxTheme) -> void:
	if not wait_indicator or not label:
		return

	var visible_chars: int = label.visible_characters
	if visible_chars <= 0:
		visible_chars = label.get_total_character_count()
	if visible_chars <= 0:
		return

	var original_text := label.text
	var last_char_line := maxi(0, _line_at_char_index(visible_chars - 1) - 1)

	var font: Font = null
	var font_size := 26
	var settings := label.label_settings
	if settings:
		font = settings.font
		font_size = settings.font_size
	if font == null:
		font = label.get_theme_default_font()
	if font == null:
		push_warning("MessageBox: No se pudo obtener la fuente para calcular posición INLINE")
		return

	var first_char_of_line: int = visible_chars
	for i in range(visible_chars):
		if _line_at_char_index(i) - 1 == last_char_line:
			first_char_of_line = i
			break

	var chars_in_line: int = maxi(0, visible_chars - first_char_of_line)
	var target_line_text := ""
	if first_char_of_line < original_text.length():
		target_line_text = original_text.substr(first_char_of_line, chars_in_line)

	var text_width := 0.0
	if target_line_text.length() > 0:
		text_width = font.get_string_size(target_line_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

	var line_height := _label_line_height()
	var scroll_pos = scroll.position
	var scroll_offset = scroll.scroll_vertical
	var indicator_height = wait_indicator.texture.get_height() if wait_indicator.texture else 16
	var last_line_y = scroll_pos.y + (last_char_line * line_height) - scroll_offset + (line_height / 2.0) - (indicator_height / 2.0) + 10
	var text_margin_left: int = int(round(scroll.offset_left))
	var text_start_x = scroll_pos.x + text_margin_left
	var text_end_x = text_start_x + text_width - 16
	wait_indicator.position = Vector2(text_end_x, last_line_y) + messagebox_theme.wait_indicator_offset


## Fuerza el ancho real del área de texto al interior del ScrollContainer.
func _bag_apply_inner_text_width() -> void:
	if not _bag_dialog_text_layout_saved:
		return
	if scroll == null or container == null or label == null:
		return
	var inner_w: float = maxf(1.0, scroll.offset_right - scroll.offset_left)
	container.custom_minimum_size.x = inner_w
	label.offset_left = 0.0
	label.offset_right = inner_w
	label.custom_minimum_size.x = inner_w
	label.queue_redraw()
	_rebuild_char_line_map()

## Layout de texto para diálogo estrecho (p. ej. mochila): margen izquierdo 16 y mitad de ancho útil + autowrap.
func apply_bag_dialog_text_layout(enabled: bool) -> void:
	if enabled:
		if _bag_dialog_text_layout_saved or not is_node_ready():
			return
		_bag_saved_container_min_size = container.custom_minimum_size
		_bag_dialog_saved_scroll = {
			"left": scroll.offset_left,
			"right": scroll.offset_right,
			"top": scroll.offset_top,
			"bottom": scroll.offset_bottom,
		}
		var content_w: float = scroll.offset_right - scroll.offset_left
		var half_content_w: float = round(content_w / 2.0)
		scroll.offset_left = 16.0
		scroll.offset_right = 16.0 + half_content_w

		_bag_dialog_saved_rtl_states.clear()
		_bag_dialog_saved_rtl_states.append({
			"autowrap_mode": label.autowrap_mode,
			"offset_left": label.offset_left,
			"offset_right": label.offset_right,
			"custom_minimum_size": label.custom_minimum_size,
		})
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

		_bag_dialog_text_layout_saved = true
		_bag_apply_inner_text_width()
	else:
		if not _bag_dialog_text_layout_saved:
			return
		scroll.offset_left = float(_bag_dialog_saved_scroll.get("left", 32.0))
		scroll.offset_right = float(_bag_dialog_saved_scroll.get("right", 465.0))
		scroll.offset_top = float(_bag_dialog_saved_scroll.get("top", 16.0))
		scroll.offset_bottom = float(_bag_dialog_saved_scroll.get("bottom", 79.0))

		container.custom_minimum_size = _bag_saved_container_min_size

		if not _bag_dialog_saved_rtl_states.is_empty():
			var entry: Dictionary = _bag_dialog_saved_rtl_states[0]
			label.autowrap_mode = entry["autowrap_mode"] as TextServer.AutowrapMode
			label.offset_left = float(entry.get("offset_left", 0.0))
			label.offset_right = float(entry.get("offset_right", 433.0))
			label.custom_minimum_size = entry["custom_minimum_size"] as Vector2

		_bag_dialog_saved_rtl_states.clear()
		_bag_dialog_text_layout_saved = false

## Cambia el estilo de marco del MessageBox (método legacy, ahora usa temas)
## @param style: El estilo de marco (MessageBoxFrameStyle.Values)
func set_frame_style(style: MessageBoxFrameStyle.Values) -> void:
	var messagebox_theme = MessageBoxFrameStyle.get_messagebox_theme(style)
	apply_theme(messagebox_theme)
	print("MessageBox: Tema aplicado - %s" % MessageBoxFrameStyle.get_display_name(style))

func writeText():
	set_physics_process(true)
	if _typing_mode == TypingMode.INSTANT:
		_set_visible_characters(-1)
		set_physics_process(false)
		finsihedTyping.emit()
		return
	while label.visible_characters >= 0 and label.visible_characters < label.get_total_character_count():
		if _stop:
			_stop = false
			return
		_set_visible_characters(label.visible_characters + 1)
		await get_tree().create_timer(typingSpeed/100.0).timeout
	finsihedTyping.emit()


func startText():
	enable_input_handling()
	_connect_once(line_displayed, Callable(self, "newLine"))
	_connect_once(finsihedTyping, Callable(self, "_finishedMessage"))
	_connect_once(finished, Callable(self, "onFinish"))

	# Asegurar scroll en 0 antes de empezar
	scroll.scroll_vertical = 0

	_set_visible_characters(0)

	# Esperar frame y resetear scroll de nuevo por si algo lo cambió
	await get_tree().process_frame
	scroll.scroll_vertical = 0

	#$AnimationPlayer.animation_finished.connect(_finishedMessage)
	if !waitInput:#waitTime > 0.0:
		_connect_once(finishedAllText, Callable(self, "close"))
	#if !closeAtEnd:
		#finishedAllText.connect(func(): finished.emit())

	#$AnimationPlayer.play("Typing")
	await writeText()

	if _on_text_visible_ready.is_valid():
		var cb := _on_text_visible_ready
		_on_text_visible_ready = Callable()
		cb.call()

## Sonido al avanzar texto/mensaje (no al cerrar). Basado en estado, no en la flecha visible.
func _should_play_continue_sound_on_accept() -> bool:
	if not waitInput:
		return false
	# Cerrar el cuadro → sin sonido
	if messageHasFinished and closeAtEnd:
		return false
	# Último mensaje sin cerrar (closeAtEnd=false) → sin sonido
	if messageHasFinished and isLastMessage:
		return false
	return true


func _play_message_continue_sound() -> void:
	if _should_play_continue_sound_on_accept():
		AudioManager.play_ui_select()

func selectOption(): #(ui_accept)
	print("selected")

	# Ignorar input si se está haciendo scroll
	if _is_scrolling:
		return

	if messageHasFinished:
		if waitInput:
			# Lógica de cierre:
			if closeAtEnd:
				# closeAtEnd = true → Siempre cerrar
				if play_confirm_sound_on_close:
					AudioManager.play_ui_select()
				close()
			elif not isLastMessage:
				# closeAtEnd = false y hay más mensajes → Continuar al siguiente
				_play_message_continue_sound()
				resumeText()
			else:
				# closeAtEnd = false y es último mensaje → Finalizar sin cerrar
				_finish_without_closing()
	else:
		if typing:
			pass#SPEED UP TEXT
		else:
			if waitInput:
				_play_message_continue_sound()
				resumeText()

func cancelOption(): #(ui_cancel)
	print("cancel")

	# Ignorar input si se está haciendo scroll
	if _is_scrolling:
		return

	if messageHasFinished:
		if waitInput:
			# Lógica de cierre (igual que selectOption):
			if closeAtEnd:
				if play_confirm_sound_on_close:
					AudioManager.play_ui_select()
				close()
			elif not isLastMessage:
				_play_message_continue_sound()
				resumeText()
			else:
				# closeAtEnd = false y es último mensaje → Finalizar sin cerrar
				_finish_without_closing()
	else:
		if typing:
			pass#SPEED UP TEXT

func resumeText():
	$AnimationPlayer2.stop()
	$next.hide()
	if !messageHasFinished :
		await scrollText()
	elif messageHasFinished and !isLastMessage:
		_reset_line_state()
		nextLineStop = 2
		setText(getNextMessage())
		_set_visible_characters(0)
		scroll.scroll_vertical = 0
		_adjust_container_size()

	writeText()
	#$AnimationPlayer.play("Typing")
	resume.emit()

func pauseText():
	set_physics_process(false)
	_stop = true
	#$AnimationPlayer.pause()
	# Mostrar icono "next" en pausas intermedias (saltos de línea) SIEMPRE si waitInput
	# (porque hay más texto por mostrar del mensaje actual)
	# closeAtEnd NO afecta aquí - las pausas intermedias siempre muestran icono
	if waitInput and wait_indicator:
		# Solo mostrar si hay textura configurada en el tema
		if _current_theme and _current_theme.wait_indicator_texture:
			wait_indicator.visible = true
			# Actualizar posición del indicador si está en modo INLINE
			if _current_theme.wait_indicator_mode == MessageBoxTheme.WaitIndicatorMode.INLINE_END_OF_TEXT:
				_update_wait_indicator_inline(_current_theme)
			$AnimationPlayer2.play("Idle")
		else:
			wait_indicator.visible = false

func stopText():
		$AnimationPlayer.stop()

func newLine():
	if messageHasFinished:
		return

	if actualLine == nextLineStop:
		nextLineStop += 1
		pauseText()
		if !waitInput:
			resumeText()

func addMessage(message):
	if message is String:
		messageTextList.push_back(message)
	elif message is Array[String]:
		for m:String in message:
			messageTextList.push_back(m)
	else:
		push_error("MessageBox: Tipo de mensaje inválido. Se esperaba String o Array[String]")

func scrollText():
	_is_scrolling = true
	await get_tree().process_frame
	var line_idx: int = maxi(0, actualLine - 1)
	var target_scroll: int = int(round(_label_line_height() * float(line_idx)))
	var vs: VScrollBar = scroll.get_v_scroll_bar()
	if vs:
		target_scroll = clampi(target_scroll, 0, int(ceil(vs.max_value)))
	updateScroll(scroll.scroll_vertical, target_scroll)
	$AnimationPlayer2.play("Scroll")
	await $AnimationPlayer2.animation_finished
	_is_scrolling = false

	# Actualizar posición del indicador después del scroll si está en modo INLINE
	if _current_theme and _current_theme.wait_indicator_mode == MessageBoxTheme.WaitIndicatorMode.INLINE_END_OF_TEXT:
		_update_wait_indicator_inline(_current_theme)

func getNextMessage():
	var nextMessage:String = messageTextList[actualMessageIndex]
	actualMessageIndex += 1
	return nextMessage

func _finishedMessage():
	finishedMessage.emit()

	# Guardar los valores ANTES de que se puedan resetear por las señales
	# Lógica del icono "next":
	# - Si showIconAtEnd = false (overworld): Solo mostrar si hay más mensajes por procesar
	# - Si showIconAtEnd = true (batalla): Siempre mostrar al final
	var should_show_arrow = false
	if waitInput and messageHasFinished and isLastMessage:
		if showIconAtEnd:
			# Modo batalla: Siempre mostrar el icono al final
			should_show_arrow = true
		else:
			# Modo overworld: Solo mostrar si hay más mensajes pendientes por procesar
			should_show_arrow = actualMessageIndex < messageTextList.size()

	await get_tree().process_frame

	if messageHasFinished and isLastMessage:
		if waitTime > 0.0:
			await get_tree().create_timer(waitTime).timeout
		finishedAllText.emit()

	# Mostrar la flecha "next" si estamos esperando input del usuario
	if should_show_arrow and wait_indicator:
		# Solo mostrar si hay textura configurada en el tema
		if _current_theme and _current_theme.wait_indicator_texture:
			wait_indicator.visible = true
			# Actualizar posición del indicador si está en modo INLINE
			if _current_theme.wait_indicator_mode == MessageBoxTheme.WaitIndicatorMode.INLINE_END_OF_TEXT:
				_update_wait_indicator_inline(_current_theme)
			$AnimationPlayer2.play("Idle")
		else:
			hide_wait_indicator()
	else:
		hide_wait_indicator()

func showMessage(message = null):
	_is_processing_message = true

	if message!=null:
		addMessage(message)

	# Resetear scroll y estado del label para nuevo mensaje
	scroll.scroll_vertical = 0
	_reset_line_state()
	nextLineStop = 2

	setText(getNextMessage())
	# CRÍTICO: Establecer visible_characters a 0 inmediatamente para evitar que se vea el texto completo durante un frame
	_set_visible_characters(0)
	hide_wait_indicator()

	if _expand_height:
		# Layout invisible: medir y crecer antes de revelar (evita el salto).
		modulate.a = 0.0
		show()
		_set_visible_characters(-1)
		await get_tree().process_frame
		await get_tree().process_frame
		_fit_panel_height_to_all_lines()
		_set_visible_characters(0)
		scroll.scroll_vertical = 0
		modulate.a = 1.0
	else:
		_restore_panel_height_if_needed()
		show()
		await get_tree().process_frame
		_set_visible_characters(0)
		_adjust_container_size()
		scroll.scroll_vertical = 0

	if play_open_sound_on_show:
		AudioManager.play_ui_select()

	await startText()

	# CRÍTICO: En lugar de await finished (que puede perderse),
	# usar polling del flag
	while _is_processing_message:
		await get_tree().process_frame

	print("MessageBox.showMessage: Completado")

func close():
	# Si ya no está procesando, no hacer nada (ya se cerró)
	if not _is_processing_message:
		print("MessageBox.close(): Ya estaba cerrado, ignorando")
		return

	print("MessageBox.close(): Cerrando...")

	# Deshabilitar input para evitar múltiples llamadas
	disable_input_handling()

	hide_wait_indicator()
	scroll.scroll_vertical = 0
	if closeAtEnd:
		hide()
		_restore_panel_height_if_needed()

	# CRÍTICO: Marcar como no procesando ANTES de emitir finished
	_is_processing_message = false

	finished.emit()

	print("MessageBox.close(): Cerrado y señal emitida")

	# Si closeAtEnd = false, mantener el input deshabilitado para evitar reiniciar
	# El input se rehabilitará solo cuando se muestre un nuevo mensaje


## Finaliza el mensaje sin cerrar ni limpiar (para mantener visible con closeAtEnd=false)
func _finish_without_closing() -> void:
	if not _is_processing_message:
		return

	# Guardar estado visual antes de limpiar
	var current_scroll_position = scroll.scroll_vertical
	var current_text = label.text

	# Ocultar icono next
	hide_wait_indicator()

	# Hacer limpieza completa (reutiliza código de clear)
	# Esto desconecta señales, resetea variables, marca _is_processing_message = false
	clear()

	# Restaurar contenido visual para que se mantenga visible
	label.text = current_text
	_set_visible_characters(-1)
	scroll.scroll_vertical = current_scroll_position

	# El await en showMessage() ya se desbloqueó porque clear() pone _is_processing_message = false


func clear():
	disable_input_handling()
	if line_displayed.is_connected(newLine):
		line_displayed.disconnect(newLine)
	if finsihedTyping.is_connected(_finishedMessage):
		finsihedTyping.disconnect(_finishedMessage)
	#$AnimationPlayer.animation_finished.disconnect(_finishedMessage)
	if finishedAllText.is_connected(close):
		finishedAllText.disconnect(close)
	#SignalManager.disconnectAll(finishedAllText)
	if finished.is_connected(onFinish):
		finished.disconnect(onFinish)
	scroll.scroll_vertical = 0
	waitTime = 0.0
	messageTextList.clear()
	closeAtEnd = true
	waitInput = true
	showIconAtEnd = false  # Resetear a valor por defecto
	_typing_mode = TypingMode.TYPING
	_stop = false
	actualMessageIndex = 0
	_is_processing_message = false  ## CRÍTICO: Resetear flag
	_on_text_visible_ready = Callable()
	_expand_height = false
	# No restaurar altura aquí: con closeAtEnd=false el texto sigue visible
	# y recuperaría el alto de 2 líneas. Se restaura al ocultar o en el siguiente mensaje.
	modulate.a = 1.0

## Limpia y oculta el MessageBox (llamado después de una batalla)
func cleanup_and_hide() -> void:
	clear()
	_restore_panel_height_if_needed()
	hide()


func show_clear_text():
	label.text = ""
	if wait_indicator:
		wait_indicator.visible = false
	if animation_player:
		animation_player.stop()
	show()

## Ajusta el tamaño del Container y el Label según el texto real.
func _adjust_container_size() -> void:
	if not is_node_ready() or not container or not label:
		return

	var line_count: int = label.get_line_count()
	if line_count <= 0:
		line_count = 1

	var required_height: int = ceili(_label_content_height())
	if required_height < 12:
		required_height = int(round(float(line_count) * _label_line_height()))

	container.custom_minimum_size.y = required_height
	container.size.y = required_height

	label.custom_minimum_size.y = required_height
	label.size.y = required_height

	_bag_apply_inner_text_width()


## Crece el panel hacia arriba para mostrar todas las líneas (p. ej. INFO. de objetos).
func _fit_panel_height_to_all_lines() -> void:
	if not is_node_ready() or scroll == null or label == null:
		return
	if not _height_layout_saved:
		_saved_panel_min_size = custom_minimum_size
		_saved_panel_size = size
		_saved_scroll_offset_bottom = scroll.offset_bottom
		_saved_panel_offset_top = offset_top
		_saved_panel_offset_bottom = offset_bottom
		_saved_grow_vertical = grow_vertical
		_saved_panel_bottom_edge = position.y + size.y
		_height_layout_saved = true

	_adjust_container_size()
	var line_count: int = maxi(1, label.get_line_count())
	# Sin paginar: todas las líneas visibles de golpe.
	nextLineStop = maxi(line_count, 1)

	var content_h: float = _label_content_height()
	if content_h < 8.0:
		content_h = float(line_count) * _label_line_height()
	content_h = maxf(content_h, container.custom_minimum_size.y)

	var top_m: float = scroll.offset_top
	var default_h: float = _saved_panel_min_size.y if _saved_panel_min_size.y > 0.0 else 96.0
	var bottom_m: float = maxf(8.0, default_h - _saved_scroll_offset_bottom)
	var new_panel_h: float = top_m + content_h + bottom_m
	var new_scroll_bottom: float = new_panel_h - bottom_m

	scroll.offset_bottom = new_scroll_bottom
	_set_panel_height_pinned_bottom(new_panel_h)


## Cambia el alto del panel manteniendo el borde inferior (encoge/crece hacia arriba).
func _set_panel_height_pinned_bottom(new_panel_h: float) -> void:
	var parent_h: float = size.y
	var parent_ctrl := get_parent() as Control
	if parent_ctrl != null:
		parent_h = parent_ctrl.size.y
	elif get_viewport() != null:
		parent_h = get_viewport().get_visible_rect().size.y

	var bottom_edge: float = _saved_panel_bottom_edge
	if bottom_edge < 0.0:
		bottom_edge = position.y + size.y
		_saved_panel_bottom_edge = bottom_edge

	var top_y: float = bottom_edge - new_panel_h
	custom_minimum_size.y = new_panel_h
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	# Offsets según anclas (bottom-wide o top-left absoluto).
	offset_top = top_y - anchor_top * parent_h
	offset_bottom = bottom_edge - anchor_bottom * parent_h
	size.y = new_panel_h
	# Reafirmar por si set_size movió el rect.
	offset_top = top_y - anchor_top * parent_h
	offset_bottom = bottom_edge - anchor_bottom * parent_h


func _restore_panel_height_if_needed() -> void:
	if not _height_layout_saved:
		return
	custom_minimum_size = _saved_panel_min_size
	size = _saved_panel_size
	offset_top = _saved_panel_offset_top
	offset_bottom = _saved_panel_offset_bottom
	grow_vertical = _saved_grow_vertical as Control.GrowDirection
	if scroll != null:
		scroll.offset_bottom = _saved_scroll_offset_bottom
	_saved_panel_bottom_edge = -1.0
	_height_layout_saved = false


## Restaura el alto por defecto del panel (p. ej. al cerrar desde DisplayManager).
func restore_expanded_height() -> void:
	_restore_panel_height_if_needed()

func updateScroll(startingPosition:int, finalPosition:int):
#### Sprite:position
	var animation: Animation = $AnimationPlayer2.get_animation("Scroll")
	var track_index = animation.find_track("../ScrollContainer:scroll_vertical", Animation.TYPE_VALUE)
	var key_id: int = animation.track_find_key(track_index, 0.0)
	animation.track_set_key_value(track_index, key_id, startingPosition)
	key_id = animation.track_find_key(track_index, 1.0)
	animation.track_set_key_value(track_index, key_id, finalPosition)

func onFinish():
	clear()

func _connect_once(signal_ref: Signal, callable_ref: Callable) -> void:
	if signal_ref.is_connected(callable_ref):
		return
	signal_ref.connect(callable_ref)

func enable_input_handling():
	var dm := DisplayManager.instance
	if not dm:
		push_error("MessageBox: DisplayManager no disponible para gestionar input")
		return
	if not dm.messagebox_input_accept.is_connected(Callable(self, "selectOption")):
		dm.messagebox_input_accept.connect(Callable(self, "selectOption"))
	if not dm.messagebox_input_cancel.is_connected(Callable(self, "cancelOption")):
		dm.messagebox_input_cancel.connect(Callable(self, "cancelOption"))

func disable_input_handling():
	var dm := DisplayManager.instance
	if not dm:
		return
	if dm.messagebox_input_accept.is_connected(Callable(self, "selectOption")):
		dm.messagebox_input_accept.disconnect(Callable(self, "selectOption"))
	if dm.messagebox_input_cancel.is_connected(Callable(self, "cancelOption")):
		dm.messagebox_input_cancel.disconnect(Callable(self, "cancelOption"))
