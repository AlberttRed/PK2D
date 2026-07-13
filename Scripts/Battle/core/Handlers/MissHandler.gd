extends MoveFailHandler

class_name MissHandler

func _init(_user: BattlePokemon, _move: BattleMove = null):
	super(_user, HitResult.Values.MISS_GLOBAL, _move, null)
