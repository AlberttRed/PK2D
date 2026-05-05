class_name BattleMessageItem
extends RefCounted


func get_used_item_message(item_data: ItemData) -> Dictionary:
	if item_data == null:
		return {}
	return {
		"type": "display",
		"text": "¡Se usó el objeto %s!" % item_data.get_display_name(),
		"wait_time": 0.8,
	}


static func get_no_effect_text() -> String:
	return "No tendría ningún efecto."


static func get_revive_success_text(pokemon: Pokemon) -> String:
	if pokemon == null:
		return "¡Ya no está debilitado!"
	return "¡%s ya no está debilitado!" % pokemon.get_display_name()


static func get_status_heal_success_text(pokemon: Pokemon, cure_mode: int, cured_prev: int) -> String:
	if pokemon == null:
		return "¡Se curó!"
	match cure_mode:
		StatusHealItemEffect.CureMode.ALL_STATUS:
			return "%s se curó de todos los problemas de estado." % pokemon.get_display_name()
		_:
			if cured_prev == CONST.STATUS.PARALYSIS:
				return "%s se ha curado de la parálisis." % pokemon.get_display_name()
			if cured_prev == CONST.STATUS.SLEEP:
				return "¡%s se despertó!" % pokemon.get_display_name()
			if cured_prev == CONST.STATUS.POISON:
				return "¡%s se curó del veneno!" % pokemon.get_display_name()
			return "¡%s se curó!" % pokemon.get_display_name()
