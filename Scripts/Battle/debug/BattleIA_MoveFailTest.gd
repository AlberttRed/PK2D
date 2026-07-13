extends BattleIA

class_name BattleIA_MoveFailTest

## IA determinista para TestBattle: secuencia de movimientos que provocan fallos naturales.

var _planned_move_ids: Array[int] = []
var _step := 0


func _init() -> void:
	difficulty_name = "MoveFailTest"
	use_items = false
	can_switch_strategically = false


static func create_gastly_scenario() -> BattleIA_MoveFailTest:
	var ia := BattleIA_MoveFailTest.new()
	ia._planned_move_ids = [
		MovesEnum.Values.LICK,
		MovesEnum.Values.DOUBLE_TEAM,
		MovesEnum.Values.DOUBLE_TEAM,
		MovesEnum.Values.DOUBLE_TEAM,
		MovesEnum.Values.DOUBLE_TEAM,
		MovesEnum.Values.DOUBLE_TEAM,
		MovesEnum.Values.DOUBLE_TEAM,
	]
	return ia


func decide_action(pokemon: BattlePokemon) -> BattleChoice:
	var move_id := MovesEnum.Values.LICK
	if _step < _planned_move_ids.size():
		move_id = _planned_move_ids[_step]
	_step += 1
	return _build_move_choice(pokemon, move_id)


func _build_move_choice(pokemon: BattlePokemon, move_id: int) -> BattleChoice:
	var moves := pokemon.get_available_moves()
	var move_index := -1
	for i in moves.size():
		if moves[i].get_id() == move_id:
			move_index = i
			break
	if move_index < 0:
		var legal := get_selectable_move_indices(pokemon)
		if legal.is_empty():
			return BattlePassChoice.new()
		move_index = legal[0]
	var move := moves[move_index]
	var choice := BattleMoveChoice.new()
	choice.move_index = move_index
	choice.pokemon = pokemon
	var selector := BattleTargetSelector.new()
	choice.targets = selector.resolve_targets(move, pokemon, null)
	return choice
