extends Resource
class_name AbilityData

@export var id: int = -1
@export var internal_name: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var effect_resource: Script = null

func print_info():
	var name := display_name if display_name != "" else internal_name.capitalize()
	print("[Ability] %s (ID %d) | %s" % [name, id, description])
