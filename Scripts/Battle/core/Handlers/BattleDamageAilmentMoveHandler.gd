extends BattleHandler

class_name BattleDamageAilmentMoveHandler

var user
var target
var move

func _init(_move, _user, _target):
	move = _move
	user = _user
	target = _target

func apply() -> void:
	# TODO: aplicar daño y posible estado
	pass

func visualize(ui) -> void:
	# TODO: visualizar daño y mensajes de estado
	pass


