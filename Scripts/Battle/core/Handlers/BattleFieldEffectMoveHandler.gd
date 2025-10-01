extends BattleHandler

class_name BattleFieldEffectMoveHandler

var user
var target
var move

func _init(_move, _user, _target):
	move = _move
	user = _user
	target = _target

func apply() -> void:
	# TODO: aplicar efecto de campo a side o al campo completo
	pass

func visualize(ui) -> void:
	# TODO: visualizar efecto de campo
	pass


