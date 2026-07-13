extends MoveFailHandler

class_name ProtectedHandler

func _init(_user: BattlePokemon, _move: BattleMove, _target: BattleTarget):
	super(_user, HitResult.Values.PROTECTED, _move, _target)
