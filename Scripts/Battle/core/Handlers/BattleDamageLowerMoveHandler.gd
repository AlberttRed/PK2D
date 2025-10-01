extends BattleHandler

class_name BattleDamageLowerMoveHandler

var user
var target
var move

func _init(_move, _user, _target):
	move = _move
	user = _user
	target = _target

func apply() -> void:
	# TODO: aplicar daño y bajar stats
	pass

func visualize(ui) -> void:
	# TODO: visualizar daño y cambios de stats
	pass


