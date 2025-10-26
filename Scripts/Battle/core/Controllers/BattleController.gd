extends Node

class_name BattleController

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

func _ready():
	# Este método puede quedar vacío si se usa start_battle() desde BattleScene
	pass

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

	var player_spots:Array[BattleSpot] = ui.get_player_spots_for_mode(rules.mode)
	var enemy_spots:Array[BattleSpot] = ui.get_enemy_spots_for_mode(rules.mode)

	for i in player_actives.size():
		var spot := player_spots[i]
		spot.load_active_pokemon(player_actives[i], rules)
		spot.side = player_side
		player_side.battle_spots.append(spot)

	for i in enemy_actives.size():
		var spot := enemy_spots[i]
		spot.load_active_pokemon(enemy_actives[i], rules)
		spot.side = enemy_side
		enemy_side.battle_spots.append(spot)

	# Ajustar visualmente la posición de los spots
	ui.position_battlespots_for_mode(rules.mode)

func start_battle() -> void:
	# Configurar UI para el nuevo combate
	BattleEffectController.set_ui(ui)
	
	turn_controller.battle_controller = self
	# Inyectar lógica de targeting en la UI
	ui.target_selector = BattleTargetSelector.new()
	print("Combate iniciado (test)")
	await ui.play_intro_sequence(rules,player_side.get_active_pokemons(),enemy_side.get_active_pokemons(),player_side.get_trainer_names(),enemy_side.get_trainer_names())
	await turn_controller.start_turn_loop()


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

	if !winner_side.is_empty():
		# Mostrar mensaje de final de combate
		await ui.show_battle_end_message(winner_side, rules, enemy_side.get_trainer_names())

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
	print(result_msg)
	
	# Guardar el ganador antes de limpiar el estado
	var battle_winner = winner_side
	
	# Limpiar estado del combate para el siguiente
	_cleanup_battle_state()
	

	# Hacer esta función awaitable
	await get_tree().process_frame
	
	# Emitir con el ganador guardado (antes del cleanup)
	SignalManager.battle_finished.emit(battle_winner)

func _cleanup_battle_state():
	# Resetear flags de control
	finished = false
	winner_side = ""
	
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
