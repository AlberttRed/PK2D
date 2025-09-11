extends Panel
signal action_selected(battle_choice: BattleChoice)

@onready var label_question = $Label
@onready var cmd_luchar = $Commands/Luchar
@onready var cmd_pokemon = $Commands/Pokemon
@onready var cmd_mochila = $Commands/Mochila
@onready var cmd_huir = $Commands/Huir

func _ready():
	# Conectar focus
	#cmd_luchar.focus_entered.connect(_on_cmd_luchar_focus)
	#cmd_pokemon.focus_entered.connect(_on_cmd_pokemon_focus)
	#cmd_mochila.focus_entered.connect(_on_cmd_mochila_focus)
	#cmd_huir.focus_entered.connect(_on_cmd_huir_focus)

	# Conectar botones
	cmd_luchar.pressed.connect(_on_cmd_luchar_pressed)
	cmd_pokemon.pressed.connect(_on_cmd_pokemon_pressed)
	cmd_mochila.pressed.connect(_on_cmd_mochila_pressed)
	cmd_huir.pressed.connect(_on_cmd_huir_pressed)

func show_for(pokemon: BattlePokemon) -> BattleChoice:
	label_question.text = "¿Qué debería hacer\n" + pokemon.get_name() + "?"
	visible = true
	cmd_luchar.grab_focus()

	var choice: BattleChoice = await action_selected
	visible = false
	return choice

func _on_cmd_luchar_pressed(): action_selected.emit(BattleMoveChoice.new())
func _on_cmd_pokemon_pressed(): action_selected.emit(BattleMoveChoice.new())
func _on_cmd_mochila_pressed(): action_selected.emit(null) #BattleItemChoice
func _on_cmd_huir_pressed(): action_selected.emit(null) #BattleRunChoice

## Resalta visualmente el botón con focus
#func _highlight(cmd: Button):
	#for b in [cmd_luchar, cmd_pokemon, cmd_mochila, cmd_huir]:
		#b.get("theme_override_styles/panel").region_rect.position.x = 0
	#cmd.get("theme_override_styles/panel").region_rect.position.x = 130
#
#func _on_cmd_luchar_focus(): _highlight(cmd_luchar)
#func _on_cmd_pokemon_focus(): _highlight(cmd_pokemon)
#func _on_cmd_mochila_focus(): _highlight(cmd_mochila)
#func _on_cmd_huir_focus(): _highlight(cmd_huir)
