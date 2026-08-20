extends Node
class_name BattleMessageController

var AilmentMessages = BattleMessageAilment.new()
var AbilityMessages = BattleMessageAbility.new()
var WeatherMessages = BattleMessageWeather.new()
var FieldEffectMessages = BattleMessageFieldEffect.new()
var ItemMessages = BattleMessageItem.new()
var MoveFailMessages = BattleMessageMoveFail.new()
const FAMILY := MessageFamily.Values

func get_intro_messages(
	rules: BattleRules,
	player_pokemon: Array[BattlePokemon],
	enemy_pokemon: Array[BattlePokemon],
	player_trainers: Array[String],
	enemy_trainers: Array[String]) -> Array[Dictionary]:
	var messages: Array[Dictionary] = []

	# Validar que hay Pokemon disponibles
	if player_pokemon.is_empty():
		push_error("BattleMessageController.get_intro_messages(): player_pokemon está vacío. El player no tiene Pokemon disponibles para combatir.")
		# Retornar mensaje de error en lugar de array vacío
		messages.append({
			"type": "input",
			"text": "¡Error: El jugador no tiene Pokemon disponibles!",
			"showIconAtEnd": true
		})
		return messages

	if enemy_pokemon.is_empty():
		push_error("BattleMessageController.get_intro_messages(): enemy_pokemon está vacío. El trainer no tiene Pokemon disponibles para combatir.")
		# Retornar mensaje de error en lugar de array vacío
		messages.append({
			"type": "input",
			"text": "¡Error: El entrenador no tiene Pokemon disponibles!",
			"showIconAtEnd": true
		})
		return messages

	match rules.mode:
		BattleRules.BattleModes.SINGLE:
			if rules.type == BattleRules.BattleTypes.WILD:
				messages.append({
					"type": "input",
					"text": "¡Un " + enemy_pokemon[0].get_name() + " salvaje apareció!",
					"showIconAtEnd": true
				})
			else:
				var enemy = enemy_trainers[0] if not enemy_trainers.is_empty() else "Entrenador"
				messages.append({
					"type": "input",
					"text": "¡" + enemy + " quiere luchar!",
					"showIconAtEnd": true
				})
				messages.append(get_trainer_send_in_intro_message(
					enemy_pokemon[0].get_display_name(), enemy, 0
				))
			messages.append({
				"type": "display",
				"text": "¡Adelante, " + player_pokemon[0].get_name() + "!",
				"wait_time": 0.5
			})

		BattleRules.BattleModes.DOUBLE:
			if rules.type == BattleRules.BattleTypes.WILD:
				messages.append(_get_wild_double_appeared_message(enemy_pokemon))
			else:
				_append_trainer_double_enemy_intro_messages(
					messages, enemy_pokemon, enemy_trainers
				)

			_append_player_double_send_in_message(
				messages, player_pokemon, player_trainers
			)

	return messages


func _get_wild_double_appeared_message(enemy_pokemon: Array[BattlePokemon]) -> Dictionary:
	var text: String
	if enemy_pokemon.size() >= 2:
		text = "¡Un %s y un %s salvajes aparecieron!" % [
			enemy_pokemon[0].get_name(), enemy_pokemon[1].get_name()
		]
	else:
		text = "¡Un %s salvaje apareció!" % enemy_pokemon[0].get_name()
	return {"type": "input", "text": text, "showIconAtEnd": true}


func _append_trainer_double_enemy_intro_messages(
	messages: Array[Dictionary],
	enemy_pokemon: Array[BattlePokemon],
	enemy_trainers: Array[String]
) -> void:
	if enemy_trainers.size() == 1:
		messages.append({
			"type": "input",
			"text": "¡" + enemy_trainers[0] + " quiere luchar!",
			"showIconAtEnd": true
		})
		if enemy_pokemon.size() >= 2:
			messages.append(get_trainer_double_send_in_intro_message(
				enemy_pokemon[0].get_display_name(),
				enemy_pokemon[1].get_display_name(),
				enemy_trainers[0]
			))
		else:
			messages.append(get_trainer_send_in_intro_message(
				enemy_pokemon[0].get_display_name(), enemy_trainers[0], 0
			))
	elif enemy_trainers.size() >= 2:
		messages.append({
			"type": "input",
			"text": "¡" + enemy_trainers[0] + " y " + enemy_trainers[1] + " quieren luchar!",
			"showIconAtEnd": true
		})
		messages.append(get_trainer_send_in_intro_message(
			enemy_pokemon[0].get_display_name(), enemy_trainers[0], 0
		))
		if enemy_pokemon.size() >= 2:
			messages.append(get_trainer_send_in_intro_message(
				enemy_pokemon[1].get_display_name(), enemy_trainers[1], 1
			))


func _append_player_double_send_in_message(
	messages: Array[Dictionary],
	player_pokemon: Array[BattlePokemon],
	player_trainers: Array[String]
) -> void:
	var pokemon_names := _format_active_pokemon_names(player_pokemon)
	if player_trainers.size() == 1:
		messages.append({
			"type": "wait",
			"text": "¡Adelante, %s!" % pokemon_names,
			"wait_time": 0.5
		})
	elif player_trainers.size() >= 2:
		messages.append({
			"type": "wait",
			"text": "¡%s y %s enviaron a %s!" % [
				player_trainers[0], player_trainers[1], pokemon_names
			],
			"wait_time": 0.5
		})


func _format_active_pokemon_names(pokemon: Array[BattlePokemon]) -> String:
	if pokemon.size() >= 2:
		return "%s y %s" % [pokemon[0].get_name(), pokemon[1].get_name()]
	return pokemon[0].get_name()

func get_effectiveness_message(result: DamageEffect) -> Dictionary:
	if result.is_super_effective():
		return { "type": "wait", "text": "¡Es muy eficaz!", "wait_time": 1.0 }
	elif result.is_not_very_effective():
		return { "type": "wait", "text": "No es muy eficaz...", "wait_time": 1.0 }
	elif result.is_ineffective():
		return { "type": "wait", "text": "No afecta %s..." % result.target.get_battle_target_name(), "wait_time": 1.0 }

	return {}

func get_critical_hit_message() -> Dictionary:
	return { "type": "wait", "text": "¡Golpe crítico!", "wait_time": 1.0 }

func get_heal_message(pokemon: BattlePokemon) -> Dictionary:
	return {
		"type": "display",
		"text": "¡%s recuperó salud!" % [pokemon.get_battle_display_name(true)],
		"wait_time": 1.0
	}

func get_drain_message(target: BattlePokemon) -> Dictionary:
	return {
		"type": "display",
		"text": "¡%s ha perdido energía!" % [target.get_battle_display_name(true)],
		"wait_time": 1.0
	}


func get_used_item_message(item_data: ItemData) -> Dictionary:
	return ItemMessages.get_used_item_message(item_data)

func get_used_move_message(user: BattlePokemon, move: BattleMove) -> Dictionary:
	return {
		"type": "display",
		"text": "¡%s ha usado %s!" % [user.get_battle_display_name(true), move.get_name()],
		"wait_time": 0.5
	}


func get_no_moves_left_message(pokemon: BattlePokemon) -> Dictionary:
	if pokemon == null:
		return {}
	var subject := pokemon.get_battle_target_name()
	if not subject.is_empty():
		subject = subject[0].to_upper() + subject.substr(1)
	return {
		"type": "display",
		"text": "¡%s no le quedan movimientos!" % subject,
		"wait_time": 1.0,
	}


func get_struggle_recoil_message(pokemon: BattlePokemon) -> Dictionary:
	if pokemon == null:
		return {}
	return {
		"type": "display",
		"text": "¡%s se resiente del retroceso!" % pokemon.get_battle_display_name(true),
		"wait_time": 1.0,
	}

func get_start_ailment_message(
	user: BattlePokemon,
	ailment_id: AilmentsEnum.Values,
	related_pokemon: BattlePokemon = null,
	causing_move_id: int = 0
) -> Dictionary:
	if user == null:
		return {}
	return AilmentMessages.get_start_ailment_message(user, ailment_id, related_pokemon, causing_move_id)

func get_end_ailment_message(
	user: BattlePokemon,
	ailment_id: AilmentsEnum.Values,
	causing_move_id: int = 0
) -> Dictionary:
	if user == null:
		return {}
	return AilmentMessages.get_end_ailment_message(user, ailment_id, causing_move_id)

func get_already_ailment_message(user:BattlePokemon, ailment_id: AilmentsEnum.Values, has_other_status: bool) -> Dictionary:
	if user == null:
		return {}
	return AilmentMessages.get_already_ailment_message(user, ailment_id, has_other_status)

func get_ailment_effect_message(
	user: BattlePokemon,
	ailment_id: AilmentsEnum.Values,
	causing_move_id: int = 0
) -> Dictionary:
	if user == null:
		return {}
	return AilmentMessages.get_ailment_effect_message(user, ailment_id, causing_move_id)

func get_ailment_previous_effect_message(
	user: BattlePokemon,
	ailment_id: AilmentsEnum.Values,
	related_pokemon: BattlePokemon = null
) -> Dictionary:
	if user == null:
		return {}
	return AilmentMessages.get_ailment_previous_effect_message(user, ailment_id, related_pokemon)


func get_trap_block_switch_message(user: BattlePokemon) -> Dictionary:
	if user == null:
		return {}
	return AilmentMessages.get_trap_block_switch_message(user)


func get_perish_song_tick_message(user: BattlePokemon, counter: int) -> Dictionary:
	if user == null:
		return {}
	return AilmentMessages.get_perish_song_tick_message(user, counter)

func get_ability_effect_message(user:BattlePokemon, target:BattlePokemon, ability_id: AbilitiesEnum.Values) -> Dictionary:
	if user == null or target == null:
		return {}
	return AbilityMessages.get_ability_effect_message(user, target, ability_id)

func get_start_ability_message(user:BattlePokemon, ability_id: AbilitiesEnum.Values) -> Dictionary:
	if user == null:
		return {}
	return AbilityMessages.get_start_ability_message(user, ability_id)

func get_end_ability_message(user:BattlePokemon, ability_id: AbilitiesEnum.Values) -> Dictionary:
	if user == null:
		return {}
	return AbilityMessages.get_end_ability_message(user, ability_id)

func get_start_weather_message(weather_id: WeathersEnum.Values) -> Dictionary:
	if weather_id == WeathersEnum.Values.NONE:
		return {}
	return WeatherMessages.get_start_weather_message(weather_id)

func get_ongoing_weather_message(weather_id: WeathersEnum.Values) -> Dictionary:
	if weather_id == WeathersEnum.Values.NONE:
		return {}
	return WeatherMessages.get_ongoing_weather_message(weather_id)

func get_end_weather_message(weather_id: WeathersEnum.Values) -> Dictionary:
	if weather_id == WeathersEnum.Values.NONE:
		return {}
	return WeatherMessages.get_end_weather_message(weather_id)

func get_already_active_weather_message() -> Dictionary:
	return WeatherMessages.get_already_active_weather_message()

func get_weather_residual_damage_message(
	weather_id: WeathersEnum.Values,
	pokemon: BattlePokemon
) -> Dictionary:
	if weather_id == WeathersEnum.Values.NONE or pokemon == null:
		return {}
	return WeatherMessages.get_residual_damage_message(weather_id, pokemon)

func get_start_field_effect_message(effect_id: FieldEffectsEnum.Values, side: BattleSide = null) -> Dictionary:
	if effect_id < 0:
		return {}
	return FieldEffectMessages.get_start_field_effect_message(effect_id, side)

func get_end_field_effect_message(effect_id: FieldEffectsEnum.Values, side: BattleSide = null) -> Dictionary:
	if effect_id < 0:
		return {}
	return FieldEffectMessages.get_end_field_effect_message(effect_id, side)

func get_already_active_field_effect_message() -> Dictionary:
	return FieldEffectMessages.get_already_active_field_effect_message()

func get_mist_stat_block_message(pokemon: BattlePokemon) -> Dictionary:
	return FieldEffectMessages.get_mist_stat_block_message(pokemon)

func get_spikes_damage_message(pokemon: BattlePokemon) -> Dictionary:
	return FieldEffectMessages.get_spikes_damage_message(pokemon)

func get_toxic_spikes_absorbed_message(pokemon: BattlePokemon) -> Dictionary:
	return FieldEffectMessages.get_toxic_spikes_absorbed_message(pokemon)

func get_badly_poisoned_message(pokemon: BattlePokemon) -> Dictionary:
	return AilmentMessages.get_badly_poisoned_message(pokemon)

# ============================================================================
# Unificado: helpers por familia (limpia BattleUI)
# ============================================================================

func get_start_effect_message(
	family: MessageFamily.Values,
	user: BattlePokemon = null,
	source: int = 0,
	side: BattleSide = null,
	related_pokemon: BattlePokemon = null,
	causing_move_id: int = 0
) -> Dictionary:
	match family:
		FAMILY.AILMENT:
			return get_start_ailment_message(user, source, related_pokemon, causing_move_id)
		FAMILY.ABILITY:
			return get_start_ability_message(user, source)
		FAMILY.WEATHER:
			return get_start_weather_message(source)
		FAMILY.FIELD_EFFECT:
			return get_start_field_effect_message(source, side)
		_:
			return {}

func get_effect_message(
	family: MessageFamily.Values,
	user: BattlePokemon = null,
	source: int = 0,
	causing_move_id: int = 0
) -> Dictionary:
	match family:
		FAMILY.AILMENT:
			return get_ailment_effect_message(user, source, causing_move_id)
		FAMILY.ABILITY:
			return get_ability_effect_message(user, null, source)
		FAMILY.WEATHER:
			return get_ongoing_weather_message(source)
		FAMILY.FIELD_EFFECT:
			return {}
		_:
			return {}

func get_end_effect_message(
	family: MessageFamily.Values,
	user: BattlePokemon = null,
	source: int = 0,
	side: BattleSide = null,
	causing_move_id: int = 0
) -> Dictionary:
	match family:
		FAMILY.AILMENT:
			return get_end_ailment_message(user, source, causing_move_id)
		FAMILY.ABILITY:
			return get_end_ability_message(user, source)
		FAMILY.WEATHER:
			return get_end_weather_message(source)
		FAMILY.FIELD_EFFECT:
			return get_end_field_effect_message(source, side)
		_:
			return {}

func get_already_effect_message(family: MessageFamily.Values, user: BattlePokemon = null, source: int = 0, has_other_status: bool = false) -> Dictionary:
	match family:
		FAMILY.AILMENT:
			return get_already_ailment_message(user, source, has_other_status)
		FAMILY.WEATHER:
			return get_already_active_weather_message()
		FAMILY.FIELD_EFFECT:
			return get_already_active_field_effect_message()
		_:
			return {}

func get_previous_effect_message(
	family: MessageFamily.Values,
	user: BattlePokemon = null,
	source: int = 0,
	related_pokemon: BattlePokemon = null
) -> Dictionary:
	match family:
		FAMILY.AILMENT:
			return get_ailment_previous_effect_message(user, source, related_pokemon)
		_:
			return {}

func get_stat_stage_change_message(pokemon: BattlePokemon, stat: StatsEnum.Values, amount: int, applied: bool) -> Dictionary:
	if amount == 0:
		return {}

	var _name := pokemon.get_battle_display_name()
	var stat_name := StatsEnum.get_display_name(stat)
	var verb := ""
	var msg := ""

	if amount > 1:
		verb = "subió mucho" if applied else "no puede subir más"
	elif amount == 1:
		verb = "subió" if applied else "no puede subir más"
	elif amount < -1:
		verb = "bajó mucho" if applied else "no puede bajar más"
	elif amount == -1:
		verb = "bajó" if applied else "no puede bajar más"

	msg =  "¡%s %s %s!" % [stat_name, pokemon.get_battle_possessive_name(), verb]

	return {
		"type": "display",
		"text": msg,
		"wait_time": 0.5
	}

func get_generic_stat_stage_failed_message(pokemon: BattlePokemon, is_increase: bool) -> Dictionary:
	var verb := "subir" if is_increase else "bajar"
	var msg := "¡Las características %s no pueden %s más!" % [pokemon.get_battle_possessive_name(), verb]

	return {
		"type": "display",
		"text": msg,
		"wait_time": 0.5
	}

# (El bloque duplicado de agregadores por familia fue consolidado en los métodos anteriores)

func get_move_fail_message(
	hit_result: HitResult.Values,
	user: BattlePokemon,
	move: BattleMove = null,
	target: BattleTarget = null
) -> Dictionary:
	if user == null:
		return {}
	return MoveFailMessages.get_move_fail_message(hit_result, user, move, target)


func get_fail_effect_message(
	family: MessageFamily.Values,
	user: BattlePokemon = null,
	hit_result: int = 0,
	move: BattleMove = null,
	target: BattleTarget = null
) -> Dictionary:
	match family:
		FAMILY.MOVE_FAIL:
			return get_move_fail_message(hit_result, user, move, target)
		_:
			return {}


func get_failed_move_message(user: BattlePokemon) -> Dictionary:
	return get_move_fail_message(HitResult.Values.MISS_GLOBAL, user)

func get_multi_hit_message(num_hits: int) -> Dictionary:
	return {
		"type": "wait",
		"text": "N.º de golpes: %d." % num_hits,
		"wait_time": 1.0
	}

func get_faint_message(pokemon: BattlePokemon) -> Dictionary:
	return {
		"type": "input",
		"text": "¡%s se debilitó!" % pokemon.get_battle_display_name(true), #Validado HGSS
		"showIconAtEnd": true
	}


func get_use_next_pokemon_prompt_text() -> String:
	return "¿Usas el siguiente Pokémon?"


func get_faint_refuse_flee_failed_message() -> Dictionary:
	return {
		"type": "input",
		"text": "¡No puedes huir!",
		"showIconAtEnd": true
	}


func get_opponent_next_pokemon_message(pokemon_name: String, trainer_name: String) -> Dictionary:
	return {
		"type": "input",
		"text": "¡%s será el próximo POKéMON de %s!" % [pokemon_name, trainer_name],
		"showIconAtEnd": true
	}


func get_trainer_send_in_display_message(pokemon_name: String, trainer_name: String) -> Dictionary:
	return {
		"type": "display",
		"text": "¡%s es el POKéMON enviado por %s!" % [pokemon_name, trainer_name],
		"wait_time": 1.2
	}


func get_trainer_send_in_intro_message(
	pokemon_name: String,
	trainer_name: String,
	enemy_spot_index: int
) -> Dictionary:
	var msg := get_trainer_send_in_display_message(pokemon_name, trainer_name)
	msg["trainer_send_in"] = true
	msg["enemy_spot_index"] = enemy_spot_index
	return msg


func get_trainer_double_send_in_display_message(
	pokemon_a: String,
	pokemon_b: String,
	trainer_name: String
) -> Dictionary:
	return {
		"type": "display",
		"text": "¡%s y %s son la opción de %s!" % [pokemon_a, pokemon_b, trainer_name],
		"wait_time": 1.4
	}


func get_trainer_double_send_in_intro_message(
	pokemon_a: String,
	pokemon_b: String,
	trainer_name: String
) -> Dictionary:
	var msg := get_trainer_double_send_in_display_message(pokemon_a, pokemon_b, trainer_name)
	msg["trainer_send_in"] = true
	msg["trainer_send_in_double"] = true
	return msg


func get_gained_exp_message(battle_pokemon: BattlePokemon, exp_gained: int) -> Dictionary:
	return {
		"type": "input",
		"text": "¡%s ha ganado %d Puntos de Experiencia!" % [battle_pokemon.get_name(), exp_gained],
		"showIconAtEnd": true
	}


func get_level_up_message(battle_pokemon: BattlePokemon, new_level: int) -> Dictionary:
	return {
		"type": "input",
		"text": "¡%s subió al nivel %d!" % [battle_pokemon.get_name(), new_level],
		"showIconAtEnd": true
	}


func get_no_target_message(user: BattlePokemon) -> Dictionary:
	return get_move_fail_message(HitResult.Values.NO_TARGET, user)

# Mensaje de escape/huida unificado
func get_escape_message(is_trainer_battle: bool, escape_succeeded: bool) -> Dictionary:
	if is_trainer_battle:
		return {
			"type": "wait",
			"text": "¡No puedes huir de un combate contra un Entrenador!", #Validado HGSS
			"wait_time": 1.5
		}
	elif escape_succeeded:
		return {
			"type": "input",
			"text": "¡Escapaste sin problemas!", #Validado HGSS
			"showIconAtEnd": true
		}
	else:
		return {
			"type": "wait",
			"text": "¡No puedes escapar!",
			"wait_time": 1.5
		}

# Mensajes de cambio de Pokémon
func get_switch_message(trainer_name: String, pokemon_name: String) -> Dictionary:
	return {
		"type": "wait",
		"text": "¡%s envió a %s!" % [trainer_name, pokemon_name],
		"wait_time": 1.2
	}

# Mensajes de final de combate
func get_battle_end_message(winner_side: String, rules: BattleRules, enemy_participants: Array) -> Dictionary:
	match winner_side:
		"capture":
			return {}
		"player":
			# En combates salvajes, no se muestra mensaje al ganar
			if rules.type == BattleRules.BattleTypes.WILD:
				return {}
			# En combates contra entrenadores, mostrar mensaje de victoria
			else:
				# Extraer nombres de los participantes
				var enemy_trainer_names: Array[String] = []
				for participant in enemy_participants:
					if participant is BattleParticipant:
						enemy_trainer_names.append(participant.name)

				var trainer_text = ""
				if enemy_trainer_names.size() == 1:
					trainer_text = enemy_trainer_names[0]
				elif enemy_trainer_names.size() == 2:
					trainer_text = enemy_trainer_names[0] + " y " + enemy_trainer_names[1]
				else:
					trainer_text = "el entrenador"

				return {
					"type": "input",
					"text": "¡Has vencido a %s!" % trainer_text,
					"showIconAtEnd": true
				}
		"enemy":
			return {
				"type": "input",
				"text": "Te has quedado sin Pokémon. Has perdido el combate.",
				"showIconAtEnd": true
			}
		"draw":
			return {
				"type": "input",
				"text": "¡El combate terminó en empate!",
				"showIconAtEnd": true
			}
		_:
			return {
				"type": "input",
				"text": "El combate ha terminado.",
				"showIconAtEnd": true
			}
