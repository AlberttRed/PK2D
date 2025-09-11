extends Node

class_name BattleController

signal battle_started
signal battle_ended

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

func _ready():
	# Este método puede quedar vacío si se usa start_battle() desde BattleScene
	pass

# Configura los dos BattleSide con sus participantes y reglas
func setup_sides(player_participants: Array[BattleParticipant], enemy_participants: Array[BattleParticipant], rules: BattleRules):

	var player_side = BattleSide.new(BattleSide.Types.PLAYER)
	for p in player_participants:
		player_side.add_participant(p)
	player_side.prepare_for_battle(rules)
	
	var enemy_side = BattleSide.new(BattleSide.Types.ENEMY)
	for p in enemy_participants:
		enemy_side.add_participant(p)
	enemy_side.prepare_for_battle(rules)
	
	self.player_side = player_side
	self.enemy_side = enemy_side
	self.sides = [player_side, enemy_side]
	assign_opponent_sides()

	self.rules = rules
	
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
	ui.visible = true  # Si estaba oculto por defecto
	turn_controller.battle_controller = self
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
	
func get_all_active_pokemon():
	return get_active_battle_spots().map(func(spot:BattleSpot): return spot.pokemon as BattlePokemon) as Array[BattlePokemon]

func assign_opponent_sides():
	if sides.size() != 2:
		push_warning("assign_opponent_sides() requiere exactamente dos lados.")
		return

	sides[0].opponent_side = sides[1]
	sides[1].opponent_side = sides[0]

func battle_finished() -> bool:
	# Lógica real pendiente
	return false

func get_message_controller() -> BattleMessageController:
	return ui.message_controller


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
