extends BattleHandler

class_name BattleMoveHandler

var user
var target
var move
var category = null

# Marcador genérico que los Multi-Hit pueden consultar al final
var show_effectiveness: bool = false

func _init(_move = null, _user = null, _target = null, _category = null):
	move = _move
	user = _user
	target = _target
	category = _category


