extends Control

class_name BattleUI

const _LEVELUP_STATS_SCENE := preload("res://Scenes/UI/LevelUP/LEVELUP.tscn")
const _MOVE_LEARNING_FLOW := preload("res://Scripts/UI/MoveLearningFlowController.gd")
const _PARTY_SUMMARY_SCENE := preload("res://Scenes/UI/2 - Party/PartySummary.tscn")
const _BAG_SCENE := preload("res://Scenes/UI/BAG.tscn")
const _BAG_CONTROLLER_SCRIPT := preload("res://Scripts/UI/BagController.gd")
const _PARTY_SCENE := preload("res://Scenes/UI/2 - Party/PARTY.tscn")
const _PARTY_CONTROLLER_SCRIPT := preload("res://Scripts/UI/PartyController.gd")

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
## Mochila solo para el flujo de combate (no comparte sesión con la Bolsa de pausa).
var _battle_bag_ui: BagUI = null
## Selector Party reutilizado para elegir objetivo aliado de ítems en combate.
var _battle_party_ui: PartyUI = null
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
	var choice: BattleChoice = await show_action_menu_for(pokemon)

	if choice.canceled:
		return choice

	choice.pokemon = pokemon

	if choice is BattleBagChoice:
		if battle_controller != null:
			(choice as BattleBagChoice).battle_controller = battle_controller
		return await show_bag_item_selection(pokemon)

	if choice is not BattleMoveChoice:
		return choice

	var move_choice: BattleMoveChoice = await show_move_selection(pokemon)

	return move_choice


func _ensure_battle_bag_ui() -> void:
	if _battle_bag_ui != null:
		return
	var node: Node = _BAG_SCENE.instantiate()
	if node is BagUI:
		_battle_bag_ui = node
		add_child(_battle_bag_ui)
		_battle_bag_ui.z_index = 30
		_battle_bag_ui.hide()
	else:
		push_error("BattleUI: BAG.tscn debe instanciar BagUI.")


func _ensure_battle_party_ui() -> void:
	if _battle_party_ui != null:
		return
	var node: Node = _PARTY_SCENE.instantiate()
	if node is PartyUI:
		_battle_party_ui = node
		add_child(_battle_party_ui)
		_battle_party_ui.z_index = 31
		_battle_party_ui.hide()
	else:
		push_error("BattleUI: PARTY.tscn debe instanciar PartyUI.")


## Flujo mochila en combate: solo UI; el turno aplica `ItemEffect` vía `BattleItemHandler`.
func show_bag_item_selection(pokemon: BattlePokemon) -> BattleChoice:
	if battle_controller == null:
		var fail := BattleChoice.new()
		fail.canceled = true
		return fail
	_ensure_battle_bag_ui()
	var bag_ctrl: BagController = _BAG_CONTROLLER_SCRIPT.new(null)
	bag_ctrl.configure_battle_item_flow()
	_battle_bag_ui.setup(bag_ctrl)

	actions_menu.hide()
	moves_menu.hide()
	message_box.hide()
	if not _battle_bag_ui.visible:
		_battle_bag_ui.open()

	while true:
		var picked_id: int = -1
		var selected_item_data: ItemData = null
		var picked_wrap: Array = [-1]
		var go_back_wrap: Array = [false]
		var on_use := func(id: int):
			picked_wrap[0] = id
		var on_back := func():
			go_back_wrap[0] = true
		_battle_bag_ui.use_requested.connect(on_use, CONNECT_ONE_SHOT)
		_battle_bag_ui.back_requested.connect(on_back, CONNECT_ONE_SHOT)
		while int(picked_wrap[0]) <= 0 and not bool(go_back_wrap[0]):
			await get_tree().process_frame
		if _battle_bag_ui.use_requested.is_connected(on_use):
			_battle_bag_ui.use_requested.disconnect(on_use)
		if _battle_bag_ui.back_requested.is_connected(on_back):
			_battle_bag_ui.back_requested.disconnect(on_back)

		if bool(go_back_wrap[0]):
			_battle_bag_ui.close()
			return await show_action_selection(pokemon)

		picked_id = int(picked_wrap[0])
		var item_data: ItemData = DatabaseService.get_item_by_id(picked_id)
		if item_data == null:
			continue
		selected_item_data = item_data

		if _battle_bag_ui.has_method("set_input_enabled"):
			_battle_bag_ui.set_input_enabled(false)
		var action_idx: int = await _show_battle_bag_item_action_menu(picked_id, item_data)
		# El action menu de bolsa deja el MessageBox abierto (closeAtEnd=false).
		DisplayManager.close_message()
		if _battle_bag_ui != null and _battle_bag_ui.visible and _battle_bag_ui.has_method("set_input_enabled"):
			_battle_bag_ui.set_input_enabled(true)

		match action_idx:
			0:
				pass # Usar
			1:
				await DisplayManager.show_message("Tirar: pendiente de implementar.", {
					"waitInput": false,
					"closeAtEnd": true,
					"frameStyle": MessageBoxFrameStyle.Values.FIRERED,
					"typingMode": "instant"
				})
				continue
			_:
				continue

		var out := BattleBagChoice.new()
		out.pokemon = pokemon
		out.battle_controller = battle_controller
		out.item_id = picked_id
		out.target_party_slot = -1
		out.enemy_target_battle_pokemon = null
		if selected_item_data == null:
			continue

		if _battle_item_needs_ally_party_pick(selected_item_data):
			var last_party_focus_slot: int = -1
			while true:
				var slot: int = await _pick_ally_party_slot_for_item(pokemon, selected_item_data, last_party_focus_slot)
				if slot < 0:
					await _reset_bag_ui_after_party_cancel()
					await _await_menu_inputs_released()
					break
				if _is_item_usable_on_party_slot_in_battle(pokemon, selected_item_data, picked_id, slot):
					out.target_party_slot = slot
					var preview_target: BattlePokemon = out.resolve_item_target_battle_pokemon()
					if _is_runtime_target_active_in_battle(preview_target):
						if _battle_party_ui != null and _battle_party_ui.visible:
							_battle_party_ui.close()
					_battle_bag_ui.close()
					return out
				last_party_focus_slot = slot
				await _show_no_effect_message_while_party_open()
			continue
		elif _battle_item_needs_enemy_target_pick(selected_item_data):
			_battle_bag_ui.close()
			var foe: BattlePokemon = await _pick_enemy_target_for_item(pokemon)
			if foe == null:
				if _battle_bag_ui != null and not _battle_bag_ui.visible:
					_battle_bag_ui.open()
				continue
			out.enemy_target_battle_pokemon = foe
			return out
		else:
			_battle_bag_ui.close()
			return out
	var fallback_choice := BattleChoice.new()
	fallback_choice.canceled = true
	return fallback_choice


func _show_battle_bag_item_action_menu(item_id: int, item_data: ItemData) -> int:
	var item_name: String = item_data.get_display_name() if item_data != null else ("Item #%d" % item_id)
	var dm := DisplayManager.instance
	if dm != null and dm.has_method("_show_bag_item_action_menu"):
		var pushed_layout := false
		if dm.has_method("_push_bag_item_dialog_layout"):
			dm._push_bag_item_dialog_layout()
			pushed_layout = true
		var idx: int = await dm._show_bag_item_action_menu(item_name)
		if pushed_layout and dm.has_method("_pop_bag_item_dialog_layout"):
			dm._pop_bag_item_dialog_layout()
		return idx
	return await DisplayManager.show_message_with_choices(
		"Has seleccionado %s." % item_name,
		["Usar", "Tirar", "Salir"],
		true
	)


func _battle_item_needs_ally_party_pick(item_data: ItemData) -> bool:
	if not item_data.requires_target():
		return false
	if item_data.kind == ItemEnums.Kind.POKEBALL:
		return false
	return true


func _battle_item_needs_enemy_target_pick(item_data: ItemData) -> bool:
	if not item_data.requires_target():
		return false
	return item_data.kind == ItemEnums.Kind.POKEBALL


func _pick_ally_party_slot_for_item(_actor: BattlePokemon, _item_data: ItemData, initial_focus_slot: int = -1) -> int:
	if battle_controller == null or battle_controller.player_side == null:
		return -1
	_sync_player_battle_party_to_persistent()
	# Evita heredar input del ChoiceBox (accept/cancel/direcciones) al abrir Party.
	await _await_menu_inputs_released()
	_ensure_battle_party_ui()
	if _battle_party_ui == null:
		return -1

	var party_ctrl: PartyController = _PARTY_CONTROLLER_SCRIPT.new(null, &"battle")
	_battle_party_ui.setup(party_ctrl)
	if _battle_bag_ui != null and _battle_bag_ui.visible and _battle_bag_ui.has_method("set_input_enabled"):
		_battle_bag_ui.set_input_enabled(false)

	var picked_slot_wrap: Array = [-1]
	var cancelled_wrap: Array = [false]
	var on_selected := func(slot: int):
		picked_slot_wrap[0] = slot
	var on_cancel := func():
		cancelled_wrap[0] = true
		_battle_party_ui.close()
	_battle_party_ui.bag_item_target_selected.connect(on_selected, CONNECT_ONE_SHOT)
	_battle_party_ui.bag_item_target_cancelled.connect(on_cancel, CONNECT_ONE_SHOT)

	_battle_party_ui.open_for_bag_item_target_pick(initial_focus_slot)
	if _battle_party_ui.has_method("set_input_enabled"):
		_battle_party_ui.set_input_enabled(false)
	# Guardia adicional para evitar propagación del último input.
	await _await_menu_inputs_released()
	if _battle_party_ui != null and _battle_party_ui.visible and _battle_party_ui.has_method("set_input_enabled"):
		_battle_party_ui.set_input_enabled(true)
	while int(picked_slot_wrap[0]) < 0 and not bool(cancelled_wrap[0]):
		await get_tree().process_frame
	if bool(cancelled_wrap[0]):
		while _battle_party_ui != null and _battle_party_ui.visible:
			await get_tree().process_frame
		if _battle_bag_ui != null and _battle_bag_ui.visible and _battle_bag_ui.has_method("set_input_enabled"):
			_battle_bag_ui.set_input_enabled(true)
	if _battle_party_ui.bag_item_target_selected.is_connected(on_selected):
		_battle_party_ui.bag_item_target_selected.disconnect(on_selected)
	if _battle_party_ui.bag_item_target_cancelled.is_connected(on_cancel):
		_battle_party_ui.bag_item_target_cancelled.disconnect(on_cancel)
	if int(picked_slot_wrap[0]) >= 0 and _battle_party_ui != null and _battle_party_ui.visible and _battle_party_ui.has_method("set_input_enabled"):
		_battle_party_ui.set_input_enabled(false)
	return int(picked_slot_wrap[0])


func _await_menu_inputs_released() -> void:
	var quiet_frames := 0
	var safety_frames := 0
	while quiet_frames < 2 and safety_frames < 20:
		var pressed := Input.is_action_pressed("ui_accept") \
			or Input.is_action_pressed("ui_cancel") \
			or Input.is_action_pressed("ui_start")
		if pressed:
			quiet_frames = 0
		else:
			quiet_frames += 1
		safety_frames += 1
		await get_tree().process_frame


func show_party_item_result_and_close(message_text: String) -> void:
	_sync_player_battle_party_to_persistent()
	if _battle_party_ui != null and _battle_party_ui.visible and _battle_party_ui.has_method("refresh_slots_display"):
		_battle_party_ui.refresh_slots_display()
	if message_text.is_empty():
		if _battle_party_ui != null and _battle_party_ui.visible:
			_battle_party_ui.close()
		return
	await DisplayManager.show_message(message_text, {
		"waitInput": true,
		"closeAtEnd": true,
		"waitTime": 0.0,
		"showIconAtEnd": false,
		"frameStyle": MessageBoxFrameStyle.Values.FIRERED,
		"typingMode": "typing",
	})
	if _battle_party_ui != null and _battle_party_ui.visible:
		_battle_party_ui.close()
	if _battle_bag_ui != null and _battle_bag_ui.visible and _battle_bag_ui.has_method("set_input_enabled"):
		_battle_bag_ui.set_input_enabled(true)


func _is_item_usable_on_party_slot_in_battle(actor: BattlePokemon, item_data: ItemData, item_id: int, slot: int) -> bool:
	if item_data == null:
		return false
	var effect: ItemEffect = item_data.effect as ItemEffect
	if effect == null:
		return false
	var preview := BattleBagChoice.new()
	preview.pokemon = actor
	preview.battle_controller = battle_controller
	preview.item_id = item_id
	preview.target_party_slot = slot
	var target_bp: BattlePokemon = preview.resolve_item_target_battle_pokemon()
	if target_bp == null:
		return false
	var ctx: ItemUseContext = BattleItemHandler.build_player_battle_item_context(preview, target_bp)
	return effect.can_use(ctx)


func _show_no_effect_message_while_party_open() -> void:
	if _battle_party_ui != null and _battle_party_ui.visible and _battle_party_ui.has_method("set_input_enabled"):
		_battle_party_ui.set_input_enabled(false)
	await DisplayManager.show_message("No tendría ningún efecto.", {
		"waitInput": true,
		"closeAtEnd": true,
		"waitTime": 0.0,
		"showIconAtEnd": false,
		"frameStyle": MessageBoxFrameStyle.Values.FIRERED,
		"typingMode": "typing",
	})
	if _battle_party_ui != null and _battle_party_ui.visible and _battle_party_ui.has_method("set_input_enabled"):
		_battle_party_ui.set_input_enabled(true)


func _sync_player_battle_party_to_persistent() -> void:
	if battle_controller == null or battle_controller.player_side == null:
		return
	for bp: BattlePokemon in battle_controller.player_side.pokemonParty:
		if bp != null:
			bp.write_persistent_state_to_runtime()


func _is_runtime_target_active_in_battle(target_bp: BattlePokemon) -> bool:
	if target_bp == null:
		return false
	var spot: BattleSpot = target_bp.battle_spot
	if spot == null:
		return false
	if not spot.has_active_pokemon():
		return false
	return spot.get_active_pokemon() == target_bp


func _reset_bag_ui_after_party_cancel() -> void:
	if _battle_bag_ui == null:
		return
	var nav_state: Dictionary = {}
	if _battle_bag_ui.has_method("get_navigation_state"):
		nav_state = _battle_bag_ui.get_navigation_state()
	if _battle_bag_ui.visible:
		_battle_bag_ui.close()
		while _battle_bag_ui != null and _battle_bag_ui.visible:
			await get_tree().process_frame
	_battle_bag_ui.open()
	if not nav_state.is_empty() and _battle_bag_ui.has_method("restore_navigation_state"):
		_battle_bag_ui.restore_navigation_state(nav_state)
		if _battle_bag_ui.has_method("refresh_from_controller"):
			_battle_bag_ui.refresh_from_controller()
	if _battle_bag_ui.has_method("set_input_enabled"):
		_battle_bag_ui.set_input_enabled(false)
		await get_tree().process_frame
		_battle_bag_ui.set_input_enabled(true)


func _pick_enemy_target_for_item(actor: BattlePokemon) -> BattlePokemon:
	var spot: BattleSpot = await show_target_selection(actor)
	if spot == null:
		return null
	if not spot.has_active_pokemon():
		return null
	return spot.get_active_pokemon()


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
	if _battle_move_forget_summary != null and _battle_move_forget_summary.visible:
		return true
	if _battle_bag_ui != null and _battle_bag_ui.visible:
		return true
	return _battle_party_ui != null and _battle_party_ui.visible


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
