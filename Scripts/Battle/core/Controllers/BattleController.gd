extends Node

class_name BattleController

const _BATTLE_EXPERIENCE := preload("res://Scripts/Battle/experience/ExperienceCalculator.gd")
const _BATTLE_LEVEL_GROWTH := preload("res://Scripts/Battle/experience/PokemonLevelGrowth.gd")

var ui: BattleUI
@onready var turn_controller: BattleTurnController = $TurnController
#var animation_controller: BattleAnimationControllerRefactor
#var effect_manager: BattleEffectPhaseManagerRefactor

var rules: BattleRules
var participants: Array = []
var player_side: BattleSide
var enemy_side: BattleSide
var sides: Array[BattleSide]

var finished := false
var winner_side: String = ""
## Resultado de captura exitosa (persistencia al cerrar combate).
var successful_capture: CaptureResult = null

func _ready():
	pass


## Pokémon del jugador que entra al terreno: enfrentamiento con todos los rivales vivos en campo.
func notify_player_entered_field(player_bp: BattlePokemon) -> void:
	if player_bp == null or not player_bp.controllable:
		return
	if enemy_side == null:
		return
	for spot in enemy_side.battle_spots:
		var e: BattlePokemon = spot.pokemon
		if e != null and not e.is_fainted():
			e.register_player_exp_participant(player_bp)


## Rival que entra al terreno: se asocian como participantes todos los aliados vivos en campo.
func notify_enemy_entered_field(enemy_bp: BattlePokemon) -> void:
	if enemy_bp == null or player_side == null:
		return
	for spot in player_side.battle_spots:
		var p: BattlePokemon = spot.pokemon
		if p != null and p.controllable and not p.is_fainted():
			enemy_bp.register_player_exp_participant(p)

# Configura los dos BattleSide con sus participantes y reglas
func setup_sides(player_participants: Array[BattleParticipant], enemy_participants: Array[BattleParticipant], _rules: BattleRules):
	self.player_side = BattleSide.new(BattleSide.Types.PLAYER)
	for p in player_participants:
		player_side.add_participant(p)
	player_side.prepare_for_battle(_rules)

	self.enemy_side = BattleSide.new(BattleSide.Types.ENEMY)
	for p in enemy_participants:
		enemy_side.add_participant(p)
	enemy_side.prepare_for_battle(_rules)

	self.sides = [player_side, enemy_side]
	assign_opponent_sides()

	self.rules = _rules

func assign_active_pokemons_to_spots():
	var player_actives = player_side.get_active_pokemons()
	var enemy_actives = enemy_side.get_active_pokemons()

	var player_spots: Array[BattleSpot] = ui.get_player_spots_for_mode(rules.mode)
	var enemy_spots: Array[BattleSpot] = ui.get_enemy_spots_for_mode(rules.mode)

	_connect_exp_signals_on_spots(player_spots)
	_connect_exp_signals_on_spots(enemy_spots)

	player_side.battle_spots.clear()
	enemy_side.battle_spots.clear()

	_assign_actives_to_spots(player_actives, player_spots, player_side)
	_assign_actives_to_spots(enemy_actives, enemy_spots, enemy_side)

	ui.position_battlespots_for_mode(rules.mode, player_actives.size(), enemy_actives.size())
	prepare_trainer_intro_field()


func _assign_actives_to_spots(
	actives: Array[BattlePokemon],
	spots: Array[BattleSpot],
	side: BattleSide
) -> void:
	for i in spots.size():
		var spot := spots[i]
		if i < actives.size():
			spot.visible = true
			spot.load_active_pokemon(actives[i], rules)
			spot.side = side
			side.battle_spots.append(spot)
		else:
			spot.remove_pokemon()
			spot.visible = false


func prepare_trainer_intro_field() -> void:
	## Oculta sprites hasta el send-in visual (ball throw + reveal).
	if player_side != null:
		for spot: BattleSpot in player_side.battle_spots:
			if spot == null:
				continue
			spot.set_pokemon_sprite_visible(false)
			if spot.hp_bar:
				spot.hp_bar.visible = false
	if rules == null or rules.type != BattleRules.BattleTypes.TRAINER:
		return
	if enemy_side == null:
		return
	for spot: BattleSpot in enemy_side.battle_spots:
		if spot == null:
			continue
		spot.set_pokemon_sprite_visible(false)
		if spot.hp_bar:
			spot.hp_bar.visible = false


func _connect_exp_signals_on_spots(spots: Array[BattleSpot]) -> void:
	for spot in spots:
		if spot == null:
			continue
		if spot.active_pokemon_loaded.is_connected(_on_battle_spot_active_pokemon_loaded):
			continue
		spot.active_pokemon_loaded.connect(_on_battle_spot_active_pokemon_loaded)


func _on_battle_spot_active_pokemon_loaded(bp: BattlePokemon) -> void:
	if bp == null:
		return
	if bp.controllable:
		notify_player_entered_field(bp)
	else:
		notify_enemy_entered_field(bp)


func start_battle() -> void:
	# Configurar UI para el nuevo combate
	BattleEffectController.set_ui(ui)
	BattleDebugEffectSeeder.try_apply(self)

	turn_controller.battle_controller = self
	# Inyectar lógica de targeting en la UI
	ui.target_selector = BattleTargetSelector.new()
	_mark_enemy_species_as_seen()
	print("Combate iniciado (test)")
	await ui.play_intro_sequence(rules,player_side.get_active_pokemons(),enemy_side.get_active_pokemons(),player_side.get_trainer_names(),enemy_side.get_trainer_names())
	await turn_controller.start_turn_loop()


## Marca como vistas todas las especies rivales presentes en el encuentro.
func _mark_enemy_species_as_seen() -> void:
	var pokedex = GameStateService.get_pokedex()
	if pokedex == null or enemy_side == null:
		return
	for participant in enemy_side.participants:
		if participant == null:
			continue
		for bp in participant.pokemon_team:
			if bp == null or bp.base_data == null:
				continue
			var species_id := int(bp.base_data.pokemon_id)
			var was_seen: bool = pokedex.is_seen(species_id)
			pokedex.mark_seen(species_id)
			if OS.is_debug_build() and not was_seen:
				print("Pokedex: especie %d vista por primera vez en combate." % species_id)


func get_active_battle_spots() -> Array[BattleSpot]:
	var spots: Array[BattleSpot] = []

	for side:BattleSide in [player_side, enemy_side]:
		for spot:BattleSpot in side.battle_spots:
			if spot.pokemon and not spot.pokemon.is_fainted():
				spots.append(spot)

	return spots

func get_all_active_pokemon() -> Array[BattlePokemon]:
	var result: Array[BattlePokemon] = []
	result.assign(get_active_battle_spots().map(func(spot: BattleSpot): return spot.pokemon))
	return result

func get_all_battle_spot_pokemon() -> Array[BattlePokemon]:
	# Devuelve TODOS los Pokémon en los battle spots, incluidos los debilitados
	var result: Array[BattlePokemon] = []
	for side: BattleSide in [player_side, enemy_side]:
		for spot: BattleSpot in side.battle_spots:
			if spot.pokemon:
				result.append(spot.pokemon)
	return result

func assign_opponent_sides():
	if sides.size() != 2:
		push_warning("assign_opponent_sides() requiere exactamente dos lados.")
		return

	sides[0].opponent_side = sides[1]
	sides[1].opponent_side = sides[0]

func register_successful_capture(capture_result: CaptureResult, target_bp: BattlePokemon = null) -> void:
	if capture_result == null or not capture_result.success:
		return
	successful_capture = capture_result
	finished = true
	winner_side = "capture"
	# La limpieza visual del rival se aplaza a tras la secuencia de captura (véase `apply_capture_field_cleanup`).


## Retira al salvaje del campo tras la animación/mensajes de captura (no en `apply()` del handler).
func apply_capture_field_cleanup(target_bp: BattlePokemon = null) -> void:
	_remove_captured_wild_from_field(target_bp)


func _remove_captured_wild_from_field(target_bp: BattlePokemon) -> void:
	if target_bp != null and target_bp.battle_spot != null:
		target_bp.battle_spot.remove_pokemon()
		return
	if enemy_side == null:
		return
	for spot in enemy_side.battle_spots:
		if spot != null and spot.pokemon != null and spot.pokemon.is_wild:
			spot.remove_pokemon()
			return


func battle_finished() -> bool:
	# Si ya se determinó el fin, no recalcular
	if finished:
		return true

	# Verificar si alguien ha escapado exitosamente
	if player_side.escapedBattle or enemy_side.escapedBattle:
		finished = true
		return true

	# Verificar si todos los Pokémon de algún lado están debilitados
	var player_alive := player_side.count_alive_pokemons()
	var enemy_alive := enemy_side.count_alive_pokemons()

	if player_alive == 0 or enemy_alive == 0:
		finished = true
		if player_alive == 0 and enemy_alive == 0:
			winner_side = "draw"
		elif player_alive == 0:
			winner_side = "enemy"
		else:
			winner_side = "player"

	return finished

func get_message_controller() -> BattleMessageController:
	return ui.message_controller

func end_battle() -> void:
	# Asegura que el estado final esté calculado
	if not finished:
		battle_finished()

	if winner_side == "capture" and successful_capture != null:
		await _finalize_successful_capture()

	if !winner_side.is_empty():
		# Mostrar mensaje de final de combate
		await ui.show_battle_end_message(winner_side, rules, enemy_side.participants)

	# NO ocultamos el UI aquí - lo manejará el GUI con las transiciones
	# La UI debe quedarse visible para que el fade funcione correctamente

	# Señal global con el resultado
	var result_msg := "Resultado del combate: desconocido"
	match winner_side:
		"player":
			result_msg = "Resultado del combate: gana Player"
		"enemy":
			result_msg = "Resultado del combate: gana Enemy"
		"draw":
			result_msg = "Resultado del combate: empate"
		"capture":
			result_msg = "Resultado del combate: captura exitosa"
	print(result_msg)

	# Guardar el ganador antes de limpiar el estado
	var battle_winner = winner_side

	# Registrar resultado del combate en GameStateService (solo para combates contra entrenadores)
	if rules.type == BattleRules.BattleTypes.TRAINER and not winner_side.is_empty() and winner_side != "draw":
		_register_battle_result(winner_side)

	_sync_player_runtime_from_battle()

	# Limpiar estado del combate para el siguiente
	_cleanup_battle_state()


	# Hacer esta función awaitable
	await get_tree().process_frame

	# Emitir con el ganador guardado (antes del cleanup)
	# SignalManager.battle_finished.emit(battle_winner)  # DEPRECATED
	# Emitir en DisplayManager en su lugar
	if DisplayManager.instance:
		DisplayManager.instance._on_battle_finished(battle_winner)

## Registra el resultado del combate en GameStateService
## p_winner_side: "player" o "enemy"
func _register_battle_result(p_winner_side: String) -> void:
	# Determinar el resultado para cada entrenador enemigo
	var result: String = "V" if p_winner_side == "player" else "D"

	# Registrar resultado para cada participante enemigo que sea entrenador
	for participant in enemy_side.participants:
		if participant is BattleParticipant and participant.is_trainer and not participant.is_player:
			var trainer_id = participant.trainer_resource_id
			print("BattleController: Registrando resultado para trainer_resource_id='%s', result='%s'" % [trainer_id, result])
			if not trainer_id.is_empty():
				GameStateService.register_trainer_battle_result(trainer_id, result)
			else:
				push_warning("BattleController: No se pudo registrar resultado - trainer_resource_id vacío para participante '%s'" % participant.name)

## Tras animación/mensaje de faint del rival; un KO → una llamada (multi-target puede ser 2 KOs seguidos).
func grant_experience_after_enemy_ko(defeated_enemy: BattlePokemon, action_executor: BattlePokemon) -> void:
	if defeated_enemy == null or rules == null:
		return
	var recipients: Array[BattlePokemon] = defeated_enemy.get_runtime_exp_recipient_battle_pokemon(action_executor)
	if recipients.is_empty():
		return
	var is_trainer := rules.type == BattleRules.BattleTypes.TRAINER
	var grant = _BATTLE_EXPERIENCE.grant_for_defeated_enemies([defeated_enemy], recipients, is_trainer)
	print("BattleController: EXP tras KO de %s — receptores=%d resultados=%d" % [
		defeated_enemy.get_name(), recipients.size(), grant.outcomes.size()
	])
	var level_ctx_by_bp: Dictionary = {}
	for rec_bp in recipients:
		if rec_bp == null or rec_bp.base_data == null:
			continue
		# PS del combate → runtime antes de subida de nivel (si no, hp_actual sigue el valor previo al combate).
		rec_bp.write_persistent_state_to_runtime()
		var lvl_result = _BATTLE_LEVEL_GROWTH.check_and_apply_level_up(rec_bp.base_data)
		level_ctx_by_bp[rec_bp] = lvl_result
		if lvl_result.levels_gained > 0:
			rec_bp.refresh_derived_stats_from_base()
			rec_bp.base_data._update_resource_name()

	for outcome in grant.outcomes:
		var po = outcome
		if po == null or po.battle_pokemon == null:
			continue
		var bp: BattlePokemon = po.battle_pokemon
		print("¡%s ha ganado %d Puntos de Experiencia!" % [bp.get_name(), po.gained_exp])
		if ui == null:
			continue
		await ui.show_gained_exp_message(bp, po.gained_exp)
		var lvl_res = level_ctx_by_bp.get(bp)
		var lv_before: int = bp.base_data.level
		var lv_gained: int = 0
		if lvl_res != null:
			lv_before = lvl_res.old_level
			lv_gained = lvl_res.levels_gained
		var spot: BattleSpot = bp.battle_spot
		var should_animate_exp_bar: bool = spot != null and spot.hp_bar != null and bp.in_battle \
			and spot.get_active_pokemon() == bp
		if should_animate_exp_bar:
			var old_total: int = po.new_total_exp - po.gained_exp
			# Durante la animación EXP, el nivel en pantalla debe seguir siendo el de antes hasta llenar el trozo actual.
			if lv_gained > 0:
				spot.hp_bar.refresh_panel_labels(lv_before)
			else:
				spot.hp_bar.refresh_panel_labels()
			var msg_cb := Callable()
			if lv_gained > 0 and lvl_res != null:
				msg_cb = func(cb_bp: BattlePokemon, reached_level: int) -> void:
					await ui.show_level_up_dialog_for_single_level(cb_bp, reached_level, lvl_res)
			await spot.hp_bar.animate_exp_bar_gain(old_total, po.new_total_exp, lv_before, lv_gained, msg_cb)
		elif lv_gained > 0 and lvl_res != null:
			await ui.show_level_up_dialog_sequence(bp, lvl_res)


func _sync_player_runtime_from_battle() -> void:
	for participant in player_side.participants:
		if participant == null or not participant.is_player:
			continue
		for bp in participant.pokemon_team:
			if bp:
				bp.write_persistent_state_to_runtime()
		_mirror_player_party_to_gamestate(participant)


## Party UI / guardado usan `GameStateService.party`; el combate usa el `Battler.party`.
## Si no comparten la misma instancia de `Pokemon`, copiamos PS / estado / PP por slot.
func _mirror_player_party_to_gamestate(participant: BattleParticipant) -> void:
	if participant == null:
		return
	var gs_party = GameStateService.get_party()
	if gs_party == null:
		return
	var team: Array[BattlePokemon] = participant.pokemon_team
	for i in range(team.size()):
		var bp: BattlePokemon = team[i]
		if bp == null or bp.base_data == null:
			continue
		var runtime_mon: Pokemon = bp.base_data
		if i >= gs_party.count():
			break
		var gs_mon: Pokemon = gs_party.get_pokemon(i)
		if gs_mon == null:
			continue
		if gs_mon == runtime_mon:
			continue
		var max_hp: int = gs_mon.get_final_stat(StatsEnum.Values.HP)
		gs_mon.hp_actual = clampi(runtime_mon.hp_actual, 0, max_hp)
		gs_mon.major_status = runtime_mon.major_status
		gs_mon.level = runtime_mon.level
		gs_mon.totalExp = runtime_mon.totalExp
		gs_mon.pending_evolution = runtime_mon.pending_evolution.duplicate()
		var n_moves: int = mini(gs_mon.movements.size(), runtime_mon.movements.size())
		for j in range(n_moves):
			var gs_mv: Move = gs_mon.movements[j] as Move
			var rt_mv: Move = runtime_mon.movements[j] as Move
			if gs_mv != null and rt_mv != null:
				gs_mv.pp_actual = clampi(rt_mv.pp_actual, 0, gs_mv.pp)


func _finalize_successful_capture() -> void:
	if successful_capture == null or successful_capture.captured_pokemon == null:
		return
	var registration: Dictionary = CaptureRegistrationService.register_captured_pokemon(
		successful_capture.captured_pokemon
	)
	var message: String = str(registration.get("message", ""))
	if message.is_empty():
		return
	await ui.show_message_from_dict({
		"type": "input",
		"text": message,
		"wait_time": 0.0,
		"showIconAtEnd": true,
	})


func _cleanup_battle_state():
	# Resetear flags de control
	finished = false
	winner_side = ""
	successful_capture = null

	# Resetear controlador de turnos
	turn_controller.reset()

	# Limpiar efectos persistentes
	BattleEffectController.reset_effects()


#func init_battle():
	## Configura elementos iniciales, como UI, animaciones de entrada, etc.
	#effect_manager.update_active_pokemon_effects(get_active_pokemon())
	#ui.setup_participants(participants)
	## Mostrar sprites, barras, etc.
	## Opcional: mostrar pokéballs, habilidades, clima...
#
#func loop_turns():
	#while not finished:
		#await effect_manager.apply_turn_start()
#
		#var turn := BattleTurn.new(get_active_pokemon())
		#await turn.collect_choices()
		#await turn.execute()
#
		#await effect_manager.apply_turn_end()
		#await check_victory_conditions()
#
#func get_active_pokemon() -> Array:
	#var actives = []
	#for participant in participants:
		#actives += participant.get_active_pokemons()
	#return actives
#
#func check_victory_conditions():
	## Implementa la lógica para finalizar el combate
	## Si un equipo no tiene más pokémon, marca la batalla como finalizada
	#if false:  # reemplaza con condición real
		#finished = true
