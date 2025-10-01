extends BattleMoveHandler

class_name BattleHealMoveHandler

var heal_result = null

func _init(_move, _user, _target, _category = null):
	super._init(_move, _user, _target, _category)

func apply() -> void:
	heal_result = move.calculate_healing(target)
	# TODO: aplicar curación cuando esté implementado.

func visualize(ui) -> void:
	# TODO: visualizar curación cuando esté implementado.
	pass
