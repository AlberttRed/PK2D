class_name BattleMoveAnimation

var animation : Animation
var move : BattleMove
var origin : BattlePokemon:
	get:
		return move.pokemon
#
#func _init(_move :BattleMove):
	#self.move = _move

#func _init():
	#pass
	#
func doAnimation(_target : BattleSpot):
	assert(false, "Please override doAnimation()` in the derived script.")
