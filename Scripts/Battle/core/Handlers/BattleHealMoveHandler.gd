extends BattleHandler

class_name BattleHealMoveHandler

var user
var target
var move

var heal_result = null

func _init(_move, _user, _target):
	move = _move
	user = _user
	target = _target

func apply() -> void:
	heal_result = move.calculate_healing(target)
	# TODO: aplicar curación cuando esté implementado.

func visualize(ui) -> void:
	# TODO: visualizar curación cuando esté implementado.
	pass


