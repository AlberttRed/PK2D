extends Control

class_name PartySummary

signal closed

enum {
	DATA,
	TRAINER,
	STATS,
	MOVES,
	RIBBONS
}

var loadedParty: Array[Pokemon] = []
var pages: Array[Panel]
@onready var generalInfo: Control = $GENERAL
var activePage: Panel:
	get:
		if pages.is_empty() or summaryIndex < 0 or summaryIndex >= pages.size():
			return null
		return pages[summaryIndex]

var summaryIndex: int = 0
var movingIndex: int = 0


func _ready() -> void:
	generalInfo.hide()
	visibility_changed.connect(_on_visibility_changed)
	for c: Panel in $PAGES.get_children():
		c.hide()
		pages.push_back(c)
	pages[MOVES].showGeneralInfo.connect(showGeneralInfo)


func showSummary(page: int) -> void:
	show()
	generalInfo.show()
	pages[page].open()


func loadPokemonInfo(pokemon: Pokemon) -> void:
	loadGeneralInfo(pokemon)
	for page: Panel in pages:
		page.loadPokemonInfo(pokemon)


func loadGeneralInfo(pokemon: Pokemon) -> void:
	generalInfo.get_node("Nombre").setText(pokemon.get_display_name())

	if pokemon.gender == CONST.GENEROS.MACHO:
		generalInfo.get_node("Genero").texture = preload("res://Sprites/UI/Party/male_icon.png")
	elif pokemon.gender == CONST.GENEROS.HEMBRA:
		generalInfo.get_node("Genero").texture = preload("res://Sprites/UI/Party/female_icon.png")
	else:
		generalInfo.get_node("Genero").texture = null

	if pokemon.fainted:
		generalInfo.get_node("Status").visible = true
		generalInfo.get_node("Status").region_enabled = true
		generalInfo.get_node("Status").region_rect = Rect2(0, 16 * (CONST.STATUS.FAINTED - 1), 44, 16)
	elif pokemon.major_status != CONST.STATUS.OK:
		generalInfo.get_node("Status").visible = true
		generalInfo.get_node("Status").region_enabled = true
		var row: int = maxi(0, pokemon.major_status - 1)
		generalInfo.get_node("Status").region_rect = Rect2(0, 16 * row, 44, 16)
	else:
		generalInfo.get_node("Status").visible = false

	generalInfo.get_node("Nivel").setText(str(pokemon.level))
	generalInfo.get_node("Sprite").texture = pokemon.get_battle_front_sprite()

	var ball_tex := PokeballItemEffect.get_summary_texture(pokemon.captured_ball_id)
	if ball_tex != null:
		generalInfo.get_node("Pokeball").texture = ball_tex


func closeSummary(page: int) -> void:
	pages[page].hide()


func close() -> void:
	summaryIndex = 0
	hide()
	for page: Panel in pages:
		page.hide()
	closed.emit()


func showGeneralInfo(_visible: bool) -> void:
	generalInfo.visible = _visible


func selectOption() -> void:
	pass


func cancelOption() -> void:
	if activePage != null and activePage.name == "MOVES" and activePage.mode != activePage.Modes.NORMAL:
		return
	close()


func moveLeft() -> void:
	if activePage != null and activePage.name == "MOVES" and activePage.mode != activePage.Modes.NORMAL:
		return
	if visible and summaryIndex > 0:
		summaryIndex -= 1
		pages[summaryIndex].open()
		pages[summaryIndex + 1].hide()


func moveRight() -> void:
	if activePage != null and activePage.name == "MOVES" and activePage.mode != activePage.Modes.NORMAL:
		return
	if visible and summaryIndex < 4:
		summaryIndex += 1
		pages[summaryIndex].open()
		pages[summaryIndex - 1].hide()


func moveUp() -> void:
	if activePage != null and activePage.name == "MOVES" and (activePage.mode == activePage.Modes.DETAILED or activePage.mode == activePage.Modes.LEARNING):
		activePage.call("navigate_move_focus", -1)
		return
	if activePage != null and activePage.name == "MOVES" and activePage.mode != activePage.Modes.NORMAL:
		return
	if visible and movingIndex > 0:
		movingIndex -= 1
		loadPokemonInfo(loadedParty[movingIndex])


func moveDown() -> void:
	if activePage != null and activePage.name == "MOVES" and (activePage.mode == activePage.Modes.DETAILED or activePage.mode == activePage.Modes.LEARNING):
		activePage.call("navigate_move_focus", 1)
		return
	if activePage != null and activePage.name == "MOVES" and activePage.mode != activePage.Modes.NORMAL:
		return
	if loadedParty.is_empty():
		return
	if movingIndex < loadedParty.size() - 1:
		movingIndex += 1
		loadPokemonInfo(loadedParty[movingIndex])


func _on_visibility_changed() -> void:
	var dm := DisplayManager.instance
	if dm == null:
		return
	if self.visible:
		dm.input_accept.connect(selectOption)
		dm.input_cancel.connect(cancelOption)
		dm.input_left.connect(moveLeft)
		dm.input_right.connect(moveRight)
		dm.input_up.connect(moveUp)
		dm.input_down.connect(moveDown)
	else:
		if dm.input_accept.is_connected(selectOption):
			dm.input_accept.disconnect(selectOption)
		if dm.input_cancel.is_connected(cancelOption):
			dm.input_cancel.disconnect(cancelOption)
		if dm.input_left.is_connected(moveLeft):
			dm.input_left.disconnect(moveLeft)
		if dm.input_right.is_connected(moveRight):
			dm.input_right.disconnect(moveRight)
		if dm.input_up.is_connected(moveUp):
			dm.input_up.disconnect(moveUp)
		if dm.input_down.is_connected(moveDown):
			dm.input_down.disconnect(moveDown)
