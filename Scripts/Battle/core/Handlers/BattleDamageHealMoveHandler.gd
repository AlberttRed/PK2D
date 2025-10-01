extends BattleMoveHandler

class_name BattleDamageHealMoveHandler

func _init(_move, _user, _target, _category = null):
	super._init(_move, _user, _target, _category)

func apply() -> void:
	# TODO: aplicar daño y curación por drenaje
	pass

func visualize(ui) -> void:
	# TODO: visualizar daño y curación
	pass


