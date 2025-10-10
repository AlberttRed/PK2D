extends Control

class_name BattleUI

@onready var message_controller:BattleMessageController = $MessageController
@onready var field_ui:FieldUI = $FieldUI
#@onready var party_ui = $PartyUI
@onready var actions_menu = $ActionsMenu
@onready var message_box:MessageBox = $MessageBox
@onready var moves_menu = $MovesMenu
@onready var target_selector_ui = $TargetSelectorUI
@onready var result_display := BattleResultDisplay.new()

func _ready() -> void:
	result_display.ui = self
	visible = false

func show_trainer_sprites():
	$FieldUI/PlayerBase/TrainerA.visible = true
	$FieldUI/EnemyBase/TrainerA.visible = true  # O TrainerB si hay más de uno
	# Mostrar los sprites de los entrenadores en pantalla

func show_enemy_pokemon(pokemons: Array[BattlePokemon], rules: BattleRules):
	if pokemons.size() >= 1:
		var spot_a: BattleSpot = $FieldUI/EnemyBase/PokemonSpotA
		spot_a.load_active_pokemon(pokemons[0], rules)

	if pokemons.size() >= 2:
		var spot_b: BattleSpot = $FieldUI/EnemyBase/PokemonSpotB
		spot_b.load_active_pokemon(pokemons[1], rules)
	# Mostrar el sprite del Pokémon enemigo

func show_player_pokemon(pokemons: Array[BattlePokemon], rules: BattleRules):
	if pokemons.size() >= 1:
		$FieldUI/PlayerBase/PokemonSpotA.load_active_pokemon(pokemons[0], rules)
	if pokemons.size() >= 2:
		$FieldUI/PlayerBase/PokemonSpotB.load_active_pokemon(pokemons[1], rules)
	# Mostrar el sprite del Pokémon del jugador

func show_enemy_hp_bar(pokemons: Array[BattlePokemon]):
	if pokemons.size() >= 1:
		$FieldUI/EnemyBase/PokemonSpotA/HPBar.visible = true
	if pokemons.size() >= 2:
		$FieldUI/EnemyBase/PokemonSpotB/HPBar.visible = true
	# Mostrar la barra de vida del Pokémon enemigo

func show_player_hp_bar(pokemons: Array[BattlePokemon]):
	if pokemons.size() >= 1:
		$FieldUI/PlayerBase/PokemonSpotA/HPBar.visible = true
	if pokemons.size() >= 2:
		$FieldUI/PlayerBase/PokemonSpotB/HPBar.visible = true
	# Mostrar la barra de vida del Pokémon del jugador

func get_player_spots_for_mode(mode: int) -> Array[BattleSpot]:
	return $FieldUI.get_player_spots_for_mode(mode)

func get_enemy_spots_for_mode(mode: int) -> Array[BattleSpot]:
	return $FieldUI.get_enemy_spots_for_mode(mode)

func get_all_spots_for_mode(mode: int) -> Array[BattleSpot]:
	return $FieldUI.get_all_spots_for_mode(mode)

func position_battlespots_for_mode(mode: int) -> void:
	$FieldUI.position_battlespots_for_mode(mode)

func show_action_selection(pokemon: BattlePokemon) -> BattleChoice:
	# Mostrar panel de acciones: LUCHAR, POKÉMON, MOCHILA, HUIR
	var choice:BattleChoice = await show_action_menu_for(pokemon)

	if choice.canceled:
		return choice

	choice.pokemon = pokemon  # Importante: establecer el Pokémon que realiza la acción

	# Si no es LUCHAR, devolvemos directamente
	if choice is not BattleMoveChoice:
		return choice

	# Mostrar el menú de movimientos
	var move_choice:BattleMoveChoice = await show_move_selection(pokemon)

	return move_choice

func show_action_menu_for(pokemon: BattlePokemon) -> BattleChoice:
	if pokemon.battle_spot.has_previous_controllable_pokemon():
		actions_menu.allow_cancel()
	moves_menu.hide()
	message_box.hide()
	return await actions_menu.show_for(pokemon)


func show_moves_menu_for(pokemon: BattlePokemon) -> BattleChoice:
	actions_menu.hide()
	message_box.hide()
	return await moves_menu.show_for(pokemon)


func show_move_selection(pokemon: BattlePokemon) -> BattleMoveChoice:
	var move_choice = await show_moves_menu_for(pokemon)

	if move_choice.canceled:
		# Si el usuario cancela el menú de movimientos, se vuelve a mostrar el menú de acciones
		return await show_action_selection(pokemon)

	move_choice.pokemon = pokemon  # también aquí, por seguridad

	# Verificar si necesita selección manual de target
	var move: BattleMove = move_choice.get_move()
	var target_type := move.base_data.get_target_id() as BattleTarget.TYPE
	
	if BattleTargetSelector.requires_manual_selection(target_type, pokemon):
		var selected_spot := await show_target_selection(pokemon)
		
		if selected_spot == null:
			# Usuario canceló la selección de target
			return await show_move_selection(pokemon)
		
		move_choice.manual_selected_spot = selected_spot
	
	moves_menu.hide()
	return move_choice


func show_target_selection(user: BattlePokemon) -> BattleSpot:
	# Obtener los spots seleccionables
	var candidates := BattleTargetSelector.get_selectable_spots(user)

	if candidates.size() == 1:
		return candidates[0]

	target_selector_ui.show_targets(candidates)
	
	# Esperar a que se seleccione un target - await devuelve directamente el parámetro de la señal
	var selected_spot: BattleSpot = await target_selector_ui.target_chosen
	
	return selected_spot
	
func hide_action_menu():
	actions_menu.hide()

	
func play_intro_sequence(rules,player_pokemon,enemy_pokemon,player_trainers,enemy_trainers) -> void:
	var intro_messages = message_controller.get_intro_messages(
		rules,
		player_pokemon,
		enemy_pokemon,
		player_trainers,
		enemy_trainers
	)

	for msg in intro_messages:
		await show_message_from_dict(msg)
	

		# Opcional: insertar animaciones si lo necesitas más adelante
		# if msg.type == "send_out_enemy":
		#     await enemy_side.play_entry_animation(enemy_pokemon)
		# elif msg.type == "send_out_player":
		#     await player_side.play_entry_animation(player_pokemon)

	# Aquí podrías activar el menú o iniciar la siguiente fase del combate
	actions_menu.show()
	
func show_used_move_message(user: BattlePokemon, move: BattleMove) -> void:
	await show_message_from_dict(message_controller.get_used_move_message(user, move))
	
func show_failed_move_message(user: BattlePokemon) -> void:
	await show_message_from_dict(message_controller.get_failed_move_message(user))
	clear_message_box()

func show_multi_hit_message(num_hits: int) -> void:
	await show_message_from_dict(message_controller.get_multi_hit_message(num_hits))
	clear_message_box()

func show_effectiveness_message(result: DamageEffect) -> void:
	await show_message_from_dict(message_controller.get_effectiveness_message(result))
	clear_message_box()

func show_critical_hit_message() -> void:
	await show_message_from_dict(message_controller.get_critical_hit_message())
	clear_message_box()

func show_heal_message(pokemon: BattlePokemon, amount: int) -> void:
	await show_message_from_dict(message_controller.get_heal_message(pokemon, amount))

func show_drain_message(pokemon: BattlePokemon, amount: int) -> void:
	await show_message_from_dict(message_controller.get_drain_message(pokemon, amount))

func show_start_ailment_message(user: BattlePokemon, ailment: Ailment) -> void:
	await show_message_from_dict(message_controller.get_start_ailment_message(user, ailment))

func show_end_ailment_message(user: BattlePokemon, ailment: Ailment) -> void:
	await show_message_from_dict(message_controller.get_end_ailment_message(user, ailment))

func show_ailment_effect_message(user: BattlePokemon, ailment: Ailment) -> void:
	await show_message_from_dict(message_controller.get_ailment_effect_message(user, ailment))

func show_already_ailment_message(user: BattlePokemon, ailment: Ailment, same_status: bool) -> void:
	await show_message_from_dict(message_controller.get_already_ailment_message(user, ailment, same_status))

func show_ailment_previous_effect_message(user: BattlePokemon, ailment: Ailment) -> void:
	await show_message_from_dict(message_controller.get_ailment_previous_effect_message(user, ailment))

func show_stat_stage_change_message(pokemon: BattlePokemon, stat: StatsEnum.Values, amount: int):
	await show_message_from_dict(message_controller.get_stat_stage_change_message(pokemon, stat, amount))

func show_ability_effect_message(user: BattlePokemon, target: BattlePokemon, ability: Ability) -> void:
	await show_message_from_dict(message_controller.get_ability_effect_message(user, target, ability))

# Mensajes de escape/huida
func show_escape_message(pokemon_name: String, is_trainer_battle: bool, escape_succeeded: bool) -> void:
	await show_message_from_dict(message_controller.get_escape_message(pokemon_name, is_trainer_battle, escape_succeeded))

# Mensajes de cambio de Pokémon
func show_switch_message(trainer_name: String, pokemon_name: String) -> void:
	await show_message_from_dict(message_controller.get_switch_message(trainer_name, pokemon_name))

# Mensaje de final de combate
func show_battle_end_message(winner_side: String, rules: BattleRules, enemy_trainer_names: Array[String]) -> void:
	await show_message_from_dict(message_controller.get_battle_end_message(winner_side, rules, enemy_trainer_names))

# Mensaje de debilitamiento
func show_faint_message(pokemon: BattlePokemon) -> void:
	await show_message_from_dict(message_controller.get_faint_message(pokemon))

# Manda el mensaje a mostrar al MessageBox según el tipo de mensaje devuleto por el MessageController
func show_message_from_dict(msg: Dictionary) -> void:
	if msg == null or msg.is_empty():
		return
	match msg.type:
		"input":
			await message_box.show_input(msg.text)
		"wait":
			await message_box.show_wait(msg.text, msg.get("wait_time", 1.0))
		"display":
			await message_box.show_display(msg.text, msg.get("wait_time", 0.0))
		"no_close":
			await message_box.show_no_close(msg.text)

func clear_message_box():
	message_box.show_clear_text()
