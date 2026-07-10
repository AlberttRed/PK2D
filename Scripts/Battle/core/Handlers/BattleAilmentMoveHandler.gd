extends BattleMoveHandler

class_name BattleAilmentMoveHandler

var _apply_results: Array[Dictionary] = []
var _move_effect: BattleMoveEffect = null


func _apply() -> void:
	_apply_results.clear()
	if target.get_pokemon() == null:
		return

	for entry in move.get_ailment_entries():
		_apply_results.append(_try_apply_ailment_entry(entry))


func _visualize(ui) -> void:
	var target_pokemon: BattlePokemon = target.get_pokemon()
	if target_pokemon == user and _move_effect == null:
		_move_effect = move.create_move_effect(user)
	if _move_effect != null and target_pokemon == user:
		await _move_effect.visualize(ui)
	for apply_data in _apply_results:
		await _visualize_ailment_entry_result(ui, apply_data, true)
