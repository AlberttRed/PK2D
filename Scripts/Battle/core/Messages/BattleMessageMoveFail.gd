class_name BattleMessageMoveFail
extends RefCounted


func get_move_fail_message(
	hit_result: HitResult.Values,
	user: BattlePokemon,
	_move: BattleMove = null,
	target: BattleTarget = null
) -> Dictionary:
	match hit_result:
		HitResult.Values.MISS_GLOBAL:
			return _miss_global_message(user)
		HitResult.Values.EVADED:
			return _evaded_message(user, target)
		HitResult.Values.PROTECTED:
			return _protected_message(user, target)
		HitResult.Values.IMMUNE:
			return _immune_message(user, target)
		HitResult.Values.NO_TARGET:
			return _no_target_message(user)
		_:
			push_warning("BattleMessageMoveFail: HitResult sin mapeo (%d)" % hit_result)
			return _generic_fail_message(user)


func _miss_global_message(user: BattlePokemon) -> Dictionary:
	return {
		"type": "wait",
		"text": "¡El ataque %s falló!" % user.get_battle_possessive_name(),
		"wait_time": 1.0,
		"message_key": "move_fail.miss_global",
	}


func _evaded_message(_user: BattlePokemon, target: BattleTarget) -> Dictionary:
	var target_pokemon := target.get_pokemon() if target != null else null
	var target_name := target_pokemon.get_battle_display_name(true) if target_pokemon != null else "el objetivo"
	return {
		"type": "wait",
		"text": "¡%s esquivó el ataque!" % target_name,
		"wait_time": 1.0,
		"message_key": "move_fail.evaded",
	}


func _protected_message(_user: BattlePokemon, target: BattleTarget) -> Dictionary:
	var target_pokemon := target.get_pokemon() if target != null else null
	var target_name := target_pokemon.get_battle_display_name(true) if target_pokemon != null else "el objetivo"
	return {
		"type": "wait",
		"text": "¡%s se protegió!" % target_name,
		"wait_time": 1.0,
		"message_key": "move_fail.protected",
	}


func _immune_message(_user: BattlePokemon, target: BattleTarget) -> Dictionary:
	var target_pokemon := target.get_pokemon() if target != null else null
	var target_name := target_pokemon.get_battle_target_name() if target_pokemon != null else "el objetivo"
	return {
		"type": "wait",
		"text": "No afecta %s..." % target_name,
		"wait_time": 1.0,
		"message_key": "move_fail.immune",
	}


func _no_target_message(_user: BattlePokemon) -> Dictionary:
	return {
		"type": "wait",
		"text": "¡Pero no hay objetivo al que atacar!",
		"wait_time": 1.0,
		"message_key": "move_fail.no_target",
	}


func _generic_fail_message(user: BattlePokemon) -> Dictionary:
	return {
		"type": "wait",
		"text": "¡El ataque %s falló!" % user.get_battle_possessive_name(),
		"wait_time": 1.0,
		"message_key": "move_fail.generic",
	}
