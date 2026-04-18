extends Panel
class_name PartySummaryMoves

signal moveSelected
signal showGeneralInfo

enum Modes {
	NORMAL,
	DETAILED,
	LEARNING
}

const MOVEPANELS_DEFAULT_POSITION = Vector2(240, 92)
const MOVEPANELS_LEARNING_POSITION = Vector2(240, 16)

@export var normalBackground: Texture
@export var detailedBackground: Texture
@export var learningBackground: Texture
@export var moveSelMark: Texture

@onready var movePanels: Array[Panel] = [$MovePanels/Move1, $MovePanels/Move2, $MovePanels/Move3, $MovePanels/Move4]
@onready var mode: Modes = Modes.NORMAL: set = setMode
@onready var moveInfo: Control = $MoveInfo
@onready var learningMovePanel = $Move0

var moveIndexSelected
var activePanel: Panel

var learningMove: Move:
	set(m):
		learningMove = m
var pokemon: Pokemon
var moves: Array = []
var originMoveIndexSelected = null
var targetMoveIndexSelected = null

var moveIndex: int:
	get:
		if activePanel == null:
			return -1
		else:
			return int(activePanel.name.right(1)) - 1

var activeMove: Move:
	get:
		if moveIndex == -1:
			return learningMove
		return moves[moveIndex]


func _ready() -> void:
	setLearningPanel(false)
	visibility_changed.connect(_on_visibility_changed_cleanup)


func _on_visibility_changed_cleanup() -> void:
	if not visible:
		_on_hidden()


func open(learningMode: bool = false):
	get_viewport().gui_focus_changed.connect(onFocusChanged)
	var dm := DisplayManager.instance
	if dm:
		dm.input_accept.connect(selectOption)
		dm.input_cancel.connect(cancelOption)
	if learningMode:
		self.mode = Modes.LEARNING
	else:
		self.mode = Modes.NORMAL
	show()
	if mode == Modes.LEARNING:
		if DisplayManager.instance:
			await DisplayManager.fade_out(0.15)
		await moveSelected
	return moveIndexSelected


func loadPokemonInfo(pokemon: Pokemon) -> void:
	clear()
	self.pokemon = pokemon
	moves.clear()
	for m in pokemon.movements:
		if m is Move:
			moves.append(m)
	loadMoves()


func loadMoves() -> void:
	for i in range(moves.size()):
		loadMove(movePanels[i], moves[i])


func loadMove(movePanel: Panel, move: Move) -> void:
	if move == null or move.base == null:
		return
	movePanel.visible = true
	movePanel.get_node("Ataque").setText(move.base.Name)
	movePanel.get_node("Tipo").frame = move.base.type_id
	movePanel.get_node("dPP").setText(str(move.pp_actual) + "/" + str(move.pp))
	movePanel.focus_mode = Control.FOCUS_ALL
	movePanel.get_theme_stylebox("panel").set("texture", null)


func loadMoveInfo(move: Move) -> void:
	if move == null or move.base == null or pokemon == null or pokemon.base == null:
		return
	moveInfo.get_node("Sprite").texture = pokemon.get_icon_sprite()
	var t1 := pokemon.get_type1()
	if t1 != null and t1.image != null:
		moveInfo.get_node("Type1").texture = t1.image
		moveInfo.get_node("Type1").vframes = 1
	var t2 := pokemon.get_type2()
	if t2 != null and t2.image != null:
		moveInfo.get_node("Type2").visible = true
		moveInfo.get_node("Type2").texture = t2.image
		moveInfo.get_node("Type2").vframes = 1
	else:
		moveInfo.get_node("Type2").visible = false

	match move.base.damage_class_id:
		2:
			moveInfo.get_node("dCategory").frame = 0
		3:
			moveInfo.get_node("dCategory").frame = 1
		1:
			moveInfo.get_node("dCategory").frame = 2
		_:
			moveInfo.get_node("dCategory").frame = 2

	if move.base.power != 0:
		moveInfo.get_node("dPower").setText(str(move.base.power))
	else:
		moveInfo.get_node("dPower").setText("---")
	if move.base.accuracy != 0:
		moveInfo.get_node("dAccuracy").setText(str(move.base.accuracy))
	else:
		moveInfo.get_node("dAccuracy").setText("---")
	moveInfo.get_node("lDescription").setText(move.base.description)


func clear() -> void:
	moves.clear()
	for panel: Panel in movePanels:
		panel.visible = false
		panel.get_node("Ataque").text = ""
		panel.get_node("Ataque/Outline").text = ""
		panel.get_node("Tipo").frame = 0
		panel.get_node("dPP").text = ""
		panel.get_node("dPP/Outline").text = ""


func setMode(_mode: Modes) -> void:
	mode = _mode
	match _mode:
		Modes.NORMAL:
			setNormalMode()
		Modes.DETAILED:
			setDetailedMode()
		Modes.LEARNING:
			setLearningMode()


func select(_panel: Panel = null) -> void:
	var panel: Panel
	if _panel != null:
		panel = _panel
	else:
		panel = activePanel
	panel.z_index = 1
	panel.get_theme_stylebox("panel").set("texture", moveSelMark)
	if moveIndex != originMoveIndexSelected:
		panel.get_theme_stylebox("panel").set("region_rect", Rect2(0, 0, 252, 74))
	loadMoveInfo(activeMove)


func unselect(_panel: Panel = null) -> void:
	var panel: Panel
	if _panel != null:
		panel = _panel
	else:
		panel = activePanel
	panel.z_index = 0
	if moveIndex != originMoveIndexSelected:
		panel.get_theme_stylebox("panel").set("texture", null)


func selectOption() -> void:
	if mode == Modes.NORMAL:
		setMode(Modes.DETAILED)
		movePanels[0].grab_focus()
	elif mode == Modes.DETAILED:
		if originMoveIndexSelected == null:
			originMoveIndexSelected = moveIndex
			setSelectedPanel()
		else:
			if moveIndex != originMoveIndexSelected:
				targetMoveIndexSelected = moveIndex
				swapMoves(moves[originMoveIndexSelected], moves[targetMoveIndexSelected])
				select()
	elif mode == Modes.LEARNING:
		if moveIndex != -1:
			moveIndexSelected = moveIndex
		moveSelected.emit()


func cancelOption() -> void:
	if mode == Modes.DETAILED:
		activePanel.release_focus()
		setMode(Modes.NORMAL)
		if originMoveIndexSelected != null:
			unselect(movePanels[originMoveIndexSelected])
			originMoveIndexSelected = null
	elif mode == Modes.LEARNING:
		moveSelected.emit()


func swapMoves(originMove: Move, targetMove: Move) -> void:
	moves[targetMoveIndexSelected] = originMove
	moves[originMoveIndexSelected] = targetMove
	loadMoves()
	targetMoveIndexSelected = null
	unselect(movePanels[originMoveIndexSelected])
	originMoveIndexSelected = null
	unselect()


func _on_move_focus_entered() -> void:
	if activePanel != null:
		select()


func _on_move_focus_exited() -> void:
	if activePanel != null:
		unselect()
	activePanel = null


func _on_hidden() -> void:
	activePanel = null
	if get_viewport().gui_focus_changed.is_connected(onFocusChanged):
		get_viewport().gui_focus_changed.disconnect(onFocusChanged)
	var dm := DisplayManager.instance
	if dm:
		if dm.input_accept.is_connected(selectOption):
			dm.input_accept.disconnect(selectOption)
		if dm.input_cancel.is_connected(cancelOption):
			dm.input_cancel.disconnect(cancelOption)


func onFocusChanged(control: Control) -> void:
	self.activePanel = control


## Navegación vertical entre movimientos (DisplayManager consume ui_up/down con el party abierto, así que no llega el foco automático).
func navigate_move_focus(delta: int) -> void:
	if mode != Modes.DETAILED:
		return
	var indices: Array[int] = []
	for i in range(movePanels.size()):
		if movePanels[i].visible:
			indices.append(i)
	if indices.is_empty():
		return
	var pos_in_list: int = 0
	if activePanel != null:
		var panel_i: int = movePanels.find(activePanel)
		if panel_i >= 0:
			var found: int = indices.find(panel_i)
			if found >= 0:
				pos_in_list = found
	var new_pos: int = clampi(pos_in_list + delta, 0, indices.size() - 1)
	if new_pos == pos_in_list:
		return
	movePanels[indices[new_pos]].grab_focus()


func setSelectedPanel() -> void:
	activePanel.get_theme_stylebox("panel").set("region_rect", Rect2(0, 74, 252, 74))


func setNormalMode() -> void:
	setLearningPanel(false)
	get_theme_stylebox("panel").texture = normalBackground
	showGeneralInfo.emit(true)
	$MovePanels.position = MOVEPANELS_DEFAULT_POSITION
	moveInfo.hide()


func setDetailedMode() -> void:
	setLearningPanel(false)
	get_theme_stylebox("panel").texture = detailedBackground
	showGeneralInfo.emit(false)
	$MovePanels.position = MOVEPANELS_DEFAULT_POSITION
	moveInfo.show()


func setLearningMode() -> void:
	get_theme_stylebox("panel").texture = learningBackground
	showGeneralInfo.emit(false)
	setLearningPanel(true)
	$MovePanels.position = MOVEPANELS_LEARNING_POSITION
	moveInfo.show()
	movePanels[0].grab_focus()


func setLearningPanel(active: bool) -> void:
	learningMovePanel.visible = active
	if active:
		loadMove(learningMovePanel, learningMove)
	else:
		learningMovePanel.focus_mode = FOCUS_NONE
