extends BattleItemHandler

class_name BattleReviveItemHandler

var _choice: BattleBagChoice = null
var _item_data: ItemData = null
var _runtime_revive: ReviveEffect = null
var _target_bp: BattlePokemon = null


func _init(choice: BattleBagChoice, item_data: ItemData) -> void:
	_choice = choice
	_item_data = item_data


func _apply() -> void:
	_runtime_revive = null
	_target_bp = null
	var bc: BattleController = _choice.battle_controller
	var actor: BattlePokemon = _choice.pokemon
	if bc == null or actor == null:
		item_use_result = ItemUseResult.failure_error("Contexto de combate incompleto.")
		item_use_result.battle_continuation = ItemUseResult.BattleContinuation.COMPLETE_ACTION
		return

	var target_bp: BattlePokemon = _choice.resolve_item_target_battle_pokemon()
	if target_bp == null or target_bp.base_data == null:
		item_use_result = ItemUseResult.failure_error("Objetivo de revivir inválido.")
		item_use_result.battle_continuation = ItemUseResult.BattleContinuation.COMPLETE_ACTION
		return
	_target_bp = target_bp
	var ctx: ItemUseContext = BattleItemHandler.build_player_battle_item_context(_choice, target_bp)
	var revive_eff: ReviveItemEffect = _item_data.effect as ReviveItemEffect
	if revive_eff == null:
		item_use_result = ItemUseResult.failure_error("Ítem sin efecto de revivir válido.")
		item_use_result.battle_continuation = ItemUseResult.BattleContinuation.COMPLETE_ACTION
		return

	item_use_result = revive_eff.apply(ctx)
	if item_use_result == null:
		item_use_result = ItemUseResult.failure_error("El efecto de revivir devolvió un resultado inválido.")
		item_use_result.battle_continuation = ItemUseResult.BattleContinuation.COMPLETE_ACTION
		return

	if not item_use_result.success:
		item_use_result.battle_continuation = ItemUseResult.BattleContinuation.COMPLETE_ACTION
		return

	var amount: int = int(item_use_result.effect_data.get("restored_hp", 0))
	amount = clampi(amount, 1, target_bp.total_hp)
	if amount <= 0:
		item_use_result = ItemUseResult.failure_error("Resultado de revivir sin cantidad válida.")
		item_use_result.battle_continuation = ItemUseResult.BattleContinuation.COMPLETE_ACTION
		return

	_runtime_revive = ReviveEffect.new(target_bp, amount, true)
	_runtime_revive.apply()
	target_bp.write_persistent_state_to_runtime()

	item_use_result.battle_continuation = ItemUseResult.BattleContinuation.COMPLETE_ACTION
	_consume_from_bag_if_needed(_item_data, item_use_result, _choice)


func _visualize(ui: BattleUI) -> void:
	if item_use_result == null:
		return
	var target_is_active: bool = is_target_active_in_battle(_target_bp)
	if not target_is_active:
		await show_party_result_message_and_close(ui, item_use_result, _choice.target_party_slot)
		return
	await show_item_used_battle_message(ui, _item_data)
	if _runtime_revive != null:
		await _runtime_revive.visualize(ui)
	await show_battle_result_message(ui, item_use_result)
