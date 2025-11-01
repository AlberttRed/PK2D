
extends CanvasLayer

signal input
signal selected_choice

var fading:bool = false
var next = false

#@onready var msg = MessageBox.new($MSG)
@onready var msg:MessageBox = $MSG
@onready var choice_box:ChoiceBox = $ChoiceBox
#onready var options = get_node("OPTIONS")
#@onready var menu = $MAIN_MENU
#@onready var battle:BattleUI = $BATTLE
@onready var BattleNew:BattleScene = $BattleNew
#@onready var choices:ChoicesContainer = $ChoicesContainer
#@onready var party:Party = $PARTY
#onready var bag = get_node("BAG")
#@onready var transition = $TRANSITION
#@onready var levelUp = $LEVELUP
@onready var fade_layer:ColorRect = $FadeLayer

var choices_options = null

func _ready():
	# Conectar señales del SignalManager
	SignalManager.message_requested.connect(_on_message_requested)
	SignalManager.messagebox_input_accept.connect(_on_messagebox_accept)
	SignalManager.messagebox_input_cancel.connect(_on_messagebox_cancel)
	SignalManager.battle_requested.connect(_on_battle_requested)
	SignalManager.battle_finished.connect(_on_battle_finished)
	SignalManager.hide_overworld_messagebox.connect(_on_hide_overworld_messagebox)

	# Conectar señales del MessageBox
	msg.finished.connect(_on_message_finished)
#	$INTRO.connect("continue", GAME_DATA, "load_game")
#	$INTRO.connect("new_game", GAME_DATA, "new_game")
#	add_user_signal("finished")
#	add_user_signal("input")
	#menu.pokemon.connect(showParty)
	#if name == "GUI":
		#showMessageYesNo("Esta es la primera línea
#Esta es la segunda línea
#Esta es la tercera línea
#Esta es la cuarta línea")#, 2.0)

#	menu.connect("save", self, "save")
#	menu.connect("bag", self, "show_bag")
#	options.connect("text_speed_changed", self, "_on_text_speed_changed")
	#msg.connect("input", self, "send_input")
#
#func _init():
#	get_node("MSG").Panel = CONST.Window_StyleBoxç
func setMessageBox(msgBox:MessageBox):
	if self.msg != null:
		self.msg.clear()
	msgBox.setText("")
	self.msg = msgBox

func resetMessageBox():
	if self.msg != null:
		self.msg.clear()
	self.msg = $MSG

func showMessageInput(text):
	self.msg.waitInput = true
	await self.msg.showMessage(text)

func showMessageWait(text, waitTime:float):
	msg.waitTime = waitTime
	await msg.showMessage(text)

func showMessageNoClose(text):
	msg.closeAtEnd = false
	await msg.showMessage(text)

#
#func showMessageYesNo(message:String, closeAtEnd:bool = true) -> int:
	#msg.closeAtEnd = false
	#msg.waitInput = false
	#if closeAtEnd:
		#select.connect(Callable(msg, "close"))
	#await msg.showMessage(message)
	#var selectedOption:int = await showChoices(["SI","NO"])
	#if closeAtEnd:
		#select.disconnect(Callable(msg, "close"))
	#else:
		#msg.setText("")
	#
	#return selectedOption

#func showPartyMoveSelection(pokemon:PokemonInstance, learningMove:MoveInstance):
	#var moveIndexSelected = await party.showMoveSelection(pokemon, learningMove)
	#return moveIndexSelected
	#

func showMsg(text : String, showIcon : bool = true, _waitTime : float = 0.0, waitInput:bool = false):
	msg.show_msgBattle(text, showIcon, _waitTime, waitInput)
	await msg.finished


func show_msg(text="", wait = null, obj = null, sig="", _choices_options = [], _close = true):
	msg.connect("finished", Callable(self, "close_msg"))
	choices_options = _choices_options
	var choices = []
	var close = _close
	if choices_options != [] and choices_options != null:
			choices = _choices_options[0]
			if choices != null and choices != []:
				close = false
				msg.disconnect("finished", Callable(self, "close_msg"))
				msg.connect("finished", Callable(self, "show_choices"))

	msg.show_msg(text,wait,obj,sig, close)#choices_options.size() == 0 or ((choices_options[0] == null or choices_options[0].size() == 0) and close == true))
#
#func show_choices():
	#for c in choices_options[0]:
		##print("add choice")
		#if !chs.has_user_signal(c):
			#chs.add_user_signal(c)
		#chs.connect(c, Callable(self, "add_choice_cmd"))
		#chs.add_choice(c)
#
	#chs.show_choices(choices_options[1], choices_options[2])
	#await chs.exit
	#chs.clear_choices()
	#msg.clear_msg()
	#
	#for c in choices_options[0]:
		#chs.disconnect(c, Callable(self, "add_choice_cmd"))
#
	#close_msg()
	#


func add_choice_cmd(c):
	selected_choice.emit(c)

func close_msg():
	if msg.is_connected("finished", Callable(self, "show_choices")):
		msg.disconnect("finished", Callable(self, "show_choices"))

	if msg.is_connected("finished", Callable(self, "close_msg")):
		msg.disconnect("finished", Callable(self, "close_msg"))
	input.emit()


#func show_options():
#	options.show()
#	options.set_process(true)
#	yield(options,"exit")
#	options.set_process(false)
#
func clear_msg():
	msg.clear_msg()

func clear_choices():
	msg.clear_msg()
#
#func show_menu():
	#menu.start = false
	#menu.open()
	##menu.set_process(true)
	#await menu.exit
	##yield(menu,"exit")
	##menu.set_process(false)

func isVisible():
	return msg.is_visible() || BattleNew.visible# || $INTRO.is_visible() || bag.is_visible() || transition.is_visible()#|| options.is_visible()

#func _on_text_speed_changed(speed):
#	get_node("MSG/Timer 2").set_wait_time(CONST.TEXT_SPEEDS[speed])

#func _on_menu_options():
#	menu.hide()
#	menu.set_process(false)
#	show_options()
#	yield(options, "exit")
#	menu.show()
#	menu.set_process(true)
#
#func send_input():
#	emit_signal("input")
#
#func show_bag():
#	menu.hide()
#	menu.set_process(false)
#	bag.show_bag()
#	bag.set_process(true)
#	yield(bag,"salir")
#	bag.hide()
#	bag.set_process(false)
#	menu.show()
#	menu.set_process(true)
#
func isFading():
	return fading or (fade_layer != null and fade_layer.is_fade_active())

## --- Señales del SignalManager ---
## Maneja solicitudes de mensaje desde el SignalManager
func _on_message_requested(text: String, config: Dictionary = {}) -> void:
	await show_message_with_config(text, config)
	SignalManager.message_finished.emit()

## Notifica que el mensaje terminó
func _on_message_finished() -> void:
	SignalManager.message_finished.emit()
	# Asegurar que no queden flags de pulsación retenidos tras cerrar el mensaje
	pressed_actions.clear()

## Maneja input de accept para el MessageBox
func _on_messagebox_accept() -> void:
	SignalManager.input_accept.emit()

## Maneja input de cancel para el MessageBox
func _on_messagebox_cancel() -> void:
	SignalManager.input_cancel.emit()

## Maneja solicitudes de batalla desde el SignalManager
func _on_battle_requested(participants: Array[BattleParticipant], rules: BattleRules) -> void:
	# Bloquear control del jugador al iniciar batalla
	SignalManager.player_control_blocked.emit()

	# Separar participantes en player y enemy
	var player_participants: Array[BattleParticipant] = []
	var enemy_participants: Array[BattleParticipant] = []

	for participant in participants:
		if participant.is_player:
			player_participants.append(participant)
		else:
			enemy_participants.append(participant)

	# Emitir señal de inicio de batalla
	SignalManager.battle_started.emit()

	# Mostrar la escena de batalla
	BattleNew.visible = true

	# Iniciar el combate (esto ejecutará la transición que maneja todo el fade)
	await BattleNew.start_battle(player_participants, enemy_participants, rules)



## Oculta el MessageBox del overworld (llamado después de los parpadeos de transición)
func _on_hide_overworld_messagebox() -> void:
	print("GUI: Limpiando y ocultando MessageBox del overworld")
	msg.cleanup_and_hide()


## Maneja el evento de finalización de la batalla
func _on_battle_finished(_winner_side: String) -> void:
	print("GUI: Batalla terminada, iniciando transición de salida...")

	# Hacer fade in (a negro) para ocultar la batalla
	await fade_layer.fade_in(0.3)

	# Ocultar la escena de batalla (BattleScene gestiona su propia UI internamente)
	BattleNew.cleanup_battle()

	# Hacer fade out para revelar el overworld
	await fade_layer.fade_out(0.3)

	# Desbloquear control del jugador
	SignalManager.player_control_unblocked.emit()
	print("GUI: Control del jugador desbloqueado")

## --- Métodos del MessageBox ---
## Muestra un mensaje con configuración específica
func show_message_with_config(text: String, config: Dictionary = {}) -> void:
	# Pasar TODA la configuración al MessageBox usando show_custom
	await msg.show_custom(text, config)

## Muestra el ChoiceBox con las opciones especificadas y devuelve el índice seleccionado
func show_choices(options: Array[String]) -> int:
	if options.is_empty():
		push_error("GUI.show_choices: Array de opciones vacío")
		return -1

	# Mostrar el ChoiceBox y esperar la selección
	var selected_index = await choice_box.show_choices(options)

	return selected_index

## Muestra un mensaje seguido automáticamente de opciones (estilo Pokémon)
## El ChoiceBox aparece automáticamente cuando el mensaje termina de escribirse
func show_message_with_choices(text: String, options: Array[String]) -> int:
	if options.is_empty():
		push_error("GUI.show_message_with_choices: Array de opciones vacío")
		return -1

	# Mostrar el mensaje sin esperar input y sin cerrar
	await msg.show_custom(text, {
		"waitInput": false,
		"closeAtEnd": false,
		"waitTime": 0.0,
		"showIconAtEnd": false
	})

	await get_tree().create_timer(0.3).timeout

	# Automáticamente mostrar las opciones cuando el mensaje termina
	var selected_index = await choice_box.show_choices(options)

	# Cerrar el MessageBox después de la selección
	msg.hide()
	msg.clear()

	return selected_index

#
#func showParty():
	#await GUI.fadeIn(3)
	#menu.close()
	#party.loadParty(GAME_DATA.party)
	#party.open(Party.Modes.MENU)
	#await party.exit
	#menu.open()
	#await GUI.fadeOut(3)
	#
#func showChoices(choiceOptions:Array[String], closeAtEnd = true):
	#choices.addChoices(choiceOptions)
	#choices.activeChoices(choiceOptions)
	#var selectedChoice:int = await choices.showContainer()
	#if closeAtEnd:
		#choices.hideContainer()
	#return selectedChoice

#func showPartyBattle():
	#await GUI.fadeIn(3)
	#GUI.battle.hide()
	#var party.openPokemonSelection()
	#await party.exit
	#GUI.battle.show()
	#await GUI.fadeOut(3)
var input_locked := false
var pressed_actions := {}

func _input(event: InputEvent):
	# Registrar liberaciones SIEMPRE, incluso si el GUI no es visible,
	# para evitar que queden flags de pulsación colgados entre mensajes
	if event is InputEventKey and !event.pressed:
		for action in ["ui_accept", "ui_cancel", "ui_start", "ui_up", "ui_down", "ui_right", "ui_left"]:
			if InputMap.event_is_action(event, action):
				pressed_actions.erase(action)

	# Si el foco actual está dentro de BattleUI, no consumir el input aquí
	if $BattleNew.visible:
		var focus_owner = get_viewport().gui_get_focus_owner()
		var battle_ui = $BattleNew/BattleUI
		if battle_ui != null and focus_owner != null and battle_ui.is_ancestor_of(focus_owner):
			return

	if input_locked or !isVisible() or isFading():
		return

	var input_consumed = false

	# Evitar repeticiones automáticas manteniendo pulsado
	if event.is_action_pressed("ui_accept") and !pressed_actions.has("ui_accept"):
		pressed_actions["ui_accept"] = true
		print("GUI accept")
		SignalManager.input_accept.emit()
		SignalManager.messagebox_input_accept.emit()
		input_consumed = true

	if event.is_action_pressed("ui_cancel") and !pressed_actions.has("ui_cancel"):
		pressed_actions["ui_cancel"] = true
		print("GUI cancel")
		SignalManager.input_cancel.emit()
		SignalManager.messagebox_input_cancel.emit()
		input_consumed = true

	if event.is_action_pressed("ui_start") and !pressed_actions.has("ui_start"):
		pressed_actions["ui_start"] = true
		print("GUI start")
		SignalManager.input_start.emit()
		input_consumed = true

	if event.is_action_pressed("ui_up") and !pressed_actions.has("ui_up"):
		pressed_actions["ui_up"] = true
		print("GUI up")
		SignalManager.input_up.emit()
		input_consumed = true

	if event.is_action_pressed("ui_down") and !pressed_actions.has("ui_down"):
		pressed_actions["ui_down"] = true
		print("GUI down")
		SignalManager.input_down.emit()
		input_consumed = true

	if event.is_action_pressed("ui_right") and !pressed_actions.has("ui_right"):
		pressed_actions["ui_right"] = true
		print("GUI right")
		SignalManager.input_right.emit()
		input_consumed = true

	if event.is_action_pressed("ui_left") and !pressed_actions.has("ui_left"):
		pressed_actions["ui_left"] = true
		print("GUI left")
		SignalManager.input_left.emit()
		input_consumed = true

	# Consumir el input para evitar que llegue al Player
	if input_consumed:
		get_viewport().set_input_as_handled()



#func _input(event):
	##if ($MSG.visible and !chs.visible and msg.text_completed):
	#if (isVisible() && !isFading()):
		#if event.is_action_pressed("ui_accept"):
			#Input.action_release("ui_accept")
			#INPUT.ui_accept.free_state()
			#print("GUI accept")
			#if choices.visible:
				#select.emit()
			#else:
				#accept.emit()
		#if event.is_action_pressed("ui_cancel"):
			#Input.action_release("ui_cancel")
			#INPUT.ui_cancel.free_state()
			#print("GUI cancel")
			#cancel.emit()
		#if event.is_action_pressed("ui_start"):
			#Input.action_release("ui_start")
			#INPUT.ui_start.free_state()
			#print("GUI start")
			#if (INPUT.ui_start.is_action_just_released()):
				#start.emit()
		#if event.is_action_pressed("ui_up"):
			#Input.action_release("ui_up")
			#INPUT.ui_up.free_state()
			#print("GUI up")
			#up.emit()
		#if event.is_action_pressed("ui_down"):
			#Input.action_release("ui_down")
			#INPUT.ui_down.free_state()
			#print("GUI down")
			#down.emit()
		#if event.is_action_pressed("ui_right"):
			#Input.action_release("ui_right")
			#INPUT.ui_right.free_state()
			#print("GUI right")
			#right.emit()
		#if event.is_action_pressed("ui_left"):
			#Input.action_release("ui_left")
			#INPUT.ui_left.free_state()
			#print("GUI left")
			#left.emit()



#func start_battle(double, trainer1, trainer2, trainer3 = null, trainer4 = null):#wild_encounter(id, level):
#	battle.show()
#	battle.start_battle(double, trainer1, trainer2, trainer3, trainer4)
#	#battle.wild_encounter(id, level)
#
#func init_battle(double, trainer1, trainer2, trainer3 = null, trainer4 = null):
#	battle.start_battle(double, trainer1, trainer2, trainer3, trainer4)
#
#func set_next():
#	next = true
#
#func save():
#	print("SAVING")
#	GAME_DATA.save_game()
#
#func start_intro():
#	$INTRO.start()
##
#func play_transition(animation : String):
	#transition.play(animation)
	#await transition.finished
	#
#func fadeOut(speed:int=1.0):
	#transition.animationPlayer.speed_scale = speed
	#transition.play("Transitions/FadeToNormal")
	#await transition.finished
	#transition.animationPlayer.speed_scale = 1.0
	#fading = false
	#fadedOut.emit()
	#
#func fadeIn(speed:int=1.0):
	#fading = true
	#transition.animationPlayer.speed_scale = speed #set_speed_scale
	#transition.play("Transitions/FadeToBlack")
	#await transition.finished
	#transition.animationPlayer.speed_scale = 1.0
	#fadedIn.emit()
	#
#func initBattleTransition():
	#GUI.transition.play("Transitions/Battle_WildTransition")
	#await transition.finished
	#
	##await GUI.battle.playAnimation("START_BATTLE_GRASS")
	#
#func resetTransitionScreen():
	#GUI.transition.play("RESET")
	#await transition.finished
