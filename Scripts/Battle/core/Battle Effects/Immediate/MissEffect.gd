class_name MissEffect
extends ImmediateBattleEffect

var user
var target

func _init(u):
	user = u

func apply():
	pass # no cambia el estado

func visualize(ui: BattleUI):
	await ui.show_failed_move_message(user)
