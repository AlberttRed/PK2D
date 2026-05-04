extends BattleItemHandler

class_name BattleReviveItemHandler

var _choice: BattleBagChoice = null
var _item_data: ItemData = null
var _runtime_revive: ReviveEffect = null


func _init(choice: BattleBagChoice, item_data: ItemData) -> void:
	_choice = choice
	_item_data = item_data


func _apply() -> void:
	_runtime_revive = null
	var bc: BattleController = _choice.battle_controller
	var actor: BattlePokemon = _choice.pokemon
	if bc == null or actor == null:
		item_use_result = ItemUseResult.failure_error("Contexto de combate incompleto.")
		item_use_result.battle_continuation = ItemUseResult.BattleContinuation.COMPLETE_ACTION
		return

	var target_bp: BattlePokemon = actor
	var ctx: ItemUseContext = BattleItemHandler.build_player_battle_item_context(_choice, target_bp)
	var revive_eff: ReviveItemEffect = _item_data.effect as ReviveItemEffect
	if revive_eff == null:
		item_use_result = ItemUseResult.failure_error("Ítem sin efecto de revivir válido.")
		item_use_result.battle_continuation = ItemUseResult.BattleContinuation.COMPLETE_ACTION
		return

	if not revive_eff.can_use(ctx):
		item_use_result = ItemUseResult.failure_blocked("No tiene efecto en un Pokémon que no esté debilitado.")
		item_use_result.battle_continuation = ItemUseResult.BattleContinuation.COMPLETE_ACTION
		return

	var amount: int = revive_eff.compute_revived_hp_amount(target_bp.base_data)
	amount = clampi(amount, 1, target_bp.total_hp)

	_runtime_revive = ReviveEffect.new(target_bp, amount, true)
	_runtime_revive.apply()
	target_bp.write_persistent_state_to_runtime()

	var msg: String = revive_eff.build_revive_success_message(target_bp.base_data, amount)
	item_use_result = ItemUseResult.success_result(1, msg, {"restored_hp": amount})
	item_use_result.battle_continuation = ItemUseResult.BattleContinuation.COMPLETE_ACTION
	_consume_from_bag_if_needed(_item_data, item_use_result)


func _visualize(ui: BattleUI) -> void:
	if item_use_result == null:
		return
	if not item_use_result.message.is_empty():
		await ui.show_message_from_dict({
			"type": "display",
			"text": item_use_result.message,
			"wait_time": 0.8,
		})
	if _runtime_revive != null:
		await _runtime_revive.visualize(ui)
		await ui.show_heal_message(_runtime_revive.target)
