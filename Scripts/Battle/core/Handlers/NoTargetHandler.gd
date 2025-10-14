extends BattleHandler

class_name NoTargetHandler

var user: BattlePokemon

func _init(_user: BattlePokemon):
    user = _user

func apply() -> void:
    pass

func visualize(ui: BattleUI) -> void:
    await ui.show_no_target_message(user)


