class_name BattleMessageAilment
extends RefCounted


func get_start_ailment_message(user:BattlePokemon, ailment:Ailment) -> Dictionary:
	var msg:String = ""
	match ailment.id:
		"burn":
			msg = "¡%s se ha quemado!" % [user.get_name()]
		"paralysis":
			msg = "¡%s está paralizado! ¡Quizá no pueda moverse!" % [user.get_name()]
		"freeze":
			msg = "¡%s fue congelado!" % [user.get_name()]
		"poison":
			msg = "¡%s fue envenenado!" % [user.get_name()]
		"sleep":
			msg = "¡%s se durmió!" % [user.get_name()]
		"confusion":
			msg = "¡%s se encuentra confuso!" % [user.get_name()]
		_:
			push_warning("Invalid AIlment on get_start_ailment_message()")
			return {}
			
	return {
		"type": "wait",
		"text": msg,
		"wait_time": 2.0
	}
	

func get_end_ailment_message(user:BattlePokemon, ailment:Ailment) -> Dictionary:
	var msg:String = ""
	match ailment.id:
		"burn":
			msg = "¡%s ya no está quemado!" % [user.get_name()]
		"paralysis":
			msg = "¡%s ya no está paralizado!" % [user.get_name()]
		"freeze":
			msg = "¡%s ya no está congelado!" % [user.get_name()]
		"poison":
			msg = "¡%s ya no está envenenado!" % [user.get_name()]
		"sleep":
			msg = "¡%s se despertó!" % [user.get_name()]
		"confusion":
			msg = "¡%s ya no está confuso!" % [user.get_name()]
		_:
			push_warning("Invalid AIlment or not implemented on get_end_ailment_message()")
			return {}
			
	return {
		"type": "wait",
		"text": msg,
		"wait_time": 2.0
	}
	
func get_already_ailment_message(user:BattlePokemon, ailment:Ailment, has_other_status: bool) -> Dictionary:
	var msg:String = ""
	
	if has_other_status:
		return {
			"type": "wait",
			"text": "¡Pero falló!",
			"wait_time": 2.0
		}
	else:
		match ailment.id:
			"burn":
				msg = "¡%s ya está quemado!" % [user.get_name()]
			"paralysis":
				msg = "¡%s ya está paralizado!" % [user.get_name()]
			"freeze":
				msg = "¡%s ya está congelado!" % [user.get_name()]
			"poison":
				msg = "¡%s ya está envenenado!" % [user.get_name()]
			"sleep":
				msg = "¡%s ya está dormido!" % [user.get_name()]
			"confusion":
				msg = "¡%s ya está confuso!" % [user.get_name()]
			_:
				push_warning("Invalid AIlment on get_already_ailment_message()")
				return {}
				
		return {
			"type": "wait",
			"text": msg,
			"wait_time": 2.0
		}

func get_ailment_effect_message(user:BattlePokemon, ailment:Ailment) -> Dictionary:
	var msg:String = ""
	match ailment.id:
		"burn":
			msg = "¡%s se resiente de la quemadura!" % [user.get_name()]
		"paralysis":
			msg = "¡%s está paralizado! ¡No se puede mover!" % [user.get_name()]
		"freeze":
			msg = "¡%s está congelado!" % [user.get_name()]
		"poison":
			msg = "¡El veneno resta PS a %s!" % [user.get_name()]
		"sleep":
			msg = "%s está dormido como un tronco." % [user.get_name()]
		"confusion":
			msg = "¡Está tan confuso que se hirió a si mismo!"
		_:
			push_warning("Invalid AIlment or not implemented on get_ailment_effect_message()")
			return {}
			
	return {
		"type": "wait",
		"text": msg,
		"wait_time": 2.0
	}

func get_ailment_previous_effect_message(user:BattlePokemon, ailment:Ailment) -> Dictionary:
	var msg:String = ""
	match ailment.id:
		"confusion":
			msg = "¡%s está confuso!" % [user.get_name()]
		_:
			push_warning("Invalid AIlment or not implemented on get_ailment_effect_message()")
			return {}
	return {
		"type": "wait",
		"text": msg,
		"wait_time": 2.0
	}
