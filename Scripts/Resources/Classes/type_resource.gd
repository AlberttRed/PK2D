extends Resource

class_name Type

@export var internal_name : String = ""
@export var Name : String = ""
@export var id : int = 0
@export var ineffective: Array[Resource] # the types this type is ineffective against.
@export var no_effect_to: Array[Resource] # the types this type has no effect against.
@export var no_effect_from: Array[Resource] # the types this type has no effect from.
@export var resistance: Array[Resource] # the types this type is resistant to.
@export var super_effective: Array[Resource] # the types this type is super effective against.
@export var weakness: Array[Resource] # the types this type is weak to.
@export var panelMove_y: int = 0 #la posició del panel en la imatge
@export var image : Texture2D = null

	
func get_effectiveness_from(type) -> float:
	for t in no_effect_from:
		if t.id == type.id:
			print(Name + " not affect from " + type.Name)
			return 0.0
	for t in resistance:
		if t.id == type.id:
			print(Name + " resist from " + type.Name)
			return 0.5
	for t in weakness:
		if t.id == type.id:
			print(Name + " weak from " + type.Name)
			return 2.0
	
	print(Name + " is normal from " + type.Name)
	return 1.0

		
func get_effectiveness_against(type) -> float:
	for t in no_effect_to:
		if t.id == type.id:
			print(Name + " not affect againgst " + type.Name)
			return 0.0
	for t in ineffective:
		if t.id == type.id:
			print(Name + " is ineffective againgst " + type.Name)
			return 0.5
	for t in super_effective:
		if t.id == type.id:
			print(Name + " is super effective againgst " + type.Name)
			return 2.0
	
	print(Name + " is normal againgst " + type.Name)
	return 1.0
	
func get_effectiveness_against_pokemon(pokemon: BattlePokemon) -> float:
	var t1 = pokemon.get_type1()
	var t2 = pokemon.get_type2()
	var eff1 = get_effectiveness_against(t1)
	var eff2 = get_effectiveness_against(t2) if t2 != null and t2 != t1 else 1.0
	return eff1 * eff2

			
func _to_string() -> String:
	return "%s (%s)" % [Name, id]
