extends Panel

class_name MessageBox

signal resume
signal finsihedTyping
signal finishedMessage
signal finishedAllText
signal finished

enum {YES, NO}

@onready var label:RichTextLabel = $ScrollContainer/Container/LabelHGSS
@onready var label2:RichTextLabel = $ScrollContainer/Container/LabelHGSS/Outline
@onready var label3:RichTextLabel = $ScrollContainer/Container/LabelHGSS/Outline2
@onready var scroll:ScrollContainer = $ScrollContainer
@onready var container: Control = $ScrollContainer/Container
@onready var wait_indicator: Sprite2D = $next  ## El indicador de espera (flecha)
@onready var animation_player: AnimationPlayer = $AnimationPlayer2  ## El AnimationPlayer para el indicador

var typingSpeed:float = 5
var _stop:bool = false

var messageTextList: Array[String] = []
var actualMessageIndex: int = 0
var waitTime:float = 0.0
var waitInput:bool = true
var closeAtEnd:bool = true
var showIconAtEnd:bool = false  ## Si true, muestra el icono "next" al final aunque no haya más mensajes (batalla)
var _is_processing_message: bool = false  ## Flag para evitar race conditions
var _is_scrolling: bool = false  ## Flag para indicar si se está haciendo scroll
var _current_theme: MessageBoxTheme = null  ## Tema actualmente aplicado
var typing:bool:
	get:
		return label.visible_ratio > 0 and is_physics_processing()# $AnimationPlayer.is_playing() and $AnimationPlayer.current_animation == "Typing"

var messageHasFinished:bool:
	get:
		return label.messageHasFinished

var isLastMessage:bool:
	get:
		return messageTextList.is_empty() or actualMessageIndex == messageTextList.size()

# Called when the node entzers the scene tree for the first time.
func _ready():
	setText("")

#func _physics_process(delta: float) -> void:
	#if label.visible_ratio < 1:
		#label.visible_ratio += 0.1 * (label.get_total_character_count()/100.0) * delta
	#else:
		#set_physics_process(false)
		#finsihedTyping.emit()
func setText(_text):
	label.text = _text

func show_custom(text: String, config := {}):
	waitInput = config.get("waitInput", true)
	closeAtEnd = config.get("closeAtEnd", true)
	waitTime = config.get("waitTime", 0.0)
	showIconAtEnd = config.get("showIconAtEnd", false)

	# Aplicar tema si se especifica un estilo de marco
	if config.has("frameStyle"):
		var frame_style = config.get("frameStyle")
		if frame_style is int:
			set_frame_style(frame_style as MessageBoxFrameStyle.Values)
		elif frame_style is MessageBoxFrameStyle.Values:
			set_frame_style(frame_style)

	await showMessage(text)

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

	# Actualizar el WaitIndicator
	_update_wait_indicator(messagebox_theme)

## Actualiza el WaitIndicator según el tema
## @param messagebox_theme: El MessageBoxTheme con la configuración del indicador
func _update_wait_indicator(messagebox_theme: MessageBoxTheme) -> void:
	if not wait_indicator:
		return

	# Aplicar textura si está definida
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

	# Obtener el último carácter visible
	var visible_chars = label.visible_characters
	if visible_chars <= 0:
		visible_chars = label.get_total_character_count()

	if visible_chars <= 0:
		return

	# Obtener la línea del último carácter visible (0-indexed)
	var last_char_line = label.get_character_line(visible_chars - 1)

	# Obtener el contenido del texto original
	var original_text = label.text

	# Contar cuántos caracteres de BBCode hay al inicio (antes del contenido real)
	var bbcode_chars = 0
	if original_text.begins_with("[left]"):
		bbcode_chars = 6
	elif original_text.begins_with("[center]"):
		bbcode_chars = 8
	elif original_text.begins_with("[right]"):
		bbcode_chars = 7

	# Ajustar visible_chars para excluir el BBCode al inicio
	var adjusted_visible_chars = visible_chars
	if adjusted_visible_chars > bbcode_chars:
		adjusted_visible_chars -= bbcode_chars
	else:
		adjusted_visible_chars = 0

	# Obtener el contenido del texto sin BBCode para calcular el ancho
	var text_content = original_text
	# Remover BBCode básico (simplificado) - hacerlo ANTES de dividir en líneas
	text_content = text_content.replace("[left]", "").replace("[center]", "").replace("[right]", "")

	# Obtener la fuente y tamaño para calcular el ancho del texto
	var font = label.get_theme_font("normal_font")
	var font_size = label.get_theme_font_size("normal_font_size")
	if not font:
		# Fallback: usar fuente por defecto
		font = label.get("theme_override_fonts/normal_font")
		if not font:
			font = label.get("default_font")

	if not font:
		push_warning("MessageBox: No se pudo obtener la fuente para calcular posición INLINE")
		return

	# Encontrar el primer carácter de la línea actual usando get_character_line()
	# get_character_line() usa índices del texto original (con BBCode)
	# Iterar desde bbcode_chars (inicio del contenido real) hasta visible_chars
	var first_char_of_line_original = visible_chars  # Inicializar con el último carácter visible
	for i in range(bbcode_chars, visible_chars):
		if label.get_character_line(i) == last_char_line:
			first_char_of_line_original = i
			break

	# Calcular cuántos caracteres visibles hay en esta línea visual (en el texto original)
	var chars_in_line_original = visible_chars - first_char_of_line_original
	if chars_in_line_original < 0:
		chars_in_line_original = 0

	# Obtener el texto desde el primer carácter de la línea hasta el último carácter visible
	var target_line_text = ""
	if first_char_of_line_original < original_text.length() and visible_chars <= original_text.length():
		var line_text_with_bbcode = original_text.substr(first_char_of_line_original, chars_in_line_original)
		# Remover BBCode del texto de la línea
		target_line_text = line_text_with_bbcode.replace("[left]", "").replace("[center]", "").replace("[right]", "")
	elif first_char_of_line_original < original_text.length():
		var line_text_with_bbcode = original_text.substr(first_char_of_line_original, visible_chars - first_char_of_line_original)
		target_line_text = line_text_with_bbcode.replace("[left]", "").replace("[center]", "").replace("[right]", "")

	# Calcular el ancho del texto visible de la línea actual (solo esta línea)
	var text_width = 0.0
	if target_line_text.length() > 0:
		text_width = font.get_string_size(target_line_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

	# Calcular posición Y: basada en la línea del último carácter visible
	var line_height = 32.0
	var scroll_pos = scroll.position
	var scroll_offset = scroll.scroll_vertical  # Considerar el scroll vertical
	var indicator_height = wait_indicator.texture.get_height() if wait_indicator.texture else 16

	# Posición Y: parte superior del ScrollContainer + altura de la línea - scroll offset + centrado vertical
	var last_line_y = scroll_pos.y + (last_char_line * line_height) - scroll_offset + (line_height / 2.0) - (indicator_height / 2.0) + 10

	# Calcular posición X: inicio del área de texto + ancho del texto hasta el último carácter visible de la línea
	var text_margin_left = 32  # Margen izquierdo del ScrollContainer
	var text_start_x = scroll_pos.x + text_margin_left
	var text_end_x = text_start_x + text_width - 16  # Ajuste para posicionar correctamente

	wait_indicator.position = Vector2(text_end_x, last_line_y) + messagebox_theme.wait_indicator_offset

## Cambia el estilo de marco del MessageBox (método legacy, ahora usa temas)
## @param style: El estilo de marco (MessageBoxFrameStyle.Values)
func set_frame_style(style: MessageBoxFrameStyle.Values) -> void:
	var messagebox_theme = MessageBoxFrameStyle.get_messagebox_theme(style)
	apply_theme(messagebox_theme)
	print("MessageBox: Tema aplicado - %s" % MessageBoxFrameStyle.get_display_name(style))

func writeText():
	set_physics_process(true)
	while label.visible_characters < label.get_total_character_count():
		if _stop:
			_stop = false
			return
		label.visible_characters += 1
		await get_tree().create_timer(typingSpeed/100.0).timeout
	finsihedTyping.emit()


func startText():
	enable_input_handling()
	label.line_displayed.connect(newLine)
	finsihedTyping.connect(_finishedMessage)
	finished.connect(onFinish)

	# Asegurar scroll en 0 antes de empezar
	scroll.scroll_vertical = 0

	label.visible_characters = 0

	# Esperar frame y resetear scroll de nuevo por si algo lo cambió
	await get_tree().process_frame
	scroll.scroll_vertical = 0

	#$AnimationPlayer.animation_finished.connect(_finishedMessage)
	if !waitInput:#waitTime > 0.0:
		finishedAllText.connect(close)
	#if !closeAtEnd:
		#finishedAllText.connect(func(): finished.emit())

	#$AnimationPlayer.play("Typing")
	await writeText()

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
				close()
			elif not isLastMessage:
				# closeAtEnd = false y hay más mensajes → Continuar al siguiente
				resumeText()
			else:
				# closeAtEnd = false y es último mensaje → Finalizar sin cerrar
				_finish_without_closing()
	else:
		if typing:
			pass#SPEED UP TEXT
		else:
			if waitInput:
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
				close()
			elif not isLastMessage:
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
		label.text = getNextMessage()

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
	if waitInput:
		# Actualizar posición del indicador si está en modo INLINE
		if _current_theme and _current_theme.wait_indicator_mode == MessageBoxTheme.WaitIndicatorMode.INLINE_END_OF_TEXT:
			_update_wait_indicator_inline(_current_theme)
		$AnimationPlayer2.play("Idle")

func stopText():
		$AnimationPlayer.stop()

func newLine():
	if messageHasFinished:
		return

	if label.actualLine == label.nextLineStop:
		label.nextLineStop += 1
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
	updateScroll(scroll.scroll_vertical, 32*(label.actualLine-1))
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
	if should_show_arrow:
		# Actualizar posición del indicador si está en modo INLINE
		if _current_theme and _current_theme.wait_indicator_mode == MessageBoxTheme.WaitIndicatorMode.INLINE_END_OF_TEXT:
			_update_wait_indicator_inline(_current_theme)
		$AnimationPlayer2.play("Idle")

func showMessage(message = null):
	_is_processing_message = true

	if message!=null:
		addMessage(message)

	# Resetear scroll y estado del label para nuevo mensaje
	scroll.scroll_vertical = 0
	label.reset()
	label.nextLineStop = 2

	label.text = getNextMessage()
	# CRÍTICO: Establecer visible_characters a 0 inmediatamente para evitar que se vea el texto completo durante un frame
	label.visible_characters = 0
	$AnimationPlayer2.stop()
	$next.hide()
	self.show()

	# Esperar frame para que el layout se calcule y podamos obtener el número de líneas
	await get_tree().process_frame
	# Asegurar que visible_characters sigue en 0 después del frame (por si algo lo cambió)
	label.visible_characters = 0

	# Calcular y ajustar el tamaño del Container y los RichTextLabel según el número de líneas
	_adjust_container_size()

	# Forzar scroll a 0 después de ajustar el tamaño
	scroll.scroll_vertical = 0

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

	$AnimationPlayer2.stop()
	$next.hide()
	scroll.scroll_vertical = 0
	if closeAtEnd:
		hide()

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
	$AnimationPlayer2.stop()
	$next.hide()

	# Hacer limpieza completa (reutiliza código de clear)
	# Esto desconecta señales, resetea variables, marca _is_processing_message = false
	clear()

	# Restaurar contenido visual para que se mantenga visible
	label.text = current_text
	scroll.scroll_vertical = current_scroll_position

	# El await en showMessage() ya se desbloqueó porque clear() pone _is_processing_message = false


func clear():
	disable_input_handling()
	if label.line_displayed.is_connected(newLine):
		label.line_displayed.disconnect(newLine)
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
	_stop = false
	actualMessageIndex = 0
	_is_processing_message = false  ## CRÍTICO: Resetear flag

## Limpia y oculta el MessageBox (llamado después de una batalla)
func cleanup_and_hide() -> void:
	clear()
	hide()


func show_clear_text():
	label.text = ""
	show()

## Ajusta el tamaño del Container y los RichTextLabel según el número de líneas del texto
## Cada línea ocupa 32px (altura de línea + separación)
func _adjust_container_size() -> void:
	if not is_node_ready() or not container or not label:
		return

	# Obtener el número de líneas del texto
	var line_count = label.get_line_count()
	if line_count == 0:
		line_count = 1  # Mínimo 1 línea

	# Calcular la altura necesaria: 32px por línea
	var required_height = line_count * 32

	# Ajustar el tamaño del Container
	container.custom_minimum_size.y = required_height
	container.size.y = required_height

	# Ajustar el tamaño de los 3 RichTextLabel
	label.custom_minimum_size.y = required_height
	label.size.y = required_height

	label2.custom_minimum_size.y = required_height
	label2.size.y = required_height

	label3.custom_minimum_size.y = required_height
	label3.size.y = required_height

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
