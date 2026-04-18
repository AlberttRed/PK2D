extends Panel
class_name PartyPokemonPanel

signal selected
signal swappedOut
signal swappedIn

@export var style_rounded_normal : StyleBox
@export var style_rounded_normal_sel : StyleBox
@export var style_rounded_fainted : StyleBox
@export var style_rounded_fainted_sel : StyleBox
@export var style_rounded_swap : StyleBox
@export var style_rounded_swap_sel : StyleBox

@export var style_square_normal : StyleBox
@export var style_square_normal_sel : StyleBox
@export var style_square_empty : StyleBox
@export var style_square_fainted : StyleBox
@export var style_square_fainted_sel : StyleBox
@export var style_square_swap : StyleBox
@export var style_square_swap_sel : StyleBox

var mode: PartyPanelModes.Modes = PartyPanelModes.Modes.MENU
var order:int #Panel order inside Party
var pokemon: Pokemon
var swapping: bool = false

func _ready() -> void:
	self.focus_mode = Control.FOCUS_NONE
	self.visible = false

func apply_empty_slot(slot_order: int) -> void:
	self.order = slot_order
	self.pokemon = null
	focus_mode = FocusMode.FOCUS_NONE
	self.visible = false


func loadPokemon(pokemon: Pokemon) -> void:
	self.visible = true
	self.pokemon = pokemon
	focus_mode = FocusMode.FOCUS_ALL

	$Nombre.setText(pokemon.get_display_name())

	$dNv.setText(str(pokemon.level))

	if pokemon.fainted:
		$Status.visible = true
		$Status.region_enabled = true
		$Status.region_rect = Rect2(0, 16 * (CONST.STATUS.FAINTED - 1), 44, 16)
	elif pokemon.major_status != CONST.STATUS.OK:
		$Status.visible = true
		$Status.region_enabled = true
		var row: int = maxi(0, pokemon.major_status - 1)
		$Status.region_rect = Rect2(0, 16 * row, 44, 16)
	else:
		$Status.visible = false

	$health_bar.init(pokemon)

	var icon_tex := pokemon.get_icon_sprite()
	$pkmn.texture = icon_tex

	if pokemon.gender == CONST.GENEROS.MACHO:
		$gender.texture = preload("res://Sprites/UI/Party/male_icon.png")
	elif pokemon.gender == CONST.GENEROS.HEMBRA:
		$gender.texture = preload("res://Sprites/UI/Party/female_icon.png")
	else:
		$gender.texture = null
	_play_party_icon_idle()


## Animación suave del icono en tarjeta no seleccionada (misma que al quitar foco).
func _play_party_icon_idle() -> void:
	var ap := get_node_or_null("AnimationPlayer") as AnimationPlayer
	if ap:
		ap.play("party_animations/PARTY_pkmn_icon")


func select():
	if pokemon == null:
		return
	var form = ""
	var type = ""

	if order == 0:
		form = "rounded"
	else:
		form = "square"

	if pokemon != null and pokemon.fainted:
		type = "fainted_sel"
	elif mode != PartyPanelModes.Modes.SWAP:
		type = "normal_sel"
	elif mode == PartyPanelModes.Modes.SWAP:
		if swapping:
			type = "swap"
		else:
			type = "swap_sel"
		
	add_theme_stylebox_override("panel", get("style_" + form + "_" + type))
	$ball.texture = preload("res://Sprites/UI/Party/partyBallSel.PNG")
	$AnimationPlayer.play("party_animations/PARTY_pkmn_icon_updown")
	
	selected.emit(order)
	
func setSwapMode() -> void:
	self.mode = PartyPanelModes.Modes.SWAP

func unselect():
	if pokemon == null:
		return
	var form = ""
	var type = ""

	if order == 0:
		form = "rounded"
	else:
		form = "square"
	if pokemon != null and pokemon.fainted:
		type = "fainted"
	elif mode != PartyPanelModes.Modes.SWAP or (mode == PartyPanelModes.Modes.SWAP && !swapping):
		type = "normal"
	elif mode == PartyPanelModes.Modes.SWAP && swapping:
		type = "swap"
	add_theme_stylebox_override("panel", get("style_" + form + "_" + type))
	$ball.texture = preload("res://Sprites/UI/Party/partyBall.PNG")
	_play_party_icon_idle()


func update_styles():
	var form = ""
	var type = ""
	
	if order == 0:
		form = "rounded"
	else:
		form = "square"
		
func clear() -> void:
	if pokemon != null:
		unselect()
	self.order = 0
	self.pokemon = null
	for c in selected.get_connections():
		if c is Dictionary and c.has("callable"):
			selected.disconnect(c["callable"])
	self.swapping = false
	self.mode = PartyPanelModes.Modes.MENU


func _on_focus_entered() -> void:
	# Aplicar siempre: durante fade_out el foco ya está en el panel pero is_fading() sigue true
	# (p. ej. vuelta mochila → party) y si no, nunca se ve el estilo seleccionado.
	select()


func _on_focus_exited() -> void:
	unselect()

func enableFocus():
	if not focus_entered.is_connected(_on_focus_entered):
		focus_entered.connect(_on_focus_entered)
	if not focus_exited.is_connected(_on_focus_exited):
		focus_exited.connect(_on_focus_exited)
	self.focus_mode = Control.FOCUS_ALL if pokemon != null else Control.FOCUS_NONE


func disableFocus():
	if focus_entered.is_connected(_on_focus_entered):
		focus_entered.disconnect(_on_focus_entered)
	if focus_exited.is_connected(_on_focus_exited):
		focus_exited.disconnect(_on_focus_exited)
	self.focus_mode = Control.FOCUS_NONE

func setMode(new_mode: PartyPanelModes.Modes) -> void:
	self.mode = new_mode
	update()
	
func setSwapping(swapping:bool):
	self.swapping = swapping
	update()
		
func update():
	if pokemon == null:
		return
	if has_focus():
		select()
	else:
		unselect()
		
func swapOut() -> void:
	var tw := create_tween()
	var delta := Vector2(-260, 0) if (order == 0 or order == 2 or order == 4) else Vector2(260, 0)
	tw.tween_property(self, "position", position + delta, 0.5)
	await tw.finished
	swappedOut.emit()


func swapIn() -> void:
	var tw := create_tween()
	var delta := Vector2(260, 0) if (order == 0 or order == 2 or order == 4) else Vector2(-260, 0)
	tw.tween_property(self, "position", position + delta, 0.5)
	await tw.finished
	swappedIn.emit()


func swapInLeft():
	$AnimationPlayer.play("party_animations/swapInLeft")
	
func swapOutRight():
	$AnimationPlayer.play("party_animations/SwapOutRight")
	
func swapInRight():
	$AnimationPlayer.play("party_animations/swapInRight")

#func emitSwappedIn():
	#print("swappedIN")
	#swappedIn.emit()
	#
#func emitSwappedOut():
	#print("swappedOUT")
	#swappedOut.emit()
