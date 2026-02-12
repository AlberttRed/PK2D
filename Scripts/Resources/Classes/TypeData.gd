extends Resource

class_name TypeData

@export var internal_name : String = ""
@export var Name : String = ""
@export var id : int = 0
@export var ineffective: Array[int] = [] # IDs of types this type is ineffective against.
@export var no_effect_to: Array[int] = [] # IDs of types this type has no effect against.
@export var no_effect_from: Array[int] = [] # IDs of types this type has no effect from.
@export var resistance: Array[int] = [] # IDs of types this type is resistant to.
@export var super_effective: Array[int] = [] # IDs of types this type is super effective against.
@export var weakness: Array[int] = [] # IDs of types this type is weak to.
@export var panelMove_y: int = 0 #la posició del panel en la imatge
@export var image : Texture2D = null


func get_effectiveness_from(type) -> float:
	if type == null:
		return 1.0

	var type_id: int = 0
	if type.has("id"):
		type_id = type.id
	else:
		var id_variant = type.get("id")
		if id_variant != null:
			type_id = int(id_variant)

	if type_id in no_effect_from:
		print(Name + " not affect from " + type.Name)
		return 0.0
	if type_id in resistance:
		print(Name + " resist from " + type.Name)
		return 0.5
	if type_id in weakness:
		print(Name + " weak from " + type.Name)
		return 2.0

	print(Name + " is normal from " + type.Name)
	return 1.0


func get_effectiveness_against(type) -> float:
	if type == null:
		return 1.0

	var type_id: int = 0
	if type.has("id"):
		type_id = type.id
	else:
		var id_variant = type.get("id")
		if id_variant != null:
			type_id = int(id_variant)

	if type_id in no_effect_to:
		print(Name + " not affect againgst " + type.Name)
		return 0.0
	if type_id in ineffective:
		print(Name + " is ineffective againgst " + type.Name)
		return 0.5
	if type_id in super_effective:
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

func print_info():
	print("[Type] %s | ID: %d | internal: %s" % [Name, id, internal_name])

