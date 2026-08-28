class_name BattleMessageAbility
extends RefCounted


static func _ability_to_id(ability) -> int:
	if typeof(ability) == TYPE_INT:
		return int(ability)
	if ability == null:
		return AbilitiesEnum.Values.NONE
	return int(ability.id)

func get_start_ability_message(user:BattlePokemon, ability_id: AbilitiesEnum.Values) -> Dictionary:
	var msg:String = ""
	match ability_id:
		_:
			push_warning("Invalid AbilityData on get_start_ability_message()")
			return {}
			
	return {
		"type": "wait",
		"text": msg,
		"wait_time": 2.0
	}
	

func get_end_ability_message(user:BattlePokemon, ability_id: AbilitiesEnum.Values) -> Dictionary:
	var msg:String = ""
	match ability_id:
		_:
			push_warning("Invalid AbilityData or not implemented on get_end_ability_message()")
			return {}
			
	return {
		"type": "wait",
		"text": msg,
		"wait_time": 2.0
	}
	
func get_ability_ailment_message(user:BattlePokemon, ability_id: AbilitiesEnum.Values) -> Dictionary:
	var msg:String = ""
	match ability_id:
		_:
			push_warning("Invalid AbilityData on get_ability_ailment_message()")
			return {}
			
	return {
		"type": "wait",
		"text": msg,
		"wait_time": 2.0
	}
	
func get_ability_effect_message(user:BattlePokemon, target:BattlePokemon, ability_id: AbilitiesEnum.Values) -> Dictionary:
	var msg:String = ""
	match ability_id:
		AbilitiesEnum.Values.INTIMIDATE:
			msg = "¡Intimidación %s baja el Ataque %s!" % [user.get_battle_possessive_name(), target.get_battle_possessive_name()]
		_:
			push_warning("Invalid AbilityData or not implemented on get_ability_effect_message()")
			return {}
			
	# display: el texto permanece durante la animación del siguiente objetivo (dobles).
	return {
		"type": "display",
		"text": msg,
		"wait_time": 2.0
	}
