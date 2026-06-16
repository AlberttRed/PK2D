extends BattleMoveHandler

class_name BattleDamageAilmentMoveHandler

var damage: DamageEffect = null
var _apply_results: Array[Dictionary] = []


func _apply() -> void:
	if target.get_pokemon() == null:
		return

	damage = move.calculate_damage(target.get_pokemon())
	show_effectiveness = (damage.effectiveness != 1.0)
	damage.apply()

	_apply_results.clear()
	if damage == null or damage.is_ineffective() or target.get_pokemon().is_fainted():
		return

	for entry in move.get_ailment_entries():
		_apply_results.append(_try_apply_ailment_entry(entry))


func _visualize(ui) -> void:
	if damage != null:
		await damage.visualize(ui)
		if damage.is_critical:
			await ui.show_critical_hit_message()
		if show_effectiveness:
			await ui.show_effectiveness_message(damage)

	for apply_data in _apply_results:
		await _visualize_ailment_entry_result(ui, apply_data, false)
