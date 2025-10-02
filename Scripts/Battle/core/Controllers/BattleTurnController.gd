extends Node

class_name BattleTurnController

signal turn_finished(turn_number: int)

var battle_controller: BattleController

var current_turn := 0
var collected_choices: Array[BattleChoice] = []
var last_ordered_choices: Array[BattleChoice] = []

func _ready():
	randomize()

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
		var selectedChoice:BattleChoice = null
		var p:BattlePokemon = spot.get_active_pokemon()
		p.init_turn()

		if p.controllable and not _player_has_attempted_escape():
			selectedChoice = await battle_controller.ui.show_action_menu_for(p)
		elif !p.controllable:
			selectedChoice = await p.participant.decide_action_for(p)
		# Si es controlable pero ya se intentó escapar, selectedChoice queda null
		# y se asignará BattlePassChoice.new() más abajo

		# Garantizar que cada Pokémon declara una acción
		if selectedChoice == null:
			selectedChoice = BattlePassChoice.new()
		
		# Asignar el choice al pokemon (el setter se encarga de asignar el pokemon al choice)
		p.selectedBattleChoice = selectedChoice
		
		collected_choices.append(selectedChoice)

func _player_has_attempted_escape() -> bool:
	# Verificar si algún choice del jugador es un BattleRunChoice
	return collected_choices and collected_choices.filter(func(c): return c is BattleRunChoice).size() > 0
			
func execute_turn():
	var ordered_choices:Array[BattleChoice] = order_choices(collected_choices)
	last_ordered_choices = ordered_choices
	var results: Dictionary = {} # key: BattleChoice, value: Array[BattleHandler]
	
	#Calculamos y resolvemos las acciones seleccionadas por cada pokémon activo
	for choice:BattleChoice in ordered_choices:
		if choice.pokemon.is_fainted():
			continue
		results[choice] = choice.resolve()
	
	print_turn_debug_log(ordered_choices, results)
	
	# Mostrar animaciones y efectos tras resolver todo
	for choice in ordered_choices:
		if results.has(choice):
			await handle_result(choice, results[choice])
			# Si el combate terminó (por ejemplo, por escape exitoso), salir del bucle
			if battle_controller.finished:
				break
	
	# Aplicar efectos de fin de turno solo si el combate no ha terminado
	if not battle_controller.finished:
		await BattleEffectController.process_global_phase(BattleEffect.Phases.ON_END_BATTLE_TURN)
	
func order_choices(battle_choices: Array[BattleChoice]) -> Array[BattleChoice]:
	battle_choices.sort_custom(_sort_choices)
	print(">>> Orden de ejecución:")
	for choice:BattleChoice in battle_choices:
		var pkmn_name = choice.pokemon.get_name()
		var speed = choice.pokemon.get_speed()
		var action_desc := ""
		if choice is BattleMoveChoice and choice.get_move() != null:
			action_desc = "usará %s" % choice.get_move().get_name()
		elif choice is BattleSwitchChoice:
			action_desc = "cambiará de Pokémon"
		elif choice is BattleBagChoice:
			action_desc = "usará un objeto"
		elif choice is BattleRunChoice:
			action_desc = "intentará huir"
		elif choice.is_pass():
			action_desc = "pasará"
		else:
			action_desc = "realizará otra acción"
		print("- %s %s (velocidad: %d)" % [pkmn_name, action_desc, speed])
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

func handle_result(choice: BattleChoice, handlers: Array[BattleHandler]) -> void:
	if choice is BattleMoveChoice:
		await handle_move_result(choice, handlers)
	elif choice is BattleSwitchChoice:
		await handle_switch_result(choice, handlers)
	elif choice is BattleBagChoice:
		await handle_bag_result(choice, handlers)
	elif choice is BattleRunChoice:
		await handle_run_result(choice, handlers)
	else:
		push_warning("handle_result: tipo de choice no reconocido o aún no implementado.")
		
	await BattleEffectController.process_phase(choice.pokemon, BattleEffect.Phases.ON_END_POKEMON_TURN)

#
func handle_move_result(choice: BattleMoveChoice, handlers: Array[BattleHandler]) -> void:

	# Aplicar y visualizar efectos previos al movimiento (como confusión, paralizado)
	await BattleEffectController.process_phase(choice.pokemon, BattleEffect.Phases.ON_BEFORE_MOVE)

	if(!choice.pokemon.can_act_this_turn):
		return

	await battle_controller.ui.show_used_move_message(choice.pokemon, choice.get_move())
	
	for h in handlers:
		h.apply()
	for h in handlers:
		await h.visualize(battle_controller.ui)

func handle_switch_result(_choice: BattleSwitchChoice, handlers: Array[BattleHandler]) -> void:
	# Aplicar todos los handlers
	for handler in handlers:
		handler.apply()
	
	# Visualizar todos los handlers
	for handler in handlers:
		await handler.visualize(battle_controller.ui)

func handle_bag_result(_choice: BattleBagChoice, handlers: Array[BattleHandler]) -> void:
	# Aplicar todos los handlers
	for handler in handlers:
		handler.apply()
	
	# Visualizar todos los handlers
	for handler in handlers:
		await handler.visualize(battle_controller.ui)

func handle_run_result(choice: BattleRunChoice, handlers: Array[BattleHandler]) -> void:
	# Aplicar todos los handlers
	for handler in handlers:
		handler.apply()
	
	# Visualizar todos los handlers
	for handler in handlers:
		await handler.visualize(battle_controller.ui)
	
	# Si se escapó exitosamente, terminar el combate inmediatamente
	if choice.pokemon.side.escapedBattle:
		battle_controller.finished = true
		return  # No procesar efectos posteriores si se escapó
	
	# Si falló el escape, el Pokémon pierde el turno y no se procesan efectos posteriores
	# El turno pasa directamente al oponente

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
	turn_finished.emit(current_turn)
	# Aquí iría lógica futura de efectos, clima, estados...
	#await battle_controller.end_turn()

func get_execution_order() -> Array[BattleChoice]:
	return last_ordered_choices.duplicate()
	
func print_turn_debug_log(choices: Array[BattleChoice], results: Dictionary) -> void:
	for choice in choices:
		if results.has(choice):
			var handlers: Array[BattleHandler] = results[choice]
			var user: String = choice.pokemon.get_name()
			var action_desc := ""
			
			if choice is BattleMoveChoice and choice.get_move() != null:
				action_desc = "usará %s" % choice.get_move().get_name()
			elif choice is BattleSwitchChoice:
				action_desc = "cambiará de Pokémon"
			elif choice is BattleBagChoice:
				action_desc = "usará un objeto"
			elif choice is BattleRunChoice:
				action_desc = "intentará huir"
			elif choice.is_pass():
				action_desc = "pasará"
			else:
				action_desc = "realizará otra acción"
			
			if handlers.is_empty():
				continue
			print("%s resolverá %d handler(s) para %s" % [user, handlers.size(), action_desc])

func print_active_effects_log():
	print("====== Battle Effects Log ======")
	print("Field Effects:")
	var field_effects = BattleEffectController.get_field_effects()
	if field_effects.is_empty():
		print("   (sin efectos de Campo)")
	else:
		for e in field_effects:
			var effect_name = e.get_script().resource_path.get_file().get_basename()
			print("     · %s" % effect_name)

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
				var effect_name = e.get_script().resource_path.get_file().get_basename()
				print("     · %s" % effect_name)

		if side_effects.is_empty():
			print("   (sin efectos de Side)")
		else:
			print("   Side Effects:")
			for e in side_effects:
				var effect_name = e.get_script().resource_path.get_file().get_basename()
				print("     · %s" % effect_name)

	print("================================")


func print_stat_stages_log() -> void:
	for spot in battle_controller.get_active_battle_spots():
		var pokemon = spot.get_active_pokemon()
		var display_name = pokemon.get_display_name()
		print("[Estadísticas modificadas para %s]" % display_name)

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
