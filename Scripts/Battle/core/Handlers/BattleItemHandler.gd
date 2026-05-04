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
