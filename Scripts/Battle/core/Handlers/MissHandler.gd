extends BattleHandler

class_name MissHandler

var user: BattlePokemon

func _init(_user: BattlePokemon):
	user = _user

func apply() -> void:
	pass

func visualize(ui: BattleUI) -> void:
	await ui.show_failed_move_message(user)


