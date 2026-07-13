extends BattleHandler

class_name MoveFailHandler

var user: BattlePokemon
var move: BattleMove
var target: BattleTarget
var hit_result: HitResult.Values

func _init(
	_user: BattlePokemon,
	_hit_result: HitResult.Values,
	_move: BattleMove = null,
	_target: BattleTarget = null
):
	user = _user
	hit_result = _hit_result
	move = _move
	target = _target

func apply() -> void:
	pass

func visualize(ui: BattleUI) -> void:
	await ui.show_move_fail_message(hit_result, user, move, target)
