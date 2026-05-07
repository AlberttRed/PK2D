extends BattleHandler

class_name BattleItemHandler

## Resultado del último `apply()` para `_visualize` y para la capa de combate.
var item_use_result: ItemUseResult = null

var _should_visualize: bool = true

func apply() -> void:
	item_use_result = null
	_should_visualize = true
	_apply()


func visualize(ui: BattleUI) -> void:
	if not _should_visualize:
		return
	await _visualize(ui)


func _apply() -> void:
	pass


func _visualize(_ui: BattleUI) -> void:
	pass


func is_target_active_in_battle(target_bp: BattlePokemon) -> bool:
	if target_bp == null:
		return false
	var spot: BattleSpot = target_bp.battle_spot
	if spot == null:
		return false
	if not spot.has_active_pokemon():
		return false
	return spot.get_active_pokemon() == target_bp


func show_item_used_battle_message(ui: BattleUI, item_data: ItemData) -> void:
	if item_data == null or ui == null:
		return
	var msg: Dictionary = {}
	if ui.message_controller != null and ui.message_controller.has_method("get_used_item_message"):
		msg = ui.message_controller.get_used_item_message(item_data)
	if msg.is_empty():
		msg = BattleMessageItem.new().get_used_item_message(item_data)
	if msg.is_empty():
		return
	await ui.show_message_from_dict(msg)


func show_overworld_style_result_message(result: ItemUseResult) -> void:
	if result == null or result.message.is_empty():
		return
	await DisplayManager.show_message(result.message, {
		"waitInput": true,
		"closeAtEnd": true,
		"waitTime": 0.0,
		"showIconAtEnd": false,
		"frameStyle": MessageBoxFrameStyle.Values.FIRERED,
		"typingMode": "typing",
	})


func show_party_result_message_and_close(ui: BattleUI, result: ItemUseResult, target_party_slot: int = -1) -> void:
	if result == null or result.message.is_empty():
		if ui != null and ui.has_method("show_party_item_result_and_close"):
			if target_party_slot >= 0:
				await ui.callv("show_party_item_result_and_close", ["", target_party_slot])
			else:
				await ui.callv("show_party_item_result_and_close", [""])
		return
	if ui != null and ui.has_method("show_party_item_result_and_close"):
		if target_party_slot >= 0:
			await ui.callv("show_party_item_result_and_close", [result.message, target_party_slot])
		else:
			await ui.callv("show_party_item_result_and_close", [result.message])
		return
	await show_overworld_style_result_message(result)


func show_battle_result_message(ui: BattleUI, result: ItemUseResult) -> void:
	if result == null or result.message.is_empty():
		return
	await ui.show_message_from_dict({
		"type": "display",
		"text": result.message,
		"wait_time": 0.8,
	})


func _consume_from_bag_if_needed(item_data: ItemData, result: ItemUseResult) -> void:
	if item_data == null or result == null or not result.success:
		return
	if item_data.is_consumable and result.consume_amount > 0:
		var bag = GameStateService.get_bag()
		if bag != null:
			bag.remove_item(item_data.id, result.consume_amount)


static func build_player_battle_item_context(choice: BattleBagChoice, target_battle_pokemon: BattlePokemon) -> ItemUseContext:
	var bc: BattleController = choice.battle_controller
	var bag = GameStateService.get_bag()
	var party: Array = []
	var slot := -1
	var idx := 0
	for bp in bc.player_side.pokemonParty:
		party.append(bp.base_data)
		if bp == target_battle_pokemon:
			slot = idx
		idx += 1

	return ItemUseContext.new(
		ItemEnums.UseContext.BATTLE,
		party,
		bag,
		target_battle_pokemon.base_data,
		slot,
		-1,
		bc,
		choice.pokemon,
		target_battle_pokemon
	)
