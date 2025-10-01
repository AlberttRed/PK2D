extends BattleHandler

class_name BattleSwaggerMoveHandler

var user
var target
var move

func _init(_move, _user, _target):
	move = _move
	user = _user
	target = _target

func apply() -> void:
	# TODO: aplicar efecto tipo Swagger
	pass

func visualize(ui) -> void:
	# TODO: visualizar Swagger
	pass


