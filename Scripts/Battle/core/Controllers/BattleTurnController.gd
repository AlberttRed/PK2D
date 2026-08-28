extends Node

class_name BattleTurnController

signal turn_finished(turn_number: int)

var battle_controller: BattleController

var current_turn := 0
var collected_choices: Array[BattleChoice] = []
var last_ordered_choices: Array[BattleChoice] = []
## Spots que necesitan cambio forzado tras KO (Gen 4+: se resuelven al final del turno).
## Cada entrada: { "side": BattleSide, "spot": BattleSpot, "fainted": BattlePokemon }
var _pending_forced_switches: Array[Dictionary] = []
## EXP de rivales debilitados (también al final del turno, con los reemplazos).
## Cada entrada: { "fainted": BattlePokemon, "executor": BattlePokemon }
var _pending_exp_grants: Array[Dictionary] = []

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

		await check_and_show_fainted(actor)

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
		var speed = actor.get_effective_speed()
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
	var speed_a: int = a.pokemon.get_effective_speed() if a.pokemon != null else 0
	var speed_b: int = b.pokemon.get_effective_speed() if b.pokemon != null else 0

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

	# Animación del move una sola vez con todos los targets (multi-hit la gestiona MultiHitHandler).
	if not _has_multi_hit_handler(handlers):
		await BattleMoveHandler.play_battle_animation_for_handlers(
			battle_controller.ui,
			handlers,
			choice.get_move(),
			choice.pokemon
		)

	# Por target: daño/efecto → si KO, faint inmediato (no dejar barras a 0 hasta el final).
	for h in handlers:
		await h.visualize(battle_controller.ui)
		await check_and_show_fainted(choice.pokemon)

	choice.pokemon.commit_move_usage(choice.get_move())
	await BattleEffectController.process_phase(
		choice.pokemon,
		BattleEffect.Phases.ON_AFTER_MOVE,
		BattlePhaseContext.for_move(choice.pokemon, choice)
	)


func _has_multi_hit_handler(handlers: Array[BattleHandler]) -> bool:
	for h in handlers:
		if h is MultiHitHandler:
			return true
	return false

func handle_switch_result(choice: BattleSwitchChoice, handlers: Array[BattleHandler]) -> void:
	for handler in handlers:
		handler.apply()

	for handler in handlers:
		await handler.visualize(battle_controller.ui)

	# Hazards al entrar (Púas / Trampa Rocas) pueden dejar HP a 0.
	await check_and_show_fainted(_exp_executor_after_switch(choice))


func _exp_executor_after_switch(choice: BattleSwitchChoice) -> BattlePokemon:
	# EXP del rival debilitado por hazards al entrar → Pokémon activo del jugador.
	var player_active := _first_living_active(battle_controller.player_side)
	if player_active != null:
		return player_active
	if choice != null and choice.pokemon != null and not choice.pokemon.is_fainted():
		return choice.pokemon
	return null


func _first_living_active(side: BattleSide) -> BattlePokemon:
	if side == null:
		return null
	for pokemon in side.get_active_pokemons():
		if pokemon != null and not pokemon.is_fainted():
			return pokemon
	return null


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
		# Residual (veneno, clima…): faint inmediato; EXP/reemplazos más abajo.
		await check_and_show_fainted(_first_living_active(battle_controller.player_side))
	# EXP de todos los KO del turno (y residuales), luego reemplazos.
	await resolve_pending_experience()
	if not battle_controller.finished:
		await resolve_pending_forced_switches()
	else:
		_pending_forced_switches.clear()
		_pending_exp_grants.clear()
	turn_finished.emit(current_turn)

func reset():
	# Limpiar estado del controlador de turnos para el siguiente combate
	current_turn = 0
	collected_choices.clear()
	last_ordered_choices.clear()
	_pending_forced_switches.clear()
	_pending_exp_grants.clear()

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

## Resuelve KOs en campo (anim + mensaje) y encola EXP + cambios forzados.
## EXP y reemplazos se aplican al final de turno (Gen 4+).
## exp_executor: quién se apunta la EXP de rivales debilitados (null = sin EXP).
func check_and_show_fainted(exp_executor: BattlePokemon = null) -> void:
	if battle_controller.enemy_side != null:
		for spot in battle_controller.enemy_side.battle_spots:
			await _resolve_faint_on_spot(spot, exp_executor)
	if battle_controller.player_side != null:
		for spot in battle_controller.player_side.battle_spots:
			await _resolve_faint_on_spot(spot, exp_executor)


func _resolve_faint_on_spot(spot: BattleSpot, exp_executor: BattlePokemon) -> void:
	if spot == null or spot.pokemon == null or not spot.pokemon.is_fainted():
		return
	var fainted := spot.pokemon
	var side := fainted.side
	await spot.play_faint_animation()
	# Tras el hundimiento: retirar sprite/HPBar antes del mensaje (como HGSS).
	BattleEffectController.clear_pokemon_effects(fainted)
	spot.remove_pokemon()
	await battle_controller.ui.show_faint_message(fainted)
	_queue_exp_after_enemy_faint(fainted, exp_executor)

	if battle_controller.battle_finished():
		_pending_forced_switches.clear()
		return
	if side == null or not side.has_any_pokemon_alive():
		return
	if spot.pokemon != null:
		return

	_queue_forced_switch_after_faint(side, spot, fainted)


func _queue_exp_after_enemy_faint(fainted: BattlePokemon, exp_executor: BattlePokemon) -> void:
	if fainted == null or exp_executor == null:
		return
	var side := fainted.side
	if side == null or side.type != BattleSide.Types.ENEMY:
		return
	_pending_exp_grants.append({
		"fainted": fainted,
		"executor": exp_executor,
	})


func resolve_pending_experience() -> void:
	while not _pending_exp_grants.is_empty():
		var entry: Dictionary = _pending_exp_grants.pop_front()
		var fainted: BattlePokemon = entry.get("fainted")
		var executor: BattlePokemon = entry.get("executor")
		if fainted == null or executor == null:
			continue
		await battle_controller.grant_experience_after_enemy_ko(fainted, executor)


func _queue_forced_switch_after_faint(
	side: BattleSide,
	spot: BattleSpot,
	fainted: BattlePokemon
) -> void:
	for entry in _pending_forced_switches:
		if entry.get("spot") == spot:
			return

	var participant: BattleParticipant = (
		fainted.participant if fainted != null else _get_side_participant(side)
	)
	# Multi: el lado puede seguir vivo por el aliado, pero ESTE entrenador puede no tener banca.
	if side != null and participant != null and not side.participant_has_healthy_bench(participant):
		return

	_pending_forced_switches.append({
		"side": side,
		"spot": spot,
		"fainted": fainted,
	})


func resolve_pending_forced_switches() -> void:
	_sort_pending_forced_switches()
	while not _pending_forced_switches.is_empty():
		if battle_controller.battle_finished():
			_pending_forced_switches.clear()
			return

		var entry: Dictionary = _pending_forced_switches.pop_front()
		var side: BattleSide = entry.get("side")
		var spot: BattleSpot = entry.get("spot")
		var fainted: BattlePokemon = entry.get("fainted")

		if spot == null or spot.pokemon != null:
			continue
		if side == null or not side.has_any_pokemon_alive():
			continue

		await _send_forced_switch_after_faint(side, spot, fainted)
		# Hazards al entrar pueden KO → faint + EXP encolada; repartir EXP antes del siguiente envío.
		await resolve_pending_experience()
		_sort_pending_forced_switches()


func _sort_pending_forced_switches() -> void:
	# Rival primero, luego jugador; dentro del lado, orden de spots.
	_pending_forced_switches.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var side_a: BattleSide = a.get("side")
		var side_b: BattleSide = b.get("side")
		var rank_a := 0 if (side_a != null and side_a.type == BattleSide.Types.ENEMY) else 1
		var rank_b := 0 if (side_b != null and side_b.type == BattleSide.Types.ENEMY) else 1
		if rank_a != rank_b:
			return rank_a < rank_b
		var spot_a: BattleSpot = a.get("spot")
		var spot_b: BattleSpot = b.get("spot")
		var idx_a := side_a.battle_spots.find(spot_a) if side_a != null else 0
		var idx_b := side_b.battle_spots.find(spot_b) if side_b != null else 0
		return idx_a < idx_b
	)


func _send_forced_switch_after_faint(
	side: BattleSide,
	spot: BattleSpot,
	fainted: BattlePokemon
) -> void:
	# Multi: el lado puede seguir vivo por el aliado, pero ESTE entrenador puede no tener banca.
	# Sin sustituto no abrir party (atraparía al jugador sin opciones).
	var participant: BattleParticipant = (
		fainted.participant if fainted != null else _get_side_participant(side)
	)
	if side != null and participant != null and not side.participant_has_healthy_bench(participant):
		return

	var choice: BattleSwitchChoice = null
	if fainted != null and fainted.controllable:
		choice = await battle_controller.ui.resolve_player_forced_switch_after_faint(side, spot, fainted)
		if battle_controller.battle_finished():
			return
	else:
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
