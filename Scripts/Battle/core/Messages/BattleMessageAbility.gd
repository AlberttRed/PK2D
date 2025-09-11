class_name BattleMessageAbility
extends RefCounted


func get_start_ability_message(user:BattlePokemon, ability:Ability) -> Dictionary:
	var msg:String = ""
	match ability.id:
		_:
			push_warning("Invalid Ability on get_start_ability_message()")
			return {}
			
	return {
		"type": "wait",
		"text": msg,
		"wait_time": 2.0
	}
	

func get_end_ability_message(user:BattlePokemon, ability:Ability) -> Dictionary:
	var msg:String = ""
	match ability.id:
		_:
			push_warning("Invalid Ability or not implemented on get_end_ability_message()")
			return {}
			
	return {
		"type": "wait",
		"text": msg,
		"wait_time": 2.0
	}
	
func get_ability_ailment_message(user:BattlePokemon, ability:Ability) -> Dictionary:
	var msg:String = ""
	
	match ability.id:
		_:
			push_warning("Invalid Ability on get_ability_ailment_message()")
			return {}
			
	return {
		"type": "wait",
		"text": msg,
		"wait_time": 2.0
	}

func get_ability_effect_message(user:BattlePokemon, target:BattlePokemon, ability:Ability) -> Dictionary:
	var msg:String = ""
	match ability.id:
		AbilityTypes.Ability.INTIMIDATE:
			msg = "¡Intimidación %s baja el Ataque %s!" % [BattleMessageController.get_possessive_name(user), BattleMessageController.get_possessive_name(target)]
		_:
			push_warning("Invalid Ability or not implemented on get_ability_effect_message()")
			return {}
			
	return {
		"type": "wait",
		"text": msg,
		"wait_time": 2.0
	}
