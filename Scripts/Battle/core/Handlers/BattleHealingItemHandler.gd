extends BattleItemHandler

class_name BattleHealingItemHandler

var _choice: BattleBagChoice = null
var _item_data: ItemData = null
var _runtime_heal: HealEffect = null


func _init(choice: BattleBagChoice, item_data: ItemData) -> void:
	_choice = choice
	_item_data = item_data


func _apply() -> void:
	_runtime_heal = null
	var bc: BattleController = _choice.battle_controller
	var actor: BattlePokemon = _choice.pokemon
	if bc == null or actor == null:
		item_use_result = ItemUseResult.failure_error("Contexto de combate incompleto.")
		item_use_result.battle_continuation = ItemUseResult.BattleContinuation.COMPLETE_ACTION
		return

	var target_bp: BattlePokemon = actor
	var ctx: ItemUseContext = BattleItemHandler.build_player_battle_item_context(_choice, target_bp)
	var heal_eff: HealingItemEffect = _item_data.effect as HealingItemEffect
	if heal_eff == null:
		item_use_result = ItemUseResult.failure_error("Ítem sin efecto de curación válido.")
		item_use_result.battle_continuation = ItemUseResult.BattleContinuation.COMPLETE_ACTION
		return

	if not heal_eff.can_use(ctx):
		var pokemon: Pokemon = target_bp.base_data
		if pokemon.hp_actual <= 0:
			item_use_result = ItemUseResult.failure_blocked("El Pokémon está debilitado")
		else:
			var max_hp: int = pokemon.get_final_stat(StatsEnum.Values.HP)
			if pokemon.hp_actual >= max_hp:
				item_use_result = ItemUseResult.failure_no_effect("El Pokémon ya tiene el HP al máximo")
			else:
				item_use_result = ItemUseResult.failure_no_effect("No tendrá efecto.")
		item_use_result.battle_continuation = ItemUseResult.BattleContinuation.COMPLETE_ACTION
		return

	var amount: int = heal_eff.compute_healed_amount(target_bp.base_data)
	if amount <= 0:
		item_use_result = ItemUseResult.failure_no_effect("No tendrá efecto.")
		item_use_result.battle_continuation = ItemUseResult.BattleContinuation.COMPLETE_ACTION
		return

	_runtime_heal = HealEffect.new(target_bp, amount, true)
	_runtime_heal.apply()
	target_bp.write_persistent_state_to_runtime()

	var msg: String = heal_eff.build_heal_success_message(target_bp.base_data, amount)
	item_use_result = ItemUseResult.success_result(1, msg, {"healed_amount": amount})
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
	if _runtime_heal != null:
		await _runtime_heal.visualize(ui)
		await ui.show_heal_message(_runtime_heal.target)
