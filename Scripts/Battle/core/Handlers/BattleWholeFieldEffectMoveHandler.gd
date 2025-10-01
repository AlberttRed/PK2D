extends BattleHandler

class_name BattleWholeFieldEffectMoveHandler

var user
var target
var move

func _init(_move, _user, _target):
	move = _move
	user = _user
	target = _target

func apply() -> void:
	# TODO: aplicar efecto de campo global
	pass

func visualize(ui) -> void:
	# TODO: visualizar efecto global
	pass


