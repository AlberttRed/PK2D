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

var typingSpeed:float = 5
var _stop:bool = false

var messageTextList: Array[String] = []
var actualMessageIndex: int = 0
var waitTime:float = 0.0
var waitInput:bool = true
var closeAtEnd:bool = true
var showIconAtEnd:bool = false  ## Si true, muestra el icono "next" al final aunque no haya más mensajes (batalla)
var _is_processing_message: bool = false  ## Flag para evitar race conditions
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
	pass
	#waitInput = true
	##waitTime = 2.0
	#showMessage("Esta es la primera línea
#Esta es la segunda línea
#Esta es la tercera línea
#Esta es la cuarta línea")

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
	label.visible_characters = 0
	#$AnimationPlayer.animation_finished.connect(_finishedMessage)
	if !waitInput:#waitTime > 0.0:
		finishedAllText.connect(close)
	#if !closeAtEnd:
		#finishedAllText.connect(func(): finished.emit())
	
	#$AnimationPlayer.play("Typing")
	await writeText()
	
func selectOption(): #(ui_accept)
	print("selected")
	
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
	updateScroll(32*(label.actualLine-2), 32*(label.actualLine-1))
	$AnimationPlayer2.play("Scroll")
	await $AnimationPlayer2.animation_finished
	
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
		$AnimationPlayer2.play("Idle")
		
func showMessage(message = null):
	_is_processing_message = true
	
	if message!=null:
		addMessage(message)
	label.text = getNextMessage()
	$AnimationPlayer2.stop()
	$next.hide()
	self.show()
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
	if not SignalManager.messagebox_input_accept.is_connected(Callable(self, "selectOption")):
		SignalManager.messagebox_input_accept.connect(Callable(self, "selectOption"))
	if not SignalManager.messagebox_input_cancel.is_connected(Callable(self, "cancelOption")):
		SignalManager.messagebox_input_cancel.connect(Callable(self, "cancelOption"))

func disable_input_handling():
	if SignalManager.messagebox_input_accept.is_connected(Callable(self, "selectOption")):
		SignalManager.messagebox_input_accept.disconnect(Callable(self, "selectOption"))
	if SignalManager.messagebox_input_cancel.is_connected(Callable(self, "cancelOption")):
		SignalManager.messagebox_input_cancel.disconnect(Callable(self, "cancelOption"))
