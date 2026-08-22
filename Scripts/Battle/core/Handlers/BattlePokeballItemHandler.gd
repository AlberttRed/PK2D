extends BattleItemHandler

class_name BattlePokeballItemHandler

var _choice: BattleBagChoice = null
var _item_data: ItemData = null
var _runtime_capture: CaptureEffect = null
var _target_bp: BattlePokemon = null


func _init(choice: BattleBagChoice, item_data: ItemData) -> void:
	_choice = choice
	_item_data = item_data


func _apply() -> void:
	_runtime_capture = null
	_target_bp = null
	item_use_result = null

	if _choice == null or _choice.battle_controller == null or _choice.pokemon == null:
		item_use_result = ItemUseResult.failure_error("Contexto de combate incompleto.")
		item_use_result.battle_continuation = ItemUseResult.BattleContinuation.COMPLETE_ACTION
		return

	if _item_data == null:
		item_use_result = ItemUseResult.failure_error("Objeto desconocido.")
		item_use_result.battle_continuation = ItemUseResult.BattleContinuation.COMPLETE_ACTION
		return

	var target_bp: BattlePokemon = _choice.resolve_item_target_battle_pokemon()
	if target_bp == null:
		item_use_result = ItemUseResult.failure_blocked("No hay un Pokémon salvaje capturable.")
		item_use_result.battle_continuation = ItemUseResult.BattleContinuation.COMPLETE_ACTION
		return
	_target_bp = target_bp

	var ctx: ItemUseContext = BattleItemHandler.build_player_battle_item_context(_choice, target_bp)
	var ball_eff: PokeballItemEffect = PokeballItemEffect.resolve_for_item(_item_data)
	if ball_eff == null:
		item_use_result = ItemUseResult.failure_error("Ítem sin efecto de captura válido.")
		item_use_result.battle_continuation = ItemUseResult.BattleContinuation.COMPLETE_ACTION
		return

	item_use_result = ball_eff.apply(ctx)
	if item_use_result == null:
		item_use_result = ItemUseResult.failure_error("El efecto de captura devolvió un resultado inválido.")
		item_use_result.battle_continuation = ItemUseResult.BattleContinuation.COMPLETE_ACTION
		return

	if not item_use_result.success:
		item_use_result.battle_continuation = ItemUseResult.BattleContinuation.COMPLETE_ACTION
		return

	var ball_name: String = _item_data.get_display_name()
	var thrower_name: String = BattleItemHandler.get_player_trainer_display_name(_choice)
	_runtime_capture = CaptureEffect.new(target_bp, ball_eff, ball_name, thrower_name)
	_runtime_capture.apply()
	var capture_result: CaptureResult = _runtime_capture.result

	_consume_from_bag_if_needed(_item_data, item_use_result, _choice)

	if capture_result != null and capture_result.success:
		_choice.battle_controller.register_successful_capture(capture_result, target_bp)
		item_use_result.battle_continuation = ItemUseResult.BattleContinuation.BLOCKING_SEQUENCE
		item_use_result.effect_data["capture_result"] = capture_result
	else:
		item_use_result = ItemUseResult.failure_no_effect("")
		item_use_result.battle_continuation = ItemUseResult.BattleContinuation.COMPLETE_ACTION


func _visualize(ui: BattleUI) -> void:
	if item_use_result == null:
		return
	if _runtime_capture != null:
		await _runtime_capture.visualize(ui)
		if item_use_result.battle_continuation == ItemUseResult.BattleContinuation.BLOCKING_SEQUENCE:
			_choice.battle_controller.apply_capture_field_cleanup(_target_bp)
		return
	if item_use_result.outcome in [ItemUseResult.Outcome.BLOCKED, ItemUseResult.Outcome.ERROR]:
		await show_battle_result_message(ui, item_use_result)
		return
	if not item_use_result.message.is_empty():
		await show_battle_result_message(ui, item_use_result)
