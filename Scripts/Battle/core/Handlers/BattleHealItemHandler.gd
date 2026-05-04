extends BattleItemHandler

class_name BattleHealItemHandler

var _choice: BattleBagChoice = null
var _item_data: ItemData = null


func _init(choice: BattleBagChoice, item_data: ItemData) -> void:
	_choice = choice
	_item_data = item_data


func _apply() -> void:
	var bc: BattleController = _choice.battle_controller
	var actor: BattlePokemon = _choice.pokemon
	if bc == null or actor == null:
		item_use_result = ItemUseResult.failure_error("Contexto de combate incompleto.")
		item_use_result.battle_continuation = ItemUseResult.BattleContinuation.COMPLETE_ACTION
		return

	var target_bp := actor
	var ctx: ItemUseContext = _build_player_battle_item_context(_choice, target_bp)
	item_use_result = ItemUseService.try_use(_item_data, ctx)

	if item_use_result.success:
		target_bp.refresh_derived_stats_from_base()
		_refresh_hp_bar(target_bp)
		item_use_result.battle_continuation = ItemUseResult.BattleContinuation.COMPLETE_ACTION
		_consume_from_bag_if_needed(_item_data, item_use_result)
	else:
		item_use_result.battle_continuation = ItemUseResult.BattleContinuation.COMPLETE_ACTION


func _refresh_hp_bar(target_bp: BattlePokemon) -> void:
	var spot: BattleSpot = target_bp.battle_spot
	if spot != null and spot.hp_bar != null:
		spot.hp_bar.sync_health_bar_from_pokemon()


func _visualize(ui: BattleUI) -> void:
	if item_use_result == null:
		return
	if not item_use_result.message.is_empty():
		await ui.show_message_from_dict({
			"type": "display",
			"text": item_use_result.message,
			"wait_time": 0.8,
		})


func _build_player_battle_item_context(choice: BattleBagChoice, target_battle_pokemon: BattlePokemon) -> ItemUseContext:
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
