extends BattleHandler

class_name BattleUniqueMoveHandler

var user
var target
var move

func _init(_move, _user, _target):
	move = _move
	user = _user
	target = _target

func apply() -> void:
	# TODO: lógica específica por movimiento
	pass

func visualize(ui) -> void:
	# TODO: visualización específica
	pass


