extends BattleHandler

class_name BattleDamageHealMoveHandler

var user
var target
var move

func _init(_move, _user, _target):
	move = _move
	user = _user
	target = _target

func apply() -> void:
	# TODO: aplicar daño y curación por drenaje
	pass

func visualize(ui) -> void:
	# TODO: visualizar daño y curación
	pass


