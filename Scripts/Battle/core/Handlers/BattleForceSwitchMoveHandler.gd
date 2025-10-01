extends BattleHandler

class_name BattleForceSwitchMoveHandler

var user
var target
var move

func _init(_move, _user, _target):
	move = _move
	user = _user
	target = _target

func apply() -> void:
	# TODO: forzar cambio de Pokémon rival
	pass

func visualize(ui) -> void:
	# TODO: visualizar cambio forzado
	pass


