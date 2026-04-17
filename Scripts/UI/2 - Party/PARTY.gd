extends Panel

signal exit
signal pokemonSelected
signal modeChanged
signal panelSwap

const msgBox_normalSize = Vector2(398, 66)
const msgBox_actionsSize = Vector2(370, 66)

var style_selected
var style_empty

enum ACTION_PANEL {NONE, DATOS, CAMBIO, MOVER, OBJETO, SALIR}

@export var style_salir : StyleBox
@export var style_salir_sel : StyleBox

@export var style_actions_empty : StyleBox
@export var style_actions_selected : StyleBox
#"ACTIONS/VBoxContainer/SALIR"
@onready var pokemonPanels:Array[PartyPokemonPanel] = [$PKMN_0,$PKMN_1,$PKMN_2,$PKMN_3,$PKMN_4,$PKMN_5]
#@onready var pkmns = [$PKMN_0/Panel,$PKMN_1/Panel,$PKMN_2/Panel,$PKMN_3/Panel,$PKMN_4/Panel,$PKMN_5/Panel]
#@onready var actions_chs = [$ACTIONS/VBoxContainer/NONE, $ACTIONS/VBoxContainer/DATOS,$ACTIONS/VBoxContainer/CAMBIO,$ACTIONS/VBoxContainer/MOVER,$ACTIONS/VBoxContainer/OBJETO,$ACTIONS/VBoxContainer/SALIR]
#@onready var actions_chs = []
#@onready var summary = [$SUMMARY/SUMMARY_1,$SUMMARY/SUMMARY_2,$SUMMARY/SUMMARY_3,$SUMMARY/SUMMARY_4,$SUMMARY/SUMMARY_5]
@onready var summary:PartySummary = $SUMMARY
@onready var salir = $Salir
@onready var actions:ChoicesContainer = $ACTIONS
@onready var fixedMsg = $FIXED_MSG
@onready var msgBox:MessageBox = $MSG #MessageBox.new($MSG)
var canQuit: bool = true

var _mode_internal: PartyPanelModes.Modes = PartyPanelModes.Modes.MENU
var mode: PartyPanelModes.Modes:
	get:
		return _mode_internal
	set(value):
		_mode_internal = value
		_apply_mode_to_ui(value)

#var signals = ["pokedex","pokemon","item","player","save","option","exit"]
var start
var opened = false

#var movingPokemon:bool = false
var movePokemonOriginIndex:int = -1
var movePokemonTargetIndex:int = -1
var swapping:bool = false

var index: int = 0 #Index used to move pokemon targets
var actions_index:int = ACTION_PANEL.NONE #Index used to move between panel actions
#var summary_index = 0 #Index used to move between summaries pages
#var movingIndex: int = 0 #Index used to move between pokemon summaries

var activePanel:PartyPokemonPanel:
	get:
		if index == -1:
			return $Salir
		return pokemonPanels[index]
var activePokemon:
	get:
		if index == -1:
			return null
		return activePanel.pokemon


var loadedParty: Array[Pokemon] = []:
	set(p):
		loadedParty = p
		summary.loadedParty = p
var selectedBattlePokemon # Pokemon index selected to enter battle

func _init():
	pass


func _ready():
	hide()
	summary.hide()
	actions.hide()

func loadParty(_party: Array) -> void:
	loadedParty.clear()
	for item in _party:
		if item is Pokemon:
			loadedParty.append(item)
		elif item is BattlePokemon:
			var inst: Variant = (item as BattlePokemon).instance
			if inst is Pokemon:
				loadedParty.append(inst as Pokemon)
		
func loadPanels():
	for p:int in range(loadedParty.size()):
		pokemonPanels[p].order = p
		pokemonPanels[p].loadPokemon(loadedParty[p])
		pokemonPanels[p].selected.connect(setIndex)
		modeChanged.connect(pokemonPanels[p].setMode)

		
	
func open(open_mode: PartyPanelModes.Modes) -> void:
	loadPanels()
	selectedBattlePokemon = null
	self.mode = open_mode
	pokemonPanels[0].select()
	hideActions()
	print("exit connections: " + str(GUI.accept.get_connections().size()))
	print("open party")
	GUI.accept.connect(Callable(self, "selectOption"))
	GUI.cancel.connect(Callable(self, "cancelOption"))
	#for p in pkmns:
		#p.get_node("AnimationPlayer").play("party_animations/RESET")
	#load_pokemon()

	#match mode:
		#Modes.MENU:
			#setMenuMode()
		#Modes.BATTLE:
			#setBattleMode()
		#Modes.BAG:
			#setBagMode()

	setFixedMsgText("Elige a un Pokémon.")
	#update_styles()
	GUI.setMessageBox(msgBox)
	show()
	if GUI.isFading():
		await GUI.fadeOut(3)
	pokemonPanels[index].grab_focus()
		#await GUI.fadedOut
	#load_focus()
	
#func openPokemonSelection():
	#open(CONST.PARTY_MODES.BATTLE)
	#await pokemonSelected
	#return index
	#
func unloadPanels():
	for panel:PartyPokemonPanel in pokemonPanels:
		panel.clear()
	
func close():
	GUI.accept.disconnect(Callable(self, "selectOption"))
	GUI.cancel.disconnect(Callable(self, "cancelOption"))
	SignalManager.disconnectAll(modeChanged)
	unloadPanels()
	$Salir.release_focus()
	GUI.resetMessageBox()
	await GUI.fadeIn(3)
	hide()
	exit.emit()
	
func selectOption():
	if !visible or swapping:
		return
	if !msgBox.is_visible():
		if !actions.visible and !$SUMMARY.visible:
			if activePanel.name == "Salir":
				if mode == PartyPanelModes.Modes.SWAP:
					cancelMovePokemon()
				if canQuit:
					close()
			else:
				if mode == PartyPanelModes.Modes.MENU:
					show_PartyActions()
				elif mode == PartyPanelModes.Modes.SWAP:
					movePokemonTargetIndex = index
					await swapPokemon()
				elif mode == PartyPanelModes.Modes.BATTLE:
					show_BattleActions()
					
		elif actions.visible and !$SUMMARY.visible:
			if actions.isSelected("DATOS"):
				showSummary(PartySummary.DATA)
			elif actions.isSelected("CAMBIO"):
				if activePokemon.inBattle:
					await showMsg(activePokemon.get_display_name() + " ya está en el campo de batalla!")
				elif activePokemon.fainted:
					await showMsg("¡A " + activePokemon.get_display_name() + " no le quedan fuerzas para luchar!")
				else:
					selectedBattlePokemon = index
					pokemonSelected.emit()#loadedParty[index])#index
					close()
			elif actions.isSelected("MOVER"):
				selectMovePokemon()
			elif actions.isSelected("OBJETO"):
				print("objeto")
			elif actions.isSelected("SALIR"):
				cancelOption()
		#elif $SUMMARY.visible:
			#hide_summaries()
			
func showMsg(text:String):
	if actions.visible:
		actions.hide()
	msgBox.position = Vector2(0, 288)
	await GUI.showMessageInput(text)
	msgBox.position = Vector2(0, 0)
	actions.show()
	
func cancelOption():
	if swapping:
		return
	if !msgBox.is_visible():
		if !actions.visible and !$SUMMARY.visible:
			if mode == PartyPanelModes.Modes.SWAP:
				cancelMovePokemon()
				if activePanel.name == "Salir":
					if canQuit:
						close()
			else:
				if activePanel.name == "Salir":
					if canQuit:
						close()
				index = -1
				salir.grab_focus()
				#update_styles()
		elif actions.visible and !$SUMMARY.visible:
			hideActions()
			#pkmns[index].grab_focus()
		#elif $SUMMARY.visible:
			#hideSummary()

#func moveRight():
	#if $SUMMARY.visible:
		#if summary_index < 4:
			#summary_index += 1
			#summary.showSummary(summary_index)
		#
#func moveLeft():
	#if $SUMMARY.visible:
		#if summary_index > 0:
			#summary.closeSummary(summary_index)
			#summary_index -= 1
#
#func moveUp():
	#if $SUMMARY.visible:
		#if movingIndex > 0:
			#movingIndex -= 1
		#summary.loadPokemonInfo(loadedParty[movingIndex])
		#
#func moveDown():
	#if $SUMMARY.visible:
		#if movingIndex < 5:
			#movingIndex += 1
		#summary.loadPokemonInfo(loadedParty[movingIndex])

func selectMovePokemon():
	var form = ""
	var type = ""
	if mode != PartyPanelModes.Modes.SWAP:
		hideActions()
		pokemonPanels[index].grab_focus()
		self.mode = PartyPanelModes.Modes.SWAP
		panelSwap.connect(pokemonPanels[index].setSwapping)
		#movingPokemon = true
		movePokemonOriginIndex = index
		panelSwap.emit(true)

		#update_styles()
		
func swapPokemon():
	swapping = true
	disablePanels()
	#if movePokemonOriginIndex == 0 or movePokemonOriginIndex == 2 or movePokemonOriginIndex == 4: #LEFT
		#pokemonPanels[movePokemonOriginIndex].swapOutLeft()
	#else: #RIGHT
		#pokemonPanels[movePokemonOriginIndex].swapOutRight()
#
	#if movePokemonTargetIndex == 0 or movePokemonTargetIndex == 2 or movePokemonTargetIndex == 4: #LEFT
		#pokemonPanels[movePokemonTargetIndex].swapOutLeft()
	#else: #RIGHT
		#pokemonPanels[movePokemonTargetIndex].swapOutRight()
		#
	pokemonPanels[movePokemonOriginIndex].swapOut()
	pokemonPanels[movePokemonTargetIndex].swapOut()
	#await pokemonPanels[movePokemonOriginIndex].swappedOut
	await pokemonPanels[movePokemonTargetIndex].swappedOut
	
	var pOrigin = loadedParty[movePokemonOriginIndex]
	var pTarget = loadedParty[movePokemonTargetIndex]
	
	pokemonPanels[movePokemonOriginIndex].loadPokemon(pTarget)
	loadedParty[movePokemonOriginIndex] = pTarget
	loadedParty[movePokemonTargetIndex] = pOrigin
	pokemonPanels[movePokemonTargetIndex].loadPokemon(pOrigin)
	#load_pokemon()

	pokemonPanels[movePokemonOriginIndex].swapIn()
	pokemonPanels[movePokemonTargetIndex].swapIn()
#
	#if movePokemonOriginIndex == 0 or movePokemonOriginIndex == 2 or movePokemonOriginIndex == 4: #LEFT
		#pokemonPanels[movePokemonOriginIndex].swapInLeft()
	#else: #RIGHT
		#pokemonPanels[movePokemonOriginIndex].swapInRight()
#
	#if movePokemonTargetIndex == 0 or movePokemonTargetIndex == 2 or movePokemonTargetIndex == 4: #LEFT
		#pokemonPanels[movePokemonTargetIndex].swapInLeft()
	#else: #RIGHT
		#pokemonPanels[movePokemonTargetIndex].swapInRight()
		#
	#await pokemonPanels[movePokemonOriginIndex].swappedIn
	await pokemonPanels[movePokemonTargetIndex].swappedIn
	
	index = movePokemonTargetIndex
	cancelMovePokemon()
	enablePanels()
	pokemonPanels[index].grab_focus()
	swapping = false
	#setPanelFocus()
	
func cancelMovePokemon():
	self.mode = PartyPanelModes.Modes.MENU
	#movingPokemon = false
	panelSwap.emit(false)
	movePokemonOriginIndex = -1
	movePokemonTargetIndex = -1
	SignalManager.disconnectAll(panelSwap)
	#update_styles()
	
func show_party():
	opened = false
	#load_pokemon()
	#update_styles()
	pokemonPanels[0].grab_focus()
	show()
	
	
func hide_party():
	for p in range(loadedParty.size()):
		pokemonPanels[p].visible = false
	opened = false
	hide()

func setSwapping(swap:bool):
	swapping = swap
	#
#func emitSwappedIn():
	#print("swappedIN")
	#swappedIn.emit()
	#
#
#func emitSwappedOut():
	#print("swappedOUT")
	#swappedOut.emit()

	#if index == -1:
		#salir.add_theme_stylebox_override("panel", style_salir_sel)

	
func setFixedMsgText(text:String, boxSize:Vector2 = msgBox_normalSize):
	fixedMsg.get_node("Label").setText(text)
	fixedMsg.size = boxSize

func showActions():
	setFixedMsgText("¿Qué hacer con " + activePokemon.get_display_name() + "?", msgBox_actionsSize)
	#pokemonPanels[index].release_focus()
	#update_styles()
	disablePanels()
	actions.showContainer()

func show_PartyActions():
	actions.activeChoices(["DATOS","MOVER","OBJETO","SALIR"])
	showActions()

func show_BattleActions():
	actions.activeChoices(["CAMBIO","DATOS","SALIR"])
	showActions()

func hideActions():
	setFixedMsgText("Elige a un Pokémon.")
	actions.hideContainer()
	enablePanels()
	pokemonPanels[index].grab_focus()
	#load_focus()
	#update_styles()

#func setPanelFocus():
	#var panelName:String = str(get_focus_owner(self).get_parent().get_name())
	#print(panelName)
	#index = panelName.right(1).to_int()
	#update_styles()


#
#func _on_actions_focus_entered():
	#if !GUI.isFading():
		#match get_focus_owner($ACTIONS/VBoxContainer).get_name():
			#"DATOS":
				#actions_index = ACTION_PANEL.DATOS
			#"CAMBIO":
				#actions_index = ACTION_PANEL.CAMBIO
			#"MOVER":
				#actions_index = ACTION_PANEL.MOVER
			#"OBJETO":
				#actions_index = ACTION_PANEL.OBJETO
			#"SALIR":
				#actions_index = ACTION_PANEL.SALIR
		#update_actions_styles()
	#
#func load_focus():
	#for p in pkmns:
		#p.set_focus_mode(Control.FOCUS_ALL)
	#if loadedParty.size() == 1:
		#print("LOL")
		#pkmns[0].set_focus_neighbor(SIDE_BOTTOM, "../../Salir")
		#pkmns[0].set_focus_neighbor(SIDE_RIGHT, "../../PKMN_0/Panel")
	#if loadedParty.size() == 2:
		#pkmns[0].set_focus_neighbor(SIDE_BOTTOM, "../../Salir")
		#pkmns[1].set_focus_neighbor(SIDE_BOTTOM, "../../Salir")
	#if loadedParty.size() == 3:
		#pkmns[1].set_focus_neighbor(SIDE_BOTTOM, "../../Salir")
		#pkmns[2].set_focus_neighbor(SIDE_BOTTOM, "../../Salir")
		#pkmns[2].set_focus_neighbor(SIDE_RIGHT, "../../PKMN_2/Panel")
	#if loadedParty.size() == 4:
		#pkmns[2].set_focus_neighbor(SIDE_BOTTOM, "../../Salir")
		#pkmns[3].set_focus_neighbor(SIDE_BOTTOM, "../../Salir")
	#if loadedParty.size() == 5:
		#pkmns[3].set_focus_neighbor(SIDE_BOTTOM, "../../Salir")
		#pkmns[4].set_focus_neighbor(SIDE_BOTTOM, "../../Salir")
		#pkmns[4].set_focus_neighbor(SIDE_RIGHT, "../../PKMN_4/Panel")
	#if loadedParty.size() == 6:
		#pkmns[4].set_focus_neighbor(SIDE_BOTTOM, "../../Salir")
		#pkmns[5].set_focus_neighbor(SIDE_BOTTOM, "../../Salir")
	#pkmns[index].grab_focus()
	#

func _on_Salir_focus_entered():
	if !GUI.isFading():
		index = -1
		salir.add_theme_stylebox_override("panel", style_salir_sel)
	#

func _on_salir_focus_exited() -> void:
	if !GUI.isFading():
		salir.add_theme_stylebox_override("panel", style_salir)

func disablePanels():
	for panel:PartyPokemonPanel in pokemonPanels:
		panel.disableFocus()

func enablePanels():
	for panel:PartyPokemonPanel in pokemonPanels:
		panel.enableFocus()
	#for p in pkmns:
		#p.set_focus_mode(Control.FOCUS_NONE)
#		p.set_focus_neighbour(MARGIN_BOTTOM, "")
#		p.set_focus_neighbour(MARGIN_TOP, "")
#		p.set_focus_neighbour(MARGIN_LEFT, "")
#		p.set_focus_neighbour(MARGIN_RIGHT, "")
	
#func clear_actions_focus():
	#for a in actions_chs:
		#a.set_focus_mode(0)
		#a.set_focus_neighbor(SIDE_BOTTOM, null)
		#a.set_focus_neighbor(SIDE_TOP, null)
		#a.set_focus_neighbor(SIDE_LEFT, null)
		#a.set_focus_neighbor(SIDE_RIGHT, null)
		#
		
func showSummary(page:int):
	await GUI.fadeIn(3)
	hideActions()
	disablePanels()
	summary.loadPokemonInfo(loadedParty[index])
	summary.movingIndex = index
	summary.showSummary(page)
	await GUI.fadeOut(3)
	await summary.closed
	pokemonPanels[index].grab_focus()
	summary.movingIndex = index
	hideActions()
	await GUI.fadeOut(3)
	
	
	
	
func showMoveSelection(pokemon: Pokemon, learningMove: Move) -> Variant:
	await GUI.fadeIn(3)
	hideActions()
	disablePanels()
	summary.loadPokemonInfo(pokemon)
	show()
	summary.summaryIndex = PartySummary.MOVES
	summary.show()
	summary.pages[PartySummary.MOVES].learningMove = learningMove
	var selectedMoveIndex = await summary.pages[PartySummary.MOVES].open(true)
	await summary.close()
	hide()
	await GUI.fadeOut(3)
	return selectedMoveIndex
	
#func hideSummary():
	#await GUI.fadeIn(3)
	#pokemonPanels[index].grab_focus()
	#summary.movingIndex = index
	#summary.close()
	#hideActions()
	#await GUI.fadeOut(3)

#func get_focus_owner(parent):
	#for c in parent.get_children():
		#var p
		#if c is Panel:
			#p = c
		#else:
			#p = c.get_node("Panel")
		#if p.has_focus():
			#return p
			#

func _apply_mode_to_ui(m: PartyPanelModes.Modes) -> void:
	match m:
		PartyPanelModes.Modes.MENU:
			setMenuMode()
		PartyPanelModes.Modes.BATTLE:
			setBattleMode()
		PartyPanelModes.Modes.BAG:
			setBagMode()
		PartyPanelModes.Modes.SWAP:
			setSwapMode()
			
func setMenuMode():
	modeChanged.emit(mode)

func setBattleMode():
	exit.connect(func(): pokemonSelected.emit(), CONNECT_ONE_SHOT)
	print("exit connections: " + str(exit.get_connections().size()))
	modeChanged.emit(mode)

func setBagMode():
	modeChanged.emit(mode)

func setSwapMode():
	modeChanged.emit(mode)
	
func setIndex(_index:int):
	self.index = _index
