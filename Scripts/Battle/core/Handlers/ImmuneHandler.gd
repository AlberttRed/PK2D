extends MoveFailHandler

class_name ImmuneHandler

func _init(_user: BattlePokemon, _move: BattleMove, _target: BattleTarget):
	super(_user, HitResult.Values.IMMUNE, _move, _target)
