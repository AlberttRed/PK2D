extends Node
class_name BattleMessageController

var AilmentMessages = BattleMessageAilment.new()
var AbilityMessages = BattleMessageAbility.new()


func get_intro_messages(
	rules: BattleRules,
	player_pokemon: Array[BattlePokemon],
	enemy_pokemon: Array[BattlePokemon],
	player_trainers: Array[String],
	enemy_trainers: Array[String]) -> Array[Dictionary]:
	var messages: Array[Dictionary] = []

	match rules.mode:
		BattleRules.BattleModes.SINGLE:
			if rules.type == BattleRules.BattleTypes.WILD:
				messages.append({
					"type": "wait",
					"text": "¡Un " + enemy_pokemon[0].get_name() + " salvaje apareció!",
					"wait_time": 1.5
				})
			else:
				var enemy = enemy_trainers[0]
				messages.append({
					"type": "input",
					"text": "¡" + enemy + " quiere luchar!"
				})
				messages.append({
					"type": "wait",
					"text": "¡" + enemy + " envió a " + enemy_pokemon[0].get_name() + "!",
					"wait_time": 1.2
				})
			messages.append({
				"type": "wait",
				"text": "¡Adelante, " + player_pokemon[0].get_name() + "!",
				"wait_time": 0.5
			})

		BattleRules.BattleModes.DOUBLE:
			if rules.type == BattleRules.BattleTypes.WILD:
				messages.append({
					"type": "wait",
					"text": "¡Un " + enemy_pokemon[0].get_name() + " y un " + enemy_pokemon[1].get_name() + " salvajes aparecieron!",
					"wait_time": 1.5
				})
			else:
				if enemy_trainers.size() == 1:
					messages.append({
						"type": "input",
						"text": "¡" + enemy_trainers[0] + " quiere luchar!"
					})
					messages.append({
						"type": "wait",
						"text": "¡" + enemy_trainers[0] + " envió a " + enemy_pokemon[0].get_name() + " y " + enemy_pokemon[1].get_name() + "!",
						"wait_time": 1.4
					})
				elif enemy_trainers.size() == 2:
					messages.append({
						"type": "input",
						"text": "¡" + enemy_trainers[0] + " y " + enemy_trainers[1] + " quieren luchar!"
					})
					messages.append({
						"type": "wait",
						"text": "¡" + enemy_trainers[0] + " y " + enemy_trainers[1] + " enviaron a " + enemy_pokemon[0].get_name() + " y " + enemy_pokemon[1].get_name() + "!",
						"wait_time": 1.4
					})

			if player_trainers.size() == 1:
				messages.append({
					"type": "wait",
					"text": "¡Adelante, " + player_pokemon[0].get_name() + " y " + player_pokemon[1].get_name() + "!",
					"wait_time": 0.5
				})
			elif player_trainers.size() == 2:
				messages.append({
					"type": "wait",
					"text": "¡" + player_trainers[0] + " y " + player_trainers[1] + " enviaron a " + player_pokemon[0].get_name() + " y " + player_pokemon[1].get_name() + "!",
					"wait_time": 0.5
				})

	return messages

func get_effectiveness_message(result: DamageEffect) -> Dictionary:
	if result.is_super_effective():
		return { "type": "input", "text": "¡Es muy eficaz!" }
	elif result.is_not_very_effective():
		return { "type": "input", "text": "No es muy eficaz..." }
	elif result.is_ineffective():
		return { "type": "input", "text": "No afecta a %s..." % result.target.get_name() }
	
	return {}
	
func get_critical_hit_message() -> Dictionary:
	return { "type": "input", "text": "¡Golpe crítico!" }

func get_used_move_message(user: BattlePokemon, move: BattleMove) -> Dictionary:
	return {
		"type": "wait",
		"text": "¡%s ha usado %s!" % [user.get_name(), move.get_name()],
		"wait_time": 0.5
	}

func get_start_ailment_message(user:BattlePokemon, ailment:Ailment) -> Dictionary:
	return AilmentMessages.get_start_ailment_message(user, ailment)

func get_end_ailment_message(user:BattlePokemon, ailment:Ailment) -> Dictionary:
	return AilmentMessages.get_end_ailment_message(user, ailment)

func get_already_ailment_message(user:BattlePokemon, ailment:Ailment, has_other_status: bool) -> Dictionary:
	return AilmentMessages.get_already_ailment_message(user, ailment, has_other_status)

func get_ailment_effect_message(user:BattlePokemon, ailment:Ailment) -> Dictionary:
	return AilmentMessages.get_ailment_effect_message(user, ailment)

func get_ailment_previous_effect_message(user:BattlePokemon, ailment:Ailment) -> Dictionary:
	return AilmentMessages.get_ailment_previous_effect_message(user, ailment)
	
func get_ability_effect_message(user:BattlePokemon, target:BattlePokemon, ability:Ability) -> Dictionary:
	return AbilityMessages.get_ability_effect_message(user, target, ability)

func get_stat_stage_change_message(pokemon: BattlePokemon, stat: StatTypes.Stat, amount: int) -> Dictionary:
	if amount == 0:
		return {}

	var name := get_display_name(pokemon)
	var stat_name := get_stat_display_name(stat)
	var verb := ""
	var msg := ""

	if amount > 1:
		verb = "subió mucho"
	elif amount == 1:
		verb = "subió"
	elif amount < -1:
		verb = "bajó mucho"
	elif amount == -1:
		verb = "bajó"
	
	msg =  "¡%s %s %s!" % [stat_name, get_possessive_name(pokemon), verb]
	
	return {
		"type": "wait",
		"text": msg,
		"wait_time": 0.5
	}

func get_stat_display_name(stat: StatTypes.Stat) -> String:
	match stat:
		StatTypes.Stat.ATTACK: return "Ataque"
		StatTypes.Stat.DEFENSE: return "Defensa"
		StatTypes.Stat.SP_ATTACK: return "At. Esp."
		StatTypes.Stat.SP_DEFENSE: return "Def. Esp."
		StatTypes.Stat.SPEED: return "Velocidad"
		StatTypes.Stat.ACCURACY: return "Precisión"
		StatTypes.Stat.EVASION: return "Evasión"
		_: return "Estadística"

func get_failed_move_message(user: BattlePokemon) -> Dictionary:
	return {
		"type": "input",
		"text": "¡El ataque de %s falló!" % [user.get_name()]
	}
	
static func get_display_name(pokemon: BattlePokemon) -> String:
	if pokemon.controllable:
		return pokemon.get_display_name()
	elif pokemon.is_wild:
		return "el %s salvaje" % pokemon.get_name()
	else:
		return "el %s rival" % pokemon.get_name()

static func get_possessive_name(pokemon: BattlePokemon) -> String:
	if pokemon.controllable:
		return "de %s" % pokemon.get_display_name()
	elif pokemon.is_wild:
		return "del %s salvaje" % pokemon.get_name()
	else:
		return "del %s rival" % pokemon.get_name()

func get_multi_hit_message(num_hits: int) -> Dictionary:
	return {
		"type": "input",
		"text": "N.º de golpes: %d." % num_hits
	}

func get_faint_message(pokemon: BattlePokemon) -> Dictionary:
	return {
		"type": "input",
		"text": "%s se ha debilitado." % pokemon.nickname
	}
