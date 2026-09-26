extends Panel
signal action_selected(battle_choice: BattleChoice)

@onready var label_question: Label = $Label
@onready var cmd_luchar = $Commands/Luchar
@onready var cmd_pokemon = $Commands/Pokemon
@onready var cmd_mochila = $Commands/Mochila
@onready var cmd_huir = $Commands/Huir

var _suppress_focus_sound: bool = false
var _last_focus_index: int = 0
var _commands: Array[Button] = []

func _ready():
	set_process_input(false)
	_commands = [cmd_luchar, cmd_pokemon, cmd_mochila, cmd_huir]
	cmd_luchar.pressed.connect(_on_cmd_luchar_pressed)
	cmd_pokemon.pressed.connect(_on_cmd_pokemon_pressed)
	cmd_mochila.pressed.connect(_on_cmd_mochila_pressed)
	cmd_huir.pressed.connect(_on_cmd_huir_pressed)
	for cmd in _commands:
		cmd.focus_entered.connect(_on_command_focus_entered)

func show_for(pokemon: BattlePokemon, preserve_focus: bool = false) -> BattleChoice:
	label_question.text = "¿Qué debería hacer\n" + pokemon.get_name() + "?"
	_suppress_focus_sound = true
	visible = true
	if not preserve_focus:
		_last_focus_index = 0
	var focus_index := clampi(_last_focus_index, 0, _commands.size() - 1)
	_commands[focus_index].grab_focus()
	await get_tree().process_frame
	_suppress_focus_sound = false
	var choice: BattleChoice = await action_selected
	set_process_input(false)
	visible = false
	return choice

func _on_command_focus_entered() -> void:
	for i in _commands.size():
		if _commands[i].has_focus():
			_last_focus_index = i
			break
	if _suppress_focus_sound:
		return
	_play_cursor_sound()

func _on_cmd_luchar_pressed():
	_play_select_sound()
	action_selected.emit(BattleMoveChoice.new())

func _on_cmd_pokemon_pressed():
	_play_select_sound()
	action_selected.emit(BattleSwitchChoice.new())

func _on_cmd_mochila_pressed():
	_play_select_sound()
	action_selected.emit(BattleBagChoice.new())

func _on_cmd_huir_pressed():
	_play_select_sound()
	action_selected.emit(BattleRunChoice.new())

func allow_cancel():
	set_process_input(true)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_cancel_pressed()

func _on_cancel_pressed():
	_play_cancel_sound()
	var choice := BattleChoice.new()
	choice.canceled = true
	action_selected.emit(choice)


func _play_cursor_sound() -> void:
	AudioManager.play_ui_cursor()


func _play_select_sound() -> void:
	AudioManager.play_ui_select()


func _play_cancel_sound() -> void:
	AudioManager.play_ui_cancel()
