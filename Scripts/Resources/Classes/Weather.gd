extends Resource
class_name Weather

@export var id: int
@export var internal_name: String
@export var display_name: String
@export var effect: Resource

func get_effect(_duration: int = 5, _started_by_move: bool = false) -> PersistentBattleEffect:
	return effect.new(self,_duration,_started_by_move) if effect != null else null
