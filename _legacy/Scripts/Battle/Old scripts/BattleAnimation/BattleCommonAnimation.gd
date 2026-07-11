class_name BattleCommonAnimation extends Animation

var root : Object
var parameters : Dictionary
#var animName : String
func _init():#_rootAnimPlayer : AnimationPlayer, _animName : String):
	print("yep")
	#self.animName = _animName
	#self.rootAnimPlayer = _rootAnimPlayer
	
func addParameter(key:String,value:Object):
	parameters[key] = value
	
func getParameter(key:String):
	return parameters[key]

#func doAnimation(_target : BattlePokemon):
#	assert(false, "Please override doAnimation()` in the derived script.")
#
