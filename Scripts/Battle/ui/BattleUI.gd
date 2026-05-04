extends Control

class_name BattleUI

const _LEVELUP_STATS_SCENE := preload("res://Scenes/UI/LevelUP/LEVELUP.tscn")
const _MOVE_LEARNING_FLOW := preload("res://Scripts/UI/MoveLearningFlowController.gd")
const _PARTY_SUMMARY_SCENE := preload("res://Scenes/UI/2 - Party/PartySummary.tscn")

@onready var message_controller:BattleMessageController = $MessageController
@onready var field_ui:FieldUI = $FieldUI
#@onready var party_ui = $PartyUI
@onready var actions_menu = $ActionsMenu
@onready var message_box:MessageBox = $MessageBox
@onready var moves_menu = $MovesMenu
@onready var target_selector_ui = $TargetSelectorUI
var target_selector: BattleTargetSelector = null
@onready var result_display := BattleResultDisplay.new()

## Referencia al controlador de combate (asignada desde `BattleScene` al iniciar).
var battle_controller: BattleController = null

var _level_up_stats_panel: Panel = null
var _move_learning_flow: RefCounted = null
var _battle_move_forget_summary: PartySummary = null
const FAMILY := MessageFamily.Values

func _ready() -> void:
	result_display.ui = self
	visible = false
	_move_learning_flow = _MOVE_LEARNING_FLOW.new()
	_level_up_stats_panel = _LEVELUP_STATS_SCENE.instantiate() as Panel
	add_child(_level_up_stats_panel)
	_level_up_stats_panel.visible = false
	_level_up_stats_panel.z_index = 15
	_battle_move_forget_summary = _PARTY_SUMMARY_SCENE.instantiate() as PartySummary
	if _battle_move_forget_summary != null:
		add_child(_battle_move_forget_summary)
		_battle_move_forget_summary.hide()
		_battle_move_forget_summary.z_index = 25

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

	if choice is BattleBagChoice and battle_controller != null:
		(choice as BattleBagChoice).battle_controller = battle_controller

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

	# Verificar si necesita selección manual de target (usando la lógica, no la UI)
	var move: BattleMove = move_choice.get_move()
	var target_type := move.base_data.get_target_id() as BattleTarget.TYPE
	
	var selected_spot: BattleSpot = null
	if target_selector != null and target_selector.requires_manual_selection(target_type, pokemon):
		selected_spot = await show_target_selection(pokemon)
		
		if selected_spot == null:
			# Usuario canceló la selección de target
			return await show_move_selection(pokemon)
	
	# Generar los targets aquí usando la lógica y asignarlos al choice
	if target_selector != null:
		move_choice.targets = target_selector.resolve_targets(move, pokemon, selected_spot)
	
	moves_menu.hide()
	return move_choice


func show_target_selection(user: BattlePokemon) -> BattleSpot:
	# Obtener los spots seleccionables con la lógica
	var candidates: Array[BattleSpot] = []
	if target_selector != null:
		candidates = target_selector.get_selectable_spots(user)

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
		print("escrito!")
	
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

func show_no_target_message(user: BattlePokemon) -> void:
	await show_message_from_dict(message_controller.get_no_target_message(user))
	clear_message_box()

func show_heal_message(pokemon: BattlePokemon) -> void:
	await show_message_from_dict(message_controller.get_heal_message(pokemon))
	

func show_drain_message(pokemon: BattlePokemon) -> void:
	await show_message_from_dict(message_controller.get_drain_message(pokemon))

func show_stat_stage_change_message(pokemon: BattlePokemon, stat: StatsEnum.Values, amount: int, applied: bool):
	await show_message_from_dict(message_controller.get_stat_stage_change_message(pokemon, stat, amount, applied))

func show_generic_stat_stage_failed_message(pokemon: BattlePokemon, is_increase: bool):
	await show_message_from_dict(message_controller.get_generic_stat_stage_failed_message(pokemon, is_increase))

func show_ability_effect_message(user: BattlePokemon, target: BattlePokemon, ability_id: int) -> void:
	await show_message_from_dict(message_controller.get_ability_effect_message(user, target, ability_id))

# Mensajes de escape/huida
func show_escape_message(is_trainer_battle: bool, escape_succeeded: bool) -> void:
	await show_message_from_dict(message_controller.get_escape_message(is_trainer_battle, escape_succeeded))

# Mensajes de cambio de Pokémon
func show_switch_message(trainer_name: String, pokemon_name: String) -> void:
	await show_message_from_dict(message_controller.get_switch_message(trainer_name, pokemon_name))

# Mensaje de final de combate
func show_battle_end_message(winner_side: String, rules: BattleRules, enemy_participants: Array) -> void:
	# Mostrar mensaje de victoria
	await show_message_from_dict(message_controller.get_battle_end_message(winner_side, rules, enemy_participants))
	
	# Si el jugador ganó contra un entrenador, mostrar mensaje de derrota del trainer
	if winner_side == "player" and rules.type == BattleRules.BattleTypes.TRAINER:
		for participant in enemy_participants:
			if participant is BattleParticipant and not participant.defeat_message.is_empty():
				await show_message_from_dict({
					"type": "input",
					"text": participant.defeat_message,
					"showIconAtEnd": true
				})

# Mensaje de debilitamiento
func show_faint_message(pokemon: BattlePokemon) -> void:
	await show_message_from_dict(message_controller.get_faint_message(pokemon))


func show_gained_exp_message(battle_pokemon: BattlePokemon, exp_gained: int) -> void:
	await show_message_from_dict(message_controller.get_gained_exp_message(battle_pokemon, exp_gained))
	clear_message_box()


func show_level_up_message(battle_pokemon: BattlePokemon, new_level: int) -> void:
	print("¡%s subió al nivel %d!" % [battle_pokemon.get_name(), new_level])
	await show_message_from_dict(message_controller.get_level_up_message(battle_pokemon, new_level))
	clear_message_box()


## Una sola subida (mensaje + paneles de stats para ese escalón `new_level - 1` → `new_level` + aprendizaje de movimientos).
func show_level_up_dialog_for_single_level(bp: BattlePokemon, new_level: int, lvl_res: Variant = null) -> void:
	if bp == null or bp.base_data == null:
		return
	var stat_changes: RefCounted = bp.base_data.level_up_stat_changes_between(new_level - 1, new_level)
	await show_level_up_message(bp, new_level)
	await show_level_up_stat_panels(stat_changes)
	await _run_move_learning_for_level(bp, new_level, lvl_res)


## Resultado de `PokemonLevelGrowth.LevelUpResult` (campo `stat_changes`). Dos pantallas como en el proyecto antiguo.
func show_level_up_stat_panels(stat_changes: Variant) -> void:
	if stat_changes == null or _level_up_stats_panel == null:
		return
	await _level_up_stats_panel.show_stats_increment(stat_changes)
	await _level_up_stats_panel.show_final_stats(stat_changes)


func show_level_up_dialog_sequence(bp: BattlePokemon, lvl_res: Variant) -> void:
	if lvl_res == null:
		return
	for lv: int in range(lvl_res.old_level + 1, lvl_res.new_level + 1):
		await show_level_up_dialog_for_single_level(bp, lv, lvl_res)


func _run_move_learning_for_level(bp: BattlePokemon, level_reached: int, lvl_res: Variant) -> void:
	if _move_learning_flow == null or bp == null or bp.base_data == null or lvl_res == null:
		return
	var by_level: Dictionary = lvl_res.move_learning_by_level if "move_learning_by_level" in lvl_res else {}
	var move_res: RefCounted = by_level.get(level_reached, null)
	if move_res == null:
		return
	for learned_var in move_res.learned_moves:
		var learned_move: Move = learned_var as Move
		if learned_move == null:
			continue
		await _show_runtime_message("¡%s aprendió %s!" % [bp.base_data.get_display_name(), learned_move.get_move_name()])
	for mv_var in move_res.pending_moves:
		var pending_move: Move = mv_var as Move
		if pending_move == null:
			continue
		await _move_learning_flow.start_move_learning_flow(
			bp.base_data,
			pending_move,
			_MOVE_LEARNING_FLOW.OriginContext.BATTLE,
			Callable(self, "_show_runtime_message"),
			Callable(self, "_show_runtime_choices"),
			Callable(self, "_select_move_to_forget_via_summary")
		)
		_remove_pending_move_entry(bp.base_data, pending_move, level_reached)


func _remove_pending_move_entry(mon: Pokemon, move: Move, learned_level: int) -> void:
	if mon == null or move == null:
		return
	for i in range(mon.pending_move_learnings.size()):
		var entry: Dictionary = mon.pending_move_learnings[i]
		var entry_move: Move = entry.get("move", null)
		var entry_level: int = int(entry.get("level", -1))
		if entry_move != null and entry_move.base != null and move.base != null and entry_move.base.id == move.base.id and entry_level == learned_level:
			mon.pending_move_learnings.remove_at(i)
			return


func _show_runtime_message(text: String) -> void:
	await show_message_from_dict({
		"type": "input",
		"text": text,
		"showIconAtEnd": true,
	})
	clear_message_box()


func _show_runtime_choices(text: String, options: Array[String]) -> int:
	await _show_runtime_message(text)
	return await DisplayManager.show_choices(options)


func _select_move_to_forget_via_summary(mon: Pokemon, learning_move: Move) -> int:
	if _battle_move_forget_summary == null or mon == null or learning_move == null:
		return -1
	_in_hgss_summary_input_pause(true)
	_battle_move_forget_summary.loadedParty = [mon]
	_battle_move_forget_summary.movingIndex = 0
	_battle_move_forget_summary.loadPokemonInfo(mon)
	_battle_move_forget_summary.summaryIndex = PartySummary.MOVES
	_battle_move_forget_summary.show()
	var moves_page: PartySummaryMoves = _battle_move_forget_summary.pages[PartySummary.MOVES] as PartySummaryMoves
	if moves_page == null:
		_battle_move_forget_summary.close()
		_in_hgss_summary_input_pause(false)
		return -1
	moves_page.learningMove = learning_move
	var selected_raw: Variant = await moves_page.open(true)
	var selected_idx: int = int(selected_raw) if typeof(selected_raw) == TYPE_INT else -1
	_battle_move_forget_summary.close()
	_in_hgss_summary_input_pause(false)
	return selected_idx


func _in_hgss_summary_input_pause(paused: bool) -> void:
	if paused:
		actions_menu.hide()
		moves_menu.hide()
		target_selector_ui.hide()


## Modal UI propia de batalla que también debe habilitar el ruteo de input global (DisplayManager).
func has_modal_ui_visible() -> bool:
	return _battle_move_forget_summary != null and _battle_move_forget_summary.visible


# API unificada por variante (source es SIEMPRE int id)
func show_start_effect_message(family: MessageFamily.Values, user: BattlePokemon = null, source_id: int = 0) -> void:
	var side: BattleSide = user.side if user != null else null
	var msg: Dictionary = message_controller.get_start_effect_message(family, user, source_id, side)
	if !msg or msg.is_empty(): return
	await show_message_from_dict(msg)

func show_effect_message(family: MessageFamily.Values, user: BattlePokemon = null, source_id: int = 0) -> void:
	var msg: Dictionary = message_controller.get_effect_message(family, user, source_id)
	if !msg or msg.is_empty(): return
	await show_message_from_dict(msg)

func show_end_effect_message(family: MessageFamily.Values, user: BattlePokemon = null, source_id: int = 0) -> void:
	var side: BattleSide = user.side if user != null else null
	var msg: Dictionary = message_controller.get_end_effect_message(family, user, source_id, side)
	if !msg or msg.is_empty(): return
	await show_message_from_dict(msg)

func show_already_effect_message(family: MessageFamily.Values, user: BattlePokemon = null, source_id: int = 0, has_other_status: bool = false) -> void:
	var msg: Dictionary = message_controller.get_already_effect_message(family, user, source_id, has_other_status)
	if !msg or msg.is_empty(): return
	await show_message_from_dict(msg)

func show_previous_effect_message(family: MessageFamily.Values, user: BattlePokemon = null, source_id: int = 0) -> void:
	var msg: Dictionary = message_controller.get_previous_effect_message(family, user, source_id)
	if !msg or msg.is_empty(): return
	await show_message_from_dict(msg)

# Manda el mensaje a mostrar al MessageBox según el tipo de mensaje devuleto por el MessageController
func show_message_from_dict(msg: Dictionary) -> void:
	if msg == null or msg.is_empty():
		return
	match msg.type:
		"input":
			await message_box.show_input(msg.text, true)  # Batalla: mostrar icono al final
		"wait":
			await message_box.show_wait(msg.text, msg.get("wait_time", 1.0))
		"display":
			await message_box.show_display(msg.text, msg.get("wait_time", 0.0))
		"no_close":
			await message_box.show_no_close(msg.text, true)  # Batalla: mostrar icono al final

func clear_message_box():
	message_box.show_clear_text()
