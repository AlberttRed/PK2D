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
var waitTime:float = 0.0:
		set(wait):
				waitInput = (wait == 0.0)
				waitTime = wait
var waitInput:bool = true
var closeAtEnd:bool = true
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
	await showMessage(text)

func show_input(text: String):
	await show_custom(text, {
		"waitInput": true,
		"closeAtEnd": true,
		"waitTime": 0.0
	})

func show_wait(text: String, wait_time: float):
	await show_custom(text, {
		"waitInput": false,
		"closeAtEnd": true,
		"waitTime": wait_time
	})

func show_no_close(text: String):
	await show_custom(text, {
		"waitInput": true,
		"closeAtEnd": false,
		"waitTime": 0.0
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
	#GUI.accept.connect(selectOption)
	#GUI.cancel.connect(cancelOption)
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
			close()
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
				close()
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
		assert("Invalid message for MessageBox")

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
	if messageHasFinished and isLastMessage:
		if waitTime > 0.0:
			await get_tree().create_timer(waitTime).timeout
		finishedAllText.emit()
		
func showMessage(message = null):
	if message!=null:
		addMessage(message)
	label.text = getNextMessage()
	$next.hide()
	self.show()
	await startText()
	await finished
		
func close():
	if closeAtEnd:
		hide()
	finished.emit()
	
func clear():
	disable_input_handling()
	#if GUI.accept.is_connected(selectOption):
		#GUI.accept.disconnect(selectOption)
	#GUI.cancel.disconnect(cancelOption)
	if label.line_displayed.is_connected(newLine):
		label.line_displayed.disconnect(newLine)
	if finsihedTyping.is_connected(_finishedMessage):
		finsihedTyping.disconnect(_finishedMessage)
	#$AnimationPlayer.animation_finished.disconnect(_finishedMessage)
	SignalManager.disconnectAll(finishedAllText)
	if finished.is_connected(onFinish):
		finished.disconnect(onFinish)
	waitTime = 0.0
	messageTextList.clear()
	closeAtEnd = true
	waitInput = true
	_stop = false
	actualMessageIndex = 0
	
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
	if not GUI.accept.is_connected(Callable(self, "selectOption")):
		GUI.accept.connect(Callable(self, "selectOption"))
	if not GUI.cancel.is_connected(Callable(self, "cancelOption")):
		GUI.cancel.connect(Callable(self, "cancelOption"))

func disable_input_handling():
	if GUI.accept.is_connected(Callable(self, "selectOption")):
		GUI.accept.disconnect(Callable(self, "selectOption"))
	if GUI.cancel.is_connected(Callable(self, "cancelOption")):
		GUI.cancel.disconnect(Callable(self, "cancelOption"))
