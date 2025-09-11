extends Panel
signal move_selected(battle_choice: BattleChoice)

@onready var lbl_pps = $lblPPs
@onready var move_type_icon = $MoveType
@onready var move_buttons = [
	$Moves/Move1,
	$Moves/Move2,
	$Moves/Move3,
	$Moves/Move4
]
var current_pokemon: BattlePokemon
var moves: Array[BattleMove] = []

func _ready():
	for i in move_buttons.size():
		move_buttons[i].pressed.connect(_on_move_pressed.bind(i))
		move_buttons[i].focus_entered.connect(_on_focus_entered.bind(i))

func show_for(pokemon: BattlePokemon) -> BattleMoveChoice:
	current_pokemon = pokemon
	moves = pokemon.get_available_moves()

	for i in 4:
		if i < moves.size():
			var move:BattleMove = moves[i]
			var button = move_buttons[i]
			button.visible = true
			button.get_node("Label").setText(move.get_name())
			button.disabled = false

			# Estilo visual según tipo (posición vertical en el sprite)
			button.get("theme_override_styles/normal").region_rect.position.y = 46 * (move.get_type().id - 1)
			button.get("theme_override_styles/focus").region_rect.position.y = 46 * (move.get_type().id - 1)
		else:
			move_buttons[i].visible = false

	move_buttons[0].grab_focus()
	visible = true

	var choice: BattleMoveChoice = await move_selected
	visible = false
	return choice

func _on_move_pressed(index: int):
	var choice := BattleMoveChoice.new()
	choice.move_index = index
	move_selected.emit(choice)

func _on_focus_entered(index: int):
	var move = moves[index]
	update_move_info_panel(move)

func update_move_info_panel(move: BattleMove):
	move_type_icon.texture = move.get_type().image
	move_type_icon.vframes = 1

	lbl_pps.text = "PP: %d/%d" % [move.get_pp(), move.get_total_pp()]

	var ratio = float(move.get_pp()) / float(move.get_total_pp())
	if move.get_pp() == 0:
		lbl_pps.add_theme_color_override("default_color", Color("FF4A4A"))
		lbl_pps.add_theme_color_override("font_shadow_color", Color("8C3131"))
	elif ratio <= 0.25:
		lbl_pps.add_theme_color_override("default_color", Color("FF8C21"))
		lbl_pps.add_theme_color_override("font_shadow_color", Color("944A18"))
	elif ratio <= 0.5:
		lbl_pps.add_theme_color_override("default_color", Color("FFC600"))
		lbl_pps.add_theme_color_override("font_shadow_color", Color("946B00"))
	else:
		lbl_pps.add_theme_color_override("default_color", Color("585850"))
		lbl_pps.add_theme_color_override("font_shadow_color", Color("A8B8B8"))
