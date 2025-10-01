extends BattleHandler

class_name BattleOhkoMoveHandler

var user
var target
var move

func _init(_move, _user, _target):
	move = _move
	user = _user
	target = _target

func apply() -> void:
	# TODO: aplicar OHKO si procede
	pass

func visualize(ui) -> void:
	# TODO: visualizar OHKO
	pass


