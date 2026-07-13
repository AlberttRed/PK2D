extends MoveFailHandler

class_name EvadedHandler

func _init(_user: BattlePokemon, _move: BattleMove, _target: BattleTarget):
	super(_user, HitResult.Values.EVADED, _move, _target)
