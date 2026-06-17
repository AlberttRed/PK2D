class_name BattleMessageAilment
extends RefCounted


func get_start_ailment_message(
	user: BattlePokemon,
	ailment_id: AilmentsEnum.Values,
	related_pokemon: BattlePokemon = null,
	causing_move_id: int = 0
) -> Dictionary:
	var msg: String = ""
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
		AilmentsEnum.Values.FLINCH:
			return {}
		AilmentsEnum.Values.TRAP:
			return _get_trap_start_message(user, related_pokemon, causing_move_id)
		_:
			push_warning("Invalid AIlment on get_start_ailment_message()")
			return {}

	return {
		"type": "wait",
		"text": msg,
		"wait_time": 2.0
	}


func get_end_ailment_message(
	user: BattlePokemon,
	ailment_id: AilmentsEnum.Values,
	causing_move_id: int = 0
) -> Dictionary:
	var msg: String = ""
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
		AilmentsEnum.Values.TRAP:
			return _get_trap_end_message(user, causing_move_id)
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
			AilmentsEnum.Values.TRAP:
				msg = "¡%s ya está atrapado!" % [user.get_battle_display_name(true)]
			_:
				push_warning("Invalid AIlment on get_already_ailment_message()")
				return {}

		return {
			"type": "wait",
			"text": msg,
			"wait_time": 2.0
		}

func get_ailment_effect_message(
	user: BattlePokemon,
	ailment_id: AilmentsEnum.Values,
	causing_move_id: int = 0
) -> Dictionary:
	var msg: String = ""
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
		AilmentsEnum.Values.FLINCH:
			msg = "¡%s retrocedió!" % [user.get_battle_display_name(true)]
		AilmentsEnum.Values.TRAP:
			return _get_trap_effect_message(user, causing_move_id)
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


func get_trap_block_switch_message(user: BattlePokemon) -> Dictionary:
	if user == null:
		return {}
	return {
		"type": "wait",
		"text": "¡%s está atrapado y no puede cambiar!" % [user.get_battle_display_name(true)],
		"wait_time": 2.0
	}


func _get_trap_start_message(
	target: BattlePokemon,
	inflictor: BattlePokemon,
	move_id: int
) -> Dictionary:
	var msg: String = ""
	match move_id:
		MovesEnum.Values.BIND:
			msg = "¡Atadura de %s oprime a %s!" % [
				inflictor.get_battle_display_name(true),
				target.get_battle_display_name(false),
			]
		MovesEnum.Values.WRAP:
			msg = "¡Constricción de %s atrapó a %s!" % [
				inflictor.get_battle_display_name(true),
				target.get_battle_display_name(false),
			]
		MovesEnum.Values.CLAMP:
			msg = "¡%s atenazó a %s!" % [
				inflictor.get_battle_display_name(true),
				target.get_battle_display_name(false),
			]
		MovesEnum.Values.FIRE_SPIN, MovesEnum.Values.WHIRLPOOL:
			msg = "¡%s fue atrapado en el torbellino!" % [target.get_battle_display_name(true)]
		MovesEnum.Values.SAND_TOMB:
			msg = "¡%s fue atrapado en el bucle de arena!" % [target.get_battle_display_name(true)]
		MovesEnum.Values.MAGMA_STORM:
			msg = "¡%s fue atrapado en la tormenta ígnea!" % [target.get_battle_display_name(true)]
		MovesEnum.Values.INFESTATION:
			msg = "¡%s fue atrapado en el acoso!" % [target.get_battle_display_name(true)]
		_:
			msg = "¡%s quedó atrapado!" % [target.get_battle_display_name(true)]

	return {
		"type": "wait",
		"text": msg,
		"wait_time": 2.0
	}


func _get_trap_effect_message(target: BattlePokemon, move_id: int) -> Dictionary:
	var move_name := _get_trap_move_name(move_id)
	var msg := (
		"¡%s ha herido a %s!" % [move_name, target.get_battle_display_name(false)]
		if move_id != 0
		else "¡%s se resiente del atrapamiento!" % [target.get_battle_display_name(true)]
	)
	return {
		"type": "display",
		"text": msg,
		"wait_time": 0.5
	}


func _get_trap_end_message(target: BattlePokemon, move_id: int) -> Dictionary:
	var move_name := _get_trap_end_move_name(move_id)
	var msg := (
		"¡%s se liberó de %s!" % [target.get_battle_display_name(true), move_name]
		if move_id != 0
		else "¡%s ya no está atrapado!" % [target.get_battle_display_name(true)]
	)
	return {
		"type": "wait",
		"text": msg,
		"wait_time": 2.0
	}


func _get_trap_end_move_name(move_id: int) -> String:
	if move_id == MovesEnum.Values.BIND:
		return "ATADURA"
	return _get_trap_move_name(move_id)


func _get_trap_move_name(move_id: int) -> String:
	match move_id:
		MovesEnum.Values.BIND:
			return "Atadura"
		MovesEnum.Values.WRAP:
			return "Constricción"
		MovesEnum.Values.FIRE_SPIN:
			return "Giro Fuego"
		MovesEnum.Values.CLAMP:
			return "Tenaza"
		MovesEnum.Values.WHIRLPOOL:
			return "Torbellino"
		MovesEnum.Values.SAND_TOMB:
			return "Bucle Arena"
		MovesEnum.Values.MAGMA_STORM:
			return "Lluvia Ígnea"
		MovesEnum.Values.INFESTATION:
			return "Acoso"
		_:
			return "la trampa"
