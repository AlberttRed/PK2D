class_name BattleStruggleChoice
extends BattleMoveChoice

var _struggle_move: BattleMove = null


static func create_move_for(pokemon: BattlePokemon) -> BattleMove:
	var move_data: MoveData = DatabaseService.get_move(MovesEnum.Values.STRUGGLE)
	if move_data == null:
		push_error("BattleStruggleChoice: Forcejeo (165) no encontrado en DatabaseService")
		return null
	return Move.new(move_data).to_battle_move(pokemon)


static func create_for(pokemon: BattlePokemon) -> BattleStruggleChoice:
	var choice := BattleStruggleChoice.new()
	choice.pokemon = pokemon
	choice._struggle_move = create_move_for(pokemon)
	if choice._struggle_move != null:
		var selector := BattleTargetSelector.new()
		choice.targets = selector.resolve_targets(choice._struggle_move, pokemon, null)
	return choice


static func create_if_needed(pokemon: BattlePokemon) -> BattleStruggleChoice:
	var filter := BattleEffectController.get_move_selection_filter(pokemon)
	if filter.requires_struggle():
		return create_for(pokemon)
	return null


func get_move() -> BattleMove:
	return _struggle_move


func resolve() -> Array[BattleHandler]:
	var handlers: Array[BattleHandler] = []
	var move_instance := get_move()
	if move_instance == null or targets.is_empty():
		return handlers

	for target_entry in targets:
		handlers.append(BattleStruggleMoveHandler.new(move_instance, pokemon, target_entry))

	return handlers
