extends Node2D
class_name BattleScene

@onready var battle_controller: BattleController = $BattleController
@onready var battle_ui: BattleUI = $BattleUI

# Inicia un nuevo combate con los participantes y reglas especificadas.
# Prepara ambos lados, aplica reglas, y sincroniza con la UI.
func start_battle(player_participants: Array[BattleParticipant], enemy_participants: Array[BattleParticipant], rules: BattleRules):
	# Crea y configura el controlador
	battle_controller.ui = battle_ui
	BattleEffectController.set_ui(battle_ui)
	battle_controller.setup_sides(player_participants, enemy_participants, rules)
	battle_controller.assign_active_pokemons_to_spots() 
	
	for pokemon:BattlePokemon in battle_controller.get_all_active_pokemon():
		pokemon.log_pokemon_stats()

	 # Iniciar la secuencia de inicio del combate
	await play_transition()
	await show_trainers_and_pokemon()
	await show_hp_bars()
	show_action_menu()
	
	# Iniciar la lógica del combate
	await battle_controller.start_battle()
	
func play_transition():
	# Placeholder para la transición de entrada
	await get_tree().create_timer(0.5).timeout

func show_trainers_and_pokemon():
	if battle_controller.rules.type == BattleRules.BattleTypes.TRAINER:
		# Mostrar sprites de los entrenadores
		battle_ui.show_trainer_sprites()
		await get_tree().create_timer(0.5).timeout

		# Mostrar mensajes de introducción
		await battle_ui.show_message("¡[Nombre del entrenador] te desafía a un combate!")
		await get_tree().create_timer(0.5).timeout

		# Mostrar Pokémon del enemigo
		await battle_ui.show_enemy_pokemon(battle_controller.enemy_side.get_active_pokemons(), battle_controller.rules)
		await get_tree().create_timer(0.5).timeout

		# Mostrar Pokémon del jugador
		await battle_ui.show_player_pokemon(battle_controller.player_side.get_active_pokemons(), battle_controller.rules)
		await get_tree().create_timer(0.5).timeout
	else:
		pass
		## Combate contra Pokémon salvaje
		#await battle_ui.show_enemy_pokemon(battle_controller.enemy_side.get_active_pokemons(), battle_controller.rules)
		#await get_tree().create_timer(0.5).timeout
#
		## Mostrar Pokémon del jugador
		#await battle_ui.show_player_pokemon(battle_controller.player_side.get_active_pokemons(), battle_controller.rules)
		#await get_tree().create_timer(0.5).timeout
#
	#
func show_hp_bars():
	await battle_ui.show_enemy_hp_bar(battle_controller.enemy_side.get_active_pokemons())
	await get_tree().create_timer(0.5).timeout
	await battle_ui.show_player_hp_bar(battle_controller.player_side.get_active_pokemons())
	await get_tree().create_timer(0.5).timeout
	
func show_action_menu():
	pass
	
