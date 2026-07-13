extends MoveFailHandler

class_name NoTargetHandler

func _init(_user: BattlePokemon, _move: BattleMove = null):
	super(_user, HitResult.Values.NO_TARGET, _move, null)
