extends Node

class_name BattleTurnController

var battle_controller: BattleController

var current_turn := 0
var collected_choices: Array[BattleChoice] = []

func start_turn_loop():
	for pokemon in battle_controller.get_all_active_pokemon():	
		await BattleEffectController.process_phase(pokemon, BattleEffect.Phases.ON_ENTRY)
	while not battle_controller.battle_finished():
		await new_turn()
		await select_actions()
		await execute_turn()
		await end_turn()

	await battle_controller.end_battle()

func new_turn():
	current_turn += 1
	#battle_controller.new_turn.emit()
	#battle_ui.actions_menu.hide()  # o mostrar algo específico si lo necesitas

func select_actions():
	collected_choices.clear()
	print_stat_stages_log()
	print_active_effects_log()
	# Recorremos todos los BattleSpots activos en ambos lados del combate
	for spot:BattleSpot in battle_controller.get_active_battle_spots():
		var p:BattlePokemon = spot.get_active_pokemon()
		p.init_turn()

		if p.controllable:
			var choice = await battle_controller.ui.show_action_menu_for(p)
			p.selectedBattleChoice = choice
		else:
			var participant = p.participant  # o como lo tengas enlazado
			p.selectedBattleChoice = await participant.decide_action_for(p)
		if p.selectedBattleChoice != null:
			collected_choices.append(p.selectedBattleChoice)
			
func execute_turn():
	var ordered_choices:Array[BattleChoice] = order_choices(collected_choices)
	var results: Dictionary = {} # key: BattleChoice, value: BattleMoveResult
	
	#Calculamos y resolvemos las acciones seleccionadas por cada pokémon activo
	for choice:BattleChoice in ordered_choices:
		if choice.pokemon.is_fainted():
			continue
		var move_result = await choice.resolve()
		results[choice] = move_result
	
	print_turn_debug_log(ordered_choices, results)
	
	# Mostrar animaciones y efectos tras resolver todo
	for choice in ordered_choices:
		if results.has(choice):
			await handle_result(choice, results[choice])
	
	# Aplicar efectos de fin de turno
	await BattleEffectController.process_global_phase(BattleEffect.Phases.ON_END_BATTLE_TURN)
	
func order_choices(battle_choices: Array[BattleChoice]) -> Array[BattleChoice]:
	battle_choices.sort_custom(_sort_choices)
	print(">>> Orden de ejecución:")
	for choice:BattleChoice in battle_choices:
		var pkmn_name = choice.pokemon.get_name()
		var move_name = choice.get_move().get_name() if choice.get_move() != null else "Otra acción"
		print("- %s usará %s (velocidad: %d)" % [
			pkmn_name, move_name, choice.pokemon.get_speed()
		])
	return battle_choices
	


func _sort_choices(a: BattleChoice, b: BattleChoice) -> bool:
	# 1. Prioridad
	if a.get_priority() != b.get_priority():
		return a.get_priority() > b.get_priority()

	# 2. Velocidad
	var speed_a = a.pokemon.get_speed()
	var speed_b = b.pokemon.get_speed()

	if speed_a != speed_b:
		return speed_a > speed_b

	# 3. Desempate aleatorio
	return randi() % 2 == 0

func handle_result(choice: BattleChoice, result) -> void:
	if choice is BattleMoveChoice:
		await handle_move_result(choice, result)

	# elif choice is BattleSwitchChoice:
	#	await handle_switch_result(choice, result)

	# BattleItemChoice:
	# 	await handle_item_result(choice, result)

	# BattleRunChoice:
	# 	await handle_run_result(choice, result)
	else:
		push_warning("handle_result: tipo de choice no reconocido o aún no implementado.")
		
	await BattleEffectController.process_phase(choice.pokemon, BattleEffect.Phases.ON_END_POKEMON_TURN)

#
func handle_move_result(choice: BattleMoveChoice, result: BattleMoveResult) -> void:

	# Aplicar y visualizar efectos previos al movimiento (como confusión, paralizado)
	await BattleEffectController.process_phase(choice.pokemon, BattleEffect.Phases.ON_BEFORE_MOVE)

	if(!choice.pokemon.can_act_this_turn):
		return

	await battle_controller.ui.show_used_move_message(choice.pokemon, choice.get_move())
	
	for effect in result.effects:
		effect.apply()
	for effect in result.effects:
		print("visualize " + choice.get_move().get_name())
		await effect.visualize(battle_controller.ui)
		
	# Aplicar y visualizar efectos posteriores al movimiento (como veneno, quemadura)
	await BattleEffectController.process_phase(choice.pokemon, BattleEffect.Phases.ON_AFTER_MOVE)

	#var user = choice.pokemon
	#var move = choice.get_move()
	#var message_controller:= battle_controller.get_message_controller()
#
	#var used_msg := message_controller.get_used_move_message(move, user)
	#await battle_controller.show_message_from_dict(used_msg)
#
	## ⚠️ Animación general del movimiento (comentado por ahora)
	## await animation_controller.play_move_animation(user, move, result.targets)
#
	#if result.missed:
		#var missed_target := result.targets[0].get_active_pokemon()
		#var msg:Dictionary = message_controller.get_failed_move_message(user)
		#await battle_controller.show_message_from_dict(msg)
		#return
#
#
	#for spot:BattleSpot in result.targets:
		#var pokemon := spot.get_active_pokemon()
		#var dmg_list = result.get_damage_results_for(pokemon)#result.damage_results.get(pokemon, [])
#
		#for dmg in dmg_list:
			## ⚠️ Animación de golpe (se deberá mover al AnimationController)
			#await spot.play_hit_animation()
#
#
			## ⚠️ Reducción visual de HP 
			#await spot.apply_damage(dmg)
#
			## Mostrar mensajes (eficacia, crítico...)
			#for msg in message_controller.get_damage_result_messages(choice, dmg, pokemon):
				#await battle_controller.show_message_from_dict(msg)
#
		#if dmg_list.size() > 1:
			#var multi_hit_msg := message_controller.get_multi_hit_message(dmg_list.size())
			#await battle_controller.show_message_from_dict(multi_hit_msg)
#
		#if pokemon.get_hp() == 0:
			#var faint_msg := message_controller.get_faint_message(pokemon)
			#await battle_controller.show_message_from_dict(faint_msg)
#
			## ⚠️ Animación de debilitamiento (comentado por ahora)
			## await animation_controller.play_faint_animation(pokemon)


func end_turn():
	pass
	# Aquí iría lógica futura de efectos, clima, estados...
	#await battle_controller.end_turn()
	
func print_turn_debug_log(choices: Array[BattleChoice], results: Dictionary) -> void:
	for choice in choices:
		if choice is BattleMoveChoice and results.has(choice):
			var result = results[choice]
			if not result.has_method("effects"):
				continue

			var effects: Array = result.effects
			var user := choice.pokemon.get_name()
			var move = choice.get_move().get_name()

			if effects.size() == 1 and effects[0] is MissEffect:
				var missed_target = effects[0].target.get_name()
				print("%s usará %s contra %s pero fallará." % [user, move, missed_target])
			else:
				var grouped := {}

				for effect in effects:
					var inner_effects = effect.sub_effects if effect.has("sub_effects") else [effect]

					for e in inner_effects:
						if e is DamageEffect:
							var t = e.target
							if not grouped.has(t):
								grouped[t] = { "damage": 0, "healing": 0 }
							grouped[t].damage += e.amount
						#elif e is HealEffect:
							#var t = e.target
							#if not grouped.has(t):
								#grouped[t] = { "damage": 0, "healing": 0 }
							#grouped[t].healing += e.amount

				for target in grouped.keys():
					var tname = target.get_name()
					var entry = grouped[target]
					if entry.damage > 0:
						print("%s usará %s contra %s e infligirá %d de daño." % [user, move, tname, entry.damage])
					if entry.healing > 0:
						print("%s usará %s y curará %d PS a %s." % [user, move, entry.healing, tname])

func print_active_effects_log():
	print("====== Battle Effects Log ======")
	print("Field Effects:")
	var field_effects = BattleEffectController.get_field_effects()
	if field_effects.is_empty():
		print("   (sin efectos de Campo)")
	else:
		for e in field_effects:
			var name = e.get_script().resource_path.get_file().get_basename()
			print("     · %s" % name)

	for spot in battle_controller.get_active_battle_spots():
		var pokemon = spot.get_active_pokemon()
		var team = pokemon.side.to_string()
		print("- %s [%s]" % [pokemon.get_name(), team])

		var pokemon_effects = BattleEffectController.get_pokemon_effects(pokemon)
		var side_effects = BattleEffectController.get_side_effects(pokemon)

		if pokemon_effects.is_empty():
			print("   (sin efectos Pokémon)")
		else:
			print("   Pokémon Effects:")
			for e in pokemon_effects:
				var name = e.get_script().resource_path.get_file().get_basename()
				print("     · %s" % name)

		if side_effects.is_empty():
			print("   (sin efectos de Side)")
		else:
			print("   Side Effects:")
			for e in side_effects:
				var name = e.get_script().resource_path.get_file().get_basename()
				print("     · %s" % name)

	print("================================")


func print_stat_stages_log() -> void:
	for spot in battle_controller.get_active_battle_spots():
		var pokemon = spot.get_active_pokemon()
		var name = pokemon.get_display_name()
		print("[Estadísticas modificadas para %s]" % name)

		var stages = pokemon.stat_stages
		var any_modified := false

		for stat in StatTypes.Stat.values():
			var stage = stages.get_stat(stat)
			if stage != 0:
				any_modified = true
				var icon = "↑" if stage > 0 else "↓"
				var stat_name = StatTypes.stat_to_string(stat).capitalize()
				print("  %s: %s %+d" % [stat_name, icon, stage])

		if not any_modified:
			print("  (Sin modificaciones activas)")
