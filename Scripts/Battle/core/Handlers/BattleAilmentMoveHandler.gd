extends BattleHandler

class_name BattleAilmentMoveHandler

var user
var target
var move

func _init(_move, _user, _target):
	move = _move
	user = _user
	target = _target

func apply() -> void:
	pass

func visualize(ui) -> void:
	pass


