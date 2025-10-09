extends BattleHandler

class_name BattleWholeFieldEffectMoveHandler

var user: BattlePokemon
var target: BattlePokemon
var move: BattleMove
var move_effect: BattleMoveEffect

func _init(_move: BattleMove, _user: BattlePokemon, _target: BattlePokemon):
	move = _move
	user = _user
	target = _target
	
	# Obtener el efecto del movimiento desde su definición
	move_effect = move.create_move_effect(target)
	if not move_effect:
		push_warning("BattleWholeFieldEffectMoveHandler: El movimiento '%s' no tiene un BattleMoveEffect asignado" % move.get_name())

func apply() -> void:
	if move_effect:
		move_effect.apply()

func visualize(ui: BattleUI) -> void:
	if move_effect:
		await move_effect.visualize(ui)
