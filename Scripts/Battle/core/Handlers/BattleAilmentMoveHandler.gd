extends BattleMoveHandler

class_name BattleAilmentMoveHandler

var _apply_results: Array[Dictionary] = []


func _apply() -> void:
	_apply_results.clear()
	if target.get_pokemon() == null:
		return

	for entry in move.get_ailment_entries():
		_apply_results.append(_try_apply_ailment_entry(entry))


func _visualize(ui) -> void:
	for apply_data in _apply_results:
		await _visualize_ailment_entry_result(ui, apply_data, true)
