class_name PokemonLearningMove

enum Type {
LVL_UP=1,
EGG_MOVE=2,
TUTOR=3,
MACHINE=4,
LIGHT_BALL_EGG=6,
FORM_CHANGE=10
}

var moveId:int
var learningType:PokemonLearningMove.Type
var learningLevel:int

func _init(_moveId:int, _learningType:PokemonLearningMove.Type, _learningLevel:int) -> void:
	self.moveId = _moveId
	self.learningType = _learningType
	self.learningLevel = _learningLevel

func getMove() -> MoveInstance:
	return MoveInstance.new(moveId)
