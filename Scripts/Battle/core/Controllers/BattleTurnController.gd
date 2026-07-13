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
	await BattleEffectController.process_global_phase(BattleEffect.Phases.ON_BATTLE_START)
	while not battle_controller.battle_finished():
		await new_turn()
		await select_actions()
		await execute_turn()
		await end_turn()

	await battle_controller.end_battle()

func new_turn():
	current_turn += 1
	if not battle_controller.finished:
		await BattleEffectController.process_global_phase(BattleEffect.Phases.ON_INIT_BATTLE_TURN)

func select_actions():
	collected_choices.clear()
	print_stat_stages_log()
	print_active_effects_log()

	# Inicializar turnos en ambos sides (resetea flags y prepara el turno)
	if battle_controller.player_side:
		battle_controller.player_side.init_turn()
	if battle_controller.enemy_side:
		battle_controller.enemy_side.init_turn()

	# Recorremos todos los BattleSpots activos en ambos lados del combate
	for spot:BattleSpot in battle_controller.get_active_battle_spots():
		var selectedChoice:BattleChoice = null
		var p:BattlePokemon = spot.get_active_pokemon()
		p.init_turn()

		# Verificar si el side de este Pokémon ya tiene una acción bloqueante
		if p.side.has_blocking_action_this_turn:
			# Saltar selección, asignar acción de "pasar turno"
			selectedChoice = BattlePassChoice.new()
		elif p.controllable:
			selectedChoice = await battle_controller.ui.show_action_selection(p)

			if selectedChoice.canceled:
				await select_actions()
				return

			# Si es bloqueante, marcar el side
			if selectedChoice.is_blocking_action():
				p.side.has_blocking_action_this_turn = true

		elif !p.controllable:
			selectedChoice = await p.participant.decide_action_for(p)

			# También marcar si la IA elige una acción bloqueante
			if selectedChoice and selectedChoice.is_blocking_action():
				p.side.has_blocking_action_this_turn = true

		# Garantizar que cada Pokémon declara una acción
		if selectedChoice == null:
			selectedChoice = BattlePassChoice.new()

		# Asignar el choice al pokemon (el setter se encarga de asignar el pokemon al choice)
		p.selectedBattleChoice = selectedChoice

		collected_choices.append(selectedChoice)

func execute_turn():
	var ordered_choices:Array[BattleChoice] = order_choices(collected_choices)
	last_ordered_choices = ordered_choices
	var results: Dictionary = {} # key: BattleChoice, value: Array[BattleHandler]

	#Calculamos y resolvemos las acciones seleccionadas por cada pokémon activo
	for choice:BattleChoice in ordered_choices:
		if _should_skip_choice(choice):
			continue
		results[choice] = choice.resolve()

	print_turn_debug_log(ordered_choices, results)

	# Mostrar animaciones y efectos tras resolver todo (orden de velocidad)
	for choice in ordered_choices:
		if not results.has(choice):
			continue
		var actor: BattlePokemon = choice.pokemon
		# El rival puede haber caído antes de su turno (más rápido que él): no ejecutar ni revisar KO con actor nulo.
		if actor == null or actor.is_fainted():
			continue

		await BattleEffectController.process_phase(actor, BattleEffect.Phases.ON_INIT_POKEMON_TURN)
		await handle_result(choice, results[choice])

		await check_and_show_fainted_pokemon(actor)

		if battle_controller.battle_finished():
			break
		else:
			await BattleEffectController.process_phase(actor, BattleEffect.Phases.ON_END_POKEMON_TURN)

func order_choices(battle_choices: Array[BattleChoice]) -> Array[BattleChoice]:
	battle_choices.sort_custom(_sort_choices)
	print(">>> Orden de ejecución:")
	for choice:BattleChoice in battle_choices:
		var actor: BattlePokemon = choice.pokemon
		if actor == null:
			continue
		var pkmn_name = actor.get_name()
		var speed = actor.get_speed()
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



func _should_skip_choice(choice: BattleChoice) -> bool:
	var actor: BattlePokemon = choice.pokemon
	return actor == null or actor.is_fainted()


func _sort_choices(a: BattleChoice, b: BattleChoice) -> bool:
	# 1. Prioridad
	if a.get_priority() != b.get_priority():
		return a.get_priority() > b.get_priority()

	# 2. Velocidad
	var speed_a: int = a.pokemon.get_speed() if a.pokemon != null else 0
	var speed_b: int = b.pokemon.get_speed() if b.pokemon != null else 0

	if speed_a != speed_b:
		return speed_a > speed_b

	# 3. Desempate aleatorio determinista (como en los juegos originales)
	# Usamos un hash determinista que combina el turno actual con el hash del objeto del Pokémon
	# Esto simula aleatoriedad cada turno pero mantiene la transitividad durante la ordenación
	# El hash del objeto es único y determinista durante la ejecución
	var hash_a = hash(str(current_turn) + str(hash(a.pokemon)))
	var hash_b = hash(str(current_turn) + str(hash(b.pokemon)))
	return hash_a < hash_b

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

#
func handle_move_result(choice: BattleMoveChoice, handlers: Array[BattleHandler]) -> void:
	# Aplicar y visualizar efectos previos al movimiento (como confusión, paralizado, mofa)
	await BattleEffectController.process_phase(choice.pokemon, BattleEffect.Phases.ON_BEFORE_MOVE)

	if not choice.pokemon.can_act_this_turn:
		return

	# Otra Vez u otros efectos pueden haber cambiado el movimiento tras la resolución inicial.
	var refreshed := choice.resolve()
	if not refreshed.is_empty():
		handlers = refreshed

	await battle_controller.ui.show_used_move_message(choice.pokemon, choice.get_move())

	# Aplicar uno a uno revalidando justo antes de cada apply(),
	# ya que handlers anteriores pueden debilitar objetivos de los siguientes
	for i in handlers.size():
		var h: BattleHandler = handlers[i]
		if h is BattleMoveHandler and !h.ensure_valid_single_enemy_target_or_null():
			h = NoTargetHandler.new(choice.pokemon, choice.get_move())
			handlers[i] = h
		h.apply()

	for h in handlers:
		await h.visualize(battle_controller.ui)

	choice.pokemon.commit_move_usage(choice.get_move())
	await BattleEffectController.process_phase(
		choice.pokemon,
		BattleEffect.Phases.ON_AFTER_MOVE,
		BattlePhaseContext.for_move(choice.pokemon, choice)
	)

func handle_switch_result(_choice: BattleSwitchChoice, handlers: Array[BattleHandler]) -> void:
	for handler in handlers:
		handler.apply()

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

func end_turn():
	if not battle_controller.finished:
		await BattleEffectController.process_global_phase(BattleEffect.Phases.ON_END_BATTLE_TURN)
		await check_and_show_fainted_after_residual_effects()
	turn_finished.emit(current_turn)

func reset():
	# Limpiar estado del controlador de turnos para el siguiente combate
	current_turn = 0
	collected_choices.clear()
	last_ordered_choices.clear()

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

		for stat in StatsEnum.Values.values():
			var stage = stages.get_stat(stat)
			if stage != 0:
				any_modified = true
				var icon = "↑" if stage > 0 else "↓"
				var stat_name = StatsEnum.get_display_name(stat).capitalize()
				print("  %s: %s %+d" % [stat_name, icon, stage])

		if not any_modified:
			print("  (Sin modificaciones activas)")

func check_and_show_fainted_pokemon(action_executor: BattlePokemon) -> void:
	var executor_side = action_executor.side
	var opponent_side = action_executor.get_opponent_side()

	for spot in opponent_side.battle_spots:
		await _resolve_faint_on_spot(spot, action_executor, true)

	for spot in executor_side.battle_spots:
		await _resolve_faint_on_spot(spot, action_executor, false)


func check_and_show_fainted_after_residual_effects() -> void:
	if battle_controller.enemy_side != null:
		for spot in battle_controller.enemy_side.battle_spots:
			await _resolve_faint_on_spot(spot, null, true)
	if battle_controller.player_side != null:
		for spot in battle_controller.player_side.battle_spots:
			await _resolve_faint_on_spot(spot, null, false)


func _resolve_faint_on_spot(
	spot: BattleSpot,
	exp_executor: BattlePokemon,
	grant_exp: bool
) -> void:
	if spot == null or spot.pokemon == null or not spot.pokemon.is_fainted():
		return
	var fainted := spot.pokemon
	var side := fainted.side
	await spot.play_faint_animation()
	await battle_controller.ui.show_faint_message(fainted)
	if grant_exp:
		await battle_controller.grant_experience_after_enemy_ko(fainted, exp_executor)
	BattleEffectController.clear_pokemon_effects(fainted)
	spot.remove_pokemon()

	if battle_controller.battle_finished():
		return
	if side == null or not side.has_any_pokemon_alive():
		return
	if spot.pokemon != null:
		return

	await _send_forced_switch_after_faint(side, spot, fainted)


func _send_forced_switch_after_faint(
	side: BattleSide,
	spot: BattleSpot,
	fainted: BattlePokemon
) -> void:
	var choice: BattleSwitchChoice = null
	if side.is_controllable():
		choice = await battle_controller.ui.resolve_player_forced_switch_after_faint(side, spot, fainted)
		if battle_controller.battle_finished():
			return
	else:
		var participant := _get_side_participant(side)
		if participant != null:
			choice = participant.decide_forced_switch_for(side, spot, fainted)
			if choice != null and _is_trainer_send_in_after_faint(side):
				await battle_controller.ui.handle_opponent_trainer_send_in_sequence(
					side, participant, choice
				)
				if battle_controller.battle_finished():
					return

	if choice == null:
		if side.escapedBattle or battle_controller.battle_finished():
			return
		push_warning("Forced switch: no se pudo elegir sustituto.")
		return

	var handlers := choice.resolve()
	if handlers.is_empty():
		push_warning("Forced switch: no se pudo resolver el cambio.")
		return
	await handle_switch_result(choice, handlers)


func _get_side_participant(side: BattleSide) -> BattleParticipant:
	if side == null or side.participants.is_empty():
		return null
	return side.participants[0]


func _is_trainer_send_in_after_faint(side: BattleSide) -> bool:
	if side == null or side.is_controllable():
		return false
	var rules := side.battle_rules
	if rules == null and battle_controller != null:
		rules = battle_controller.rules
	return rules != null and rules.type == BattleRules.BattleTypes.TRAINER
