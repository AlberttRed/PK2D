class_name BattleMessageAilment
extends RefCounted


func get_start_ailment_message(user:BattlePokemon, ailment_id: AilmentsEnum.Values) -> Dictionary:
	var msg:String = ""
	match ailment_id:
		AilmentsEnum.Values.BURN:
			msg = "¡%s se ha quemado!" % [user.get_battle_display_name(true)]
		AilmentsEnum.Values.PARALYSIS:
			msg = "¡%s está paralizado! ¡Quizá no pueda moverse!" % [user.get_battle_display_name(true)]
		AilmentsEnum.Values.FREEZE:
			msg = "¡%s fue congelado!" % [user.get_battle_display_name(true)]
		AilmentsEnum.Values.POISON:
			msg = "¡%s fue envenenado!" % [user.get_battle_display_name(true)]
		AilmentsEnum.Values.SLEEP:
			msg = "¡%s se durmió!" % [user.get_battle_display_name(true)]
		AilmentsEnum.Values.CONFUSION:
			msg = "¡%s se encuentra confuso!" % [user.get_battle_display_name(true)]
		AilmentsEnum.Values.INFATUATION:
			msg = "¡%s se ha enamorado!" % [user.get_battle_display_name(true)]
		_:
			push_warning("Invalid AIlment on get_start_ailment_message()")
			return {}

	return {
		"type": "wait",
		"text": msg,
		"wait_time": 2.0
	}


func get_end_ailment_message(user:BattlePokemon, ailment_id: AilmentsEnum.Values) -> Dictionary:
	var msg:String = ""
	match ailment_id:
		AilmentsEnum.Values.BURN:
			msg = "¡%s ya no está quemado!" % [user.get_battle_display_name(true)]
		AilmentsEnum.Values.PARALYSIS:
			msg = "¡%s ya no está paralizado!" % [user.get_battle_display_name(true)]
		AilmentsEnum.Values.FREEZE:
			msg = "¡%s ya no está congelado!" % [user.get_battle_display_name(true)]
		AilmentsEnum.Values.POISON:
			msg = "¡%s ya no está envenenado!" % [user.get_battle_display_name(true)]
		AilmentsEnum.Values.SLEEP:
			msg = "¡%s se despertó!" % [user.get_battle_display_name(true)]
		AilmentsEnum.Values.CONFUSION:
			msg = "¡%s ya no está confuso!" % [user.get_battle_display_name(true)]
		AilmentsEnum.Values.INFATUATION:
			msg = "¡%s ya no está enamorado!" % [user.get_battle_display_name(true)]
		_:
			push_warning("Invalid AIlment or not implemented on get_end_ailment_message()")
			return {}

	return {
		"type": "wait",
		"text": msg,
		"wait_time": 2.0
	}

func get_already_ailment_message(user:BattlePokemon, ailment_id: AilmentsEnum.Values, has_other_status: bool) -> Dictionary:
	var msg:String = ""

	if has_other_status:
		return {
			"type": "wait",
			"text": "¡Pero falló!",
			"wait_time": 2.0
		}
	else:
		match ailment_id:
			AilmentsEnum.Values.BURN:
				msg = "¡%s ya está quemado!" % [user.get_battle_display_name(true)]
			AilmentsEnum.Values.PARALYSIS:
				msg = "¡%s ya está paralizado!" % [user.get_battle_display_name(true)]
			AilmentsEnum.Values.FREEZE:
				msg = "¡%s ya está congelado!" % [user.get_battle_display_name(true)]
			AilmentsEnum.Values.POISON:
				msg = "¡%s ya está envenenado!" % [user.get_battle_display_name(true)]
			AilmentsEnum.Values.SLEEP:
				msg = "¡%s ya está dormido!" % [user.get_battle_display_name(true)]
			AilmentsEnum.Values.CONFUSION:
				msg = "¡%s ya está confuso!" % [user.get_battle_display_name(true)]
			AilmentsEnum.Values.INFATUATION:
				msg = "¡%s ya está enamorado!" % [user.get_battle_display_name(true)]
			_:
				push_warning("Invalid AIlment on get_already_ailment_message()")
				return {}

		return {
			"type": "wait",
			"text": msg,
			"wait_time": 2.0
		}

func get_ailment_effect_message(user:BattlePokemon, ailment_id: AilmentsEnum.Values) -> Dictionary:
	var msg:String = ""
	match ailment_id:
		AilmentsEnum.Values.BURN:
			msg = "¡%s se resiente de la quemadura!" % [user.get_battle_display_name(true)]
		AilmentsEnum.Values.PARALYSIS:
			msg = "¡%s está paralizado! ¡No se puede mover!" % [user.get_battle_display_name(true)]
		AilmentsEnum.Values.FREEZE:
			msg = "¡%s está congelado!" % [user.get_battle_display_name(true)]
		AilmentsEnum.Values.POISON:
			msg = "¡El veneno resta PS %s!" % [user.get_battle_target_name()]
		AilmentsEnum.Values.SLEEP:
			msg = "%s está dormido como un tronco." % [user.get_battle_display_name(true)]
		AilmentsEnum.Values.CONFUSION:
			msg = "¡Está tan confuso que se hirió a si mismo!"
		AilmentsEnum.Values.INFATUATION:
			msg = "¡El amor impide que %s ataque!" % [user.get_battle_display_name(false)]
		_:
			push_warning("Invalid AIlment or not implemented on get_ailment_effect_message()")
			return {}

	return {
		"type": "display",
		"text": msg,
		"wait_time": 0.5
	}

func get_ailment_previous_effect_message(
	user: BattlePokemon,
	ailment_id: AilmentsEnum.Values,
	related_pokemon: BattlePokemon = null
) -> Dictionary:
	var msg: String = ""
	match ailment_id:
		AilmentsEnum.Values.CONFUSION:
			msg = "¡%s está confuso!" % [user.get_battle_display_name(true)]
		AilmentsEnum.Values.INFATUATION:
			if related_pokemon == null:
				push_warning("Infatuation previous message requires related_pokemon (inflictor).")
				return {}
			msg = "¡%s se ha enamorado %s!" % [
				user.get_battle_display_name(true),
				related_pokemon.get_battle_possessive_name(),
			]
		_:
			push_warning("Invalid AIlment or not implemented on get_ailment_effect_message()")
			return {}
	return {
		"type": "wait",
		"text": msg,
		"wait_time": 2.0
	}
