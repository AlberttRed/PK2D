extends Node2D
class_name BattleScene

@onready var battle_controller: BattleController = $BattleController
@onready var battle_ui: BattleUI = $BattleUI

# Rutas a las transiciones de combate
const WILD_TRANSITION_1 = "res://Sprites/Transiciones/battle1.png"
const WILD_TRANSITION_2 = "res://Sprites/Transiciones/Wild/021-Normal01.png"
const WILD_TRANSITION_3 = "res://Sprites/Transiciones/Wild/022-Normal02.png"

# Inicia un nuevo combate con los participantes y reglas especificadas.
# Prepara ambos lados, aplica reglas, y sincroniza con la UI.
func start_battle(player_participants: Array[BattleParticipant], enemy_participants: Array[BattleParticipant], rules: BattleRules):
	# Ocultar la UI al inicio para que no se vea antes de la transición
	battle_ui.visible = false
	
	# Crea y configura el controlador
	battle_controller.ui = battle_ui
	BattleEffectController.set_ui(battle_ui)
	battle_controller.setup_sides(player_participants, enemy_participants, rules)
	battle_controller.assign_active_pokemons_to_spots() 
	
	for pokemon:BattlePokemon in battle_controller.get_all_active_pokemon():
		pokemon.log_pokemon_stats()

	# Ejecutar transición de entrada (hasta negro)
	await play_transition()
	
	# Configurar todos los elementos visuales mientras está en negro
	battle_ui.visible = true  # Si estaba oculto por defecto
	battle_ui.message_box.show_clear_text()
	await show_trainers_and_pokemon()
	await show_hp_bars()

	
	# Revelar el combate ya configurado
	SignalManager.battle_reveal_requested.emit()
	await SignalManager.battle_reveal_finished
	
	# Iniciar la lógica del combate
	await battle_controller.start_battle()

	
func play_transition():
	# Usar el FadeLayer del GUI para la transición
	# Por ahora usamos la primera transición salvaje, más adelante se puede elegir según el tipo de combate
	var transition_path = WILD_TRANSITION_1
	
	# Determinar el tipo de transición según las reglas del combate
	if battle_controller.rules and battle_controller.rules.type == BattleRules.BattleTypes.WILD:
		pass
		# Elegir aleatoriamente entre las transiciones salvajes
		# var wild_transitions = [WILD_TRANSITION_1, WILD_TRANSITION_2]
		# transition_path = wild_transitions[randi() % wild_transitions.size()]
	
	# Solicitar la transición al FadeLayer (1.5 segundos para el efecto)
	SignalManager.battle_transition_requested.emit(transition_path, 1.5)
	await SignalManager.battle_transition_finished

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
	
func cleanup_battle():
	battle_ui.visible = false
	hide()
