class_name BattleResultDisplay

# Esta clase se encarga de mostrar los resultados visuales y mensajes tras ejecutar una acción.
# Se espera que esté instanciada o referenciada desde BattleUI.
var ui:BattleUI

#func display_move_result(result: BattleMoveResult, choice: BattleMoveChoice) -> void:
	##var message_controller = ui.message_controller
	#
	#await ui.show_used_move_message(choice.pokemon, choice.get_move())
#
	#if result.missed:
		#await ui.show_failed_move_message(choice.pokemon)
		#return
#
	#for impact in result.impact_results:
		#await display_impact_result(impact)
#
	#if result.inflicts_damage():
		#await ui.show_effectiveness_message(result)
#
	#if result.num_hits > 1:
		#await ui.show_multi_hit_message(result.num_hits)
#
#
#func display_move_result(result: BattleMoveResult, choice: BattleMoveChoice) -> void:
	#await ui.show_used_move_message(choice.pokemon, choice.get_move())
#
	#if result.missed:
		#await ui.show_failed_move_message(choice.pokemon)
		#return
#
	## Mostrar efectividad por cada target (una sola vez por target)
	#for spot in result.targets:
		#var target = spot.get_active_pokemon()
		#
		#for impact in result.get_impact_results_for(target):
			#await display_impact_result(impact)
#
		#if result.inflicts_damage():
			#await ui.show_effectiveness_message(result, target)
#
		#if result.is_multi_hit():
			#await ui.show_multi_hit_message(result.num_hits)
#
#
#func display_impact_result(impact: MoveImpactResult) -> void:
	#var spot:BattleSpot = impact.target.battle_spot
	#var message_controller = ui.message_controller
#
	#if impact is MoveImpactResult.Damage:
		#await spot.play_hit_animation()
		#await spot.apply_damage(impact)

		##for msg in message_controller.get_damage_result_messages(impact, impact.target):
			##await ui.show_message_from_dict(msg)
		#if impact.is_critical:
			#await ui.show_critical_hit_message()
#
	#elif impact is MoveImpactResult.Heal:
		##await spot.play_heal_animation()
		#await spot.apply_healing(impact.amount)
#
		#await ui.show_message_from_dict({
			#"text": "%s recuperó salud." % impact.target.get_name()
		#})
## TODO: implementar para cuando se realice un cambio de Pokémon
#func display_switch_result(result: BattleSwitchResult, choice: BattleSwitchChoice) -> void:
	#pass
#
## TODO: implementar si en el futuro se incluye usar objeto como acción principal
#func display_item_result(result: BattleItemResult, choice: BattleItemChoice) -> void:
	#pass
#
## TODO: implementar si en el futuro se permite escapar como acción principal
#func display_run_result(result: BattleRunResult, choice: BattleRunChoice) -> void:
	#pass
